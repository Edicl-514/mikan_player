use super::episode_table::*;
use super::matching::*;
use super::region::*;
use super::source_config::*;
use super::types::*;
use fancy_regex::Regex;
use scraper::{Html, Selector};

trait SearchPlayResultEmitter {
    fn emit(&self, result: SearchPlayResult) -> bool;
}

impl SearchPlayResultEmitter for crate::frb_generated::StreamSink<SearchPlayResult> {
    fn emit(&self, result: SearchPlayResult) -> bool {
        self.add(result).is_ok()
    }
}

async fn forward_search_play_results<S, E>(stream: S, emitter: &E)
where
    S: futures::Stream<Item = (String, anyhow::Result<SearchPlayResult>)>,
    E: SearchPlayResultEmitter + ?Sized,
{
    use futures::stream::StreamExt;

    let mut stream = Box::pin(stream);
    while let Some((source_name, result)) = stream.next().await {
        if let Ok(search_result) = result {
            log::info!(
                "Source '{}' completed, sending result to stream",
                source_name
            );
            if !emitter.emit(search_result) {
                break;
            }
        } else if let Err(error) = result {
            log::warn!("Source search failed for {}: {}", source_name, error);
        }
    }
}

/// 搜索所有源，返回所有找到的播放页面URL列表
/// Flutter 端可以使用 WebView 加载这些 URL 来拦截视频请求
///
/// # 参数
/// * `anime_name` - 动画名称
/// * `absolute_episode` - 绝对集号（如第15集），优先匹配
/// * `relative_episode` - 相对集号（如当季第3集），绝对集号找不到时回退使用
pub(crate) async fn generic_search_play_pages(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<Vec<SearchPlayResult>> {
    let client = crate::api::network::get_shared_client().clone();

    let sources = load_enabled_sources().await?;

    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream = futures::stream::iter(sources).map(|source| {
        let client = client.clone();
        let source = source.clone();
        let anime_name = anime_name.clone();
        async move {
            log::info!("Searching source: {}", source.arguments.name);
            search_single_source(
                &client,
                &source,
                &anime_name,
                absolute_episode,
                relative_episode,
            )
            .await
        }
    });

    let all_results: Vec<_> = stream.buffer_unordered(limit).collect().await;

    let results: Vec<SearchPlayResult> = all_results.into_iter().filter_map(|r| r.ok()).collect();

    Ok(results)
}

/// 搜索所有源，以流的形式返回结果（每个源搜索完成后立即返回）
/// 这样可以让UI实时显示搜索结果，而不是等所有源都搜索完毕
pub(crate) async fn generic_search_play_pages_stream(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<SearchPlayResult>,
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

    let stream = futures::stream::iter(sources)
        .map(|source| {
            let client = client.clone();
            let anime_name = anime_name.clone();
            async move {
                log::info!("Searching source: {}", source.arguments.name);
                let result = search_single_source(
                    &client,
                    &source,
                    &anime_name,
                    absolute_episode,
                    relative_episode,
                )
                .await;
                (source.arguments.name, result)
            }
        })
        .buffer_unordered(limit);

    forward_search_play_results(stream, &sink).await;

    Ok(())
}
/// 搜索单个源
async fn search_single_source(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<SearchPlayResult> {
    let source_name = source.arguments.name.clone();
    let video_regex = source
        .arguments
        .search_config
        .match_video
        .match_video_url
        .clone();
    let cookies = source.arguments.search_config.match_video.cookies.clone();
    let headers = source
        .arguments
        .search_config
        .match_video
        .add_headers_to_video
        .clone();

    let search_candidates = build_search_candidates(anime_name);
    let mut ranked_subjects: Vec<SubjectCandidate> = Vec::new();

    for (idx, query_name) in search_candidates.iter().enumerate() {
        if idx > 0 {
            log::info!(
                "[{}] No results found, retrying with alias: '{}'",
                source_name,
                query_name
            );
        }

        // 预处理搜索词（去除标点、季数等）
        let search_term = preprocess_search_term(query_name);

        // 提取核心关键词用于匹配（去除"第X季"等后缀）
        let core_name = extract_core_name(query_name);
        log::info!(
            "[{}] Search term: '{}', Core name: '{}'",
            source_name,
            search_term,
            core_name
        );

        // Step 1: 搜索（使用预处理后的搜索词）
        let search_url = source
            .arguments
            .search_config
            .search_url
            .replace("{keyword}", &search_term);
        log::info!("[{}] Searching: {}", source_name, search_url);

        let resp_text = client.get(&search_url).send().await?.text().await?;

        {
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
    }

    if ranked_subjects.is_empty() {
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    let retry_limit = subject_retry_limit(ranked_subjects.len());
    let mut episode_url = String::new();

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
            log::info!("[{}] Found detail URL: {}", source_name, detail_url);
        }

        // Step 2: 获取剧集列表
        let detail_resp_text = match client.get(&detail_url).send().await {
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
        };

        episode_url = {
            let detail_doc = Html::parse_document(&detail_resp_text);
            let mut found_url = String::new();

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
                                found_url = absolutize_url(&detail_url, &href);
                            }
                        }
                    }
                }
            } else if let Some(ref format) = source
                .arguments
                .search_config
                .selector_channel_format_no_channel
            {
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
                            found_url = absolutize_url(&detail_url, &href);
                        }
                    }
                }
            }
            found_url
        };

        if !episode_url.is_empty() {
            break;
        }

        log::warn!(
            "[{}] Subject candidate has no playable episodes (title='{}'); trying next if any",
            source_name,
            candidate.title
        );
    }

    if episode_url.is_empty() {
        return Err(anyhow::anyhow!("No episodes found"));
    }

    log::info!("[{}] Found episode URL: {}", source_name, episode_url);

    // Step 3: 尝试直接获取视频URL（可选，主要让 WebView 处理）
    let direct_video_url = None;

    // 尝试获取页面并解析 player_aaaa

    // 不再使用内置的player_aaaa提取，直接返回搜索结果让WebView处理

    Ok(SearchPlayResult {
        source_name,
        play_page_url: episode_url,
        video_regex,
        direct_video_url,
        cookies,
        headers,
        channel_name: None,
        channel_index: None,
        captcha_config_json: source
            .arguments
            .captcha_config
            .as_ref()
            .map(|config| serde_json::to_string(config).unwrap_or_default()),
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

/// 搜索并播放动画（支持集号选择）
///
/// # 参数
/// * `anime_name` - 动画名称
/// * `absolute_episode` - 绝对集号（如第15集），优先匹配
/// * `relative_episode` - 相对集号（如当季第3集），绝对集号找不到时回退使用
pub(crate) async fn generic_search_and_play_with_episode(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    generic_search_and_play_internal(anime_name, absolute_episode, relative_episode).await
}

/// 搜索并播放动画（默认第一集，保持向后兼容）
pub(crate) async fn generic_search_and_play(anime_name: String) -> anyhow::Result<String> {
    generic_search_and_play_internal(anime_name, None, None).await
}

/// 内部实现：搜索并播放动画
async fn generic_search_and_play_internal(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    // 1. 从订阅地址拉取播放源配置 JSON
    let client = crate::api::network::get_shared_client().clone();
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;
    let root = detect_and_filter_root(root).await;

    search_and_play_sources(
        &client,
        root.exported_media_source_data_list.media_sources,
        &anime_name,
        absolute_episode,
        relative_episode,
    )
    .await
}

async fn search_and_play_sources(
    client: &reqwest::Client,
    sources: Vec<MediaSource>,
    anime_name: &str,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    // 2. Iterate sources and try to find the anime
    let search_candidates = build_search_candidates(anime_name);
    for source in sources {
        if !crate::api::config::is_source_enabled(&source.arguments.name) {
            continue;
        }
        log::info!("Trying source: {}", source.arguments.name);

        let mut detail_url = String::new();

        // --- Step 1: Search ---
        for (idx, query_name) in search_candidates.iter().enumerate() {
            if idx > 0 {
                log::info!(
                    "No results found, retrying with alias for {}: '{}'",
                    source.arguments.name,
                    query_name
                );
            }

            let search_url = source
                .arguments
                .search_config
                .search_url
                .replace("{keyword}", query_name);
            log::info!("Searching: {}", search_url);

            let resp_text = match client.get(&search_url).send().await {
                Ok(resp) => resp.text().await?,
                Err(e) => {
                    log::warn!("Search failed for {}: {}", source.arguments.name, e);
                    detail_url.clear();
                    break;
                }
            };

            {
                let document = Html::parse_document(&resp_text);

                // Implement logic for "selectorSubjectFormatIndexed"
                if let Some(ref format) = source
                    .arguments
                    .search_config
                    .selector_subject_format_indexed
                {
                    if let (Ok(name_sel), Ok(link_sel)) = (
                        Selector::parse(&format.select_names),
                        Selector::parse(&format.select_links),
                    ) {
                        let names: Vec<_> = document.select(&name_sel).collect();
                        let links: Vec<_> = document.select(&link_sel).collect();

                        // Simple zip matching
                        for (name_el, link_el) in names.iter().zip(links.iter()) {
                            let title = name_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();

                            log::info!("Found result: {} -> {}", title, href);

                            // Simple fuzzy match: if result contains the query
                            if title.contains(query_name) {
                                // Handle relative URLs
                                detail_url = absolutize_url(&search_url, &href);
                                break;
                            }
                        }
                    }
                }
            } // document dropped here

            if !detail_url.is_empty() {
                break;
            }
        }

        if detail_url.is_empty() {
            continue;
        }

        log::info!("Found detail URL: {}", detail_url);

        // --- Step 2: Get Episode List ---
        let detail_resp_text = match client.get(&detail_url).send().await {
            Ok(resp) => resp.text().await?,
            Err(e) => {
                log::warn!("Detail fetch failed: {}", e);
                continue;
            }
        };

        let mut episode_url = String::new();
        {
            let detail_doc = Html::parse_document(&detail_resp_text);
            // Strategy 1: Flattened
            if let Some(ref format) = source
                .arguments
                .search_config
                .selector_channel_format_flattened
            {
                if let (Ok(list_sel), Ok(item_sel)) = (
                    Selector::parse(&format.select_episode_lists),
                    Selector::parse(&format.select_episodes_from_list),
                ) {
                    // Find list container (often multiple tabs, we take first valid)
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
                                // Relative URL handling
                                episode_url = absolutize_url(&detail_url, &href);
                            }
                        }
                    }
                }
            } else if let Some(ref format) = source
                .arguments
                .search_config
                .selector_channel_format_no_channel
            {
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
                            // Relative URL handling
                            episode_url = absolutize_url(&detail_url, &href);
                        }
                    }
                }
            }
        } // detail_doc dropped here

        if episode_url.is_empty() {
            log::warn!("No episodes found for {}", detail_url);
            continue;
        }

        log::info!("Found episode URL: {}", episode_url);

        // --- Step 3: Get Video URL ---
        let mut request_builder = client.get(&episode_url);

        // Add custom headers if configured (e.g. User-Agent)
        if let Some(ref headers) = source
            .arguments
            .search_config
            .match_video
            .add_headers_to_video
        {
            for (k, v) in headers {
                request_builder = request_builder.header(k, v);
            }
        }
        // Add cookies if configured
        if let Some(ref cookies) = source.arguments.search_config.match_video.cookies {
            request_builder = request_builder.header("Cookie", cookies);
        }

        let mut video_page_text = match request_builder.send().await {
            Ok(resp) => resp.text().await?,
            Err(e) => {
                log::warn!("Video page fetch failed: {}", e);
                continue;
            }
        };

        // Debug: Check if m3u8 exists in the text
        log::info!(
            "DEBUG: Analyzing page content (Length: {})",
            video_page_text.len()
        );
        let matches: Vec<_> = video_page_text.match_indices("m3u8").collect();
        if matches.is_empty() {
            log::warn!("DEBUG: 'm3u8' string NOT found in video page text.");
        } else {
            log::info!("DEBUG: Found {} occurrences of 'm3u8'.", matches.len());
            for (i, (idx, _)) in matches.iter().enumerate() {
                let preview = text_window_around_match(&video_page_text, *idx, 100, 200);
                log::info!(
                    "DEBUG: Match #{}: ...{}...",
                    i + 1,
                    preview.replace("\n", " ").replace("\r", " ")
                );
            }
        }

        // Handle nested URL logic (e.g. iframe src)
        // Debug: Log all iframe sources to see if we missed a nested player
        {
            let doc = Html::parse_document(&video_page_text);
            let iframe_selector = Selector::parse("iframe").unwrap();
            let mut found_iframes = false;
            for element in doc.select(&iframe_selector) {
                if let Some(src) = element.value().attr("src") {
                    log::info!("DEBUG: Found iframe src: {}", src);
                    found_iframes = true;
                }
            }
            if !found_iframes {
                log::info!("DEBUG: No iframes found in the page.");
            }

            // Debug: Check scripts for potential packed content or player vars
            let script_selector = Selector::parse("script").unwrap();
            for element in doc.select(&script_selector) {
                if let Some(src) = element.value().attr("src") {
                    if src.contains("player") || src.contains("config") {
                        log::info!("DEBUG: Found suspicious script src: {}", src);
                    }
                }
            }
        }

        if source
            .arguments
            .search_config
            .match_video
            .enable_nested_url
            .unwrap_or(false)
        {
            if let Some(ref nested_regex_str) =
                source.arguments.search_config.match_video.match_nested_url
            {
                // Skip if regex is "$^" (assuming it means "skip" or match nothing valid)
                if nested_regex_str != "$^" {
                    log::info!("Trying to find nested URL with: {}", nested_regex_str);
                    if let Ok(nested_re) = Regex::new(nested_regex_str) {
                        // fancy_regex::captures returns Result<Option<Captures>, Error>
                        if let Ok(Some(caps)) = nested_re.captures(&video_page_text) {
                            let mut nested_url = if caps.len() > 1 {
                                caps.get(1).map_or("", |m| m.as_str()).to_string()
                            } else {
                                caps.get(0).map_or("", |m| m.as_str()).to_string()
                            };

                            if !nested_url.is_empty() {
                                // Handle relative URL
                                if !nested_url.starts_with("http") {
                                    nested_url = absolutize_url(&episode_url, &nested_url);
                                }

                                log::info!("FOUND NESTED URL: {}", nested_url);
                                // Fetch the nested page
                                let mut nested_req = client.get(&nested_url);
                                if let Some(ref headers) = source
                                    .arguments
                                    .search_config
                                    .match_video
                                    .add_headers_to_video
                                {
                                    for (k, v) in headers {
                                        nested_req = nested_req.header(k, v);
                                    }
                                }
                                if let Some(ref cookies) =
                                    source.arguments.search_config.match_video.cookies
                                {
                                    nested_req = nested_req.header("Cookie", cookies);
                                }

                                if let Ok(resp) = nested_req.send().await {
                                    if let Ok(text) = resp.text().await {
                                        video_page_text = text;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    log::info!("Skipping nested match because regex is $^");
                }
            }
        }

        // 直接使用JSON配置的正则表达式，不使用内置兜底逻辑
        let regex_str = &source.arguments.search_config.match_video.match_video_url;
        log::info!("Matching video with regex: {}", regex_str);

        if let Ok(re) = Regex::new(regex_str) {
            // fancy_regex::captures returns Result<Option<Captures>, Error>
            if let Ok(Some(caps)) = re.captures(&video_page_text) {
                // Try to find a named capture group "v" or default to whole match or first group
                // In sample.json: `url=(?<v>.+playlist.m3u8)`

                let mut video_url = String::new();
                if let Some(v) = caps.name("v") {
                    video_url = v.as_str().to_string();
                } else if caps.len() > 1 {
                    // Start checking from group 1, pick first non-empty
                    for i in 1..caps.len() {
                        if let Some(m) = caps.get(i) {
                            if !m.as_str().is_empty() {
                                video_url = m.as_str().to_string();
                                break;
                            }
                        }
                    }
                    // If no group matched, maybe fall back?
                } else {
                    video_url = caps.get(0).map_or("", |m| m.as_str()).to_string();
                }

                if !video_url.is_empty() {
                    // Simple URL decoding if needed (often urls are encoded in query params)
                    if video_url.contains("%") {
                        if let Ok(decoded) = urlencoding::decode(&video_url) {
                            video_url = decoded.into_owned();
                        }
                    }

                    log::info!("FOUND VIDEO URL: {}", video_url);
                    return Ok(video_url);
                }
            } else {
                log::warn!("No video match found in text with regex: {}", regex_str);
                // 不使用兜底逻辑，直接返回错误，让用户修改JSON配置
            }
        } else {
            log::error!("Failed to compile regex: {}", regex_str);
        }
    }

    Err(anyhow::anyhow!(
        "No video found - regex did not match the page content"
    ))
}

fn text_window_around_match(
    text: &str,
    match_start: usize,
    before_chars: usize,
    after_chars: usize,
) -> String {
    let mut prefix: Vec<char> = text[..match_start]
        .chars()
        .rev()
        .take(before_chars)
        .collect();
    prefix.reverse();
    let suffix: String = text[match_start..].chars().take(after_chars).collect();
    prefix.into_iter().chain(suffix.chars()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::Method;
    use reqwest::Client;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct ClosedEmitter {
        attempts: AtomicUsize,
    }

    impl SearchPlayResultEmitter for ClosedEmitter {
        fn emit(&self, _result: SearchPlayResult) -> bool {
            self.attempts.fetch_add(1, Ordering::SeqCst);
            false
        }
    }

    fn stream_result(source_name: &str) -> SearchPlayResult {
        SearchPlayResult {
            source_name: source_name.to_string(),
            play_page_url: format!("https://example.test/{source_name}"),
            video_regex: "video".to_string(),
            direct_video_url: None,
            cookies: None,
            headers: None,
            channel_name: None,
            channel_index: None,
            captcha_config_json: None,
            enable_nested_url: false,
            match_nested_url: None,
        }
    }

    #[tokio::test]
    async fn closed_result_sink_stops_polling_remaining_source_searches() {
        let polls = Arc::new(AtomicUsize::new(0));
        let stream_polls = polls.clone();
        let stream = futures::stream::unfold(0, move |index| {
            let stream_polls = stream_polls.clone();
            async move {
                stream_polls.fetch_add(1, Ordering::SeqCst);
                (index < 2).then(|| {
                    let name = format!("Source{index}");
                    ((name.clone(), Ok(stream_result(&name))), index + 1)
                })
            }
        });
        let emitter = ClosedEmitter {
            attempts: AtomicUsize::new(0),
        };

        forward_search_play_results(stream, &emitter).await;

        assert_eq!(emitter.attempts.load(Ordering::SeqCst), 1);
        assert_eq!(polls.load(Ordering::SeqCst), 1);
    }

    fn no_proxy_client() -> Client {
        Client::builder()
            .no_proxy()
            .build()
            .expect("failed to build loopback test client")
    }

    /// Build a `MediaSource` whose search URL points at the loopback server.
    fn indexed_source(search_url: &str, video_regex: &str) -> MediaSource {
        let raw = format!(
            r#"{{
                "factoryId": "web-selector",
                "arguments": {{
                    "name": "PlaySource",
                    "searchConfig": {{
                        "searchUrl": "{search_url}",
                        "subjectFormatId": "indexed",
                        "selectorSubjectFormatIndexed": {{
                            "selectNames": "li.result span.name",
                            "selectLinks": "li.result a.link"
                        }},
                        "channelFormatId": "no-channel",
                        "selectorChannelFormatNoChannel": {{
                            "selectEpisodes": "div.play-list a.ep"
                        }},
                        "matchVideo": {{ "matchVideoUrl": "{video_regex}" }}
                    }}
                }}
            }}"#
        );
        serde_json::from_str(&raw).expect("fixture MediaSource JSON must parse")
    }

    #[tokio::test]
    async fn search_single_source_resolves_episode_url_and_preserves_port() {
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

        let search_url = format!("{}/search?q={{keyword}}", server.base_url());
        // `\\.` in the raw literal becomes a valid `\.` JSON escape, decoding
        // back to the regex `url=(?<v>.+\.m3u8)`.
        let mut source = indexed_source(&search_url, r"url=(?<v>.+\\.m3u8)");
        source.arguments.captcha_config = Some(
            serde_json::from_value(serde_json::json!({
                "enable": true,
                "type": "image",
                "detectSelector": "form.captcha"
            }))
            .unwrap(),
        );
        let client = no_proxy_client();

        // Ask for absolute episode 2 explicitly.
        let result = search_single_source(&client, &source, "测试动画", Some(2), None)
            .await
            .expect("search should resolve a play page URL");

        assert_eq!(result.source_name, "PlaySource");
        // The relative /detail/1 link and /play/2 href were absolutized against
        // the loopback origin — the non-default port must survive (RT-2-001).
        assert_eq!(result.play_page_url, server.url("/play/2"));
        assert_eq!(result.video_regex, r"url=(?<v>.+\.m3u8)");
        assert!(!result.enable_nested_url);
        let captcha: serde_json::Value =
            serde_json::from_str(result.captcha_config_json.as_deref().unwrap()).unwrap();
        assert_eq!(captcha["enable"], true);
        assert_eq!(captcha["type"], "image");

        // Search page fetched once; detail page fetched once.
        assert_eq!(server.request_count(Method::GET, "/search"), 1);
        assert_eq!(server.request_count(Method::GET, "/detail/1"), 1);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn search_single_source_errors_when_search_has_no_match() {
        let server = TestServer::spawn([TestRoute::get(
            "/search",
            TestResponse::ok("<html><body><ul class=\"search-results\"></ul></body></html>"),
        )])
        .await;

        let search_url = format!("{}/search?q={{keyword}}", server.base_url());
        let source = indexed_source(&search_url, "x");
        let client = no_proxy_client();

        let result = search_single_source(&client, &source, "测试动画", None, None).await;
        let err = result.err().expect("no candidates should surface an error");
        assert!(err.to_string().contains("No matching anime found"));

        // Detail must never be requested when the search yields nothing.
        assert_eq!(server.request_count(Method::GET, "/detail/1"), 0);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn search_single_source_falls_back_to_first_episode_when_number_absent() {
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

        let search_url = format!("{}/search?q={{keyword}}", server.base_url());
        let source = indexed_source(&search_url, "x");
        let client = no_proxy_client();

        // No episode number → select_episode_by_number returns the first anchor.
        let result = search_single_source(&client, &source, "测试动画", None, None)
            .await
            .expect("search should resolve first episode");
        assert_eq!(result.play_page_url, server.url("/play/1"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn search_single_source_falls_back_to_next_ranked_detail() {
        let search_html = r#"
            <ul class="search-results">
              <li class="result"><span class="name">测试动画</span><a class="link" href="/detail/empty">first</a></li>
              <li class="result"><span class="name">测试动画</span><a class="link" href="/detail/1">second</a></li>
            </ul>"#;
        let server = TestServer::spawn([
            TestRoute::get("/search", TestResponse::ok(search_html)),
            TestRoute::get(
                "/detail/empty",
                TestResponse::fixture("generic_scraper/detail_empty.html"),
            ),
            TestRoute::get(
                "/detail/1",
                TestResponse::fixture("generic_scraper/detail_no_channel.html"),
            ),
        ])
        .await;

        let source = indexed_source(&format!("{}/search?q={{keyword}}", server.base_url()), "x");
        let result = search_single_source(&no_proxy_client(), &source, "测试动画", Some(2), None)
            .await
            .expect("the second equally ranked detail page should be tried");

        assert_eq!(result.play_page_url, server.url("/play/2"));
        assert_eq!(server.request_count(Method::GET, "/detail/empty"), 1);
        assert_eq!(server.request_count(Method::GET, "/detail/1"), 1);
        server.shutdown().await;
    }

    #[test]
    fn text_window_around_match_respects_unicode_boundaries() {
        let text = format!("{}m3u8{}", "中".repeat(40), "尾".repeat(50));
        let match_start = text.find("m3u8").unwrap();
        let preview = text_window_around_match(&text, match_start, 10, 12);

        assert!(preview.starts_with(&"中".repeat(10)));
        assert!(preview.contains("m3u8"));
        assert!(preview.ends_with(&"尾".repeat(8)));
    }

    #[tokio::test]
    async fn full_playback_flow_applies_headers_cookies_nested_url_and_unicode_logging() {
        let _guard = isolate_runtime_config();
        let play_html = format!(
            "{}m3u8<iframe src=\"../nested/player\"></iframe>",
            "播放页中文".repeat(30)
        );
        let server = TestServer::spawn([
            TestRoute::get(
                "/search",
                TestResponse::fixture("generic_scraper/search_indexed.html"),
            ),
            TestRoute::get(
                "/detail/1",
                TestResponse::fixture("generic_scraper/detail_no_channel.html"),
            ),
            TestRoute::get("/play/1", TestResponse::ok(play_html)),
            TestRoute::get(
                "/nested/player",
                TestResponse::ok("url=https%3A%2F%2Fmedia.example%2Fvideo.m3u8"),
            ),
        ])
        .await;

        let source: MediaSource = serde_json::from_value(serde_json::json!({
            "factoryId": "web-selector",
            "arguments": {
                "name": "FullFlowSource",
                "searchConfig": {
                    "searchUrl": format!("{}/search?q={{keyword}}", server.base_url()),
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
                        "matchVideoUrl": "url=(?<v>.+m3u8)",
                        "enableNestedUrl": true,
                        "matchNestedUrl": "src=\"([^\"]+)\"",
                        "cookies": "session=rt2",
                        "addHeadersToVideo": { "x-rt2-test": "present" }
                    }
                }
            }
        }))
        .unwrap();

        let video_url =
            search_and_play_sources(&no_proxy_client(), vec![source], "测试动画", Some(1), None)
                .await
                .expect("the complete playback chain should resolve a video URL");

        assert_eq!(video_url, "https://media.example/video.m3u8");
        for path in ["/play/1", "/nested/player"] {
            let request = server
                .requests()
                .into_iter()
                .find(|request| request.uri.path() == path)
                .unwrap_or_else(|| panic!("missing request for {path}"));
            assert_eq!(request.headers["cookie"], "session=rt2");
            assert_eq!(request.headers["x-rt2-test"], "present");
        }
        server.shutdown().await;
    }
}
