use lazy_static::lazy_static;
use librqbit::{
    AddTorrent, AddTorrentOptions, AddTorrentResponse, Session, SessionOptions, api::Api,
    api::TorrentIdOrHash, http_api::HttpApi,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::Once;
use tokio::sync::Mutex;

const DEFAULT_TRACKERS: [&str; 6] = [
    "&tr=udp://tracker.opentrackr.org:1337/announce",
    "&tr=udp://open.demonii.com:1337/announce",
    "&tr=udp://exodus.desync.com:6969/announce",
    "&tr=udp://tracker.openbittorrent.com:6969/announce",
    "&tr=udp://opentracker.i2p.rocks:6969/announce",
    "&tr=udp://tracker.doko.moe:6969/announce",
];

pub fn init_engine(cache_dir: String, download_dir: String) {
    // Initialize config with paths
    crate::api::config::init_config(cache_dir, download_dir);

    static INIT_ENGINE_ONCE: Once = Once::new();
    INIT_ENGINE_ONCE.call_once(|| {
        // Disable heavy logs from rqbit and related crates
        let _ = env_logger::Builder::from_env(
            env_logger::Env::default()
                .default_filter_or("info,librqbit=off,librqbit_dht=off,tracing=off"),
        )
        .try_init();
        flutter_rust_bridge::setup_default_user_utils();
    });

    log::info!("Mikan Player Rust engine initialized");

    if let Some(proxy) = crate::api::network::get_system_proxy() {
        log::info!("Detected system proxy: {}", proxy);
    } else {
        log::info!("No system proxy detected.");
    }
}

pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}

pub fn update_config(
    bgm: String,
    bangumi: String,
    mikan: String,
    playback_sub: String,
    use_reverse_proxy: bool,
) {
    crate::api::config::update_config(bgm, bangumi, mikan, playback_sub, use_reverse_proxy);
}

pub fn set_bangumi_reverse_proxy(enabled: bool) {
    crate::api::config::set_bangumi_reverse_proxy(enabled);
}

pub fn get_bangumi_reverse_proxy() -> bool {
    crate::api::config::get_bangumi_reverse_proxy()
}

pub fn set_disabled_sources(sources: Vec<String>) {
    crate::api::config::set_disabled_sources(sources);
}

pub fn set_max_concurrent_searches(limit: u32) {
    crate::api::config::set_max_concurrent_searches(limit);
}

pub fn set_download_dir(dir: String) {
    crate::api::config::set_download_dir(dir);
}

pub async fn get_playback_sources() -> Vec<crate::api::generic_scraper::SourceState> {
    match crate::api::generic_scraper::get_playback_sources().await {
        Ok(s) => s,
        Err(e) => {
            log::error!("Failed to get playback sources: {}", e);
            vec![]
        }
    }
}

/// 预加载播放源配置（应用启动和设置更改时调用）
/// 这会尝试从订阅地址拉取最新的配置，失败时使用本地备份
pub async fn preload_playback_source_config() -> String {
    log::info!("Starting to preload playback source config...");
    match crate::api::generic_scraper::preload_playback_sources().await {
        Ok(_) => {
            log::info!("Playback source config preloaded successfully");
            "success".to_string()
        }
        Err(e) => {
            log::warn!("Failed to preload playback source config: {}", e);
            format!("error: {}", e)
        }
    }
}

/// 刷新播放源配置（从订阅地址重新拉取并保存到本地缓存）
/// 只在用户点击刷新按钮时调用。返回合并后的完整 JSON（含手动源）。
pub async fn refresh_playback_source_config() -> String {
    log::info!("Starting to refresh playback source config from subscription URL...");
    match crate::api::generic_scraper::refresh_playback_source_config().await {
        Ok(result) => {
            log::info!(
                "Playback source config refreshed successfully (apply_default_enabled={})",
                result.apply_default_enabled
            );
            result.content
        }
        Err(e) => {
            log::error!("Failed to refresh playback source config: {}", e);
            format!("error: {}", e)
        }
    }
}

struct AppState {
    session: Arc<Session>,
}

lazy_static! {
    static ref STATE: Arc<Mutex<Option<Arc<tokio::sync::Mutex<AppState>>>>> =
        Arc::new(Mutex::new(None));
}

// Initialize session and server if not already running
async fn ensure_initialized() -> anyhow::Result<Arc<tokio::sync::Mutex<AppState>>> {
    let mut state_guard = STATE.lock().await;
    if let Some(state) = state_guard.as_ref() {
        return Ok(state.clone());
    }

    let mut options = SessionOptions::default();
    // Enable a TCP listener for incoming peer connections.
    // Using a high port range avoids the legacy 6881-6889 ports that some ISPs throttle.
    // NOTE: `None` disables listening entirely in librqbit.
    options.listen_port_range = Some(49152..65535);

    // Enable UPnP for NAT traversal
    options.enable_upnp_port_forwarding = true;

    // Buffer some disk writes in memory to reduce small-write overhead on Windows.
    // This can noticeably improve throughput on some machines (AV/indexing/slow disks).
    // Value is in megabytes. Use a smaller buffer on mobile where memory is tight.
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        options.defer_writes_up_to = Some(16);
    }
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        options.defer_writes_up_to = Some(64);
    }

    // Enable DHT for better peer discovery (especially for magnets)
    // This is crucial for discovering peers from magnet links
    options.disable_dht = false;

    // Disable DHT persistence on Android to avoid initialization errors.
    // Some Android file systems or permission settings can cause issues with the DHT state file.
    #[cfg(target_os = "android")]
    {
        options.disable_dht_persistence = true;
    }
    #[cfg(not(target_os = "android"))]
    {
        options.disable_dht_persistence = false;
    }

    // Optimize peer connections for faster downloads.
    // A shorter connect timeout frees up connection slots more quickly when peers
    // are unreachable; 10 s is plenty for any peer that's going to answer at all.
    options.peer_opts = Some(librqbit::PeerConnectionOptions {
        connect_timeout: Some(std::time::Duration::from_secs(10)),
        read_write_timeout: Some(std::time::Duration::from_secs(60)),
        ..Default::default()
    });

    // Note: librqbit 8.1.1 may not have disable_pex option
    // PEX is usually enabled by default in modern BitTorrent clients

    // Use the provided download directory from config
    let download_dir = std::path::PathBuf::from(crate::api::config::get_download_dir());

    if !download_dir.exists() {
        std::fs::create_dir_all(&download_dir)?;
    }

    log::info!("Torrent data directory: {:?}", download_dir);
    let session = Session::new_with_opts(download_dir, options).await?;

    if let Some(port) = session.tcp_listen_port() {
        log::info!("rqbit incoming TCP listener: 0.0.0.0:{}", port);
    } else {
        log::warn!("rqbit incoming TCP listener is DISABLED (no listen port)");
    }

    let api = Api::new(session.clone(), None, None);

    let http_api = HttpApi::new(api, None);

    // Start HTTP Server on port 3000
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = tokio::net::TcpListener::bind(addr).await?;

    // Spawn server in background
    tokio::spawn(async move {
        if let Err(e) = http_api.make_http_api_and_run(listener, None).await {
            log::error!("HttpApi server error: {}", e);
        }
    });

    let app_state = Arc::new(tokio::sync::Mutex::new(AppState {
        session: session.clone(),
    }));

    *state_guard = Some(app_state.clone());
    Ok(app_state)
}

async fn get_session() -> anyhow::Result<Arc<Session>> {
    let state = ensure_initialized().await?;
    let state_guard = state.lock().await;
    Ok(state_guard.session.clone())
}

fn text_preview(value: &str, max_chars: usize) -> String {
    let mut chars = value.chars();
    let preview = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{preview}...")
    } else {
        preview
    }
}

fn inject_default_trackers(mut magnet: String) -> (String, usize) {
    let mut added_tracker_count = 0;
    for tracker in DEFAULT_TRACKERS {
        if !magnet.contains(tracker) {
            magnet.push_str(tracker);
            added_tracker_count += 1;
        }
    }
    (magnet, added_tracker_count)
}

pub async fn start_torrent(magnet: String) -> String {
    if magnet.trim().is_empty() {
        return "Error: empty magnet link".to_string();
    }

    let session = match get_session().await {
        Ok(s) => s,
        Err(e) => return format!("Error initializing engine: {}", e),
    };

    // Add Torrent
    // Log original magnet link (truncated for safety)
    let magnet_preview = text_preview(&magnet, 200);
    log::info!("Original magnet link: {}", magnet_preview);

    // Count original trackers in the magnet link
    let original_tracker_count = magnet.matches("&tr=").count();
    log::info!(
        "Original magnet contains {} trackers",
        original_tracker_count
    );

    // Inject a small, high-quality tracker set. We intentionally keep the list
    // short: every extra tracker has to be announced to on startup, which
    // significantly delays the first peer connection when many are slow or dead.
    // Users get the rest through DHT + PEX + the magnet's own trackers.
    let (magnet, added_tracker_count) = inject_default_trackers(magnet);

    let final_tracker_count = magnet.matches("&tr=").count();
    log::info!(
        "Added {} new trackers, total {} trackers in final magnet link",
        added_tracker_count,
        final_tracker_count
    );

    // Optimized Torrent Options for streaming
    let mut add_opts = AddTorrentOptions::default();

    // Use sequential mode for streaming - downloads pieces in order
    // This is crucial for video playback
    add_opts.overwrite = true;
    add_opts.only_files_regex = None; // We'll select the file after getting metadata
    // Use the current download directory from config so that runtime path
    // changes take effect for newly added torrents immediately.
    add_opts.output_folder = Some(crate::api::config::get_download_dir());

    // Enable initial peer fetch to get more peers quickly
    add_opts.initial_peers = None; // Let it use tracker announces

    // List mode should be false to actually download
    add_opts.list_only = false;

    // Force reannounce to trackers to get fresh peer list
    add_opts.force_tracker_interval = None; // Use default tracker intervals

    let torrent = AddTorrent::from_url(magnet.clone());

    // We get a handle and ID from the response
    let response = match tokio::time::timeout(
        tokio::time::Duration::from_secs(90),
        session.add_torrent(torrent, Some(add_opts)),
    )
    .await
    {
        Ok(Ok(res)) => res,
        Ok(Err(e)) => return format!("Error adding torrent: {}", e),
        Err(_) => {
            return "Error adding torrent: timed out waiting for torrent metadata".to_string();
        }
    };

    let (_id, handle) = match response {
        AddTorrentResponse::Added(id, h) => (id, h),
        AddTorrentResponse::AlreadyManaged(id, h) => (id, h),
        AddTorrentResponse::ListOnly(_) => return "Error: Torrent is list-only mode".to_string(),
    };

    // Wait for metadata to ensure file list is populated
    if let Err(e) = handle.wait_until_initialized().await {
        return format!("Error waiting for metadata: {}", e);
    }

    // Find largest file (video)
    let info_hash = handle.info_hash().as_string();

    // Log tracker information for debugging
    // This helps verify that trackers are being used correctly
    let stats = handle.stats();
    if let Some(live) = &stats.live {
        log::info!(
            "Torrent status: state={:?}, peers={}, download_speed={:.2} MB/s",
            stats.state,
            live.snapshot.peer_stats.live,
            live.download_speed.mbps
        );
    }

    let (largest_file_idx, largest_len) = handle
        .with_metadata(|meta| {
            let mut largest_idx = 0;
            let mut largest_len = 0;
            if let Ok(file_iter) = meta.info.iter_file_details() {
                for (idx, file) in file_iter.enumerate() {
                    if file.len > largest_len {
                        largest_len = file.len;
                        largest_idx = idx;
                    }
                }
            }
            (largest_idx, largest_len)
        })
        .unwrap_or((0, 0));

    if largest_len == 0 {
        return "Error: No files found in torrent".to_string();
    }

    // Note: In librqbit 8.x, sequential download and file selection are handled
    // differently. The HTTP streaming endpoint prioritizes the requested range's
    // pieces automatically, so we don't need an artificial delay here before
    // returning the stream URL.

    log::info!(
        "Streaming file index {} from torrent {} (size: {} bytes)",
        largest_file_idx,
        info_hash,
        largest_len
    );

    // Get current stats for debugging
    let stats = handle.stats();
    if let Some(live) = &stats.live {
        log::info!(
            "Torrent state: {:?}, download speed: {:.2} MB/s",
            stats.state,
            live.download_speed.mbps
        );
    } else {
        log::info!("Torrent state: {:?}, not yet live", stats.state);
    }

    // Construct stream URL
    format!(
        "http://127.0.0.1:3000/torrents/{}/stream/{}",
        info_hash, largest_file_idx
    )
}

/// Torrent download statistics
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct TorrentStats {
    pub info_hash: String,
    pub name: String,
    pub state: String,
    pub progress: f64,
    pub download_speed: f64, // bytes per second
    pub upload_speed: f64,   // bytes per second
    pub downloaded: u64,     // bytes
    pub total_size: u64,     // bytes
    pub peers: u32,
    pub seeders: u32,
}

/// Detailed tracker status information
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct TrackerInfo {
    pub url: String,
    pub status: String,
    pub peers: u32,
    pub last_announce: String,
}

fn calculate_progress(downloaded: u64, total_size: u64) -> f64 {
    if total_size == 0 {
        return 0.0;
    }
    ((downloaded as f64 / total_size as f64) * 100.0).clamp(0.0, 100.0)
}

fn normalize_torrent_state(raw_state: &str, is_paused: bool) -> String {
    if is_paused {
        "paused".to_string()
    } else if raw_state.starts_with("Live") {
        "live".to_string()
    } else if raw_state.starts_with("Initializing") {
        "initializing".to_string()
    } else if raw_state.starts_with("Error") {
        "error".to_string()
    } else if raw_state.starts_with("Paused") {
        "paused".to_string()
    } else {
        raw_state.to_lowercase()
    }
}

fn format_torrent_stats(stats: &[TorrentStats]) -> String {
    if stats.is_empty() {
        return "No active torrents".to_string();
    }

    let mut result = String::from("Active Torrents:\n");
    for stat in stats {
        result.push_str(&format!(
            "- {} ({:.1}%): {:.2} MB/s down, {} peers\n",
            stat.name,
            stat.progress,
            stat.download_speed / 1024.0 / 1024.0,
            stat.peers
        ));
    }
    result
}

/// Get tracker information for a specific torrent
pub async fn get_tracker_info(info_hash: String) -> Vec<TrackerInfo> {
    let session = match get_session().await {
        Ok(s) => s,
        Err(_) => return vec![],
    };
    let info_hash_lower = info_hash.to_lowercase();

    // Find the torrent by info hash and get tracker info
    session.with_torrents(|torrents| {
        for (_id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                // Note: librqbit may not expose detailed tracker info in the public API
                // This is a placeholder for future implementation
                // For now, we return basic info
                log::info!("Getting tracker info for torrent: {}", info_hash);

                // Return empty vec as librqbit doesn't expose tracker details easily
                return vec![];
            }
        }
        vec![]
    })
}

/// Get detailed stats for all active torrents
pub async fn get_torrent_stats() -> Vec<TorrentStats> {
    let session = match get_session().await {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    // Use the session's torrent iteration method - collect data inside closure
    let results: Vec<TorrentStats> = session.with_torrents(|torrents| {
        let mut collected = Vec::new();
        for (id, handle) in torrents {
            let stats = handle.stats();
            let info_hash = handle.info_hash().as_string().to_lowercase();

            // Get torrent name from metadata
            let name = handle
                .with_metadata(|meta| {
                    meta.info
                        .name
                        .as_ref()
                        .map(|s| s.to_string())
                        .unwrap_or_else(|| format!("Torrent {}", id))
                })
                .unwrap_or_else(|_| format!("Torrent {}", id));

            // Get total size
            let total_size: u64 = handle
                .with_metadata(|meta| {
                    meta.info
                        .iter_file_lengths()
                        .ok()
                        .map(|iter| iter.sum::<u64>())
                        .unwrap_or(0)
                })
                .unwrap_or(0);

            let (download_speed, upload_speed, downloaded, peers, seeders) =
                if let Some(live) = &stats.live {
                    (
                        live.download_speed.mbps,
                        live.upload_speed.mbps,
                        stats.progress_bytes,
                        live.snapshot.peer_stats.live as u32,
                        live.snapshot.peer_stats.seen as u32,
                    )
                } else {
                    (0.0, 0.0, stats.progress_bytes, 0, 0)
                };

            let progress = calculate_progress(downloaded, total_size);

            // Normalize the state into a small, stable set of lowercase tokens so
            // the Dart side doesn't have to depend on `Debug` formatting of
            // librqbit's internal enum (variant names and payloads can change).
            let raw_state = format!("{:?}", stats.state);
            let is_paused = handle.is_paused();
            let normalized_state = normalize_torrent_state(&raw_state, is_paused);

            collected.push(TorrentStats {
                info_hash,
                name,
                state: normalized_state,
                progress,
                download_speed: download_speed as f64 * 1024.0 * 1024.0, // Convert from MB/s to bytes/s
                upload_speed: upload_speed as f64 * 1024.0 * 1024.0,
                downloaded,
                total_size,
                peers,
                seeders,
            });
        }
        collected
    });

    results
}

/// Get torrent download stats for debugging
/// Returns stats for currently active torrents
pub async fn get_all_torrents_info() -> String {
    let stats = get_torrent_stats().await;
    format_torrent_stats(&stats)
}

/// Stop and remove a torrent by info hash
pub async fn stop_torrent(info_hash: String, delete_files: bool) -> bool {
    let session = match get_session().await {
        Ok(s) => s,
        Err(_) => return false,
    };
    let info_hash_lower = info_hash.to_lowercase();

    // Find the torrent ID by info hash
    let torrent_id = session.with_torrents(|torrents| {
        for (id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                return Some(id);
            }
        }
        None
    });

    if let Some(id) = torrent_id {
        match session.delete(TorrentIdOrHash::Id(id), delete_files).await {
            Ok(_) => {
                log::info!(
                    "Successfully stopped torrent: {} (delete_files: {})",
                    info_hash,
                    delete_files
                );
                true
            }
            Err(e) => {
                log::error!("Failed to stop torrent {}: {}", info_hash, e);
                false
            }
        }
    } else {
        log::warn!("Torrent not found: {}", info_hash);
        false
    }
}

/// Pause a torrent by info hash
pub async fn pause_torrent(info_hash: String) -> bool {
    let session = match get_session().await {
        Ok(s) => s,
        Err(_) => return false,
    };
    let info_hash_lower = info_hash.to_lowercase();

    let handle = session.with_torrents(|torrents| {
        for (_id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                return Some(handle.clone());
            }
        }
        None
    });

    if let Some(handle) = handle {
        if handle.is_paused() {
            log::info!("Torrent already paused: {}", info_hash);
            return true;
        }

        match session.pause(&handle).await {
            Ok(_) => {
                log::info!("Successfully paused torrent: {}", info_hash);
                true
            }
            Err(e) => {
                log::error!("Failed to pause torrent {}: {}", info_hash, e);
                false
            }
        }
    } else {
        log::warn!("Torrent not found for pause: {}", info_hash);
        false
    }
}

/// Resume a paused torrent by info hash
pub async fn resume_torrent(info_hash: String) -> bool {
    let session = match get_session().await {
        Ok(s) => s,
        Err(_) => return false,
    };
    let info_hash_lower = info_hash.to_lowercase();

    let handle = session.with_torrents(|torrents| {
        for (_id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                return Some(handle.clone());
            }
        }
        None
    });

    if let Some(handle) = handle {
        if !handle.is_paused() {
            log::info!("Torrent is already running: {}", info_hash);
            return true;
        }

        match session.unpause(&handle).await {
            Ok(_) => {
                log::info!("Successfully resumed torrent: {}", info_hash);
                true
            }
            Err(e) => {
                log::error!("Failed to resume torrent {}: {}", info_hash, e);
                false
            }
        }
    } else {
        log::warn!("Torrent not found for resume: {}", info_hash);
        false
    }
}

// ============================================================================
// ECH (Encrypted Client Hello) for bangumi SNI cloaking
// ============================================================================

pub fn set_bangumi_use_ech(enabled: bool) {
    crate::api::config::set_bangumi_use_ech(enabled);
}

pub fn get_bangumi_use_ech() -> bool {
    crate::api::config::get_bangumi_use_ech()
}

/// Refresh the Cloudflare ECHConfig cache. Returns the byte length of the
/// newly-cached ECHConfigList, or 0 on failure.
pub async fn refresh_bangumi_ech_config() -> usize {
    match crate::api::ech::refresh_bangumi_ech_config().await {
        Ok(n) => n,
        Err(e) => {
            log::warn!("refresh_bangumi_ech_config failed: {e}");
            0
        }
    }
}

/// Warm up the ECHConfig cache if ECH is enabled and we don't have a fresh one.
/// Safe to call from `main()` at startup. Errors are swallowed: the HTTP layer
/// falls back to plaintext SNI when no ECHConfig is available.
pub async fn warmup_bangumi_ech_config() {
    if !crate::api::config::get_bangumi_use_ech() {
        return;
    }
    if let Err(e) = crate::api::ech::ensure_fresh_ech_config().await {
        log::warn!("ECHConfig warmup failed (will fall back to plain SNI): {e}");
    }
}

/// Return the user-configured DoH endpoint list (first = highest priority).
/// Empty means "use compiled-in defaults from `crate::api::ech`".
pub fn get_bangumi_doh_endpoints() -> Vec<String> {
    crate::api::config::get_bangumi_doh_endpoints()
}

/// Replace the user DoH list wholesale. Invalid entries are filtered out.
pub fn set_bangumi_doh_endpoints(endpoints: Vec<String>) -> Vec<String> {
    crate::api::config::set_bangumi_doh_endpoints(endpoints);
    crate::api::config::get_bangumi_doh_endpoints()
}

/// Append a DoH endpoint to the end of the user list. Returns the resulting
/// list. Rejects non-https URLs.
pub fn add_bangumi_doh_endpoint(endpoint: String) -> Vec<String> {
    crate::api::config::add_bangumi_doh_endpoint(endpoint);
    crate::api::config::get_bangumi_doh_endpoints()
}

/// Remove a DoH endpoint from the user list. Returns the resulting list.
pub fn remove_bangumi_doh_endpoint(endpoint: String) -> Vec<String> {
    crate::api::config::remove_bangumi_doh_endpoint(endpoint);
    crate::api::config::get_bangumi_doh_endpoints()
}

/// Reorder: move the entry at `from` to `to`. Returns the resulting list.
pub fn move_bangumi_doh_endpoint(from: usize, to: usize) -> Vec<String> {
    crate::api::config::move_bangumi_doh_endpoint(from, to)
}

/// Reset the user DoH list back to empty (= use compiled-in defaults).
pub fn reset_bangumi_doh_endpoints() -> Vec<String> {
    crate::api::config::reset_bangumi_doh_endpoints();
    crate::api::config::get_bangumi_doh_endpoints()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greet_preserves_unicode_input() {
        assert_eq!(greet("测试用户 ✨".to_string()), "Hello, 测试用户 ✨!");
    }

    #[test]
    fn text_preview_truncates_by_character_boundary() {
        let input = "磁".repeat(201);
        let preview = text_preview(&input, 200);

        assert_eq!(preview.chars().count(), 203);
        assert!(preview.ends_with("..."));
        assert_eq!(text_preview("短文本", 200), "短文本");
        assert_eq!(text_preview("", 0), "");
    }

    #[test]
    fn tracker_injection_adds_only_missing_defaults() {
        let existing = DEFAULT_TRACKERS[0];
        let magnet = format!("magnet:?xt=urn:btih:fixture{existing}");

        let (updated, added) = inject_default_trackers(magnet);

        assert_eq!(added, DEFAULT_TRACKERS.len() - 1);
        assert_eq!(updated.matches(existing).count(), 1);
        for tracker in DEFAULT_TRACKERS {
            assert!(updated.contains(tracker));
        }
    }

    #[tokio::test]
    async fn empty_magnet_returns_stable_error_without_initializing_engine() {
        assert_eq!(
            start_torrent(" \t\n".to_string()).await,
            "Error: empty magnet link"
        );
    }

    #[test]
    fn progress_handles_zero_and_transient_overrun() {
        assert_eq!(calculate_progress(50, 100), 50.0);
        assert_eq!(calculate_progress(1, 0), 0.0);
        assert_eq!(calculate_progress(101, 100), 100.0);
    }

    #[test]
    fn state_normalization_is_stable_across_payloads_and_pause_override() {
        assert_eq!(normalize_torrent_state("Live", false), "live");
        assert_eq!(
            normalize_torrent_state("Initializing(SomeMetadata)", false),
            "initializing"
        );
        assert_eq!(normalize_torrent_state("Error(boom)", false), "error");
        assert_eq!(normalize_torrent_state("FutureState", false), "futurestate");
        assert_eq!(normalize_torrent_state("Live", true), "paused");
    }

    #[test]
    fn torrent_stats_formatter_handles_empty_and_unicode_rows() {
        assert_eq!(format_torrent_stats(&[]), "No active torrents");
        let stats = vec![TorrentStats {
            info_hash: "fixture".to_string(),
            name: "Unicode 动画 ✨".to_string(),
            state: "live".to_string(),
            progress: 12.34,
            download_speed: 2.5 * 1024.0 * 1024.0,
            upload_speed: 0.0,
            downloaded: 123,
            total_size: 1000,
            peers: 7,
            seeders: 3,
        }];

        assert_eq!(
            format_torrent_stats(&stats),
            "Active Torrents:\n- Unicode 动画 ✨ (12.3%): 2.50 MB/s down, 7 peers\n"
        );
    }
}
