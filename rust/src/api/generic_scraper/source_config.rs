use super::region::{detect_and_filter_root, detect_current_region_with_retry};
use super::types::*;
use scraper::Selector;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
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
/// Subscription JSON is considered fresh for 3 days; after that, auto-refresh
/// replaces subscription sources (manual sources are always preserved).
pub(crate) const SUBSCRIPTION_REFRESH_TTL_MS: u64 = 3 * 24 * 60 * 60 * 1000;

/// Sidecar metadata for the on-disk playback source cache.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct PlaybackSourcesMeta {
    /// Unix ms when subscription sources were last successfully pulled.
    #[serde(default)]
    last_subscription_refresh_ms: u64,
    /// Subscription URL that produced the cached subscription sources.
    #[serde(default)]
    subscription_url: String,
    /// True once we have applied remote `defaultEnabled` to local toggles
    /// at least once (first successful subscription pull). Subsequent auto
    /// refreshes must not re-sync switches.
    #[serde(default)]
    default_enabled_applied: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SubscriptionRefreshKind {
    Automatic,
    Manual,
}

/// 获取播放源配置缓存文件路径
pub(super) fn get_cache_file_path() -> anyhow::Result<std::path::PathBuf> {
    let base_dir = std::path::PathBuf::from(crate::api::config::get_cache_dir());

    // 确保目录存在
    if !base_dir.exists() {
        fs::create_dir_all(&base_dir)?;
    }

    Ok(base_dir.join("playback_sources_cache.json"))
}

fn get_meta_file_path() -> anyhow::Result<std::path::PathBuf> {
    let base_dir = std::path::PathBuf::from(crate::api::config::get_cache_dir());
    if !base_dir.exists() {
        fs::create_dir_all(&base_dir)?;
    }
    Ok(base_dir.join("playback_sources_meta.json"))
}

fn load_meta() -> PlaybackSourcesMeta {
    match get_meta_file_path() {
        Ok(path) if path.exists() => fs::read_to_string(&path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default(),
        _ => PlaybackSourcesMeta::default(),
    }
}

fn save_meta(meta: &PlaybackSourcesMeta) -> anyhow::Result<()> {
    let path = get_meta_file_path()?;
    let content = serde_json::to_string_pretty(meta)?;
    fs::write(&path, content)?;
    Ok(())
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

/// Tag every source pulled from a remote subscription as `Subscription`.
fn mark_sources_as_subscription(root: &mut SampleRoot) {
    for source in &mut root.exported_media_source_data_list.media_sources {
        source.arguments.source_origin = SourceOrigin::Subscription;
    }
}

/// Merge remote subscription sources with local manual sources.
/// Manual sources are always preserved and win name clashes; subscription
/// sources are fully replaced by the remote set.
///
/// `preserve_legacy_local_only`: when true (first refresh after upgrading from a
/// build that did not tag origins), local-only entries are retained for one
/// migration cycle. They remain subscription/read-only entries instead of being
/// permanently misclassified as manual, so a later refresh can remove stale
/// subscription entries.
fn merge_subscription_with_manual(
    remote: SampleRoot,
    local: Option<SampleRoot>,
    preserve_legacy_local_only: bool,
) -> SampleRoot {
    let mut remote = remote;
    mark_sources_as_subscription(&mut remote);

    let Some(local) = local else {
        return remote;
    };

    let remote_names: HashSet<String> = remote
        .exported_media_source_data_list
        .media_sources
        .iter()
        .map(|s| s.arguments.name.clone())
        .collect();

    let preserved_local_sources: Vec<MediaSource> = local
        .exported_media_source_data_list
        .media_sources
        .into_iter()
        .filter_map(|s| {
            if s.arguments.source_origin.is_manual() {
                return Some(s);
            }
            if preserve_legacy_local_only && !remote_names.contains(&s.arguments.name) {
                // Preserve an untagged local-only entry for one migration cycle,
                // but keep it read-only instead of claiming it is user-created.
                return Some(s);
            }
            None
        })
        .collect();

    let manual_names: HashSet<String> = preserved_local_sources
        .iter()
        .filter(|source| source.arguments.source_origin.is_manual())
        .map(|source| source.arguments.name.clone())
        .collect();

    if !manual_names.is_empty() {
        remote
            .exported_media_source_data_list
            .media_sources
            .retain(|source| !manual_names.contains(&source.arguments.name));
    }

    if !preserved_local_sources.is_empty() {
        log::info!(
            "Preserving {} local source(s) across subscription refresh",
            preserved_local_sources.len()
        );
        remote
            .exported_media_source_data_list
            .media_sources
            .extend(preserved_local_sources);
    }

    remote
}

fn parse_local_root() -> Option<SampleRoot> {
    load_from_cache()
        .ok()
        .and_then(|content| serde_json::from_str::<SampleRoot>(&content).ok())
}

fn should_apply_default_enabled(
    kind: SubscriptionRefreshKind,
    meta: &PlaybackSourcesMeta,
    has_local_cache: bool,
) -> bool {
    kind == SubscriptionRefreshKind::Manual || (!meta.default_enabled_applied && !has_local_cache)
}

fn subscription_cache_needs_refresh(
    meta: &PlaybackSourcesMeta,
    current_subscription_url: &str,
    now_ms: u64,
) -> bool {
    meta.last_subscription_refresh_ms == 0
        || meta.subscription_url != current_subscription_url
        || now_ms.saturating_sub(meta.last_subscription_refresh_ms) >= SUBSCRIPTION_REFRESH_TTL_MS
}

/// 从订阅地址刷新播放源配置并保存到本地缓存。
///
/// 只替换订阅源，本地手动添加的源会被保留。手动刷新会同步远端开关；
/// 自动刷新仅在首次拉取时请求同步开关。
async fn refresh_playback_source_config_with_kind(
    kind: SubscriptionRefreshKind,
) -> anyhow::Result<RefreshPlaybackSourcesResult> {
    let sub_url = crate::api::config::get_playback_sub_url();
    log::info!("Refreshing playback source config from: {}", sub_url);

    let resp = crate::api::network::retry_request("refresh_playback_source_config", |client| {
        client.get(&sub_url)
    })
    .await?;
    let content = resp.text().await?;
    log::info!("Successfully fetched config from subscription URL");

    // 验证JSON格式
    let remote: SampleRoot = serde_json::from_str(&content)?;
    log::info!("Playback source config validated successfully");

    let local = parse_local_root();
    let mut meta = load_meta();
    let apply_default_enabled = should_apply_default_enabled(kind, &meta, local.is_some());
    // Legacy caches (no meta / never refreshed under the new scheme) may hold
    // untagged local-only entries. Preserve them for one migration cycle.
    let preserve_legacy_local_only = meta.last_subscription_refresh_ms == 0;

    let merged = merge_subscription_with_manual(remote, local, preserve_legacy_local_only);
    let new_content = serde_json::to_string_pretty(&merged)?;
    save_to_cache(&new_content)?;

    meta.last_subscription_refresh_ms = current_timestamp_ms();
    meta.subscription_url = sub_url;
    meta.default_enabled_applied = true;
    if let Err(e) = save_meta(&meta) {
        log::warn!("Failed to save playback sources meta: {e}");
    }

    invalidate_source_config_cache();

    Ok(RefreshPlaybackSourcesResult {
        content: new_content,
        apply_default_enabled,
    })
}

/// User-requested refresh. Unlike automatic refresh, this reapplies the remote
/// `defaultEnabled` values to preserve the existing refresh-button behavior.
pub(crate) async fn refresh_playback_source_config() -> anyhow::Result<RefreshPlaybackSourcesResult>
{
    refresh_playback_source_config_with_kind(SubscriptionRefreshKind::Manual).await
}

/// 预加载播放源配置（应用启动时调用）。
///
/// - 无本地缓存 → 从订阅地址拉取
/// - 有缓存且订阅超过 3 天未刷新 → 后台合并刷新（失败则继续用旧缓存）
/// - 有缓存且仍在有效期内 → 仅校验本地 JSON
pub(crate) async fn preload_playback_sources() -> anyhow::Result<()> {
    let _ = detect_current_region_with_retry(2).await;

    match load_from_cache() {
        Ok(content) => {
            // 验证JSON格式
            let _root: SampleRoot = serde_json::from_str(&content)?;
            log::info!("Playback source config loaded from cache and validated");

            let meta = load_meta();
            let now = current_timestamp_ms();
            let age = now.saturating_sub(meta.last_subscription_refresh_ms);
            let subscription_url = crate::api::config::get_playback_sub_url();
            // Missing meta, changed subscription URL, or expired cache → refresh.
            let needs_refresh = subscription_cache_needs_refresh(&meta, &subscription_url, now);

            if needs_refresh {
                log::info!(
                    "Subscription cache expired or meta missing (age={}ms, ttl={}ms); auto-refreshing",
                    age,
                    SUBSCRIPTION_REFRESH_TTL_MS
                );
                match refresh_playback_source_config_with_kind(SubscriptionRefreshKind::Automatic)
                    .await
                {
                    Ok(result) => {
                        log::info!(
                            "Auto-refreshed subscription sources (apply_default_enabled={})",
                            result.apply_default_enabled
                        );
                    }
                    Err(e) => {
                        // Keep serving the existing cache; do not fail startup.
                        log::warn!(
                            "Auto-refresh of subscription sources failed, keeping cache: {e}"
                        );
                    }
                }
            }

            Ok(())
        }
        Err(e) => {
            // 缓存不存在，从网络拉取
            log::warn!("Failed to load from cache: {}, fetching from network...", e);
            refresh_playback_source_config_with_kind(SubscriptionRefreshKind::Automatic).await?;
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
        let is_manual = source.arguments.source_origin.is_manual();
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
            is_manual,
        });
    }
    Ok(sources)
}

/// 更新单个源的配置。
///
/// Subscription sources are read-only: their content can only be replaced by a
/// subscription refresh. Manual sources remain fully editable.
pub(crate) async fn update_single_source_config(update: SourceConfigUpdate) -> anyhow::Result<()> {
    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;
    let mut root: SampleRoot = serde_json::from_str(&content)?;

    let mut found = false;
    for source in &mut root.exported_media_source_data_list.media_sources {
        if source.arguments.name == update.name {
            if !source.arguments.source_origin.is_manual() {
                return Err(anyhow::anyhow!(
                    "Subscription source '{}' is read-only; only manual sources can be edited",
                    update.name
                ));
            }

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

            // Ensure the origin flag stays manual after edit.
            source.arguments.source_origin = SourceOrigin::Manual;
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

/// 添加新的源配置（始终标记为手动源）
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
            source_origin: SourceOrigin::Manual,
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

    fn seed_manual_source(name: &str, tier: i32) {
        let mut root: SampleRoot = serde_json::from_str(&minimal_config_json(name, tier)).unwrap();
        root.exported_media_source_data_list.media_sources[0]
            .arguments
            .source_origin = SourceOrigin::Manual;
        save_to_cache(&serde_json::to_string_pretty(&root).unwrap()).unwrap();
    }

    #[tokio::test]
    async fn update_single_source_config_full_json_replace_and_not_found() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        seed_manual_source("src", 1);

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
        assert!(updated.arguments.source_origin.is_manual());
    }

    #[tokio::test]
    async fn update_single_source_config_rejects_subscription_source() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        // minimal_config_json has default origin = subscription
        save_to_cache(&minimal_config_json("sub-src", 1)).unwrap();

        let err = update_single_source_config(SourceConfigUpdate {
            name: "sub-src".to_string(),
            new_name: None,
            tier: Some(9),
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
        assert!(err.to_string().contains("read-only"));

        let root: SampleRoot = serde_json::from_str(&load_from_cache().unwrap()).unwrap();
        assert_eq!(
            root.exported_media_source_data_list.media_sources[0]
                .arguments
                .tier,
            Some(1),
            "subscription source must not be mutated"
        );
    }

    #[test]
    fn merge_preserves_manual_and_replaces_subscription() {
        let remote: SampleRoot = serde_json::from_str(&minimal_config_json("remote-a", 1)).unwrap();

        let mut local: SampleRoot =
            serde_json::from_str(&minimal_config_json("local-sub", 2)).unwrap();
        // One subscription source that should be dropped, one manual kept.
        local.exported_media_source_data_list.media_sources[0]
            .arguments
            .source_origin = SourceOrigin::Subscription;
        let mut manual: MediaSource =
            local.exported_media_source_data_list.media_sources[0].clone();
        manual.arguments.name = "manual-only".to_string();
        manual.arguments.source_origin = SourceOrigin::Manual;
        local
            .exported_media_source_data_list
            .media_sources
            .push(manual);

        let merged = merge_subscription_with_manual(remote, Some(local), false);
        let names: Vec<_> = merged
            .exported_media_source_data_list
            .media_sources
            .iter()
            .map(|s| (s.arguments.name.as_str(), s.arguments.source_origin))
            .collect();
        assert_eq!(names.len(), 2);
        assert!(names.contains(&("remote-a", SourceOrigin::Subscription)));
        assert!(names.contains(&("manual-only", SourceOrigin::Manual)));
        assert!(!names.iter().any(|(n, _)| *n == "local-sub"));
    }

    #[test]
    fn merge_legacy_keeps_untagged_local_only_read_only_for_one_cycle() {
        let remote: SampleRoot = serde_json::from_str(&minimal_config_json("remote-a", 1)).unwrap();
        // Untagged local-only (defaults to subscription origin).
        let local: SampleRoot =
            serde_json::from_str(&minimal_config_json("user-added", 2)).unwrap();

        let merged = merge_subscription_with_manual(remote, Some(local), true);
        let names: Vec<_> = merged
            .exported_media_source_data_list
            .media_sources
            .iter()
            .map(|s| (s.arguments.name.as_str(), s.arguments.source_origin))
            .collect();
        assert_eq!(names.len(), 2);
        assert!(names.contains(&("remote-a", SourceOrigin::Subscription)));
        assert!(names.contains(&("user-added", SourceOrigin::Subscription)));

        let next_remote: SampleRoot =
            serde_json::from_str(&minimal_config_json("remote-a", 3)).unwrap();
        let merged_again = merge_subscription_with_manual(next_remote, Some(merged), false);
        assert_eq!(
            merged_again
                .exported_media_source_data_list
                .media_sources
                .len(),
            1
        );
        assert_eq!(
            merged_again.exported_media_source_data_list.media_sources[0]
                .arguments
                .name,
            "remote-a"
        );
    }

    #[test]
    fn merge_remote_name_clash_preserves_manual_with_same_name() {
        let remote: SampleRoot = serde_json::from_str(&minimal_config_json("clash", 1)).unwrap();
        let mut local: SampleRoot = serde_json::from_str(&minimal_config_json("clash", 9)).unwrap();
        local.exported_media_source_data_list.media_sources[0]
            .arguments
            .source_origin = SourceOrigin::Manual;

        let merged = merge_subscription_with_manual(remote, Some(local), false);
        assert_eq!(
            merged.exported_media_source_data_list.media_sources.len(),
            1
        );
        let only = &merged.exported_media_source_data_list.media_sources[0];
        assert_eq!(only.arguments.name, "clash");
        assert_eq!(only.arguments.source_origin, SourceOrigin::Manual);
        assert_eq!(only.arguments.tier, Some(9));
    }

    #[test]
    fn cache_freshness_is_scoped_to_subscription_url() {
        let now = 10 * SUBSCRIPTION_REFRESH_TTL_MS;
        let meta = PlaybackSourcesMeta {
            last_subscription_refresh_ms: now - 1_000,
            subscription_url: "https://a.example/sub.json".to_string(),
            default_enabled_applied: true,
        };

        assert!(!subscription_cache_needs_refresh(
            &meta,
            "https://a.example/sub.json",
            now
        ));
        assert!(subscription_cache_needs_refresh(
            &meta,
            "https://b.example/sub.json",
            now
        ));

        let expired_at = meta.last_subscription_refresh_ms + SUBSCRIPTION_REFRESH_TTL_MS;
        assert!(subscription_cache_needs_refresh(
            &meta,
            "https://a.example/sub.json",
            expired_at
        ));
    }

    #[test]
    fn manual_refresh_syncs_switches_but_automatic_refresh_preserves_them() {
        let already_initialized = PlaybackSourcesMeta {
            last_subscription_refresh_ms: 1,
            subscription_url: "https://a.example/sub.json".to_string(),
            default_enabled_applied: true,
        };
        assert!(should_apply_default_enabled(
            SubscriptionRefreshKind::Manual,
            &already_initialized,
            true
        ));
        assert!(!should_apply_default_enabled(
            SubscriptionRefreshKind::Automatic,
            &already_initialized,
            true
        ));

        assert!(should_apply_default_enabled(
            SubscriptionRefreshKind::Automatic,
            &PlaybackSourcesMeta::default(),
            false
        ));
    }

    #[tokio::test]
    async fn update_single_source_config_rejects_invalid_json_without_persisting() {
        let _guard = isolate_runtime_config();
        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        seed_manual_source("src", 1);
        let original = load_from_cache().unwrap();

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
        seed_manual_source("src", 1);
        let original = load_from_cache().unwrap();

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
        seed_manual_source("src", 1);

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
