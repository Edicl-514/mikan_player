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
    if href.starts_with("http") {
        href.to_string()
    } else {
        let base = if let Ok(u) = url::Url::parse(base_url) {
            format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
        } else {
            "".to_string()
        };
        format!("{}{}", base, href)
    }
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
            if let Some(ref channel_selector) = format.select_channel_names {
                if !channel_selector.is_empty() {
                    if let Ok(ch_sel) = Selector::parse(channel_selector) {
                        let channel_pattern = format.match_channel_name.as_deref();
                        for (idx, ch_el) in detail_doc.select(&ch_sel).enumerate() {
                            let raw_text = ch_el.text().collect::<String>();
                            let channel_name = extract_channel_name(&raw_text, channel_pattern);
                            if !channel_name.is_empty() {
                                channels.push(ChannelInfo {
                                    name: channel_name,
                                    index: idx,
                                });
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
                    if channels.is_empty() {
                        channels.push(ChannelInfo {
                            name: "默认线路".to_string(),
                            index: 0,
                        });
                    }

                    let mapped_channel_index = channels
                        .get(channel_idx)
                        .map(|ch| ch.index)
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
}
