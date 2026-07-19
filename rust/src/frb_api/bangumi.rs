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
) -> anyhow::Result<Vec<bangumi_impl::BangumiComment>> {
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
