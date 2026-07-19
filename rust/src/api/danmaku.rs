// 弹幕 API 模块
// 集成 Dandanplay API 实现弹幕功能

use base64::{Engine, engine::general_purpose::STANDARD as BASE64};
use flutter_rust_bridge::frb;
use reqwest::header::{HeaderMap, HeaderValue};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

const DANDANPLAY_API_BASE_URL: &str = "https://api.dandanplay.net";

/// 从编译时环境变量读取 App ID (`DANDANPLAY_APP_ID`)
fn get_app_id() -> Result<String, String> {
    match option_env!("DANDANPLAY_APP_ID") {
        Some(v) if !v.is_empty() => Ok(v.to_string()),
        _ => Err("Environment variable DANDANPLAY_APP_ID not set during compilation".to_string()),
    }
}

/// 从编译时环境变量读取 App Secret (`DANDANPLAY_APP_SECRET`)
fn get_app_secret() -> Result<String, String> {
    match option_env!("DANDANPLAY_APP_SECRET") {
        Some(v) if !v.is_empty() => Ok(v.to_string()),
        _ => {
            Err("Environment variable DANDANPLAY_APP_SECRET not set during compilation".to_string())
        }
    }
}

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
    // count: i32,
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
fn generate_signature(
    url: &str,
    timestamp: i64,
    app_id: &str,
    app_secret: &str,
) -> Result<String, String> {
    let url_path = extract_url_path(url).ok_or("Invalid URL")?;

    // 拼接签名数据: AppId + Timestamp + UrlPath + AppSecret
    let data_to_hash = format!("{}{}{}{}", app_id, timestamp, url_path, app_secret);

    // SHA256 哈希
    let mut hasher = Sha256::new();
    hasher.update(data_to_hash.as_bytes());
    let hash = hasher.finalize();

    // Base64 编码
    Ok(BASE64.encode(hash))
}

/// 构建带签名的请求头
fn build_signed_headers(url: &str, app_id: &str, app_secret: &str) -> Result<HeaderMap, String> {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_secs() as i64;

    let signature = generate_signature(url, timestamp, app_id, app_secret)?;

    let mut headers = HeaderMap::new();
    headers.insert("Accept", HeaderValue::from_static("application/json"));
    headers.insert(
        "User-Agent",
        HeaderValue::from_static("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"),
    );
    headers.insert(
        "X-AppId",
        HeaderValue::from_str(app_id).map_err(|e| e.to_string())?,
    );
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

struct DanmakuApiClient {
    base_url: String,
    app_id: String,
    app_secret: String,
    direct_client: Option<reqwest::Client>,
}

impl DanmakuApiClient {
    fn production() -> Result<Self, String> {
        Ok(Self {
            base_url: DANDANPLAY_API_BASE_URL.to_string(),
            app_id: get_app_id()?,
            app_secret: get_app_secret()?,
            direct_client: None,
        })
    }

    #[cfg(test)]
    fn for_test(base_url: String) -> Self {
        Self {
            base_url,
            app_id: "fixture-app-id".to_string(),
            app_secret: "fixture-app-secret".to_string(),
            direct_client: Some(
                reqwest::Client::builder()
                    .no_proxy()
                    .build()
                    .expect("failed to build danmaku test client"),
            ),
        }
    }

    fn url(&self, path_and_query: &str) -> String {
        format!(
            "{}/{}",
            self.base_url.trim_end_matches('/'),
            path_and_query.trim_start_matches('/')
        )
    }

    fn signed_headers(&self, url: &str) -> Result<HeaderMap, String> {
        build_signed_headers(url, &self.app_id, &self.app_secret)
    }

    async fn send(
        &self,
        label: &str,
        request_fn: impl Fn(&reqwest::Client) -> reqwest::RequestBuilder,
    ) -> anyhow::Result<reqwest::Response> {
        if let Some(client) = &self.direct_client {
            return Ok(request_fn(client).send().await?);
        }

        crate::api::network::retry_request_with_status(label, request_fn, true).await
    }

    async fn search_anime(&self, keyword: String) -> Result<Vec<DanmakuAnime>, String> {
        let url = self.url(&format!(
            "/api/v2/search/anime?keyword={}",
            urlencoding::encode(&keyword)
        ));
        let headers = self.signed_headers(&url)?;
        let response = self
            .send("danmaku_search_anime", |client| {
                client.get(&url).headers(headers.clone())
            })
            .await
            .map_err(|e| format!("Request failed: {e}"))?;
        let status = response.status();
        let text = response.text().await.map_err(|e| e.to_string())?;

        if !status.is_success() {
            return Err(format!("API error {status}: {text}"));
        }

        let api_response: SearchResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Parse error: {e} - Response: {text}"))?;
        Ok(api_response
            .animes
            .into_iter()
            .map(|anime| DanmakuAnime {
                anime_id: anime.anime_id,
                anime_title: anime.anime_title,
                anime_type: anime.anime_type,
                type_description: anime.type_description,
                image_url: anime.image_url,
            })
            .collect())
    }

    async fn get_episodes(&self, anime_id: i64) -> Result<Vec<DanmakuEpisode>, String> {
        let url = self.url(&format!("/api/v2/bangumi/{anime_id}"));
        let headers = self.signed_headers(&url)?;
        let response = self
            .send("danmaku_get_episodes", |client| {
                client.get(&url).headers(headers.clone())
            })
            .await
            .map_err(|e| format!("Request failed: {e}"))?;
        let status = response.status();
        let text = response.text().await.map_err(|e| e.to_string())?;

        if !status.is_success() {
            return Err(format!("API error {status}: {text}"));
        }

        let api_response: BangumiResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Parse error: {e} - Response: {text}"))?;
        Ok(api_response
            .bangumi
            .episodes
            .into_iter()
            .map(|episode| DanmakuEpisode {
                episode_id: episode.episode_id,
                episode_title: episode.episode_title,
                episode_number: episode.episode_number,
            })
            .collect())
    }

    async fn get_bangumi_episodes(&self, subject_id: i64) -> Result<Vec<BangumiTvEpisode>, String> {
        let url = self.url(&format!("/api/v2/bangumi/bgmtv/{subject_id}"));
        let headers = self.signed_headers(&url)?;
        let response = self
            .send("danmaku_get_bangumi_episodes", |client| {
                client.get(&url).headers(headers.clone())
            })
            .await
            .map_err(|e| format!("Request failed: {e}"))?;
        let status = response.status();
        let text = response.text().await.map_err(|e| e.to_string())?;

        if !status.is_success() {
            return Err(format!("API error {status}: {text}"));
        }

        let api_response: BangumiTvResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Parse error: {e} - Response: {text}"))?;
        log::info!(
            "[Danmaku] Loaded {} episodes from Bangumi TV subject {}",
            api_response.bangumi.episodes.len(),
            subject_id
        );
        Ok(api_response
            .bangumi
            .episodes
            .into_iter()
            .map(|episode| BangumiTvEpisode {
                episode_id: episode.episode_id,
                episode_title: episode.episode_title,
                episode_number: episode.episode_number,
                air_date: episode.air_date,
            })
            .collect())
    }

    async fn get_comments(&self, episode_id: i64) -> Result<Vec<Danmaku>, String> {
        let url = self.url(&format!(
            "/api/v2/comment/{episode_id}?withRelated=true&chConvert=1"
        ));
        let headers = self.signed_headers(&url)?;
        let response = self
            .send("danmaku_get_comments", |client| {
                client.get(&url).headers(headers.clone())
            })
            .await
            .map_err(|e| format!("Request failed: {e}"))?;
        let status = response.status();
        let text = response.text().await.map_err(|e| e.to_string())?;

        if !status.is_success() {
            return Err(format!("API error {status}: {text}"));
        }

        let api_response: DanmakuResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Parse error: {e} - Response: {text}"))?;
        let mut danmakus: Vec<Danmaku> = api_response
            .comments
            .iter()
            .filter_map(parse_danmaku_comment)
            .collect();
        danmakus.sort_by(|left, right| {
            left.time
                .partial_cmp(&right.time)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        log::info!(
            "[Danmaku] Loaded {} comments for episode {}",
            danmakus.len(),
            episode_id
        );
        Ok(danmakus)
    }

    async fn match_anime(
        &self,
        file_name: String,
        file_hash: Option<String>,
    ) -> Result<Vec<DanmakuMatch>, String> {
        let url = self.url("/api/v2/match");
        let headers = self.signed_headers(&url)?;
        let body = serde_json::json!({
            "fileName": file_name,
            "fileHash": file_hash.unwrap_or_default(),
            "matchMode": "hashAndFileName"
        });
        let response = self
            .send("danmaku_match_anime", |client| {
                client
                    .post(&url)
                    .headers(headers.clone())
                    .header("Content-Type", "application/json")
                    .body(body.to_string())
            })
            .await
            .map_err(|e| format!("Request failed: {e}"))?;
        let status = response.status();
        let text = response.text().await.map_err(|e| e.to_string())?;

        if !status.is_success() {
            return Err(format!("API error {status}: {text}"));
        }

        let api_response: MatchResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Parse error: {e} - Response: {text}"))?;
        log::info!(
            "[Danmaku] Match result for '{}': is_matched={}, matches={}",
            file_name,
            api_response.is_matched,
            api_response.matches.len()
        );
        Ok(api_response
            .matches
            .into_iter()
            .map(|match_result| DanmakuMatch {
                episode_id: match_result.episode_id,
                anime_id: match_result.anime_id,
                anime_title: match_result.anime_title,
                episode_title: match_result.episode_title,
            })
            .collect())
    }

    async fn get_by_title(
        &self,
        anime_title: String,
        episode_number: String,
        relative_episode: Option<i32>,
    ) -> Result<Vec<Danmaku>, String> {
        let animes = self.search_anime(anime_title.clone()).await?;
        if animes.is_empty() {
            log::warn!("[Danmaku] No anime found for title: {anime_title}");
            return Ok(vec![]);
        }

        let anime = &animes[0];
        let episodes = self.get_episodes(anime.anime_id).await?;
        let mut episode = episodes.iter().find(|episode| {
            episode
                .episode_number
                .as_ref()
                .map(|number| number == &episode_number)
                .unwrap_or(false)
        });
        if episode.is_none()
            && let Some(index) = relative_episode_index(relative_episode)
            && index < episodes.len()
        {
            log::info!(
                "[Danmaku] Episode {} not found by number for '{}', using relative episode {}",
                episode_number,
                anime_title,
                index + 1
            );
            episode = Some(&episodes[index]);
        }

        if let Some(episode) = episode {
            log::info!(
                "[Danmaku] Loading comments for '{}' - {} (ID: {})",
                anime.anime_title,
                episode.episode_title,
                episode.episode_id
            );
            self.get_comments(episode.episode_id).await
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

    async fn get_by_bangumi_id(
        &self,
        subject_id: i64,
        episode_number: String,
        relative_episode: Option<i32>,
    ) -> Result<Vec<Danmaku>, String> {
        let episodes = self.get_bangumi_episodes(subject_id).await?;
        if episodes.is_empty() {
            log::warn!("[Danmaku] No episodes found for Bangumi TV subject: {subject_id}");
            return Ok(vec![]);
        }

        let mut episode = episodes
            .iter()
            .find(|episode| episode.episode_number == episode_number);
        if episode.is_none()
            && let Some(index) = relative_episode_index(relative_episode)
            && index < episodes.len()
        {
            log::info!(
                "[Danmaku] Episode {} not found by number for subject {}, using relative episode {}",
                episode_number,
                subject_id,
                index + 1
            );
            episode = Some(&episodes[index]);
        }

        if let Some(episode) = episode {
            log::info!(
                "[Danmaku] Found episode: {} (ID: {}) for subject {} ep {} (rel: {:?})",
                episode.episode_title,
                episode.episode_id,
                subject_id,
                episode_number,
                relative_episode
            );
            self.get_comments(episode.episode_id).await
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
}

fn relative_episode_index(relative_episode: Option<i32>) -> Option<usize> {
    relative_episode?
        .checked_sub(1)
        .and_then(|index| usize::try_from(index).ok())
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
    DanmakuApiClient::production()?.search_anime(keyword).await
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
    DanmakuApiClient::production()?.get_episodes(anime_id).await
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
    DanmakuApiClient::production()?
        .get_bangumi_episodes(subject_id)
        .await
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
    DanmakuApiClient::production()?
        .get_comments(episode_id)
        .await
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
    DanmakuApiClient::production()?
        .match_anime(file_name, file_hash)
        .await
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
    DanmakuApiClient::production()?
        .get_by_title(anime_title, episode_number, relative_episode)
        .await
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
    DanmakuApiClient::production()?
        .get_by_bangumi_id(subject_id, episode_number, relative_episode)
        .await
}

// ============================================================================
// 测试
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use axum::http::{Method, StatusCode};

    #[test]
    fn extracts_signature_path_without_query() {
        let url = "https://api.dandanplay.net/api/v2/search/anime?keyword=test";
        let path = extract_url_path(url);
        assert_eq!(path, Some("/api/v2/search/anime".to_string()));
    }

    #[tokio::test]
    async fn search_anime_uses_signed_local_request_and_parses_fixture() {
        let server = TestServer::spawn([TestRoute::get(
            "/api/v2/search/anime",
            TestResponse::fixture("danmaku/search_anime.json")
                .with_header("content-type", "application/json"),
        )])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let animes = api.search_anime("测试 动画".to_string()).await.unwrap();

        assert_eq!(animes.len(), 1);
        assert_eq!(animes[0].anime_id, 42);
        assert_eq!(animes[0].anime_title, "Fixture Anime / 测试动画");
        assert_eq!(animes[0].anime_type, "tvseries");
        assert_eq!(animes[0].type_description.as_deref(), Some("TV"));
        let requests = server.requests();
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0].method, Method::GET);
        assert_eq!(
            requests[0].uri.query(),
            Some("keyword=%E6%B5%8B%E8%AF%95%20%E5%8A%A8%E7%94%BB")
        );
        assert_eq!(requests[0].headers["x-appid"], "fixture-app-id");
        assert!(!requests[0].headers["x-signature"].is_empty());
        assert!(!requests[0].headers["x-timestamp"].is_empty());

        server.shutdown().await;
    }

    #[tokio::test]
    async fn get_comments_filters_invalid_rows_applies_defaults_and_sorts() {
        let server = TestServer::spawn([TestRoute::get(
            "/api/v2/comment/42001",
            TestResponse::fixture("danmaku/comments.json"),
        )])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let comments = api.get_comments(42001).await.unwrap();

        assert_eq!(comments.len(), 3);
        assert_eq!(comments[0].time, 1.25);
        assert_eq!(comments[0].danmaku_type, 5);
        assert_eq!(comments[0].color, 65280);
        assert_eq!(comments[1].time, 7.0);
        assert_eq!(comments[1].danmaku_type, 1);
        assert_eq!(comments[1].color, 0xFFFFFF);
        assert_eq!(comments[2].time, 12.5);
        assert_eq!(
            server.requests()[0].uri.query(),
            Some("withRelated=true&chConvert=1")
        );

        server.shutdown().await;
    }

    #[tokio::test]
    async fn get_bangumi_episodes_parses_fixture_without_network() {
        let server = TestServer::spawn([TestRoute::get(
            "/api/v2/bangumi/bgmtv/517057",
            TestResponse::fixture("danmaku/bangumi_tv.json"),
        )])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let episodes = api.get_bangumi_episodes(517057).await.unwrap();

        assert_eq!(episodes.len(), 2);
        assert_eq!(episodes[0].episode_id, 42001);
        assert_eq!(episodes[0].episode_number, "1");
        assert_eq!(episodes[0].air_date.as_deref(), Some("2026-07-19"));
        assert_eq!(episodes[1].episode_number, "SP1");
        assert_eq!(episodes[1].air_date, None);

        server.shutdown().await;
    }

    #[tokio::test]
    async fn get_by_bangumi_id_runs_the_full_flow_against_loopback() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/api/v2/bangumi/bgmtv/517057",
                TestResponse::fixture("danmaku/bangumi_tv.json"),
            ),
            TestRoute::get(
                "/api/v2/comment/42001",
                TestResponse::fixture("danmaku/comments.json"),
            ),
        ])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let comments = api
            .get_by_bangumi_id(517057, "missing".to_string(), Some(1))
            .await
            .unwrap();

        assert_eq!(comments.len(), 3);
        assert_eq!(
            server.request_count(Method::GET, "/api/v2/bangumi/bgmtv/517057"),
            1
        );
        assert_eq!(
            server.request_count(Method::GET, "/api/v2/comment/42001"),
            1
        );

        server.shutdown().await;
    }

    #[tokio::test]
    async fn title_flow_and_match_request_use_the_same_local_client() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/api/v2/search/anime",
                TestResponse::fixture("danmaku/search_anime.json"),
            ),
            TestRoute::get(
                "/api/v2/bangumi/42",
                TestResponse::fixture("danmaku/bangumi.json"),
            ),
            TestRoute::get(
                "/api/v2/comment/42002",
                TestResponse::fixture("danmaku/comments.json"),
            ),
            TestRoute::post("/api/v2/match", TestResponse::fixture("danmaku/match.json")),
        ])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let comments = api
            .get_by_title("测试动画".to_string(), "SP1".to_string(), None)
            .await
            .unwrap();
        assert_eq!(comments.len(), 3);

        let matches = api
            .match_anime("Fixture Anime - 01.mkv".to_string(), None)
            .await
            .unwrap();
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].episode_id, 42001);
        let match_request = server
            .requests()
            .into_iter()
            .find(|request| request.uri.path() == "/api/v2/match")
            .unwrap();
        let body: serde_json::Value = serde_json::from_slice(&match_request.body).unwrap();
        assert_eq!(body["fileName"], "Fixture Anime - 01.mkv");
        assert_eq!(body["fileHash"], "");
        assert_eq!(body["matchMode"], "hashAndFileName");

        server.shutdown().await;
    }

    #[tokio::test]
    async fn api_errors_preserve_status_and_response_body() {
        let server = TestServer::spawn([TestRoute::get(
            "/api/v2/search/anime",
            TestResponse::new(StatusCode::TOO_MANY_REQUESTS, r#"{"error":"rate limited"}"#),
        )])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let error = api.search_anime("fixture".to_string()).await.unwrap_err();

        assert!(error.contains("429 Too Many Requests"));
        assert!(error.contains("rate limited"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn invalid_relative_episode_never_underflows_or_fetches_comments() {
        let server = TestServer::spawn([TestRoute::get(
            "/api/v2/bangumi/bgmtv/517057",
            TestResponse::fixture("danmaku/bangumi_tv.json"),
        )])
        .await;
        let api = DanmakuApiClient::for_test(server.base_url());

        let comments = api
            .get_by_bangumi_id(517057, "missing".to_string(), Some(i32::MIN))
            .await
            .unwrap();

        assert!(comments.is_empty());
        assert_eq!(server.requests().len(), 1);
        server.shutdown().await;
    }

    /// Explicit live-network smoke test. It requires compile-time Dandanplay
    /// credentials and is intentionally excluded from the default test suite.
    #[tokio::test]
    #[ignore = "requires live network and DANDANPLAY_APP_ID/APP_SECRET at compile time"]
    async fn live_danmaku_api_smoke() {
        let comments = danmaku_get_by_bangumi_id(517057, "1".to_string(), Some(1))
            .await
            .expect("live Dandanplay request failed");
        assert!(!comments.is_empty());
    }
}
