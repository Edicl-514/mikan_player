use super::types::*;
use scraper::{Html, Selector};

use super::bangumi_data_store::download_bangumi_data_json_single_flight;
use super::bangumi_data_store::{
    bangumi_data_trace, get_or_load_bangumi_data_blocking, invalidate_bangumi_data_cache,
    load_data_json_and_filter,
};
use super::parse_time::*;
use super::sites_index::{invalidate_sites_index, spawn_build_sites_index_background};

pub(super) fn is_legacy_mode() -> bool {
    crate::api::config::get_bangumi_request_mode() == "legacy"
}

pub(crate) async fn fetch_archive_list() -> anyhow::Result<Vec<ArchiveQuarter>> {
    if is_legacy_mode() {
        fetch_archive_list_html().await
    } else {
        fetch_archive_list_api().await
    }
}

pub(super) async fn fetch_archive_list_api() -> anyhow::Result<Vec<ArchiveQuarter>> {
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

pub(super) async fn fetch_archive_list_html() -> anyhow::Result<Vec<ArchiveQuarter>> {
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

pub(crate) async fn fetch_schedule_basic(year_quarter: String) -> anyhow::Result<Vec<AnimeInfo>> {
    if is_legacy_mode() {
        fetch_schedule_basic_html(year_quarter).await
    } else {
        fetch_schedule_basic_api(&year_quarter).await
    }
}

/// API-only schedule fetch — no local-JSON fallback.
/// Returns the API result directly; caller decides how to handle
/// failure (e.g. a Dart-side racer can weight download/local separately).
pub(crate) async fn fetch_schedule_basic_api_only(
    year_quarter: String,
) -> anyhow::Result<Vec<AnimeInfo>> {
    if is_legacy_mode() {
        fetch_schedule_basic_html(year_quarter).await
    } else {
        fetch_schedule_basic_api_from_url(&format!(
            "{}/bangumi/archive/{}",
            crate::api::config::get_bgmlist_api_url(),
            year_quarter
        ))
        .await
    }
}

pub(super) async fn fetch_schedule_basic_api(year_quarter: &str) -> anyhow::Result<Vec<AnimeInfo>> {
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

pub(super) async fn fetch_schedule_basic_api_from_url(url: &str) -> anyhow::Result<Vec<AnimeInfo>> {
    let resp = crate::api::network::retry_request("fetch_schedule_basic_api", |client| {
        client.get(url).header("accept", "application/json")
    })
    .await?;

    let data: ArchiveResponse = resp.json().await?;
    let animes = data
        .items
        .iter()
        .filter_map(bgmlist_item_to_anime_info)
        .collect();

    Ok(animes)
}

pub(super) async fn fetch_schedule_basic_from_local_data_json(
    year_quarter: &str,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");

    // Download if missing; sites index rebuild is deferred to background.
    // force=false: if a concurrent download (warmup) produced the file
    // while we waited for the permit, skip the redundant fetch.
    if !local_path.exists() {
        let _ = download_bangumi_data_json_single_flight(&local_path, false).await;
        invalidate_bangumi_data_cache();
        invalidate_sites_index().await;
        spawn_build_sites_index_background();
    }

    // Primary parse — wrapped in spawn_blocking to avoid blocking a
    // Tokio worker on the cold mmap+serde_json path.
    let local_path_clone = local_path.clone();
    let year_quarter_owned = year_quarter.to_string();
    let parse_ok = tokio::task::spawn_blocking(move || -> (bool, Vec<AnimeInfo>) {
        if !local_path_clone.exists() {
            return (true, vec![]);
        }
        match get_or_load_bangumi_data_blocking() {
            Ok(data) => {
                let a = load_data_json_and_filter(&data, &year_quarter_owned);
                if !a.is_empty() {
                    return (true, a);
                }
                log::info!("data.json had 0 items for quarter");
                (true, vec![])
            }
            Err(e) => {
                log::warn!(
                    "Local data.json was unusable ({}); marking for re-download",
                    e
                );
                (false, vec![])
            }
        }
    })
    .await?;

    if parse_ok.0 {
        return Ok(parse_ok.1);
    }

    // get_or_load_bangumi_data_blocking failed — file is corrupt. Re-download.
    // force=true: the corrupt file already exists, so the skip-if-exists
    // shortcut must be bypassed to actually overwrite it.
    let _ = download_bangumi_data_json_single_flight(&local_path, true).await;
    invalidate_bangumi_data_cache();
    invalidate_sites_index().await;
    spawn_build_sites_index_background();

    let year_quarter_owned = year_quarter.to_string();
    let retry = tokio::task::spawn_blocking(move || -> Vec<AnimeInfo> {
        if !local_path.exists() {
            return vec![];
        }
        if let Ok(data) = get_or_load_bangumi_data_blocking() {
            let a = load_data_json_and_filter(&data, &year_quarter_owned);
            if !a.is_empty() {
                return a;
            }
        }
        vec![]
    })
    .await?;
    Ok(retry)
}

/// Public wrapper for `fetch_schedule_basic_from_local_data_json` so that the
/// Dart side can invoke the local-JSON path directly (instead of waiting for
/// the bgmlist API to fail first). Semantics are identical: if the cached file
/// is missing this function will attempt one download, and if the file is
/// corrupt it will re-download once before giving up.
pub(crate) async fn fetch_schedule_basic_from_local_json(
    year_quarter: String,
) -> anyhow::Result<Vec<AnimeInfo>> {
    fetch_schedule_basic_from_local_data_json(&year_quarter).await
}

/// Try to load the schedule from the local `bangumi-data.json` cache **without
/// downloading**. Returns `Ok(empty vec)` when the file is absent or contains
/// zero matches for the requested quarter — the caller can then decide to
/// start a background download or fall back to the API.
///
/// This is the "Level 2" path in the three-tier loading strategy:
///   1. SQLite timetable cache  (fastest, ~ms)
///   2. This function           (mmap read, ~22ms)
///   3. Concurrent API + download (slowest, seconds)
pub(crate) fn fetch_schedule_basic_from_local_json_nodl(
    year_quarter: String,
) -> anyhow::Result<Vec<AnimeInfo>> {
    bangumi_data_trace(&format!(
        "fetch_schedule_basic_from_local_json_nodl start quarter={year_quarter}"
    ));
    let data = get_or_load_bangumi_data_blocking()?;
    let result = load_data_json_and_filter(&data, &year_quarter);
    bangumi_data_trace(&format!(
        "fetch_schedule_basic_from_local_json_nodl done quarter={year_quarter} count={}",
        result.len()
    ));
    Ok(result)
}

pub(super) async fn fetch_schedule_basic_html(
    year_quarter: String,
) -> anyhow::Result<Vec<AnimeInfo>> {
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
