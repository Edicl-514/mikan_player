use anyhow::Result;
use log::info;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use url::Url;

const DMHY_API_BASE_URL: &str = "https://api.animes.garden";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DmhyResource {
    pub title: String,
    pub magnet: String,
    pub size: String,
    pub publish_date: String,
    pub episode: Option<i32>,
}

#[derive(Debug, Deserialize)]
struct Rss {
    channel: Option<Channel>,
}

#[derive(Debug, Deserialize)]
struct Channel {
    #[serde(rename = "item", default)]
    items: Vec<Item>,
}

#[derive(Debug, Deserialize)]
struct Item {
    title: Option<String>,
    enclosure: Option<Enclosure>,
    #[serde(rename = "pubDate")]
    pub_date: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Enclosure {
    #[serde(rename = "@url")]
    url: Option<String>,
    #[serde(rename = "@length")]
    length: Option<String>,
}

lazy_static::lazy_static! {
    static ref EPISODE_TOKEN_RE: regex::Regex = regex::Regex::new(r"(?i)^(?:ep?|#)?0*(\d{1,3})(?:v\d+)?$").unwrap();
}

fn extract_episode(title: &str) -> Option<i32> {
    // Reusing the logic from mikan.rs or similar robust logic
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
            // Basic heuristic to avoid resolutions like 720, 1080, etc.
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

fn format_kib_size(raw_kib: Option<&str>) -> String {
    const UNITS: [&str; 8] = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB"];
    let size_kib = raw_kib
        .and_then(|value| value.trim().parse::<u64>().ok())
        .unwrap_or(0);
    if size_kib == 0 {
        return "0.0 B".to_string();
    }

    // Anime Garden's feed uses KiB despite RSS enclosure.length normally being
    // bytes. Start at KB directly so extreme inputs cannot overflow u64 * 1024.
    let mut size = size_kib as f64;
    let mut unit_idx = 1;

    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }

    format!("{:.1} {}", size, UNITS[unit_idx])
}

fn is_valid_magnet(raw_url: &str) -> bool {
    Url::parse(raw_url).is_ok_and(|url| {
        url.scheme() == "magnet"
            && url
                .query_pairs()
                .any(|(key, value)| key == "xt" && value.starts_with("urn:btih:"))
    })
}

fn parse_dmhy_resources_from_xml(
    xml_content: &str,
    target_episode: i32,
) -> Result<Vec<DmhyResource>> {
    let rss: Rss = quick_xml::de::from_str(xml_content)?;
    let mut resources = Vec::new();
    let mut seen_magnets = HashSet::new();

    for item in rss.channel.map(|channel| channel.items).unwrap_or_default() {
        let Some(title) = item
            .title
            .map(|title| title.trim().to_string())
            .filter(|title| !title.is_empty())
        else {
            continue;
        };
        let Some(enclosure) = item.enclosure else {
            continue;
        };
        let Some(magnet) = enclosure
            .url
            .map(|url| url.trim().to_string())
            .filter(|url| is_valid_magnet(url))
        else {
            continue;
        };
        let episode = extract_episode(&title);
        if episode != Some(target_episode) {
            continue;
        }
        if !seen_magnets.insert(magnet.clone()) {
            continue;
        }

        resources.push(DmhyResource {
            title,
            magnet,
            size: format_kib_size(enclosure.length.as_deref()),
            publish_date: item.pub_date.unwrap_or_default().trim().to_string(),
            episode,
        });
    }

    Ok(resources)
}

struct DmhyApiClient {
    base_url: String,
    direct_client: Option<Client>,
}

impl DmhyApiClient {
    fn production() -> Self {
        Self {
            base_url: DMHY_API_BASE_URL.to_string(),
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
                    .expect("failed to build DMHY test client"),
            ),
        }
    }

    async fn fetch_resources(
        &self,
        subject_id: String,
        target_episode: i32,
    ) -> Result<Vec<DmhyResource>> {
        info!(
            "Fetching DMHY resources for Subject ID: {}, Episode: {}",
            subject_id, target_episode
        );

        let mut url = Url::parse(&self.base_url)?;
        url.set_path("/feed.xml");
        url.set_query(None);
        url.query_pairs_mut().append_pair("subject", &subject_id);
        let response = if let Some(client) = &self.direct_client {
            client
                .get(url)
                .header("accept", "application/xml")
                .send()
                .await?
                .error_for_status()?
        } else {
            crate::api::network::retry_request("fetch_dmhy_resources", |client| {
                client.get(url.clone()).header("accept", "application/xml")
            })
            .await?
        };
        let resources = parse_dmhy_resources_from_xml(&response.text().await?, target_episode)?;

        info!("Found {} matching DMHY resources", resources.len());
        Ok(resources)
    }
}

pub async fn fetch_dmhy_resources(
    subject_id: String,
    target_episode: i32,
) -> Result<Vec<DmhyResource>> {
    DmhyApiClient::production()
        .fetch_resources(subject_id, target_episode)
        .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::fixture::fixture_text;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use axum::http::Method;

    #[test]
    fn episode_extraction_handles_versions_unicode_and_noise_tokens() {
        assert_eq!(extract_episode("[Group] Anime - 01 [1080p]"), Some(1));
        assert_eq!(extract_episode("Unicode 动画【E003v2】"), Some(3));
        assert_eq!(extract_episode("Only 1080 720 x264"), None);
        assert_eq!(extract_episode("Episode 0"), None);
        assert_eq!(extract_episode("Episode 1000"), None);
    }

    #[test]
    fn size_formatter_uses_feed_kib_units_without_integer_overflow() {
        assert_eq!(format_kib_size(None), "0.0 B");
        assert_eq!(format_kib_size(Some("invalid")), "0.0 B");
        assert_eq!(format_kib_size(Some("1")), "1.0 KB");
        assert_eq!(format_kib_size(Some("1024")), "1.0 MB");
        assert_eq!(format_kib_size(Some("1048576")), "1.0 GB");
        assert_eq!(format_kib_size(Some("18446744073709551615")), "16.0 ZB");
    }

    #[test]
    fn magnet_validation_rejects_non_magnet_or_missing_btih() {
        assert!(is_valid_magnet("magnet:?xt=urn:btih:fixture"));
        assert!(!is_valid_magnet("magnet:?dn=missing-hash"));
        assert!(!is_valid_magnet("https://example.com/file.torrent"));
        assert!(!is_valid_magnet("not a URL"));
    }

    #[test]
    fn minimal_fixture_parses_normal_resource_and_kib_size() {
        let xml = fixture_text("dmhy/feed_minimal.xml");

        let resources = parse_dmhy_resources_from_xml(&xml, 1).unwrap();

        assert_eq!(resources.len(), 1);
        assert_eq!(resources[0].title, "[Fixture] 测试动画 - 01 [1080p]");
        assert_eq!(resources[0].magnet, "magnet:?xt=urn:btih:fixture");
        assert_eq!(resources[0].size, "1.0 MB");
        assert_eq!(resources[0].publish_date, "Sun, 19 Jul 2026 00:00:00 GMT");
        assert_eq!(resources[0].episode, Some(1));
    }

    #[test]
    fn edge_fixture_skips_bad_nodes_and_duplicates_but_preserves_unicode_and_raw_date() {
        let xml = fixture_text("dmhy/feed_edge_cases.xml");

        let resources = parse_dmhy_resources_from_xml(&xml, 1).unwrap();

        assert_eq!(resources.len(), 4);
        assert_eq!(
            resources[0].title,
            "[字幕组] Unicode 测试动画 ✨ - E01v2 [1080p]"
        );
        assert_eq!(resources[0].publish_date, "invalid but preserved");
        assert_eq!(resources[0].size, "1.0 MB");
        assert_eq!(resources[1].size, "0.0 B");
        assert_eq!(resources[2].size, "0.0 B");
        assert_eq!(resources[3].size, "16.0 ZB");
    }

    #[test]
    fn missing_channel_is_an_empty_feed_and_malformed_xml_is_an_error() {
        assert!(
            parse_dmhy_resources_from_xml("<rss version=\"2.0\"></rss>", 1)
                .unwrap()
                .is_empty()
        );
        let malformed = fixture_text("dmhy/feed_malformed.xml");
        assert!(parse_dmhy_resources_from_xml(&malformed, 1).is_err());
    }

    #[tokio::test]
    async fn loopback_request_encodes_subject_and_sets_xml_accept_header() {
        let server = TestServer::spawn([TestRoute::get(
            "/feed.xml",
            TestResponse::fixture("dmhy/feed_minimal.xml")
                .with_header("content-type", "application/xml"),
        )])
        .await;
        let api = DmhyApiClient::for_test(server.base_url());

        let resources = api
            .fetch_resources("主题 / 517057".to_string(), 1)
            .await
            .unwrap();

        assert_eq!(resources.len(), 1);
        let requests = server.requests();
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0].method, Method::GET);
        assert_eq!(requests[0].headers["accept"], "application/xml");
        let subject = requests[0]
            .uri
            .query()
            .and_then(|query| {
                url::form_urlencoded::parse(query.as_bytes()).find(|(key, _)| key == "subject")
            })
            .map(|(_, value)| value.into_owned());
        assert_eq!(subject.as_deref(), Some("主题 / 517057"));

        server.shutdown().await;
    }
}
