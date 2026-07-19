use log::{debug, info, warn};
use reqwest::Client;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use url::Url;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanSearchResult {
    pub id: String,
    pub name: String,
    pub image_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanEpisodeResource {
    pub title: String,
    pub magnet: String,
    pub size: String,
    pub update_time: String,
    pub episode: Option<i32>,
}

// Simple Levenshtein distance implementation
fn levenshtein(s1: &str, s2: &str) -> usize {
    let v1: Vec<char> = s1.chars().collect();
    let v2: Vec<char> = s2.chars().collect();
    let l1 = v1.len();
    let l2 = v2.len();

    let mut matrix = vec![vec![0; l2 + 1]; l1 + 1];

    for i in 0..=l1 {
        matrix[i][0] = i;
    }
    for j in 0..=l2 {
        matrix[0][j] = j;
    }

    for i in 1..=l1 {
        for j in 1..=l2 {
            let cost = if v1[i - 1] == v2[j - 1] { 0 } else { 1 };
            matrix[i][j] = (matrix[i - 1][j] + 1)
                .min(matrix[i][j - 1] + 1)
                .min(matrix[i - 1][j - 1] + cost);
        }
    }

    matrix[l1][l2]
}

// Calculate similarity (0.0 to 1.0)
fn similarity(s1: &str, s2: &str) -> f64 {
    let distance = levenshtein(s1, s2);
    let max_len = s1.chars().count().max(s2.chars().count());
    if max_len == 0 {
        return 1.0;
    }
    1.0 - (distance as f64 / max_len as f64)
}

lazy_static::lazy_static! {
    static ref SEASON_RE: regex::Regex = regex::Regex::new(r"(?i)第[一二三四五六七八九十\d]+季|Part\s*\d+|\d+(st|nd|rd|th)\s*Season|Season\s*\d+").unwrap();
    static ref EPISODE_TOKEN_RE: regex::Regex = regex::Regex::new(r"(?i)^(?:ep?|#)?0*(\d{1,3})(?:v\d+)?$").unwrap();
}

struct MikanApiClient {
    base_url: String,
    direct_client: Option<Client>,
}

impl MikanApiClient {
    fn from_config() -> Self {
        Self {
            base_url: crate::api::config::get_mikan_url(),
            direct_client: None,
        }
    }

    #[cfg(test)]
    fn for_test(base_url: String) -> Self {
        Self {
            base_url,
            direct_client: Some(
                Client::builder()
                    .no_proxy()
                    .build()
                    .expect("failed to build Mikan test client"),
            ),
        }
    }

    fn endpoint(&self, path: &str) -> anyhow::Result<Url> {
        let mut url = Url::parse(&self.base_url)?;
        url.set_path(path);
        url.set_query(None);
        url.set_fragment(None);
        Ok(url)
    }

    fn bangumi_endpoint(&self, mikan_id: &str) -> anyhow::Result<Url> {
        let mut url = self.endpoint("/Home/Bangumi")?;
        url.path_segments_mut()
            .map_err(|_| anyhow::anyhow!("Mikan base URL cannot be a base"))?
            .push(mikan_id);
        Ok(url)
    }

    async fn send(&self, label: &str, url: Url) -> anyhow::Result<reqwest::Response> {
        if let Some(client) = &self.direct_client {
            return Ok(client.get(url).send().await?.error_for_status()?);
        }

        crate::api::network::retry_request(label, |client| client.get(url.clone())).await
    }

    async fn search_anime(&self, name_cn: String) -> anyhow::Result<Option<MikanSearchResult>> {
        let cleaned_name = name_cn.trim();
        let final_search_str = prepare_search_term(&name_cn);

        info!(
            "Searching Mikan for anime: {} (Processed from {})",
            final_search_str, name_cn
        );

        let mut url = self.endpoint("/Home/Search")?;
        url.query_pairs_mut()
            .append_pair("searchstr", &final_search_str);
        debug!("Mikan search URL: {}", url);
        let resp_text = self.send("search_mikan_anime", url).await?.text().await?;
        let results =
            parse_mikan_search_results_from_html(&resp_text, &self.base_url, cleaned_name);

        if let Some(best) = results.first() {
            info!(
                "Selected Mikan anime: {} (ID: {}) with similarity {}",
                best.0.name, best.0.id, best.1
            );
            Ok(Some(best.0.clone()))
        } else {
            warn!("No Mikan anime found for search: {}", final_search_str);
            Ok(None)
        }
    }

    async fn get_resources(
        &self,
        mikan_id: String,
        current_episode_sort: i32,
    ) -> anyhow::Result<Vec<MikanEpisodeResource>> {
        info!(
            "Fetching Mikan resources for ID: {} Episode: {}",
            mikan_id, current_episode_sort
        );
        let url = self.bangumi_endpoint(&mikan_id)?;
        debug!("Mikan bangumi URL: {}", url);
        let resp_text = self.send("get_mikan_resources", url).await?.text().await?;

        let mut resources = parse_mikan_resources_from_html(&resp_text, current_episode_sort);
        let expand_urls = get_mikan_expand_urls(&resp_text, &mikan_id, &self.base_url);

        if !expand_urls.is_empty() {
            info!(
                "Found {} 'Show More' buttons, fetching extra resources...",
                expand_urls.len()
            );
            for expand_url in expand_urls {
                debug!("Fetching expanded resources: {}", expand_url);
                match self
                    .send("get_mikan_expanded_resources", expand_url.clone())
                    .await
                {
                    Ok(resp) => match resp.text().await {
                        Ok(html) => resources
                            .extend(parse_mikan_resources_from_html(&html, current_episode_sort)),
                        Err(error) => warn!(
                            "Failed to read expanded resources from {}: {}",
                            expand_url, error
                        ),
                    },
                    Err(error) => warn!(
                        "Failed to fetch expanded resources from {}: {}",
                        expand_url, error
                    ),
                }
            }
        }

        let mut seen_magnets = HashSet::new();
        resources.retain(|resource| seen_magnets.insert(resource.magnet.clone()));
        info!("Found {} total matching resources.", resources.len());
        Ok(resources)
    }
}

fn prepare_search_term(name: &str) -> String {
    let cleaned_name = name.trim();
    let punctuation = |c: char| -> bool {
        c.is_ascii_punctuation()
            || "。！，、？（）《》【】“”‘’「」『』〜～·•ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫ".contains(c)
    };

    // 1. Replace all punctuation with spaces
    let mut cleaned = name
        .chars()
        .map(|c| if punctuation(c) { ' ' } else { c })
        .collect::<String>();

    // 2. Remove season related keywords using regex
    cleaned = SEASON_RE.replace_all(&cleaned, " ").to_string();

    // 3. Split by whitespace and pick the longest segment
    let segments: Vec<&str> = cleaned
        .split_whitespace()
        .filter(|s| s.chars().count() >= 1)
        .collect();

    segments
        .iter()
        .max_by_key(|s| s.chars().count())
        .map(|s| s.to_string())
        .unwrap_or_else(|| cleaned_name.to_string())
}

fn resolve_url(base_url: &str, raw_url: &str) -> Option<String> {
    let raw_url = raw_url.trim();
    if raw_url.is_empty() {
        return None;
    }

    if raw_url.starts_with("//") {
        let scheme = Url::parse(base_url).ok()?.scheme().to_string();
        return Some(format!("{scheme}:{raw_url}"));
    }
    if let Ok(url) = Url::parse(raw_url) {
        return Some(url.to_string());
    }

    Url::parse(base_url)
        .ok()?
        .join(raw_url)
        .ok()
        .map(|url| url.to_string())
}

fn extract_css_url(style: &str) -> Option<&str> {
    let start = style.find("url(")? + 4;
    let remainder = style.get(start..)?;
    let end = remainder.find(')')?;
    let value = remainder[..end].trim();
    let value = value
        .strip_prefix("&quot;")
        .and_then(|value| value.strip_suffix("&quot;"))
        .or_else(|| {
            value
                .strip_prefix('\'')
                .and_then(|value| value.strip_suffix('\''))
        })
        .or_else(|| {
            value
                .strip_prefix('"')
                .and_then(|value| value.strip_suffix('"'))
        })
        .unwrap_or(value)
        .trim();
    (!value.is_empty()).then_some(value)
}

fn mikan_id_from_href(base_url: &str, href: &str) -> Option<String> {
    let resolved = resolve_url(base_url, href)?;
    let url = Url::parse(&resolved).ok()?;
    let segments = url.path_segments()?.collect::<Vec<_>>();
    let bangumi_index = segments
        .windows(2)
        .position(|parts| parts == ["Home", "Bangumi"])?;
    if bangumi_index + 3 != segments.len() {
        return None;
    }
    let id = segments[bangumi_index + 2].trim();
    (!id.is_empty()).then(|| id.to_string())
}

fn parse_mikan_search_results_from_html(
    html_content: &str,
    base_url: &str,
    searched_name: &str,
) -> Vec<(MikanSearchResult, f64)> {
    let document = Html::parse_document(html_content);

    let list_selector = Selector::parse(".an-ul li a").unwrap();
    let text_selector = Selector::parse(".an-text").unwrap();
    let bg_selector = Selector::parse(".b-lazy").unwrap();

    let mut results = Vec::new();

    for element in document.select(&list_selector) {
        let Some(id) = element
            .value()
            .attr("href")
            .and_then(|href| mikan_id_from_href(base_url, href))
        else {
            continue;
        };
        let name = element
            .select(&text_selector)
            .next()
            .and_then(|e| e.attr("title"))
            .map(str::trim)
            .filter(|name| !name.is_empty())
            .map(str::to_string)
            .unwrap_or_default();
        if name.is_empty() {
            continue;
        }

        let image_url = element
            .select(&bg_selector)
            .next()
            .and_then(|e| e.attr("style"))
            .and_then(extract_css_url)
            .and_then(|raw_url| resolve_url(base_url, raw_url))
            .unwrap_or_default();

        let sim = similarity(searched_name, &name);
        debug!(
            "Found result: {} (ID: {}) Image: {} Similarity: {}",
            name, id, image_url, sim
        );
        results.push((
            MikanSearchResult {
                id,
                name,
                image_url,
            },
            sim,
        ));
    }

    results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    let mut seen_ids = HashSet::new();
    results.retain(|(result, _)| seen_ids.insert(result.id.clone()));
    results
}

pub async fn search_mikan_anime(name_cn: String) -> anyhow::Result<Option<MikanSearchResult>> {
    MikanApiClient::from_config().search_anime(name_cn).await
}

fn extract_episode(title: &str) -> Option<i32> {
    let re_chars = ['[', ']', '【', '】', '(', ')', ' ', '-', '_'];
    let parts: Vec<&str> = title
        .split(|c| re_chars.contains(&c))
        .filter(|s| !s.is_empty())
        .collect();

    for part in parts.iter().rev() {
        if let Some(num) = EPISODE_TOKEN_RE
            .captures(part)
            .and_then(|captures| captures.get(1))
            .and_then(|capture| capture.as_str().parse::<i32>().ok())
        {
            if num > 0
                && num < 1000
                && num != 720
                && num != 1080
                && num != 2160
                && num != 264
                && num != 265
            {
                return Some(num);
            }
        }
    }
    None
}

fn parse_mikan_resources_from_html(
    html_content: &str,
    current_episode_sort: i32,
) -> Vec<MikanEpisodeResource> {
    let document = Html::parse_document(html_content);
    let table_selector = Selector::parse(".episode-table tbody tr").unwrap();
    let name_selector = Selector::parse(".magnet-link-wrap").unwrap();
    let size_selector = Selector::parse("td:nth-child(3)").unwrap();
    let time_selector = Selector::parse("td:nth-child(4)").unwrap();
    let magnet_selector = Selector::parse(".js-magnet").unwrap();

    let mut resources = Vec::new();
    let mut seen_magnets = HashSet::new();

    for row in document.select(&table_selector) {
        let name_el = row.select(&name_selector).next();
        let magnet_el = row.select(&magnet_selector).next();

        if let (Some(name_el), Some(magnet_el)) = (name_el, magnet_el) {
            let title = name_el.text().collect::<String>().trim().to_string();
            let Some(magnet) = magnet_el
                .attr("data-clipboard-text")
                .map(str::trim)
                .filter(|magnet| magnet.starts_with("magnet:?"))
                .map(str::to_string)
            else {
                continue;
            };
            let size = row
                .select(&size_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string())
                .unwrap_or_default();
            let update_time = row
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string())
                .unwrap_or_default();

            let episode = extract_episode(&title);

            if let Some(ep) = episode {
                if ep == current_episode_sort {
                    if !seen_magnets.insert(magnet.clone()) {
                        continue;
                    }
                    debug!("Matched resource: {} (EP {}) Magnet: {}", title, ep, magnet);
                    resources.push(MikanEpisodeResource {
                        title: title.clone(),
                        magnet,
                        size,
                        update_time,
                        episode: Some(ep),
                    });
                }
            }
        }
    }
    resources
}

fn get_mikan_expand_urls(html_content: &str, mikan_id: &str, base_url: &str) -> Vec<Url> {
    let document = Html::parse_document(html_content);
    let expand_selector = Selector::parse(".js-expand-episode").unwrap();
    let mut expand_urls = Vec::new();
    let mut seen_params = HashSet::new();

    for btn in document.select(&expand_selector) {
        let group_id = btn.attr("data-subtitlegroupid").unwrap_or("").trim();
        let take = btn.attr("data-take").unwrap_or("").trim();

        if group_id.is_empty() || take.is_empty() {
            continue;
        }
        if !seen_params.insert((group_id.to_string(), take.to_string())) {
            continue;
        }
        if let Ok(mut expand_url) = Url::parse(base_url) {
            expand_url.set_path("/Home/ExpandEpisodeTable");
            expand_url.set_query(None);
            expand_url
                .query_pairs_mut()
                .append_pair("bangumiId", mikan_id)
                .append_pair("subtitleGroupId", group_id)
                .append_pair("take", take);
            expand_urls.push(expand_url);
        }
    }
    expand_urls
}

pub async fn get_mikan_resources(
    mikan_id: String,
    current_episode_sort: i32,
) -> anyhow::Result<Vec<MikanEpisodeResource>> {
    MikanApiClient::from_config()
        .get_resources(mikan_id, current_episode_sort)
        .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::fixture::fixture_text;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use axum::http::Method;

    #[test]
    fn levenshtein_and_similarity_count_unicode_characters() {
        assert_eq!(levenshtein("动画", "动话"), 1);
        assert_eq!(similarity("", ""), 1.0);
        assert_eq!(similarity("动画", "动话"), 0.5);
    }

    #[test]
    fn search_term_removes_season_markers_and_keeps_the_longest_title_segment() {
        assert_eq!(prepare_search_term("《测试动画》第二季 Part 2"), "测试动画");
        assert_eq!(
            prepare_search_term("  A / Unicode标题✨  "),
            "Unicode标题✨"
        );
        assert_eq!(prepare_search_term("【】"), "【】");
    }

    #[test]
    fn minimal_search_fixture_resolves_relative_cover_url() {
        let html = fixture_text("mikan/search_minimal.html");

        let results = parse_mikan_search_results_from_html(
            &html,
            "https://mikan.example",
            "Fixture Anime / 测试动画",
        );

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0.id, "123");
        assert_eq!(results[0].0.name, "Fixture Anime / 测试动画");
        assert_eq!(
            results[0].0.image_url,
            "https://mikan.example/images/fixture.jpg"
        );
    }

    #[test]
    fn search_parser_handles_quoted_and_absolute_covers_and_skips_bad_or_duplicate_nodes() {
        let html = fixture_text("mikan/search_edge_cases.html");

        let results = parse_mikan_search_results_from_html(
            &html,
            "https://mikan.example/base",
            "Unicode 测试动画 ✨",
        );

        assert_eq!(results.len(), 2);
        assert_eq!(results[0].0.id, "201");
        assert_eq!(results[0].0.name, "Unicode 测试动画 ✨");
        assert_eq!(results[0].0.image_url, "https://cdn.example/cover.jpg");
        assert_eq!(results[1].0.id, "200");
        assert_eq!(
            results[1].0.image_url,
            "https://mikan.example/images/other.jpg"
        );
    }

    #[tokio::test]
    async fn search_request_encodes_unicode_query_and_parses_loopback_fixture() {
        let server = TestServer::spawn([TestRoute::get(
            "/Home/Search",
            TestResponse::fixture("mikan/search_minimal.html"),
        )])
        .await;
        let api = MikanApiClient::for_test(server.base_url());

        let result = api
            .search_anime("《测试动画》第二季".to_string())
            .await
            .unwrap()
            .unwrap();

        assert_eq!(result.id, "123");
        let requests = server.requests();
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0].method, Method::GET);
        let query = requests[0]
            .uri
            .query()
            .and_then(|query| url::form_urlencoded::parse(query.as_bytes()).next())
            .unwrap();
        assert_eq!(query.0, "searchstr");
        assert_eq!(query.1, "测试动画");

        server.shutdown().await;
    }

    #[test]
    fn episode_extraction_accepts_common_versions_and_rejects_codec_or_resolution_tokens() {
        assert_eq!(extract_episode("[Group] Anime - 01 [1080p]"), Some(1));
        assert_eq!(extract_episode("[Group] Anime - E003v2 [x265]"), Some(3));
        assert_eq!(extract_episode("Unicode 动画【12】"), Some(12));
        assert_eq!(extract_episode("Only 1080 720 x265"), None);
        assert_eq!(extract_episode("Episode 0"), None);
        assert_eq!(extract_episode("Episode 1000"), None);
    }

    #[test]
    fn resource_parser_filters_target_episode_invalid_links_and_duplicates() {
        let html = fixture_text("mikan/resources_edge_cases.html");

        let resources = parse_mikan_resources_from_html(&html, 1);

        assert_eq!(resources.len(), 2);
        assert_eq!(resources[0].title, "[Fixture] 测试动画 - 01 [1080p]");
        assert_eq!(resources[0].magnet, "magnet:?xt=urn:btih:one");
        assert_eq!(resources[0].size, "1.2 GB");
        assert_eq!(resources[0].update_time, "2026/07/19 12:00");
        assert_eq!(resources[1].title, "Unicode 🍊 动画【01】");
        assert_eq!(resources[1].size, "");
        assert_eq!(resources[1].update_time, "");
    }

    #[test]
    fn expand_urls_are_deduplicated_and_percent_encoded() {
        let html = fixture_text("mikan/resources_edge_cases.html");

        let urls = get_mikan_expand_urls(&html, "bangumi / 1", "https://mikan.example");

        assert_eq!(urls.len(), 1);
        let pairs = urls[0]
            .query_pairs()
            .collect::<std::collections::HashMap<_, _>>();
        assert_eq!(
            pairs.get("bangumiId").map(|value| value.as_ref()),
            Some("bangumi / 1")
        );
        assert_eq!(
            pairs.get("subtitleGroupId").map(|value| value.as_ref()),
            Some("字幕 组&A")
        );
        assert_eq!(pairs.get("take").map(|value| value.as_ref()), Some("65"));
    }

    #[tokio::test]
    async fn full_resource_flow_fetches_expansion_and_deduplicates_magnets() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/Home/Bangumi/fixture-id",
                TestResponse::fixture("mikan/resources_edge_cases.html"),
            ),
            TestRoute::get(
                "/Home/ExpandEpisodeTable",
                TestResponse::fixture("mikan/resources_expanded.html"),
            ),
        ])
        .await;
        let api = MikanApiClient::for_test(server.base_url());

        let resources = api
            .get_resources("fixture-id".to_string(), 1)
            .await
            .unwrap();

        assert_eq!(resources.len(), 3);
        assert!(
            resources
                .iter()
                .any(|resource| resource.magnet.ends_with("expanded"))
        );
        assert_eq!(
            server.request_count(Method::GET, "/Home/ExpandEpisodeTable"),
            1
        );

        server.shutdown().await;
    }
}
