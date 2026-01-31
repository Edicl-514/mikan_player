// 弹幕 API 模块
// 集成 Dandanplay API 实现弹幕功能

use base64::{Engine, engine::general_purpose::STANDARD as BASE64};
use flutter_rust_bridge::frb;
use reqwest::header::{HeaderMap, HeaderValue};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// AppId
const APP_ID: &str = " ";

/// AppSecret
const APP_SECRET: &str = " ";

// ============================================================================
// 数据结构定义
// ============================================================================

/// 弹幕数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Danmaku {
    /// 弹幕出现时间（秒）
    pub time: f64,
    /// 弹幕类型: 1-3 滚动, 4 底部, 5 顶部
    pub danmaku_type: i32,
    /// 弹幕颜色 (RGB 整数值)
    pub color: u32,
    /// 弹幕内容
    pub text: String,
}

/// 搜索结果中的动画
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DanmakuAnime {
    /// 动画ID
    pub anime_id: i64,
    /// 动画标题
    pub anime_title: String,
    /// 动画类型
    pub anime_type: String,
    /// 类型描述
    pub type_description: Option<String>,
    /// 封面图 URL
    pub image_url: Option<String>,
}

/// 剧集信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DanmakuEpisode {
    /// 剧集ID (用于获取弹幕)
    pub episode_id: i64,
    /// 剧集标题
    pub episode_title: String,
    /// 剧集编号
    pub episode_number: Option<String>,
}

/// Bangumi TV 剧集信息 (从 Dandanplay Bangumi API 获取)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiTvEpisode {
    /// 剧集ID (用于获取弹幕)
    pub episode_id: i64,
    /// 剧集标题
    pub episode_title: String,
    /// 剧集编号
    pub episode_number: String,
    /// 播放日期
    pub air_date: Option<String>,
}

/// 匹配结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DanmakuMatch {
    /// 剧集ID
    pub episode_id: i64,
    /// 动画ID  
    pub anime_id: i64,
    /// 动画标题
    pub anime_title: String,
    /// 剧集标题
    pub episode_title: String,
}

// ============================================================================
// API 响应结构 (内部使用)
// ============================================================================

#[derive(Debug, Deserialize)]
struct DanmakuComment {
    p: String,
    m: String,
}

#[derive(Debug, Deserialize)]
struct DanmakuResponse {
    count: i32,
    comments: Vec<DanmakuComment>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchAnimeApi {
    anime_id: i64,
    anime_title: String,
    #[serde(rename = "type")]
    anime_type: String,
    type_description: Option<String>,
    image_url: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SearchResponse {
    animes: Vec<SearchAnimeApi>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct EpisodeApi {
    episode_id: i64,
    episode_title: String,
    episode_number: Option<String>,
}

#[derive(Debug, Deserialize)]
struct BangumiDetail {
    episodes: Vec<EpisodeApi>,
}

#[derive(Debug, Deserialize)]
struct BangumiResponse {
    bangumi: BangumiDetail,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MatchResultApi {
    episode_id: i64,
    anime_id: i64,
    anime_title: String,
    episode_title: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MatchResponse {
    is_matched: bool,
    matches: Vec<MatchResultApi>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BangumiTvEpisodeApi {
    episode_id: i64,
    episode_title: String,
    episode_number: String,
    air_date: Option<String>,
}

#[derive(Debug, Deserialize)]
struct BangumiTvDetail {
    episodes: Vec<BangumiTvEpisodeApi>,
}

#[derive(Debug, Deserialize)]
struct BangumiTvResponse {
    bangumi: BangumiTvDetail,
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 从完整 URL 提取路径部分
fn extract_url_path(url: &str) -> Option<String> {
    if let Some(start) = url.find("://") {
        let after_scheme = &url[start + 3..];
        if let Some(slash_pos) = after_scheme.find('/') {
            let path_start = start + 3 + slash_pos;
            let path = if let Some(query_pos) = url[path_start..].find('?') {
                &url[path_start..path_start + query_pos]
            } else {
                &url[path_start..]
            };
            return Some(path.to_string());
        }
    }
    None
}

/// 生成 X-Signature 签名
/// 算法: Base64(SHA256(AppId + Timestamp + UrlPath + AppSecret))
fn generate_signature(url: &str, timestamp: i64) -> Result<String, String> {
    let url_path = extract_url_path(url).ok_or("Invalid URL")?;

    // 拼接签名数据: AppId + Timestamp + UrlPath + AppSecret
    let data_to_hash = format!("{}{}{}{}", APP_ID, timestamp, url_path, APP_SECRET);

    // SHA256 哈希
    let mut hasher = Sha256::new();
    hasher.update(data_to_hash.as_bytes());
    let hash = hasher.finalize();

    // Base64 编码
    Ok(BASE64.encode(&hash))
}

/// 构建带签名的请求头
fn build_signed_headers(url: &str) -> Result<HeaderMap, String> {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_secs() as i64;

    let signature = generate_signature(url, timestamp)?;

    let mut headers = HeaderMap::new();
    headers.insert("Accept", HeaderValue::from_static("application/json"));
    headers.insert(
        "User-Agent",
        HeaderValue::from_static("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"),
    );
    headers.insert("X-AppId", HeaderValue::from_static(APP_ID));
    headers.insert(
        "X-Signature",
        HeaderValue::from_str(&signature).map_err(|e| e.to_string())?,
    );
    headers.insert(
        "X-Timestamp",
        HeaderValue::from_str(&timestamp.to_string()).map_err(|e| e.to_string())?,
    );

    Ok(headers)
}

/// 解析弹幕参数
/// 格式: "时间,类型,颜色,用户ID"
fn parse_danmaku_comment(comment: &DanmakuComment) -> Option<Danmaku> {
    let parts: Vec<&str> = comment.p.split(',').collect();
    if parts.len() >= 3 {
        let time = parts[0].parse::<f64>().ok()?;
        let danmaku_type = parts[1].parse::<i32>().unwrap_or(1);
        let color = parts[2].parse::<u32>().unwrap_or(0xFFFFFF);

        Some(Danmaku {
            time,
            danmaku_type,
            color,
            text: comment.m.clone(),
        })
    } else {
        None
    }
}

// ============================================================================
// 公开 API (Flutter Rust Bridge)
// ============================================================================

/// 搜索动画
///
/// # 参数
/// - `keyword`: 搜索关键词
///
/// # 返回
/// 匹配的动画列表
#[frb]
pub async fn danmaku_search_anime(keyword: String) -> Result<Vec<DanmakuAnime>, String> {
    let url = format!(
        "https://api.dandanplay.net/api/v2/search/anime?keyword={}",
        urlencoding::encode(&keyword)
    );

    let headers = build_signed_headers(&url)?;

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .headers(headers)
        .send()
        .await
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status();
    let text = response.text().await.map_err(|e| e.to_string())?;

    if !status.is_success() {
        return Err(format!("API error {}: {}", status, text));
    }

    let api_response: SearchResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Parse error: {} - Response: {}", e, text))?;

    Ok(api_response
        .animes
        .into_iter()
        .map(|a| DanmakuAnime {
            anime_id: a.anime_id,
            anime_title: a.anime_title,
            anime_type: a.anime_type,
            type_description: a.type_description,
            image_url: a.image_url,
        })
        .collect())
}

/// 获取动画剧集列表
///
/// # 参数
/// - `anime_id`: 动画ID (从搜索结果获取)
///
/// # 返回
/// 剧集列表
#[frb]
pub async fn danmaku_get_episodes(anime_id: i64) -> Result<Vec<DanmakuEpisode>, String> {
    let url = format!("https://api.dandanplay.net/api/v2/bangumi/{}", anime_id);

    let headers = build_signed_headers(&url)?;

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .headers(headers)
        .send()
        .await
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status();
    let text = response.text().await.map_err(|e| e.to_string())?;

    if !status.is_success() {
        return Err(format!("API error {}: {}", status, text));
    }

    let api_response: BangumiResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Parse error: {} - Response: {}", e, text))?;

    Ok(api_response
        .bangumi
        .episodes
        .into_iter()
        .map(|e| DanmakuEpisode {
            episode_id: e.episode_id,
            episode_title: e.episode_title,
            episode_number: e.episode_number,
        })
        .collect())
}

/// 通过 Bangumi TV subject_id 获取剧集列表
///
/// # 参数
/// - `subject_id`: Bangumi TV 的 subject_id (例如: 517057)
///
/// # 返回
/// 剧集列表
#[frb]
pub async fn danmaku_get_bangumi_episodes(
    subject_id: i64,
) -> Result<Vec<BangumiTvEpisode>, String> {
    let url = format!(
        "https://api.dandanplay.net/api/v2/bangumi/bgmtv/{}",
        subject_id
    );

    let headers = build_signed_headers(&url)?;

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .headers(headers)
        .send()
        .await
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status();
    let text = response.text().await.map_err(|e| e.to_string())?;

    if !status.is_success() {
        return Err(format!("API error {}: {}", status, text));
    }

    let api_response: BangumiTvResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Parse error: {} - Response: {}", e, text))?;

    log::info!(
        "[Danmaku] Loaded {} episodes from Bangumi TV subject {}",
        api_response.bangumi.episodes.len(),
        subject_id
    );

    Ok(api_response
        .bangumi
        .episodes
        .into_iter()
        .map(|e| BangumiTvEpisode {
            episode_id: e.episode_id,
            episode_title: e.episode_title,
            episode_number: e.episode_number,
            air_date: e.air_date,
        })
        .collect())
}

/// 获取弹幕列表
///
/// # 参数
/// - `episode_id`: 剧集ID (从剧集列表或匹配结果获取)
///
/// # 返回
/// 弹幕列表，按时间排序
#[frb]
pub async fn danmaku_get_comments(episode_id: i64) -> Result<Vec<Danmaku>, String> {
    let url = format!(
        "https://api.dandanplay.net/api/v2/comment/{}?withRelated=true&chConvert=1",
        episode_id
    );

    let headers = build_signed_headers(&url)?;

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .headers(headers)
        .send()
        .await
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status();
    let text = response.text().await.map_err(|e| e.to_string())?;

    if !status.is_success() {
        return Err(format!("API error {}: {}", status, text));
    }

    let api_response: DanmakuResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Parse error: {} - Response: {}", e, text))?;

    let mut danmakus: Vec<Danmaku> = api_response
        .comments
        .iter()
        .filter_map(parse_danmaku_comment)
        .collect();

    // 按时间排序
    danmakus.sort_by(|a, b| {
        a.time
            .partial_cmp(&b.time)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    log::info!(
        "[Danmaku] Loaded {} comments for episode {}",
        danmakus.len(),
        episode_id
    );

    Ok(danmakus)
}

/// 通过文件名匹配动画
///
/// # 参数
/// - `file_name`: 视频文件名
/// - `file_hash`: 可选的文件hash (前16MB的MD5)
///
/// # 返回
/// 匹配结果列表，可能为空
#[frb]
pub async fn danmaku_match_anime(
    file_name: String,
    file_hash: Option<String>,
) -> Result<Vec<DanmakuMatch>, String> {
    let url = "https://api.dandanplay.net/api/v2/match";

    let headers = build_signed_headers(url)?;

    let body = serde_json::json!({
        "fileName": file_name,
        "fileHash": file_hash.unwrap_or_default(),
        "matchMode": "hashAndFileName"
    });

    let client = reqwest::Client::new();
    let response = client
        .post(url)
        .headers(headers)
        .header("Content-Type", "application/json")
        .body(body.to_string())
        .send()
        .await
        .map_err(|e| format!("Request failed: {}", e))?;

    let status = response.status();
    let text = response.text().await.map_err(|e| e.to_string())?;

    if !status.is_success() {
        return Err(format!("API error {}: {}", status, text));
    }

    let api_response: MatchResponse = serde_json::from_str(&text)
        .map_err(|e| format!("Parse error: {} - Response: {}", e, text))?;

    log::info!(
        "[Danmaku] Match result for '{}': is_matched={}, matches={}",
        file_name,
        api_response.is_matched,
        api_response.matches.len()
    );

    Ok(api_response
        .matches
        .into_iter()
        .map(|m| DanmakuMatch {
            episode_id: m.episode_id,
            anime_id: m.anime_id,
            anime_title: m.anime_title,
            episode_title: m.episode_title,
        })
        .collect())
}

/// 便捷方法：通过动画名称和集数获取弹幕
///
/// # 参数
/// - `anime_title`: 动画标题
/// - `episode_number`: 集数编号 (例如: "1", "2")
/// - `relative_episode`: 相对集号 (1-based 索引，作为回退)
///
/// # 返回
/// 弹幕列表，如果找不到则返回空列表
#[frb]
pub async fn danmaku_get_by_title(
    anime_title: String,
    episode_number: String,
    relative_episode: Option<i32>,
) -> Result<Vec<Danmaku>, String> {
    // 1. 搜索动画
    let animes = danmaku_search_anime(anime_title.clone()).await?;

    if animes.is_empty() {
        log::warn!("[Danmaku] No anime found for title: {}", anime_title);
        return Ok(vec![]);
    }

    // 2. 获取第一个匹配动画的剧集列表
    let anime = &animes[0];
    let episodes = danmaku_get_episodes(anime.anime_id).await?;

    // 3. 找到对应集数的剧集
    // 优先匹配集数编号
    let mut episode = episodes.iter().find(|e| {
        e.episode_number
            .as_ref()
            .map(|n| n == &episode_number)
            .unwrap_or(false)
    });

    // 如果编号不匹配，尝试通过相对集号（索引）匹配
    if episode.is_none() {
        if let Some(rel_ep) = relative_episode {
            let episode_idx = (rel_ep - 1) as usize;
            if episode_idx < episodes.len() {
                log::info!(
                    "[Danmaku] Episode {} not found by number for '{}', using relative episode {}",
                    episode_number,
                    anime_title,
                    rel_ep
                );
                episode = Some(&episodes[episode_idx]);
            }
        }
    }

    if let Some(ep) = episode {
        // 4. 获取弹幕
        log::info!(
            "[Danmaku] Loading comments for '{}' - {} (ID: {})",
            anime.anime_title,
            ep.episode_title,
            ep.episode_id
        );

        danmaku_get_comments(ep.episode_id).await
    } else {
        log::warn!(
            "[Danmaku] Episode {} (rel: {:?}) not found for '{}' (total: {})",
            episode_number,
            relative_episode,
            anime_title,
            episodes.len()
        );
        Ok(vec![])
    }
}

/// 便捷方法：通过 Bangumi TV subject_id 和集数获取弹幕
///
/// # 参数
/// - `subject_id`: Bangumi TV 的 subject_id
/// - `episode_number`: 集数编号 (例如: "1", "2", "SP1" 等)
/// - `relative_episode`: 相对集号 (1-based 索引，作为回退)
///
/// # 返回
/// 弹幕列表，如果找不到则返回空列表
#[frb]
pub async fn danmaku_get_by_bangumi_id(
    subject_id: i64,
    episode_number: String,
    relative_episode: Option<i32>,
) -> Result<Vec<Danmaku>, String> {
    // 1. 获取剧集列表
    let episodes = danmaku_get_bangumi_episodes(subject_id).await?;

    if episodes.is_empty() {
        log::warn!(
            "[Danmaku] No episodes found for Bangumi TV subject: {}",
            subject_id
        );
        return Ok(vec![]);
    }

    // 2. 找到对应集数的剧集
    // 优先匹配集数编号
    let mut episode = episodes.iter().find(|e| e.episode_number == episode_number);

    // 如果编号不匹配，尝试通过相对集号（索引）匹配
    if episode.is_none() {
        if let Some(rel_ep) = relative_episode {
            let episode_idx = (rel_ep - 1) as usize;
            if episode_idx < episodes.len() {
                log::info!(
                    "[Danmaku] Episode {} not found by number for subject {}, using relative episode {}",
                    episode_number,
                    subject_id,
                    rel_ep
                );
                episode = Some(&episodes[episode_idx]);
            }
        }
    }

    if let Some(ep) = episode {
        log::info!(
            "[Danmaku] Found episode: {} (ID: {}) for subject {} ep {} (rel: {:?})",
            ep.episode_title,
            ep.episode_id,
            subject_id,
            episode_number,
            relative_episode
        );

        // 3. 获取弹幕
        danmaku_get_comments(ep.episode_id).await
    } else {
        log::warn!(
            "[Danmaku] Episode {} (rel: {:?}) not found for subject {} (total: {} episodes)",
            episode_number,
            relative_episode,
            subject_id,
            episodes.len()
        );
        Ok(vec![])
    }
}

// ============================================================================
// 测试
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_url_path() {
        let url = "https://api.dandanplay.net/api/v2/search/anime?keyword=test";
        let path = extract_url_path(url);
        assert_eq!(path, Some("/api/v2/search/anime".to_string()));
    }

    #[tokio::test]
    async fn test_search_anime() {
        let result = danmaku_search_anime("葬送的芙莉莲".to_string()).await;
        assert!(result.is_ok());
        let animes = result.unwrap();
        assert!(!animes.is_empty());
        println!("Found {} anime(s)", animes.len());
    }

    #[tokio::test]
    async fn test_get_danmaku() {
        // 葬送的芙莉莲 第1话的 episode_id
        let result = danmaku_get_comments(176170001).await;
        assert!(result.is_ok());
        let danmakus = result.unwrap();
        assert!(!danmakus.is_empty());
        println!("Got {} danmaku comments", danmakus.len());
    }

    #[tokio::test]
    async fn test_get_bangumi_episodes() {
        // 【我推的孩子】 第三季 的 subject_id
        let result = danmaku_get_bangumi_episodes(517057).await;
        assert!(result.is_ok());
        let episodes = result.unwrap();
        assert!(!episodes.is_empty());
        println!("Found {} episodes", episodes.len());
        for ep in episodes.iter().take(3) {
            println!(
                "Episode {}: {} (ID: {})",
                ep.episode_number, ep.episode_title, ep.episode_id
            );
        }
    }

    #[tokio::test]
    async fn test_get_danmaku_by_bangumi_id() {
        // 【我推的孩子】 第三季 第1话
        let result = danmaku_get_by_bangumi_id(517057, "1".to_string(), Some(1)).await;
        assert!(result.is_ok());
        let danmakus = result.unwrap();
        assert!(!danmakus.is_empty());
        println!("Got {} danmaku comments for episode 1", danmakus.len());
    }
}
