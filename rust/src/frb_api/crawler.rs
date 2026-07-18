use crate::api::crawler as crawler_impl;

pub async fn fetch_archive_list() -> anyhow::Result<Vec<crawler_impl::ArchiveQuarter>> {
    crawler_impl::fetch_archive_list().await
}

pub async fn fetch_schedule_basic(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fetch_schedule_basic(year_quarter).await
}

pub async fn fetch_schedule_basic_api_only(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fetch_schedule_basic_api_only(year_quarter).await
}

pub async fn fetch_schedule_basic_from_local_json(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fetch_schedule_basic_from_local_json(year_quarter).await
}

pub fn fetch_schedule_basic_from_local_json_nodl(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fetch_schedule_basic_from_local_json_nodl(year_quarter)
}

pub fn spawn_sites_index_background() {
    crawler_impl::spawn_sites_index_background();
}

pub async fn build_sites_index() -> anyhow::Result<usize> {
    crawler_impl::build_sites_index().await
}

pub async fn invalidate_sites_index() {
    crawler_impl::invalidate_sites_index().await;
}

pub async fn fetch_bangumi_data_sites(bangumi_id: i64) -> Vec<crawler_impl::BangumiDataSiteEntry> {
    crawler_impl::fetch_bangumi_data_sites(bangumi_id).await
}

pub async fn fetch_bangumi_data_sites_by_mikan(
    mikan_id: i64,
) -> Vec<crawler_impl::BangumiDataSiteEntry> {
    crawler_impl::fetch_bangumi_data_sites_by_mikan(mikan_id).await
}

pub async fn lookup_mikan_id(bangumi_id: i64) -> Option<i64> {
    crawler_impl::lookup_mikan_id(bangumi_id).await
}

pub async fn fill_anime_details(
    animes: Vec<crawler_impl::AnimeInfo>,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fill_anime_details(animes).await
}

pub async fn fetch_light_subject_details(
    subject_id: i64,
) -> anyhow::Result<crawler_impl::AnimeInfo> {
    crawler_impl::fetch_light_subject_details(subject_id).await
}

pub async fn fetch_extra_subjects(
    year_quarter: String,
    existing_ids: Vec<String>,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    crawler_impl::fetch_extra_subjects(year_quarter, existing_ids).await
}

pub fn get_bangumi_data_cache_status() -> crawler_impl::BangumiDataCacheStatus {
    crawler_impl::get_bangumi_data_cache_status()
}

pub async fn refresh_bangumi_data_cache() -> anyhow::Result<bool> {
    crawler_impl::refresh_bangumi_data_cache().await
}

pub async fn ensure_bangumi_data_cache(max_age_secs: u64) -> anyhow::Result<bool> {
    crawler_impl::ensure_bangumi_data_cache(max_age_secs).await
}
