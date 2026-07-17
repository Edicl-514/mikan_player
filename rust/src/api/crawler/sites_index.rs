use super::types::*;
use std::collections::HashMap;
use std::sync::{Arc, OnceLock};
use tokio::sync::RwLock;

use super::bangumi_data_store::{
    bangumi_data_generation, bangumi_data_trace, get_or_load_bangumi_data_blocking,
    sites_index_build_single_flight,
};

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
            if guard.is_some() {
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
pub fn spawn_sites_index_background() {
    spawn_build_sites_index_background();
}

/// Pure sites-index build logic — no single-flight guard. The caller must
/// hold the `sites_index_build_single_flight()` permit (or otherwise be the
/// sole builder) to avoid duplicate concurrent builds.
pub(super) async fn build_sites_index_core() -> anyhow::Result<usize> {
    type SitesIndexMaps = (
        HashMap<i64, Vec<BangumiDataSiteEntry>>,
        HashMap<i64, i64>,
        HashMap<i64, i64>,
    );

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
            let mut by_bangumi: HashMap<i64, Vec<BangumiDataSiteEntry>> =
                HashMap::with_capacity(data.items.len());
            let mut by_mikan: HashMap<i64, i64> = HashMap::new();
            let mut by_bangumi_to_mikan: HashMap<i64, i64> = HashMap::new();

            for item in &data.items {
                let entries: Vec<BangumiDataSiteEntry> = item
                    .sites
                    .iter()
                    .filter_map(|s| {
                        let meta = data.site_meta.get(&s.site)?;
                        let url = s
                            .url
                            .clone()
                            .filter(|u| !u.is_empty())
                            .unwrap_or_else(|| meta.url_template.replace("{{id}}", &s.id));
                        Some(BangumiDataSiteEntry {
                            site: s.site.clone(),
                            title: meta.title.clone(),
                            url,
                            kind: meta.kind.clone(),
                            comment: s.comment.clone().filter(|c| !c.is_empty()),
                        })
                    })
                    .collect();
                if entries.is_empty() {
                    continue;
                }

                let bgm_id = item
                    .sites
                    .iter()
                    .find(|s| s.site == "bangumi")
                    .and_then(|s| s.id.parse::<i64>().ok());
                let mikan_id = item
                    .sites
                    .iter()
                    .find(|s| s.site == "mikan")
                    .and_then(|s| s.id.parse::<i64>().ok());

                if let Some(bid) = bgm_id {
                    by_bangumi.insert(bid, entries);
                    if let Some(mid) = mikan_id {
                        by_mikan.insert(mid, bid);
                        by_bangumi_to_mikan.insert(bid, mid);
                    }
                }
            }

            bangumi_data_trace(&format!(
                "build_sites_index_core maps built bangumi={} mikan={}",
                by_bangumi.len(),
                by_mikan.len()
            ));
            Ok((by_bangumi, by_mikan, by_bangumi_to_mikan))
        })
        .await??;

    if bangumi_data_generation() != started_generation {
        anyhow::bail!("bangumi-data changed while building sites index; discarding stale index");
    }

    let count = by_bangumi.len();
    *sites_index_slot().write().await = Some(Arc::new(SitesIndex {
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
        if let Some(idx) = guard.as_ref() {
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
pub async fn build_sites_index() -> anyhow::Result<usize> {
    build_sites_index_singleflight().await
}

/// Drop the in-memory index. Used when `bangumi-data.json` is replaced so
/// the next `build_sites_index` call rebuilds against the new payload.
pub async fn invalidate_sites_index() {
    let mut guard = sites_index_slot().write().await;
    *guard = None;
}

/// FRB-exposed lookup. When the index has not been built yet and the local
/// `bangumi-data.json` exists, kicks off a non-blocking background rebuild
/// and returns the current (possibly empty) result. The details page should
/// treat an empty result as "data not ready yet" and re-query on the next
/// user action / stream tick. Synchronously waiting here would block the UI
/// on a ~370 ms parse+build on the first lookup in a process.
pub async fn fetch_bangumi_data_sites(bangumi_id: i64) -> Vec<BangumiDataSiteEntry> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref() {
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
pub async fn fetch_bangumi_data_sites_by_mikan(mikan_id: i64) -> Vec<BangumiDataSiteEntry> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref() {
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
pub async fn lookup_mikan_id(bangumi_id: i64) -> Option<i64> {
    {
        let guard = sites_index_slot().read().await;
        if let Some(idx) = guard.as_ref() {
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
        guard.is_some()
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
