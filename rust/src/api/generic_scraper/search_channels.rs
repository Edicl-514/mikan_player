use super::episode_table::*;
use super::headers_cookies::*;
use super::matching::*;
use super::region::*;
use super::source_config::*;
use super::types::*;
use scraper::Html;

/// 搜索单个源，返回包含所有channel和剧集信息的完整结果
/// 此函数用于获取多线路（如"简中"/"繁中"、"线路A"/"线路B"）的详细信息
async fn search_single_source_with_channels(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
    runtime_override: Option<&SourceRuntimeOverride>,
) -> anyhow::Result<SearchResultWithChannels> {
    let source_name = source.arguments.name.clone();
    let video_regex = source
        .arguments
        .search_config
        .match_video
        .match_video_url
        .clone();
    let configured_cookies = source.arguments.search_config.match_video.cookies.clone();
    let runtime_cookies = runtime_override.and_then(|o| o.cookies.as_deref());
    let cookies = merge_cookie_strings(configured_cookies.as_deref(), runtime_cookies);
    let headers = source
        .arguments
        .search_config
        .match_video
        .add_headers_to_video
        .clone();
    let default_subtitle_language = source
        .arguments
        .search_config
        .default_subtitle_language
        .clone();
    let default_resolution = source.arguments.search_config.default_resolution.clone();

    let initial_search_page_html = runtime_override
        .and_then(|o| o.search_page_html.clone())
        .filter(|s| !s.is_empty());
    let initial_search_page_url = runtime_override
        .and_then(|o| o.search_page_url.clone())
        .filter(|s| !s.is_empty());

    let search_candidates = build_search_candidates(anime_name);
    let mut ranked_subjects: Vec<SubjectCandidate> = Vec::new();
    let mut last_search_url = String::new();
    let initial_detail_page_html = runtime_override
        .and_then(|o| o.detail_page_html.clone())
        .filter(|s| !s.is_empty());
    let initial_detail_page_url = runtime_override
        .and_then(|o| o.detail_page_url.clone())
        .filter(|s| !s.is_empty());

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
        log::info!(
            "[{}] Search term: '{}', Core name: '{}'",
            source_name,
            search_term,
            core_name
        );

        // Step 1: 搜索
        let search_url = source
            .arguments
            .search_config
            .search_url
            .replace("{keyword}", &search_term);
        log::info!("[{}] Searching: {}", source_name, search_url);
        last_search_url = search_url.clone();

        let resp_text = if idx == 0 && initial_search_page_html.is_some() {
            log::info!(
                "[{}] Using runtime override search page HTML ({} bytes)",
                source_name,
                initial_search_page_html.as_ref().unwrap().len()
            );
            initial_search_page_html.clone().unwrap()
        } else {
            let request = client.get(&search_url);
            let request = apply_cookie_header(request, cookies.as_deref());
            let request = apply_browser_page_headers(
                request,
                &search_url,
                initial_search_page_url.as_deref().or(Some(&search_url)),
            );
            request.send().await?.text().await?
        };

        let document = Html::parse_document(&resp_text);
        let sel_result = select_best_subject_candidate(&document, source, query_name, &core_name);
        if !sel_result.ranked.is_empty() {
            ranked_subjects = sel_result
                .ranked
                .into_iter()
                .map(|c| SubjectCandidate {
                    title: c.title,
                    url: absolutize_url(&search_url, &c.url),
                    score: c.score,
                })
                .collect();
            break;
        }
    }

    if let Some(forced) = initial_detail_page_url.clone() {
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
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    let retry_limit = subject_retry_limit(ranked_subjects.len());
    let mut detail_url = String::new();
    let mut matched_title = String::new();
    let mut channels: Vec<ChannelInfo> = Vec::new();
    let mut episodes: Vec<EpisodeInfo> = Vec::new();

    for (try_idx, candidate) in ranked_subjects.iter().take(retry_limit).enumerate() {
        detail_url = candidate.url.clone();
        matched_title = candidate.title.clone();

        if try_idx > 0 {
            log::info!(
                "[{}] Falling back to next subject candidate #{}: '{}' (score={}) url={}",
                source_name,
                try_idx + 1,
                matched_title,
                candidate.score,
                detail_url
            );
        } else {
            log::info!(
                "[{}] Found detail URL: {} (title: {})",
                source_name,
                detail_url,
                matched_title
            );
        }

        // Step 2: 获取详情页并解析channels和episodes
        let detail_resp_text = if try_idx == 0 {
            if let Some(html) = initial_detail_page_html.clone() {
                log::info!(
                    "[{}] Using runtime override detail page HTML ({} bytes)",
                    source_name,
                    html.len()
                );
                html
            } else {
                let request = client.get(&detail_url);
                let request = apply_cookie_header(request, cookies.as_deref());
                let request =
                    apply_browser_page_headers(request, &detail_url, Some(&last_search_url));
                match request.send().await {
                    Ok(resp) => match resp.text().await {
                        Ok(text) => text,
                        Err(e) => {
                            log::warn!("[{}] Detail page text failed: {}", source_name, e);
                            continue;
                        }
                    },
                    Err(e) => {
                        log::warn!("[{}] Detail page fetch failed: {}", source_name, e);
                        continue;
                    }
                }
            }
        } else {
            let request = client.get(&detail_url);
            let request = apply_cookie_header(request, cookies.as_deref());
            let request = apply_browser_page_headers(request, &detail_url, Some(&last_search_url));
            match request.send().await {
                Ok(resp) => match resp.text().await {
                    Ok(text) => text,
                    Err(e) => {
                        log::warn!("[{}] Detail page text failed: {}", source_name, e);
                        continue;
                    }
                },
                Err(e) => {
                    log::warn!("[{}] Detail page fetch failed: {}", source_name, e);
                    continue;
                }
            }
        };

        let (parsed_channels, parsed_episodes) =
            parse_episode_table_from_detail(source, &detail_url, &detail_resp_text);
        channels = parsed_channels;
        episodes = parsed_episodes;

        log::info!(
            "[{}] Found {} channels and {} episodes",
            source_name,
            channels.len(),
            episodes.len()
        );

        if !episodes.is_empty() {
            let cache = build_episode_table_cache(
                source,
                anime_name,
                detail_url.clone(),
                matched_title.clone(),
                channels.clone(),
                episodes.clone(),
                cookies.clone(),
                headers.clone(),
            );
            save_episode_table_cache(&cache);
            break;
        }

        log::warn!(
            "[{}] Subject candidate has no playable episodes (title='{}'); trying next if any",
            source_name,
            matched_title
        );
    }

    if episodes.is_empty() {
        return Err(anyhow::anyhow!("No episodes found"));
    }

    Ok(SearchResultWithChannels {
        source_name,
        detail_url,
        matched_title,
        channels,
        episodes,
        video_regex,
        cookies,
        headers,
        default_subtitle_language,
        default_resolution,
    })
}
/// 搜索所有源，返回包含多channel信息的完整结果
/// 此API用于UI展示所有可用的线路和剧集供用户选择
pub(crate) async fn generic_search_with_channels(
    anime_name: String,
) -> anyhow::Result<Vec<SearchResultWithChannels>> {
    let client = crate::api::network::get_shared_client().clone();

    let sources = load_enabled_sources().await?;

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
            async move {
                log::info!("Searching source with channels: {}", source.arguments.name);
                search_single_source_with_channels(&client, &source, &anime_name, None).await
            }
        })
        .buffer_unordered(limit);

    let all_results: Vec<_> = stream.collect().await;

    let results: Vec<SearchResultWithChannels> =
        all_results.into_iter().filter_map(|r| r.ok()).collect();

    Ok(results)
}

/// 搜索所有源，以流的形式返回包含多channel信息的结果
pub(crate) async fn generic_search_with_channels_stream(
    anime_name: String,
    sink: crate::frb_generated::StreamSink<SearchResultWithChannels>,
) -> anyhow::Result<()> {
    let client = crate::api::network::get_shared_client().clone();

    let sources = load_enabled_sources().await?;

    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream =
        futures::stream::iter(sources)
            .map(|source| {
                let client = client.clone();
                let anime_name = anime_name.clone();
                async move {
                    search_single_source_with_channels(&client, &source, &anime_name, None).await
                }
            })
            .buffer_unordered(limit);

    let mut stream = Box::pin(stream);
    while let Some(result) = stream.next().await {
        if let Ok(search_result) = result {
            log::info!(
                "Source '{}' completed with {} channels",
                search_result.source_name,
                search_result.channels.len()
            );
            sink.add(search_result).ok();
        }
    }

    Ok(())
}

/// 根据指定的channel和集号获取播放页面URL
/// 此API用于在用户选择了具体的线路和集数后获取播放页面
pub(crate) async fn get_episode_play_url(
    source_name: String,
    anime_name: String,
    channel_index: usize,
    episode_number: Option<u32>,
    runtime_override: Option<SourceRuntimeOverride>,
) -> anyhow::Result<SearchPlayResult> {
    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;
    let root = detect_and_filter_root(root).await;

    // 找到指定的源
    let source = root
        .exported_media_source_data_list
        .media_sources
        .iter()
        .find(|s| s.arguments.name == source_name)
        .ok_or_else(|| anyhow::anyhow!("Source not found: {}", source_name))?;

    let config_hash = source_config_hash(source);
    if let Some(cache) = load_episode_table_cache(&source_name, &anime_name, config_hash) {
        let target_episode = select_episode_from_table(
            &cache.episodes,
            Some(channel_index),
            episode_number,
            episode_number,
        )
        .ok_or_else(|| anyhow::anyhow!("Episode not found in cache"))?;
        let channel_name = cache
            .channels
            .iter()
            .find(|channel| channel.index == target_episode.channel_index)
            .map(|channel| channel.name.clone());

        let runtime_cookies = runtime_override.as_ref().and_then(|o| o.cookies.as_deref());
        let merged_cookies = merge_cookie_strings(cache.cookies.as_deref(), runtime_cookies);

        return Ok(SearchPlayResult {
            source_name,
            play_page_url: target_episode.url.clone(),
            video_regex: cache.video_regex,
            direct_video_url: None,
            cookies: merged_cookies,
            headers: cache.headers,
            channel_name,
            channel_index: Some(target_episode.channel_index),
            captcha_config_json: None,
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
    }

    // 获取完整的channel和episode信息
    let result =
        search_single_source_with_channels(&client, source, &anime_name, runtime_override.as_ref())
            .await?;

    // 根据channel_index和episode_number找到目标episode
    let target_episode = if let Some(ep_num) = episode_number {
        // 在指定channel中查找指定集数
        result
            .episodes
            .iter()
            .filter(|ep| ep.channel_index == channel_index)
            .find(|ep| ep.episode_number == Some(ep_num))
            .or_else(|| {
                // 如果找不到，尝试在所有channel中找
                result
                    .episodes
                    .iter()
                    .find(|ep| ep.episode_number == Some(ep_num))
            })
    } else {
        // 如果没有指定集数，返回指定channel的第一集
        result
            .episodes
            .iter()
            .filter(|ep| ep.channel_index == channel_index)
            .next()
    };

    let episode = target_episode.ok_or_else(|| anyhow::anyhow!("Episode not found"))?;

    // 获取channel名称
    let channel_name = result.channels.get(channel_index).map(|ch| ch.name.clone());

    // 尝试提取视频URL
    let direct_video_url = None;

    // 不再使用内置的player_aaaa提取，直接返回搜索结果让WebView处理

    Ok(SearchPlayResult {
        source_name,
        play_page_url: episode.url.clone(),
        video_regex: result.video_regex,
        direct_video_url,
        cookies: result.cookies,
        headers: result.headers,
        channel_name,
        channel_index: Some(channel_index),
        captcha_config_json: None,
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
}
