use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use fancy_regex::Regex;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize}; // Added Serialize
use serde_json::Value;
use std::fs;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceState {
    pub name: String,
    pub description: String,
    pub icon_url: String,
    pub tier: i32,
    pub default_subtitle_language: String,
    pub default_resolution: String,
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
    pub description: Option<String>,
    #[serde(rename = "iconUrl")]
    pub icon_url: Option<String>,
    pub tier: Option<i32>,
    #[serde(rename = "searchConfig")]
    pub search_config: SearchConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SearchConfig {
    #[serde(rename = "searchUrl")]
    pub search_url: String,

    #[serde(rename = "defaultSubtitleLanguage")]
    pub default_subtitle_language: Option<String>,

    #[serde(rename = "defaultResolution")]
    pub default_resolution: Option<String>,

    // Subject format selector
    #[serde(rename = "subjectFormatId")]
    pub subject_format_id: Option<String>,

    // Selectors for result list
    #[serde(rename = "selectorSubjectFormatA")]
    pub selector_subject_format_a: Option<SelectorSubjectFormatA>,
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
pub struct SelectorSubjectFormatA {
    #[serde(rename = "selectLists")]
    pub select_lists: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorSubjectFormatIndexed {
    #[serde(rename = "selectNames")]
    pub select_names: String,
    #[serde(rename = "selectLinks")]
    pub select_links: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorChannelFormatFlattened {
    #[serde(rename = "selectEpisodeLists")]
    pub select_episode_lists: String,
    #[serde(rename = "selectEpisodesFromList")]
    pub select_episodes_from_list: String,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SelectorChannelFormatNoChannel {
    #[serde(rename = "selectEpisodes")]
    pub select_episodes: String,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct MatchVideo {
    #[serde(rename = "matchVideoUrl")]
    pub match_video_url: String,

    #[serde(rename = "enableNestedUrl")]
    pub enable_nested_url: Option<bool>,

    #[serde(rename = "matchNestedUrl")]
    pub match_nested_url: Option<String>,

    #[serde(rename = "cookies")]
    pub cookies: Option<String>,

    #[serde(rename = "addHeadersToVideo")]
    pub add_headers_to_video: Option<std::collections::HashMap<String, String>>,
}

/// 解析中文数字（一二三四五六七八九十等）为阿拉伯数字
fn parse_chinese_number(s: &str) -> Option<u32> {
    // 首先尝试直接解析阿拉伯数字
    if let Ok(num) = s.parse::<u32>() {
        return Some(num);
    }
    
    let s = s.trim();
    if s.is_empty() {
        return None;
    }
    
    // 中文数字映射
    let digit_map: std::collections::HashMap<char, u32> = [
        ('零', 0), ('〇', 0),
        ('一', 1), ('壹', 1),
        ('二', 2), ('贰', 2), ('两', 2),
        ('三', 3), ('叁', 3),
        ('四', 4), ('肆', 4),
        ('五', 5), ('伍', 5),
        ('六', 6), ('陆', 6),
        ('七', 7), ('柒', 7),
        ('八', 8), ('捌', 8),
        ('九', 9), ('玖', 9),
    ].iter().cloned().collect();
    
    let mut result: u32 = 0;
    let mut current: u32 = 0;
    let mut has_ten = false;
    
    for c in s.chars() {
        if let Some(&digit) = digit_map.get(&c) {
            current = digit;
        } else if c == '十' || c == '拾' {
            has_ten = true;
            if current == 0 {
                // "十" 开头，表示 10
                result += 10;
            } else {
                // "X十"，表示 X * 10
                result += current * 10;
                current = 0;
            }
        } else if c == '百' || c == '佰' {
            result += current * 100;
            current = 0;
        } else {
            // 未知字符，忽略
        }
    }
    
    // 处理最后的个位数
    result += current;
    
    if result > 0 || has_ten {
        Some(result)
    } else {
        None
    }
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

/// 计算标题匹配分数 (0-100)，使用 Jaccard 相似度
fn calculate_match_score(title: &str, full_name: &str, core_name: &str) -> i32 {
    let title_lower = title.to_lowercase();
    let full_lower = full_name.to_lowercase();
    let core_lower = core_name.to_lowercase();
    
    // 计算标题与完整查询名的字符级 Jaccard 相似度
    let title_chars: std::collections::HashSet<char> = title_lower.chars().filter(|c| !c.is_whitespace()).collect();
    let full_chars: std::collections::HashSet<char> = full_lower.chars().filter(|c| !c.is_whitespace()).collect();
    
    let intersection_full = title_chars.intersection(&full_chars).count();
    let union_full = title_chars.union(&full_chars).count();
    
    let jaccard_full = if union_full > 0 {
        intersection_full as f64 / union_full as f64
    } else {
        0.0
    };
    
    // 计算标题与核心名的字符级 Jaccard 相似度
    let core_chars: std::collections::HashSet<char> = core_lower.chars().filter(|c| !c.is_whitespace()).collect();
    
    let intersection_core = title_chars.intersection(&core_chars).count();
    let union_core = title_chars.union(&core_chars).count();
    
    let jaccard_core = if union_core > 0 {
        intersection_core as f64 / union_core as f64
    } else {
        0.0
    };
    
    // 加权组合：优先考虑与完整查询名的相似度（包含季数等关键信息）
    // 权重：完整查询名 70%，核心名 30%
    let weighted_score = (jaccard_full * 0.7 + jaccard_core * 0.3) * 100.0;
    
    weighted_score as i32
}

/// 从集数列表中选择指定集号的链接
/// absolute_ep: 绝对集号（如第15集）
/// relative_ep: 相对集号（如当季第3集）
/// custom_pattern: 自定义的集号匹配正则表达式（从JSON配置读取）
/// 优先匹配绝对集号，找不到则回退到相对集号
fn select_episode_by_number(
    episode_elements: &[scraper::element_ref::ElementRef],
    absolute_ep: Option<u32>,
    relative_ep: Option<u32>,
    custom_pattern: Option<&str>,
) -> Option<String> {
    if episode_elements.is_empty() {
        return None;
    }
    
    // 如果没有指定集号，返回第一集
    if absolute_ep.is_none() && relative_ep.is_none() {
        return episode_elements.first()
            .and_then(|ep| ep.value().attr("href"))
            .map(|s| s.to_string());
    }
    
    // 尝试从元素文本中提取集号
    // 优先使用自定义正则表达式（从JSON配置读取），支持命名捕获组 (?<ep>...)
    let extract_episode_number = |text: &str| -> Option<u32> {
        // 如果提供了自定义正则表达式，优先使用
        if let Some(pattern) = custom_pattern {
            if !pattern.is_empty() && pattern != "$^" {
                if let Ok(re) = Regex::new(pattern) {
                    if let Ok(Some(caps)) = re.captures(text) {
                        // 优先尝试命名捕获组 "ep"
                        if let Some(ep_match) = caps.name("ep") {
                            let ep_str = ep_match.as_str();
                            // 处理中文数字
                            if let Some(num) = parse_chinese_number(ep_str) {
                                log::debug!("Custom pattern matched (named group 'ep'): '{}' -> {}", ep_str, num);
                                return Some(num);
                            }
                            // 尝试直接解析数字
                            if let Ok(num) = ep_str.parse::<u32>() {
                                log::debug!("Custom pattern matched (named group 'ep'): '{}' -> {}", ep_str, num);
                                return Some(num);
                            }
                        }
                        // 回退到第一个捕获组
                        if let Some(num_match) = caps.get(1) {
                            let num_str = num_match.as_str();
                            if let Some(num) = parse_chinese_number(num_str) {
                                log::debug!("Custom pattern matched (group 1): '{}' -> {}", num_str, num);
                                return Some(num);
                            }
                            if let Ok(num) = num_str.parse::<u32>() {
                                log::debug!("Custom pattern matched (group 1): '{}' -> {}", num_str, num);
                                return Some(num);
                            }
                        }
                    }
                }
            }
        }
        
        // 默认的集数匹配模式：第X集、第X话、EP X、Episode X、纯数字等
        let default_patterns = [
            r"第\s*(?<ep>[一二三四五六七八九十百千\d]+)\s*[集话]",
            r"EP\.?\s*(\d+)",
            r"Episode\s*(\d+)",
            r"第\s*(\d+)",
            r"^(\d+)$",
            r"\[(?<ep>\d+)\]",      // 匹配 [01]
            r"【(?<ep>\d+)】",      // 匹配 【01】
            r"\s+(?<ep>\d+)\s*$",   // 匹配结尾的数字，如 "Title 01"
        ];
        
        for pattern in &default_patterns {
            if let Ok(re) = Regex::new(pattern) {
                if let Ok(Some(caps)) = re.captures(text) {
                    // 优先尝试命名捕获组
                    if let Some(ep_match) = caps.name("ep") {
                        let ep_str = ep_match.as_str();
                        if let Some(num) = parse_chinese_number(ep_str) {
                            return Some(num);
                        }
                        if let Ok(num) = ep_str.parse::<u32>() {
                            return Some(num);
                        }
                    }
                    // 回退到第一个捕获组
                    if let Some(num_str) = caps.get(1) {
                        if let Ok(num) = num_str.as_str().parse::<u32>() {
                            return Some(num);
                        }
                    }
                }
            }
        }
        None
    };
    
    // 构建集号到索引的映射
    let mut ep_map: std::collections::HashMap<u32, usize> = std::collections::HashMap::new();
    for (idx, element) in episode_elements.iter().enumerate() {
        let text = element.text().collect::<String>().trim().to_string();
        if let Some(ep_num) = extract_episode_number(&text) {
            log::debug!("Episode element #{}: '{}' -> ep {}", idx, text, ep_num);
            ep_map.insert(ep_num, idx);
        } else {
            log::debug!("Episode element #{}: '{}' -> no match", idx, text);
        }
    }
    
    log::info!("Episode map: {:?}", ep_map);
    
    log::info!("Episode map built: {:?}, looking for absolute_ep={:?}, relative_ep={:?}, custom_pattern={:?}", 
        ep_map, absolute_ep, relative_ep, custom_pattern);
    
    // 优先尝试绝对集号
    if let Some(abs_ep) = absolute_ep {
        if let Some(&idx) = ep_map.get(&abs_ep) {
            log::info!("Found episode by absolute number: {} at index {}", abs_ep, idx);
            return episode_elements.get(idx)
                .and_then(|ep| ep.value().attr("href"))
                .map(|s| s.to_string());
        } else {
            log::info!("Absolute episode {} not found in map, trying relative episode", abs_ep);
        }
    }
    
    // 回退到相对集号
    if let Some(rel_ep) = relative_ep {
        if let Some(&idx) = ep_map.get(&rel_ep) {
            log::info!("Found episode by relative number: {} at index {}", rel_ep, idx);
            return episode_elements.get(idx)
                .and_then(|ep| ep.value().attr("href"))
                .map(|s| s.to_string());
        } else {
            log::info!("Relative episode {} not found", rel_ep);
        }
    }
    
    // 如果都找不到，返回第一集作为后备
    log::warn!("Could not find specified episode, falling back to first episode");
    episode_elements.first()
        .and_then(|ep| ep.value().attr("href"))
        .map(|s| s.to_string())
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
            
            // 严格检查解码后的URL是否是真正的视频URL
            // 必须包含视频格式后缀，且不能是HTML页面
            let is_video_url = (final_url.contains(".m3u8") 
                || final_url.contains(".mp4") 
                || final_url.contains(".flv")
                || final_url.contains(".ts")
                || final_url.contains(".mkv")
                || final_url.contains(".avi"))
                && !final_url.contains(".html"); // 排除HTML页面
  
            
            if is_video_url {
                log::info!("DEBUG: Validated as video URL");
                return Some(final_url);
            } else {
                log::warn!("DEBUG: URL does not appear to be a direct video URL, skipping player_aaaa extraction");
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
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers (Referer, User-Agent etc)
    pub headers: Option<std::collections::HashMap<String, String>>,
}

/// 搜索进度状态
#[derive(Debug, Clone)]
pub enum SearchStep {
    /// 等待中
    Pending,
    /// 正在搜索
    Searching,
    /// 正在获取详情页
    FetchingDetail,
    /// 正在获取剧集列表
    FetchingEpisodes,
    /// 正在提取视频URL
    ExtractingVideo,
    /// 搜索成功
    Success,
    /// 搜索失败
    Failed,
}

/// 带状态的搜索进度
#[derive(Debug, Clone)]
pub struct SourceSearchProgress {
    /// 源名称
    pub source_name: String,
    /// 当前搜索步骤
    pub step: SearchStep,
    /// 错误信息（如果有）
    pub error: Option<String>,
    /// 播放页面 URL（如果找到）
    pub play_page_url: Option<String>,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: Option<String>,
    /// 直接解析得到的视频URL（如果有）
    pub direct_video_url: Option<String>,
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers
    pub headers: Option<std::collections::HashMap<String, String>>,
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
        let enabled = crate::api::config::is_source_enabled(&name);
        sources.push(SourceState {
            name,
            description,
            icon_url,
            tier,
            default_subtitle_language,
            default_resolution,
            enabled,
        });
    }
    Ok(sources)
}

/// 搜索所有源，返回所有找到的播放页面URL列表
/// Flutter 端可以使用 WebView 加载这些 URL 来拦截视频请求
/// 
/// # 参数
/// * `anime_name` - 动画名称
/// * `absolute_episode` - 绝对集号（如第15集），优先匹配
/// * `relative_episode` - 相对集号（如当季第3集），绝对集号找不到时回退使用
pub async fn generic_search_play_pages(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<Vec<SearchPlayResult>> {
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
                search_single_source(&client, &source, &anime_name, absolute_episode, relative_episode).await
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
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
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
            search_single_source(&client, &source, &anime_name, absolute_episode, relative_episode).await
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

/// 获取所有已启用源的列表（用于初始化UI显示）
pub async fn get_enabled_source_names() -> anyhow::Result<Vec<String>> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;
    let root: SampleRoot = serde_json::from_str(&content)?;

    let names: Vec<String> = root
        .exported_media_source_data_list
        .media_sources
        .iter()
        .filter(|s| crate::api::config::is_source_enabled(&s.arguments.name))
        .map(|s| s.arguments.name.clone())
        .collect();
    
    Ok(names)
}

/// 搜索所有源，以流的形式返回详细进度（包含搜索步骤和错误信息）
pub async fn generic_search_with_progress(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<SourceSearchProgress>,
) -> anyhow::Result<()> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;
    
    use futures::stream::{FuturesUnordered, StreamExt};
    
    let mut tasks = FuturesUnordered::new();
    
    // Create configured tasks for all enabled sources
    for source in root.exported_media_source_data_list.media_sources {
        if !crate::api::config::is_source_enabled(&source.arguments.name) {
             log::info!("Skipping disabled source: {}", source.arguments.name);
             continue;
        }

        let client = client.clone();
        let anime_name = anime_name.clone();
        let sink = sink.clone();
        let task = async move {
            let source_name = source.arguments.name.clone();
            
            // 发送初始状态
            sink.add(SourceSearchProgress {
                source_name: source_name.clone(),
                step: SearchStep::Searching,
                error: None,
                play_page_url: None,
                video_regex: None,
                direct_video_url: None,
                cookies: None,
                headers: None,
            }).ok();
            
            // 执行搜索并返回带进度的结果
            search_single_source_with_progress(&client, &source, &anime_name, absolute_episode, relative_episode, &sink).await
        };
        tasks.push(task);
    }
    
    // 等待所有任务完成
    while let Some(_) = tasks.next().await {
        // 结果已经通过 sink 发送
    }
    
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
) -> anyhow::Result<()> {
    let source_name = source.arguments.name.clone();
    let video_regex = source.arguments.search_config.match_video.match_video_url.clone();
    let cookies = source.arguments.search_config.match_video.cookies.clone();
    let headers = source.arguments.search_config.match_video.add_headers_to_video.clone();
    
    // 预处理搜索词
    let search_term = preprocess_search_term(anime_name);
    let core_name = extract_core_name(anime_name);
    
    // Step 1: 搜索
    let search_url = source
        .arguments
        .search_config
        .search_url
        .replace("{keyword}", &search_term);
    
    let resp_text = match client.get(&search_url).send().await {
        Ok(resp) => match resp.text().await {
            Ok(text) => text,
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
                }).ok();
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
            }).ok();
            return Err(anyhow::anyhow!("Network error"));
        }
    };
    
    // 解析搜索结果
    let detail_url = {
        let document = Html::parse_document(&resp_text);
        let mut found_url = String::new();
        let mut best_match_score = 0;
        
        // 根据 subjectFormatId 选择使用哪个 selector
        let format_id = source.arguments.search_config.subject_format_id.as_deref().unwrap_or("indexed");
        
        if format_id == "a" {
            // 使用 selectorSubjectFormatA
            if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
                if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                    let links: Vec<_> = document.select(&list_sel).collect();
                    let mut all_results = Vec::new();
                    
                    log::info!("[{}] === 搜索结果列表 (Format A) ===", source_name);
                    log::info!("[{}] 目标: '{}' | 核心名: '{}'", source_name, anime_name, core_name);
                    log::info!("[{}] 总共找到 {} 个结果", source_name, links.len());

                    for link_el in links.iter() {
                        let title = link_el.text().collect::<String>().trim().to_string();
                        let href = link_el.value().attr("href").unwrap_or("").to_string();

                        let score = calculate_match_score(&title, anime_name, &core_name);
                        all_results.push((title.clone(), score, href.clone()));
                        
                        log::info!("[{}] 结果 #{}: '{}' | 分数: {} | URL: {}", 
                            source_name, all_results.len(), title, score,
                            if href.len() > 100 { format!("{}...", &href[..100]) } else { href.clone() });
                        
                        if score > best_match_score && score >=30 {
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
                        }
                    }
                    
                    if !all_results.is_empty() {
                        let top_matches: Vec<_> = all_results.iter()
                            .filter(|(_, score, _)| *score >= 40)
                            .collect();
                        if !top_matches.is_empty() {
                            log::info!("[{}] ✓ 符合条件的结果 (分数≥40):", source_name);
                            for (title, score, _) in top_matches {
                                log::info!("[{}]   - '{}' (分数: {})", source_name, title, score);
                            }
                        } else {
                            log::warn!("[{}] ✗ 没有符合条件的结果 (所有结果分数都<40)", source_name);
                            if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max() {
                                log::warn!("[{}] 最高分: {}", source_name, max_score);
                            }
                        }
                        if best_match_score >= 50 {
                            log::info!("[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})", source_name, best_match_score);
                        }
                    }
                }
            }
        } else {
            // 使用 selectorSubjectFormatIndexed (默认)
            if let Some(ref format) = source.arguments.search_config.selector_subject_format_indexed {
                if let (Ok(name_sel), Ok(link_sel)) = (
                    Selector::parse(&format.select_names),
                    Selector::parse(&format.select_links),
                ) {
                    let names: Vec<_> = document.select(&name_sel).collect();
                    let links: Vec<_> = document.select(&link_sel).collect();
                    let mut all_results = Vec::new();
                    
                    log::info!("[{}] === 搜索结果列表 (Format Indexed) ===", source_name);
                    log::info!("[{}] 目标: '{}' | 核心名: '{}'", source_name, anime_name, core_name);
                    log::info!("[{}] 总共找到 {} 个结果", source_name, names.len().min(links.len()));

                    for (name_el, link_el) in names.iter().zip(links.iter()) {
                        let title = name_el.text().collect::<String>().trim().to_string();
                        let href = link_el.value().attr("href").unwrap_or("").to_string();

                        let score = calculate_match_score(&title, anime_name, &core_name);
                        all_results.push((title.clone(), score, href.clone()));
                        
                        log::info!("[{}] 结果 #{}: '{}' | 分数: {} | URL: {}", 
                            source_name, all_results.len(), title, score,
                            if href.len() > 100 { format!("{}...", &href[..100]) } else { href.clone() });
                        
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
                        }
                    }
                    
                    if !all_results.is_empty() {
                        let top_matches: Vec<_> = all_results.iter()
                            .filter(|(_, score, _)| *score >= 50)
                            .collect();
                        if !top_matches.is_empty() {
                            log::info!("[{}] ✓ 符合条件的结果 (分数≥50):", source_name);
                            for (title, score, _) in top_matches {
                                log::info!("[{}]   - '{}' (分数: {})", source_name, title, score);
                            }
                        } else {
                            log::warn!("[{}] ✗ 没有符合条件的结果 (所有结果分数都<50)", source_name);
                            if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max() {
                                log::warn!("[{}] 最高分: {}", source_name, max_score);
                            }
                        }
                        if best_match_score >= 50 {
                            log::info!("[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})", source_name, best_match_score);
                        }
                    }
                }
            }
        }
        found_url
    };

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
        }).ok();
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
    }).ok();

    let detail_resp_text = match client.get(&detail_url).send().await {
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
                }).ok();
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
            }).ok();
            return Err(anyhow::anyhow!("Detail network error"));
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
    }).ok();

    let episode_url = {
        let detail_doc = Html::parse_document(&detail_resp_text);
        let mut found_url = String::new();
        
        if let Some(ref format) = source.arguments.search_config.selector_channel_format_flattened {
            if let (Ok(list_sel), Ok(item_sel)) = (
                Selector::parse(&format.select_episode_lists),
                Selector::parse(&format.select_episodes_from_list),
            ) {
                if let Some(list_container) = detail_doc.select(&list_sel).next() {
                    let episodes: Vec<_> = list_container.select(&item_sel).collect();
                    let ep_pattern = format.match_episode_sort_from_name.as_deref();
                    if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
                let episodes: Vec<_> = detail_doc.select(&ep_sel).collect();
                let ep_pattern = format.match_episode_sort_from_name.as_deref();
                if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
        sink.add(SourceSearchProgress {
            source_name: source_name.clone(),
            step: SearchStep::Failed,
            error: Some("未找到剧集列表".to_string()),
            play_page_url: None,
            video_regex: None,
            direct_video_url: None,
            cookies: None,
            headers: None,
        }).ok();
        return Err(anyhow::anyhow!("No episodes found"));
    }

    // Step 4: 尝试提取视频URL
    sink.add(SourceSearchProgress {
        source_name: source_name.clone(),
        step: SearchStep::ExtractingVideo,
        error: None,
        play_page_url: Some(episode_url.clone()),
        video_regex: Some(video_regex.clone()),
        direct_video_url: None,
        cookies: cookies.clone(),
        headers: headers.clone(),
    }).ok();

    let mut direct_video_url = None;
    
    let mut request_builder = client.get(&episode_url);
    if let Some(ref headers) = source.arguments.search_config.match_video.add_headers_to_video {
        for (k, v) in headers {
            request_builder = request_builder.header(k, v);
        }
    }
    if let Some(ref cookies) = source.arguments.search_config.match_video.cookies {
        request_builder = request_builder.header("Cookie", cookies);
    }
    
    if let Ok(resp) = request_builder.send().await {
        if let Ok(video_page_text) = resp.text().await {
            if let Some(player_url) = try_extract_player_aaaa_url(&video_page_text) {
                log::info!("[{}] Found direct video URL from player_aaaa: {}", source_name, player_url);
                direct_video_url = Some(player_url);
            }
        }
    }

    // 发送成功结果
    sink.add(SourceSearchProgress {
        source_name: source_name.clone(),
        step: SearchStep::Success,
        error: None,
        play_page_url: Some(episode_url),
        video_regex: Some(video_regex),
        direct_video_url,
        cookies,
        headers,
    }).ok();

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
    let video_regex = source.arguments.search_config.match_video.match_video_url.clone();
    let cookies = source.arguments.search_config.match_video.cookies.clone();
    let headers = source.arguments.search_config.match_video.add_headers_to_video.clone();
    
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
        
        // 根据 subjectFormatId 选择使用哪个 selector
        let format_id = source.arguments.search_config.subject_format_id.as_deref().unwrap_or("indexed");
        
        if format_id == "a" {
            // 使用 selectorSubjectFormatA
            if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
                if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                    let links: Vec<_> = document.select(&list_sel).collect();
                    let mut all_results = Vec::new();
                    
                    log::info!("[{}] === 搜索结果列表 (Format A) ===", source_name);
                    log::info!("[{}] 目标: '{}' | 核心名: '{}'", source_name, anime_name, core_name);
                    log::info!("[{}] 总共找到 {} 个结果", source_name, links.len());

                    for link_el in links.iter() {
                        let title = link_el.text().collect::<String>().trim().to_string();
                        let href = link_el.value().attr("href").unwrap_or("").to_string();

                        // 计算匹配分数
                        let score = calculate_match_score(&title, anime_name, &core_name);
                        all_results.push((title.clone(), score, href.clone()));
                        
                        log::info!("[{}] 结果 #{}: '{}' | 分数: {} | URL: {}", 
                            source_name, all_results.len(), title, score,
                            if href.len() > 100 { format!("{}...", &href[..100]) } else { href.clone() });
                        
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
                        }
                    }
                    
                    if !all_results.is_empty() {
                        let top_matches: Vec<_> = all_results.iter()
                            .filter(|(_, score, _)| *score >= 50)
                            .collect();
                        if !top_matches.is_empty() {
                            log::info!("[{}] ✓ 符合条件的结果 (分数≥50):", source_name);
                            for (title, score, _) in top_matches {
                                log::info!("[{}]   - '{}' (分数: {})", source_name, title, score);
                            }
                        } else {
                            log::warn!("[{}] ✗ 没有符合条件的结果 (所有结果分数都<50)", source_name);
                            if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max() {
                                log::warn!("[{}] 最高分: {}", source_name, max_score);
                            }
                        }
                        if best_match_score >= 50 {
                            log::info!("[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})", source_name, best_match_score);
                        }
                    }
                }
            }
        } else {
            // 使用 selectorSubjectFormatIndexed (默认)
            if let Some(ref format) = source.arguments.search_config.selector_subject_format_indexed {
                if let (Ok(name_sel), Ok(link_sel)) = (
                    Selector::parse(&format.select_names),
                    Selector::parse(&format.select_links),
                ) {
                    let names: Vec<_> = document.select(&name_sel).collect();
                    let links: Vec<_> = document.select(&link_sel).collect();
                    let mut all_results = Vec::new();
                    
                    log::info!("[{}] === 搜索结果列表 (Format Indexed) ===", source_name);
                    log::info!("[{}] 目标: '{}' | 核心名: '{}'", source_name, anime_name, core_name);
                    log::info!("[{}] 总共找到 {} 个结果", source_name, names.len().min(links.len()));

                    for (name_el, link_el) in names.iter().zip(links.iter()) {
                        let title = name_el.text().collect::<String>().trim().to_string();
                        let href = link_el.value().attr("href").unwrap_or("").to_string();

                        // 计算匹配分数
                        let score = calculate_match_score(&title, anime_name, &core_name);
                        all_results.push((title.clone(), score, href.clone()));
                        
                        log::info!("[{}] 结果 #{}: '{}' | 分数: {} | URL: {}", 
                            source_name, all_results.len(), title, score,
                            if href.len() > 100 { format!("{}...", &href[..100]) } else { href.clone() });
                        
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
                        }
                    }
                    
                    if !all_results.is_empty() {
                        let top_matches: Vec<_> = all_results.iter()
                            .filter(|(_, score, _)| *score >= 50)
                            .collect();
                        if !top_matches.is_empty() {
                            log::info!("[{}] ✓ 符合条件的结果 (分数≥50):", source_name);
                            for (title, score, _) in top_matches {
                                log::info!("[{}]   - '{}' (分数: {})", source_name, title, score);
                            }
                        } else {
                            log::warn!("[{}] ✗ 没有符合条件的结果 (所有结果分数都<50)", source_name);
                            if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max() {
                                log::warn!("[{}] 最高分: {}", source_name, max_score);
                            }
                        }
                        if best_match_score >= 50 {
                            log::info!("[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})", source_name, best_match_score);
                        }
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
                    let episodes: Vec<_> = list_container.select(&item_sel).collect();
                    let ep_pattern = format.match_episode_sort_from_name.as_deref();
                    if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
                let episodes: Vec<_> = detail_doc.select(&ep_sel).collect();
                let ep_pattern = format.match_episode_sort_from_name.as_deref();
                if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
    let mut request_builder = client.get(&episode_url);
    if let Some(ref headers) = source.arguments.search_config.match_video.add_headers_to_video {
        for (k, v) in headers {
            request_builder = request_builder.header(k, v);
        }
    }
    if let Some(ref cookies) = source.arguments.search_config.match_video.cookies {
        request_builder = request_builder.header("Cookie", cookies);
    }

    if let Ok(resp) = request_builder.send().await {
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
        cookies,
        headers,
    })
}

/// 搜索并播放动画（支持集号选择）
/// 
/// # 参数
/// * `anime_name` - 动画名称
/// * `absolute_episode` - 绝对集号（如第15集），优先匹配
/// * `relative_episode` - 相对集号（如当季第3集），绝对集号找不到时回退使用
pub async fn generic_search_and_play_with_episode(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    generic_search_and_play_internal(anime_name, absolute_episode, relative_episode).await
}

/// 搜索并播放动画（默认第一集，保持向后兼容）
pub async fn generic_search_and_play(anime_name: String) -> anyhow::Result<String> {
    generic_search_and_play_internal(anime_name, None, None).await
}

/// 内部实现：搜索并播放动画
async fn generic_search_and_play_internal(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
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
                        let episodes: Vec<_> = list_container.select(&item_sel).collect();
                        let ep_pattern = format.match_episode_sort_from_name.as_deref();
                        if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
                    let episodes: Vec<_> = detail_doc.select(&ep_sel).collect();
                    let ep_pattern = format.match_episode_sort_from_name.as_deref();
                    if let Some(href) = select_episode_by_number(&episodes, absolute_episode, relative_episode, ep_pattern) {
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
        if let Some(ref headers) = source.arguments.search_config.match_video.add_headers_to_video {
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
                            let mut nested_url = if caps.len() > 1 {
                                caps.get(1).map_or("", |m| m.as_str()).to_string()
                            } else {
                                caps.get(0).map_or("", |m| m.as_str()).to_string()
                            };

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
                                let mut nested_req = client.get(&nested_url);
                                if let Some(ref headers) = source.arguments.search_config.match_video.add_headers_to_video {
                                    for (k, v) in headers {
                                        nested_req = nested_req.header(k, v);
                                    }
                                }
                                if let Some(ref cookies) = source.arguments.search_config.match_video.cookies {
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
