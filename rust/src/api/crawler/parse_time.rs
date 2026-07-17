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
    if item.title.is_empty() {
        return None;
    }
    let zh_title = item
        .title_translate
        .zh_hans
        .first()
        .cloned()
        .or_else(|| item.title_translate.zh_hant.first().cloned())
        .unwrap_or_default();
    let (title, sub_title) = if zh_title.is_empty() {
        (item.title.clone(), None)
    } else {
        (zh_title, Some(item.title.clone()))
    };
    let (broadcast_day, broadcast_time) = if item.broadcast.is_empty() {
        parse_broadcast_from_rfc(&item.begin)
    } else {
        parse_broadcast_from_rfc(&item.broadcast)
    };
    let mut bangumi_id = None;
    let mut mikan_id = None;
    for site in &item.sites {
        match site.site.as_str() {
            "bangumi" => bangumi_id = Some(site.id.clone()),
            "mikan" => mikan_id = Some(site.id.clone()),
            _ => {}
        }
    }
    let site_url = if item.official_site.is_empty() {
        None
    } else {
        Some(item.official_site.clone())
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
        if q_num >= 1 && q_num <= 4 {
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
