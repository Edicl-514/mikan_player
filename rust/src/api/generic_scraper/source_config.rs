use super::region::{detect_and_filter_root, detect_current_region_with_retry};
use super::types::*;
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
        serde_json::from_str::<SearchConfig>(json)
            .map_err(|e| anyhow::anyhow!("Invalid SearchConfig JSON: {}", e))?
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
        Some(
            serde_json::from_str::<CaptchaConfig>(json)
                .map_err(|e| anyhow::anyhow!("Invalid CaptchaConfig JSON: {}", e))?,
        )
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
