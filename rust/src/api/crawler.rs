mod bangumi_data_store;
mod fill_details;
mod parse_time;
mod schedule_api;
mod sites_index;
mod types;

pub use bangumi_data_store::{
    ensure_bangumi_data_cache, get_bangumi_data_cache_status, refresh_bangumi_data_cache,
};
pub use fill_details::{fetch_extra_subjects, fetch_light_subject_details, fill_anime_details};
pub use schedule_api::{
    fetch_archive_list, fetch_schedule_basic, fetch_schedule_basic_api_only,
    fetch_schedule_basic_from_local_json, fetch_schedule_basic_from_local_json_nodl,
};
pub use sites_index::{
    build_sites_index, fetch_bangumi_data_sites, fetch_bangumi_data_sites_by_mikan,
    invalidate_sites_index, lookup_mikan_id, spawn_sites_index_background,
};
pub use types::*;

#[cfg(test)]
mod tests {
    use super::bangumi_data_store::*;
    use super::parse_time::*;
    use super::types::*;

    /// Serializes tests that mutate the process-global
    /// `crate::api::config::CONFIG` cache_dir (via `init_config`) so
    /// they don't clobber each other when cargo runs tests in
    /// parallel. Acquire at the start of any test that calls
    /// `init_config`.
    static TEST_CONFIG_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[test]
    fn parse_broadcast_parts_supports_legacy_and_current_bgmlist_text() {
        assert_eq!(
            parse_broadcast_parts(Some("周一 00:00")),
            (Some("周一".to_string()), Some("00:00".to_string()))
        );
        assert_eq!(
            parse_broadcast_parts(Some("每周日 00:00")),
            (Some("周日".to_string()), Some("00:00".to_string()))
        );
    }

    #[test]
    fn parse_broadcast_from_rfc_parses_weekly_schedule() {
        let (day, time) = parse_broadcast_from_rfc("R/2026-04-04T16:00:00.000Z/P7D");
        assert_eq!(day, Some("周日".to_string()));
        assert_eq!(time, Some("00:00".to_string()));
    }

    #[test]
    fn parse_broadcast_from_rfc_handles_legacy_begin_without_r_prefix() {
        // npm bangumi-data `begin` form, no R/ prefix — must still parse as UTC.
        let (day, time) = parse_broadcast_from_rfc("1962/12/31 16:00:00");
        // 1962-12-31T16:00:00Z -> +8 = 1963-01-01 00:00 -> Tuesday.
        assert_eq!(day, Some("周二".to_string()));
        assert_eq!(time, Some("00:00".to_string()));
    }

    #[test]
    fn parse_begin_utc_supports_iso_and_legacy_forms() {
        assert!(parse_begin_utc("2025-09-30T16:35:00.000Z").is_some());
        assert!(parse_begin_utc("2025-09-30T16:35:00").is_some());
        assert!(parse_begin_utc("1962/12/31 16:00:00").is_some());
        assert!(parse_begin_utc("").is_none());
        assert!(parse_begin_utc("not a date").is_none());
    }

    #[test]
    fn parse_broadcast_from_rfc_empty_string() {
        assert_eq!(parse_broadcast_from_rfc(""), (None, None));
    }

    #[test]
    fn quarter_to_title_formats_correctly() {
        assert_eq!(quarter_to_title("2026q1"), "2026年1月");
        assert_eq!(quarter_to_title("2026q4"), "2026年10月");
    }

    #[test]
    fn bgmlist_item_to_anime_info_extracts_ids() {
        let item = BgmlistItem {
            title: "テストアニメ".to_string(),
            title_translate: BgmlistTitleTranslate {
                zh_hans: vec!["测试动画".to_string()],
                zh_hant: vec![],
            },
            item_type: "tv".to_string(),
            official_site: String::new(),
            begin: "2026-04-04T16:00:00.000Z".to_string(),
            broadcast: "R/2026-04-04T16:00:00.000Z/P7D".to_string(),
            sites: vec![
                BgmlistSite {
                    site: "bangumi".to_string(),
                    id: "505258".to_string(),
                    url: None,
                    begin: None,
                    broadcast: None,
                    comment: None,
                    regions: None,
                },
                BgmlistSite {
                    site: "mikan".to_string(),
                    id: "3886".to_string(),
                    url: None,
                    begin: None,
                    broadcast: None,
                    comment: None,
                    regions: None,
                },
            ],
            id: None,
        };
        let anime = bgmlist_item_to_anime_info(&item).unwrap();
        assert_eq!(anime.title, "测试动画");
        assert_eq!(anime.sub_title, Some("テストアニメ".to_string()));
        assert_eq!(anime.bangumi_id, Some("505258".to_string()));
        assert_eq!(anime.mikan_id, Some("3886".to_string()));
        assert_eq!(anime.broadcast_day, Some("周日".to_string()));
        assert_eq!(anime.broadcast_time, Some("00:00".to_string()));
    }

    #[test]
    fn bgmlist_item_to_anime_info_uses_legacy_begin_when_no_broadcast() {
        // Mirrors the npm bangumi-data row: legacy `begin`, empty `broadcast`.
        let item = BgmlistItem {
            title: "テスト".to_string(),
            title_translate: BgmlistTitleTranslate::default(),
            item_type: "tv".to_string(),
            official_site: String::new(),
            begin: "1962/12/31 16:00:00".to_string(),
            broadcast: String::new(),
            sites: vec![],
            id: None,
        };
        let anime = bgmlist_item_to_anime_info(&item).unwrap();
        // 16:00 UTC -> 00:00 CST next day.
        assert_eq!(anime.broadcast_day, Some("周二".to_string()));
        assert_eq!(anime.broadcast_time, Some("00:00".to_string()));
    }

    #[test]
    fn filter_items_by_quarter_works() {
        let items = vec![
            BgmlistItem {
                title: "A".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2026-04-04T16:00:00.000Z".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
            BgmlistItem {
                title: "B".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2026-01-04T16:00:00.000Z".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
        ];
        let filtered = filter_items_by_quarter(&items, "2026q2");
        assert_eq!(filtered.len(), 1);
        assert_eq!(filtered[0].title, "A");
    }

    #[test]
    fn filter_items_by_quarter_handles_legacy_form_and_tz_boundary() {
        let items = vec![
            // Legacy npm form, late September UTC -> Oct 1 CST => belongs to q4.
            BgmlistItem {
                title: "boundary".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2025/9/30 16:35:00".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
            // Legacy form, solidly in October CST.
            BgmlistItem {
                title: "october".to_string(),
                title_translate: BgmlistTitleTranslate::default(),
                item_type: "tv".to_string(),
                official_site: String::new(),
                begin: "2025/10/5 01:00:00".to_string(),
                broadcast: String::new(),
                sites: vec![],
                id: None,
            },
        ];
        let filtered = filter_items_by_quarter(&items, "2025q4");
        assert_eq!(filtered.len(), 2);
    }

    /// `verify_bangumi_data_payload` returns `Err` for payloads that are not
    /// valid JSON or are missing the top-level `items` array. Well-formed
    /// payloads (even with an empty `items` array) pass.
    #[test]
    fn verify_bangumi_data_payload_rejects_invalid_inputs() {
        assert!(verify_bangumi_data_payload(b"").is_err());
        assert!(verify_bangumi_data_payload(b"not json").is_err());
        assert!(verify_bangumi_data_payload(b"{}").is_err());
        assert!(verify_bangumi_data_payload(b"{\"items\":42}").is_err());
        // Valid structure: top-level object with an "items" array.
        assert!(verify_bangumi_data_payload(b"{\"items\":[]}").is_ok());
        assert!(verify_bangumi_data_payload(b"{\"items\":[{\"title\":\"A\"}]}").is_ok());
    }

    #[test]
    fn atomic_write_bytes_replaces_existing_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("cache.json");
        std::fs::write(&path, b"old").unwrap();

        atomic_write_bytes(&path, b"new content").unwrap();

        let written = std::fs::read(&path).unwrap();
        assert_eq!(written, b"new content");
        // The .tmp staging file should not linger after a successful write.
        let leftovers: Vec<_> = std::fs::read_dir(dir.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_name().to_string_lossy().contains(".tmp."))
            .collect();
        assert!(
            leftovers.is_empty(),
            "tmp staging file should be cleaned up, found: {:?}",
            leftovers.iter().map(|e| e.path()).collect::<Vec<_>>()
        );
    }

    #[test]
    fn failure_marker_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let cache_dir = dir.path().to_string_lossy().to_string();
        // No marker yet.
        assert!(last_failure_age_secs(&cache_dir).is_none());

        write_failure_marker(&cache_dir);
        let age = last_failure_age_secs(&cache_dir).expect("age should be parseable");
        assert!(
            age < 5,
            "freshly written marker should report age < 5s, got {}",
            age
        );

        clear_failure_marker(&cache_dir);
        assert!(last_failure_age_secs(&cache_dir).is_none());
    }

    #[test]
    fn failure_marker_tolerates_garbage() {
        let dir = tempfile::tempdir().unwrap();
        let cache_dir = dir.path().to_string_lossy().to_string();
        std::fs::write(bangumi_data_failure_marker_path(&cache_dir), "not-an-epoch").unwrap();
        // Garbage in the marker must NOT cause a panic; the helper should
        // treat it as "unknown" (None) and let the retry proceed.
        assert!(last_failure_age_secs(&cache_dir).is_none());
    }

    /// `get_or_load_bangumi_data_blocking` parses the on-disk file once
    /// and reuses the `Arc` for every subsequent call. `invalidate_bangumi_data_cache`
    /// forces a re-parse on the next call. This is the property the
    /// schedule + sites-index unification relies on.
    ///
    /// Serialized via a `Mutex` because the function reads from a
    /// process-global config slot, which cargo's parallel test runner
    /// would otherwise have other tests clobber mid-run.
    #[test]
    fn get_or_load_bangumi_data_caches_arc_and_respects_invalidate() {
        use crate::api::config::init_config;
        use std::sync::Arc as StdArc;

        let _guard = TEST_CONFIG_LOCK.lock().unwrap_or_else(|e| e.into_inner());

        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        let json_path = dir.path().join("bangumi-data.json");
        std::fs::write(
            &json_path,
            br#"{"items":[{"title":"A","titleTranslate":{"zh-Hans":[],"zh-Hant":[]},"type":"tv","officialSite":"","begin":"2026-04-04T16:00:00.000Z","broadcast":"","sites":[],"id":null}]}"#,
        )
        .unwrap();

        invalidate_bangumi_data_cache();
        let first: StdArc<BangumiDataJson> =
            get_or_load_bangumi_data_blocking().expect("first load should succeed");
        assert_eq!(first.items.len(), 1);

        // Second call must return the same `Arc` (pointer identity) —
        // the kernel page cache and serde_json parse are reused.
        let second: StdArc<BangumiDataJson> = get_or_load_bangumi_data_blocking().unwrap();
        assert!(StdArc::ptr_eq(&first, &second));

        // After invalidation the next call reparses. The contents are
        // identical but the `Arc` is fresh.
        invalidate_bangumi_data_cache();
        let third: StdArc<BangumiDataJson> = get_or_load_bangumi_data_blocking().unwrap();
        assert!(!StdArc::ptr_eq(&first, &third));
        assert_eq!(third.items.len(), 1);
    }

    /// `get_or_load_bangumi_data_blocking` returns `Err` when the cache
    /// file is absent — callers fall through to download/retry instead
    /// of panicking. See the `caches_arc_*` test for the lock rationale.
    #[test]
    fn get_or_load_bangumi_data_errors_when_file_missing() {
        use crate::api::config::init_config;

        let _guard = TEST_CONFIG_LOCK.lock().unwrap_or_else(|e| e.into_inner());

        let dir = tempfile::tempdir().unwrap();
        init_config(
            dir.path().to_string_lossy().to_string(),
            dir.path().to_string_lossy().to_string(),
        );
        // No bangumi-data.json in the temp dir.
        invalidate_bangumi_data_cache();
        let err = get_or_load_bangumi_data_blocking().unwrap_err();
        assert!(
            err.to_string().contains("bangumi-data.json not cached"),
            "unexpected error: {err}"
        );
    }
}
