use super::matching::{extract_channel_name, extract_episode_number_from_text};
use super::source_config::{current_timestamp_ms, hash_str, source_config_hash};
use super::types::*;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(super) struct CachedEpisodeTable {
    pub(super) source_name: String,
    pub(super) anime_name: String,
    pub(super) detail_url: String,
    pub(super) matched_title: String,
    pub(super) channels: Vec<ChannelInfo>,
    pub(super) episodes: Vec<EpisodeInfo>,
    pub(super) video_regex: String,
    pub(super) cookies: Option<String>,
    pub(super) headers: Option<std::collections::HashMap<String, String>>,
    pub(super) default_subtitle_language: Option<String>,
    pub(super) default_resolution: Option<String>,
    pub(super) config_hash: u64,
    pub(super) cached_at_ms: u64,
    pub(super) expires_at_ms: u64,
}

impl CachedEpisodeTable {
    pub(super) fn is_expired(&self) -> bool {
        current_timestamp_ms() > self.expires_at_ms
    }
}
pub(super) fn get_episode_cache_dir() -> anyhow::Result<std::path::PathBuf> {
    let base_dir =
        std::path::PathBuf::from(crate::api::config::get_cache_dir()).join("online_episode_cache");
    if !base_dir.exists() {
        fs::create_dir_all(&base_dir)?;
    }
    Ok(base_dir)
}

pub(super) fn get_episode_cache_path(
    source_name: &str,
    anime_name: &str,
    config_hash: u64,
) -> anyhow::Result<std::path::PathBuf> {
    let key = format!("{}|{}|{}", source_name, anime_name, config_hash);
    Ok(get_episode_cache_dir()?.join(format!("{:016x}.json", hash_str(&key))))
}

pub(super) fn load_episode_table_cache(
    source_name: &str,
    anime_name: &str,
    config_hash: u64,
) -> Option<CachedEpisodeTable> {
    let cache_path = get_episode_cache_path(source_name, anime_name, config_hash).ok()?;
    let content = fs::read_to_string(&cache_path).ok()?;
    let cache: CachedEpisodeTable = serde_json::from_str(&content).ok()?;
    if cache.source_name != source_name || cache.config_hash != config_hash || cache.is_expired() {
        log::info!(
            "[{}] Episode table cache stale or mismatched: {:?}",
            source_name,
            cache_path
        );
        return None;
    }
    log::info!(
        "[{}] Episode table cache hit: {} episodes",
        source_name,
        cache.episodes.len()
    );
    Some(cache)
}

pub(super) fn save_episode_table_cache(cache: &CachedEpisodeTable) {
    let Ok(cache_path) =
        get_episode_cache_path(&cache.source_name, &cache.anime_name, cache.config_hash)
    else {
        return;
    };

    match serde_json::to_string(cache) {
        Ok(content) => {
            if let Err(e) = fs::write(&cache_path, content) {
                log::warn!(
                    "[{}] Failed to write episode table cache {:?}: {}",
                    cache.source_name,
                    cache_path,
                    e
                );
            } else {
                log::info!(
                    "[{}] Saved episode table cache: {} episodes",
                    cache.source_name,
                    cache.episodes.len()
                );
            }
        }
        Err(e) => log::warn!(
            "[{}] Failed to serialize episode table cache: {}",
            cache.source_name,
            e
        ),
    }
}

pub(super) fn absolutize_url(base_url: &str, href: &str) -> String {
    let Ok(base) = url::Url::parse(base_url) else {
        return href.to_string();
    };

    base.join(href)
        .map(|url| url.into())
        .unwrap_or_else(|_| href.to_string())
}

pub(super) fn parse_episode_table_from_detail(
    source: &MediaSource,
    detail_url: &str,
    detail_resp_text: &str,
) -> (Vec<ChannelInfo>, Vec<EpisodeInfo>) {
    let detail_doc = Html::parse_document(detail_resp_text);
    let mut channels: Vec<ChannelInfo> = Vec::new();
    let mut episodes: Vec<EpisodeInfo> = Vec::new();

    let channel_format_id = source
        .arguments
        .search_config
        .channel_format_id
        .as_deref()
        .unwrap_or("no-channel");

    if channel_format_id == "index-grouped" {
        if let Some(ref format) = source
            .arguments
            .search_config
            .selector_channel_format_flattened
        {
            let mut channel_index_by_position: Vec<usize> = Vec::new();
            if let Some(ref channel_selector) = format.select_channel_names {
                if !channel_selector.is_empty() {
                    if let Ok(ch_sel) = Selector::parse(channel_selector) {
                        let channel_pattern = format.match_channel_name.as_deref();
                        for (idx, ch_el) in detail_doc.select(&ch_sel).enumerate() {
                            let raw_text = ch_el.text().collect::<String>();
                            let extracted = extract_channel_name(&raw_text, channel_pattern);
                            let channel_name = if extracted.trim().is_empty() {
                                format!("线路 {}", idx + 1)
                            } else {
                                extracted.trim().to_string()
                            };
                            let normalized = channel_name.to_lowercase();
                            if let Some(existing) = channels
                                .iter()
                                .find(|channel| channel.name.to_lowercase() == normalized)
                            {
                                channel_index_by_position.push(existing.index);
                            } else {
                                let logical_index = channels.len();
                                channels.push(ChannelInfo {
                                    name: channel_name,
                                    index: logical_index,
                                });
                                channel_index_by_position.push(logical_index);
                            }
                        }
                    }
                }
            }

            if let (Ok(list_sel), Ok(item_sel)) = (
                Selector::parse(&format.select_episode_lists),
                Selector::parse(&format.select_episodes_from_list),
            ) {
                let ep_pattern = format.match_episode_sort_from_name.as_deref();
                for (channel_idx, list_container) in detail_doc.select(&list_sel).enumerate() {
                    if channel_index_by_position.is_empty() && channels.len() <= channel_idx {
                        channels.push(ChannelInfo {
                            name: if channel_idx == 0 {
                                "默认线路".to_string()
                            } else {
                                format!("线路 {}", channel_idx + 1)
                            },
                            index: channel_idx,
                        });
                    }

                    let mapped_channel_index = channel_index_by_position
                        .get(channel_idx)
                        .copied()
                        .or_else(|| channels.get(channel_idx).map(|ch| ch.index))
                        .unwrap_or(channel_idx);

                    for ep_el in list_container.select(&item_sel) {
                        let ep_name = ep_el.text().collect::<String>().trim().to_string();
                        let ep_href = ep_el.value().attr("href").unwrap_or("").to_string();
                        if ep_href.is_empty() {
                            continue;
                        }

                        episodes.push(EpisodeInfo {
                            name: ep_name.clone(),
                            url: absolutize_url(detail_url, &ep_href),
                            episode_number: extract_episode_number_from_text(&ep_name, ep_pattern),
                            channel_index: mapped_channel_index,
                        });
                    }
                }
            }
        }
    } else if let Some(ref format) = source
        .arguments
        .search_config
        .selector_channel_format_no_channel
    {
        channels.push(ChannelInfo {
            name: "默认线路".to_string(),
            index: 0,
        });

        if let Ok(ep_sel) = Selector::parse(&format.select_episodes) {
            let ep_pattern = format.match_episode_sort_from_name.as_deref();
            for ep_el in detail_doc.select(&ep_sel) {
                let ep_name = ep_el.text().collect::<String>().trim().to_string();
                let ep_href = ep_el.value().attr("href").unwrap_or("").to_string();
                if ep_href.is_empty() {
                    continue;
                }

                episodes.push(EpisodeInfo {
                    name: ep_name.clone(),
                    url: absolutize_url(detail_url, &ep_href),
                    episode_number: extract_episode_number_from_text(&ep_name, ep_pattern),
                    channel_index: 0,
                });
            }
        }
    }

    if channels.is_empty() && episodes.is_empty() {
        if let Some(ref format) = source
            .arguments
            .search_config
            .selector_channel_format_flattened
        {
            if let (Ok(list_sel), Ok(item_sel)) = (
                Selector::parse(&format.select_episode_lists),
                Selector::parse(&format.select_episodes_from_list),
            ) {
                let ep_pattern = format.match_episode_sort_from_name.as_deref();
                if let Some(list_container) = detail_doc.select(&list_sel).next() {
                    channels.push(ChannelInfo {
                        name: "默认线路".to_string(),
                        index: 0,
                    });
                    for ep_el in list_container.select(&item_sel) {
                        let ep_name = ep_el.text().collect::<String>().trim().to_string();
                        let ep_href = ep_el.value().attr("href").unwrap_or("").to_string();
                        if ep_href.is_empty() {
                            continue;
                        }
                        episodes.push(EpisodeInfo {
                            name: ep_name.clone(),
                            url: absolutize_url(detail_url, &ep_href),
                            episode_number: extract_episode_number_from_text(&ep_name, ep_pattern),
                            channel_index: 0,
                        });
                    }
                }
            }
        }
    }

    (channels, episodes)
}

pub(super) fn select_episode_from_table<'a>(
    episodes: &'a [EpisodeInfo],
    preferred_channel_index: Option<usize>,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> Option<&'a EpisodeInfo> {
    if episodes.is_empty() {
        return None;
    }

    let channel_episodes: Vec<&EpisodeInfo> = episodes
        .iter()
        .filter(|ep| {
            preferred_channel_index
                .map(|channel_index| ep.channel_index == channel_index)
                .unwrap_or(true)
        })
        .collect();
    let candidates = if channel_episodes.is_empty() {
        episodes.iter().collect::<Vec<_>>()
    } else {
        channel_episodes
    };

    if let Some(abs) = absolute_episode {
        if let Some(found) = candidates
            .iter()
            .copied()
            .find(|ep| ep.episode_number == Some(abs))
        {
            return Some(found);
        }
        if let Some(found) = episodes.iter().find(|ep| ep.episode_number == Some(abs)) {
            return Some(found);
        }
    }

    if let Some(rel) = relative_episode {
        if rel > 0 {
            let idx = (rel - 1) as usize;
            if let Some(found) = candidates.get(idx) {
                return Some(*found);
            }
        }
    }

    candidates.first().copied()
}

pub(super) fn build_episode_table_cache(
    source: &MediaSource,
    anime_name: &str,
    detail_url: String,
    matched_title: String,
    channels: Vec<ChannelInfo>,
    episodes: Vec<EpisodeInfo>,
    cookies: Option<String>,
    headers: Option<std::collections::HashMap<String, String>>,
) -> CachedEpisodeTable {
    let now = current_timestamp_ms();
    CachedEpisodeTable {
        source_name: source.arguments.name.clone(),
        anime_name: anime_name.to_string(),
        detail_url,
        matched_title,
        channels,
        episodes,
        video_regex: source
            .arguments
            .search_config
            .match_video
            .match_video_url
            .clone(),
        cookies,
        headers,
        default_subtitle_language: source
            .arguments
            .search_config
            .default_subtitle_language
            .clone(),
        default_resolution: source.arguments.search_config.default_resolution.clone(),
        config_hash: source_config_hash(source),
        cached_at_ms: now,
        expires_at_ms: now + 24 * 60 * 60 * 1000,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn episode(name: &str, number: Option<u32>, channel_index: usize) -> EpisodeInfo {
        EpisodeInfo {
            name: name.to_string(),
            url: format!("https://example.test/{channel_index}/{name}"),
            episode_number: number,
            channel_index,
        }
    }

    #[test]
    fn absolute_episode_match_wins_inside_preferred_channel() {
        let episodes = vec![
            episode("线路一第1集", Some(1), 0),
            episode("线路二第1集", Some(1), 1),
            episode("线路二第2集", Some(2), 1),
        ];

        let selected = select_episode_from_table(&episodes, Some(1), Some(2), Some(1)).unwrap();
        assert_eq!(selected.name, "线路二第2集");
    }

    #[test]
    fn relative_episode_falls_back_to_position_in_channel() {
        let episodes = vec![
            episode("A", None, 0),
            episode("B", None, 1),
            episode("C", None, 1),
        ];

        let selected = select_episode_from_table(&episodes, Some(1), None, Some(2)).unwrap();
        assert_eq!(selected.name, "C");
    }

    #[test]
    fn select_from_table_returns_none_for_empty_and_first_as_last_resort() {
        // Empty table never selects anything, regardless of the requested numbers.
        assert!(select_episode_from_table(&[], Some(0), Some(1), Some(1)).is_none());

        // With neither absolute nor relative match available, the function falls
        // back to the first candidate in the preferred channel rather than failing.
        let episodes = vec![episode("first", None, 0), episode("second", None, 0)];
        let selected = select_episode_from_table(&episodes, Some(0), None, None).unwrap();
        assert_eq!(selected.name, "first");

        // A preferred channel with no members degrades to the whole list.
        let selected = select_episode_from_table(&episodes, Some(9), Some(42), None).unwrap();
        assert_eq!(selected.name, "first");
    }

    #[test]
    fn absolutize_url_preserves_scheme_host_and_nondefault_port() {
        // Regression for RT-2-001: dropping the port sends the follow-up
        // request to the wrong origin.
        assert_eq!(
            absolutize_url("http://127.0.0.1:8080/search?q=x", "/detail/42"),
            "http://127.0.0.1:8080/detail/42"
        );
        assert_eq!(
            absolutize_url("https://host.example/anime", "/ep/1"),
            "https://host.example/ep/1"
        );
        // Absolute hrefs pass through untouched.
        assert_eq!(
            absolutize_url("http://127.0.0.1:8080/", "https://cdn.example/v.m3u8"),
            "https://cdn.example/v.m3u8"
        );
        // Unparsable base yields the bare relative href (documented behavior).
        assert_eq!(absolutize_url("not a url", "/x"), "/x");
    }

    #[test]
    fn absolutize_url_handles_path_relative_parent_and_protocol_relative_urls() {
        assert_eq!(
            absolutize_url("https://host.example/anime/detail/index.html", "play/1"),
            "https://host.example/anime/detail/play/1"
        );
        assert_eq!(
            absolutize_url("https://host.example/anime/detail/index.html", "../play/2"),
            "https://host.example/anime/play/2"
        );
        assert_eq!(
            absolutize_url(
                "https://host.example/anime/detail/index.html",
                "//cdn.example/v.m3u8"
            ),
            "https://cdn.example/v.m3u8"
        );
    }

    /// Build a `MediaSource` from JSON so tests exercise the same serde path
    /// production uses, rather than hand-assembling nested structs.
    fn source_from_search_config(search_config_json: &str) -> MediaSource {
        let raw = format!(
            r#"{{
                "factoryId": "web-selector",
                "arguments": {{
                    "name": "TestSource",
                    "searchConfig": {search_config_json}
                }}
            }}"#
        );
        serde_json::from_str(&raw).expect("fixture MediaSource JSON must parse")
    }

    #[test]
    fn parse_no_channel_detail_extracts_episodes_and_resolves_relative_urls() {
        let source = source_from_search_config(
            r#"{
                "searchUrl": "https://s.example/?q={keyword}",
                "channelFormatId": "no-channel",
                "selectorChannelFormatNoChannel": {
                    "selectEpisodes": "div.play-list a.ep"
                },
                "matchVideo": { "matchVideoUrl": "url=(?<v>.+\\.m3u8)" }
            }"#,
        );
        let html =
            crate::test_support::fixture::fixture_text("generic_scraper/detail_no_channel.html");

        let (channels, episodes) =
            parse_episode_table_from_detail(&source, "http://127.0.0.1:8080/anime/1", &html);

        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].name, "默认线路");
        assert_eq!(episodes.len(), 3);
        // Relative hrefs are absolutized against the detail URL, keeping the port.
        assert_eq!(episodes[0].url, "http://127.0.0.1:8080/play/1");
        assert_eq!(episodes[0].episode_number, Some(1));
        assert_eq!(episodes[2].episode_number, Some(3));
        assert!(episodes.iter().all(|ep| ep.channel_index == 0));
    }

    #[test]
    fn parse_no_channel_detail_skips_entries_without_href() {
        let source = source_from_search_config(
            r#"{
                "searchUrl": "https://s.example/?q={keyword}",
                "channelFormatId": "no-channel",
                "selectorChannelFormatNoChannel": {
                    "selectEpisodes": "ul.mixed li a"
                },
                "matchVideo": { "matchVideoUrl": "x" }
            }"#,
        );
        // One anchor has no href and must be dropped rather than yielding an
        // episode with an empty URL.
        let html =
            r#"<ul class="mixed"><li><a>第1集</a></li><li><a href="/play/2">第2集</a></li></ul>"#;

        let (_channels, episodes) =
            parse_episode_table_from_detail(&source, "https://host.example/a", html);

        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0].url, "https://host.example/play/2");
    }

    #[test]
    fn parse_index_grouped_detail_maps_channels_to_episode_lists() {
        let source = source_from_search_config(
            r#"{
                "searchUrl": "https://s.example/?q={keyword}",
                "channelFormatId": "index-grouped",
                "selectorChannelFormatFlattened": {
                    "selectChannelNames": "div.channels span.channel-name",
                    "matchChannelName": "播放线路：(?<ch>.+)",
                    "selectEpisodeLists": "ul.ep-list",
                    "selectEpisodesFromList": "li a"
                },
                "matchVideo": { "matchVideoUrl": "x" }
            }"#,
        );
        let html =
            crate::test_support::fixture::fixture_text("generic_scraper/detail_index_grouped.html");

        let (channels, episodes) =
            parse_episode_table_from_detail(&source, "https://host.example:9443/a", &html);

        assert_eq!(channels.len(), 2);
        assert_eq!(channels[0].name, "简中");
        assert_eq!(channels[1].name, "繁中");
        // Two lists x two episodes each.
        assert_eq!(episodes.len(), 4);
        assert_eq!(episodes.iter().filter(|e| e.channel_index == 0).count(), 2);
        assert_eq!(episodes.iter().filter(|e| e.channel_index == 1).count(), 2);
        // Relative hrefs are absolutized against the detail origin, port
        // preserved (RT-2-001 regression).
        assert_eq!(episodes[0].url, "https://host.example:9443/cn/play/1");
        // Second channel's episodes map to channel_index 1 and its own hrefs.
        let tw_first = episodes.iter().find(|e| e.channel_index == 1).unwrap();
        assert_eq!(tw_first.url, "https://host.example:9443/tw/play/1");
    }

    #[test]
    fn parse_index_grouped_detail_deduplicates_channels_and_names_empty_entries() {
        let source = source_from_search_config(
            r#"{
                "searchUrl": "https://s.example/?q={keyword}",
                "channelFormatId": "index-grouped",
                "selectorChannelFormatFlattened": {
                    "selectChannelNames": "span.channel-name",
                    "selectEpisodeLists": "ul.ep-list",
                    "selectEpisodesFromList": "li a"
                },
                "matchVideo": { "matchVideoUrl": "x" }
            }"#,
        );
        let html = r#"
            <span class="channel-name">线路B</span>
            <span class="channel-name">   </span>
            <span class="channel-name">线路B</span>
            <ul class="ep-list"><li><a href="/b/1">第1集</a></li></ul>
            <ul class="ep-list"><li><a href="/unnamed/1">第1集</a></li></ul>
            <ul class="ep-list"><li><a href="/b/2">第2集</a></li></ul>"#;

        let (channels, episodes) =
            parse_episode_table_from_detail(&source, "https://host.example/detail", html);

        assert_eq!(channels.len(), 2);
        assert_eq!(channels[0].name, "线路B");
        assert_eq!(channels[0].index, 0);
        assert_eq!(channels[1].name, "线路 2");
        assert_eq!(channels[1].index, 1);
        assert_eq!(
            episodes
                .iter()
                .map(|episode| episode.channel_index)
                .collect::<Vec<_>>(),
            vec![0, 1, 0]
        );
    }

    #[test]
    fn parse_detail_returns_empty_when_selectors_match_nothing() {
        let source = source_from_search_config(
            r#"{
                "searchUrl": "https://s.example/?q={keyword}",
                "channelFormatId": "no-channel",
                "selectorChannelFormatNoChannel": { "selectEpisodes": "div.absent a" },
                "matchVideo": { "matchVideoUrl": "x" }
            }"#,
        );

        let (channels, episodes) = parse_episode_table_from_detail(
            &source,
            "https://host.example/a",
            "<html><body>no matching nodes</body></html>",
        );

        // no-channel always seeds a single default channel, but no episodes.
        assert_eq!(channels.len(), 1);
        assert!(episodes.is_empty());
    }
}
