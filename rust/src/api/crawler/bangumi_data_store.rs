use super::types::*;
use memmap2::Mmap;
use std::path::Path;
use std::sync::{
    Arc, OnceLock,
    atomic::{AtomicU64, Ordering},
};
use std::time::Duration;
use tokio::sync::Semaphore;

use super::parse_time::*;
use super::sites_index::{build_sites_index, invalidate_sites_index};

pub(super) fn bangumi_data_trace(message: &str) {
    log::info!("[RustBangumiData] {}", message);
    println!("[RustBangumiData] {}", message);
}

/// Sidecar file that records the last (Unix-epoch-second) failed warmup
/// attempt. Holding this on disk means a transient CDN hiccup doesn't trap
/// the user on a stale cache for the full 7-day TTL: as soon as more than
/// `BANGUMI_DATA_RETRY_AFTER_SECS` has passed since the last failure, the
/// next warmup will retry.
pub(super) fn bangumi_data_failure_marker_path(cache_dir: &str) -> std::path::PathBuf {
    std::path::Path::new(cache_dir).join("bangumi-data.failed-at")
}

pub(super) fn write_failure_marker(cache_dir: &str) {
    let path = bangumi_data_failure_marker_path(cache_dir);
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(epoch) = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) {
        let _ = std::fs::write(&path, epoch.as_secs().to_string());
    }
}

pub(super) fn clear_failure_marker(cache_dir: &str) {
    let _ = std::fs::remove_file(bangumi_data_failure_marker_path(cache_dir));
}

pub(super) fn bangumi_data_version_marker_path(cache_dir: &str) -> std::path::PathBuf {
    std::path::Path::new(cache_dir).join("bangumi-data.version")
}

pub(super) fn write_version_marker(cache_dir: &str, version: &str) {
    let path = bangumi_data_version_marker_path(cache_dir);
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let _ = std::fs::write(&path, version);
}

pub(super) fn read_version_marker(cache_dir: &str) -> Option<String> {
    let path = bangumi_data_version_marker_path(cache_dir);
    let raw = std::fs::read_to_string(&path).ok()?;
    let trimmed = raw.trim().to_string();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed)
    }
}

pub(super) fn read_bangumi_data_version_from_json(_path: &Path) -> Option<String> {
    None
}

pub(super) fn extract_bangumi_data_version_from_url(url: &str) -> Option<String> {
    let re = regex::Regex::new(r"bangumi-data@([\d.]+)/").ok()?;
    let caps = re.captures(url)?;
    caps.get(1).map(|m| m.as_str().to_string())
}

pub(super) fn last_failure_age_secs(cache_dir: &str) -> Option<u64> {
    let path = bangumi_data_failure_marker_path(cache_dir);
    let raw = std::fs::read_to_string(&path).ok()?;
    let epoch: u64 = raw.trim().parse().ok()?;
    let elapsed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .ok()?
        .as_secs()
        .saturating_sub(epoch);
    Some(elapsed)
}

/// How long after a failed warmup we will keep refusing to retry. Short
/// enough that a one-hour CDN outage won't trap the user on stale data for
/// the full freshness window; long enough that a wedged retry loop doesn't
/// hammer the CDN on every launch.
pub(super) const BANGUMI_DATA_RETRY_AFTER_SECS: u64 = 60 * 60;

/// Validate the downloaded payload is well-formed JSON with an `items` array.
///
/// Since we float on `@0.3` (resolved to the latest patch by the CDN) there
/// is no single pinned SHA-512 to check against. Structural validation
/// catches truncated responses, CDN error pages, and other malformed
/// payloads while allowing the version to advance automatically.
pub(super) fn verify_bangumi_data_payload(bytes: &[u8]) -> anyhow::Result<()> {
    let value: serde_json::Value = serde_json::from_slice(bytes)
        .map_err(|e| anyhow::anyhow!("bangumi-data payload is not valid JSON: {}", e))?;
    if !value.get("items").map_or(false, |v| v.is_array()) {
        anyhow::bail!("bangumi-data payload JSON is missing a top-level \"items\" array");
    }
    Ok(())
}

pub(super) async fn download_bangumi_data_json(path: &Path) -> anyhow::Result<()> {
    let cache_dir = crate::api::config::get_cache_dir();
    let urls = crate::api::config::get_bangumi_data_cdn_urls();
    if urls.is_empty() {
        anyhow::bail!("no bangumi-data CDN candidates configured");
    }

    let mut last_err: Option<anyhow::Error> = None;
    for url in &urls {
        log::info!("Trying bangumi-data from {}", url);
        let attempt = crate::api::network::retry_request("download_bangumi_data_json", |client| {
            // The package is ~7 MB; override the shared client's 30 s timeout so
            // the download survives slow mainland-China links without aborting
            // mid-stream.
            client.get(url).timeout(Duration::from_secs(120))
        })
        .await;

        let resp = match attempt {
            Ok(r) => r,
            Err(e) => {
                log::warn!("bangumi-data fetch failed for {}: {}", url, e);
                last_err = Some(e);
                continue;
            }
        };

        let resolved_url = resp.url().to_string();
        let resolved_version = extract_bangumi_data_version_from_url(&resolved_url);

        let bytes = match resp.bytes().await {
            Ok(b) => b,
            Err(e) => {
                log::warn!("bangumi-data body read failed for {}: {}", url, e);
                last_err = Some(e.into());
                continue;
            }
        };

        if bytes.is_empty() {
            log::warn!("bangumi-data payload empty from {}", url);
            last_err = Some(anyhow::anyhow!("bangumi-data download returned 0 bytes"));
            continue;
        }

        if let Err(e) = verify_bangumi_data_payload(&bytes) {
            log::warn!(
                "{}",
                format_args!("{} — refusing to cache an invalid payload", e)
            );
            last_err = Some(e);
            continue;
        };

        // Atomic write: stage to "<name>.tmp" in the same directory, fsync,
        // then rename. A crash mid-write leaves the previous (good) cache in
        // place; a successful rename replaces it in one syscall.
        if let Err(e) = atomic_write_bytes(path, &bytes) {
            log::warn!("bangumi-data atomic write failed: {}", e);
            last_err = Some(e);
            continue;
        }

        if let Some(ref ver) = resolved_version {
            write_version_marker(&cache_dir, ver);
        }

        log::info!(
            "bangumi-data downloaded from {} ({} bytes, version={:?}, ok)",
            url,
            bytes.len(),
            resolved_version
        );
        clear_failure_marker(&cache_dir);
        return Ok(());
    }

    write_failure_marker(&cache_dir);
    Err(last_err.unwrap_or_else(|| anyhow::anyhow!("bangumi-data download failed")))
}

/// Write `bytes` to `path` atomically by staging to `<path>.tmp` and renaming.
/// `rename` is atomic on the same filesystem on every supported target
/// (Windows / macOS / Linux), so a crash or concurrent read either sees the
/// old file or the new one — never a half-written file.
pub(super) fn atomic_write_bytes(path: &Path, bytes: &[u8]) -> anyhow::Result<()> {
    use std::io::Write;

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let file_name = path
        .file_name()
        .ok_or_else(|| anyhow::anyhow!("cache path has no file name"))?;
    let tmp_path = path.with_file_name(format!(
        "{}.tmp.{}",
        file_name.to_string_lossy(),
        std::process::id()
    ));

    {
        let mut f = std::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&tmp_path)?;
        f.write_all(bytes)?;
        f.sync_all()?;
    }
    // On Windows, std::fs::rename fails if the destination exists, so
    // explicitly replace. POSIX rename(2) is atomic and overwrites.
    replace_atomic(&tmp_path, path)?;
    let _ = std::fs::remove_file(&tmp_path);
    Ok(())
}

#[cfg(unix)]
pub(super) fn replace_atomic(src: &Path, dst: &Path) -> anyhow::Result<()> {
    std::fs::rename(src, dst)?;
    Ok(())
}

#[cfg(windows)]
pub(super) fn replace_atomic(src: &Path, dst: &Path) -> anyhow::Result<()> {
    // Rust's std::fs::rename on Windows is implemented via MoveFileExW with
    // MOVEFILE_REPLACE_EXISTING, so it is atomic and overwrites the
    // destination. If that ever changes or fails, fall back to a manual
    // copy-then-delete (still better than a half-written cache file).
    match std::fs::rename(src, dst) {
        Ok(()) => Ok(()),
        Err(e) => {
            log::warn!(
                "MoveFileEx failed for {} -> {} ({}); falling back to copy+delete",
                src.display(),
                dst.display(),
                e
            );
            std::fs::copy(src, dst)?;
            let _ = std::fs::remove_file(src);
            Ok(())
        }
    }
}

pub(super) fn load_data_json_and_filter(
    data: &BangumiDataJson,
    year_quarter: &str,
) -> Vec<AnimeInfo> {
    let items = filter_items_by_quarter(&data.items, year_quarter);
    items
        .iter()
        .filter_map(|item| bgmlist_item_to_anime_info(item))
        .collect()
}

/// Read and parse the cached `bangumi-data.json` via `memmap2`. The 7 MB file
/// is read once by the page cache; subsequent calls within the same process
/// (or after the file has been touched) skip the `read()` syscall cost and
/// only pay the ~20 ms serde_json parse.
pub(super) fn read_bangumi_data_json_mmap(path: &Path) -> anyhow::Result<BangumiDataJson> {
    let file = std::fs::File::open(path)?;
    let mmap = unsafe { Mmap::map(&file)? };
    let data: BangumiDataJson = serde_json::from_slice(&mmap)?;
    Ok(data)
}

// =====================================================================
// Shared parsed `bangumi-data.json` payload
//
// Both the schedule path (`load_data_json_and_filter` -> which animes
// aired in quarter X?) and the sites-index path (`build_sites_index` ->
// bangumi.tv id -> Vec<RSS site>) walk the same ~7 MB JSON. Without
// sharing, each path re-`mmap`s and re-parses the file. We keep a
// process-wide `Arc<BangumiDataJson>` in a `OnceLock<RwLock<...>>` slot;
// the first caller pays the parse cost, subsequent callers clone the
// `Arc` and operate on the already-parsed data.
//
// The slot is dropped by `invalidate_bangumi_data_cache` whenever the
// underlying file is replaced (download, refresh) so the next caller
// reparses the new payload.
// =====================================================================

pub(super) static BANGUMI_DATA: OnceLock<std::sync::RwLock<Option<Arc<BangumiDataJson>>>> =
    OnceLock::new();

pub(super) fn bangumi_data_slot() -> &'static std::sync::RwLock<Option<Arc<BangumiDataJson>>> {
    BANGUMI_DATA.get_or_init(|| std::sync::RwLock::new(None))
}

pub(super) static BANGUMI_DATA_GENERATION: AtomicU64 = AtomicU64::new(0);

pub(super) fn bangumi_data_generation() -> u64 {
    BANGUMI_DATA_GENERATION.load(Ordering::SeqCst)
}

/// Drop the cached parsed payload. Called whenever `bangumi-data.json`
/// is replaced on disk so the next call reparses the new file.
pub(crate) fn invalidate_bangumi_data_cache() {
    if let Ok(mut guard) = bangumi_data_slot().write() {
        *guard = None;
    }
    BANGUMI_DATA_GENERATION.fetch_add(1, Ordering::SeqCst);
}

/// Return a clone of the cached parsed payload, parsing + caching the
/// on-disk file on first call. Returns `Err` when the file is missing or
/// malformed.
///
/// Safe to call from both sync and async contexts: the read path is a
/// non-blocking `try_read` (clones an `Arc`), the write path is a
/// blocking `write` on a `std::sync::RwLock`. The actual `mmap` +
/// `serde_json::from_slice` runs on the calling thread; callers in
/// async contexts should wrap this in `tokio::task::spawn_blocking`
/// when they expect the cold path to be taken.
pub(super) fn get_or_load_bangumi_data_blocking() -> anyhow::Result<Arc<BangumiDataJson>> {
    {
        let guard = bangumi_data_slot().read().unwrap();
        if let Some(arc) = guard.as_ref() {
            return Ok(Arc::clone(arc));
        }
    }
    let cache_dir = crate::api::config::get_cache_dir();
    let path = std::path::Path::new(&cache_dir).join("bangumi-data.json");
    if !path.exists() {
        anyhow::bail!("bangumi-data.json not cached at {}", path.display());
    }
    let data = read_bangumi_data_json_mmap(&path)?;
    let arc = Arc::new(data);
    let mut guard = bangumi_data_slot().write().unwrap();
    // Another caller may have raced us to install the value; prefer the
    // existing one so two parallel parses can't fight.
    if let Some(existing) = guard.as_ref() {
        return Ok(Arc::clone(existing));
    }
    *guard = Some(Arc::clone(&arc));
    Ok(arc)
}

// =====================================================================
// Single-flight guards for download & sites-index build
//
// Prevent warmup, Level 3 download, API fallback, and manual refresh
// from concurrently downloading the same 7 MB file or building the
// sites index in parallel. Each guard is a process-wide semaphore=1;
// second callers wait for the first to finish rather than redoing work.
// =====================================================================

pub(super) static DOWNLOAD_SINGLE_FLIGHT: OnceLock<Semaphore> = OnceLock::new();

pub(super) fn download_single_flight() -> &'static Semaphore {
    DOWNLOAD_SINGLE_FLIGHT.get_or_init(|| Semaphore::new(1))
}

pub(super) static SITES_INDEX_BUILD_SINGLE_FLIGHT: OnceLock<Semaphore> = OnceLock::new();

pub(super) fn sites_index_build_single_flight() -> &'static Semaphore {
    SITES_INDEX_BUILD_SINGLE_FLIGHT.get_or_init(|| Semaphore::new(1))
}

pub(super) fn file_signature(path: &Path) -> Option<(std::time::SystemTime, u64)> {
    let metadata = std::fs::metadata(path).ok()?;
    Some((metadata.modified().ok()?, metadata.len()))
}

/// Download `bangumi-data.json` with single-flight protection.
///
/// - `force=false`: "fetch when missing" path (timetable Level 3). After
///   waiting for the permit, skip the download if another caller produced
///   the file in the meantime, so warmup and Level 3 don't both fetch 7 MB.
/// - `force=true`: manual refresh / stale warmup. The first caller performs
///   the refresh; queued forced callers skip their duplicate download when
///   the file changed while they were waiting.
pub(super) async fn download_bangumi_data_json_single_flight(
    path: &Path,
    force: bool,
) -> anyhow::Result<()> {
    let previous_signature = file_signature(path);
    let _permit = download_single_flight().acquire().await;
    // Another caller may have just finished downloading while we waited.
    let current_signature = file_signature(path);
    if !force {
        if current_signature.is_some() {
            log::debug!(
                "bangumi-data.json already present after single-flight wait, skipping download"
            );
            return Ok(());
        }
    } else if current_signature.is_some() && current_signature != previous_signature {
        log::debug!(
            "bangumi-data.json refreshed by another caller while waiting, skipping duplicate forced download"
        );
        return Ok(());
    }
    download_bangumi_data_json(path).await
}

// =====================================================================
// bangumi-data cache status / refresh / ensure
// =====================================================================

pub(crate) fn get_bangumi_data_cache_status() -> BangumiDataCacheStatus {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");

    let metadata = std::fs::metadata(&local_path).ok();
    let cached = metadata.is_some();
    let file_size = metadata.as_ref().map(|m| m.len()).unwrap_or(0);
    let last_modified_secs = metadata
        .and_then(|m| m.modified().ok())
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs());
    let version = read_version_marker(&cache_dir)
        .or_else(|| read_bangumi_data_version_from_json(&local_path))
        .unwrap_or_else(|| crate::api::config::BANGUMI_DATA_VERSION.to_string());
    let last_failed_secs = last_failure_age_secs(&cache_dir);

    BangumiDataCacheStatus {
        cached,
        file_size,
        last_modified_secs,
        version,
        last_failed_secs,
    }
}

pub(crate) async fn refresh_bangumi_data_cache() -> anyhow::Result<bool> {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");
    // force=true: this is a user-initiated refresh — always re-download
    // even when the file already exists.
    download_bangumi_data_json_single_flight(&local_path, true).await?;
    clear_failure_marker(&cache_dir);
    invalidate_bangumi_data_cache();
    invalidate_sites_index().await;
    if let Err(e) = build_sites_index().await {
        log::warn!("bangumi-data sites index build failed after refresh: {e:#}");
    }
    Ok(true)
}

/// Ensure the offline `bangumi-data.json` cache is present and fresh. Downloads
/// only when the file is missing or its mtime is older than `max_age_secs`, so
/// the ~7 MB payload is not re-fetched on every startup. Returns `true` when a
/// download actually happened. Safe to call from app startup.
///
/// Transient CDN failure handling: when the last warmup attempt failed we
/// drop a sidecar file with the failure timestamp. While that marker is
/// fresher than `BANGUMI_DATA_RETRY_AFTER_SECS` AND the on-disk cache still
/// exists (even if stale), we skip the download so we don't hammer the CDN
/// every startup. As soon as `BANGUMI_DATA_RETRY_AFTER_SECS` has elapsed
/// — *or* the cache is missing — the next call retries.
pub(crate) async fn ensure_bangumi_data_cache(max_age_secs: u64) -> anyhow::Result<bool> {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");
    let max_age = Duration::from_secs(max_age_secs);

    let mtime = std::fs::metadata(&local_path)
        .and_then(|m| m.modified())
        .ok();
    let age_ok = mtime
        .and_then(|t| t.elapsed().ok())
        .map(|age| age < max_age)
        .unwrap_or(false);

    let recently_failed = last_failure_age_secs(&cache_dir)
        .map(|age| age < BANGUMI_DATA_RETRY_AFTER_SECS)
        .unwrap_or(false);

    if age_ok {
        log::debug!("bangumi-data cache is fresh, skipping download");
        // A successful warmup clears the failure marker opportunistically —
        // catches the case where the cache was refreshed by another process.
        if recently_failed {
            clear_failure_marker(&cache_dir);
        }
        // Startup warmup should stay light: it only keeps the JSON cache
        // available/fresh. Sites-index construction can be memory-heavy on
        // Android and details lookups self-heal lazily when needed.
        return Ok(false);
    }

    if local_path.exists() && recently_failed {
        log::info!(
            "bangumi-data warmup recently failed ({}s ago) and a stale cache exists; \
             skipping retry until cooldown elapses",
            last_failure_age_secs(&cache_dir).unwrap_or(0)
        );
        // Stale cache can still be served. Do not build the sites index during
        // startup warmup; details lookups self-heal lazily when needed.
        return Ok(false);
    }

    // force=true: we only reach this branch when the cache is stale
    // (older than max_age_secs), so the existing file must be replaced.
    download_bangumi_data_json_single_flight(&local_path, true).await?;
    invalidate_bangumi_data_cache();
    invalidate_sites_index().await;
    // Keep startup warmup focused on refreshing the JSON file. Avoid building
    // the sites index here; it can be rebuilt lazily by details-page lookups.
    Ok(true)
}
