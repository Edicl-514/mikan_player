use super::types::*;
use chrono::Datelike;

pub(super) const QUARTER_NAMES: [&str; 4] = ["1月", "4月", "7月", "10月"];
pub(super) const CST_OFFSET: chrono::FixedOffset = chrono::FixedOffset::east_opt(8 * 3600).unwrap();

/// Parse a `begin` timestamp as a UTC instant. Accepts both the ISO-8601 form
/// returned by the bgmlist.com API (`2025-09-30T16:35:00.000Z`, with or without
/// the trailing `Z`) and the legacy `YYYY/M/D H:mm:ss` form stored by the npm
/// `bangumi-data` package. Both forms denote a UTC instant.
pub(super) fn parse_begin_utc(begin: &str) -> Option<chrono::DateTime<chrono::Utc>> {
    let s = begin.trim();
    if s.is_empty() {
        return None;
    }
    // RFC3339 with explicit zone (API form).
    if let Ok(dt) = s.parse::<chrono::DateTime<chrono::Utc>>() {
        return Some(dt);
    }
    // ISO-8601 naive (no zone) — treat as UTC.
    for fmt in &["%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S"] {
        if let Ok(ndt) = chrono::NaiveDateTime::parse_from_str(s, fmt) {
            return Some(ndt.and_utc());
        }
    }
    // Legacy npm package form: "1962/12/31 16:00:00".
    if let Ok(ndt) = chrono::NaiveDateTime::parse_from_str(s, "%Y/%m/%d %H:%M:%S") {
        return Some(ndt.and_utc());
    }
    None
}

/// Derive the CST (+8) weekday name and `HH:MM` time from a UTC instant.
pub(super) fn datetime_to_cst_day_time(
    dt: chrono::DateTime<chrono::Utc>,
) -> (Option<String>, Option<String>) {
    let cst = dt.with_timezone(&CST_OFFSET);
    let weekday = match cst.weekday().num_days_from_monday() {
        0 => "周一",
        1 => "周二",
        2 => "周三",
        3 => "周四",
        4 => "周五",
        5 => "周六",
        6 => "周日",
        _ => "",
    };
    let time = cst.format("%H:%M").to_string();
    (
        if weekday.is_empty() {
            None
        } else {
            Some(weekday.to_string())
        },
        Some(time),
    )
}

pub(super) fn parse_broadcast_from_rfc(broadcast: &str) -> (Option<String>, Option<String>) {
    let broadcast = broadcast.trim();
    if broadcast.is_empty() {
        return (None, None);
    }
    // bgmlist `broadcast` is `R/<ISO>/P7D`; the first segment is the start
    // instant. Fall through to `parse_begin_utc` so a bare timestamp (no `R/`
    // prefix) — including the legacy `begin` form — also parses.
    let instant_str = if let Some(rest) = broadcast.strip_prefix("R/") {
        rest.split('/').next().unwrap_or(rest)
    } else {
        broadcast
    };
    match parse_begin_utc(instant_str) {
        Some(dt) => datetime_to_cst_day_time(dt),
        None => (None, None),
    }
}

pub(super) fn bgmlist_item_to_anime_info(item: &BgmlistItem) -> Option<AnimeInfo> {
    let original_title = item.title.trim();
    if original_title.is_empty() {
        return None;
    }
    let zh_title = item
        .title_translate
        .zh_hans
        .iter()
        .chain(item.title_translate.zh_hant.iter())
        .map(|title| title.trim())
        .find(|title| !title.is_empty())
        .map(str::to_string)
        .unwrap_or_default();
    let (title, sub_title) = if zh_title.is_empty() {
        (original_title.to_string(), None)
    } else {
        (zh_title, Some(original_title.to_string()))
    };
    let parsed_broadcast = parse_broadcast_from_rfc(&item.broadcast);
    let (broadcast_day, broadcast_time) =
        if parsed_broadcast.0.is_some() || parsed_broadcast.1.is_some() {
            parsed_broadcast
        } else {
            parse_broadcast_from_rfc(&item.begin)
        };
    let valid_site_id = |site_name: &str| {
        item.sites
            .iter()
            .filter(|site| site.site == site_name)
            .map(|site| site.id.trim())
            .find(|id| id.parse::<i64>().ok().is_some_and(|value| value > 0))
            .map(str::to_string)
    };
    let bangumi_id = valid_site_id("bangumi");
    let mikan_id = valid_site_id("mikan");
    let site_url = match item.official_site.trim() {
        "" => None,
        value => Some(value.to_string()),
    };
    Some(AnimeInfo {
        title,
        sub_title,
        bangumi_id,
        mikan_id,
        cover_url: None,
        site_url,
        broadcast_day,
        broadcast_time,
        score: None,
        rank: None,
        tags: Vec::new(),
        full_json: None,
    })
}

pub(super) fn quarter_to_title(quarter: &str) -> String {
    let re = regex::Regex::new(r"^(\d{4})q([1-4])$").unwrap();
    if let Some(caps) = re.captures(quarter) {
        let year = caps.get(1).unwrap().as_str();
        let q_num: usize = caps.get(2).unwrap().as_str().parse().unwrap_or(0);
        if (1..=4).contains(&q_num) {
            return format!("{}年{}", year, QUARTER_NAMES[q_num - 1]);
        }
    }
    quarter.to_string()
}

pub(super) fn filter_items_by_quarter<'a>(
    items: &'a [BgmlistItem],
    year_quarter: &str,
) -> Vec<&'a BgmlistItem> {
    let re = regex::Regex::new(r"^(\d{4})q([1-4])$").unwrap();
    let caps = match re.captures(year_quarter) {
        Some(c) => c,
        None => return Vec::new(),
    };
    let year: i32 = caps.get(1).unwrap().as_str().parse().unwrap_or(0);
    let q: u32 = caps.get(2).unwrap().as_str().parse().unwrap_or(0);
    let (start_month, end_month) = match q {
        1 => (1, 3),
        2 => (4, 6),
        3 => (7, 9),
        4 => (10, 12),
        _ => return Vec::new(),
    };

    items
        .iter()
        .filter(|item| {
            // Parse the UTC instant (ISO or legacy form) then convert to CST
            // (+8) before comparing the month, so a show whose UTC begin falls
            // on the last day of a quarter still groups with the next quarter
            // exactly like the bgmlist.com API does.
            let Some(dt) = parse_begin_utc(&item.begin) else {
                return false;
            };
            let cst = dt.with_timezone(&CST_OFFSET);
            cst.year() == year && cst.month() >= start_month && cst.month() <= end_month
        })
        .collect()
}

pub(super) fn parse_broadcast_parts(raw: Option<&str>) -> (Option<String>, Option<String>) {
    let Some(raw) = raw.map(str::trim).filter(|value| !value.is_empty()) else {
        return (None, None);
    };

    let normalized = raw.replace("每周", "周");
    let mut broadcast_day = None;
    let mut broadcast_time = None;

    for part in normalized.split_whitespace() {
        if part.starts_with('周') {
            broadcast_day = Some(part.to_string());
        } else if part.contains(':') {
            broadcast_time = Some(part.to_string());
        }
    }

    if broadcast_day.is_none() && broadcast_time.is_none() {
        if normalized.contains(':') {
            broadcast_time = Some(normalized);
        } else {
            broadcast_day = Some(normalized);
        }
    }

    (broadcast_day, broadcast_time)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(title: &str, begin: &str) -> BgmlistItem {
        BgmlistItem {
            title: title.to_string(),
            begin: begin.to_string(),
            ..BgmlistItem::default()
        }
    }

    #[test]
    fn parses_rfc3339_offsets_naive_iso_and_legacy_as_utc_instants() {
        let utc = parse_begin_utc("2025-07-01T00:00:00Z").unwrap();
        assert_eq!(parse_begin_utc("2025-06-30T20:00:00-04:00").unwrap(), utc);
        assert_eq!(parse_begin_utc("2025-07-01T09:00:00+09:00").unwrap(), utc);
        assert_eq!(parse_begin_utc("2025-07-01T00:00:00").unwrap(), utc);
        assert_eq!(parse_begin_utc("2025/7/1 00:00:00").unwrap(), utc);
    }

    #[test]
    fn rejects_empty_and_invalid_calendar_timestamps() {
        for value in [
            "",
            "not-a-date",
            "2025-02-29T00:00:00Z",
            "2025/13/1 00:00:00",
        ] {
            assert!(
                parse_begin_utc(value).is_none(),
                "{value:?} should be invalid"
            );
        }
        assert!(parse_begin_utc("2024-02-29T00:00:00Z").is_some());
    }

    #[test]
    fn converts_utc_to_fixed_cst_without_dst_drift() {
        let winter = parse_begin_utc("2025-01-05T16:05:00Z").unwrap();
        let summer = parse_begin_utc("2025-07-06T16:05:00Z").unwrap();
        assert_eq!(
            datetime_to_cst_day_time(winter),
            (Some("周一".to_string()), Some("00:05".to_string()))
        );
        assert_eq!(
            datetime_to_cst_day_time(summer),
            (Some("周一".to_string()), Some("00:05".to_string()))
        );
    }

    #[test]
    fn quarter_filter_uses_cst_at_quarter_and_year_boundaries() {
        let items = vec![
            item("q1-last", "2025-03-31T15:59:59Z"),
            item("q2-first", "2025-03-31T16:00:00Z"),
            item("next-year", "2025-12-31T16:00:00Z"),
            item("invalid", "2025-02-30T00:00:00Z"),
        ];

        let q1: Vec<_> = filter_items_by_quarter(&items, "2025q1")
            .into_iter()
            .map(|item| item.title.as_str())
            .collect();
        let q2: Vec<_> = filter_items_by_quarter(&items, "2025q2")
            .into_iter()
            .map(|item| item.title.as_str())
            .collect();
        let next_q1: Vec<_> = filter_items_by_quarter(&items, "2026q1")
            .into_iter()
            .map(|item| item.title.as_str())
            .collect();

        assert_eq!(q1, ["q1-last"]);
        assert_eq!(q2, ["q2-first"]);
        assert_eq!(next_q1, ["next-year"]);
        assert!(filter_items_by_quarter(&items, "2025q5").is_empty());
    }

    #[test]
    fn item_normalization_skips_blank_values_and_falls_back_from_bad_broadcast() {
        let mut value = item("  Original  ", "2025-03-31T16:30:00Z");
        value.title_translate.zh_hans = vec![" ".to_string(), " 中文名 ".to_string()];
        value.broadcast = "invalid recurrence".to_string();
        value.official_site = " https://example.test/show ".to_string();
        value.sites = vec![
            BgmlistSite {
                site: "bangumi".to_string(),
                id: "".to_string(),
                url: None,
                begin: None,
                broadcast: None,
                comment: None,
                regions: None,
            },
            BgmlistSite {
                site: "bangumi".to_string(),
                id: "123".to_string(),
                url: None,
                begin: None,
                broadcast: None,
                comment: None,
                regions: None,
            },
        ];

        let anime = bgmlist_item_to_anime_info(&value).unwrap();
        assert_eq!(anime.title, "中文名");
        assert_eq!(anime.sub_title.as_deref(), Some("Original"));
        assert_eq!(anime.bangumi_id.as_deref(), Some("123"));
        assert_eq!(anime.broadcast_day.as_deref(), Some("周二"));
        assert_eq!(anime.broadcast_time.as_deref(), Some("00:30"));
        assert_eq!(anime.site_url.as_deref(), Some("https://example.test/show"));
        assert!(bgmlist_item_to_anime_info(&item("   ", "2025-01-01T00:00:00Z")).is_none());
    }

    #[test]
    fn broadcast_parsers_accept_recurrence_and_legacy_display_parts() {
        assert_eq!(
            parse_broadcast_from_rfc("R/2025-01-05T16:05:00Z/P7D"),
            (Some("周一".to_string()), Some("00:05".to_string()))
        );
        assert_eq!(
            parse_broadcast_parts(Some(" 每周日 01:30 ")),
            (Some("周日".to_string()), Some("01:30".to_string()))
        );
        assert_eq!(parse_broadcast_parts(Some("  ")), (None, None));
    }

    #[test]
    fn quarter_titles_only_normalize_supported_quarters() {
        assert_eq!(quarter_to_title("2025q1"), "2025年1月");
        assert_eq!(quarter_to_title("2025q4"), "2025年10月");
        assert_eq!(quarter_to_title("2025q0"), "2025q0");
        assert_eq!(quarter_to_title("bad"), "bad");
    }
}
