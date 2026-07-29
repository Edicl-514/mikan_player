use super::types::*;
use chrono::{Local, TimeZone};

pub(super) const BANGUMI_NEXT_COMMENTS_PAGE_SIZE: i64 = 20;

pub(super) fn bangumi_next_request(path: &str) -> (String, Option<String>, Option<i64>) {
    let context = crate::api::config::get_bangumi_next_request_context();
    (
        format!("{}{}", context.base_url, path),
        context.access_token,
        context.user_id,
    )
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

pub(super) fn json_i32(value: &serde_json::Value) -> Option<i32> {
    value.as_i64().and_then(|value| i32::try_from(value).ok())
}

pub(super) fn json_i64(value: &serde_json::Value) -> Option<i64> {
    value.as_i64()
}

pub(super) fn parse_infobox(value: &serde_json::Value) -> Vec<InfoboxItem> {
    value
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let key = item["key"].as_str()?.trim();
            if key.is_empty() {
                return None;
            }

            let value = match &item["value"] {
                serde_json::Value::String(value) => value.trim().to_string(),
                serde_json::Value::Array(values) => values
                    .iter()
                    .filter_map(|value| match value {
                        serde_json::Value::String(value) => {
                            let value = value.trim();
                            (!value.is_empty()).then(|| value.to_string())
                        }
                        serde_json::Value::Object(value) => {
                            let key = value
                                .get("k")
                                .and_then(|value| value.as_str())
                                .unwrap_or("")
                                .trim();
                            let value = value
                                .get("v")
                                .and_then(|value| value.as_str())
                                .unwrap_or("")
                                .trim();
                            match (key.is_empty(), value.is_empty()) {
                                (_, true) => None,
                                (true, false) => Some(value.to_string()),
                                (false, false) => Some(format!("{key}: {value}")),
                            }
                        }
                        _ => None,
                    })
                    .collect::<Vec<_>>()
                    .join(", "),
                _ => String::new(),
            };

            (!value.is_empty()).then(|| InfoboxItem {
                key: key.to_string(),
                value,
            })
        })
        .collect()
}

pub(super) fn normalize_image_url(value: Option<&str>) -> String {
    let raw = value.unwrap_or("").trim();
    if raw.is_empty() {
        return String::new();
    }
    normalize_bangumi_url(raw)
}

pub(super) fn parse_user_object<'a>(item: &'a serde_json::Value) -> &'a serde_json::Value {
    if item["creator"].is_object() {
        &item["creator"]
    } else if item["user"].is_object() {
        &item["user"]
    } else {
        &serde_json::Value::Null
    }
}

pub(super) fn parse_user_name(user: &serde_json::Value) -> String {
    user["nickname"]
        .as_str()
        .filter(|value| !value.is_empty())
        .or_else(|| user["username"].as_str().filter(|value| !value.is_empty()))
        .or_else(|| user["name"].as_str().filter(|value| !value.is_empty()))
        .unwrap_or("")
        .to_string()
}

pub(super) fn parse_user_id(user: &serde_json::Value) -> String {
    user["username"]
        .as_str()
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .or_else(|| json_i64(&user["id"]).map(|id| id.to_string()))
        .unwrap_or_default()
}

pub(super) fn parse_user_avatar(user: &serde_json::Value) -> String {
    let avatar = &user["avatar"];
    if let Some(url) = avatar.as_str() {
        normalize_avatar_url(Some(url))
    } else if avatar.is_object() {
        normalize_avatar_url(
            avatar["large"]
                .as_str()
                .or_else(|| avatar["medium"].as_str())
                .or_else(|| avatar["small"].as_str()),
        )
    } else {
        String::new()
    }
}

pub(super) fn normalize_avatar_url(value: Option<&str>) -> String {
    let Some(raw) = value else {
        return String::new();
    };
    let raw = raw.trim();
    if raw.is_empty() {
        return String::new();
    }
    normalize_bangumi_url(raw)
}

pub(super) fn normalize_bangumi_url(value: &str) -> String {
    let value = value.trim();
    if value.is_empty() {
        return String::new();
    }

    let absolute = if value.starts_with("//") {
        format!("https:{value}")
    } else if value.starts_with('/') {
        format!("{}{}", crate::api::config::get_bangumi_url(), value)
    } else {
        value.to_string()
    };
    crate::api::config::rewrite_bangumi_url_if_proxied(&absolute)
}

/// Pull a `background-image: url('...')` style value out of a `style` attribute
/// and resolve it into an absolute URL with any bangumi host remapped.
pub(super) fn extract_avatar_url(style: Option<&str>) -> String {
    let Some(style) = style else {
        return String::new();
    };
    let Some(start) = style.find("url(") else {
        return String::new();
    };
    let Some(end) = style[start + 4..].find(')') else {
        return String::new();
    };
    let raw = style[start + 4..start + 4 + end].trim();
    let raw = raw
        .strip_prefix("&quot;")
        .and_then(|value| value.strip_suffix("&quot;"))
        .or_else(|| {
            raw.strip_prefix('\'')
                .and_then(|value| value.strip_suffix('\''))
        })
        .or_else(|| {
            raw.strip_prefix('"')
                .and_then(|value| value.strip_suffix('"'))
        })
        .unwrap_or(raw)
        .trim();
    normalize_bangumi_url(raw)
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn json_i32_rejects_type_changes_and_overflow() {
        assert_eq!(json_i32(&json!(42)), Some(42));
        assert_eq!(json_i32(&json!(i64::from(i32::MAX) + 1)), None);
        assert_eq!(json_i32(&json!("42")), None);
        assert_eq!(json_i32(&serde_json::Value::Null), None);
    }

    #[test]
    fn infobox_normalization_handles_strings_objects_and_invalid_values() {
        let items = parse_infobox(&json!([
            {"key": " 别名 ", "value": [" A ", {"k": "日文", "v": " B "}, {"v": "C"}, null, 7]},
            {"key": "空", "value": []},
            {"key": "", "value": "ignored"},
            {"key": "生日", "value": " 7月19日 "}
        ]));

        assert_eq!(items.len(), 2);
        assert_eq!(items[0].key, "别名");
        assert_eq!(items[0].value, "A, 日文: B, C");
        assert_eq!(items[1].value, "7月19日");
        assert!(parse_infobox(&json!({"key": "not-an-array"})).is_empty());
    }

    #[test]
    fn avatar_style_parser_accepts_quote_variants_and_relative_urls() {
        let _config = crate::test_support::state::isolate_runtime_config();
        crate::api::config::set_bangumi_reverse_proxy(false);
        assert_eq!(
            extract_avatar_url(Some("background-image: url(\"//lain.bgm.tv/a.png\")")),
            "https://lain.bgm.tv/a.png"
        );
        assert_eq!(
            extract_avatar_url(Some("background:url(&quot;/img/avatar.png&quot;)")),
            format!("{}/img/avatar.png", crate::api::config::get_bangumi_url())
        );
        assert_eq!(
            extract_avatar_url(Some("background:url(https://lain.bgm.tv/a.png)")),
            "https://lain.bgm.tv/a.png"
        );
    }

    #[test]
    fn image_normalization_absolutizes_protocol_relative_urls_before_proxy_rewrite() {
        let _config = crate::test_support::state::isolate_runtime_config();
        crate::api::config::set_bangumi_reverse_proxy(false);
        assert_eq!(
            normalize_image_url(Some(" //lain.bgm.tv/a.jpg ")),
            "https://lain.bgm.tv/a.jpg"
        );

        crate::api::config::set_bangumi_reverse_proxy(true);
        assert_eq!(
            normalize_image_url(Some("//lain.bgm.tv/a.jpg")),
            "https://lain.bangumi.lol/a.jpg"
        );
    }
}
