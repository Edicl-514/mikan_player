use super::types::*;
use chrono::{Local, TimeZone};

pub(super) const BANGUMI_NEXT_COMMENTS_PAGE_SIZE: i64 = 20;

pub(super) fn bangumi_next_url(path: &str) -> String {
    format!("{}{}", crate::api::config::get_bangumi_next_url(), path)
}

pub(super) fn format_bangumi_timestamp(timestamp: i64) -> String {
    Local
        .timestamp_opt(timestamp, 0)
        .single()
        .map(|dt| dt.format("%Y-%m-%d %H:%M").to_string())
        .unwrap_or_else(|| timestamp.to_string())
}

pub(super) fn escape_html_attribute(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());

    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\n' => escaped.push_str("&#10;"),
            '\r' => {}
            _ => escaped.push(ch),
        }
    }

    escaped
}

pub(super) fn escape_html_text(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());

    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\n' => escaped.push_str("<br>"),
            '\r' => {}
            _ => escaped.push(ch),
        }
    }

    escaped
}

pub(super) fn parse_bangumi_images(images_data: &serde_json::Value) -> Option<BangumiImages> {
    if !images_data.is_object() {
        return None;
    }
    Some(BangumiImages {
        small: normalize_image_url(images_data["small"].as_str()),
        grid: normalize_image_url(images_data["grid"].as_str()),
        large: normalize_image_url(images_data["large"].as_str()),
        medium: normalize_image_url(images_data["medium"].as_str()),
        common: normalize_image_url(images_data["common"].as_str()),
    })
}

pub(super) fn normalize_image_url(value: Option<&str>) -> String {
    let raw = value.unwrap_or("").trim();
    if raw.is_empty() {
        return String::new();
    }
    crate::api::config::rewrite_bangumi_url_if_proxied(raw)
}

pub(super) fn normalize_avatar_url(value: Option<&str>) -> String {
    let Some(raw) = value else {
        return String::new();
    };
    if raw.is_empty() {
        return String::new();
    }
    // Avatars served from `lain.bgm.tv` etc. need to be remapped to the
    // reverse-proxy host when proxy mode is enabled.
    crate::api::config::rewrite_bangumi_url_if_proxied(raw)
}

pub(super) fn normalize_bangumi_url(value: &str) -> String {
    if value.is_empty() {
        return value.to_string();
    }

    let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
    if rewritten == value {
        // Not a bangumi host (or protocol-relative); fall back to the protocol-relative
        // and relative-path handling below.
        if value.starts_with("//") {
            format!("https:{value}")
        } else if value.starts_with('/') {
            format!("{}{}", crate::api::config::get_bangumi_url(), value)
        } else {
            value.to_string()
        }
    } else {
        rewritten
    }
}

/// Pull a `background-image: url('...')` style value out of a `style` attribute
/// and resolve it into an absolute URL with any bangumi host remapped.
pub(super) fn extract_avatar_url(style: Option<&str>) -> String {
    let Some(style) = style else {
        return String::new();
    };
    let Some(start) = style.find("url('") else {
        return String::new();
    };
    let after = &style[start + 5..];
    let Some(end) = after.find("')") else {
        return String::new();
    };
    let raw = &after[..end];
    let absolute = if raw.starts_with("//") {
        format!("https:{raw}")
    } else {
        raw.to_string()
    };
    crate::api::config::rewrite_bangumi_url_if_proxied(&absolute)
}

pub(super) fn sanitize_style_value(value: &str) -> String {
    value
        .chars()
        .filter(|ch| {
            ch.is_ascii_alphanumeric()
                || matches!(ch, '#' | ',' | '.' | '%' | '-' | '_' | ' ' | '(' | ')')
        })
        .collect()
}

pub(super) fn truncate(s: &str, max: usize) -> &str {
    if s.len() <= max {
        s
    } else {
        // Find a char boundary near `max` to avoid splitting UTF-8.
        let mut idx = max;
        while idx > 0 && !s.is_char_boundary(idx) {
            idx -= 1;
        }
        &s[..idx]
    }
}
