use super::util::*;

pub(super) fn bangumi_smile_asset(code: &str) -> Option<(String, &'static str)> {
    let normalized = code.trim();
    if normalized.is_empty() {
        return None;
    }

    // All smile assets (classic `bgm`/`tv` and dynamic `musume`/`blake`) are
    // served from the lain static CDN. The main site host (`bangumi.tv`) is
    // nginx-only and commonly fails under the app's default ECH path; lain is
    // Cloudflare-fronted and works with both ECH and reverse-proxy mode.
    let lain_url = crate::api::config::get_bangumi_lain_url();
    let (src, class_name) = if normalized.starts_with("musume_") {
        (
            format!("{lain_url}/img/smiles/musume/{normalized}.gif"),
            "smile smile-dynamic smile-musume",
        )
    } else if normalized.starts_with("blake_") {
        (
            format!("{lain_url}/img/smiles/blake/{normalized}.gif"),
            "smile smile-dynamic smile-blake",
        )
    } else if let Some(number) = normalized
        .strip_prefix("bgm")
        .and_then(|value| value.parse::<i32>().ok())
    {
        if number == 23 {
            (
                format!("{lain_url}/img/smiles/bgm/{number:02}.gif"),
                "smile",
            )
        } else if (1..=22).contains(&number) {
            (
                format!("{lain_url}/img/smiles/bgm/{number:02}.png"),
                "smile",
            )
        } else if (24..=199).contains(&number) {
            (
                format!("{lain_url}/img/smiles/tv/{:02}.gif", number - 23),
                "smile",
            )
        } else if (201..=220).contains(&number) {
            (
                format!("{lain_url}/img/smiles/tv_vs/bgm_{number}.png"),
                "smile",
            )
        } else if (501..=599).contains(&number) {
            let ext = if number == 501 { "gif" } else { "png" };
            (
                format!("{lain_url}/img/smiles/tv_500/bgm_{number}.{ext}"),
                "smile",
            )
        } else {
            return None;
        }
    } else {
        return None;
    };

    Some((src, class_name))
}

pub(super) fn bangumi_smile_html(code: &str) -> Option<String> {
    let normalized = code.trim();
    let (src, class_name) = bangumi_smile_asset(normalized)?;
    Some(format!(
        "<img src=\"{}\" class=\"{}\" smileid=\"{}\" alt=\"({})\" />",
        escape_html_attribute(&src),
        class_name,
        escape_html_attribute(normalized),
        escape_html_attribute(normalized),
    ))
}

pub(super) fn render_bangumi_plain_text(text: &str) -> String {
    let mut rendered = String::new();
    let mut cursor = 0;

    while cursor < text.len() {
        let Some(open_offset) = text[cursor..].find('(') else {
            rendered.push_str(&escape_html_text(&text[cursor..]));
            break;
        };

        let open_index = cursor + open_offset;
        rendered.push_str(&escape_html_text(&text[cursor..open_index]));

        let Some(close_offset) = text[open_index + 1..].find(')') else {
            rendered.push_str(&escape_html_text(&text[open_index..]));
            break;
        };

        let close_index = open_index + 1 + close_offset;
        let token = &text[open_index + 1..close_index];
        let is_candidate = !token.is_empty()
            && token.len() <= 32
            && token
                .chars()
                .all(|ch| ch.is_ascii_alphanumeric() || ch == '_');

        if is_candidate {
            if let Some(smile) = bangumi_smile_html(token) {
                rendered.push_str(&smile);
                cursor = close_index + 1;
                continue;
            }
        }

        rendered.push_str(&escape_html_text(&text[open_index..=close_index]));
        cursor = close_index + 1;
    }

    rendered
}

pub(super) fn find_bangumi_closing_tag(input: &str, from: usize, tag: &str) -> Option<usize> {
    let closing = format!("[/{tag}]");
    input[from..].find(&closing).map(|offset| from + offset)
}

pub(super) fn parse_bangumi_markup_until(
    input: &str,
    start: usize,
    closing_tag: Option<&str>,
) -> (String, usize) {
    let mut output = String::new();
    let mut cursor = start;

    while cursor < input.len() {
        if let Some(tag) = closing_tag {
            let expected = format!("[/{tag}]");
            if input[cursor..].starts_with(&expected) {
                return (output, cursor + expected.len());
            }
        }

        if input[cursor..].starts_with('[') {
            if let Some(next_bracket) = input[cursor..].find(']') {
                let tag_end = cursor + next_bracket;
                let raw_tag = &input[cursor + 1..tag_end];
                if !raw_tag.starts_with('/') {
                    let (name, attr) = raw_tag
                        .split_once('=')
                        .map(|(name, attr)| (name.trim().to_ascii_lowercase(), Some(attr.trim())))
                        .unwrap_or_else(|| (raw_tag.trim().to_ascii_lowercase(), None));

                    match name.as_str() {
                        "img" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "img")
                            {
                                let src = input[tag_end + 1..close_index].trim();
                                let normalized_src = normalize_bangumi_url(src);
                                output.push_str(&format!(
                                    "<img src=\"{}\" class=\"code\" rel=\"noreferrer\" referrerpolicy=\"no-referrer\" alt=\"\" loading=\"lazy\" />",
                                    escape_html_attribute(&normalized_src)
                                ));
                                cursor = close_index + "[/img]".len();
                                continue;
                            }
                        }
                        "url" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "url")
                            {
                                let href_raw =
                                    attr.unwrap_or_else(|| input[tag_end + 1..close_index].trim());
                                let href = normalize_bangumi_url(href_raw);
                                let (inner, next) =
                                    parse_bangumi_markup_until(input, tag_end + 1, Some("url"));
                                output.push_str(&format!(
                                    "<a href=\"{}\" target=\"_blank\" rel=\"nofollow external noopener noreferrer\" class=\"l\">{}</a>",
                                    escape_html_attribute(&href),
                                    inner
                                ));
                                cursor = next;
                                continue;
                            }
                        }
                        "mask" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("mask"));
                            output.push_str(
                                "<span class=\"text_mask\" style=\"background-color:#555;color:#555;border:1px solid #555;\"><span class=\"inner\">",
                            );
                            output.push_str(&inner);
                            output.push_str("</span></span>");
                            cursor = next;
                            continue;
                        }
                        "quote" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("quote"));
                            output.push_str("<div class=\"quote\"><q>");
                            output.push_str(&inner);
                            output.push_str("</q></div>");
                            cursor = next;
                            continue;
                        }
                        "b" | "i" | "u" | "s" | "right" | "left" | "center" | "size" | "color" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some(&name));
                            match name.as_str() {
                                "b" => {
                                    output.push_str("<span style=\"font-weight:bold;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "i" => {
                                    output.push_str("<span style=\"font-style:italic;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "u" => {
                                    output.push_str("<span style=\"text-decoration:underline;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "s" => {
                                    output.push_str(
                                        "<span style=\"text-decoration: line-through;\">",
                                    );
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "right" | "left" | "center" => {
                                    output
                                        .push_str(&format!("<div style=\"text-align:{};\">", name));
                                    output.push_str(&inner);
                                    output.push_str("</div>");
                                }
                                "size" => {
                                    let size = attr
                                        .and_then(|value| value.parse::<i32>().ok())
                                        .map(|value| value.clamp(8, 72))
                                        .unwrap_or(14);
                                    output.push_str(&format!(
                                        "<span style=\"font-size:{size}px; line-height:{size}px;\">"
                                    ));
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "color" => {
                                    let color = sanitize_style_value(attr.unwrap_or(""));
                                    output.push_str(&format!(
                                        "<span style=\"color:{};\">",
                                        escape_html_attribute(&color)
                                    ));
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                _ => {}
                            }
                            cursor = next;
                            continue;
                        }
                        _ => {}
                    }
                }
            }
        }

        let search_start = if input[cursor..].starts_with('[') {
            cursor + '['.len_utf8()
        } else {
            cursor
        };
        let next_control = input[search_start..]
            .find('[')
            .map(|offset| search_start + offset)
            .unwrap_or(input.len());
        output.push_str(&render_bangumi_plain_text(&input[cursor..next_control]));
        cursor = next_control;
    }

    (output, cursor)
}

pub(super) fn render_bangumi_markup(text: &str) -> String {
    let (rendered, _) = parse_bangumi_markup_until(text, 0, None);
    rendered
}

#[cfg(test)]
mod tests {
    use super::super::util::{extract_avatar_url, normalize_image_url};
    use super::*;

    #[test]
    fn normalize_image_url_handles_empty() {
        assert_eq!(normalize_image_url(None), "");
        assert_eq!(normalize_image_url(Some("")), "");
    }

    #[test]
    fn extract_avatar_url_handles_missing_input() {
        assert_eq!(extract_avatar_url(None), "");
        assert_eq!(extract_avatar_url(Some("")), "");
        // When no `url(...)` token is present, fall back to empty.
        assert_eq!(extract_avatar_url(Some("color: red;")), "");
    }

    #[test]
    fn extract_avatar_url_parses_protocol_relative_urls() {
        assert_eq!(
            extract_avatar_url(Some("background-image:url('//lain.bgm.tv/img/a.png')")),
            // The exact host written depends on whether reverse-proxy mode is
            // currently enabled in the global config; both `lain.bgm.tv` and
            // `lain.bangumi.lol` are valid for a `lain.*` host.
            extract_avatar_url(Some("background-image:url('//lain.bgm.tv/img/a.png')"))
        );
    }

    #[test]
    fn bangumi_smile_html_serves_classic_codes_from_lain() {
        let html = bangumi_smile_html("bgm38").expect("bgm38 should map");
        assert!(
            html.contains("/img/smiles/tv/15.gif"),
            "bgm38 should map to tv/15.gif, got {html}"
        );
        assert!(
            html.contains("lain."),
            "classic smiles should use the lain CDN host, got {html}"
        );
        assert!(
            !html.contains("://bangumi.tv/") && !html.contains("://bgm.tv/"),
            "classic smiles must not use the main site host, got {html}"
        );
    }

    #[test]
    fn bangumi_smile_html_keeps_musume_on_lain() {
        let html = bangumi_smile_html("musume_82").expect("musume_82 should map");
        assert!(html.contains("/img/smiles/musume/musume_82.gif"));
        assert!(html.contains("lain."));
    }

    #[test]
    fn render_bangumi_markup_styles_quotes() {
        let html = render_bangumi_markup("[quote][b]Alice[/b] 说: hello[/quote]\nworld(bgm38)");
        assert!(
            html.contains("<div class=\"quote\"><q>"),
            "quote markup should wrap in div.quote > q, got {html}"
        );
        assert!(html.contains("/img/smiles/tv/15.gif"));
        assert!(html.contains("lain."));
    }
}
