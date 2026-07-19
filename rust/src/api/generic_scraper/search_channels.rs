use super::episode_table::*;
use super::headers_cookies::*;
use super::matching::*;
use super::region::*;
use super::source_config::*;
use super::types::*;
use scraper::Html;

trait SearchChannelsResultEmitter {
    fn emit(&self, result: SearchResultWithChannels) -> bool;
}

impl SearchChannelsResultEmitter for crate::frb_generated::StreamSink<SearchResultWithChannels> {
    fn emit(&self, result: SearchResultWithChannels) -> bool {
        self.add(result).is_ok()
    }
}

async fn forward_search_channel_results<S, E>(stream: S, emitter: &E)
where
    S: futures::Stream<Item = anyhow::Result<SearchResultWithChannels>>,
    E: SearchChannelsResultEmitter + ?Sized,
{
    use futures::stream::StreamExt;

    let mut stream = Box::pin(stream);
    while let Some(result) = stream.next().await {
        if let Ok(search_result) = result {
            log::info!(
                "Source '{}' completed with {} channels",
                search_result.source_name,
                search_result.channels.len()
            );
            if !emitter.emit(search_result) {
                break;
            }
        }
    }
}

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

    forward_search_channel_results(stream, &sink).await;

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::config::init_config;
    use crate::test_support::fixture::fixture_text;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::Method;
    use reqwest::Client;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct ClosedEmitter {
        attempts: AtomicUsize,
    }

    impl SearchChannelsResultEmitter for ClosedEmitter {
        fn emit(&self, _result: SearchResultWithChannels) -> bool {
            self.attempts.fetch_add(1, Ordering::SeqCst);
            false
        }
    }

    fn stream_result(source_name: &str) -> SearchResultWithChannels {
        SearchResultWithChannels {
            source_name: source_name.to_string(),
            detail_url: format!("https://example.test/{source_name}"),
            matched_title: "Anime".to_string(),
            channels: Vec::new(),
            episodes: Vec::new(),
            video_regex: "video".to_string(),
            cookies: None,
            headers: None,
            default_subtitle_language: None,
            default_resolution: None,
        }
    }

    #[tokio::test]
    async fn closed_channel_sink_stops_polling_remaining_source_searches() {
        let polls = Arc::new(AtomicUsize::new(0));
        let stream_polls = polls.clone();
        let stream = futures::stream::unfold(0, move |index| {
            let stream_polls = stream_polls.clone();
            async move {
                stream_polls.fetch_add(1, Ordering::SeqCst);
                (index < 2).then(|| (Ok(stream_result(&format!("Source{index}"))), index + 1))
            }
        });
        let emitter = ClosedEmitter {
            attempts: AtomicUsize::new(0),
        };

        forward_search_channel_results(stream, &emitter).await;

        assert_eq!(emitter.attempts.load(Ordering::SeqCst), 1);
        assert_eq!(polls.load(Ordering::SeqCst), 1);
    }

    fn no_proxy_client() -> Client {
        Client::builder()
            .no_proxy()
            .build()
            .expect("failed to build loopback test client")
    }

    /// Build a full `MediaSource` whose `searchUrl` targets the loopback server.
    /// `{keyword}` is carried in the query string so the server route matches on
    /// path alone regardless of how reqwest percent-encodes the CJK query value.
    fn source_json(base_url: &str, search_config_body: &str) -> MediaSource {
        let raw = format!(
            r#"{{
                "factoryId": "web-selector",
                "arguments": {{
                    "name": "LoopbackSource",
                    "searchConfig": {{
                        "searchUrl": "{base_url}/search?q={{keyword}}",
                        {search_config_body}
                    }}
                }}
            }}"#
        );
        serde_json::from_str(&raw).expect("fixture MediaSource JSON must parse")
    }

    /// Full search → detail → episode-table happy path over loopback, exercising
    /// the port-preserving relative-URL join (RT-2-001): the search fixture links
    /// to `/detail/1`, which must resolve back to the server's host:port.
    #[tokio::test]
    async fn search_with_channels_resolves_detail_and_episodes_over_loopback() {
        let _guard = isolate_runtime_config();
        let cache_dir = tempfile::tempdir().unwrap();
        init_config(
            cache_dir.path().to_string_lossy().to_string(),
            cache_dir.path().to_string_lossy().to_string(),
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
        ])
        .await;

        let source = source_json(
            &server.base_url(),
            r#""subjectFormatId": "indexed",
               "selectorSubjectFormatIndexed": {
                   "selectNames": "li.result span.name",
                   "selectLinks": "li.result a.link"
               },
               "channelFormatId": "no-channel",
               "selectorChannelFormatNoChannel": { "selectEpisodes": "div.play-list a.ep" },
               "matchVideo": { "matchVideoUrl": "url=(?<v>.+\\.m3u8)" }"#,
        );

        let client = no_proxy_client();
        let result = search_single_source_with_channels(&client, &source, "测试动画", None)
            .await
            .expect("search should succeed");

        assert_eq!(result.source_name, "LoopbackSource");
        // Relative /detail/1 resolved against the loopback origin, port intact.
        assert_eq!(result.detail_url, server.url("/detail/1"));
        assert_eq!(result.channels.len(), 1);
        assert_eq!(result.episodes.len(), 3);
        assert!(result.episodes[0].url.starts_with(&server.base_url()));
        assert_eq!(result.video_regex, "url=(?<v>.+\\.m3u8)");

        // Exactly one search request and one detail request were issued.
        assert_eq!(server.request_count(Method::GET, "/search"), 1);
        assert_eq!(server.request_count(Method::GET, "/detail/1"), 1);
        server.shutdown().await;
    }

    /// A runtime override supplying the search + detail HTML must short-circuit
    /// all network I/O: the loopback server receives zero requests.
    #[tokio::test]
    async fn runtime_override_html_bypasses_all_network_requests() {
        let _guard = isolate_runtime_config();
        let cache_dir = tempfile::tempdir().unwrap();
        init_config(
            cache_dir.path().to_string_lossy().to_string(),
            cache_dir.path().to_string_lossy().to_string(),
        );
        let server = TestServer::spawn([TestRoute::get(
            "/search",
            TestResponse::new(axum::http::StatusCode::INTERNAL_SERVER_ERROR, "boom"),
        )])
        .await;

        let source = source_json(
            &server.base_url(),
            r#""subjectFormatId": "indexed",
               "selectorSubjectFormatIndexed": {
                   "selectNames": "li.result span.name",
                   "selectLinks": "li.result a.link"
               },
               "channelFormatId": "no-channel",
               "selectorChannelFormatNoChannel": { "selectEpisodes": "div.play-list a.ep" },
               "matchVideo": { "matchVideoUrl": "x" }"#,
        );

        let override_item = SourceRuntimeOverride {
            source_name: "LoopbackSource".to_string(),
            cookies: Some("session=abc".to_string()),
            search_page_html: Some(fixture_text("generic_scraper/search_indexed.html")),
            search_page_url: Some(server.url("/search?q=x")),
            detail_page_html: Some(fixture_text("generic_scraper/detail_no_channel.html")),
            detail_page_url: Some(server.url("/detail/1")),
            skip_search_error: None,
        };

        let client = no_proxy_client();
        let result =
            search_single_source_with_channels(&client, &source, "测试动画", Some(&override_item))
                .await
                .expect("override-driven search should succeed");

        assert_eq!(result.episodes.len(), 3);
        // Cookie from the override is merged into the returned play cookies.
        assert_eq!(result.cookies.as_deref(), Some("session=abc"));
        // The server (which only serves 500s) was never contacted.
        assert!(server.requests().is_empty());
        server.shutdown().await;
    }

    /// When no subject scores above threshold the source yields an error rather
    /// than fetching a detail page.
    #[tokio::test]
    async fn search_with_no_matching_subject_errors_without_detail_fetch() {
        let server = TestServer::spawn([TestRoute::get(
            "/search",
            TestResponse::fixture("generic_scraper/search_indexed.html"),
        )])
        .await;

        let source = source_json(
            &server.base_url(),
            r#""subjectFormatId": "indexed",
               "selectorSubjectFormatIndexed": {
                   "selectNames": "li.result span.name",
                   "selectLinks": "li.result a.link"
               },
               "channelFormatId": "no-channel",
               "selectorChannelFormatNoChannel": { "selectEpisodes": "div.play-list a.ep" },
               "matchVideo": { "matchVideoUrl": "x" }"#,
        );

        let client = no_proxy_client();
        let err = search_single_source_with_channels(&client, &source, "毫无关联的查询词", None)
            .await
            .expect_err("no subject should match");
        assert!(err.to_string().contains("No matching anime found"));
        server.shutdown().await;
    }
}
