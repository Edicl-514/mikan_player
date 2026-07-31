use serde::{Deserialize, Serialize};

// Struct definitions matching the generated bridge code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiEpisode {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub description: String,
    pub airdate: String,
    pub duration: String,
    pub sort: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiCharacter {
    pub id: i64,
    pub name: String,
    pub role_name: String,
    pub images: Option<BangumiImages>,
    pub actors: Vec<BangumiActor>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiActor {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiImages {
    pub small: String,
    pub grid: String,
    pub large: String,
    pub medium: String,
    pub common: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiRelatedSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub relation: String,
    pub image: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiCommentReaction {
    pub name: String,
    pub image_url: String,
    pub count: i32,
    pub reacted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiCommentsPage {
    pub comments: Vec<BangumiComment>,
    pub total: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiComment {
    pub id: i64,
    pub user_id: String,
    pub user_name: String,
    /// 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃.
    pub collection_type: Option<i32>,
    pub rate: Option<i32>,
    pub content: String,
    pub content_html: String,
    pub time: String,
    pub avatar: String,
    pub reactions: Vec<BangumiCommentReaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiReview {
    pub id: i64,
    pub entry_id: i64,
    pub user_id: String,
    pub user_name: String,
    pub avatar: String,
    pub title: String,
    pub summary: String,
    pub time: String,
    pub replies_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiReviewsPage {
    pub reviews: Vec<BangumiReview>,
    pub total: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiBlogDetail {
    pub id: i64,
    pub title: String,
    pub summary: String,
    pub content: String,
    pub content_html: String,
    pub user_id: String,
    pub user_name: String,
    pub avatar: String,
    pub time: String,
    pub replies_count: i32,
    pub tags: Vec<String>,
    pub reactions: Vec<BangumiCommentReaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiTopic {
    pub id: i64,
    pub user_id: String,
    pub user_name: String,
    pub avatar: String,
    pub title: String,
    pub time: String,
    pub updated_at: String,
    pub replies_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiTopicsPage {
    pub topics: Vec<BangumiTopic>,
    pub total: Option<i32>,
    /// Rows upstream actually returned for this page, before moderation
    /// filtering. Pagination must advance on this, not on `topics.len()`, or a
    /// page whose every row was filtered out would look like the end of the list.
    pub fetched_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiTopicDetail {
    pub id: i64,
    pub title: String,
    pub user_id: String,
    pub user_name: String,
    pub avatar: String,
    pub time: String,
    pub updated_at: String,
    pub replies_count: i32,
    pub content: String,
    pub content_html: String,
    /// Moderation state of the opening post, using p1's *comment* state enum.
    /// Distinct from the topic's own state: an admin-closed topic (topic state
    /// `1`) still shows its body, while a deleted post (comment state `6`/`7`)
    /// must not.
    pub content_state: i32,
    pub reactions: Vec<BangumiCommentReaction>,
    pub replies: Vec<BangumiEpisodeComment>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiPerson {
    pub id: i64,
    pub name: String,
    pub relation: String,
    pub career: Vec<String>,
    pub person_type: i32,
    pub images: Option<BangumiImages>,
}

/// Compact role returned by `POST /p1/search/characters`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiCharacterSearchResult {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub role: i32,
    pub info: String,
    pub images: Option<BangumiImages>,
}

/// Compact person returned by `POST /p1/search/persons`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiPersonSearchResult {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub person_type: i32,
    pub info: String,
    pub career: Vec<String>,
    pub images: Option<BangumiImages>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiEpisodeComment {
    pub id: i64,
    pub user_name: String,
    pub user_id: String,
    pub avatar: String,
    pub time: String,
    pub state: i32,
    pub content_html: String,
    pub replies: Vec<BangumiEpisodeComment>,
    pub reactions: Vec<BangumiCommentReaction>,
}

// ============================================================================
// Character Detail API
// ============================================================================

/// Character details info from /v0/characters/{character_id}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterDetails {
    pub id: i64,
    pub name: String,
    pub summary: String,
    pub images: Option<BangumiImages>,
    pub gender: Option<String>,
    pub birth_year: Option<i32>,
    pub birth_mon: Option<i32>,
    pub birth_day: Option<i32>,
    pub blood_type: Option<String>,
    pub stat: CharacterStat,
    pub infobox: Vec<InfoboxItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterStat {
    pub comments: i32,
    pub collects: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InfoboxItem {
    pub key: String,
    pub value: String,
}

/// Character subject info from /v0/characters/{character_id}/subjects
/// Only includes anime (type=2)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub image: String,
    pub staff: String,                        // 主角/配角/客串
    pub persons: Vec<CharacterSubjectPerson>, // Associated voice actors
}

/// Voice actor info associated with a specific subject
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterSubjectPerson {
    pub id: i64,
    pub name: String,
    pub images: Option<BangumiImages>,
}

// ============================================================================
// Person Detail API
// ============================================================================

/// Person details from /v0/persons/{person_id}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonDetails {
    pub id: i64,
    pub name: String,
    pub summary: String,
    pub img: String,
    pub career: Vec<String>,
    pub person_type: i32,
    pub stat: CharacterStat,
    pub infobox: Vec<InfoboxItem>,
    pub locked: bool,
}

/// Subject info from /v0/persons/{person_id}/subjects (only type=2 anime)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub image: String,
    pub staff: String,
    pub eps: String,
}

/// Character info from /v0/persons/{person_id}/characters (only subject_type=2)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonCharacter {
    pub id: i64,
    pub name: String,
    pub images: Option<BangumiImages>,
    pub subject_id: i64,
    pub subject_name: String,
    pub subject_name_cn: String,
    pub staff: String,
}

// ============================================================================
// User & Auth APIs
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiUserInfo {
    pub id: i64,
    pub username: String,
    pub nickname: String,
    pub sign: Option<String>,
    pub url: Option<String>,
    pub avatar_large: Option<String>,
    pub avatar_medium: Option<String>,
    pub avatar_small: Option<String>,
}

/// Result of an OAuth token exchange (authorization code → tokens) or a
/// refresh. Mirrors the JSON returned by `POST /oauth/access_token`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiOAuthToken {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_in: i64,
    pub user_id: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiUserCollectionEntry {
    pub updated_at: String,
    pub comment: String,
    pub tags: Vec<String>,
    pub subject_id: i64,
    /// 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃
    pub collection_type: i32,
    pub rate: i32,
    pub private: bool,
    pub subject_name: String,
    pub subject_name_cn: String,
    pub subject_short_summary: String,
    pub subject_score: f64,
    pub subject_eps: i32,
    pub subject_collection_total: i32,
    pub image_small: String,
    pub image_grid: String,
    pub image_large: String,
    pub image_medium: String,
    pub image_common: String,
}

/// Stable error payload for authenticated Bangumi operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiApiError {
    pub operation: String,
    pub status: u16,
    pub upstream_code: Option<String>,
    pub retry_after_seconds: Option<u64>,
    pub message: String,
}
