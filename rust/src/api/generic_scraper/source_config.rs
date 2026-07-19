use super::region::{detect_and_filter_root, detect_current_region_with_retry};
use super::types::*;
use scraper::Selector;
use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::sync::RwLock;

lazy_static::lazy_static! {
    static ref CACHED_SOURCE_CONFIG: RwLock<Option<CachedSourceConfig>> = RwLock::new(None);
}

pub(super) struct CachedSourceConfig {
    sources: Vec<MediaSource>,
    loaded_at_ms: u64,
}

pub(super) const SOURCE_CONFIG_CACHE_TTL_MS: u64 = 30_000;
/// 获取播放源配置缓存文件路径
pub(super) fn get_cache_file_path() -> anyhow::Result<std::path::PathBuf> {
    let base_dir = std::path::PathBuf::from(crate::api::config::get_cache_dir());

    // 确保目录存在
    if !base_dir.exists() {
        fs::create_dir_all(&base_dir)?;
    }

    Ok(base_dir.join("playback_sources_cache.json"))
}

pub(super) fn current_timestamp_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_millis() as u64)
        .unwrap_or(0)
}

pub(super) fn hash_str(value: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    value.hash(&mut hasher);
    hasher.finish()
}

pub(super) fn source_config_hash(source: &MediaSource) -> u64 {
    let config_json = serde_json::to_string(&source.arguments.search_config).unwrap_or_default();
    let captcha_json = serde_json::to_string(&source.arguments.captcha_config).unwrap_or_default();
    hash_str(&format!("{}|{}", config_json, captcha_json))
}

fn validate_css_selector(field: &str, value: &str) -> anyhow::Result<()> {
    Selector::parse(value)
        .map(|_| ())
        .map_err(|error| anyhow::anyhow!("Invalid CSS selector for {field}: {error}"))
}

fn validate_regex(field: &str, value: &str) -> anyhow::Result<()> {
    regex::Regex::new(value)
        .map(|_| ())
        .map_err(|error| anyhow::anyhow!("Invalid regex for {field}: {error}"))
}

fn validate_fancy_regex(field: &str, value: &str) -> anyhow::Result<()> {
    fancy_regex::Regex::new(value)
        .map(|_| ())
        .map_err(|error| anyhow::anyhow!("Invalid regex for {field}: {error}"))
}

fn validate_search_config(config: &SearchConfig) -> anyhow::Result<()> {
    if let Some(format) = &config.selector_subject_format_a {
        validate_css_selector("selectorSubjectFormatA.selectLists", &format.select_lists)?;
    }
    if let Some(format) = &config.selector_subject_format_indexed {
        validate_css_selector(
            "selectorSubjectFormatIndexed.selectNames",
            &format.select_names,
        )?;
        validate_css_selector(
            "selectorSubjectFormatIndexed.selectLinks",
            &format.select_links,
        )?;
    }
    if let Some(format) = &config.selector_channel_format_flattened {
        if let Some(selector) = format
            .select_channel_names
            .as_deref()
            .filter(|value| !value.is_empty())
        {
            validate_css_selector(
                "selectorChannelFormatFlattened.selectChannelNames",
                selector,
            )?;
        }
        if let Some(pattern) = format.match_channel_name.as_deref() {
            validate_regex("selectorChannelFormatFlattened.matchChannelName", pattern)?;
        }
        validate_css_selector(
            "selectorChannelFormatFlattened.selectEpisodeLists",
            &format.select_episode_lists,
        )?;
        validate_css_selector(
            "selectorChannelFormatFlattened.selectEpisodesFromList",
            &format.select_episodes_from_list,
        )?;
        if let Some(selector) = format
            .select_episode_links_from_list
            .as_deref()
            .filter(|value| !value.is_empty())
        {
            validate_css_selector(
                "selectorChannelFormatFlattened.selectEpisodeLinksFromList",
                selector,
            )?;
        }
        if let Some(pattern) = format.match_episode_sort_from_name.as_deref() {
            validate_regex(
                "selectorChannelFormatFlattened.matchEpisodeSortFromName",
                pattern,
            )?;
        }
    }
    if let Some(format) = &config.selector_channel_format_no_channel {
        validate_css_selector(
            "selectorChannelFormatNoChannel.selectEpisodes",
            &format.select_episodes,
        )?;
        if let Some(selector) = format
            .select_episode_links
            .as_deref()
            .filter(|value| !value.is_empty())
        {
            validate_css_selector(
                "selectorChannelFormatNoChannel.selectEpisodeLinks",
                selector,
            )?;
        }
        if let Some(pattern) = format.match_episode_sort_from_name.as_deref() {
            validate_regex(
                "selectorChannelFormatNoChannel.matchEpisodeSortFromName",
                pattern,
            )?;
        }
    }

    validate_fancy_regex(
        "matchVideo.matchVideoUrl",
        &config.match_video.match_video_url,
    )?;
    if let Some(pattern) = config.match_video.match_nested_url.as_deref() {
        validate_fancy_regex("matchVideo.matchNestedUrl", pattern)?;
    }
    Ok(())
}

fn validate_captcha_config(config: &CaptchaConfig) -> anyhow::Result<()> {
    for (field, selector) in [
        (
            "captchaConfig.detectSelector",
            config.detect_selector.as_deref(),
        ),
        (
            "captchaConfig.successSelector",
            config.success_selector.as_deref(),
        ),
        (
            "captchaConfig.imageSelector",
            config.image_selector.as_deref(),
        ),
        (
            "captchaConfig.inputSelector",
            config.input_selector.as_deref(),
        ),
        (
            "captchaConfig.submitSelector",
            config.submit_selector.as_deref(),
        ),
        (
            "captchaConfig.refreshSelector",
            config.refresh_selector.as_deref(),
        ),
    ] {
        if let Some(selector) = selector.filter(|value| !value.is_empty()) {
            validate_css_selector(field, selector)?;
        }
    }
    Ok(())
}

/// 从本地缓存读取播放源配置
pub(super) fn load_from_cache() -> anyhow::Result<String> {
    let cache_path = get_cache_file_path()?;
    log::info!(
        "Loading playback source config from cache: {:?}",
        cache_path
    );

    if cache_path.exists() {
        let content = fs::read_to_string(&cache_path)?;
        log::info!("Successfully loaded config from cache");
        Ok(content)
    } else {
        Err(anyhow::anyhow!("Cache file does not exist"))
    }
}

/// 保存播放源配置到本地缓存
pub(super) fn save_to_cache(content: &str) -> anyhow::Result<()> {
    let cache_path = get_cache_file_path()?;
    log::info!("Saving playback source config to cache: {:?}", cache_path);
    fs::write(&cache_path, content)?;
    log::info!("Successfully saved config to cache");
    Ok(())
}

/// 从本地缓存加载播放源配置，如果缓存不存在则返回错误
pub(super) async fn load_playback_source_config(
    _client: &reqwest::Client,
) -> anyhow::Result<String> {
    // 只从本地缓存读取
    load_from_cache()
}

/// Load, parse, filter, and sort enabled sources — with in-memory caching.
/// Avoids re-reading / re-parsing / re-detecting-region when multiple search
/// streams are started in quick succession (e.g. captcha-sourceI searches).
pub(super) async fn load_enabled_sources() -> anyhow::Result<Vec<MediaSource>> {
    let now = current_timestamp_ms();

    {
        let guard = CACHED_SOURCE_CONFIG.read().unwrap();
        if let Some(cached) = guard.as_ref() {
            if now.saturating_sub(cached.loaded_at_ms) < SOURCE_CONFIG_CACHE_TTL_MS {
                log::info!(
                    "Reusing cached source config ({} sources, age={}ms)",
                    cached.sources.len(),
                    now.saturating_sub(cached.loaded_at_ms),
                );
                return Ok(cached.sources.clone());
            }
        }
    }

    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;
    let root: SampleRoot = serde_json::from_str(&content)?;
    let root = detect_and_filter_root(root).await;

    let mut sources: Vec<_> = root
        .exported_media_source_data_list
        .media_sources
        .into_iter()
        .filter(|source| {
            if !crate::api::config::is_source_enabled(&source.arguments.name) {
                log::info!("Skipping disabled source: {}", source.arguments.name);
                false
            } else {
                true
            }
        })
        .collect();

    sources.sort_by_key(|s| s.arguments.tier.unwrap_or(1));

    {
        let mut guard = CACHED_SOURCE_CONFIG.write().unwrap();
        *guard = Some(CachedSourceConfig {
            sources: sources.clone(),
            loaded_at_ms: now,
        });
    }

    log::info!(
        "Loaded and cached source config ({} enabled sources)",
        sources.len()
    );
    Ok(sources)
}

/// Invalidate the in-memory source config cache so the next
/// `load_enabled_sources` call will re-read from disk.
pub(crate) fn invalidate_source_config_cache() {
    let mut guard = CACHED_SOURCE_CONFIG.write().unwrap();
    *guard = None;
    log::info!("Source config cache invalidated");
}

/// 从订阅地址刷新播放源配置并保存到本地缓存
pub(crate) async fn refresh_playback_source_config() -> anyhow::Result<String> {
    let sub_url = crate::api::config::get_playback_sub_url();
    log::info!("Refreshing playback source config from: {}", sub_url);

    let resp = crate::api::network::retry_request("refresh_playback_source_config", |client| {
        client.get(&sub_url)
    })
    .await?;
    let content = resp.text().await?;
    log::info!("Successfully fetched config from subscription URL");

    // 验证JSON格式
    let _root: SampleRoot = serde_json::from_str(&content)?;
    log::info!("Playback source config validated successfully");

    // 保存到本地缓存
    save_to_cache(&content)?;
    invalidate_source_config_cache();

    Ok(content)
}

/// 预加载播放源配置（应用启动时调用）
/// 尝试从本地缓存加载配置，如果缓存不存在则从订阅地址拉取
pub(crate) async fn preload_playback_sources() -> anyhow::Result<()> {
    let _ = detect_current_region_with_retry(2).await;

    // 先尝试从缓存加载
    match load_from_cache() {
        Ok(content) => {
            // 验证JSON格式
            let _root: SampleRoot = serde_json::from_str(&content)?;
            log::info!("Playback source config loaded from cache and validated");
            Ok(())
        }
        Err(e) => {
            // 缓存不存在，从网络拉取
            log::warn!("Failed to load from cache: {}, fetching from network...", e);
            refresh_playback_source_config().await?;
            Ok(())
        }
    }
}

/// 获取所有播放源的状态
pub(crate) async fn get_playback_sources() -> anyhow::Result<Vec<SourceState>> {
    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;
    let root: SampleRoot = serde_json::from_str(&content)?;
    let root = detect_and_filter_root(root).await;

    let mut sources = Vec::new();
    for source in root.exported_media_source_data_list.media_sources {
        let search_config_json = serde_json::to_string_pretty(&source.arguments.search_config)
            .unwrap_or_else(|_| "{}".to_string());
        let name = source.arguments.name;
        let description = source.arguments.description.unwrap_or_default();
        let icon_url = source.arguments.icon_url.unwrap_or_default();
        let tier = source.arguments.tier.unwrap_or(1);
        let default_subtitle_language = source
            .arguments
            .search_config
            .default_subtitle_language
            .unwrap_or_default();
        let default_resolution = source
            .arguments
            .search_config
            .default_resolution
            .unwrap_or_default();
        let search_url = source.arguments.search_config.search_url.clone();
        let enabled = crate::api::config::is_source_enabled(&name);
        let captcha_config_json = source
            .arguments
            .captcha_config
            .as_ref()
            .map(|c| serde_json::to_string_pretty(c).unwrap_or_default());
        sources.push(SourceState {
            name,
            description,
            icon_url,
            tier,
            default_subtitle_language,
            default_resolution,
            search_url,
            search_config_json,
            captcha_config_json,
            enabled,
        });
    }
    Ok(sources)
}

/// 更新单个源的配置
pub(crate) async fn update_single_source_config(update: SourceConfigUpdate) -> anyhow::Result<()> {
    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;
    let mut root: SampleRoot = serde_json::from_str(&content)?;

    let mut found = false;
    for source in &mut root.exported_media_source_data_list.media_sources {
        if source.arguments.name == update.name {
            if let Some(n) = update.new_name.clone() {
                source.arguments.name = n;
            }
            if let Some(t) = update.tier {
                source.arguments.tier = Some(t);
            }
            if let Some(desc) = &update.description {
                source.arguments.description = Some(desc.clone());
            }

            if let Some(json) = &update.search_config_json {
                // 尝试解析完整的 SearchConfig JSON
                match serde_json::from_str::<SearchConfig>(json) {
                    Ok(config) => {
                        validate_search_config(&config)?;
                        source.arguments.search_config = config;
                    }
                    Err(e) => {
                        log::error!("Failed to parse search_config_json: {}", e);
                        return Err(anyhow::anyhow!(
                            "Invalid JSON format for search config: {}",
                            e
                        ));
                    }
                }
            } else {
                // 单个字段更新 (向后兼容)
                if let Some(lang) = &update.default_subtitle_language {
                    source.arguments.search_config.default_subtitle_language = Some(lang.clone());
                }
                if let Some(res) = &update.default_resolution {
                    source.arguments.search_config.default_resolution = Some(res.clone());
                }
                if let Some(url) = &update.search_url {
                    source.arguments.search_config.search_url = url.clone();
                }
            }
            if let Some(i) = update.icon_url.clone() {
                source.arguments.icon_url = Some(i);
            }

            if let Some(json) = &update.captcha_config_json {
                match serde_json::from_str::<CaptchaConfig>(json) {
                    Ok(config) => {
                        validate_captcha_config(&config)?;
                        source.arguments.captcha_config = Some(config);
                    }
                    Err(e) => {
                        log::error!("Failed to parse captcha_config_json: {}", e);
                        return Err(anyhow::anyhow!(
                            "Invalid JSON format for captcha config: {}",
                            e
                        ));
                    }
                }
            }

            found = true;
            break;
        }
    }

    if found {
        let new_content = serde_json::to_string_pretty(&root)?;
        save_to_cache(&new_content)?;
        invalidate_source_config_cache();
        Ok(())
    } else {
        Err(anyhow::anyhow!("Source not found: {}", update.name))
    }
}

/// 添加新的源配置
pub(crate) async fn add_source_config(new_config: SourceConfigUpdate) -> anyhow::Result<()> {
    // 检查名称是否为空
    if new_config.name.is_empty() {
        return Err(anyhow::anyhow!("Source name cannot be empty"));
    }

    let client = crate::api::network::get_shared_client().clone();
    let content = match load_playback_source_config(&client).await {
        Ok(c) => c,
        Err(_) => {
            // 如果不存在，创建空配置
            let empty = SampleRoot {
                exported_media_source_data_list: ExportedMediaSourceDataList {
                    media_sources: vec![],
                },
            };
            serde_json::to_string_pretty(&empty)?
        }
    };

    let mut root: SampleRoot = serde_json::from_str(&content).unwrap_or_else(|_| SampleRoot {
        exported_media_source_data_list: ExportedMediaSourceDataList {
            media_sources: vec![],
        },
    });

    // 检查重复名称
    for source in &root.exported_media_source_data_list.media_sources {
        if source.arguments.name == new_config.name {
            return Err(anyhow::anyhow!(
                "Source with name '{}' already exists",
                new_config.name
            ));
        }
    }

    // 构建 SearchConfig
    let search_config = if let Some(json) = &new_config.search_config_json {
        let config = serde_json::from_str::<SearchConfig>(json)
            .map_err(|e| anyhow::anyhow!("Invalid SearchConfig JSON: {}", e))?;
        validate_search_config(&config)?;
        config
    } else {
        // 构建默认配置
        SearchConfig {
            search_url: new_config.search_url.clone().unwrap_or_default(),
            default_subtitle_language: new_config.default_subtitle_language.clone(),
            default_resolution: new_config.default_resolution.clone(),
            subject_format_id: None,
            selector_subject_format_a: None,
            selector_subject_format_indexed: None,
            channel_format_id: None,
            selector_channel_format_flattened: None,
            selector_channel_format_no_channel: None,
            match_video: MatchVideo {
                match_video_url: String::new(),
                enable_nested_url: None,
                match_nested_url: None,
                cookies: None,
                add_headers_to_video: None,
                extra: std::collections::HashMap::new(),
            },
            extra: std::collections::HashMap::new(),
        }
    };

    let captcha_config = if let Some(json) = &new_config.captcha_config_json {
        let config = serde_json::from_str::<CaptchaConfig>(json)
            .map_err(|e| anyhow::anyhow!("Invalid CaptchaConfig JSON: {}", e))?;
        validate_captcha_config(&config)?;
        Some(config)
    } else {
        None
    };

    let new_source = MediaSource {
        factory_id: "web-selector".to_string(),
        arguments: SourceArguments {
            name: new_config.name,
            description: new_config.description,
            icon_url: new_config.icon_url,
            tier: new_config.tier,
            restricted_region: None,
            search_config,
            captcha_config,
            extra: std::collections::HashMap::new(),
        },
        extra: std::collections::HashMap::new(),
    };

    // 添加到列表
    root.exported_media_source_data_list
        .media_sources
        .push(new_source);

    let new_content = serde_json::to_string_pretty(&root)?;
    save_to_cache(&new_content)?;
    invalidate_source_config_cache();

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::config::init_config;
    use crate::test_support::state::isolate_runtime_config;

    /// Minimal but complete source config JSON with a single `web-selector`
    /// source, an `indexed` subject format and a `no-channel` episode format.
    fn minimal_config_json(name: &str, tier: i32) -> String {
        format!(
            r#"{{
  "exportedMediaSourceDataList": {{
    "mediaSources": [
      {{
        "factoryId": "web-selector",
        "arguments": {{
          "name": "{name}",
          "tier": {tier},
          "searchConfig": {{
            "searchUrl": "https://src.example/search?q={{keyword}}",
            "selectorSubjectFormatIndexed": {{
              "selectNames": ".title",
              "selectLinks": ".title a"
            }},
            "selectorChannelFormatNoChannel": {{
              "selectEpisodes": ".ep a"
            }},
            "matchVideo": {{ "matchVideoUrl": "url=(?<v>[^\"]+\\.m3u8)" }}
          }}
        }}
      }}
    ]
  }}
}}"#
        )
    }

    #[test]
    fn search_config_deserializes_with_optional_fields_defaulted() {
        let json = r#"{
            "searchUrl": "https://x/search?q={keyword}",
            "matchVideo": { "matchVideoUrl": "m3u8" }
        }"#;
        let cfg: SearchConfig = serde_json::from_str(json).unwrap();
        assert_eq!(cfg.search_url, "https://x/search?q={keyword}");
        // Every optional selector / format id defaults to None.
        assert!(cfg.default_subtitle_language.is_none());
        assert!(cfg.default_resolution.is_none());
        assert!(cfg.subject_format_id.is_none());
        assert!(cfg.selector_subject_format_a.is_none());
        assert!(cfg.selector_subject_format_indexed.is_none());
        assert!(cfg.channel_format_id.is_none());
        assert!(cfg.selector_channel_format_flattened.is_none());
        assert!(cfg.selector_channel_format_no_channel.is_none());
        assert!(cfg.match_video.enable_nested_url.is_none());
        assert!(cfg.extra.is_empty());
    }

    #[test]
    fn unknown_config_fields_are_preserved_in_extra_for_forward_compat() {
        // Old/newer schemas may carry fields this build doesn't model. `flatten`
        // must keep them so a save-then-load round trip does not drop data.
        let json = r#"{
            "searchUrl": "https://x/s?q={keyword}",
            "matchVideo": { "matchVideoUrl": "m3u8", "futureKnob": 7 },
            "brandNewSelector": "div.x"
        }"#;
        let cfg: SearchConfig = serde_json::from_str(json).unwrap();
        assert_eq!(
            cfg.extra.get("brandNewSelector").and_then(|v| v.as_str()),
            Some("div.x")
        );
        assert_eq!(
            cfg.match_video
                .extra
                .get("futureKnob")
                .and_then(|v| v.as_i64()),
            Some(7)
        );

        // Re-serialize and confirm the unknown fields survive the round trip.
        let round = serde_json::to_string(&cfg).unwrap();
        assert!(round.contains("brandNewSelector"));
        assert!(round.contains("futureKnob"));
    }

    #[test]
    fn missing_required_search_url_fails_to_deserialize() {
        let json = r#"{ "matchVideo": { "matchVideoUrl": "m3u8" } }"#;
        assert!(serde_json::from_str::<SearchConfig>(json).is_err());
    }

    #[test]
    fn missing_required_match_video_fails_to_deserialize() {
        let json = r#"{ "searchUrl": "https://x" }"#;
        assert!(serde_json::from_str::<SearchConfig>(json).is_err());
    }

    #[test]
    fn captcha_config_requires_enable_and_defaults_rest() {
        let cfg: CaptchaConfig = serde_json::from_str(r#"{ "enable": true }"#).unwrap();
        assert!(cfg.enable);
        assert!(cfg.captcha_type.is_none());
        assert!(cfg.detect_selector.is_none());
        assert!(cfg.ocr_constraints.is_none());
        // Missing `enable` is an error — the field is not Option.
        assert!(serde_json::from_str::<CaptchaConfig>(r#"{}"#).is_err());
    }

    #[test]
    fn config_hash_is_deterministic_and_sensitive_to_search_config() {
        let root: SampleRoot = serde_json::from_str(&minimal_config_json("A", 1)).unwrap();
        let source = &root.exported_media_source_data_list.media_sources[0];
        let h1 = source_config_hash(source);
        let h2 = source_config_hash(source);
        assert_eq!(h1, h2, "hash must be stable for identical config");

        let mut changed = source.clone();
        changed.arguments.search_config.search_url = "https://other/{keyword}".to_string();
        assert_ne!(
            h1,
            source_config_hash(&changed),
            "changing the search config must change the hash"
        );
    }

    #[test]
    fn config_hash_ignores_non_search_fields_like_tier_and_name() {
        let root_a: SampleRoot = serde_json::from_str(&minimal_config_json("A", 1)).unwrap();
        let root_b: SampleRoot = serde_json::from_str(&minimal_config_json("B", 9)).unwrap();
        // Same search/captcha config, different name + tier → same hash, because
        // the episode-table cache key intentionally tracks only the parts that
        // affect parsing.
        assert_eq!(
            source_config_hash(&root_a.exported_media_source_data_list.media_sources[0]),
            source_config_hash(&root_b.exported_media_source_data_list.media_sources[0]),
        );
    }

    #[test]
    fn cache_round_trips_and_reports_missing_file() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );

        // No file yet → explicit error rather than a panic.
        assert!(load_from_cache().is_err());

        let content = minimal_config_json("源A", 2);
        save_to_cache(&content).unwrap();
        let loaded = load_from_cache().unwrap();
        assert_eq!(loaded, content);
    }

    #[tokio::test]
    async fn add_source_config_rejects_empty_name() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );

        let err = add_source_config(SourceConfigUpdate {
            name: String::new(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: None,
            captcha_config_json: None,
        })
        .await
        .unwrap_err();
        assert!(err.to_string().contains("cannot be empty"));
    }

    #[tokio::test]
    async fn add_source_config_creates_cache_then_rejects_duplicate() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );

        let make = |name: &str| SourceConfigUpdate {
            name: name.to_string(),
            new_name: None,
            tier: Some(3),
            default_subtitle_language: None,
            default_resolution: None,
            search_url: Some("https://x/s?q={keyword}".to_string()),
            icon_url: None,
            description: Some("desc".to_string()),
            search_config_json: None,
            captcha_config_json: None,
        };

        // First add creates the cache file from scratch (no pre-existing config).
        add_source_config(make("newsrc")).await.unwrap();
        let content = load_from_cache().unwrap();
        let root: SampleRoot = serde_json::from_str(&content).unwrap();
        assert_eq!(root.exported_media_source_data_list.media_sources.len(), 1);
        assert_eq!(
            root.exported_media_source_data_list.media_sources[0]
                .arguments
                .name,
            "newsrc"
        );

        // Second add with the same name is rejected.
        let err = add_source_config(make("newsrc")).await.unwrap_err();
        assert!(err.to_string().contains("already exists"));
    }

    #[tokio::test]
    async fn add_source_config_rejects_invalid_search_config_json() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );

        let err = add_source_config(SourceConfigUpdate {
            name: "bad".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            // Missing required `matchVideo` → invalid SearchConfig.
            search_config_json: Some(r#"{ "searchUrl": "https://x" }"#.to_string()),
            captcha_config_json: None,
        })
        .await
        .unwrap_err();
        assert!(err.to_string().contains("Invalid SearchConfig JSON"));
        // Nothing must have been persisted.
        assert!(load_from_cache().is_err());
    }

    #[tokio::test]
    async fn add_source_config_rejects_invalid_regex_and_selector_without_persisting() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );

        for search_config_json in [
            r#"{
                "searchUrl": "https://x/search?q={keyword}",
                "matchVideo": { "matchVideoUrl": "(" }
            }"#,
            r#"{
                "searchUrl": "https://x/search?q={keyword}",
                "selectorSubjectFormatIndexed": {
                    "selectNames": "li[",
                    "selectLinks": "a"
                },
                "matchVideo": { "matchVideoUrl": "m3u8" }
            }"#,
            r#"{
                "searchUrl": "https://x/search?q={keyword}",
                "selectorChannelFormatNoChannel": {
                    "selectEpisodes": "a.episode",
                    "matchEpisodeSortFromName": "("
                },
                "matchVideo": { "matchVideoUrl": "m3u8" }
            }"#,
        ] {
            let err = add_source_config(SourceConfigUpdate {
                name: "invalid".to_string(),
                new_name: None,
                tier: None,
                default_subtitle_language: None,
                default_resolution: None,
                search_url: None,
                icon_url: None,
                description: None,
                search_config_json: Some(search_config_json.to_string()),
                captcha_config_json: None,
            })
            .await
            .unwrap_err();
            assert!(
                err.to_string().contains("Invalid regex")
                    || err.to_string().contains("Invalid CSS selector")
            );
            assert!(load_from_cache().is_err());
        }

        let err = add_source_config(SourceConfigUpdate {
            name: "invalid-captcha".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: Some(
                r#"{
                    "searchUrl": "https://x/search?q={keyword}",
                    "matchVideo": { "matchVideoUrl": "m3u8" }
                }"#
                .to_string(),
            ),
            captcha_config_json: Some(
                r#"{ "enable": true, "detectSelector": "form[" }"#.to_string(),
            ),
        })
        .await
        .unwrap_err();
        assert!(err.to_string().contains("Invalid CSS selector"));
        assert!(load_from_cache().is_err());
    }

    #[tokio::test]
    async fn update_single_source_config_full_json_replace_and_not_found() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        save_to_cache(&minimal_config_json("src", 1)).unwrap();

        // Unknown source name is an error.
        let err = update_single_source_config(SourceConfigUpdate {
            name: "nope".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: None,
            captcha_config_json: None,
        })
        .await
        .unwrap_err();
        assert!(err.to_string().contains("Source not found"));

        // Replace the whole search config via JSON.
        update_single_source_config(SourceConfigUpdate {
            name: "src".to_string(),
            new_name: Some("src-renamed".to_string()),
            tier: Some(5),
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: Some(
                r#"{ "searchUrl": "https://new/s?q={keyword}", "matchVideo": { "matchVideoUrl": "new" } }"#
                    .to_string(),
            ),
            captcha_config_json: None,
        })
        .await
        .unwrap();

        let root: SampleRoot = serde_json::from_str(&load_from_cache().unwrap()).unwrap();
        let updated = &root.exported_media_source_data_list.media_sources[0];
        assert_eq!(updated.arguments.name, "src-renamed");
        assert_eq!(updated.arguments.tier, Some(5));
        assert_eq!(
            updated.arguments.search_config.search_url,
            "https://new/s?q={keyword}"
        );
        assert_eq!(
            updated.arguments.search_config.match_video.match_video_url,
            "new"
        );
    }

    #[tokio::test]
    async fn update_single_source_config_rejects_invalid_json_without_persisting() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        let original = minimal_config_json("src", 1);
        save_to_cache(&original).unwrap();

        let err = update_single_source_config(SourceConfigUpdate {
            name: "src".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: Some("{ not json".to_string()),
            captcha_config_json: None,
        })
        .await
        .unwrap_err();
        assert!(
            err.to_string()
                .contains("Invalid JSON format for search config")
        );
        // Cache must be untouched.
        assert_eq!(load_from_cache().unwrap(), original);
    }

    #[tokio::test]
    async fn update_single_source_config_rejects_invalid_selector_without_persisting() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        let original = minimal_config_json("src", 1);
        save_to_cache(&original).unwrap();

        let err = update_single_source_config(SourceConfigUpdate {
            name: "src".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: Some(
                r#"{
                    "searchUrl": "https://x/search?q={keyword}",
                    "selectorChannelFormatNoChannel": { "selectEpisodes": "div[" },
                    "matchVideo": { "matchVideoUrl": "m3u8" }
                }"#
                .to_string(),
            ),
            captcha_config_json: None,
        })
        .await
        .unwrap_err();

        assert!(err.to_string().contains("Invalid CSS selector"));
        assert_eq!(load_from_cache().unwrap(), original);
    }

    #[tokio::test]
    async fn update_single_source_config_single_field_backward_compat() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        save_to_cache(&minimal_config_json("src", 1)).unwrap();

        // Legacy single-field update path (no search_config_json).
        update_single_source_config(SourceConfigUpdate {
            name: "src".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: Some("zh-Hans".to_string()),
            default_resolution: Some("1080P".to_string()),
            search_url: Some("https://patched/s?q={keyword}".to_string()),
            icon_url: Some("https://patched/icon.png".to_string()),
            description: None,
            search_config_json: None,
            captcha_config_json: None,
        })
        .await
        .unwrap();

        let root: SampleRoot = serde_json::from_str(&load_from_cache().unwrap()).unwrap();
        let updated = &root.exported_media_source_data_list.media_sources[0];
        assert_eq!(
            updated
                .arguments
                .search_config
                .default_subtitle_language
                .as_deref(),
            Some("zh-Hans")
        );
        assert_eq!(
            updated
                .arguments
                .search_config
                .default_resolution
                .as_deref(),
            Some("1080P")
        );
        assert_eq!(
            updated.arguments.search_config.search_url,
            "https://patched/s?q={keyword}"
        );
        assert_eq!(
            updated.arguments.icon_url.as_deref(),
            Some("https://patched/icon.png")
        );
    }
}
