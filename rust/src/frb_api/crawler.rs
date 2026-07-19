use crate::api::crawler as crawler_impl;
use crate::frb_api::contract;

pub async fn fetch_archive_list() -> anyhow::Result<Vec<crawler_impl::ArchiveQuarter>> {
    contract::public_result(
        "fetch_archive_list",
        crawler_impl::fetch_archive_list().await,
    )
}

pub async fn fetch_schedule_basic(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    const API: &str = "fetch_schedule_basic";
    contract::public_result(
        API,
        contract::require_quarter("year_quarter", &year_quarter),
    )?;
    contract::public_result(API, crawler_impl::fetch_schedule_basic(year_quarter).await)
}

pub async fn fetch_schedule_basic_api_only(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    const API: &str = "fetch_schedule_basic_api_only";
    contract::public_result(
        API,
        contract::require_quarter("year_quarter", &year_quarter),
    )?;
    contract::public_result(
        API,
        crawler_impl::fetch_schedule_basic_api_only(year_quarter).await,
    )
}

pub async fn fetch_schedule_basic_from_local_json(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    const API: &str = "fetch_schedule_basic_from_local_json";
    contract::public_result(
        API,
        contract::require_quarter("year_quarter", &year_quarter),
    )?;
    contract::public_result(
        API,
        crawler_impl::fetch_schedule_basic_from_local_json(year_quarter).await,
    )
}

pub fn fetch_schedule_basic_from_local_json_nodl(
    year_quarter: String,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    const API: &str = "fetch_schedule_basic_from_local_json_nodl";
    contract::public_result(
        API,
        contract::require_quarter("year_quarter", &year_quarter),
    )?;
    contract::public_result(
        API,
        crawler_impl::fetch_schedule_basic_from_local_json_nodl(year_quarter),
    )
}

pub fn spawn_sites_index_background() {
    crawler_impl::spawn_sites_index_background();
}

pub async fn build_sites_index() -> anyhow::Result<usize> {
    contract::public_result("build_sites_index", crawler_impl::build_sites_index().await)
}

pub async fn invalidate_sites_index() {
    crawler_impl::invalidate_sites_index().await;
}

pub async fn fetch_bangumi_data_sites(bangumi_id: i64) -> Vec<crawler_impl::BangumiDataSiteEntry> {
    if bangumi_id <= 0 {
        return Vec::new();
    }
    crawler_impl::fetch_bangumi_data_sites(bangumi_id).await
}

pub async fn fetch_bangumi_data_sites_by_mikan(
    mikan_id: i64,
) -> Vec<crawler_impl::BangumiDataSiteEntry> {
    if mikan_id <= 0 {
        return Vec::new();
    }
    crawler_impl::fetch_bangumi_data_sites_by_mikan(mikan_id).await
}

pub async fn lookup_mikan_id(bangumi_id: i64) -> Option<i64> {
    if bangumi_id <= 0 {
        return None;
    }
    crawler_impl::lookup_mikan_id(bangumi_id).await
}

pub async fn fill_anime_details(
    animes: Vec<crawler_impl::AnimeInfo>,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    contract::public_result(
        "fill_anime_details",
        crawler_impl::fill_anime_details(animes).await,
    )
}

pub async fn fetch_light_subject_details(
    subject_id: i64,
) -> anyhow::Result<crawler_impl::AnimeInfo> {
    const API: &str = "fetch_light_subject_details";
    contract::public_result(
        API,
        contract::require_positive_i64("subject_id", subject_id),
    )?;
    contract::public_result(
        API,
        crawler_impl::fetch_light_subject_details(subject_id).await,
    )
}

pub async fn fetch_extra_subjects(
    year_quarter: String,
    existing_ids: Vec<String>,
) -> anyhow::Result<Vec<crawler_impl::AnimeInfo>> {
    const API: &str = "fetch_extra_subjects";
    contract::public_result(
        API,
        contract::require_quarter("year_quarter", &year_quarter),
    )?;
    contract::public_result(
        API,
        contract::require_positive_decimal_items("existing_ids", &existing_ids),
    )?;
    contract::public_result(
        API,
        crawler_impl::fetch_extra_subjects(year_quarter, existing_ids).await,
    )
}

pub fn get_bangumi_data_cache_status() -> crawler_impl::BangumiDataCacheStatus {
    crawler_impl::get_bangumi_data_cache_status()
}

pub async fn refresh_bangumi_data_cache() -> anyhow::Result<bool> {
    contract::public_result(
        "refresh_bangumi_data_cache",
        crawler_impl::refresh_bangumi_data_cache().await,
    )
}

pub async fn ensure_bangumi_data_cache(max_age_secs: u64) -> anyhow::Result<bool> {
    contract::public_result(
        "ensure_bangumi_data_cache",
        crawler_impl::ensure_bangumi_data_cache(max_age_secs).await,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn invalid_quarters_and_ids_are_rejected_without_io_side_effects() {
        assert_eq!(
            fetch_schedule_basic("中文q1".to_string())
                .await
                .unwrap_err()
                .to_string(),
            "fetch_schedule_basic: invalid argument `year_quarter`: must match YYYYq1 through YYYYq4"
        );
        assert_eq!(
            fetch_extra_subjects("2026q1".to_string(), vec!["0".to_string()])
                .await
                .unwrap_err()
                .to_string(),
            "fetch_extra_subjects: invalid argument `existing_ids`: item at index 0 must be a positive decimal ID"
        );
        assert!(fetch_bangumi_data_sites(0).await.is_empty());
        assert!(fetch_bangumi_data_sites_by_mikan(-1).await.is_empty());
        assert_eq!(lookup_mikan_id(0).await, None);
    }
}
