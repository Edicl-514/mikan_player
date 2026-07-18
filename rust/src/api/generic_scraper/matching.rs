use super::types::MediaSource;
use fancy_regex::Regex;
use scraper::{Html, Selector};

lazy_static::lazy_static! {
    /// 匹配季数相关的关键词
    static ref SEASON_RE: Regex = Regex::new(r"(?i)第[一二三四五六七八九十\d]+季|Part\s*\d+|\d+(st|nd|rd|th)\s*Season|Season\s*\d+").unwrap();
    static ref SUBJECT_SEASON_PATTERNS: Vec<Regex> = vec![
        Regex::new(r"第\s*(?<value>[零〇一二两三四五六七八九十百\d]+)\s*[季期]").unwrap(),
        Regex::new(r"(?i)\bseason\s*(?<value>\d+)\b").unwrap(),
        Regex::new(r"(?i)\bs\s*(?<value>\d+)\b").unwrap(),
        Regex::new(r"(?i)\b(?<value>\d+)(?:st|nd|rd|th)\s+season\b").unwrap(),
    ];
    static ref SUBJECT_PART_PATTERNS: Vec<Regex> = vec![
        Regex::new(r"(?i)\bpart\s*(?<value>\d+)\b").unwrap(),
    ];
    static ref LIVE_ACTION_RE: Regex = Regex::new(
        r"(?i)真人(?:版|剧)?|live[\s_-]*action"
    ).unwrap();
    static ref MOVIE_RE: Regex = Regex::new(
        r"(?i)剧场版|劇場版|电影版?|電影版?|(?<![a-z0-9])(?:movie|film)(?![a-z0-9])"
    ).unwrap();
    static ref OVA_RE: Regex = Regex::new(
        r"(?i)(?<![a-z0-9])(?:ova|oad)(?![a-z0-9])"
    ).unwrap();
    static ref SPECIAL_RE: Regex = Regex::new(
        r"(?i)特别篇|特別篇|总集篇|總集篇|番外篇|完结篇|完結篇|终幕|終幕|(?<![a-z0-9])(?:special|sp)(?![a-z0-9])"
    ).unwrap();
}

/// 预处理搜索词，提取核心动画名称
/// 参考 mikan.rs 的实现
pub(super) fn preprocess_search_term(name: &str) -> String {
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
pub(super) fn build_search_candidates(anime_name: &str) -> Vec<String> {
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

/// 解析中文数字（一二三四五六七八九十等）为阿拉伯数字
pub(super) fn parse_chinese_number(s: &str) -> Option<u32> {
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
pub(super) fn extract_channel_name(text: &str, pattern: Option<&str>) -> String {
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
pub(super) fn extract_core_name(name: &str) -> String {
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
pub(super) fn calculate_match_score(title: &str, full_name: &str, core_name: &str) -> i32 {
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

pub(super) const MATCH_THRESHOLD: i32 = 36;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SubjectVariant {
    Normal,
    LiveAction,
    Movie,
    Ova,
    Special,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct SubjectIdentity {
    core_title: String,
    season: Option<u32>,
    part: Option<u32>,
    variant: SubjectVariant,
}

fn extract_subject_number(title: &str, patterns: &[Regex]) -> Option<u32> {
    for pattern in patterns {
        if let Ok(Some(captures)) = pattern.captures(title) {
            if let Some(value) = captures.name("value") {
                if let Some(number) = parse_chinese_number(value.as_str()) {
                    return Some(number);
                }
            }
        }
    }
    None
}

fn subject_variant(title: &str) -> SubjectVariant {
    if LIVE_ACTION_RE.is_match(title).unwrap_or(false) {
        SubjectVariant::LiveAction
    } else if MOVIE_RE.is_match(title).unwrap_or(false) {
        SubjectVariant::Movie
    } else if OVA_RE.is_match(title).unwrap_or(false) {
        SubjectVariant::Ova
    } else if SPECIAL_RE.is_match(title).unwrap_or(false) {
        SubjectVariant::Special
    } else {
        SubjectVariant::Normal
    }
}

fn parse_subject_identity(title: &str) -> SubjectIdentity {
    let season = extract_subject_number(title, &SUBJECT_SEASON_PATTERNS);
    let part = extract_subject_number(title, &SUBJECT_PART_PATTERNS);
    let variant = subject_variant(title);

    let mut core_title = title.to_lowercase();
    for pattern in SUBJECT_SEASON_PATTERNS
        .iter()
        .chain(SUBJECT_PART_PATTERNS.iter())
    {
        core_title = pattern.replace_all(&core_title, " ").to_string();
    }
    for pattern in [&*LIVE_ACTION_RE, &*MOVIE_RE, &*OVA_RE, &*SPECIAL_RE] {
        core_title = pattern.replace_all(&core_title, " ").to_string();
    }
    core_title.retain(|c| c.is_alphanumeric());

    SubjectIdentity {
        core_title,
        season,
        part,
        variant,
    }
}

fn is_semantically_compatible_subject(
    query: &SubjectIdentity,
    best: &SubjectIdentity,
    candidate: &SubjectIdentity,
) -> bool {
    if best.core_title.is_empty() || candidate.core_title != best.core_title {
        return false;
    }

    let expected_season = query.season.or(best.season);
    if candidate.season != expected_season {
        return false;
    }

    let expected_part = query.part.or(best.part);
    if candidate.part != expected_part {
        return false;
    }

    let expected_variant = if query.variant == SubjectVariant::Normal {
        best.variant
    } else {
        query.variant
    };
    candidate.variant == expected_variant
}

fn retain_semantic_subject_retries(query_name: &str, ranked: &mut Vec<SubjectCandidate>) {
    let Some(best) = ranked.first().cloned() else {
        return;
    };

    let query_identity = parse_subject_identity(query_name);
    let best_identity = parse_subject_identity(&best.title);
    ranked.retain(|candidate| {
        candidate.url == best.url
            || is_semantically_compatible_subject(
                &query_identity,
                &best_identity,
                &parse_subject_identity(&candidate.title),
            )
    });
}

#[derive(Clone)]
pub(super) struct SubjectCandidate {
    pub(super) title: String,
    pub(super) url: String,
    pub(super) score: i32,
}

pub(super) struct SubjectSelectionResult {
    /// Highest-scoring candidate (first among ties in document order).
    pub(super) best: Option<SubjectCandidate>,
    /// Semantically compatible candidates above threshold, sorted by score desc
    /// (stable for ties) and de-duplicated by URL. Used to fall back when a detail
    /// page has no channels without crossing seasons or media variants.
    pub(super) ranked: Vec<SubjectCandidate>,
    pub(super) all_scored: Vec<(String, i32, String)>,
}

pub(super) fn select_best_subject_candidate(
    document: &Html,
    source: &MediaSource,
    query_name: &str,
    core_name: &str,
) -> SubjectSelectionResult {
    let format_id = source
        .arguments
        .search_config
        .subject_format_id
        .as_deref()
        .unwrap_or("indexed");

    let mut all_scored: Vec<(String, i32, String)> = Vec::new();

    if format_id == "a" {
        if let Some(ref format) = source.arguments.search_config.selector_subject_format_a {
            if let Ok(list_sel) = Selector::parse(&format.select_lists) {
                for link_el in document.select(&list_sel) {
                    let title = link_el.text().collect::<String>().trim().to_string();
                    let href = link_el.value().attr("href").unwrap_or("").to_string();
                    let score = calculate_match_score(&title, query_name, core_name);
                    all_scored.push((title, score, href));
                }
            }
        }
    } else if let Some(ref format) = source
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
                let score = calculate_match_score(&title, query_name, core_name);
                all_scored.push((title, score, href));
            }
        }
    }

    // Keep document order among equal scores (stable sort).
    let mut ranked: Vec<SubjectCandidate> = all_scored
        .iter()
        .filter(|(_, score, url)| *score >= MATCH_THRESHOLD && !url.is_empty())
        .map(|(title, score, url)| SubjectCandidate {
            title: title.clone(),
            url: url.clone(),
            score: *score,
        })
        .collect();
    ranked.sort_by(|a, b| b.score.cmp(&a.score));

    let mut seen_urls = std::collections::HashSet::new();
    ranked.retain(|c| seen_urls.insert(c.url.clone()));

    retain_semantic_subject_retries(query_name, &mut ranked);

    let best = ranked.first().cloned();

    SubjectSelectionResult {
        best,
        ranked,
        all_scored,
    }
}

pub(super) fn log_subject_selection(
    source_name: &str,
    format_id: &str,
    query_name: &str,
    core_name: &str,
    result: &SubjectSelectionResult,
) {
    let all_results = &result.all_scored;
    log::info!(
        "[{}] === 搜索结果列表 (Format {}) ===",
        source_name,
        if format_id == "a" { "A" } else { "Indexed" }
    );
    log::info!(
        "[{}] 目标: '{}' | 核心名: '{}'",
        source_name,
        query_name,
        core_name
    );
    log::info!("[{}] 总共找到 {} 个结果", source_name, all_results.len());

    for (i, (title, score, href)) in all_results.iter().enumerate() {
        log::info!(
            "[{}] 结果 #{}: '{}' | 分数: {} | URL: {}",
            source_name,
            i + 1,
            title,
            score,
            if href.len() > 100 {
                format!("{}...", &href[..100])
            } else {
                href.clone()
            }
        );
    }

    if !all_results.is_empty() {
        let top_matches: Vec<_> = all_results
            .iter()
            .filter(|(_, score, _)| *score >= MATCH_THRESHOLD)
            .collect();
        if !top_matches.is_empty() {
            log::info!(
                "[{}] ✓ 符合条件的结果 (分数≥{}):",
                source_name,
                MATCH_THRESHOLD
            );
            for (title, score, _) in top_matches {
                log::info!("[{}]   - '{}' (分数: {})", source_name, title, score);
            }
        } else {
            log::warn!(
                "[{}] ✗ 没有符合条件的结果 (所有结果分数都<{})",
                source_name,
                MATCH_THRESHOLD
            );
            if let Some(max_score) = all_results.iter().map(|(_, s, _)| s).max() {
                log::warn!("[{}] 最高分: {}", source_name, max_score);
            }
        }
        if let Some(best) = result.best.as_ref() {
            log::info!(
                "[{}] ★ 最终选择: '{}' (分数: {}, 候选共 {} 个)",
                source_name,
                best.title,
                best.score,
                result.ranked.len()
            );
            if result.ranked.len() > 1 {
                for (i, c) in result.ranked.iter().skip(1).take(5).enumerate() {
                    log::info!(
                        "[{}]   备选 #{}: '{}' (分数: {})",
                        source_name,
                        i + 1,
                        c.title,
                        c.score
                    );
                }
            }
        }
    }
}

/// Cap on how many detail-page candidates to try when the top match has no playable channel.
pub(super) const MAX_SUBJECT_DETAIL_RETRIES: usize = 5;

/// How many candidates to try when falling back after an empty detail page.
pub(super) fn subject_retry_limit(ranked_len: usize) -> usize {
    ranked_len.min(MAX_SUBJECT_DETAIL_RETRIES)
}

/// 从集数列表中选择指定集号的链接
/// absolute_ep: 绝对集号（如第15集）
/// relative_ep: 相对集号（如当季第3集）
/// custom_pattern: 自定义的集号匹配正则表达式（从JSON配置读取）
/// 优先匹配绝对集号，找不到则回退到相对集号
pub(super) fn select_episode_by_number(
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
/// 从文本中提取集数
pub(super) fn extract_episode_number_from_text(
    text: &str,
    custom_pattern: Option<&str>,
) -> Option<u32> {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_chinese_episode_numbers() {
        assert_eq!(parse_chinese_number("十"), Some(10));
        assert_eq!(parse_chinese_number("二十三"), Some(23));
        assert_eq!(parse_chinese_number("一百零二"), Some(102));
        assert_eq!(parse_chinese_number("12"), Some(12));
    }

    #[test]
    fn builds_unique_search_candidates_in_order() {
        assert_eq!(
            build_search_candidates("葬送的芙莉莲 || Frieren || 葬送的芙莉莲"),
            vec!["葬送的芙莉莲", "Frieren"]
        );
    }

    #[test]
    fn extracts_episode_number_with_custom_and_default_patterns() {
        assert_eq!(
            extract_episode_number_from_text(
                "第十二集",
                Some(r"第(?<ep>[一二三四五六七八九十]+)集")
            ),
            Some(12)
        );
        assert_eq!(extract_episode_number_from_text("[24]", None), Some(24));
    }

    #[test]
    fn exact_title_scores_higher_than_unrelated_title() {
        let exact = calculate_match_score("葬送的芙莉莲", "葬送的芙莉莲", "葬送的芙莉莲");
        let unrelated = calculate_match_score("迷宫饭", "葬送的芙莉莲", "葬送的芙莉莲");
        assert!(exact > unrelated);
        assert!(exact >= MATCH_THRESHOLD);
    }

    #[test]
    fn parses_subject_identity_across_season_formats() {
        let chinese = parse_subject_identity("【我推的孩子】 第三季");
        let numeric = parse_subject_identity("我推的孩子 第3期");
        let english = parse_subject_identity("Oshi no Ko Season 3 Part 2");

        assert_eq!(chinese.core_title, "我推的孩子");
        assert_eq!(chinese, numeric);
        assert_eq!(english.core_title, "oshinoko");
        assert_eq!(english.season, Some(3));
        assert_eq!(english.part, Some(2));
    }

    #[test]
    fn semantic_retries_exclude_other_seasons_and_variants() {
        let mut ranked = vec![
            SubjectCandidate {
                title: "【我推的孩子】第三季".to_string(),
                url: "/third-a".to_string(),
                score: 85,
            },
            SubjectCandidate {
                title: "我推的孩子 第3期".to_string(),
                url: "/third-b".to_string(),
                score: 74,
            },
            SubjectCandidate {
                title: "我推的孩子 第二季".to_string(),
                url: "/second".to_string(),
                score: 72,
            },
            SubjectCandidate {
                title: "我推的孩子".to_string(),
                url: "/unspecified".to_string(),
                score: 70,
            },
            SubjectCandidate {
                title: "【我推的孩子】真人版 第三季".to_string(),
                url: "/live-action".to_string(),
                score: 65,
            },
            SubjectCandidate {
                title: "我推的孩子 第三季 剧场版".to_string(),
                url: "/movie".to_string(),
                score: 60,
            },
        ];

        retain_semantic_subject_retries("【我推的孩子】 第三季", &mut ranked);

        let urls: Vec<_> = ranked
            .iter()
            .map(|candidate| candidate.url.as_str())
            .collect();
        assert_eq!(urls, vec!["/third-a", "/third-b"]);
    }

    #[test]
    fn semantic_retries_keep_the_original_best_when_query_metadata_disagrees() {
        let mut ranked = vec![
            SubjectCandidate {
                title: "我推的孩子".to_string(),
                url: "/best".to_string(),
                score: 64,
            },
            SubjectCandidate {
                title: "我推的孩子 第二季".to_string(),
                url: "/second".to_string(),
                score: 63,
            },
        ];

        retain_semantic_subject_retries("我推的孩子 第三季", &mut ranked);

        assert_eq!(ranked.len(), 1);
        assert_eq!(ranked[0].url, "/best");
    }
}
