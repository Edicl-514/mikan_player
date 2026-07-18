use crate::api::bangumi as bangumi_impl;

pub async fn fetch_bangumi_episodes(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisode>> {
    bangumi_impl::fetch_bangumi_episodes(subject_id).await
}

pub async fn fetch_bangumi_characters(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiCharacter>> {
    bangumi_impl::fetch_bangumi_characters(subject_id).await
}

pub async fn fetch_bangumi_relations(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiRelatedSubject>> {
    bangumi_impl::fetch_bangumi_relations(subject_id).await
}

pub async fn fetch_bangumi_comments(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<bangumi_impl::BangumiComment>> {
    bangumi_impl::fetch_bangumi_comments(subject_id, page).await
}

pub async fn fetch_bangumi_persons(
    subject_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiPerson>> {
    bangumi_impl::fetch_bangumi_persons(subject_id).await
}

pub async fn fetch_bangumi_episode_comments(
    episode_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::BangumiEpisodeComment>> {
    bangumi_impl::fetch_bangumi_episode_comments(episode_id).await
}

pub async fn fetch_character_details(
    character_id: i64,
) -> anyhow::Result<bangumi_impl::CharacterDetails> {
    bangumi_impl::fetch_character_details(character_id).await
}

pub async fn fetch_person_details(person_id: i64) -> anyhow::Result<bangumi_impl::PersonDetails> {
    bangumi_impl::fetch_person_details(person_id).await
}

pub async fn fetch_person_subjects(
    person_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::PersonSubject>> {
    bangumi_impl::fetch_person_subjects(person_id).await
}

pub async fn fetch_person_characters(
    person_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::PersonCharacter>> {
    bangumi_impl::fetch_person_characters(person_id).await
}

pub async fn fetch_character_subjects(
    character_id: i64,
) -> anyhow::Result<Vec<bangumi_impl::CharacterSubject>> {
    bangumi_impl::fetch_character_subjects(character_id).await
}

pub async fn fetch_bangumi_user_info(
    username: String,
) -> anyhow::Result<bangumi_impl::BangumiUserInfo> {
    bangumi_impl::fetch_bangumi_user_info(username).await
}

pub async fn fetch_bangumi_user_collections(
    username: String,
    subject_type: i32,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<bangumi_impl::BangumiUserCollectionEntry>> {
    bangumi_impl::fetch_bangumi_user_collections(username, subject_type, limit, offset).await
}

pub async fn fetch_bangumi_subject_image(
    subject_id: i64,
    image_type: String,
) -> anyhow::Result<Vec<u8>> {
    bangumi_impl::fetch_bangumi_subject_image(subject_id, image_type).await
}

pub async fn fetch_bangumi_image_url(url: String) -> anyhow::Result<Vec<u8>> {
    bangumi_impl::fetch_bangumi_image_url(url).await
}
