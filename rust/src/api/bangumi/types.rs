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
pub struct BangumiComment {
    pub user_name: String,
    pub rate: Option<i32>,
    pub content: String,
    pub content_html: String,
    pub time: String,
    pub avatar: String,
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiEpisodeComment {
    pub id: i64,
    pub user_name: String,
    pub user_id: String,
    pub avatar: String,
    pub time: String,
    pub content_html: String,
    pub replies: Vec<BangumiEpisodeComment>,
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
//
// These three endpoints used to be fetched from Dart via `dart:io HttpClient`
// directly, which doesn't speak ECH. After enabling ECH for SNI cloaking we
// need bangumi traffic on the Rust side so it goes through the rustls+ECH
// client. The wire format returned here is the **canonical** bangumi JSON
// (with the unproxied host); callers on the Dart side apply URL rewriting
// afterwards via `BangumiUrlRewriter`.

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
///
/// `expires_in` is the token lifetime in seconds as returned by Bangumi
/// (typically 2592000 = 30 days). The Dart side turns this into an absolute
/// expiry timestamp for its proactive-refresh scheduling.
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

/// Stable error payload for authenticated Bangumi operations. The FRB facade
/// serializes this value into the error text so Dart can classify failures
/// without parsing upstream prose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiApiError {
    pub operation: String,
    pub status: u16,
    pub upstream_code: Option<String>,
    pub retry_after_seconds: Option<u64>,
    pub message: String,
}
