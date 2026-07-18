use super::episode_table::*;
use super::headers_cookies::*;
use super::matching::*;
use super::region::*;
use super::source_config::*;
use super::types::*;
use scraper::{Html, Selector};
use std::fs;

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
                let source_name = source.arguments.name.clone();

                sink.add(SourceSearchProgress {
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
                })
                .ok();

                if let Some(skip_error) = runtime_override
                    .as_ref()
                    .and_then(|item| item.skip_search_error.clone())
                {
                    sink.add(SourceSearchProgress {
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
                    })
                    .ok();
                    return Ok(());
                }

                search_single_source_with_progress(
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
                let source_name = source.arguments.name.clone();

                sink.add(SourceSearchProgress {
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
                })
                .ok();

                if let Some(skip_error) = runtime_override
                    .as_ref()
                    .and_then(|item| item.skip_search_error.clone())
                {
                    sink.add(SourceSearchProgress {
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
                    })
                    .ok();
                    return Ok(());
                }

                search_single_source_with_progress(
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
    sink: &crate::frb_generated::StreamSink<SourceSearchProgress>,
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

                sink.add(SourceSearchProgress {
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
                })
                .ok();

                sink.add(SourceSearchProgress {
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
                })
                .ok();

                sink.add(SourceSearchProgress {
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
                })
                .ok();
                return Ok(());
            }
        }
    }

    let search_candidates = build_search_candidates(anime_name);
    let mut detail_url = String::new();

    for (idx, query_name) in search_candidates.iter().enumerate() {
        if idx > 0 {
            log::info!(
                "[{}] No results found, retrying with alias: '{}'",
                source_name,
                query_name
            );
        }

        // 预处理搜索词
        let search_term = preprocess_search_term(query_name);
        let core_name = extract_core_name(query_name);

        // Step 1: 搜索
        let search_url = source
            .arguments
            .search_config
            .search_url
            .replace("{keyword}", &search_term);
        let (resp_text, response_search_url) = if idx == 0 {
            if let Some(html) = initial_search_page_html.clone() {
                (
                    html,
                    initial_search_page_url
                        .clone()
                        .unwrap_or_else(|| search_url.clone()),
                )
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
                        Ok(text) => (text, search_url.clone()),
                        Err(e) => {
                            sink.add(SourceSearchProgress {
                                source_name: source_name.clone(),
                                step: SearchStep::Failed,
                                error: Some(format!("搜索请求失败: {}", e)),
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
                            })
                            .ok();
                            return Err(anyhow::anyhow!("Search request failed"));
                        }
                    },
                    Err(e) => {
                        sink.add(SourceSearchProgress {
                            source_name: source_name.clone(),
                            step: SearchStep::Failed,
                            error: Some(format!("网络错误: {}", e)),
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
                        })
                        .ok();
                        return Err(anyhow::anyhow!("Network error"));
                    }
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
                    Ok(text) => (text, search_url.clone()),
                    Err(e) => {
                        sink.add(SourceSearchProgress {
                            source_name: source_name.clone(),
                            step: SearchStep::Failed,
                            error: Some(format!("搜索请求失败: {}", e)),
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
                        })
                        .ok();
                        return Err(anyhow::anyhow!("Search request failed"));
                    }
                },
                Err(e) => {
                    sink.add(SourceSearchProgress {
                        source_name: source_name.clone(),
                        step: SearchStep::Failed,
                        error: Some(format!("网络错误: {}", e)),
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
                    })
                    .ok();
                    return Err(anyhow::anyhow!("Network error"));
                }
            }
        };

        let current_detail_url = {
            let document = Html::parse_document(&resp_text);
            let format_id = source
                .arguments
                .search_config
                .subject_format_id
                .as_deref()
                .unwrap_or("indexed");

            let sel_result =
                select_best_subject_candidate(&document, source, query_name, &core_name);
            log_subject_selection(&source_name, format_id, query_name, &core_name, &sel_result);

            sel_result
                .best
                .map(|c| absolutize_url(&response_search_url, &c.url))
                .unwrap_or_default()
        };

        if !current_detail_url.is_empty() {
            detail_url = initial_detail_page_url
                .clone()
                .filter(|item| !item.is_empty())
                .unwrap_or(current_detail_url);
            break;
        }
    }

    if detail_url.is_empty() {
        sink.add(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::Failed,
            error: Some("未找到匹配的动画".to_string()),
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
        })
        .ok();
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    // Step 2: 获取详情页
    sink.add(SourceSearchProgress {
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
    })
    .ok();

    let detail_resp_text = if let Some(html) = initial_detail_page_html.clone() {
        log::info!(
            "[{}] Using detail page HTML captured from WebView",
            source_name
        );
        html
    } else {
        match apply_browser_page_headers(
            apply_cookie_header(client.get(&detail_url), effective_cookies.as_deref()),
            &detail_url,
            runtime_override
                .as_ref()
                .and_then(|item| item.search_page_url.as_deref()),
        )
        .send()
        .await
        {
            Ok(resp) => match resp.text().await {
                Ok(text) => text,
                Err(e) => {
                    sink.add(SourceSearchProgress {
                        source_name: source_name.clone(),
                        step: SearchStep::Failed,
                        error: Some(format!("获取详情页失败: {}", e)),
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
                    })
                    .ok();
                    return Err(anyhow::anyhow!("Detail fetch failed"));
                }
            },
            Err(e) => {
                sink.add(SourceSearchProgress {
                    source_name: source_name.clone(),
                    step: SearchStep::Failed,
                    error: Some(format!("详情页网络错误: {}", e)),
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
                })
                .ok();
                return Err(anyhow::anyhow!("Detail network error"));
            }
        }
    };

    // Step 3: 获取剧集列表
    sink.add(SourceSearchProgress {
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
    })
    .ok();

    // 解析所有channels (使用代码块确保Html在await前被drop)
    let (channels, episode_url, selected_channel_name, selected_channel_index) = {
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
                                let channel_name = extract_channel_name(&raw_text, channel_pattern);
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
                                episode_url = if href.starts_with("http") {
                                    href
                                } else {
                                    let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                        format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                    } else {
                                        "".to_string()
                                    };
                                    format!("{}{}", base_url, href)
                                };
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
        } else {
            // no-channel 模式
            if let Some(ref format) = source
                .arguments
                .search_config
                .selector_channel_format_no_channel
            {
                // 创建默认channel
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
                            episode_url = if href.starts_with("http") {
                                href
                            } else {
                                let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                    format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                } else {
                                    "".to_string()
                                };
                                format!("{}{}", base_url, href)
                            };
                            selected_channel_name = Some("默认线路".to_string());
                            selected_channel_index = Some(0);
                        }
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
                                episode_url = if href.starts_with("http") {
                                    href
                                } else {
                                    let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                        format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                    } else {
                                        "".to_string()
                                    };
                                    format!("{}{}", base_url, href)
                                };
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

    let (cache_channels, cache_episodes) =
        parse_episode_table_from_detail(source, &detail_url, &detail_resp_text);
    if !cache_episodes.is_empty() {
        let cache = build_episode_table_cache(
            source,
            anime_name,
            detail_url.clone(),
            String::new(),
            cache_channels,
            cache_episodes,
            effective_cookies.clone(),
            headers.clone(),
        );
        save_episode_table_cache(&cache);
    }

    if episode_url.is_empty() {
        sink.add(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::Failed,
            error: Some("未找到剧集列表".to_string()),
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
        })
        .ok();
        return Err(anyhow::anyhow!("No episodes found"));
    }

    // Step 4: 尝试提取视频URL
    let all_channels = if channels.is_empty() {
        None
    } else {
        Some(channels.clone())
    };

    sink.add(SourceSearchProgress {
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
    })
    .ok();

    let direct_video_url = None;

    // 不再使用内置的player_aaaa提取，直接返回搜索结果让WebView处理

    // 发送成功结果
    sink.add(SourceSearchProgress {
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
    })
    .ok();

    Ok(())
}
