// use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use fancy_regex::Regex;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize}; // Added Serialize
// use serde_json::Value;
use std::fs;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceState {
    pub name: String,
    pub description: String,
    pub icon_url: String,
    pub tier: i32,
    pub default_subtitle_language: String,
    pub default_resolution: String,
    pub search_url: String,
    pub search_config_json: String,
    pub enabled: bool,
}

lazy_static::lazy_static! {
    /// 匹配季数相关的关键词
    static ref SEASON_RE: Regex = Regex::new(r"(?i)第[一二三四五六七八九十\d]+季|Part\s*\d+|\d+(st|nd|rd|th)\s*Season|Season\s*\d+").unwrap();
}

/// 预处理搜索词，提取核心动画名称
/// 参考 mikan.rs 的实现
fn preprocess_search_term(name: &str) -> String {
    let final_search_str = extract_core_name(name);
    log::info!(
        "Preprocessed search term: '{}' -> '{}'",
        name,
        final_search_str
    );
    final_search_str
}

/// 解析搜索候选词：支持用 "||" 传入别名列表
/// 返回去重后的候选列表（保留顺序）
fn build_search_candidates(anime_name: &str) -> Vec<String> {
    let mut candidates: Vec<String> = anime_name
        .split("||")
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect();

    if candidates.is_empty() {
        let trimmed = anime_name.trim();
        if !trimmed.is_empty() {
            candidates.push(trimmed.to_string());
        }
    }

    let mut seen = std::collections::HashSet::new();
    candidates.retain(|s| {
        let key = s.to_lowercase();
        if seen.contains(&key) {
            false
        } else {
            seen.insert(key);
            true
        }
    });

    candidates
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SampleRoot {
    #[serde(rename = "exportedMediaSourceDataList")]
    pub exported_media_source_data_list: ExportedMediaSourceDataList,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ExportedMediaSourceDataList {
    #[serde(rename = "mediaSources")]
    pub media_sources: Vec<MediaSource>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MediaSource {
    #[serde(rename = "factoryId")]
    pub factory_id: String,
    pub arguments: SourceArguments,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SourceArguments {
    pub name: String,
    pub description: Option<String>,
    #[serde(rename = "iconUrl")]
    pub icon_url: Option<String>,
    pub tier: Option<i32>,
    #[serde(rename = "searchConfig")]
    pub search_config: SearchConfig,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
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

    // Channel format selector: "index-grouped" (多线路) or "no-channel" (无线路区分)
    #[serde(rename = "channelFormatId")]
    pub channel_format_id: Option<String>,

    // Selectors for channel/episodes
    #[serde(rename = "selectorChannelFormatFlattened")]
    pub selector_channel_format_flattened: Option<SelectorChannelFormatFlattened>,
    #[serde(rename = "selectorChannelFormatNoChannel")]
    pub selector_channel_format_no_channel: Option<SelectorChannelFormatNoChannel>,

    // Video matching
    #[serde(rename = "matchVideo")]
    pub match_video: MatchVideo,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorSubjectFormatA {
    #[serde(rename = "selectLists")]
    pub select_lists: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorSubjectFormatIndexed {
    #[serde(rename = "selectNames")]
    pub select_names: String,
    #[serde(rename = "selectLinks")]
    pub select_links: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorChannelFormatFlattened {
    /// 选择channel名称的CSS选择器（如线路A、简中、繁中等）
    #[serde(rename = "selectChannelNames")]
    pub select_channel_names: Option<String>,
    /// 从channel名称中提取名字的正则表达式，使用命名捕获组 (?<ch>...)
    #[serde(rename = "matchChannelName")]
    pub match_channel_name: Option<String>,
    #[serde(rename = "selectEpisodeLists")]
    pub select_episode_lists: String,
    #[serde(rename = "selectEpisodesFromList")]
    pub select_episodes_from_list: String,
    /// 从剧集链接元素中提取链接的CSS选择器（可选，默认从元素自身href获取）
    #[serde(rename = "selectEpisodeLinksFromList")]
    pub select_episode_links_from_list: Option<String>,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorChannelFormatNoChannel {
    #[serde(rename = "selectEpisodes")]
    pub select_episodes: String,
    /// 从剧集元素中提取链接的CSS选择器（可选，默认从元素自身href获取）
    #[serde(rename = "selectEpisodeLinks")]
    pub select_episode_links: Option<String>,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
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
        ('零', 0),
        ('〇', 0),
        ('一', 1),
        ('壹', 1),
        ('二', 2),
        ('贰', 2),
        ('两', 2),
        ('三', 3),
        ('叁', 3),
        ('四', 4),
        ('肆', 4),
        ('五', 5),
        ('伍', 5),
        ('六', 6),
        ('陆', 6),
        ('七', 7),
        ('柒', 7),
        ('八', 8),
        ('捌', 8),
        ('九', 9),
        ('玖', 9),
    ]
    .iter()
    .cloned()
    .collect();

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

/// 从channel元素文本中提取channel名称
/// 支持使用正则表达式提取命名捕获组 (?<ch>...)
fn extract_channel_name(text: &str, pattern: Option<&str>) -> String {
    let text = text.trim();

    // 如果有自定义正则表达式，使用它来提取channel名称
    if let Some(pattern_str) = pattern {
        if !pattern_str.is_empty() && pattern_str != "$^" {
            if let Ok(re) = Regex::new(pattern_str) {
                if let Ok(Some(caps)) = re.captures(text) {
                    // 优先尝试命名捕获组 "ch"
                    if let Some(ch_match) = caps.name("ch") {
                        return ch_match.as_str().trim().to_string();
                    }
                    // 回退到第一个捕获组
                    if let Some(group1) = caps.get(1) {
                        return group1.as_str().trim().to_string();
                    }
                }
            }
        }
    }

    // 默认返回原文本
    text.to_string()
}

/// 提取动画名称的核心部分（用于搜索关键词和匹配逻辑）
fn extract_core_name(name: &str) -> String {
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

    // 3. 按空格分割，取第一个长度 >= 3 的片段作为核心词
    let segments: Vec<&str> = cleaned
        .split_whitespace()
        .filter(|s| s.chars().count() >= 1)
        .collect();

    let final_core_str = segments
        .iter()
        .find(|s| s.chars().count() >= 3)
        .map(|s| s.to_string())
        .unwrap_or_else(|| {
            // 如果没有长度 >= 3 的，取最长的片段
            segments
                .iter()
                .max_by_key(|s| s.chars().count())
                .map(|s| s.to_string())
                .unwrap_or_else(|| cleaned_name.to_string())
        });

    final_core_str
}

/// 计算标题匹配分数 (0-100)，使用 Jaccard 相似度
fn calculate_match_score(title: &str, full_name: &str, core_name: &str) -> i32 {
    let title_lower = title.to_lowercase();
    let full_lower = full_name.to_lowercase();
    let core_lower = core_name.to_lowercase();

    // 计算标题与完整查询名的字符级 Jaccard 相似度
    let title_chars: std::collections::HashSet<char> =
        title_lower.chars().filter(|c| !c.is_whitespace()).collect();
    let full_chars: std::collections::HashSet<char> =
        full_lower.chars().filter(|c| !c.is_whitespace()).collect();

    let intersection_full = title_chars.intersection(&full_chars).count();
    let union_full = title_chars.union(&full_chars).count();

    let jaccard_full = if union_full > 0 {
        intersection_full as f64 / union_full as f64
    } else {
        0.0
    };

    // 计算标题与核心名的字符级 Jaccard 相似度
    let core_chars: std::collections::HashSet<char> =
        core_lower.chars().filter(|c| !c.is_whitespace()).collect();

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
        return episode_elements
            .first()
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
                                log::debug!(
                                    "Custom pattern matched (named group 'ep'): '{}' -> {}",
                                    ep_str,
                                    num
                                );
                                return Some(num);
                            }
                            // 尝试直接解析数字
                            if let Ok(num) = ep_str.parse::<u32>() {
                                log::debug!(
                                    "Custom pattern matched (named group 'ep'): '{}' -> {}",
                                    ep_str,
                                    num
                                );
                                return Some(num);
                            }
                        }
                        // 回退到第一个捕获组
                        if let Some(num_match) = caps.get(1) {
                            let num_str = num_match.as_str();
                            if let Some(num) = parse_chinese_number(num_str) {
                                log::debug!(
                                    "Custom pattern matched (group 1): '{}' -> {}",
                                    num_str,
                                    num
                                );
                                return Some(num);
                            }
                            if let Ok(num) = num_str.parse::<u32>() {
                                log::debug!(
                                    "Custom pattern matched (group 1): '{}' -> {}",
                                    num_str,
                                    num
                                );
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
            r"\[(?<ep>\d+)\]",    // 匹配 [01]
            r"【(?<ep>\d+)】",    // 匹配 【01】
            r"\s+(?<ep>\d+)\s*$", // 匹配结尾的数字，如 "Title 01"
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

    log::info!(
        "Episode map built: {:?}, looking for absolute_ep={:?}, relative_ep={:?}, custom_pattern={:?}",
        ep_map,
        absolute_ep,
        relative_ep,
        custom_pattern
    );

    // 优先尝试绝对集号
    if let Some(abs_ep) = absolute_ep {
        if let Some(&idx) = ep_map.get(&abs_ep) {
            log::info!(
                "Found episode by absolute number: {} at index {}",
                abs_ep,
                idx
            );
            return episode_elements
                .get(idx)
                .and_then(|ep| ep.value().attr("href"))
                .map(|s| s.to_string());
        } else {
            log::info!(
                "Absolute episode {} not found in map, trying relative episode",
                abs_ep
            );
        }
    }

    // 回退到相对集号
    if let Some(rel_ep) = relative_ep {
        if let Some(&idx) = ep_map.get(&rel_ep) {
            log::info!(
                "Found episode by relative number: {} at index {}",
                rel_ep,
                idx
            );
            return episode_elements
                .get(idx)
                .and_then(|ep| ep.value().attr("href"))
                .map(|s| s.to_string());
        } else {
            log::info!("Relative episode {} not found", rel_ep);
        }
    }

    // 如果都找不到，返回第一集作为后备
    log::warn!("Could not find specified episode, falling back to first episode");
    episode_elements
        .first()
        .and_then(|ep| ep.value().attr("href"))
        .map(|s| s.to_string())
}

/// 修复被混淆的视频URL
/// 某些网站会对URL做简单的字符替换混淆：n->o, l->m, 域名中的.->/
// fn deobfuscate_video_url(url: &str) -> String {
//     // 分离协议部分 (https://)
//     let (protocol, rest) = if let Some(idx) = url.find("://") {
//         (&url[..idx + 3], &url[idx + 3..])
//     } else {
//         ("", url)
//     };

//     // 找到路径开始的位置（第一个单独的 /）
//     // 在混淆的URL中，域名部分的 . 被替换成了 /
//     // 例如: ai/girigirilove/oet/zijian/... 应该是 ai.girigirilove.net/zijian/...

//     // 替换常见的混淆模式
//     let deobfuscated = rest
//         // TLD 混淆
//         .replace("/oet/", ".net/")
//         .replace("/con/", ".com/")
//         .replace("/org/", ".org/")
//         ;

//     // 进一步处理：修复域名部分
//     let parts: Vec<&str> = deobfuscated.split('/').collect();

//     // 重建URL，智能判断哪些 / 应该是 .
//     let mut final_url = String::from(protocol);
//     let mut in_domain = true;

//     for (i, part) in parts.iter().enumerate() {
//         if i == 0 {
//             final_url.push_str(part);
//             continue;
//         }

//         // 判断是否还在域名部分
//         // 如果当前部分看起来像TLD或域名组件，则用 . 连接
//         // 如果看起来像路径（包含常见路径词或较长），则切换到路径模式
//         let is_tld = matches!(*part, "net" | "com" | "org" | "io" | "tv" | "cc" | "top" | "xyz");
//         let looks_like_path = part.contains("20") // 年份
//             || part.len() > 20
//             || part.contains("anime")
//             || part.contains("video")
//             || part.contains("play")
//             || part.contains("zijian")
//             || part.contains("cht")
//             || part.contains("chs");

//         if in_domain && (is_tld || (!looks_like_path && i <= 2)) {
//             final_url.push('.');
//             final_url.push_str(part);
//             if is_tld {
//                 in_domain = false; // TLD后面就是路径了
//             }
//         } else {
//             in_domain = false;
//             final_url.push('/');
//             final_url.push_str(part);
//         }
//     }

//     // 最后做字符级别的混淆修复
//     // o -> n, m -> l 在特定上下文中
//     let final_url = final_url
//         .replace("omdanime", "oldanime")
//         .replace("omda", "olda")
//         .replace("Sousouoo", "Sousouno")
//         .replace("playmist", "playlist")
//         .replace("playoist", "playlist")
//         .replace(".oet", ".net")  // 以防上面没处理到
//         ;

//     final_url
// }

/// 尝试从页面中解析 player_aaaa 变量并提取视频 URL
/// 这是很多视频网站使用的通用模式，视频URL存储在一个JS变量中
// fn try_extract_player_aaaa_url(page_text: &str) -> Option<String> {
//     // 匹配 var player_aaaa = {...} 格式
//     let re = Regex::new(r#"var\s+player_aaaa\s*=\s*(\{[^;]+\})"#).ok()?;

//     if let Ok(Some(caps)) = re.captures(page_text) {
//         let json_str = caps.get(1)?.as_str();
//         log::info!("DEBUG: Found player_aaaa JSON: {}...", &json_str[..json_str.len().min(200)]);

//         if let Ok(json_value) = serde_json::from_str::<Value>(json_str) {
//             // 获取加密类型和URL
//             let encrypt = json_value.get("encrypt").and_then(|v| v.as_i64()).unwrap_or(0);
//             let url_encoded = json_value.get("url").and_then(|v| v.as_str())?;

//             log::info!("DEBUG: encrypt={}, url_encoded={}...", encrypt, &url_encoded[..url_encoded.len().min(50)]);

//             // 根据加密类型解码
//             let decoded_url = match encrypt {
//                 0 => {
//                     // 无加密，直接使用
//                     url_encoded.to_string()
//                 }
//                 1 => {
//                     // escape 编码，使用URL解码
//                     urlencoding::decode(url_encoded).ok()?.into_owned()
//                 }
//                 2 => {
//                     // base64 编码的 URL 编码字符串
//                     let base64_decoded = BASE64.decode(url_encoded).ok()?;
//                     let utf8_str = String::from_utf8(base64_decoded).ok()?;
//                     urlencoding::decode(&utf8_str).ok()?.into_owned()
//                 }
//                 _ => {
//                     log::warn!("Unknown encrypt type: {}", encrypt);
//                     return None;
//                 }
//             };

//             log::info!("DEBUG: Decoded URL (before deobfuscate): {}", decoded_url);

//             // 尝试修复混淆的URL
//             let final_url = deobfuscate_video_url(&decoded_url);
//             log::info!("DEBUG: Final URL (after deobfuscate): {}", final_url);

//             // 严格检查解码后的URL是否是真正的视频URL
//             // 必须包含视频格式后缀，且不能是HTML页面
//             let is_video_url = (final_url.contains(".m3u8")
//                 || final_url.contains(".mp4")
//                 || final_url.contains(".flv")
//                 || final_url.contains(".ts")
//                 || final_url.contains(".mkv")
//                 || final_url.contains(".avi"))
//                 && !final_url.contains(".html"); // 排除HTML页面

//             if is_video_url {
//                 log::info!("DEBUG: Validated as video URL");
//                 return Some(final_url);
//             } else {
//                 log::warn!("DEBUG: URL does not appear to be a direct video URL, skipping player_aaaa extraction");
//             }
//         }
//     }

//     None
// }

/// Channel（线路）信息
#[derive(Debug, Clone, Serialize)]
pub struct ChannelInfo {
    /// Channel 名称（如"线路A"、"简中"、"繁中"等）
    pub name: String,
    /// Channel 索引
    pub index: usize,
}

/// 剧集信息
#[derive(Debug, Clone, Serialize)]
pub struct EpisodeInfo {
    /// 剧集名称/标题
    pub name: String,
    /// 剧集URL
    pub url: String,
    /// 剧集号（如果能解析出来）
    pub episode_number: Option<u32>,
    /// 所属channel索引
    pub channel_index: usize,
}

/// 包含多channel信息的搜索结果
#[derive(Debug, Clone, Serialize)]
pub struct SearchResultWithChannels {
    /// 源名称
    pub source_name: String,
    /// 动画详情页URL
    pub detail_url: String,
    /// 匹配到的动画名称
    pub matched_title: String,
    /// 所有可用的channels（线路）
    pub channels: Vec<ChannelInfo>,
    /// 所有剧集列表（按channel分组）
    pub episodes: Vec<EpisodeInfo>,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: String,
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers
    pub headers: Option<std::collections::HashMap<String, String>>,
    /// 默认字幕语言
    pub default_subtitle_language: Option<String>,
    /// 默认分辨率
    pub default_resolution: Option<String>,
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
    /// Channel 名称（如果有多channel）
    pub channel_name: Option<String>,
    /// Channel 索引
    pub channel_index: Option<usize>,
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
    /// Channel 名称（如果有多channel）
    pub channel_name: Option<String>,
    /// Channel 索引
    pub channel_index: Option<usize>,
    /// 所有可用的channels（搜索成功时填充）
    pub all_channels: Option<Vec<ChannelInfo>>,
}

/// 获取播放源配置缓存文件路径
fn get_cache_file_path() -> anyhow::Result<std::path::PathBuf> {
    let base_dir = std::path::PathBuf::from(crate::api::config::get_cache_dir());

    // 确保目录存在
    if !base_dir.exists() {
        fs::create_dir_all(&base_dir)?;
    }

    Ok(base_dir.join("playback_sources_cache.json"))
}

/// 从本地缓存读取播放源配置
fn load_from_cache() -> anyhow::Result<String> {
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
fn save_to_cache(content: &str) -> anyhow::Result<()> {
    let cache_path = get_cache_file_path()?;
    log::info!("Saving playback source config to cache: {:?}", cache_path);
    fs::write(&cache_path, content)?;
    log::info!("Successfully saved config to cache");
    Ok(())
}

/// 从本地缓存加载播放源配置，如果缓存不存在则返回错误
async fn load_playback_source_config(_client: &reqwest::Client) -> anyhow::Result<String> {
    // 只从本地缓存读取
    load_from_cache()
}

/// 从订阅地址刷新播放源配置并保存到本地缓存
pub async fn refresh_playback_source_config() -> anyhow::Result<String> {
    let client = crate::api::network::create_client()?;
    let sub_url = crate::api::config::get_playback_sub_url();
    log::info!("Refreshing playback source config from: {}", sub_url);

    // 从订阅地址拉取
    let resp = client.get(&sub_url).send().await?;
    let content = resp.text().await?;
    log::info!("Successfully fetched config from subscription URL");

    // 验证JSON格式
    let _root: SampleRoot = serde_json::from_str(&content)?;
    log::info!("Playback source config validated successfully");

    // 保存到本地缓存
    save_to_cache(&content)?;

    Ok(content)
}

/// 预加载播放源配置（应用启动时调用）
/// 尝试从本地缓存加载配置，如果缓存不存在则从订阅地址拉取
pub async fn preload_playback_sources() -> anyhow::Result<()> {
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
pub async fn get_playback_sources() -> anyhow::Result<Vec<SourceState>> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;
    let root: SampleRoot = serde_json::from_str(&content)?;

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
        sources.push(SourceState {
            name,
            description,
            icon_url,
            tier,
            default_subtitle_language,
            default_resolution,
            search_url,
            search_config_json,
            enabled,
        });
    }
    Ok(sources)
}

#[derive(Debug, Clone)]
pub struct SourceConfigUpdate {
    pub name: String,
    pub new_name: Option<String>,
    pub tier: Option<i32>,
    pub default_subtitle_language: Option<String>,
    pub default_resolution: Option<String>,
    pub search_url: Option<String>,
    pub icon_url: Option<String>,
    pub description: Option<String>,
    pub search_config_json: Option<String>,
}

/// 更新单个源的配置
pub async fn update_single_source_config(update: SourceConfigUpdate) -> anyhow::Result<()> {
    let client = crate::api::network::create_client()?;
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

            found = true;
            break;
        }
    }

    if found {
        let new_content = serde_json::to_string_pretty(&root)?;
        save_to_cache(&new_content)?;
        Ok(())
    } else {
        Err(anyhow::anyhow!("Source not found: {}", update.name))
    }
}

/// 添加新的源配置
pub async fn add_source_config(new_config: SourceConfigUpdate) -> anyhow::Result<()> {
    // 检查名称是否为空
    if new_config.name.is_empty() {
        return Err(anyhow::anyhow!("Source name cannot be empty"));
    }

    let client = crate::api::network::create_client()?;
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
            },
        }
    };

    let new_source = MediaSource {
        factory_id: "web-selector".to_string(),
        arguments: SourceArguments {
            name: new_config.name,
            description: new_config.description,
            icon_url: new_config.icon_url,
            tier: new_config.tier,
            search_config,
        },
    };

    // 添加到列表
    root.exported_media_source_data_list
        .media_sources
        .push(new_source);

    let new_content = serde_json::to_string_pretty(&root)?;
    save_to_cache(&new_content)?;

    Ok(())
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

    // 1. Filter enabled sources and sort by tier
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

    // Sort by tier (ascending, smaller is higher priority)
    sources.sort_by_key(|s| s.arguments.tier.unwrap_or(1));

    // 2. Prepare stream
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

    // 3. Execute with concurrency limit
    let all_results: Vec<_> = stream.buffer_unordered(limit).collect().await;

    // 过滤出成功的结果
    let results: Vec<SearchPlayResult> = all_results.into_iter().filter_map(|r| r.ok()).collect();

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

    // 1. Filter enabled sources and sort by tier
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

    // Sort by tier (ascending)
    sources.sort_by_key(|s| s.arguments.tier.unwrap_or(1));

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

    // 3. Consume stream and send results
    let mut stream = Box::pin(stream);

    while let Some((source_name, result)) = stream.next().await {
        if let Ok(search_result) = result {
            log::info!(
                "Source '{}' completed, sending result to stream",
                source_name
            );
            sink.add(search_result).ok();
        } else if let Err(e) = result {
            log::warn!("Source search failed for {}: {}", source_name, e);
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

    // 1. Filter enabled sources and sort by tier
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

    // Sort by tier (ascending)
    sources.sort_by_key(|s| s.arguments.tier.unwrap_or(1));

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
            async move {
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
                    channel_name: None,
                    channel_index: None,
                    all_channels: None,
                })
                .ok();

                // 执行搜索并返回带进度的结果
                search_single_source_with_progress(
                    &client,
                    &source,
                    &anime_name,
                    absolute_episode,
                    relative_episode,
                    &sink,
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
                        channel_name: None,
                        channel_index: None,
                        all_channels: None,
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
                })
                .ok();
                return Err(anyhow::anyhow!("Network error"));
            }
        };

        // 解析搜索结果
        let current_detail_url = {
            let document = Html::parse_document(&resp_text);
            let mut found_url = String::new();
            let mut best_match_score = 0;

            // 根据 subjectFormatId 选择使用哪个 selector
            let format_id = source
                .arguments
                .search_config
                .subject_format_id
                .as_deref()
                .unwrap_or("indexed");

            if format_id == "a" {
                // 使用 selectorSubjectFormatA
                if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
                    if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                        let links: Vec<_> = document.select(&list_sel).collect();
                        let mut all_results = Vec::new();

                        log::info!("[{}] === 搜索结果列表 (Format A) ===", source_name);
                        log::info!(
                            "[{}] 目标: '{}' | 核心名: '{}'",
                            source_name,
                            query_name,
                            core_name
                        );
                        log::info!("[{}] 总共找到 {} 个结果", source_name, links.len());

                        for link_el in links.iter() {
                            let title = link_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();

                            let score = calculate_match_score(&title, query_name, &core_name);
                            all_results.push((title.clone(), score, href.clone()));

                            log::info!(
                                "[{}] 结果 #{}: '{}' | 分数: {} | URL: {}",
                                source_name,
                                all_results.len(),
                                title,
                                score,
                                if href.len() > 100 {
                                    format!("{}...", &href[..100])
                                } else {
                                    href.clone()
                                }
                            );

                            if score > best_match_score && score >= 30 {
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
                            let top_matches: Vec<_> = all_results
                                .iter()
                                .filter(|(_, score, _)| *score >= 30)
                                .collect();
                            if !top_matches.is_empty() {
                                log::info!("[{}] ✓ 符合条件的结果 (分数≥30):", source_name);
                                for (title, score, _) in top_matches {
                                    log::info!(
                                        "[{}]   - '{}' (分数: {})",
                                        source_name,
                                        title,
                                        score
                                    );
                                }
                            } else {
                                log::warn!(
                                    "[{}] ✗ 没有符合条件的结果 (所有结果分数都<30)",
                                    source_name
                                );
                                if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max()
                                {
                                    log::warn!("[{}] 最高分: {}", source_name, max_score);
                                }
                            }
                            if best_match_score >= 30 {
                                log::info!(
                                    "[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})",
                                    source_name,
                                    best_match_score
                                );
                            }
                        }
                    }
                }
            } else {
                // 使用 selectorSubjectFormatIndexed (默认)
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
                        let mut all_results = Vec::new();

                        log::info!("[{}] === 搜索结果列表 (Format Indexed) ===", source_name);
                        log::info!(
                            "[{}] 目标: '{}' | 核心名: '{}'",
                            source_name,
                            query_name,
                            core_name
                        );
                        log::info!(
                            "[{}] 总共找到 {} 个结果",
                            source_name,
                            names.len().min(links.len())
                        );

                        for (name_el, link_el) in names.iter().zip(links.iter()) {
                            let title = name_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();

                            let score = calculate_match_score(&title, query_name, &core_name);
                            all_results.push((title.clone(), score, href.clone()));

                            log::info!(
                                "[{}] 结果 #{}: '{}' | 分数: {} | URL: {}",
                                source_name,
                                all_results.len(),
                                title,
                                score,
                                if href.len() > 100 {
                                    format!("{}...", &href[..100])
                                } else {
                                    href.clone()
                                }
                            );

                            if score > best_match_score && score >= 30 {
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
                            let top_matches: Vec<_> = all_results
                                .iter()
                                .filter(|(_, score, _)| *score >= 30)
                                .collect();
                            if !top_matches.is_empty() {
                                log::info!("[{}] ✓ 符合条件的结果 (分数≥30):", source_name);
                                for (title, score, _) in top_matches {
                                    log::info!(
                                        "[{}]   - '{}' (分数: {})",
                                        source_name,
                                        title,
                                        score
                                    );
                                }
                            } else {
                                log::warn!(
                                    "[{}] ✗ 没有符合条件的结果 (所有结果分数都<30)",
                                    source_name
                                );
                                if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max()
                                {
                                    log::warn!("[{}] 最高分: {}", source_name, max_score);
                                }
                            }
                            if best_match_score >= 30 {
                                log::info!(
                                    "[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})",
                                    source_name,
                                    best_match_score
                                );
                            }
                        }
                    }
                }
            }
            found_url
        };

        if !current_detail_url.is_empty() {
            detail_url = current_detail_url;
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
    })
    .ok();

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
                    channel_name: None,
                    channel_index: None,
                    all_channels: None,
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
            })
            .ok();
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
        channel_name: None,
        channel_index: None,
        all_channels: None,
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
                                    selected_channel_index = Some(0);
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
        cookies: cookies.clone(),
        headers: headers.clone(),
        channel_name: selected_channel_name.clone(),
        channel_index: selected_channel_index,
        all_channels: all_channels.clone(),
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
        cookies,
        headers,
        channel_name: selected_channel_name,
        channel_index: selected_channel_index,
        all_channels,
    })
    .ok();

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
    let mut detail_url = String::new();

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

        let current_detail_url = {
            let document = Html::parse_document(&resp_text);
            let mut found_url = String::new();
            let mut best_match_score = 0;

            // 根据 subjectFormatId 选择使用哪个 selector
            let format_id = source
                .arguments
                .search_config
                .subject_format_id
                .as_deref()
                .unwrap_or("indexed");

            if format_id == "a" {
                // 使用 selectorSubjectFormatA
                if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
                    if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                        let links: Vec<_> = document.select(&list_sel).collect();
                        let mut all_results = Vec::new();

                        log::info!("[{}] === 搜索结果列表 (Format A) ===", source_name);
                        log::info!(
                            "[{}] 目标: '{}' | 核心名: '{}'",
                            source_name,
                            query_name,
                            core_name
                        );
                        log::info!("[{}] 总共找到 {} 个结果", source_name, links.len());

                        for link_el in links.iter() {
                            let title = link_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();

                            // 计算匹配分数
                            let score = calculate_match_score(&title, query_name, &core_name);
                            all_results.push((title.clone(), score, href.clone()));

                            log::info!(
                                "[{}] 结果 #{}: '{}' | 分数: {} | URL: {}",
                                source_name,
                                all_results.len(),
                                title,
                                score,
                                if href.len() > 100 {
                                    format!("{}...", &href[..100])
                                } else {
                                    href.clone()
                                }
                            );

                            if score > best_match_score && score >= 30 {
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
                            let top_matches: Vec<_> = all_results
                                .iter()
                                .filter(|(_, score, _)| *score >= 30)
                                .collect();
                            if !top_matches.is_empty() {
                                log::info!("[{}] ✓ 符合条件的结果 (分数≥30):", source_name);
                                for (title, score, _) in top_matches {
                                    log::info!(
                                        "[{}]   - '{}' (分数: {})",
                                        source_name,
                                        title,
                                        score
                                    );
                                }
                            } else {
                                log::warn!(
                                    "[{}] ✗ 没有符合条件的结果 (所有结果分数都<30)",
                                    source_name
                                );
                                if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max()
                                {
                                    log::warn!("[{}] 最高分: {}", source_name, max_score);
                                }
                            }
                            if best_match_score >= 30 {
                                log::info!(
                                    "[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})",
                                    source_name,
                                    best_match_score
                                );
                            }
                        }
                    }
                }
            } else {
                // 使用 selectorSubjectFormatIndexed (默认)
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
                        let mut all_results = Vec::new();

                        log::info!("[{}] === 搜索结果列表 (Format Indexed) ===", source_name);
                        log::info!(
                            "[{}] 目标: '{}' | 核心名: '{}'",
                            source_name,
                            query_name,
                            core_name
                        );
                        log::info!(
                            "[{}] 总共找到 {} 个结果",
                            source_name,
                            names.len().min(links.len())
                        );

                        for (name_el, link_el) in names.iter().zip(links.iter()) {
                            let title = name_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();

                            // 计算匹配分数
                            let score = calculate_match_score(&title, query_name, &core_name);
                            all_results.push((title.clone(), score, href.clone()));

                            log::info!(
                                "[{}] 结果 #{}: '{}' | 分数: {} | URL: {}",
                                source_name,
                                all_results.len(),
                                title,
                                score,
                                if href.len() > 100 {
                                    format!("{}...", &href[..100])
                                } else {
                                    href.clone()
                                }
                            );

                            if score > best_match_score && score >= 30 {
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
                            let top_matches: Vec<_> = all_results
                                .iter()
                                .filter(|(_, score, _)| *score >= 30)
                                .collect();
                            if !top_matches.is_empty() {
                                log::info!("[{}] ✓ 符合条件的结果 (分数≥30):", source_name);
                                for (title, score, _) in top_matches {
                                    log::info!(
                                        "[{}]   - '{}' (分数: {})",
                                        source_name,
                                        title,
                                        score
                                    );
                                }
                            } else {
                                log::warn!(
                                    "[{}] ✗ 没有符合条件的结果 (所有结果分数都<30)",
                                    source_name
                                );
                                if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max()
                                {
                                    log::warn!("[{}] 最高分: {}", source_name, max_score);
                                }
                            }
                            if best_match_score >= 30 {
                                log::info!(
                                    "[{}] ★ 最终选择: 第一个分数最高的结果 (分数: {})",
                                    source_name,
                                    best_match_score
                                );
                            }
                        }
                    }
                }
            }
            found_url
        };

        if !current_detail_url.is_empty() {
            detail_url = current_detail_url;
            break;
        }
    }

    if detail_url.is_empty() {
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    log::info!("[{}] Found detail URL: {}", source_name, detail_url);

    // Step 2: 获取剧集列表
    let detail_resp_text = client.get(&detail_url).send().await?.text().await?;

    let episode_url = {
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
        channel_name: None, // 单集搜索模式不返回channel信息
        channel_index: None,
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
    let search_candidates = build_search_candidates(&anime_name);
    for source in root.exported_media_source_data_list.media_sources {
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
                    if let Some(href) = select_episode_by_number(
                        &episodes,
                        absolute_episode,
                        relative_episode,
                        ep_pattern,
                    ) {
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

/// 搜索单个源，返回包含所有channel和剧集信息的完整结果
/// 此函数用于获取多线路（如"简中"/"繁中"、"线路A"/"线路B"）的详细信息
async fn search_single_source_with_channels(
    client: &reqwest::Client,
    source: &MediaSource,
    anime_name: &str,
) -> anyhow::Result<SearchResultWithChannels> {
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
    let default_subtitle_language = source
        .arguments
        .search_config
        .default_subtitle_language
        .clone();
    let default_resolution = source.arguments.search_config.default_resolution.clone();

    let search_candidates = build_search_candidates(anime_name);
    let mut detail_url = String::new();
    let mut matched_title = String::new();

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

        let resp_text = client.get(&search_url).send().await?.text().await?;

        // 解析搜索结果
        let (current_detail_url, current_title) = {
            let document = Html::parse_document(&resp_text);
            let mut found_url = String::new();
            let mut found_title = String::new();
            let mut best_match_score = 0;

            let format_id = source
                .arguments
                .search_config
                .subject_format_id
                .as_deref()
                .unwrap_or("indexed");

            if format_id == "a" {
                if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
                    if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                        for link_el in document.select(&list_sel) {
                            let title = link_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();
                            let score = calculate_match_score(&title, query_name, &core_name);

                            if score > best_match_score && score >= 30 {
                                best_match_score = score;
                                found_title = title;
                                found_url = if href.starts_with("http") {
                                    href
                                } else {
                                    let base_url = if let Ok(u) = url::Url::parse(&search_url) {
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
            } else {
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

                        for (name_el, link_el) in names.iter().zip(links.iter()) {
                            let title = name_el.text().collect::<String>().trim().to_string();
                            let href = link_el.value().attr("href").unwrap_or("").to_string();
                            let score = calculate_match_score(&title, query_name, &core_name);

                            if score > best_match_score && score >= 50 {
                                best_match_score = score;
                                found_title = title;
                                found_url = if href.starts_with("http") {
                                    href
                                } else {
                                    let base_url = if let Ok(u) = url::Url::parse(&search_url) {
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
            (found_url, found_title)
        };

        if !current_detail_url.is_empty() {
            detail_url = current_detail_url;
            matched_title = current_title;
            break;
        }
    }

    if detail_url.is_empty() {
        return Err(anyhow::anyhow!("No matching anime found"));
    }

    log::info!(
        "[{}] Found detail URL: {} (title: {})",
        source_name,
        detail_url,
        matched_title
    );

    // Step 2: 获取详情页并解析channels和episodes
    let detail_resp_text = client.get(&detail_url).send().await?.text().await?;
    let detail_doc = Html::parse_document(&detail_resp_text);

    let mut channels: Vec<ChannelInfo> = Vec::new();
    let mut episodes: Vec<EpisodeInfo> = Vec::new();

    let channel_format_id = source
        .arguments
        .search_config
        .channel_format_id
        .as_deref()
        .unwrap_or("no-channel");

    if channel_format_id == "index-grouped" {
        // 多线路模式
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

            // 2. 获取每个channel对应的剧集列表
            if let (Ok(list_sel), Ok(item_sel)) = (
                Selector::parse(&format.select_episode_lists),
                Selector::parse(&format.select_episodes_from_list),
            ) {
                let ep_pattern = format.match_episode_sort_from_name.as_deref();

                for (channel_idx, list_container) in detail_doc.select(&list_sel).enumerate() {
                    // 如果channels为空，创建默认channel
                    if channels.is_empty() {
                        channels.push(ChannelInfo {
                            name: "默认线路".to_string(),
                            index: 0,
                        });
                    }

                    for ep_el in list_container.select(&item_sel) {
                        let ep_name = ep_el.text().collect::<String>().trim().to_string();
                        let ep_href = ep_el.value().attr("href").unwrap_or("").to_string();

                        if ep_href.is_empty() {
                            continue;
                        }

                        // 提取集数
                        let episode_number = extract_episode_number_from_text(&ep_name, ep_pattern);

                        let full_url = if ep_href.starts_with("http") {
                            ep_href
                        } else {
                            let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                                format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                            } else {
                                "".to_string()
                            };
                            format!("{}{}", base_url, ep_href)
                        };

                        episodes.push(EpisodeInfo {
                            name: ep_name,
                            url: full_url,
                            episode_number,
                            channel_index: channel_idx.min(channels.len().saturating_sub(1)),
                        });
                    }
                }
            }
        }
    } else {
        // 无线路区分模式（no-channel）
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
                let ep_pattern = format.match_episode_sort_from_name.as_deref();

                for ep_el in detail_doc.select(&ep_sel) {
                    let ep_name = ep_el.text().collect::<String>().trim().to_string();
                    let ep_href = ep_el.value().attr("href").unwrap_or("").to_string();

                    if ep_href.is_empty() {
                        continue;
                    }

                    let episode_number = extract_episode_number_from_text(&ep_name, ep_pattern);

                    let full_url = if ep_href.starts_with("http") {
                        ep_href
                    } else {
                        let base_url = if let Ok(u) = url::Url::parse(&detail_url) {
                            format!("{}://{}", u.scheme(), u.host_str().unwrap_or(""))
                        } else {
                            "".to_string()
                        };
                        format!("{}{}", base_url, ep_href)
                    };

                    episodes.push(EpisodeInfo {
                        name: ep_name,
                        url: full_url,
                        episode_number,
                        channel_index: 0,
                    });
                }
            }
        }
    }

    log::info!(
        "[{}] Found {} channels and {} episodes",
        source_name,
        channels.len(),
        episodes.len()
    );

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

/// 从文本中提取集数
fn extract_episode_number_from_text(text: &str, custom_pattern: Option<&str>) -> Option<u32> {
    // 如果提供了自定义正则表达式，优先使用
    if let Some(pattern) = custom_pattern {
        if !pattern.is_empty() && pattern != "$^" {
            if let Ok(re) = Regex::new(pattern) {
                if let Ok(Some(caps)) = re.captures(text) {
                    if let Some(ep_match) = caps.name("ep") {
                        let ep_str = ep_match.as_str();
                        if let Some(num) = parse_chinese_number(ep_str) {
                            return Some(num);
                        }
                        if let Ok(num) = ep_str.parse::<u32>() {
                            return Some(num);
                        }
                    }
                    if let Some(num_match) = caps.get(1) {
                        let num_str = num_match.as_str();
                        if let Some(num) = parse_chinese_number(num_str) {
                            return Some(num);
                        }
                        if let Ok(num) = num_str.parse::<u32>() {
                            return Some(num);
                        }
                    }
                }
            }
        }
    }

    // 默认的集数匹配模式
    let default_patterns = [
        r"第\s*(?<ep>[一二三四五六七八九十百千\d]+)\s*[集话]",
        r"EP\.?\s*(\d+)",
        r"Episode\s*(\d+)",
        r"第\s*(\d+)",
        r"^(\d+)$",
        r"\[(?<ep>\d+)\]",
        r"【(?<ep>\d+)】",
        r"\s+(?<ep>\d+)\s*$",
    ];

    for pattern in &default_patterns {
        if let Ok(re) = Regex::new(pattern) {
            if let Ok(Some(caps)) = re.captures(text) {
                if let Some(ep_match) = caps.name("ep") {
                    let ep_str = ep_match.as_str();
                    if let Some(num) = parse_chinese_number(ep_str) {
                        return Some(num);
                    }
                    if let Ok(num) = ep_str.parse::<u32>() {
                        return Some(num);
                    }
                }
                if let Some(num_str) = caps.get(1) {
                    if let Ok(num) = num_str.as_str().parse::<u32>() {
                        return Some(num);
                    }
                }
            }
        }
    }
    None
}

/// 搜索所有源，返回包含多channel信息的完整结果
/// 此API用于UI展示所有可用的线路和剧集供用户选择
pub async fn generic_search_with_channels(
    anime_name: String,
) -> anyhow::Result<Vec<SearchResultWithChannels>> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;

    // 并发搜索所有源（每个源占用一个并发槽位）
    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream = futures::stream::iter(
        root.exported_media_source_data_list
            .media_sources
            .into_iter()
            .filter(|source| crate::api::config::is_source_enabled(&source.arguments.name)),
    )
    .map(|source| {
        let client = client.clone();
        let anime_name = anime_name.clone();
        async move {
            log::info!("Searching source with channels: {}", source.arguments.name);
            search_single_source_with_channels(&client, &source, &anime_name).await
        }
    })
    .buffer_unordered(limit);

    let all_results: Vec<_> = stream.collect().await;

    let results: Vec<SearchResultWithChannels> = all_results.into_iter().filter_map(|r| r.ok()).collect();

    Ok(results)
}

/// 搜索所有源，以流的形式返回包含多channel信息的结果
pub async fn generic_search_with_channels_stream(
    anime_name: String,
    sink: crate::frb_generated::StreamSink<SearchResultWithChannels>,
) -> anyhow::Result<()> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;

    let limit = crate::api::config::get_max_concurrent_searches();
    let limit = if limit == 0 {
        usize::MAX
    } else {
        limit as usize
    };

    use futures::stream::StreamExt;

    let stream = futures::stream::iter(
        root.exported_media_source_data_list
            .media_sources
            .into_iter()
            .filter(|source| crate::api::config::is_source_enabled(&source.arguments.name)),
    )
    .map(|source| {
        let client = client.clone();
        let anime_name = anime_name.clone();
        async move { search_single_source_with_channels(&client, &source, &anime_name).await }
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
pub async fn get_episode_play_url(
    source_name: String,
    anime_name: String,
    channel_index: usize,
    episode_number: Option<u32>,
) -> anyhow::Result<SearchPlayResult> {
    let client = crate::api::network::create_client()?;
    let content = load_playback_source_config(&client).await?;

    let root: SampleRoot = serde_json::from_str(&content)?;

    // 找到指定的源
    let source = root
        .exported_media_source_data_list
        .media_sources
        .iter()
        .find(|s| s.arguments.name == source_name)
        .ok_or_else(|| anyhow::anyhow!("Source not found: {}", source_name))?;

    // 获取完整的channel和episode信息
    let result = search_single_source_with_channels(&client, source, &anime_name).await?;

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
    })
}
