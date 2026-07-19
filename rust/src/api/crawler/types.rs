use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeInfo {
    pub title: String,
    pub sub_title: Option<String>,
    pub bangumi_id: Option<String>,
    pub mikan_id: Option<String>,
    pub cover_url: Option<String>,
    pub site_url: Option<String>,
    pub broadcast_day: Option<String>,
    pub broadcast_time: Option<String>,
    pub score: Option<f64>,
    pub rank: Option<i32>,
    pub tags: Vec<String>,
    pub full_json: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchiveQuarter {
    pub year: String,
    pub quarter: String,
    pub title: String,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
pub(super) struct SeasonListResponse {
    #[allow(dead_code)]
    #[serde(default)]
    pub(super) version: u64,
    #[serde(default)]
    pub(super) items: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
pub(super) struct ArchiveResponse {
    #[serde(default)]
    pub(super) items: Vec<BgmlistItem>,
}

#[derive(Debug, Clone, Deserialize, Default)]
#[allow(dead_code)]
#[flutter_rust_bridge::frb(ignore)]
pub(super) struct BgmlistItem {
    #[serde(default)]
    pub(super) title: String,
    #[serde(rename = "titleTranslate", default)]
    pub(super) title_translate: BgmlistTitleTranslate,
    #[serde(rename = "type", default)]
    pub(super) item_type: String,
    #[serde(rename = "officialSite", default)]
    pub(super) official_site: String,
    #[serde(default)]
    pub(super) begin: String,
    #[serde(default)]
    pub(super) broadcast: String,
    #[serde(default)]
    pub(super) sites: Vec<BgmlistSite>,
    #[serde(default)]
    pub(super) id: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Default)]
#[flutter_rust_bridge::frb(ignore)]
pub(super) struct BgmlistTitleTranslate {
    #[serde(rename = "zh-Hans", default)]
    pub(super) zh_hans: Vec<String>,
    #[serde(rename = "zh-Hant", default)]
    pub(super) zh_hant: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
#[flutter_rust_bridge::frb(ignore)]
pub(super) struct BgmlistSite {
    #[serde(default)]
    pub(super) site: String,
    #[serde(default)]
    pub(super) id: String,
    #[serde(default)]
    pub(super) url: Option<String>,
    #[serde(default)]
    pub(super) begin: Option<String>,
    #[serde(default)]
    pub(super) broadcast: Option<String>,
    #[serde(default)]
    pub(super) comment: Option<String>,
    #[serde(default)]
    pub(super) regions: Option<Vec<String>>,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
#[serde(rename_all = "camelCase")]
pub(super) struct BangumiDataSiteMeta {
    #[serde(default)]
    pub(super) title: String,
    #[serde(default)]
    pub(super) url_template: String,
    #[serde(rename = "type")]
    #[serde(default)]
    pub(super) kind: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub(super) regions: Option<Vec<String>>,
}

#[derive(Debug, Clone, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
#[serde(rename_all = "camelCase")]
pub(super) struct BangumiDataJson {
    #[serde(default)]
    pub(super) site_meta: HashMap<String, BangumiDataSiteMeta>,
    #[serde(default)]
    pub(super) items: Vec<BgmlistItem>,
}

/// One site of a bangumi-data entry, resolved (URL template filled in) and
/// safe to expose to Dart via flutter_rust_bridge.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BangumiDataSiteEntry {
    pub site: String,
    pub title: String,
    pub url: String,
    pub kind: String,
    #[serde(default)]
    pub comment: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiDataCacheStatus {
    pub cached: bool,
    pub file_size: u64,
    pub last_modified_secs: Option<u64>,
    pub version: String,
    pub last_failed_secs: Option<u64>,
}
