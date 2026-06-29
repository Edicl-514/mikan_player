use chrono::Datelike;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use serde_json;
use std::collections::HashSet;
use std::path::Path;
use std::time::Duration;

const QUARTER_NAMES: [&str; 4] = ["1月", "4月", "7月", "10月"];
const CST_OFFSET: chrono::FixedOffset = chrono::FixedOffset::east_opt(8 * 3600).unwrap();

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeInfo {
    pub title: String,
    pub sub_title: Option<String>,
    pub bangumi_id: Option<String>,
    pub mikan_id: Option<String>,
    pub cover_url: Option<String>,
    pub site_url: Option<String>,
    pub broadcast_day: Option<String>,
    pub broadcast_time: Option<String>,
    pub score: Option<f64>,
    pub rank: Option<i32>,
    pub tags: Vec<String>,
    pub full_json: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchiveQuarter {
    pub year: String,
    pub quarter: String,
    pub title: String,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
struct SeasonListResponse {
    #[allow(dead_code)]
    version: u64,
    items: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
struct ArchiveResponse {
    items: Vec<BgmlistItem>,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
#[flutter_rust_bridge::frb(ignore)]
struct BgmlistItem {
    title: String,
    #[serde(rename = "titleTranslate", default)]
    title_translate: BgmlistTitleTranslate,
    #[serde(rename = "type", default)]
    item_type: String,
    #[serde(rename = "officialSite", default)]
    official_site: String,
    begin: String,
    #[serde(default)]
    broadcast: String,
    #[serde(default)]
    sites: Vec<BgmlistSite>,
    #[serde(default)]
    id: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Default)]
#[flutter_rust_bridge::frb(ignore)]
struct BgmlistTitleTranslate {
    #[serde(rename = "zh-Hans", default)]
    zh_hans: Vec<String>,
    #[serde(rename = "zh-Hant", default)]
    zh_hant: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
#[flutter_rust_bridge::frb(ignore)]
struct BgmlistSite {
    site: String,
    id: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    begin: String,
    #[serde(default)]
    broadcast: String,
    #[serde(default)]
    comment: String,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
struct BangumiDataJson {
    #[serde(default)]
    items: Vec<BgmlistItem>,
}

impl Default for BgmlistItem {
    fn default() -> Self {
        Self {
            title: String::new(),
            title_translate: BgmlistTitleTranslate::default(),
            item_type: String::new(),
            official_site: String::new(),
            begin: String::new(),
            broadcast: String::new(),
            sites: Vec::new(),
            id: None,
        }
    }
}

/// Parse a `begin` timestamp as a UTC instant. Accepts both the ISO-8601 form
/// returned by the bgmlist.com API (`2025-09-30T16:35:00.000Z`, with or without
/// the trailing `Z`) and the legacy `YYYY/M/D H:mm:ss` form stored by the npm
/// `bangumi-data` package. Both forms denote a UTC instant.
fn parse_begin_utc(begin: &str) -> Option<chrono::DateTime<chrono::Utc>> {
    let s = begin.trim();
    if s.is_empty() {
        return None;
    }
    // RFC3339 with explicit zone (API form).
    if let Ok(dt) = s.parse::<chrono::DateTime<chrono::Utc>>() {
        return Some(dt);
    }
    // ISO-8601 naive (no zone) — treat as UTC.
    for fmt in &["%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S"] {
        if let Ok(ndt) = chrono::NaiveDateTime::parse_from_str(s, fmt) {
            return Some(ndt.and_utc());
        }
    }
    // Legacy npm package form: "1962/12/31 16:00:00".
    if let Ok(ndt) = chrono::NaiveDateTime::parse_from_str(s, "%Y/%m/%d %H:%M:%S") {
        return Some(ndt.and_utc());
    }
    None
}

/// Derive the CST (+8) weekday name and `HH:MM` time from a UTC instant.
fn datetime_to_cst_day_time(dt: chrono::DateTime<chrono::Utc>) -> (Option<String>, Option<String>) {
    let cst = dt.with_timezone(&CST_OFFSET);
    let weekday = match cst.weekday().num_days_from_monday() {
        0 => "周一",
        1 => "周二",
        2 => "周三",
        3 => "周四",
        4 => "周五",
        5 => "周六",
        6 => "周日",
        _ => "",
    };
    let time = cst.format("%H:%M").to_string();
    (
        if weekday.is_empty() {
            None
        } else {
            Some(weekday.to_string())
        },
        Some(time),
    )
}

fn parse_broadcast_from_rfc(broadcast: &str) -> (Option<String>, Option<String>) {
    if broadcast.is_empty() {
        return (None, None);
    }
    // bgmlist `broadcast` is `R/<ISO>/P7D`; the first segment is the start
    // instant. Fall through to `parse_begin_utc` so a bare timestamp (no `R/`
    // prefix) — including the legacy `begin` form — also parses.
    let instant_str = if let Some(rest) = broadcast.strip_prefix("R/") {
        rest.split('/').next().unwrap_or(rest)
    } else {
        broadcast
    };
    match parse_begin_utc(instant_str) {
        Some(dt) => datetime_to_cst_day_time(dt),
        None => (None, None),
    }
}

fn bgmlist_item_to_anime_info(item: &BgmlistItem) -> Option<AnimeInfo> {
    if item.title.is_empty() {
        return None;
    }
    let zh_title = item
        .title_translate
        .zh_hans
        .first()
        .cloned()
        .or_else(|| item.title_translate.zh_hant.first().cloned())
        .unwrap_or_default();
    let (title, sub_title) = if zh_title.is_empty() {
        (item.title.clone(), None)
    } else {
        (zh_title, Some(item.title.clone()))
    };
    let (broadcast_day, broadcast_time) = if item.broadcast.is_empty() {
        parse_broadcast_from_rfc(&item.begin)
    } else {
        parse_broadcast_from_rfc(&item.broadcast)
    };
    let mut bangumi_id = None;
    let mut mikan_id = None;
    for site in &item.sites {
        match site.site.as_str() {
            "bangumi" => bangumi_id = Some(site.id.clone()),
            "mikan" => mikan_id = Some(site.id.clone()),
            _ => {}
        }
    }
    let site_url = if item.official_site.is_empty() {
        None
    } else {
        Some(item.official_site.clone())
    };
    Some(AnimeInfo {
        title,
        sub_title,
        bangumi_id,
        mikan_id,
        cover_url: None,
        site_url,
        broadcast_day,
        broadcast_time,
        score: None,
        rank: None,
        tags: Vec::new(),
        full_json: None,
    })
}

fn quarter_to_title(quarter: &str) -> String {
    let re = regex::Regex::new(r"^(\d{4})q([1-4])$").unwrap();
    if let Some(caps) = re.captures(quarter) {
        let year = caps.get(1).unwrap().as_str();
        let q_num: usize = caps.get(2).unwrap().as_str().parse().unwrap_or(0);
        if q_num >= 1 && q_num <= 4 {
            return format!("{}年{}", year, QUARTER_NAMES[q_num - 1]);
        }
    }
    quarter.to_string()
}

fn is_legacy_mode() -> bool {
    crate::api::config::get_bangumi_request_mode() == "legacy"
}

pub async fn fetch_archive_list() -> anyhow::Result<Vec<ArchiveQuarter>> {
    if is_legacy_mode() {
        fetch_archive_list_html().await
    } else {
        fetch_archive_list_api().await
    }
}

async fn fetch_archive_list_api() -> anyhow::Result<Vec<ArchiveQuarter>> {
    let url = format!(
        "{}/bangumi/season",
        crate::api::config::get_bgmlist_api_url()
    );
    let resp = crate::api::network::retry_request("fetch_archive_list_api", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    let data: SeasonListResponse = resp.json().await?;
    let mut archives: Vec<ArchiveQuarter> = data
        .items
        .into_iter()
        .filter_map(|s| {
            let re = regex::Regex::new(r"^(\d{4})q(\d)$").ok()?;
            let caps = re.captures(&s)?;
            let year = caps.get(1)?.as_str().to_string();
            let _q = caps.get(2)?.as_str().to_string();
            let title = quarter_to_title(&s);
            Some(ArchiveQuarter {
                year,
                quarter: s,
                title,
            })
        })
        .collect();

    archives.sort_by(|a, b| b.quarter.cmp(&a.quarter));

    Ok(archives)
}

async fn fetch_archive_list_html() -> anyhow::Result<Vec<ArchiveQuarter>> {
    let url = format!("{}/archive", crate::api::config::get_bgmlist_url());
    let resp_text =
        crate::api::network::retry_request("fetch_archive_list", |client| client.get(&url))
            .await?
            .text()
            .await?;
    let document = Html::parse_document(&resp_text);

    let mut archives = Vec::new();
    let selector = Selector::parse("h3, a").unwrap();

    let mut current_year = String::new();

    for element in document.select(&selector) {
        if element.value().name() == "h3" {
            current_year = element
                .text()
                .collect::<String>()
                .replace("年", "")
                .trim()
                .to_string();
        } else if element.value().name() == "a" {
            let href = element.value().attr("href").unwrap_or("");
            if href.contains("/archive/") && !href.ends_with("/archive") {
                let title = element.text().collect::<String>();
                let quarter = href.split('/').last().unwrap_or("").to_string();

                if !current_year.is_empty() {
                    archives.push(ArchiveQuarter {
                        year: current_year.clone(),
                        quarter,
                        title,
                    });
                }
            }
        }
    }

    archives.sort_by(|a, b| b.quarter.cmp(&a.quarter));

    Ok(archives)
}

pub async fn fetch_schedule_basic(year_quarter: String) -> anyhow::Result<Vec<AnimeInfo>> {
    if is_legacy_mode() {
        fetch_schedule_basic_html(year_quarter).await
    } else {
        fetch_schedule_basic_api(&year_quarter).await
    }
}

async fn fetch_schedule_basic_api(year_quarter: &str) -> anyhow::Result<Vec<AnimeInfo>> {
    let url = format!(
        "{}/bangumi/archive/{}",
        crate::api::config::get_bgmlist_api_url(),
        year_quarter
    );
    let result = fetch_schedule_basic_api_from_url(&url).await;
    match result {
        Ok(animes) if !animes.is_empty() => return Ok(animes),
        Ok(_) => {
            log::info!(
                "bgmlist API returned 0 items for {}, trying data.json fallback",
                year_quarter
            );
        }
        Err(e) => {
            log::warn!(
                "bgmlist API failed for {}: {}, trying data.json fallback",
                year_quarter,
                e
            );
        }
    }
    fetch_schedule_basic_from_local_data_json(year_quarter).await
}

async fn fetch_schedule_basic_api_from_url(url: &str) -> anyhow::Result<Vec<AnimeInfo>> {
    let resp = crate::api::network::retry_request(
        "fetch_schedule_basic_api",
        |client| client.get(url).header("accept", "application/json"),
    )
    .await?;

    let data: ArchiveResponse = resp.json().await?;
    let animes = data
        .items
        .iter()
        .filter_map(bgmlist_item_to_anime_info)
        .collect();

    Ok(animes)
}

async fn fetch_schedule_basic_from_local_data_json(
    year_quarter: &str,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");

    if !local_path.exists() {
        let _ = download_bangumi_data_json(&local_path).await;
    }

    if local_path.exists() {
        match load_data_json_and_filter(&local_path, year_quarter) {
            Ok(animes) if !animes.is_empty() => return Ok(animes),
            Ok(_) => log::info!("data.json had 0 items for {}", year_quarter),
            Err(e) => {
                // The cached file is corrupt or tampered (mtime OK, hash wrong,
                // JSON malformed). Treat it like the file is missing — try one
                // fresh download so a stale / partial-payload cache doesn't
                // silently shadow a working API path.
                log::warn!(
                    "Local data.json was unusable ({}); re-downloading",
                    e
                );
                let _ = download_bangumi_data_json(&local_path).await;
                if local_path.exists() {
                    if let Ok(animes) = load_data_json_and_filter(&local_path, year_quarter) {
                        if !animes.is_empty() {
                            return Ok(animes);
                        }
                    }
                }
            }
        }
    }

    Ok(vec![])
}

/// Sidecar file that records the last (Unix-epoch-second) failed warmup
/// attempt. Holding this on disk means a transient CDN hiccup doesn't trap
/// the user on a stale cache for the full 7-day TTL: as soon as more than
/// `BANGUMI_DATA_RETRY_AFTER_SECS` has passed since the last failure, the
/// next warmup will retry.
fn bangumi_data_failure_marker_path(cache_dir: &str) -> std::path::PathBuf {
    std::path::Path::new(cache_dir).join("bangumi-data.failed-at")
}

fn write_failure_marker(cache_dir: &str) {
    let path = bangumi_data_failure_marker_path(cache_dir);
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(epoch) = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) {
        let _ = std::fs::write(&path, epoch.as_secs().to_string());
    }
}

fn clear_failure_marker(cache_dir: &str) {
    let _ = std::fs::remove_file(bangumi_data_failure_marker_path(cache_dir));
}

fn last_failure_age_secs(cache_dir: &str) -> Option<u64> {
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
const BANGUMI_DATA_RETRY_AFTER_SECS: u64 = 60 * 60;

/// Validate the downloaded payload is well-formed JSON with an `items` array.
///
/// Since we float on `@0.3` (resolved to the latest patch by the CDN) there
/// is no single pinned SHA-512 to check against. Structural validation
/// catches truncated responses, CDN error pages, and other malformed
/// payloads while allowing the version to advance automatically.
fn verify_bangumi_data_payload(bytes: &[u8]) -> anyhow::Result<()> {
    let value: serde_json::Value = serde_json::from_slice(bytes).map_err(|e| {
        anyhow::anyhow!("bangumi-data payload is not valid JSON: {}", e)
    })?;
    if !value.get("items").map_or(false, |v| v.is_array()) {
        anyhow::bail!(
            "bangumi-data payload JSON is missing a top-level \"items\" array"
        );
    }
    Ok(())
}

async fn download_bangumi_data_json(path: &Path) -> anyhow::Result<()> {
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
        }

        // Atomic write: stage to "<name>.tmp" in the same directory, fsync,
        // then rename. A crash mid-write leaves the previous (good) cache in
        // place; a successful rename replaces it in one syscall.
        if let Err(e) = atomic_write_bytes(path, &bytes) {
            log::warn!("bangumi-data atomic write failed: {}", e);
            last_err = Some(e);
            continue;
        }

        log::info!(
            "bangumi-data downloaded from {} ({} bytes, ok)",
            url,
            bytes.len()
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
fn atomic_write_bytes(path: &Path, bytes: &[u8]) -> anyhow::Result<()> {
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
fn replace_atomic(src: &Path, dst: &Path) -> anyhow::Result<()> {
    std::fs::rename(src, dst)?;
    Ok(())
}

#[cfg(windows)]
fn replace_atomic(src: &Path, dst: &Path) -> anyhow::Result<()> {
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

fn load_data_json_and_filter(
    path: &Path,
    year_quarter: &str,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let file = std::fs::File::open(path)?;
    let data: BangumiDataJson = serde_json::from_reader(file)?;
    let items = filter_items_by_quarter(&data.items, year_quarter);
    Ok(items.iter().map(|item| bgmlist_item_to_anime_info(item)).filter_map(|opt| opt).collect())
}

fn filter_items_by_quarter<'a>(items: &'a [BgmlistItem], year_quarter: &str) -> Vec<&'a BgmlistItem> {
    let re = regex::Regex::new(r"^(\d{4})q([1-4])$").unwrap();
    let caps = match re.captures(year_quarter) {
        Some(c) => c,
        None => return Vec::new(),
    };
    let year: i32 = caps.get(1).unwrap().as_str().parse().unwrap_or(0);
    let q: u32 = caps.get(2).unwrap().as_str().parse().unwrap_or(0);
    let (start_month, end_month) = match q {
        1 => (1, 3),
        2 => (4, 6),
        3 => (7, 9),
        4 => (10, 12),
        _ => return Vec::new(),
    };

    items
        .iter()
        .filter(|item| {
            // Parse the UTC instant (ISO or legacy form) then convert to CST
            // (+8) before comparing the month, so a show whose UTC begin falls
            // on the last day of a quarter still groups with the next quarter
            // exactly like the bgmlist.com API does.
            let Some(dt) = parse_begin_utc(&item.begin) else {
                return false;
            };
            let cst = dt.with_timezone(&CST_OFFSET);
            cst.year() == year && cst.month() >= start_month && cst.month() <= end_month
        })
        .collect()
}

async fn fetch_schedule_basic_html(year_quarter: String) -> anyhow::Result<Vec<AnimeInfo>> {
    let url = format!(
        "{}/archive/{}",
        crate::api::config::get_bgmlist_url(),
        year_quarter
    );
    let resp_text =
        crate::api::network::retry_request("fetch_schedule_basic", |client| client.get(&url))
            .await?
            .text()
            .await?;
    let mut animes = Vec::new();

    {
        let document = Html::parse_document(&resp_text);

        let root_selector = Selector::parse("[class*=\"BangumiItem_root__\"]").unwrap();
        let title_selector = Selector::parse("[class*=\"BangumiItem_title__\"]").unwrap();
        let sub_title_selector = Selector::parse("[class*=\"BangumiItem_subTitle__\"]").unwrap();
        let time_selector = Selector::parse("[class*=\"BangumiItem_jpTime__\"] dd").unwrap();
        let modern_time_selector =
            Selector::parse("[class*=\"BangumiItem_datetime__\"] span").unwrap();
        let link_selector = Selector::parse("a").unwrap();

        for root in document.select(&root_selector) {
            let title = root
                .select(&title_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string())
                .unwrap_or_default();

            if title.is_empty() {
                continue;
            }

            let sub_title = root
                .select(&sub_title_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string());

            let time_str = root
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string());

            let time_str = time_str.or_else(|| {
                root.select(&modern_time_selector)
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .find(|text| text.contains('周') || text.contains(':'))
            });

            let (broadcast_day, broadcast_time) = parse_broadcast_parts(time_str.as_deref());

            let mut anime = AnimeInfo {
                title,
                sub_title,
                bangumi_id: None,
                mikan_id: None,
                cover_url: None,
                site_url: None,
                broadcast_day,
                broadcast_time,
                score: None,
                rank: None,
                tags: Vec::new(),
                full_json: None,
            };

            for link in root.select(&link_selector) {
                let href = link.value().attr("href").unwrap_or("");
                let text = link.text().collect::<String>();

                if href.contains("bangumi.tv/subject/") || href.contains("bgm.tv/subject/") {
                    let id = href.split('/').last().unwrap_or("").to_string();
                    anime.bangumi_id = Some(id);
                } else if href.contains("mikanani.me/Home/Bangumi/")
                    || href.contains("mikanani.kas.pub/Home/Bangumi/")
                {
                    let id = href.split('/').last().unwrap_or("").to_string();
                    anime.mikan_id = Some(id);
                } else if text.contains("官网") || text.contains("官方网站") {
                    anime.site_url = Some(href.to_string());
                }
            }
            animes.push(anime);
        }
    }

    Ok(animes)
}

fn parse_broadcast_parts(raw: Option<&str>) -> (Option<String>, Option<String>) {
    let Some(raw) = raw.map(str::trim).filter(|value| !value.is_empty()) else {
        return (None, None);
    };

    let normalized = raw.replace("每周", "周");
    let mut broadcast_day = None;
    let mut broadcast_time = None;

    for part in normalized.split_whitespace() {
        if part.starts_with('周') {
            broadcast_day = Some(part.to_string());
        } else if part.contains(':') {
            broadcast_time = Some(part.to_string());
        }
    }

    if broadcast_day.is_none() && broadcast_time.is_none() {
        if normalized.contains(':') {
            broadcast_time = Some(normalized);
        } else {
            broadcast_day = Some(normalized);
        }
    }

    (broadcast_day, broadcast_time)
}

pub async fn fill_anime_details(animes: Vec<AnimeInfo>) -> anyhow::Result<Vec<AnimeInfo>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    let mut results = animes;

    let graphql_details = match mode.as_str() {
        "legacy" => std::collections::HashMap::new(),
        "hybrid" | "modern" | _ => {
            let mut seen_ids = HashSet::new();
            let ids: Vec<i64> = results
                .iter()
                .filter_map(|anime| anime.bangumi_id.as_deref())
                .filter_map(|id| id.parse::<i64>().ok())
                .filter(|id| seen_ids.insert(*id))
                .collect();

            log::info!(
                "fill_anime_details strategy=graphql_then_rest mode={} batch_size={}",
                mode,
                ids.len()
            );
            crate::api::bangumi_graphql::fetch_subject_details_graphql_batch(&ids).await
        }
    };

    let is_modern = mode == "modern";
    let mut fallback_tasks: Vec<
        tokio::task::JoinHandle<anyhow::Result<(usize, serde_json::Value)>>,
    > = Vec::new();

    for (index, anime) in results.iter_mut().enumerate() {
        let Some(id) = anime.bangumi_id.clone() else {
            continue;
        };

        let used_graphql = id
            .parse::<i64>()
            .ok()
            .and_then(|parsed_id| graphql_details.get(&parsed_id))
            .map(|json| {
                apply_subject_details(anime, json);
            })
            .is_some();

        if !used_graphql {
            if is_modern {
                fallback_tasks.push(tokio::spawn(async move {
                    let p1_json =
                        fetch_subject_details_next_p1_json(id.parse::<i64>().unwrap_or(0)).await?;
                    Ok((index, normalize_next_subject_json(&p1_json)))
                }));
            } else {
                fallback_tasks.push(tokio::spawn(async move {
                    let json = fetch_subject_details_rest_json(&id).await?;
                    Ok((index, json))
                }));
            }
        }
    }

    for task in fallback_tasks {
        match task.await {
            Ok(Ok((index, json))) => {
                if let Some(anime) = results.get_mut(index) {
                    apply_subject_details(anime, &json);
                }
            }
            Ok(Err(err)) => {
                log::warn!("fill_anime_details fallback task failed: {}", err);
            }
            Err(err) => {
                log::warn!("fill_anime_details fallback task join error: {}", err);
            }
        }
    }

    Ok(results)
}

async fn fetch_subject_details_rest_json(id: &str) -> anyhow::Result<serde_json::Value> {
    let api_url = format!(
        "{}/v0/subjects/{}",
        crate::api::config::get_bangumi_api_url(),
        id
    );
    let label = format!("fill_anime_details.subject.{}", id);
    let resp = crate::api::network::retry_request_bangumi(&label, |client| {
        client.get(&api_url).header("accept", "application/json")
    })
    .await?;

    Ok(resp.json::<serde_json::Value>().await?)
}

async fn fetch_subject_details_next_p1_json(id: i64) -> anyhow::Result<serde_json::Value> {
    let url = format!(
        "{}/p1/subjects/{}",
        crate::api::config::get_bangumi_next_url(),
        id
    );
    let label = format!("fetch_subject_details_next_p1.subject.{}", id);
    let resp = crate::api::network::retry_request_bangumi(&label, |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        anyhow::bail!(
            "p1 subject request failed for id={} status={}",
            id,
            resp.status()
        );
    }

    Ok(resp.json::<serde_json::Value>().await?)
}

fn normalize_next_subject_json(subject: &serde_json::Value) -> serde_json::Value {
    let mut normalized = subject.as_object().cloned().unwrap_or_default();

    if let Some(name_cn) = normalized.get("nameCN").and_then(|v| v.as_str()) {
        normalized.insert("name_cn".to_string(), serde_json::json!(name_cn));
    }

    if let Some(meta_tags) = normalized.get("metaTags").and_then(|v| v.as_array()) {
        normalized.insert("meta_tags".to_string(), serde_json::json!(meta_tags));
    }

    if let Some(infobox_items) = normalized.get("infobox").and_then(|v| v.as_array()) {
        let normalized_infobox: Vec<serde_json::Value> = infobox_items
            .iter()
            .map(|item| {
                let mut normalized_item = item.as_object().cloned().unwrap_or_default();

                if normalized_item.get("value").is_none() {
                    if let Some(values) = normalized_item.get("values").cloned() {
                        normalized_item.insert("value".to_string(), values);
                    }
                }

                serde_json::Value::Object(normalized_item)
            })
            .collect();

        normalized.insert("infobox".to_string(), serde_json::json!(normalized_infobox));
    }

    let airtime_date = normalized
        .get("airtime")
        .and_then(|v| v.get("date"))
        .cloned()
        .unwrap_or(serde_json::Value::Null);
    normalized.insert("date".to_string(), airtime_date);

    if let Some(collection) = normalized.get("collection").and_then(|v| v.as_object()) {
        let mut normalized_collection = serde_json::Map::new();
        let mapping = [
            ("1", "wish"),
            ("2", "collect"),
            ("3", "doing"),
            ("4", "on_hold"),
            ("5", "dropped"),
        ];
        for (num_key, name_key) in mapping {
            if let Some(count) = collection.get(num_key).and_then(|v| v.as_i64()) {
                normalized_collection.insert(name_key.to_string(), serde_json::json!(count));
            }
        }
        normalized.insert(
            "collection".to_string(),
            serde_json::Value::Object(normalized_collection),
        );
    }

    if let Some(images) = normalized.get_mut("images").and_then(|v| v.as_object_mut()) {
        if let Some(value) = images.get("large").and_then(|v| v.as_str()) {
            let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
            if rewritten != value {
                images.insert("large".to_string(), serde_json::Value::String(rewritten));
            }
        }
        if let Some(value) = images.get("common").and_then(|v| v.as_str()) {
            let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
            if rewritten != value {
                images.insert("common".to_string(), serde_json::Value::String(rewritten));
            }
        }
        if images.get("large").is_none() {
            images.insert(
                "large".to_string(),
                serde_json::Value::String(String::new()),
            );
        }
        if images.get("common").is_none() {
            images.insert(
                "common".to_string(),
                serde_json::Value::String(String::new()),
            );
        }
    }

    if let Some(rating) = normalized.get_mut("rating").and_then(|v| v.as_object_mut()) {
        if let Some(score_str) = rating.get("score").and_then(|v| v.as_str()) {
            if let Ok(score) = score_str.parse::<f64>() {
                rating.insert("score".to_string(), serde_json::json!(score));
            }
        }
    }

    let total_episodes = normalized
        .get("eps")
        .cloned()
        .unwrap_or(serde_json::Value::Null);
    normalized.insert("total_episodes".to_string(), total_episodes);

    serde_json::Value::Object(normalized)
}

fn apply_subject_details(anime: &mut AnimeInfo, json: &serde_json::Value) {
    let image_url = json["images"]["large"]
        .as_str()
        .filter(|url| !url.is_empty())
        .or_else(|| {
            json["images"]["common"]
                .as_str()
                .filter(|url| !url.is_empty())
        });
    if let Some(image_url) = image_url {
        anime.cover_url = Some(crate::api::config::rewrite_bangumi_url_if_proxied(image_url));
    }

    if let Some(score) = json["rating"]["score"].as_f64() {
        anime.score = Some(score);
    }
    if let Some(rank) = json["rating"]["rank"].as_i64() {
        anime.rank = Some(rank as i32);
    }

    let mut tags: Vec<String> = json["meta_tags"]
        .as_array()
        .map(|meta_tags| {
            meta_tags
                .iter()
                .filter_map(|tag| tag.as_str().map(|value| value.to_string()))
                .collect()
        })
        .unwrap_or_else(|| {
            json["tags"]
                .as_array()
                .map(|tags| {
                    tags.iter()
                        .filter_map(|tag| tag["name"].as_str().map(|value| value.to_string()))
                        .collect()
                })
                .unwrap_or_default()
        });
    tags.sort();
    tags.dedup();
    anime.tags = tags;
    anime.full_json = Some(json.to_string());
}

pub async fn fetch_light_subject_details(subject_id: i64) -> anyhow::Result<AnimeInfo> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::debug!(
        "fetch_light_subject_details mode={} subject_id={}",
        mode,
        subject_id
    );

    match mode.as_str() {
        "legacy" => {
            let json = fetch_subject_details_rest_json(&subject_id.to_string()).await?;
            Ok(build_light_subject_from_json(subject_id, &json))
        }
        "hybrid" => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed, falling back to REST: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => fetch_subject_details_rest_json(&subject_id.to_string()).await?,
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
        "modern" => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed for modern mode, falling back to p1: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => {
                    let p1_json = fetch_subject_details_next_p1_json(subject_id).await?;
                    normalize_next_subject_json(&p1_json)
                }
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
        _ => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed, falling back to REST: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => fetch_subject_details_rest_json(&subject_id.to_string()).await?,
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
    }
}

fn build_light_subject_from_json(subject_id: i64, json: &serde_json::Value) -> AnimeInfo {
    let title = json["name"].as_str().unwrap_or("").to_string();
    let sub_title = json["name_cn"].as_str().unwrap_or("").to_string();
    let cover_url = json["images"]["large"]
        .as_str()
        .filter(|url| !url.is_empty())
        .or_else(|| {
            json["images"]["common"]
                .as_str()
                .filter(|url| !url.is_empty())
        })
        .map(|url| crate::api::config::rewrite_bangumi_url_if_proxied(url));
    let score = json["rating"]["score"].as_f64();
    let rank = json["rating"]["rank"].as_i64().map(|value| value as i32);

    let mut tags: Vec<String> = json["meta_tags"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_else(|| {
            json["tags"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|tag| tag["name"].as_str().map(String::from))
                        .collect()
                })
                .unwrap_or_default()
        });
    tags.sort();
    tags.dedup();

    AnimeInfo {
        title,
        sub_title: if sub_title.is_empty() {
            None
        } else {
            Some(sub_title)
        },
        bangumi_id: Some(subject_id.to_string()),
        mikan_id: None,
        cover_url,
        site_url: None,
        broadcast_day: None,
        broadcast_time: None,
        score,
        rank,
        tags,
        full_json: Some(json.to_string()),
    }
}

pub async fn fetch_extra_subjects(
    year_quarter: String,
    existing_ids: Vec<String>,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let existing_set: HashSet<String> = existing_ids.into_iter().collect();

    fetch_extra_bangumi_subjects(&year_quarter, &existing_set).await
}

pub async fn refresh_bangumi_data_cache() -> anyhow::Result<bool> {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");
    download_bangumi_data_json(&local_path).await.map(|_| true)
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
pub async fn ensure_bangumi_data_cache(max_age_secs: u64) -> anyhow::Result<bool> {
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
        return Ok(false);
    }

    if local_path.exists() && recently_failed {
        log::info!(
            "bangumi-data warmup recently failed ({}s ago) and a stale cache exists; \
             skipping retry until cooldown elapses",
            last_failure_age_secs(&cache_dir).unwrap_or(0)
        );
        return Ok(false);
    }

    download_bangumi_data_json(&local_path).await.map(|_| true)
}

async fn fetch_extra_bangumi_subjects(
    year_quarter: &str,
    existing_ids: &HashSet<String>,
) -> anyhow::Result<Vec<AnimeInfo>> {
    // Parse year and quarter
    if year_quarter.len() < 6 {
        return Ok(vec![]);
    }
    let year_str = &year_quarter[..4];
    let q_str = &year_quarter[4..];
    let year: i32 = year_str.parse().unwrap_or(2025);

    // Determine date range (Next quarter start is exclusive bound)
    let (start_date, end_date) = match q_str {
        "q1" => (format!("{}-01-01", year), format!("{}-04-01", year)),
        "q2" => (format!("{}-04-01", year), format!("{}-07-01", year)),
        "q3" => (format!("{}-07-01", year), format!("{}-10-01", year)),
        "q4" => (format!("{}-10-01", year), format!("{}-01-01", year + 1)),
        _ => return Ok(vec![]),
    };

    let url = format!(
        "{}/v0/search/subjects",
        crate::api::config::get_bangumi_api_url()
    );

    // Initial request to get total
    // Using limit=1 to minimize load
    let body_json = serde_json::json!({
        "filter": {
            "type": [2],
            "air_date": [format!(">={}", start_date), format!("<{}", end_date)],
            "tag": ["日本"]
        }
    });

    let init_resp =
        match crate::api::network::retry_request_bangumi("fetch_extra_subjects.init", |client| {
            client
                .post(&url)
                .query(&[("limit", "1"), ("offset", "0")])
                .header("Content-Type", "application/json")
                .header("accept", "application/json")
                .json(&body_json)
        })
        .await
        {
            Ok(resp) => resp,
            Err(err) => {
                log::warn!("fetch_extra_subjects.init failed: {}", err);
                return Ok(vec![]);
            }
        };

    if !init_resp.status().is_success() {
        return Ok(vec![]);
    }

    let init_json: serde_json::Value = init_resp.json().await?;
    let total = init_json["total"].as_u64().unwrap_or(0);

    if total == 0 {
        return Ok(vec![]);
    }

    // Concurrent fetch logic
    let limit = 20;
    let num_pages = (total as f64 / limit as f64).ceil() as u64;
    let mut tasks = Vec::new();

    for i in 0..num_pages {
        let offset = i * limit;
        let body_c = body_json.clone();
        let page_url = url.clone();

        tasks.push(tokio::spawn(async move {
            let label = format!("fetch_extra_subjects.page.offset_{}", offset);
            match crate::api::network::retry_request_bangumi(&label, |client| {
                client
                    .post(&page_url)
                    .query(&[
                        ("limit", &limit.to_string()),
                        ("offset", &offset.to_string()),
                    ])
                    .header("Content-Type", "application/json")
                    .header("accept", "application/json")
                    .json(&body_c)
            })
            .await
            {
                Ok(resp) => resp.json::<serde_json::Value>().await.ok(),
                Err(err) => {
                    log::warn!("{} failed: {}", label, err);
                    None
                }
            }
        }));
    }

    let mut new_animes = Vec::new();

    for task in tasks {
        if let Ok(Some(json)) = task.await {
            if let Some(data) = json["data"].as_array() {
                for item in data {
                    // Normalize ID for deduplication
                    let id_str = if let Some(n) = item["id"].as_u64() {
                        n.to_string()
                    } else if let Some(s) = item["id"].as_str() {
                        s.to_string()
                    } else {
                        continue;
                    };

                    if existing_ids.contains(&id_str) {
                        continue;
                    }

                    // Map to AnimeInfo
                    let name = item["name"].as_str().unwrap_or("");
                    let name_cn = item["name_cn"].as_str().unwrap_or("");
                    let title = if !name_cn.is_empty() {
                        name_cn.to_string()
                    } else {
                        name.to_string()
                    };

                    if title.is_empty() {
                        continue;
                    }

                    let date = item["date"].as_str().unwrap_or("").to_string();
                    let cover = item["images"]["large"]
                        .as_str()
                        .map(|s| crate::api::config::rewrite_bangumi_url_if_proxied(s));

                    let score = item["score"]
                        .as_f64()
                        .or_else(|| item["rating"]["score"].as_f64());

                    let rank = item["rank"]
                        .as_i64()
                        .or_else(|| item["rating"]["rank"].as_i64())
                        .map(|r| r as i32);

                    let anime = AnimeInfo {
                        title: title.clone(),
                        sub_title: if name_cn.is_empty() {
                            None
                        } else {
                            Some(name.to_string())
                        },
                        bangumi_id: Some(id_str.clone()),
                        mikan_id: None,
                        cover_url: cover,
                        site_url: None,
                        broadcast_day: None, // Will show in "Other"
                        broadcast_time: if date.is_empty() { None } else { Some(date) },
                        score,
                        rank,
                        tags: item["meta_tags"]
                            .as_array()
                            .map(|arr| {
                                arr.iter()
                                    .filter_map(|v| v.as_str().map(String::from))
                                    .collect()
                            })
                            .unwrap_or_default(),
                        full_json: Some(item.to_string()),
                    };

                    // Final check to avoid dupes within the search results themselves (unlikely with pagination but distinct IDs possible?)
                    // The set check above handles cross-list dupes.
                    // To handle within-list helper dupes (if any), we could maintain a local set, but pagination shouldn't overlap.

                    new_animes.push(anime);
                }
            }
        }
    }

    // Sort logic handled by caller? User said "Sort by date".
    // The UI currently sorts each group by `broadcast_time`.
    // Since we set `broadcast_time` to `date`, they will be sorted by date in the UI.

    Ok(new_animes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_broadcast_parts_supports_legacy_and_current_bgmlist_text() {
        assert_eq!(
            parse_broadcast_parts(Some("周一 00:00")),
            (Some("周一".to_string()), Some("00:00".to_string()))
        );
        assert_eq!(
            parse_broadcast_parts(Some("每周日 00:00")),
            (Some("周日".to_string()), Some("00:00".to_string()))
        );
    }

    #[test]
    fn parse_broadcast_from_rfc_parses_weekly_schedule() {
        let (day, time) = parse_broadcast_from_rfc("R/2026-04-04T16:00:00.000Z/P7D");
        assert_eq!(day, Some("周日".to_string()));
        assert_eq!(time, Some("00:00".to_string()));
    }

    #[test]
    fn parse_broadcast_from_rfc_handles_legacy_begin_without_r_prefix() {
        // npm bangumi-data `begin` form, no R/ prefix — must still parse as UTC.
        let (day, time) = parse_broadcast_from_rfc("1962/12/31 16:00:00");
        // 1962-12-31T16:00:00Z -> +8 = 1963-01-01 00:00 -> Tuesday.
        assert_eq!(day, Some("周二".to_string()));
        assert_eq!(time, Some("00:00".to_string()));
    }

    #[test]
    fn parse_begin_utc_supports_iso_and_legacy_forms() {
        assert!(parse_begin_utc("2025-09-30T16:35:00.000Z").is_some());
        assert!(parse_begin_utc("2025-09-30T16:35:00").is_some());
        assert!(parse_begin_utc("1962/12/31 16:00:00").is_some());
        assert!(parse_begin_utc("").is_none());
        assert!(parse_begin_utc("not a date").is_none());
    }

    #[test]
    fn parse_broadcast_from_rfc_empty_string() {
        assert_eq!(parse_broadcast_from_rfc(""), (None, None));
    }

    #[test]
    fn quarter_to_title_formats_correctly() {
        assert_eq!(quarter_to_title("2026q1"), "2026年1月");
        assert_eq!(quarter_to_title("2026q4"), "2026年10月");
    }

    #[test]
    fn bgmlist_item_to_anime_info_extracts_ids() {
        let item = BgmlistItem {
            title: "テストアニメ".to_string(),
            title_translate: BgmlistTitleTranslate {
                zh_hans: vec!["测试动画".to_string()],
                zh_hant: vec![],
            },
            item_type: "tv".to_string(),
            official_site: String::new(),
            begin: "2026-04-04T16:00:00.000Z".to_string(),
            broadcast: "R/2026-04-04T16:00:00.000Z/P7D".to_string(),
            sites: vec![
                BgmlistSite {
                    site: "bangumi".to_string(),
                    id: "505258".to_string(),
                    url: String::new(),
                    begin: String::new(),
                    broadcast: String::new(),
                    comment: String::new(),
                },
                BgmlistSite {
                    site: "mikan".to_string(),
                    id: "3886".to_string(),
                    url: String::new(),
                    begin: String::new(),
                    broadcast: String::new(),
                    comment: String::new(),
                },
            ],
            id: None,
        };
        let anime = bgmlist_item_to_anime_info(&item).unwrap();
        assert_eq!(anime.title, "测试动画");
        assert_eq!(anime.sub_title, Some("テストアニメ".to_string()));
        assert_eq!(anime.bangumi_id, Some("505258".to_string()));
        assert_eq!(anime.mikan_id, Some("3886".to_string()));
        assert_eq!(anime.broadcast_day, Some("周日".to_string()));
        assert_eq!(anime.broadcast_time, Some("00:00".to_string()));
    }

    #[test]
    fn bgmlist_item_to_anime_info_uses_legacy_begin_when_no_broadcast() {
        // Mirrors the npm bangumi-data row: legacy `begin`, empty `broadcast`.
        let item = BgmlistItem {
            title: "テスト".to_string(),
            title_translate: BgmlistTitleTranslate::default(),
            item_type: "tv".to_string(),
            official_site: String::new(),
            begin: "1962/12/31 16:00:00".to_string(),
            broadcast: String::new(),
            sites: vec![],
            id: None,
        };
        let anime = bgmlist_item_to_anime_info(&item).unwrap();
        // 16:00 UTC -> 00:00 CST next day.
        assert_eq!(anime.broadcast_day, Some("周二".to_string()));
        assert_eq!(anime.broadcast_time, Some("00:00".to_string()));
    }

    #[test]
    fn filter_items_by_quarter_works() {
        let items = vec![
            BgmlistItem {
                title: "A".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2026-04-04T16:00:00.000Z".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
            BgmlistItem {
                title: "B".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2026-01-04T16:00:00.000Z".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
        ];
        let filtered = filter_items_by_quarter(&items, "2026q2");
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].title, "A");
    }

    #[test]
    fn filter_items_by_quarter_handles_legacy_form_and_tz_boundary() {
        let items = vec![
            // Legacy npm form, late September UTC -> Oct 1 CST => belongs to q4.
            BgmlistItem {
                title: "boundary".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2025/9/30 16:35:00".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
            // Legacy form, solidly in October CST.
            BgmlistItem {
                title: "october".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2025/10/5 01:00:00".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
        ];
        let filtered = filter_items_by_quarter(&items, "2025q4");
        assert_eq!(filtered.len(), 2);
    }

    /// `verify_bangumi_data_payload` returns `Err` for payloads that are not
    /// valid JSON or are missing the top-level `items` array. Well-formed
    /// payloads (even with an empty `items` array) pass.
    #[test]
    fn verify_bangumi_data_payload_rejects_invalid_inputs() {
        assert!(verify_bangumi_data_payload(b"").is_err());
        assert!(verify_bangumi_data_payload(b"not json").is_err());
        assert!(verify_bangumi_data_payload(b"{}").is_err());
        assert!(verify_bangumi_data_payload(b"{\"items\":42}").is_err());
        // Valid structure: top-level object with an "items" array.
        assert!(verify_bangumi_data_payload(b"{\"items\":[]}").is_ok());
        assert!(verify_bangumi_data_payload(b"{\"items\":[{\"title\":\"A\"}]}").is_ok());
    }

    #[test]
    fn atomic_write_bytes_replaces_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("cache.json");
        std::fs::write(&path, b"old").unwrap();

        atomic_write_bytes(&path, b"new content").unwrap();

        let written = std::fs::read(&path).unwrap();
        assert_eq!(written, b"new content");
        // The .tmp staging file should not linger after a successful write.
        let leftovers: Vec<_> = std::fs::read_dir(dir.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_name().to_string_lossy().contains(".tmp."))
            .collect();
        assert!(
            leftovers.is_empty(),
            "tmp staging file should be cleaned up, found: {:?}",
            leftovers.iter().map(|e| e.path()).collect::<Vec<_>>()
        );
    }

    #[test]
    fn failure_marker_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let cache_dir = dir.path().to_string_lossy().to_string();
        // No marker yet.
        assert!(last_failure_age_secs(&cache_dir).is_none());

        write_failure_marker(&cache_dir);
        let age = last_failure_age_secs(&cache_dir).expect("age should be parseable");
        assert!(
            age < 5,
            "freshly written marker should report age < 5s, got {}",
            age
        );

        clear_failure_marker(&cache_dir);
        assert!(last_failure_age_secs(&cache_dir).is_none());
    }

    #[test]
    fn failure_marker_tolerates_garbage() {
        let dir = tempfile::tempdir().unwrap();
        let cache_dir = dir.path().to_string_lossy().to_string();
        std::fs::write(
            bangumi_data_failure_marker_path(&cache_dir),
            "not-an-epoch",
        )
        .unwrap();
        // Garbage in the marker must NOT cause a panic; the helper should
        // treat it as "unknown" (None) and let the retry proceed.
        assert!(last_failure_age_secs(&cache_dir).is_none());
    }
}
