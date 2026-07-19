use super::types::*;
use scraper::{Html, Selector};
use std::collections::HashSet;

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

fn archive_quarter(value: &str, fallback_title: Option<&str>) -> Option<ArchiveQuarter> {
    let quarter = value.trim();
    let captures = regex::Regex::new(r"^(\d{4})q([1-4])$")
        .ok()?
        .captures(quarter)?;
    let year = captures.get(1)?.as_str().to_string();
    let title = fallback_title
        .map(str::trim)
        .filter(|title| !title.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| quarter_to_title(quarter));
    Some(ArchiveQuarter {
        year,
        quarter: quarter.to_string(),
        title,
    })
}

fn normalize_archive_quarters<I>(quarters: I) -> Vec<ArchiveQuarter>
where
    I: IntoIterator<Item = ArchiveQuarter>,
{
    let mut seen = HashSet::new();
    let mut archives: Vec<_> = quarters
        .into_iter()
        .filter(|archive| seen.insert(archive.quarter.clone()))
        .collect();
    archives.sort_by(|a, b| b.quarter.cmp(&a.quarter));
    archives
}

fn parse_archive_list_html_body(body: &str) -> Vec<ArchiveQuarter> {
    let document = Html::parse_document(body);
    let selector = Selector::parse("a[href]").unwrap();
    normalize_archive_quarters(document.select(&selector).filter_map(|element| {
        let href = element.value().attr("href")?;
        let path = url::Url::parse(href)
            .ok()
            .map(|url| url.path().to_string())
            .unwrap_or_else(|| href.split(['?', '#']).next().unwrap_or("").to_string());
        let parts: Vec<_> = path.split('/').filter(|part| !part.is_empty()).collect();
        let quarter = parts
            .windows(2)
            .find(|parts| parts[0] == "archive")
            .map(|parts| parts[1])?;
        let title = element.text().collect::<String>();
        archive_quarter(quarter, Some(&title))
    }))
}

fn resolve_http_url(base_url: &str, raw: &str) -> Option<String> {
    let raw = raw.trim();
    if raw.is_empty() {
        return None;
    }
    let url = url::Url::parse(raw)
        .or_else(|_| url::Url::parse(base_url)?.join(raw))
        .ok()?;
    matches!(url.scheme(), "http" | "https").then(|| url.to_string())
}

fn schedule_identity(anime: &AnimeInfo) -> String {
    if let Some(id) = anime.bangumi_id.as_deref() {
        return format!("bangumi:{id}");
    }
    if let Some(id) = anime.mikan_id.as_deref() {
        return format!("mikan:{id}");
    }
    format!(
        "title:{}\u{1f}{}",
        anime.title.trim().to_lowercase(),
        anime
            .sub_title
            .as_deref()
            .unwrap_or("")
            .trim()
            .to_lowercase()
    )
}

pub(super) fn normalize_schedule_items(
    items: &[BgmlistItem],
    response_url: Option<&str>,
) -> Vec<AnimeInfo> {
    let mut seen = HashSet::new();
    items
        .iter()
        .filter_map(bgmlist_item_to_anime_info)
        .map(|mut anime| {
            if let (Some(base_url), Some(site_url)) = (response_url, anime.site_url.as_deref()) {
                anime.site_url = resolve_http_url(base_url, site_url);
            }
            anime
        })
        .filter(|anime| seen.insert(schedule_identity(anime)))
        .collect()
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
    Ok(normalize_archive_quarters(
        data.items
            .into_iter()
            .filter_map(|quarter| archive_quarter(&quarter, None)),
    ))
}

pub(super) async fn fetch_archive_list_html() -> anyhow::Result<Vec<ArchiveQuarter>> {
    let url = format!("{}/archive", crate::api::config::get_bgmlist_url());
    let resp_text =
        crate::api::network::retry_request("fetch_archive_list", |client| client.get(&url))
            .await?
            .text()
            .await?;
    Ok(parse_archive_list_html_body(&resp_text))
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
    Ok(normalize_schedule_items(&data.items, Some(url)))
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
    let mut seen = HashSet::new();

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
                .map(|e| e.text().collect::<String>().trim().to_string())
                .filter(|title| !title.is_empty());

            let time_str = root
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string());

            let time_str = time_str.or_else(|| {
                let parts: Vec<String> = root
                    .select(&modern_time_selector)
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .filter(|text| text.contains('周') || text.contains(':'))
                    .collect();
                (!parts.is_empty()).then(|| parts.join(" "))
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
                let Some(resolved) = resolve_http_url(&url, href) else {
                    continue;
                };
                let Ok(parsed) = url::Url::parse(&resolved) else {
                    continue;
                };
                let host = parsed.host_str().unwrap_or("");
                let id = parsed
                    .path_segments()
                    .and_then(|mut segments| segments.rfind(|part| !part.is_empty()))
                    .filter(|id| id.parse::<i64>().ok().is_some_and(|value| value > 0))
                    .map(str::to_string);

                if matches!(host, "bangumi.tv" | "bgm.tv" | "chii.in")
                    && parsed.path().contains("/subject/")
                {
                    anime.bangumi_id = anime.bangumi_id.or(id);
                } else if matches!(host, "mikanani.me" | "mikanani.kas.pub")
                    && parsed.path().contains("/Home/Bangumi/")
                {
                    anime.mikan_id = anime.mikan_id.or(id);
                } else if text.contains("官网") || text.contains("官方网站") {
                    anime.site_url = Some(resolved);
                }
            }
            if seen.insert(schedule_identity(&anime)) {
                animes.push(anime);
            }
        }
    }

    Ok(animes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::Method;

    fn point_bgmlist_at(base_url: &str, mode: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bgmlist_url = base_url.to_string();
        config.bangumi_request_mode = mode.to_string();
    }

    #[test]
    fn archive_html_deduplicates_valid_quarters_without_requiring_year_heading() {
        let archives = parse_archive_list_html_body(
            r#"
              <a href="/archive/2025q2">2025 spring</a>
              <a href="/archive/2025q2?duplicate=1">duplicate</a>
              <a href="https://bgmlist.test/archive/2024q4"> </a>
              <a href="/archive/2025q9">invalid</a>
              <a>missing href</a>
            "#,
        );

        assert_eq!(archives.len(), 2);
        assert_eq!(archives[0].quarter, "2025q2");
        assert_eq!(archives[0].year, "2025");
        assert_eq!(archives[0].title, "2025 spring");
        assert_eq!(archives[1].quarter, "2024q4");
        assert_eq!(archives[1].title, "2024年10月");
    }

    #[tokio::test]
    async fn api_archive_and_schedule_skip_duplicates_missing_fields_and_bad_quarters() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/api/v1/bangumi/season",
                TestResponse::ok(r#"{"items":["2025q2","2025q2","2025q9","bad","2024q4"]}"#),
            ),
            TestRoute::get(
                "/api/v1/bangumi/archive/2025q2",
                TestResponse::ok(
                    r#"{
                      "items": [
                        {
                          "title": "First",
                          "begin": "2025-04-01T00:00:00Z",
                          "officialSite": "/official/first",
                          "sites": [{"site":"bangumi","id":"7"}]
                        },
                        {
                          "title": "Duplicate id",
                          "begin": "2025-04-02T00:00:00Z",
                          "sites": [{"site":"bangumi","id":"7"}]
                        },
                        {"begin": "2025-04-03T00:00:00Z"},
                        {"title": "No id", "begin": "2025-04-04T00:00:00Z"},
                        {"title": "No id", "begin": "2025-04-05T00:00:00Z"}
                      ]
                    }"#,
                ),
            ),
        ])
        .await;
        point_bgmlist_at(&server.base_url(), "modern");

        let archives = fetch_archive_list_api().await.unwrap();
        assert_eq!(
            archives
                .iter()
                .map(|item| item.quarter.as_str())
                .collect::<Vec<_>>(),
            ["2025q2", "2024q4"]
        );

        let schedule =
            fetch_schedule_basic_api_from_url(&server.url("/api/v1/bangumi/archive/2025q2"))
                .await
                .unwrap();
        assert_eq!(schedule.len(), 2);
        assert_eq!(schedule[0].title, "First");
        assert_eq!(schedule[0].bangumi_id.as_deref(), Some("7"));
        assert_eq!(
            schedule[0].site_url.as_deref(),
            Some(server.url("/official/first").as_str())
        );
        assert_eq!(schedule[1].title, "No id");
        assert_eq!(
            server.request_count(Method::GET, "/api/v1/bangumi/season"),
            1
        );
        assert_eq!(
            server.request_count(Method::GET, "/api/v1/bangumi/archive/2025q2"),
            1
        );
        server.shutdown().await;
    }

    #[tokio::test]
    async fn legacy_schedule_resolves_relative_official_urls_and_keeps_stable_order() {
        let _config = isolate_runtime_config();
        let html = r#"
          <div class="BangumiItem_root__x">
            <div class="BangumiItem_title__x">First</div>
            <div class="BangumiItem_subTitle__x">Original</div>
            <div class="BangumiItem_datetime__x"><span>每周日</span><span>01:30</span></div>
            <a href="//bangumi.tv/subject/11">Bangumi</a>
            <a href="/official/first">官方网站</a>
          </div>
          <div class="BangumiItem_root__x">
            <div class="BangumiItem_title__x">Duplicate</div>
            <a href="https://bgm.tv/subject/11">Bangumi</a>
          </div>
          <div class="BangumiItem_root__x">
            <div class="BangumiItem_title__x">Second</div>
            <div class="BangumiItem_subTitle__x"> </div>
          </div>
        "#;
        let server =
            TestServer::spawn([TestRoute::get("/archive/2025q2", TestResponse::ok(html))]).await;
        point_bgmlist_at(&server.base_url(), "legacy");

        let schedule = fetch_schedule_basic_html("2025q2".to_string())
            .await
            .unwrap();
        assert_eq!(schedule.len(), 2);
        assert_eq!(schedule[0].title, "First");
        assert_eq!(schedule[0].bangumi_id.as_deref(), Some("11"));
        assert_eq!(schedule[0].broadcast_day.as_deref(), Some("周日"));
        assert_eq!(schedule[0].broadcast_time.as_deref(), Some("01:30"));
        assert_eq!(
            schedule[0].site_url.as_deref(),
            Some(server.url("/official/first").as_str())
        );
        assert_eq!(schedule[1].title, "Second");
        assert!(schedule[1].sub_title.is_none());
        assert_eq!(server.request_count(Method::GET, "/archive/2025q2"), 1);
        server.shutdown().await;
    }
}
