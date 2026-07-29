use crate::api::bangumi as bangumi_impl;
use crate::frb_api::contract;

pub async fn fetch_bangumi_episodes(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisode>> {
    const API: &str = "fetch_bangumi_episodes";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_episodes(subject_id).await)
}

pub async fn fetch_bangumi_characters(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiCharacter>> {
    const API: &str = "fetch_bangumi_characters";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_characters(subject_id).await,
    )
}

pub async fn fetch_bangumi_relations(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiRelatedSubject>> {
    const API: &str = "fetch_bangumi_relations";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_relations(subject_id).await)
}

pub async fn fetch_bangumi_comments(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<bangumi_impl::BangumiCommentsPage> {
    const API: &str = "fetch_bangumi_comments";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, contract::require_i32_range("page", page, 1, i32::MAX))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_comments(subject_id, page).await,
    )
}

pub async fn fetch_bangumi_persons(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiPerson>> {
    const API: &str = "fetch_bangumi_persons";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_persons(subject_id).await)
}

pub async fn fetch_bangumi_episode_comments(
    episode_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisodeComment>> {
    const API: &str = "fetch_bangumi_episode_comments";
    contract::public_result(
        API,
        contract::require_positive_i64("episode_id", episode_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_episode_comments(episode_id).await,
    )
}

pub async fn fetch_bangumi_subject_reviews(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<bangumi_impl::BangumiReviewsPage> {
    const API: &str = "fetch_bangumi_subject_reviews";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, contract::require_i32_range("page", page, 1, i32::MAX))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_subject_reviews(subject_id, page).await,
    )
}

pub async fn fetch_bangumi_blog_detail(
    entry_id: i64,
) -> anyhow::Result<bangumi_impl::BangumiBlogDetail> {
    const API: &str = "fetch_bangumi_blog_detail";
    contract::public_result(API, contract::require_positive_i64("entry_id", entry_id))?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_blog_detail(entry_id).await)
}

pub async fn fetch_bangumi_blog_comments(
    entry_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisodeComment>> {
    const API: &str = "fetch_bangumi_blog_comments";
    contract::public_result(API, contract::require_positive_i64("entry_id", entry_id))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_blog_comments(entry_id).await,
    )
}

pub async fn fetch_bangumi_subject_topics(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<bangumi_impl::BangumiTopicsPage> {
    const API: &str = "fetch_bangumi_subject_topics";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, contract::require_i32_range("page", page, 1, i32::MAX))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_subject_topics(subject_id, page).await,
    )
}

pub async fn fetch_bangumi_topic_detail(
    topic_id: i64,
) -> anyhow::Result<bangumi_impl::BangumiTopicDetail> {
    const API: &str = "fetch_bangumi_topic_detail";
    contract::public_result(API, contract::require_positive_i64("topic_id", topic_id))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_topic_detail(topic_id).await,
    )
}

pub async fn fetch_character_details(
    character_id: i64,
) -> anyhow::Result<bangumi_impl::CharacterDetails> {
    const API: &str = "fetch_character_details";
    contract::public_result(
        API,
        contract::require_positive_i64("character_id", character_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_character_details(character_id).await,
    )
}

pub async fn fetch_person_details(person_id: i64) -> anyhow::Result<bangumi_impl::PersonDetails> {
    const API: &str = "fetch_person_details";
    contract::public_result(API, contract::require_positive_i64("person_id", person_id))?;
    contract::public_result(API, bangumi_impl::fetch_person_details(person_id).await)
}

pub async fn fetch_person_subjects(
    person_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::PersonSubject>> {
    const API: &str = "fetch_person_subjects";
    contract::public_result(API, contract::require_positive_i64("person_id", person_id))?;
    contract::public_result(API, bangumi_impl::fetch_person_subjects(person_id).await)
}

pub async fn fetch_person_characters(
    person_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::PersonCharacter>> {
    const API: &str = "fetch_person_characters";
    contract::public_result(API, contract::require_positive_i64("person_id", person_id))?;
    contract::public_result(API, bangumi_impl::fetch_person_characters(person_id).await)
}

pub async fn fetch_character_subjects(
    character_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::CharacterSubject>> {
    const API: &str = "fetch_character_subjects";
    contract::public_result(
        API,
        contract::require_positive_i64("character_id", character_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_character_subjects(character_id).await,
    )
}

pub async fn fetch_bangumi_character_comments(
    character_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisodeComment>> {
    const API: &str = "fetch_bangumi_character_comments";
    contract::public_result(
        API,
        contract::require_positive_i64("character_id", character_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_character_comments(character_id).await,
    )
}

pub async fn fetch_bangumi_person_comments(
    person_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisodeComment>> {
    const API: &str = "fetch_bangumi_person_comments";
    contract::public_result(API, contract::require_positive_i64("person_id", person_id))?;
    contract::public_result(API, bangumi_impl::fetch_person_comments(person_id).await)
}

pub async fn fetch_bangumi_user_info(
    username: String,
) -> anyhow::Result<bangumi_impl::BangumiUserInfo> {
    const API: &str = "fetch_bangumi_user_info";
    contract::public_result(API, contract::require_non_blank("username", &username))?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_user_info(username).await)
}

pub async fn fetch_bangumi_user_collections(
    username: String,
    subject_type: i32,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<bangumi_impl::BangumiUserCollectionEntry>> {
    const API: &str = "fetch_bangumi_user_collections";
    contract::public_result(API, contract::require_non_blank("username", &username))?;
    contract::public_result(
        API,
        if matches!(subject_type, 1 | 2 | 3 | 4 | 6) {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "invalid argument `subject_type`: must be one of: 1, 2, 3, 4, 6"
            ))
        },
    )?;
    contract::public_result(API, contract::require_i32_range("limit", limit, 1, 100))?;
    contract::public_result(API, contract::require_non_negative_i32("offset", offset))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_user_collections(username, subject_type, limit, offset).await,
    )
}

pub async fn fetch_bangumi_subject_image(
    subject_id: i64,
    image_type: String,
) -> anyhow::Result<Vec<u8>> {
    const API: &str = "fetch_bangumi_subject_image";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        contract::require_one_of(
            "image_type",
            &image_type,
            &["small", "grid", "large", "medium", "common"],
        ),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_bangumi_subject_image(subject_id, image_type).await,
    )
}

pub async fn fetch_bangumi_image_url(url: String) -> anyhow::Result<Vec<u8>> {
    const API: &str = "fetch_bangumi_image_url";
    contract::public_result(API, contract::require_non_blank("url", &url))?;
    contract::public_result(API, bangumi_impl::fetch_bangumi_image_url(url).await)
}

/// The OAuth `client_id` for building the authorization URL that the login
/// WebView opens. Not a secret — it appears in that URL in plaintext.
pub fn bangumi_oauth_client_id() -> anyhow::Result<String> {
    const API: &str = "bangumi_oauth_client_id";
    contract::public_result(API, bangumi_impl::bangumi_oauth_client_id())
}

/// The OAuth authorization page URL the login WebView opens. Pins `bgm.tv`
/// (never an alias or the optional content reverse proxy). `redirect_uri` must
/// match the value later passed to [`exchange_bangumi_oauth_code`]
/// byte-for-byte.
pub fn bangumi_oauth_authorize_url(redirect_uri: String) -> anyhow::Result<String> {
    const API: &str = "bangumi_oauth_authorize_url";
    contract::public_result(
        API,
        contract::require_non_blank("redirect_uri", &redirect_uri),
    )?;
    contract::public_result(API, bangumi_impl::bangumi_oauth_authorize_url(redirect_uri))
}

/// Exchange an OAuth authorization `code` for an access/refresh token pair.
/// The `client_secret` stays on the Rust side of the bridge, but remains
/// extractable from a distributed client binary.
pub async fn exchange_bangumi_oauth_code(
    code: String,
    redirect_uri: String,
) -> anyhow::Result<bangumi_impl::BangumiOAuthToken> {
    const API: &str = "exchange_bangumi_oauth_code";
    contract::public_result(API, contract::require_non_blank("code", &code))?;
    contract::public_result(
        API,
        contract::require_non_blank("redirect_uri", &redirect_uri),
    )?;
    contract::public_result(
        API,
        bangumi_impl::exchange_bangumi_oauth_code(code, redirect_uri).await,
    )
}

/// Refresh an access token using the stored `refresh_token`.
pub async fn refresh_bangumi_oauth_token(
    refresh_token: String,
    redirect_uri: String,
) -> anyhow::Result<bangumi_impl::BangumiOAuthToken> {
    const API: &str = "refresh_bangumi_oauth_token";
    contract::public_result(
        API,
        contract::require_non_blank("refresh_token", &refresh_token),
    )?;
    contract::public_result(
        API,
        contract::require_non_blank("redirect_uri", &redirect_uri),
    )?;
    contract::public_result(
        API,
        bangumi_impl::refresh_bangumi_oauth_token(refresh_token, redirect_uri).await,
    )
}

/// `GET /v0/me` — the authenticated user's profile. Requires a stored token.
pub async fn fetch_bangumi_me() -> anyhow::Result<bangumi_impl::BangumiUserInfo> {
    const API: &str = "fetch_bangumi_me";
    contract::public_result(API, bangumi_impl::fetch_bangumi_me().await)
}

/// `GET /v0/users/{username}/collections` — the authenticated user's own
/// collections. `collection_type` of `0` means "all types" (no filter).
///
/// Requires the real `username` (from `/v0/me`): the list endpoint returns 404
/// for the literal `-` alias, unlike the write endpoint. The bearer token is
/// still sent so private collections are included.
pub async fn fetch_my_bangumi_collections(
    username: String,
    subject_type: i32,
    collection_type: i32,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<bangumi_impl::BangumiUserCollectionEntry>> {
    const API: &str = "fetch_my_bangumi_collections";
    contract::public_result(API, contract::require_non_blank("username", &username))?;
    contract::public_result(
        API,
        if matches!(subject_type, 1 | 2 | 3 | 4 | 6) {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "invalid argument `subject_type`: must be one of: 1, 2, 3, 4, 6"
            ))
        },
    )?;
    contract::public_result(
        API,
        if matches!(collection_type, 0 | 1 | 2 | 3 | 4 | 5) {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "invalid argument `collection_type`: must be one of: 0, 1, 2, 3, 4, 5"
            ))
        },
    )?;
    contract::public_result(API, contract::require_i32_range("limit", limit, 1, 100))?;
    contract::public_result(API, contract::require_non_negative_i32("offset", offset))?;
    let type_filter = if collection_type == 0 {
        None
    } else {
        Some(collection_type)
    };
    contract::public_result(
        API,
        bangumi_impl::fetch_my_bangumi_collections(
            username,
            subject_type,
            type_filter,
            limit,
            offset,
        )
        .await,
    )
}

/// `POST /v0/users/-/collections/{subject_id}` — upsert the authenticated
/// user's collection for a subject. Optional fields left `None` are omitted
/// from the request so an existing rating/comment is not clobbered.
pub async fn update_bangumi_collection(
    subject_id: i64,
    collection_type: i32,
    rate: Option<i32>,
    comment: Option<String>,
    tags: Option<Vec<String>>,
    private: Option<bool>,
) -> anyhow::Result<()> {
    const API: &str = "update_bangumi_collection";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        if matches!(collection_type, 1 | 2 | 3 | 4 | 5) {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "invalid argument `collection_type`: must be one of: 1, 2, 3, 4, 5"
            ))
        },
    )?;
    if let Some(rate) = rate {
        contract::public_result(API, contract::require_i32_range("rate", rate, 0, 10))?;
    }
    contract::public_result(
        API,
        bangumi_impl::update_bangumi_collection(
            subject_id,
            collection_type,
            rate,
            comment,
            private,
            tags,
        )
        .await,
    )
}

/// Set or change only the collection status using the idempotent POST path.
pub async fn set_bangumi_collection_status(
    subject_id: i64,
    collection_type: i32,
) -> anyhow::Result<()> {
    const API: &str = "set_bangumi_collection_status";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        if matches!(collection_type, 1 | 2 | 3 | 4 | 5) {
            Ok(())
        } else {
            Err(anyhow::anyhow!(
                "invalid argument `collection_type`: must be one of: 1, 2, 3, 4, 5"
            ))
        },
    )?;
    contract::public_result(
        API,
        bangumi_impl::set_bangumi_collection_status(subject_id, collection_type).await,
    )
}

/// Read one authenticated collection. Returns `None` when uncollected.
pub async fn fetch_my_bangumi_collection(
    username: String,
    subject_id: i64,
) -> anyhow::Result<Option<bangumi_impl::BangumiUserCollectionEntry>> {
    const API: &str = "fetch_my_bangumi_collection";
    contract::public_result(API, contract::require_non_blank("username", &username))?;
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::fetch_my_bangumi_collection(username, subject_id).await,
    )
}

/// Read only the collection type for compatibility with existing callers.
pub async fn fetch_my_bangumi_collection_type(
    username: String,
    subject_id: i64,
) -> anyhow::Result<Option<i32>> {
    const API: &str = "fetch_my_bangumi_collection_type";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(API, contract::require_non_blank("username", &username))?;
    contract::public_result(
        API,
        bangumi_impl::fetch_my_bangumi_collection_type(username, subject_id).await,
    )
}

/// Patch only collection metadata. `None` omits a field; an empty tag list
/// clears all tags. `type` is intentionally not part of this request.
pub async fn patch_bangumi_collection_metadata(
    subject_id: i64,
    rate: Option<i32>,
    comment: Option<String>,
    tags: Option<Vec<String>>,
    private: Option<bool>,
) -> anyhow::Result<()> {
    const API: &str = "patch_bangumi_collection_metadata";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    if let Some(rate) = rate {
        contract::public_result(API, contract::require_i32_range("rate", rate, 0, 10))?;
    }
    contract::public_result(
        API,
        bangumi_impl::patch_bangumi_collection_metadata(subject_id, rate, comment, private, tags)
            .await,
    )
}

/// `DELETE /v0/users/-/collections/{subject_id}` — remove the authenticated
/// user's collection entry for a subject.
pub async fn delete_bangumi_collection(subject_id: i64) -> anyhow::Result<()> {
    const API: &str = "delete_bangumi_collection";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        bangumi_impl::delete_bangumi_collection(subject_id).await,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn invalid_facade_arguments_fail_before_backend_work() {
        assert_eq!(
            fetch_bangumi_episodes(0).await.unwrap_err().to_string(),
            "fetch_bangumi_episodes: invalid argument `subject_id`: must be greater than zero"
        );
        assert_eq!(
            fetch_bangumi_comments(1, 0).await.unwrap_err().to_string(),
            "fetch_bangumi_comments: invalid argument `page`: must be between 1 and 2147483647"
        );
        assert_eq!(
            fetch_bangumi_user_info("  ".to_string())
                .await
                .unwrap_err()
                .to_string(),
            "fetch_bangumi_user_info: invalid argument `username`: must not be blank"
        );
        assert_eq!(
            fetch_bangumi_user_collections("user".to_string(), 5, 20, 0)
                .await
                .unwrap_err()
                .to_string(),
            "fetch_bangumi_user_collections: invalid argument `subject_type`: must be one of: 1, 2, 3, 4, 6"
        );
        assert_eq!(
            fetch_bangumi_subject_image(1, "original".to_string())
                .await
                .unwrap_err()
                .to_string(),
            "fetch_bangumi_subject_image: invalid argument `image_type`: must be one of: small, grid, large, medium, common"
        );
    }
}
