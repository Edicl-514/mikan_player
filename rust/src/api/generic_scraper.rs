use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use fancy_regex::Regex;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize}; // Added Serialize
use serde_json::Value;
use std::fs;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceState {
    pub name: String,
    pub enabled: bool,
}

lazy_static::lazy_static! {
    /// 匹配季数相关的关键词
    static ref SEASON_RE: Regex = Regex::new(r"(?i)第[一二三四五六七八九十\d]+季|Part\s*\d+|\d+(st|nd|rd|th)\s*Season|Season\s*\d+").unwrap();
}

/// 预处理搜索词，提取核心动画名称
/// 参考 mikan.rs 的实现
fn preprocess_search_term(name: &str) -> String {
    let cleaned_name = name.trim();
    
    // 判断是否为标点符号（中日文标点 + ASCII标点）
    let is_punctuation = |c: char| -> bool {
        c.is_ascii_punctuation()
            || "\u{3002}\u{FF01}\u{FF0C}\u{3001}\u{FF1F}\u{FF08}\u{FF09}\u{300A}\u{300B}\u{3010}\u{3011}\u{201C}\u{201D}\u{2018}\u{2019}\u{300C}\u{300D}\u{300E}\u{300F}\u{301C}\u{FF5E}\u{00B7}\u{2022}\u{2160}\u{2161}\u{2162}\u{2163}\u{2164}\u{2165}\u{2166}\u{2167}\u{2168}\u{2169}\u{216A}\u{216B}".contains(c)
    };

    // 1. 将所有标点替换为空格
    let mut cleaned: String = name
        .chars()
        .map(|c| if is_punctuation(c) { ' ' } else { c })
        .collect();

    // 2. 移除季数相关关键词
    cleaned = SEASON_RE.replace_all(&cleaned, " ").to_string();

    // 3. 按空格分割，取最长的片段作为搜索词
    let segments: Vec<&str> = cleaned
        .split_whitespace()
        .filter(|s| s.chars().count() >= 1)
        .collect();

    let final_search_str = segments
        .iter()
        .max_by_key(|s| s.chars().count())
        .map(|s| s.to_string())
        .unwrap_or_else(|| cleaned_name.to_string());

    log::info!("Preprocessed search term: '{}' -> '{}'", name, final_search_str);
    final_search_str
}

#[derive(Debug, Deserialize, Clone)]
pub struct SampleRoot {
    #[serde(rename = "exportedMediaSourceDataList")]
    pub exported_media_source_data_list: ExportedMediaSourceDataList,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ExportedMediaSourceDataList {
    #[serde(rename = "mediaSources")]
    pub media_sources: Vec<MediaSource>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct MediaSource {
    #[serde(rename = "factoryId")]
    pub factory_id: String,
    pub arguments: SourceArguments,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SourceArguments {
    pub name: String,
    #[serde(rename = "searchConfig")]
    pub search_config: SearchConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SearchConfig {
    #[serde(rename = "searchUrl")]
    pub search_url: String,

    // Selectors for result list
    #[serde(rename = "selectorSubjectFormatIndexed")]
    pub selector_subject_format_indexed: Option<SelectorSubjectFormatIndexed>,

    // Selectors for channel/episodes
    #[serde(rename = "selectorChannelFormatFlattened")]
    pub selector_channel_format_flattened: Option<SelectorChannelFormatFlattened>,
    #[serde(rename = "selectorChannelFormatNoChannel")]
    pub selector_channel_format_no_channel: Option<SelectorChannelFormatNoChannel>,

    // Video matching
    #[serde(rename = "matchVideo")]
    pub match_video: MatchVideo,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorSubjectFormatIndexed {
    #[serde(rename = "selectNames")]
    pub select_names: String,
    #[serde(rename = "selectLinks")]
    pub select_links: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorChannelFormatFlattened {
    #[serde(rename = "selectEpisodeLists")]
    pub select_episode_lists: String,
    #[serde(rename = "selectEpisodesFromList")]
    pub select_episodes_from_list: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorChannelFormatNoChannel {
    #[serde(rename = "selectEpisodes")]
    pub select_episodes: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct MatchVideo {
    #[serde(rename = "matchVideoUrl")]
    pub match_video_url: String,

    #[serde(rename = "enableNestedUrl")]
    pub enable_nested_url: Option<bool>,

    #[serde(rename = "matchNestedUrl")]
    pub match_nested_url: Option<String>,

    #[serde(rename = "addHeadersToVideo")]
    pub add_headers_to_video: Option<std::collections::HashMap<String, String>>,
}

/// 提取动画名称的核心部分（去除"第X季"等后缀）
fn extract_core_name(name: &str) -> String {
    // 去除常见的季数后缀
    let patterns = [
        r"\s*第[一二三四五六七八九十\d]+季",
        r"\s*Season\s*\d+",
        r"\s*S\d+",
        r"\s*Part\s*\d+",
        r"\s*\d+期",
    ];
    
    let mut result = name.to_string();
    for pattern in patterns {
        if let Ok(re) = Regex::new(pattern) {
            result = re.replace_all(&result, "").to_string();
        }
    }
    result.trim().to_string()
}

/// 计算标题匹配分数 (0-100)
fn calculate_match_score(title: &str, full_name: &str, core_name: &str) -> i32 {
    let title_lower = title.to_lowercase();
    let full_lower = full_name.to_lowercase();
    let core_lower = core_name.to_lowercase();
    
    // 完全匹配
    if title_lower == full_lower {
        return 100;
    }
    
    // 标题包含完整搜索词
    if title_lower.contains(&full_lower) {
        return 95;
    }
    
    // 搜索词包含标题（标题可能是简写）
    if full_lower.contains(&title_lower) && title_lower.len() > 3 {
        return 85;
    }
    
    // 标题包含核心名称
    if title_lower.contains(&core_lower) {
        return 80;
    }
    
    // 核心名称包含标题
    if core_lower.contains(&title_lower) && title_lower.len() > 3 {
        return 70;
    }
    
    // 计算关键词重叠
    let title_chars: std::collections::HashSet<char> = title_lower.chars().filter(|c| !c.is_whitespace()).collect();
    let core_chars: std::collections::HashSet<char> = core_lower.chars().filter(|c| !c.is_whitespace()).collect();
    
    if !title_chars.is_empty() && !core_chars.is_empty() {
        let intersection = title_chars.intersection(&core_chars).count();
        let union = title_chars.union(&core_chars).count();
        let jaccard = (intersection as f64 / union as f64 * 100.0) as i32;
        return jaccard;
    }
    
    0
}

/// 修复被混淆的视频URL
/// 某些网站会对URL做简单的字符替换混淆：n->o, l->m, 域名中的.->/ 
fn deobfuscate_video_url(url: &str) -> String {
    // 分离协议部分 (https://)
    let (protocol, rest) = if let Some(idx) = url.find("://") {
        (&url[..idx + 3], &url[idx + 3..])
    } else {
        ("", url)
    };
    
    // 找到路径开始的位置（第一个单独的 /）
    // 在混淆的URL中，域名部分的 . 被替换成了 /
    // 例如: ai/girigirilove/oet/zijian/... 应该是 ai.girigirilove.net/zijian/...
    
    // 替换常见的混淆模式
    let deobfuscated = rest
        // TLD 混淆
        .replace("/oet/", ".net/")
        .replace("/con/", ".com/")
        .replace("/org/", ".org/")
        ;
    
    // 进一步处理：修复域名部分
    let parts: Vec<&str> = deobfuscated.split('/').collect();
    
    // 重建URL，智能判断哪些 / 应该是 .
    let mut final_url = String::from(protocol);
    let mut in_domain = true;
    
    for (i, part) in parts.iter().enumerate() {
        if i == 0 {
            final_url.push_str(part);
            continue;
        }
        
        // 判断是否还在域名部分
        // 如果当前部分看起来像TLD或域名组件，则用 . 连接
        // 如果看起来像路径（包含常见路径词或较长），则切换到路径模式
        let is_tld = matches!(*part, "net" | "com" | "org" | "io" | "tv" | "cc" | "top" | "xyz");
        let looks_like_path = part.contains("20") // 年份
            || part.len() > 20 
            || part.contains("anime")
            || part.contains("video")
            || part.contains("play")
            || part.contains("zijian")
            || part.contains("cht")
            || part.contains("chs");
        
        if in_domain && (is_tld || (!looks_like_path && i <= 2)) {
            final_url.push('.');
            final_url.push_str(part);
            if is_tld {
                in_domain = false; // TLD后面就是路径了
            }
        } else {
            in_domain = false;
            final_url.push('/');
            final_url.push_str(part);
        }
    }
    
    // 最后做字符级别的混淆修复
    // o -> n, m -> l 在特定上下文中
    let final_url = final_url
        .replace("omdanime", "oldanime")
        .replace("omda", "olda")
        .replace("Sousouoo", "Sousouno")
        .replace("playmist", "playlist")
        .replace("playoist", "playlist")
        .replace(".oet", ".net")  // 以防上面没处理到
        ;
    
    final_url
}

/// 尝试从页面中解析 player_aaaa 变量并提取视频 URL
/// 这是很多视频网站使用的通用模式，视频URL存储在一个JS变量中
fn try_extract_player_aaaa_url(page_text: &str) -> Option<String> {
    // 匹配 var player_aaaa = {...} 格式
    let re = Regex::new(r#"var\s+player_aaaa\s*=\s*(\{[^;]+\})"#).ok()?;
    
    if let Ok(Some(caps)) = re.captures(page_text) {
        let json_str = caps.get(1)?.as_str();
        log::info!("DEBUG: Found player_aaaa JSON: {}...", &json_str[..json_str.len().min(200)]);
        
        if let Ok(json_value) = serde_json::from_str::<Value>(json_str) {
            // 获取加密类型和URL
            let encrypt = json_value.get("encrypt").and_then(|v| v.as_i64()).unwrap_or(0);
            let url_encoded = json_value.get("url").and_then(|v| v.as_str())?;
            
            log::info!("DEBUG: encrypt={}, url_encoded={}...", encrypt, &url_encoded[..url_encoded.len().min(50)]);
            
            // 根据加密类型解码
            let decoded_url = match encrypt {
                0 => {
                    // 无加密，直接使用
                    url_encoded.to_string()
                }
                1 => {
                    // escape 编码，使用URL解码
                    urlencoding::decode(url_encoded).ok()?.into_owned()
                }
                2 => {
                    // base64 编码的 URL 编码字符串
                    let base64_decoded = BASE64.decode(url_encoded).ok()?;
                    let utf8_str = String::from_utf8(base64_decoded).ok()?;
                    urlencoding::decode(&utf8_str).ok()?.into_owned()
                }
                _ => {
                    log::warn!("Unknown encrypt type: {}", encrypt);
                    return None;
                }
            };
            
            log::info!("DEBUG: Decoded URL (before deobfuscate): {}", decoded_url);
            
            // 尝试修复混淆的URL
            let final_url = deobfuscate_video_url(&decoded_url);
            log::info!("DEBUG: Final URL (after deobfuscate): {}", final_url);
            
            // 检查解码后的URL是否是有效的视频URL
            if final_url.contains("m3u8") || final_url.contains("mp4") || final_url.starts_with("http") {
                return Some(final_url);
            }
        }
    }
    
    None
}

/// 搜索结果：包含播放页面URL和视频URL匹配正则
pub struct SearchPlayResult {
    /// 源名称
    pub source_name: String,
    /// 播放页面 URL
    pub play_page_url: String,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: String,
    /// 直接解析得到的视频URL（如果有）
    pub direct_video_url: Option<String>,
}

/// 从订阅地址拉取播放源配置 JSON
/// 优先使用用户设置的订阅地址，失败时尝试本地备份
async fn load_playback_source_config(client: &reqwest::Client) -> anyhow::Result<String> {
    let sub_url = crate::api::config::get_playback_sub_url();
    log::info!("Loading playback source config from: {}", sub_url);

    // 首先尝试从订阅地址拉取
    match client.get(&sub_url).send().await {
        Ok(resp) => match resp.text().await {
            Ok(content) => {
                log::info!("Successfully loaded config from subscription URL");
                return Ok(content);
            }
            Err(e) => {
                log::warn!("Failed to read response from subscription URL: {}", e);
            }
        },
        Err(e) => {
            log::warn!("Failed to fetch from subscription URL: {}", e);
        }
    }

    // 降级策略：尝试从本地文件读取备份
    log::info!("Trying to load from local backup files...");
    let local_paths = vec![
        "sample.json",
        "../sample.json",
        "d:/code/mikan_player/sample.json",
    ];

    for p in local_paths {
        if let Ok(c) = fs::read_to_string(p) {
            log::info!("Loaded config from local file: {}", p);
            return Ok(c);
        }
    }

    Err(anyhow::anyhow!(
        "Could not load playback source config from subscription URL or local files"
    ))
}

/// 预加载播放源配置（应用启动和设置更改时调用）
/// 验证订阅地址的JSON格式是否有效
pub async fn preload_playback_sources() -> anyhow::Result<()> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    // 验证JSON格式
    let _root: SampleRoot = serde_json::from_str(&content)?;
    log::info!("Playback source config validated successfully");

    Ok(())
}

/// 获取所有播放源的状态
pub async fn get_playback_sources() -> anyhow::Result<Vec<SourceState>> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;
    let root: SampleRoot = serde_json::from_str(&content)?;

    let mut sources = Vec::new();
    for source in root.exported_media_source_data_list.media_sources {
        let name = source.arguments.name;
        let enabled = crate::api::config::is_source_enabled(&name);
        sources.push(SourceState { name, enabled });
    }
    Ok(sources)
}

/// 搜索所有源，返回所有找到的播放页面URL列表
/// Flutter 端可以使用 WebView 加载这些 URL 来拦截视频请求
pub async fn generic_search_play_pages(anime_name: String) -> anyhow::Result<Vec<SearchPlayResult>> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;
    
    // 并发搜索所有源
    let futures: Vec<_> = root
        .exported_media_source_data_list
        .media_sources
        .iter()
        .filter(|source| {
             if !crate::api::config::is_source_enabled(&source.arguments.name) {
                 log::info!("Skipping disabled source: {}", source.arguments.name);
                 false
             } else {
                 true
             }
        })
        .map(|source| {
            let client = client.clone();
            let source = source.clone();
            let anime_name = anime_name.clone();
            async move {
                log::info!("Searching source: {}", source.arguments.name);
                search_single_source(&client, &source, &anime_name).await
            }
        })
        .collect();
    
    // 等待所有搜索完成
    let all_results = futures::future::join_all(futures).await;
    
    // 过滤出成功的结果
    let results: Vec<SearchPlayResult> = all_results
        .into_iter()
        .filter_map(|r| r.ok())
        .collect();
    
    Ok(results)
}

/// 搜索所有源，以流的形式返回结果（每个源搜索完成后立即返回）
/// 这样可以让UI实时显示搜索结果，而不是等所有源都搜索完毕
pub async fn generic_search_play_pages_stream(
    anime_name: String,
    sink: crate::frb_generated::StreamSink<SearchPlayResult>,
) -> anyhow::Result<()> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;
    
    // 使用 FuturesUnordered 来处理每个源的搜索结果
    use futures::stream::{FuturesUnordered, StreamExt};
    
    let mut tasks = FuturesUnordered::new();
    
    // Create configured tasks
    for source in root.exported_media_source_data_list.media_sources {
        if !crate::api::config::is_source_enabled(&source.arguments.name) {
             log::info!("Skipping disabled source: {}", source.arguments.name);
             continue;
        }

        let client = client.clone();
        let anime_name = anime_name.clone();
        let task = async move {
            log::info!("Searching source: {}", source.arguments.name);
            search_single_source(&client, &source, &anime_name).await
        };
        tasks.push(task);
    }
    
    // 每个源搜索完成后立即发送结果
    while let Some(result) = tasks.next().await {
        if let Ok(search_result) = result {
            log::info!("Source '{}' completed, sending result to stream", search_result.source_name);
            sink.add(search_result).ok();
        } else if let Err(e) = result {
            log::warn!("Source search failed: {}", e);
        }
    }
    
    Ok(())
}

/// 搜索单个源
async fn search_single_source(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
) -> anyhow::Result<SearchPlayResult> {
    let source_name = source.arguments.name.clone();
    let video_regex = source.arguments.search_config.match_video.match_video_url.clone();
    
    // 预处理搜索词（去除标点、季数等）
    let search_term = preprocess_search_term(anime_name);
    
    // 提取核心关键词用于匹配（去除"第X季"等后缀）
    let core_name = extract_core_name(anime_name);
    log::info!("[{}] Search term: '{}', Core name: '{}'", source_name, search_term, core_name);
    
    // Step 1: 搜索（使用预处理后的搜索词）
    let search_url = source
        .arguments
        .search_config
        .search_url
        .replace("{keyword}", &search_term);
    log::info!("[{}] Searching: {}", source_name, search_url);

    let resp_text = client.get(&search_url).send().await?.text().await?;

    let detail_url = {
        let document = Html::parse_document(&resp_text);
        let mut found_url = String::new();
        let mut best_match_score = 0;
        
        if let Some(ref format) = source.arguments.search_config.selector_subject_format_indexed {
            if let (Ok(name_sel), Ok(link_sel)) = (
                Selector::parse(&format.select_names),
                Selector::parse(&format.select_links),
            ) {
                let names: Vec<_> = document.select(&name_sel).collect();
                let links: Vec<_> = document.select(&link_sel).collect();
                
                log::info!("[{}] Found {} results", source_name, names.len().min(links.len()));

                for (name_el, link_el) in names.iter().zip(links.iter()) {
                    let title = name_el.text().collect::<String>().trim().to_string();
                    let href = link_el.value().attr("href").unwrap_or("").to_string();

                    log::info!("[{}] Result: {} -> {}", source_name, title, href);

                    // 计算匹配分数
                    let score = calculate_match_score(&title, anime_name, &core_name);
                    
                    if score > best_match_score && score >= 50 {
                        best_match_score = score;
                        if href.starts_with("http") {
                            found_url = href;
                        } else {
                            let base_url = if let Ok(u) = url::Url::parse(&search_url) {
                                format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                            } else {
                                "".to_string()
                            };
                            found_url = format!("{}{}", base_url, href);
                        }
                        log::info!("[{}] Best match so far: {} (score: {})", source_name, title, score);
                    }
                }
            }
        }
        found_url
    };

    if detail_url.is_empty() {
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    log::info!("[{}] Found detail URL: {}", source_name, detail_url);

    // Step 2: 获取剧集列表
    let detail_resp_text = client.get(&detail_url).send().await?.text().await?;

    let episode_url = {
        let detail_doc = Html::parse_document(&detail_resp_text);
        let mut found_url = String::new();
        
        if let Some(ref format) = source.arguments.search_config.selector_channel_format_flattened {
            if let (Ok(list_sel), Ok(item_sel)) = (
                Selector::parse(&format.select_episode_lists),
                Selector::parse(&format.select_episodes_from_list),
            ) {
                if let Some(list_container) = detail_doc.select(&list_sel).next() {
                    if let Some(ep) = list_container.select(&item_sel).next() {
                        let href = ep.value().attr("href").unwrap_or("").to_string();
                        if !href.is_empty() {
                            if href.starts_with("http") {
                                found_url = href;
                            } else {
                                let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                    format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                } else {
                                    "".to_string()
                                };
                                found_url = format!("{}{}", base_url, href);
                            }
                        }
                    }
                }
            }
        } else if let Some(ref format) = source.arguments.search_config.selector_channel_format_no_channel {
            if let Ok(ep_sel) = Selector::parse(&format.select_episodes) {
                if let Some(ep) = detail_doc.select(&ep_sel).next() {
                    let href = ep.value().attr("href").unwrap_or("").to_string();
                    if !href.is_empty() {
                        if href.starts_with("http") {
                            found_url = href;
                        } else {
                            let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                            } else {
                                "".to_string()
                            };
                            found_url = format!("{}{}", base_url, href);
                        }
                    }
                }
            }
        }
        found_url
    };

    if episode_url.is_empty() {
        return Err(anyhow::anyhow!("No episodes found"));
    }

    log::info!("[{}] Found episode URL: {}", source_name, episode_url);

    // Step 3: 尝试直接获取视频URL（可选，主要让 WebView 处理）
    let mut direct_video_url = None;
    
    // 尝试获取页面并解析 player_aaaa
    if let Ok(resp) = client.get(&episode_url).send().await {
        if let Ok(video_page_text) = resp.text().await {
            if let Some(player_url) = try_extract_player_aaaa_url(&video_page_text) {
                log::info!("[{}] Found direct video URL from player_aaaa: {}", source_name, player_url);
                direct_video_url = Some(player_url);
            }
        }
    }

    Ok(SearchPlayResult {
        source_name,
        play_page_url: episode_url,
        video_regex,
        direct_video_url,
    })
}

pub async fn generic_search_and_play(anime_name: String) -> anyhow::Result<String> {
    // 1. 从订阅地址拉取播放源配置 JSON
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;

    // 2. Iterate sources and try to find the anime
    for source in root.exported_media_source_data_list.media_sources {
        if !crate::api::config::is_source_enabled(&source.arguments.name) {
             continue;
        }
        log::info!("Trying source: {}", source.arguments.name);

        // --- Step 1: Search ---
        let search_url = source
            .arguments
            .search_config
            .search_url
            .replace("{keyword}", &anime_name);
        log::info!("Searching: {}", search_url);

        let resp_text = match client.get(&search_url).send().await {
            Ok(resp) => resp.text().await?,
            Err(e) => {
                log::warn!("Search failed for {}: {}", source.arguments.name, e);
                continue;
            }
        };

        let mut detail_url = String::new();
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
                        if title.contains(&anime_name) {
                            // Handle relative URLs
                            if href.starts_with("http") {
                                detail_url = href;
                            } else {
                                // Extract base URL from search_url or just concat
                                let base_url = if let Ok(u) = url::Url::parse(&search_url) {
                                    format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                } else {
                                    "".to_string()
                                };
                                detail_url = format!("{}{}", base_url, href);
                            }
                            break;
                        }
                    }
                }
            }
        } // document dropped here

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
                        // Find first episode
                        if let Some(ep) = list_container.select(&item_sel).next() {
                            let href = ep.value().attr("href").unwrap_or("").to_string();
                            if !href.is_empty() {
                                // Relative URL handling
                                if href.starts_with("http") {
                                    episode_url = href;
                                } else {
                                    let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                        format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                    } else {
                                        "".to_string()
                                    };
                                    episode_url = format!("{}{}", base_url, href);
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
                if let Ok(ep_sel) = Selector::parse(&format.select_episodes) {
                    if let Some(ep) = detail_doc.select(&ep_sel).next() {
                        let href = ep.value().attr("href").unwrap_or("").to_string();
                        if !href.is_empty() {
                            // Relative URL handling
                            if href.starts_with("http") {
                                episode_url = href;
                            } else {
                                let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                    format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                } else {
                                    "".to_string()
                                };
                                episode_url = format!("{}{}", base_url, href);
                            }
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
                let start = if *idx > 100 { *idx - 100 } else { 0 };
                let end = if *idx + 200 < video_page_text.len() {
                    *idx + 200
                } else {
                    video_page_text.len()
                };
                log::info!(
                    "DEBUG: Match #{}: ...{}...",
                    i + 1,
                    &video_page_text[start..end]
                        .replace("\n", " ")
                        .replace("\r", " ")
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
                            let mut nested_url = String::new();
                            // Try whole match or first group
                            if caps.len() > 1 {
                                nested_url = caps.get(1).map_or("", |m| m.as_str()).to_string();
                            } else {
                                nested_url = caps.get(0).map_or("", |m| m.as_str()).to_string();
                            }

                            if !nested_url.is_empty() {
                                // Handle relative URL
                                if !nested_url.starts_with("http") {
                                    let base_url = if let Ok(u) = url::Url::parse(&episode_url) {
                                        format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                                    } else {
                                        "".to_string()
                                    };
                                    nested_url = format!("{}{}", base_url, nested_url);
                                }

                                log::info!("FOUND NESTED URL: {}", nested_url);
                                // Fetch the nested page
                                if let Ok(resp) = client.get(&nested_url).send().await {
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

        // 优先尝试从 player_aaaa 变量中提取视频URL
        // 这是很多视频网站使用的通用模式
        if let Some(player_url) = try_extract_player_aaaa_url(&video_page_text) {
            log::info!("FOUND VIDEO URL from player_aaaa: {}", player_url);
            return Ok(player_url);
        }

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
                log::warn!("No video match found in text with primary regex.");

                // Fallback: try to find any http link ending in m3u8 or containing url=...m3u8
                // This is a heuristic to help the user debug or play even if the regex in JSON is slightly off
                log::info!("Attempting fallback heuristic search...");
                let fallback_re = Regex::new(
                    r#"(https?://[^"'\s\(\)<>]+?\.m3u8)|(url=(https?%3A%2F%2F[^"'\s]+))"#,
                )
                .unwrap();
                if let Ok(Some(caps)) = fallback_re.captures(&video_page_text) {
                    let mut video_url = caps.get(0).map_or("", |m| m.as_str()).to_string();
                    // If it matched the url= group
                    if video_url.starts_with("url=") {
                        video_url = video_url.replace("url=", "");
                    }

                    if video_url.contains("%") {
                        if let Ok(decoded) = urlencoding::decode(&video_url) {
                            video_url = decoded.into_owned();
                        }
                    }
                    log::info!("FOUND VIDEO URL (FALLBACK): {}", video_url);
                    return Ok(video_url);
                }
            }
        } else {
            log::error!("Failed to compile regex: {}", regex_str);
        }
    }

    Err(anyhow::anyhow!("No video found in any source"))
}
