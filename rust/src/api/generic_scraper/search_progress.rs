use super::episode_table::*;
use super::headers_cookies::*;
use super::matching::*;
use super::region::*;
use super::source_config::*;
use super::types::*;
use scraper::{Html, Selector};
use std::fs;

trait ProgressEmitter {
    fn emit(&self, progress: SourceSearchProgress) -> bool;
}

impl ProgressEmitter for crate::frb_generated::StreamSink<SourceSearchProgress> {
    fn emit(&self, progress: SourceSearchProgress) -> bool {
        self.add(progress).is_ok()
    }
}

async fn run_source_with_progress<E: ProgressEmitter + ?Sized>(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    emitter: &E,
    runtime_override: Option<&SourceRuntimeOverride>,
) -> anyhow::Result<()> {
    let source_name = source.arguments.name.clone();
    if !emitter.emit(SourceSearchProgress {
        source_name: source_name.clone(),
        step: SearchStep::Searching,
        error: None,
        play_page_url: None,
        video_regex: None,
        direct_video_url: None,
        cookies: None,
        headers: None,
        channel_name: None,
        channel_index: None,
        all_channels: None,
        captcha_config_json: None,
        enable_nested_url: false,
        match_nested_url: None,
    }) {
        return Ok(());
    }

    if let Some(skip_error) = runtime_override.and_then(|item| item.skip_search_error.clone()) {
        emitter.emit(SourceSearchProgress {
            source_name,
            step: SearchStep::Failed,
            error: Some(skip_error),
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            all_channels: None,
            captcha_config_json: None,
            enable_nested_url: false,
            match_nested_url: None,
        });
        return Ok(());
    }

    search_single_source_with_progress(
        client,
        source,
        anime_name,
        absolute_episode,
        relative_episode,
        emitter,
        runtime_override,
    )
    .await
}

/// 获取所有已启用源的列表（用于初始化UI显示）
pub(crate) async fn get_enabled_source_names() -> anyhow::Result<Vec<String>> {
    let sources = load_enabled_sources().await?;
    let names: Vec<String> = sources.iter().map(|s| s.arguments.name.clone()).collect();
    Ok(names)
}

/// 搜索所有源，以流的形式返回详细进度（包含搜索步骤和错误信息）
pub(crate) async fn generic_search_with_progress(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<SourceSearchProgress>,
) -> anyhow::Result<()> {
    generic_search_with_progress_runtime(
        anime_name,
        absolute_episode,
        relative_episode,
        None,
        Vec::new(),
        sink,
    )
    .await
}

/// 搜索指定源，以流的形式返回详细进度
///
/// # 参数
/// * `target_source_names` - 目标源名称列表。为 None 或空时搜索所有已启用源；
///   非空时只搜索列表中列出的源，跳过不在列表中的源（不创建 skip 异步任务）。
/// * `runtime_overrides` - 运行时覆盖，仅对列表中的源生效。
pub(crate) async fn generic_search_with_progress_runtime(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    target_source_names: Option<Vec<String>>,
    runtime_overrides: Vec<SourceRuntimeOverride>,
    sink: crate::frb_generated::StreamSink<SourceSearchProgress>,
) -> anyhow::Result<()> {
    let client = crate::api::network::get_shared_client().clone();

    let runtime_override_map: std::collections::HashMap<_, _> = runtime_overrides
        .into_iter()
        .map(|item| (item.source_name.clone(), item))
        .collect();

    let target_set: Option<std::collections::HashSet<_>> =
        target_source_names.map(|names| names.into_iter().collect());

    // 1. Load enabled sources (with in-memory cache)
    let mut sources = load_enabled_sources().await?;

    // If target_source_names is specified, filter to only those sources
    if let Some(ref ts) = target_set {
        sources.retain(|source| ts.contains(&source.arguments.name));
        log::info!(
            "Filtered to {} target sources out of enabled sources",
            sources.len()
        );
    }

    // 2. Prepare stream
    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream = futures::stream::iter(sources)
        .map(|source| {
            let client = client.clone();
            let anime_name = anime_name.clone();
            let sink = sink.clone();
            let runtime_override = runtime_override_map.get(&source.arguments.name).cloned();
            async move {
                run_source_with_progress(
                    &client,
                    &source,
                    &anime_name,
                    absolute_episode,
                    relative_episode,
                    &sink,
                    runtime_override.as_ref(),
                )
                .await
            }
        })
        .buffer_unordered(limit);

    // 3. Drive the stream
    let mut stream = Box::pin(stream);
    while let Some(_) = stream.next().await {}

    Ok(())
}

/// 调试用途：从本地 JSON 文件加载播放源配置并执行搜索
///
/// 说明：
/// - 只读取指定本地 JSON 文件，不读取也不写入缓存文件
/// - 不修改订阅设置，不影响正式播放流程
/// - 可选按源名称过滤（大小写不敏感，包含匹配）
pub(crate) async fn debug_search_with_local_json(
    json_path: String,
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    source_name_filter: Option<String>,
    sink: crate::frb_generated::StreamSink<SourceSearchProgress>,
) -> anyhow::Result<()> {
    debug_search_with_local_json_runtime(
        json_path,
        anime_name,
        absolute_episode,
        relative_episode,
        source_name_filter,
        Vec::new(),
        sink,
    )
    .await
}

pub(crate) async fn debug_search_with_local_json_runtime(
    json_path: String,
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    source_name_filter: Option<String>,
    runtime_overrides: Vec<SourceRuntimeOverride>,
    sink: crate::frb_generated::StreamSink<SourceSearchProgress>,
) -> anyhow::Result<()> {
    let client = crate::api::network::get_shared_client().clone();

    let content = fs::read_to_string(&json_path)
        .map_err(|e| anyhow::anyhow!("Failed to read local JSON file '{}': {}", json_path, e))?;
    let root: SampleRoot = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Failed to parse local JSON file '{}': {}", json_path, e))?;
    let root = detect_and_filter_root(root).await;
    let runtime_override_map: std::collections::HashMap<_, _> = runtime_overrides
        .into_iter()
        .map(|item| (item.source_name.clone(), item))
        .collect();

    let normalized_filter = source_name_filter
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase());

    let mut sources: Vec<_> = root
        .exported_media_source_data_list
        .media_sources
        .into_iter()
        .filter(|source| {
            if let Some(filter) = &normalized_filter {
                source.arguments.name.to_lowercase().contains(filter)
            } else {
                true
            }
        })
        .collect();

    if sources.is_empty() {
        let filter_desc = normalized_filter.unwrap_or_default();
        if filter_desc.is_empty() {
            return Err(anyhow::anyhow!(
                "No source found in local JSON: {}",
                json_path
            ));
        }
        return Err(anyhow::anyhow!(
            "No source matched filter '{}' in local JSON: {}",
            filter_desc,
            json_path
        ));
    }

    sources.sort_by_key(|s| s.arguments.tier.unwrap_or(1));

    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream = futures::stream::iter(sources)
        .map(|source| {
            let client = client.clone();
            let anime_name = anime_name.clone();
            let sink = sink.clone();
            let runtime_override = runtime_override_map.get(&source.arguments.name).cloned();
            async move {
                run_source_with_progress(
                    &client,
                    &source,
                    &anime_name,
                    absolute_episode,
                    relative_episode,
                    &sink,
                    runtime_override.as_ref(),
                )
                .await
            }
        })
        .buffer_unordered(limit);

    let mut stream = Box::pin(stream);
    while let Some(_) = stream.next().await {}

    Ok(())
}

/// 搜索单个源（带进度报告）
async fn search_single_source_with_progress(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: &(impl ProgressEmitter + ?Sized),
    runtime_override: Option<&SourceRuntimeOverride>,
) -> anyhow::Result<()> {
    let source_name = source.arguments.name.clone();
    let video_regex = source
        .arguments
        .search_config
        .match_video
        .match_video_url
        .clone();
    let configured_cookies = source.arguments.search_config.match_video.cookies.clone();
    let headers = source
        .arguments
        .search_config
        .match_video
        .add_headers_to_video
        .clone();
    let runtime_cookies = runtime_override.and_then(|item| item.cookies.as_deref());
    let effective_cookies = merge_cookie_strings(configured_cookies.as_deref(), runtime_cookies);
    let initial_search_page_html = runtime_override
        .and_then(|item| item.search_page_html.clone())
        .filter(|item| !item.is_empty());
    let initial_search_page_url = runtime_override
        .and_then(|item| item.search_page_url.clone())
        .filter(|item| !item.is_empty());
    let initial_detail_page_html = runtime_override
        .and_then(|item| item.detail_page_html.clone())
        .filter(|item| !item.is_empty());
    let initial_detail_page_url = runtime_override
        .and_then(|item| item.detail_page_url.clone())
        .filter(|item| !item.is_empty());
    let captcha_config_json = source
        .arguments
        .captcha_config
        .as_ref()
        .map(|c| serde_json::to_string(c).unwrap_or_default());

    let config_hash = source_config_hash(source);
    if initial_detail_page_html.is_none() {
        if let Some(cache) = load_episode_table_cache(&source_name, anime_name, config_hash) {
            let selected_channel_index = cache.channels.first().map(|channel| channel.index);
            let selected_channel_name = cache.channels.first().map(|channel| channel.name.clone());
            if let Some(episode) = select_episode_from_table(
                &cache.episodes,
                selected_channel_index,
                absolute_episode,
                relative_episode,
            ) {
                let all_channels = if cache.channels.is_empty() {
                    None
                } else {
                    Some(cache.channels.clone())
                };
                let cookies = effective_cookies.clone().or(cache.cookies.clone());
                let headers = cache.headers.clone().or(headers.clone());

                if !sink.emit(SourceSearchProgress {
                    source_name: source_name.clone(),
                    step: SearchStep::FetchingEpisodes,
                    error: None,
                    play_page_url: None,
                    video_regex: None,
                    direct_video_url: None,
                    cookies: cookies.clone(),
                    headers: headers.clone(),
                    channel_name: selected_channel_name.clone(),
                    channel_index: selected_channel_index,
                    all_channels: all_channels.clone(),
                    captcha_config_json: captcha_config_json.clone(),
                    enable_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .enable_nested_url
                        .unwrap_or(false),
                    match_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .match_nested_url
                        .clone(),
                }) {
                    return Ok(());
                }

                if !sink.emit(SourceSearchProgress {
                    source_name: source_name.clone(),
                    step: SearchStep::ExtractingVideo,
                    error: None,
                    play_page_url: Some(episode.url.clone()),
                    video_regex: Some(cache.video_regex.clone()),
                    direct_video_url: None,
                    cookies: cookies.clone(),
                    headers: headers.clone(),
                    channel_name: selected_channel_name.clone(),
                    channel_index: selected_channel_index,
                    all_channels: all_channels.clone(),
                    captcha_config_json: captcha_config_json.clone(),
                    enable_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .enable_nested_url
                        .unwrap_or(false),
                    match_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .match_nested_url
                        .clone(),
                }) {
                    return Ok(());
                }

                sink.emit(SourceSearchProgress {
                    source_name: source_name.clone(),
                    step: SearchStep::Success,
                    error: None,
                    play_page_url: Some(episode.url.clone()),
                    video_regex: Some(cache.video_regex),
                    direct_video_url: None,
                    cookies,
                    headers,
                    channel_name: selected_channel_name,
                    channel_index: selected_channel_index,
                    all_channels,
                    captcha_config_json,
                    enable_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .enable_nested_url
                        .unwrap_or(false),
                    match_nested_url: source
                        .arguments
                        .search_config
                        .match_video
                        .match_nested_url
                        .clone(),
                });
                return Ok(());
            }
        }
    }

    let search_candidates = build_search_candidates(anime_name);

    // Collect ranked subject candidates from search pages (alias queries as fallback).
    // Prefer the first alias query that yields any above-threshold hits; then try detail
    // pages in score order so empty-channel duplicates don't block playable siblings.
    let mut ranked_subjects: Vec<SubjectCandidate> = Vec::new();
    let mut search_page_url_for_referer = String::new();
    // Only surface a network/fetch error when every search request failed.
    // A later successful response must not keep a stale earlier failure.
    let mut last_search_fetch_error: Option<String> = None;
    let mut any_search_fetch_ok = false;

    for (idx, query_name) in search_candidates.iter().enumerate() {
        if idx > 0 {
            log::info!(
                "[{}] No results found, retrying with alias: '{}'",
                source_name,
                query_name
            );
        }

        let search_term = preprocess_search_term(query_name);
        let core_name = extract_core_name(query_name);

        let search_url = source
            .arguments
            .search_config
            .search_url
            .replace("{keyword}", &search_term);
        let search_fetch = if idx == 0 {
            if let Some(html) = initial_search_page_html.clone() {
                Ok((
                    html,
                    initial_search_page_url
                        .clone()
                        .unwrap_or_else(|| search_url.clone()),
                ))
            } else {
                match apply_browser_page_headers(
                    apply_cookie_header(client.get(&search_url), effective_cookies.as_deref()),
                    &search_url,
                    None,
                )
                .send()
                .await
                {
                    Ok(resp) => match resp.text().await {
                        Ok(text) => Ok((text, search_url.clone())),
                        Err(e) => Err(format!("搜索请求失败: {}", e)),
                    },
                    Err(e) => Err(format!("网络错误: {}", e)),
                }
            }
        } else {
            match apply_browser_page_headers(
                apply_cookie_header(client.get(&search_url), effective_cookies.as_deref()),
                &search_url,
                None,
            )
            .send()
            .await
            {
                Ok(resp) => match resp.text().await {
                    Ok(text) => Ok((text, search_url.clone())),
                    Err(e) => Err(format!("搜索请求失败: {}", e)),
                },
                Err(e) => Err(format!("网络错误: {}", e)),
            }
        };

        let (resp_text, response_search_url) = match search_fetch {
            Ok(v) => {
                any_search_fetch_ok = true;
                last_search_fetch_error = None;
                v
            }
            Err(e) => {
                last_search_fetch_error = Some(e);
                continue;
            }
        };

        search_page_url_for_referer = response_search_url.clone();

        let format_id = source
            .arguments
            .search_config
            .subject_format_id
            .as_deref()
            .unwrap_or("indexed");

        let document = Html::parse_document(&resp_text);
        let sel_result = select_best_subject_candidate(&document, source, query_name, &core_name);
        log_subject_selection(&source_name, format_id, query_name, &core_name, &sel_result);

        if !sel_result.ranked.is_empty() {
            ranked_subjects = sel_result
                .ranked
                .into_iter()
                .map(|c| SubjectCandidate {
                    title: c.title,
                    url: absolutize_url(&response_search_url, &c.url),
                    score: c.score,
                })
                .collect();
            break;
        }
    }

    // When WebView already supplied a concrete detail URL, pin it as the first try.
    if let Some(forced) = initial_detail_page_url
        .clone()
        .filter(|item| !item.is_empty())
    {
        ranked_subjects.retain(|c| c.url != forced);
        ranked_subjects.insert(
            0,
            SubjectCandidate {
                title: String::new(),
                url: forced,
                score: i32::MAX,
            },
        );
    }

    if ranked_subjects.is_empty() {
        let error = if !any_search_fetch_ok {
            last_search_fetch_error.unwrap_or_else(|| "网络错误".to_string())
        } else {
            "未找到匹配的动画".to_string()
        };
        sink.emit(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::Failed,
            error: Some(error),
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            all_channels: None,
            captcha_config_json: None,
            enable_nested_url: false,
            match_nested_url: None,
        });
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    let retry_limit = subject_retry_limit(ranked_subjects.len());
    log::info!(
        "[{}] Trying up to {} subject detail candidate(s)",
        source_name,
        retry_limit
    );

    let mut channels: Vec<ChannelInfo> = Vec::new();
    let mut episode_url = String::new();
    let mut selected_channel_name: Option<String> = None;
    let mut selected_channel_index: Option<usize> = None;
    let mut last_detail_error: Option<String> = None;

    for (try_idx, candidate) in ranked_subjects.iter().take(retry_limit).enumerate() {
        let detail_url = candidate.url.clone();

        if try_idx > 0 {
            log::info!(
                "[{}] Falling back to next subject candidate #{}: '{}' (score={}) url={}",
                source_name,
                try_idx + 1,
                candidate.title,
                candidate.score,
                detail_url
            );
        } else {
            log::info!(
                "[{}] Trying top subject candidate: '{}' (score={}) url={}",
                source_name,
                candidate.title,
                candidate.score,
                detail_url
            );
        }

        // Step 2: 获取详情页
        if !sink.emit(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::FetchingDetail,
            error: None,
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            all_channels: None,
            captcha_config_json: None,
            enable_nested_url: false,
            match_nested_url: None,
        }) {
            return Ok(());
        }

        // Only the first attempt may use the injected WebView HTML — subsequent
        // candidates need a live fetch for their own detail URLs.
        let detail_resp_text = if try_idx == 0 {
            if let Some(html) = initial_detail_page_html.clone() {
                log::info!(
                    "[{}] Using detail page HTML captured from WebView",
                    source_name
                );
                Ok(html)
            } else {
                match apply_browser_page_headers(
                    apply_cookie_header(client.get(&detail_url), effective_cookies.as_deref()),
                    &detail_url,
                    runtime_override
                        .as_ref()
                        .and_then(|item| item.search_page_url.as_deref())
                        .or(if search_page_url_for_referer.is_empty() {
                            None
                        } else {
                            Some(search_page_url_for_referer.as_str())
                        }),
                )
                .send()
                .await
                {
                    Ok(resp) => match resp.text().await {
                        Ok(text) => Ok(text),
                        Err(e) => Err(format!("获取详情页失败: {}", e)),
                    },
                    Err(e) => Err(format!("详情页网络错误: {}", e)),
                }
            }
        } else {
            match apply_browser_page_headers(
                apply_cookie_header(client.get(&detail_url), effective_cookies.as_deref()),
                &detail_url,
                if search_page_url_for_referer.is_empty() {
                    None
                } else {
                    Some(search_page_url_for_referer.as_str())
                },
            )
            .send()
            .await
            {
                Ok(resp) => match resp.text().await {
                    Ok(text) => Ok(text),
                    Err(e) => Err(format!("获取详情页失败: {}", e)),
                },
                Err(e) => Err(format!("详情页网络错误: {}", e)),
            }
        };

        let detail_resp_text = match detail_resp_text {
            Ok(text) => text,
            Err(e) => {
                last_detail_error = Some(e);
                continue;
            }
        };

        // Step 3: 获取剧集列表
        if !sink.emit(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::FetchingEpisodes,
            error: None,
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            all_channels: None,
            captcha_config_json: None,
            enable_nested_url: false,
            match_nested_url: None,
        }) {
            return Ok(());
        }

        // 解析所有channels (使用代码块确保Html在await前被drop)
        let parse_result = {
            let detail_doc = Html::parse_document(&detail_resp_text);
            let mut channels: Vec<ChannelInfo> = Vec::new();
            let mut episode_url = String::new();
            let mut selected_channel_name: Option<String> = None;
            let mut selected_channel_index: Option<usize> = None;

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
                    // 1. 获取所有channel名称
                    if let Some(ref channel_selector) = format.select_channel_names {
                        if !channel_selector.is_empty() {
                            if let Ok(ch_sel) = Selector::parse(channel_selector) {
                                let channel_pattern = format.match_channel_name.as_deref();
                                for (idx, ch_el) in detail_doc.select(&ch_sel).enumerate() {
                                    let raw_text = ch_el.text().collect::<String>();
                                    let channel_name =
                                        extract_channel_name(&raw_text, channel_pattern);
                                    if !channel_name.is_empty() {
                                        log::info!(
                                            "[{}] Found channel {}: '{}'",
                                            source_name,
                                            idx,
                                            channel_name
                                        );
                                        channels.push(ChannelInfo {
                                            name: channel_name,
                                            index: idx,
                                        });
                                    }
                                }
                            }
                        }
                    }

                    log::info!("[{}] Total channels found: {}", source_name, channels.len());
                    if channels.is_empty() {
                        if let Ok(title_sel) = Selector::parse("title") {
                            let page_title = detail_doc
                                .select(&title_sel)
                                .next()
                                .map(|el| el.text().collect::<String>().trim().to_string())
                                .unwrap_or_default();
                            let snippet: String = detail_resp_text
                                .chars()
                                .take(4000)
                                .collect::<String>()
                                .replace('\n', " ")
                                .replace('\r', " ");
                            log::warn!(
                                "[{}] Detail page produced 0 channels. title='{}', len={}, snippet={}",
                                source_name,
                                page_title,
                                detail_resp_text.len(),
                                snippet
                            );
                        }
                    }

                    // 2. 获取第一个channel的剧集
                    if let (Ok(list_sel), Ok(item_sel)) = (
                        Selector::parse(&format.select_episode_lists),
                        Selector::parse(&format.select_episodes_from_list),
                    ) {
                        if let Some(list_container) = detail_doc.select(&list_sel).next() {
                            let episodes: Vec<_> = list_container.select(&item_sel).collect();
                            let ep_pattern = format.match_episode_sort_from_name.as_deref();
                            if let Some(href) = select_episode_by_number(
                                &episodes,
                                absolute_episode,
                                relative_episode,
                                ep_pattern,
                            ) {
                                if !href.is_empty() {
                                    episode_url = absolutize_url(&detail_url, &href);
                                    // 记录选中的channel（默认第一个）
                                    if !channels.is_empty() {
                                        selected_channel_name = Some(channels[0].name.clone());
                                        selected_channel_index = Some(channels[0].index);
                                    }
                                }
                            }
                        }
                    }
                }
            } else if let Some(ref format) = source
                .arguments
                .search_config
                .selector_channel_format_no_channel
            {
                // no-channel 模式
                channels.push(ChannelInfo {
                    name: "默认线路".to_string(),
                    index: 0,
                });

                if let Ok(ep_sel) = Selector::parse(&format.select_episodes) {
                    let episodes: Vec<_> = detail_doc.select(&ep_sel).collect();
                    let ep_pattern = format.match_episode_sort_from_name.as_deref();
                    if let Some(href) = select_episode_by_number(
                        &episodes,
                        absolute_episode,
                        relative_episode,
                        ep_pattern,
                    ) {
                        if !href.is_empty() {
                            episode_url = absolutize_url(&detail_url, &href);
                            selected_channel_name = Some("默认线路".to_string());
                            selected_channel_index = Some(0);
                        }
                    }
                }
            }

            // 如果channels为空但使用了旧的配置格式，尝试用旧逻辑
            if channels.is_empty() && episode_url.is_empty() {
                if let Some(ref format) = source
                    .arguments
                    .search_config
                    .selector_channel_format_flattened
                {
                    if let (Ok(list_sel), Ok(item_sel)) = (
                        Selector::parse(&format.select_episode_lists),
                        Selector::parse(&format.select_episodes_from_list),
                    ) {
                        if let Some(list_container) = detail_doc.select(&list_sel).next() {
                            let episodes: Vec<_> = list_container.select(&item_sel).collect();
                            let ep_pattern = format.match_episode_sort_from_name.as_deref();
                            if let Some(href) = select_episode_by_number(
                                &episodes,
                                absolute_episode,
                                relative_episode,
                                ep_pattern,
                            ) {
                                if !href.is_empty() {
                                    episode_url = absolutize_url(&detail_url, &href);
                                }
                            }
                        }
                    }
                }
            }

            (
                channels,
                episode_url,
                selected_channel_name,
                selected_channel_index,
            )
        }; // detail_doc 在这里被 drop

        channels = parse_result.0;
        episode_url = parse_result.1;
        selected_channel_name = parse_result.2;
        selected_channel_index = parse_result.3;

        // Successful parse — only cache and accept pages that actually yield a play URL.
        if !episode_url.is_empty() {
            let (cache_channels, cache_episodes) =
                parse_episode_table_from_detail(source, &detail_url, &detail_resp_text);
            if !cache_episodes.is_empty() {
                let cache = build_episode_table_cache(
                    source,
                    anime_name,
                    detail_url.clone(),
                    candidate.title.clone(),
                    cache_channels,
                    cache_episodes,
                    effective_cookies.clone(),
                    headers.clone(),
                );
                save_episode_table_cache(&cache);
            }
            break;
        }

        // Empty detail: try next same-score / lower-score subject entry for this source.
        last_detail_error = Some(format!(
            "条目 '{}' 无可播放线路/剧集",
            if candidate.title.is_empty() {
                detail_url.as_str()
            } else {
                candidate.title.as_str()
            }
        ));
        log::warn!(
            "[{}] Subject candidate has no playable episodes (channels={}, title='{}'); trying next if any",
            source_name,
            channels.len(),
            candidate.title
        );
    }

    if episode_url.is_empty() {
        let error = last_detail_error.unwrap_or_else(|| "未找到剧集列表".to_string());
        sink.emit(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::Failed,
            error: Some(error),
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            all_channels: if channels.is_empty() {
                None
            } else {
                Some(channels)
            },
            captcha_config_json: captcha_config_json.clone(),
            enable_nested_url: false,
            match_nested_url: None,
        });
        return Err(anyhow::anyhow!("No episodes found"));
    }

    // Step 4: 尝试提取视频URL
    let all_channels = if channels.is_empty() {
        None
    } else {
        Some(channels.clone())
    };

    if !sink.emit(SourceSearchProgress {
        source_name: source_name.clone(),
        step: SearchStep::ExtractingVideo,
        error: None,
        play_page_url: Some(episode_url.clone()),
        video_regex: Some(video_regex.clone()),
        direct_video_url: None,
        cookies: effective_cookies.clone(),
        headers: headers.clone(),
        channel_name: selected_channel_name.clone(),
        channel_index: selected_channel_index,
        all_channels: all_channels.clone(),
        captcha_config_json: captcha_config_json.clone(),
        enable_nested_url: source
            .arguments
            .search_config
            .match_video
            .enable_nested_url
            .unwrap_or(false),
        match_nested_url: source
            .arguments
            .search_config
            .match_video
            .match_nested_url
            .clone(),
    }) {
        return Ok(());
    }

    let direct_video_url = None;

    // 不再使用内置的player_aaaa提取，直接返回搜索结果让WebView处理

    // 发送成功结果
    sink.emit(SourceSearchProgress {
        source_name: source_name.clone(),
        step: SearchStep::Success,
        error: None,
        play_page_url: Some(episode_url),
        video_regex: Some(video_regex),
        direct_video_url,
        cookies: effective_cookies,
        headers,
        channel_name: selected_channel_name,
        channel_index: selected_channel_index,
        all_channels,
        captcha_config_json,
        enable_nested_url: source
            .arguments
            .search_config
            .match_video
            .enable_nested_url
            .unwrap_or(false),
        match_nested_url: source
            .arguments
            .search_config
            .match_video
            .match_nested_url
            .clone(),
    });

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::config::init_config;
    use crate::test_support::fixture::fixture_text;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::Method;
    use std::sync::{Arc, Mutex};

    #[derive(Clone, Default)]
    struct RecordingEmitter {
        events: Arc<Mutex<Vec<SourceSearchProgress>>>,
        fail_after: Option<usize>,
    }

    impl RecordingEmitter {
        fn with_fail_after(fail_after: usize) -> Self {
            Self {
                events: Arc::new(Mutex::new(Vec::new())),
                fail_after: Some(fail_after),
            }
        }

        fn events(&self) -> Vec<SourceSearchProgress> {
            self.events.lock().unwrap().clone()
        }
    }

    impl ProgressEmitter for RecordingEmitter {
        fn emit(&self, progress: SourceSearchProgress) -> bool {
            let mut events = self.events.lock().unwrap();
            if self
                .fail_after
                .is_some_and(|fail_after| events.len() >= fail_after)
            {
                return false;
            }
            events.push(progress);
            true
        }
    }

    fn no_proxy_client() -> reqwest::Client {
        reqwest::Client::builder().no_proxy().build().unwrap()
    }

    fn progress_source(name: &str, search_url: &str) -> MediaSource {
        serde_json::from_value(serde_json::json!({
            "factoryId": "web-selector",
            "arguments": {
                "name": name,
                "captchaConfig": {
                    "enable": true,
                    "type": "image",
                    "detectSelector": "form.captcha"
                },
                "searchConfig": {
                    "searchUrl": search_url,
                    "subjectFormatId": "indexed",
                    "selectorSubjectFormatIndexed": {
                        "selectNames": "li.result span.name",
                        "selectLinks": "li.result a.link"
                    },
                    "channelFormatId": "no-channel",
                    "selectorChannelFormatNoChannel": {
                        "selectEpisodes": "div.play-list a.ep"
                    },
                    "matchVideo": {
                        "matchVideoUrl": "url=(?<v>.+\\.m3u8)",
                        "enableNestedUrl": true,
                        "matchNestedUrl": "src=\"([^\"]+)\"",
                        "cookies": "configured=1",
                        "addHeadersToVideo": { "x-progress-test": "present" }
                    }
                }
            }
        }))
        .unwrap()
    }

    fn step_rank(step: SearchStep) -> u8 {
        match step {
            SearchStep::Pending => 0,
            SearchStep::Searching => 1,
            SearchStep::FetchingDetail => 2,
            SearchStep::FetchingEpisodes => 3,
            SearchStep::ExtractingVideo => 4,
            SearchStep::Success | SearchStep::Failed => 5,
        }
    }

    #[tokio::test]
    async fn progress_events_are_monotonic_and_include_playback_metadata() {
        let _guard = isolate_runtime_config();
        let cache_dir = tempfile::tempdir().unwrap();
        init_config(
            cache_dir.path().to_string_lossy().to_string(),
            cache_dir.path().to_string_lossy().to_string(),
        );
        let source = progress_source("ProgressSource", "https://unused.test/search?q={keyword}");
        let runtime_override = SourceRuntimeOverride {
            source_name: "ProgressSource".to_string(),
            cookies: Some("runtime=2".to_string()),
            search_page_html: Some(fixture_text("generic_scraper/search_indexed.html")),
            search_page_url: Some("https://fixture.test/search?q=x".to_string()),
            detail_page_html: Some(fixture_text("generic_scraper/detail_no_channel.html")),
            detail_page_url: Some("https://fixture.test/detail/1".to_string()),
            skip_search_error: None,
        };
        let emitter = RecordingEmitter::default();

        run_source_with_progress(
            &no_proxy_client(),
            &source,
            "测试动画",
            Some(2),
            None,
            &emitter,
            Some(&runtime_override),
        )
        .await
        .unwrap();

        let events = emitter.events();
        let steps: Vec<_> = events.iter().map(|event| event.step).collect();
        assert_eq!(
            steps,
            vec![
                SearchStep::Searching,
                SearchStep::FetchingDetail,
                SearchStep::FetchingEpisodes,
                SearchStep::ExtractingVideo,
                SearchStep::Success,
            ]
        );
        assert!(
            steps
                .windows(2)
                .all(|pair| step_rank(pair[0]) <= step_rank(pair[1]))
        );
        assert_eq!(
            events
                .iter()
                .filter(|event| matches!(event.step, SearchStep::Success | SearchStep::Failed))
                .count(),
            1
        );
        let success = events.last().unwrap();
        assert_eq!(
            success.play_page_url.as_deref(),
            Some("https://fixture.test/play/2")
        );
        assert_eq!(success.cookies.as_deref(), Some("configured=1; runtime=2"));
        assert!(success.enable_nested_url);
        assert!(
            success
                .captcha_config_json
                .as_deref()
                .unwrap()
                .contains("image")
        );
    }

    #[tokio::test]
    async fn closed_progress_sink_stops_before_detail_fetch() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/search",
                TestResponse::fixture("generic_scraper/search_indexed.html"),
            ),
            TestRoute::get(
                "/detail/1",
                TestResponse::fixture("generic_scraper/detail_no_channel.html"),
            ),
        ])
        .await;
        let source = progress_source(
            "CancelledSource",
            &format!("{}/search?q={{keyword}}", server.base_url()),
        );
        let emitter = RecordingEmitter::with_fail_after(1);

        run_source_with_progress(
            &no_proxy_client(),
            &source,
            "测试动画",
            None,
            None,
            &emitter,
            None,
        )
        .await
        .unwrap();

        assert_eq!(
            emitter
                .events()
                .iter()
                .map(|event| event.step)
                .collect::<Vec<_>>(),
            vec![SearchStep::Searching]
        );
        assert_eq!(server.request_count(Method::GET, "/search"), 1);
        assert_eq!(server.request_count(Method::GET, "/detail/1"), 0);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn skipped_sources_report_one_terminal_failure_each() {
        let emitter = RecordingEmitter::default();
        let client = no_proxy_client();

        for (name, error) in [("SourceA", "captcha required"), ("SourceB", "disabled")] {
            let source = progress_source(name, "https://unused.test/{keyword}");
            let runtime_override = SourceRuntimeOverride {
                source_name: name.to_string(),
                cookies: None,
                search_page_html: None,
                search_page_url: None,
                detail_page_html: None,
                detail_page_url: None,
                skip_search_error: Some(error.to_string()),
            };
            run_source_with_progress(
                &client,
                &source,
                "测试动画",
                None,
                None,
                &emitter,
                Some(&runtime_override),
            )
            .await
            .unwrap();
        }

        let events = emitter.events();
        let failures: Vec<_> = events
            .iter()
            .filter(|event| event.step == SearchStep::Failed)
            .collect();
        assert_eq!(failures.len(), 2);
        assert_eq!(failures[0].error.as_deref(), Some("captcha required"));
        assert_eq!(failures[1].error.as_deref(), Some("disabled"));
        assert_eq!(
            events.len(),
            4,
            "each source emits Searching then one terminal event"
        );
    }
}
