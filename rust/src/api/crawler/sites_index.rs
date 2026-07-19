use super::types::*;
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, OnceLock};
use tokio::sync::RwLock;

use super::bangumi_data_store::{
    bangumi_data_generation, bangumi_data_trace, get_or_load_bangumi_data_blocking,
    sites_index_build_single_flight,
};

type SitesIndexMaps = (
    HashMap<i64, Vec<BangumiDataSiteEntry>>,
    HashMap<i64, i64>,
    HashMap<i64, i64>,
);

fn positive_site_id(item: &BgmlistItem, site_name: &str) -> Option<i64> {
    item.sites
        .iter()
        .filter(|site| site.site.trim() == site_name)
        .filter_map(|site| site.id.trim().parse::<i64>().ok())
        .find(|id| *id > 0)
}

fn resolve_site_url(meta: &BangumiDataSiteMeta, site: &BgmlistSite) -> Option<String> {
    let id = site.id.trim();
    let template = meta.url_template.trim().replace("{{id}}", id);
    let explicit = site
        .url
        .as_deref()
        .map(str::trim)
        .filter(|url| !url.is_empty());

    let url = match explicit {
        Some(raw) => url::Url::parse(raw)
            .or_else(|_| url::Url::parse(&template)?.join(raw))
            .ok()?,
        None => url::Url::parse(&template).ok()?,
    };
    matches!(url.scheme(), "http" | "https").then(|| url.to_string())
}

fn build_sites_index_maps(data: &BangumiDataJson) -> SitesIndexMaps {
    let mut by_bangumi: HashMap<i64, Vec<BangumiDataSiteEntry>> =
        HashMap::with_capacity(data.items.len());
    let mut by_mikan: HashMap<i64, i64> = HashMap::new();
    let mut by_bangumi_to_mikan: HashMap<i64, i64> = HashMap::new();

    for item in &data.items {
        let Some(bgm_id) = positive_site_id(item, "bangumi") else {
            continue;
        };
        let mut item_seen = HashSet::new();
        let entries: Vec<BangumiDataSiteEntry> = item
            .sites
            .iter()
            .filter_map(|site| {
                let site_name = site.site.trim();
                if site_name.is_empty() {
                    return None;
                }
                let meta = data.site_meta.get(site_name)?;
                let url = resolve_site_url(meta, site)?;
                if !item_seen.insert((site_name.to_string(), url.clone())) {
                    return None;
                }
                Some(BangumiDataSiteEntry {
                    site: site_name.to_string(),
                    title: match meta.title.trim() {
                        "" => site_name.to_string(),
                        title => title.to_string(),
                    },
                    url,
                    kind: meta.kind.trim().to_string(),
                    comment: site
                        .comment
                        .as_deref()
                        .map(str::trim)
                        .filter(|comment| !comment.is_empty())
                        .map(str::to_string),
                })
            })
            .collect();
        if entries.is_empty() {
            continue;
        }

        let target = by_bangumi.entry(bgm_id).or_default();
        let mut existing: HashSet<(String, String)> = target
            .iter()
            .map(|entry| (entry.site.clone(), entry.url.clone()))
            .collect();
        target.extend(
            entries
                .into_iter()
                .filter(|entry| existing.insert((entry.site.clone(), entry.url.clone()))),
        );

        if let Some(mikan_id) = positive_site_id(item, "mikan") {
            by_mikan.entry(mikan_id).or_insert(bgm_id);
            by_bangumi_to_mikan.entry(bgm_id).or_insert(mikan_id);
        }
    }

    (by_bangumi, by_mikan, by_bangumi_to_mikan)
}

/// Fire-and-forget: rebuild the sites index in the background so the
/// timetable hot path does not block on it. Uses single-flight so
/// concurrent callers don't start duplicate builds.
///
/// The permit is acquired *here* (not inside the build core) so the
/// spawned task does not re-acquire the same guard and deadlock. The task
/// re-checks whether the index was already built after acquiring the
/// permit, then runs the pure build core.
pub(super) fn spawn_build_sites_index_background() {
    bangumi_data_trace("spawn sites index background requested");
    let permit = sites_index_build_single_flight().try_acquire();
    if permit.is_err() {
        bangumi_data_trace("sites index build already in flight");
        log::debug!("sites index build already in flight, skipping background spawn");
        return;
    }
    let permit = permit.unwrap();
    bangumi_data_trace("sites index background task spawned");
    tokio::spawn(async move {
        let _permit = permit;
        bangumi_data_trace("sites index background task started");
        // Re-check: another path may have built the index between our
        // try_acquire check and now.
        {
            let guard = sites_index_slot().read().await;
            if guard
                .as_ref()
                .is_some_and(|index| index.generation == bangumi_data_generation())
            {
                bangumi_data_trace("sites index already built; background task exits");
                return;
            }
        }
        match build_sites_index_core().await {
            Ok(n) => {
                bangumi_data_trace(&format!("background sites index build done: {n} entries"));
                log::info!("background sites index build: {n} entries");
            }
            Err(e) => {
                bangumi_data_trace(&format!("background sites index build failed: {e:#}"));
                log::warn!("background sites index build failed: {e:#}");
            }
        }
    });
}

/// FRB-exposed wrapper around `spawn_build_sites_index_background` so the
/// Dart side can warm the sites index without blocking the calling future
/// (e.g. after a Level 2 timetable hit). Safe to call repeatedly — single-
/// flight inside the Rust layer ensures at most one in-flight build.
pub(crate) fn spawn_sites_index_background() {
    spawn_build_sites_index_background();
}

/// Pure sites-index build logic — no single-flight guard. The caller must
/// hold the `sites_index_build_single_flight()` permit (or otherwise be the
/// sole builder) to avoid duplicate concurrent builds.
pub(super) async fn build_sites_index_core() -> anyhow::Result<usize> {
    let started_generation = bangumi_data_generation();
    bangumi_data_trace(&format!(
        "build_sites_index_core start generation={started_generation}"
    ));

    let (by_bangumi, by_mikan, by_bangumi_to_mikan) =
        tokio::task::spawn_blocking(|| -> anyhow::Result<SitesIndexMaps> {
            bangumi_data_trace("build_sites_index_core spawn_blocking start");
            let data = get_or_load_bangumi_data_blocking()?;
            bangumi_data_trace(&format!(
                "build_sites_index_core data loaded items={}",
                data.items.len()
            ));
            let (by_bangumi, by_mikan, by_bangumi_to_mikan) = build_sites_index_maps(&data);

            bangumi_data_trace(&format!(
                "build_sites_index_core maps built bangumi={} mikan={}",
                by_bangumi.len(),
                by_mikan.len()
            ));
            Ok((by_bangumi, by_mikan, by_bangumi_to_mikan))
        })
        .await??;

    let mut slot = sites_index_slot().write().await;
    if bangumi_data_generation() != started_generation {
        anyhow::bail!("bangumi-data changed while building sites index; discarding stale index");
    }

    let count = by_bangumi.len();
    *slot = Some(Arc::new(SitesIndex {
        generation: started_generation,
        by_bangumi_id: by_bangumi,
        by_mikan_id: by_mikan,
        by_bangumi_to_mikan,
    }));
    bangumi_data_trace(&format!("build_sites_index_core stored count={count}"));
    Ok(count)
}

/// Single-flight wrapper: acquire the permit, then re-check whether the
/// index was already built while we waited (a previous permit holder may
/// have produced it). If still empty, run the build core. Used by the pub
/// `build_sites_index` and `ensure_sites_index_built` so neither acquires
/// the guard twice.
pub(super) async fn build_sites_index_singleflight() -> anyhow::Result<usize> {
    let _permit = sites_index_build_single_flight().acquire().await;
    // Re-check after acquiring the permit: a previous holder may have
    // finished building the index while we were waiting. This also avoids
    // a redundant rebuild when several callers queued up behind the first.
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref()
            && idx.generation == bangumi_data_generation()
        {
            return Ok(idx.by_bangumi_id.len());
        }
    }
    build_sites_index_core().await
}

// =====================================================================
// bangumi-data sites index
//
// Holds a `bangumi.tv id -> Vec<BangumiDataSiteEntry>` map plus a
// `mikan id -> bangumi.tv id` map, both built once from the cached
// `bangumi-data.json`. The map is kept in process memory (no on-disk
// cache): the 7 MB JSON parses in ~370 ms on first call, then every
// lookup is O(1). The `OnceLock`+`RwLock` pair makes the read path
// lock-free after the first write.
// =====================================================================

struct SitesIndex {
    /// Parsed payload generation used to build this index.
    generation: u64,
    /// Keyed by `bangumi.tv` subject id.
    by_bangumi_id: HashMap<i64, Vec<BangumiDataSiteEntry>>,
    /// Keyed by `mikan` id; lets mikan-origin entries resolve sites too.
    by_mikan_id: HashMap<i64, i64>,
    /// Reverse map: bangumi.tv subject id → mikan id.
    by_bangumi_to_mikan: HashMap<i64, i64>,
}

static SITES_INDEX: OnceLock<RwLock<Option<Arc<SitesIndex>>>> = OnceLock::new();

fn sites_index_slot() -> &'static RwLock<Option<Arc<SitesIndex>>> {
    SITES_INDEX.get_or_init(|| RwLock::new(None))
}

/// Build the sites index from the cached JSON. Uses single-flight so
/// concurrent callers share one build (acquire permit, re-check, build
/// core). Delegates to `build_sites_index_singleflight`.
pub(crate) async fn build_sites_index() -> anyhow::Result<usize> {
    build_sites_index_singleflight().await
}

/// Drop the in-memory index. Used when `bangumi-data.json` is replaced so
/// the next `build_sites_index` call rebuilds against the new payload.
pub(crate) async fn invalidate_sites_index() {
    let mut guard = sites_index_slot().write().await;
    *guard = None;
}

/// FRB-exposed lookup. When the index has not been built yet and the local
/// `bangumi-data.json` exists, kicks off a non-blocking background rebuild
/// and returns the current (possibly empty) result. The details page should
/// treat an empty result as "data not ready yet" and re-query on the next
/// user action / stream tick. Synchronously waiting here would block the UI
/// on a ~370 ms parse+build on the first lookup in a process.
pub(crate) async fn fetch_bangumi_data_sites(bangumi_id: i64) -> Vec<BangumiDataSiteEntry> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref()
            && idx.generation == bangumi_data_generation()
        {
            return idx
                .by_bangumi_id
                .get(&bangumi_id)
                .cloned()
                .unwrap_or_default();
        }
    }
    // Index empty — fire-and-forget background build; return current
    // (empty) result so the UI call is non-blocking.
    spawn_build_sites_index_background();
    Vec::new()
}

/// Optional helper for mikan-origin entries that don't carry a bangumi id.
/// Self-heals like `fetch_bangumi_data_sites`.
pub(crate) async fn fetch_bangumi_data_sites_by_mikan(mikan_id: i64) -> Vec<BangumiDataSiteEntry> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref()
            && idx.generation == bangumi_data_generation()
        {
            if let Some(bid) = idx.by_mikan_id.get(&mikan_id).copied() {
                return idx.by_bangumi_id.get(&bid).cloned().unwrap_or_default();
            }
            return Vec::new();
        }
    }
    spawn_build_sites_index_background();
    Vec::new()
}

/// Look up the mikan id for a given bangumi.tv subject id from the
/// cached bangumi-data index. Self-heals like the site lookups.
pub(crate) async fn lookup_mikan_id(bangumi_id: i64) -> Option<i64> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref()
            && idx.generation == bangumi_data_generation()
        {
            return idx.by_bangumi_to_mikan.get(&bangumi_id).copied();
        }
    }
    spawn_build_sites_index_background();
    None
}

/// Build the in-memory sites index if it has not been built yet (or was
/// invalidated) AND the local `bangumi-data.json` file exists. Uses
/// single-flight via `build_sites_index_singleflight`, which re-checks
/// the index after acquiring the permit so queued callers don't rebuild.
/// Failures are logged and swallowed so callers stay best-effort.
#[allow(dead_code)]
pub(super) async fn ensure_sites_index_built() {
    let already = {
        let guard = sites_index_slot().read().await;
        guard
            .as_ref()
            .is_some_and(|index| index.generation == bangumi_data_generation())
    };
    if already {
        return;
    }
    let cache_dir = crate::api::config::get_cache_dir();
    let local_path = std::path::Path::new(&cache_dir).join("bangumi-data.json");
    if !local_path.exists() {
        return;
    }
    match build_sites_index_singleflight().await {
        Ok(n) => log::info!("bangumi-data sites index built: {n} entries"),
        Err(e) => log::warn!("bangumi-data sites index build failed: {e:#}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::state::isolate_runtime_config;
    use serde_json::json;

    fn data_with_subject(id: i64, mikan_id: i64) -> Vec<u8> {
        serde_json::to_vec(&json!({
            "siteMeta": {
                "bangumi": {
                    "title": "Bangumi",
                    "urlTemplate": "https://bangumi.tv/subject/{{id}}",
                    "type": "info"
                },
                "mikan": {
                    "title": "Mikan",
                    "urlTemplate": "https://mikanani.me/Home/Bangumi/{{id}}",
                    "type": "resource"
                }
            },
            "items": [{
                "title": format!("Subject {id}"),
                "begin": "2025-04-01T00:00:00Z",
                "sites": [
                    {"site": "bangumi", "id": id.to_string()},
                    {"site": "mikan", "id": mikan_id.to_string()}
                ]
            }]
        }))
        .unwrap()
    }

    #[test]
    fn site_map_merges_duplicate_subjects_and_resolves_relative_urls() {
        let data: BangumiDataJson = serde_json::from_value(json!({
            "siteMeta": {
                "bangumi": {
                    "title": "Bangumi",
                    "urlTemplate": "https://bangumi.tv/subject/{{id}}",
                    "type": "info"
                },
                "mikan": {
                    "urlTemplate": "https://mikanani.me/Home/Bangumi/{{id}}"
                },
                "rss": {
                    "title": "RSS",
                    "urlTemplate": "https://feeds.example.test/show/{{id}}",
                    "type": "onair"
                },
                "broken": {}
            },
            "items": [
                {
                    "title": "First",
                    "begin": "2025-04-01T00:00:00Z",
                    "sites": [
                        {"site": "bangumi", "id": "1"},
                        {"site": "mikan", "id": "10"},
                        {"site": "rss", "id": "feed", "url": "/rss/1", "comment": " note "},
                        {"site": "rss", "id": "feed", "url": "/rss/1"},
                        {"site": "broken", "id": "x"},
                        {"id": "missing-site"}
                    ]
                },
                {
                    "title": "Duplicate row",
                    "begin": "2025-04-02T00:00:00Z",
                    "sites": [
                        {"site": "bangumi", "id": "1"},
                        {"site": "rss", "id": "other", "url": "extra.xml"}
                    ]
                },
                {
                    "title": "Invalid identity",
                    "begin": "2025-04-03T00:00:00Z",
                    "sites": [{"site": "bangumi", "id": "0"}]
                }
            ]
        }))
        .unwrap();

        let (by_bangumi, by_mikan, reverse) = build_sites_index_maps(&data);
        assert_eq!(by_bangumi.len(), 1);
        let entries = &by_bangumi[&1];
        assert_eq!(entries.len(), 4);
        assert!(entries.iter().any(|entry| {
            entry.site == "rss"
                && entry.url == "https://feeds.example.test/rss/1"
                && entry.comment.as_deref() == Some("note")
        }));
        assert!(entries.iter().any(|entry| {
            entry.site == "rss" && entry.url == "https://feeds.example.test/show/extra.xml"
        }));
        let mikan = entries.iter().find(|entry| entry.site == "mikan").unwrap();
        assert_eq!(mikan.title, "mikan");
        assert_eq!(mikan.kind, "");
        assert_eq!(by_mikan.get(&10), Some(&1));
        assert_eq!(reverse.get(&1), Some(&10));
    }

    #[tokio::test]
    async fn concurrent_builds_share_one_index_and_invalidation_reloads_new_file() {
        let _config = isolate_runtime_config();
        let temp = tempfile::tempdir().unwrap();
        crate::api::config::init_config(
            temp.path().to_string_lossy().to_string(),
            temp.path().to_string_lossy().to_string(),
        );
        let path = temp.path().join("bangumi-data.json");
        super::super::bangumi_data_store::atomic_write_bytes(&path, &data_with_subject(1, 10))
            .unwrap();
        super::super::bangumi_data_store::invalidate_bangumi_data_cache();
        invalidate_sites_index().await;

        let (first, second) = tokio::join!(build_sites_index(), build_sites_index());
        assert_eq!(first.unwrap(), 1);
        assert_eq!(second.unwrap(), 1);
        assert_eq!(lookup_mikan_id(1).await, Some(10));
        assert_eq!(fetch_bangumi_data_sites_by_mikan(10).await.len(), 2);

        super::super::bangumi_data_store::atomic_write_bytes(&path, &data_with_subject(2, 20))
            .unwrap();
        super::super::bangumi_data_store::invalidate_bangumi_data_cache();
        assert_eq!(build_sites_index().await.unwrap(), 1);
        assert!(fetch_bangumi_data_sites(1).await.is_empty());
        assert_eq!(lookup_mikan_id(2).await, Some(20));
    }
}
