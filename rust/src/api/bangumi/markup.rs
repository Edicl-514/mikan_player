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
        } else if (200..=220).contains(&number) {
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

fn escape_code_text(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());
    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\r' => {}
            _ => escaped.push(ch),
        }
    }
    escaped
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

pub(super) fn format_bangumi_photo_url(path: &str) -> String {
    let path = path.trim();
    if path.is_empty() {
        return String::new();
    }
    if path.starts_with("http://") || path.starts_with("https://") || path.starts_with("//") {
        normalize_bangumi_markup_url(path)
    } else {
        let clean_path = path.trim_start_matches('/');
        let lain_url = crate::api::config::get_bangumi_lain_url();
        normalize_bangumi_markup_url(&format!("{lain_url}/pic/photo/l/{clean_path}"))
    }
}

fn normalize_bangumi_markup_url(value: &str) -> String {
    let normalized = normalize_bangumi_url(value);
    let Ok(url) = url::Url::parse(&normalized) else {
        return String::new();
    };
    if matches!(url.scheme(), "http" | "https") && url.host_str().is_some() {
        normalized
    } else {
        String::new()
    }
}

pub(super) fn find_bangumi_closing_tag(input: &str, from: usize, tag: &str) -> Option<usize> {
    let closing = format!("[/{tag}]");
    input[from..].find(&closing).map(|offset| from + offset)
}

fn format_bangumi_list(inner: &str, is_ordered: bool) -> String {
    let tag = if is_ordered { "ol" } else { "ul" };
    let mut out = String::new();
    out.push_str(&format!("<{tag}>"));

    let parts: Vec<&str> = inner.split("[*]").collect();
    for (i, part) in parts.iter().enumerate() {
        let mut clean = part.trim();
        while clean.starts_with("<br />") || clean.starts_with("<br>") {
            clean = clean
                .trim_start_matches("<br />")
                .trim_start_matches("<br>")
                .trim();
        }
        while clean.ends_with("<br />") || clean.ends_with("<br>") {
            clean = clean
                .trim_end_matches("<br />")
                .trim_end_matches("<br>")
                .trim();
        }
        if i == 0 && clean.is_empty() {
            continue;
        }
        if !clean.is_empty() {
            out.push_str("<li>");
            out.push_str(clean);
            out.push_str("</li>");
        }
    }
    out.push_str(&format!("</{tag}>"));
    out
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
                                let normalized_src = normalize_bangumi_markup_url(src);
                                if !normalized_src.is_empty() {
                                    output.push_str(&format!(
                                        "<img src=\"{}\" class=\"code\" rel=\"noreferrer\" referrerpolicy=\"no-referrer\" alt=\"\" loading=\"lazy\" />",
                                        escape_html_attribute(&normalized_src)
                                    ));
                                }
                                cursor = close_index + "[/img]".len();
                                continue;
                            }
                        }
                        "photo" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "photo")
                            {
                                let path_raw = input[tag_end + 1..close_index].trim();
                                let path = if !path_raw.is_empty() {
                                    path_raw
                                } else {
                                    attr.unwrap_or("")
                                };
                                let photo_url = format_bangumi_photo_url(path);
                                if !photo_url.is_empty() {
                                    output.push_str(&format!(
                                        "<img src=\"{}\" class=\"code\" rel=\"noreferrer\" referrerpolicy=\"no-referrer\" alt=\"\" loading=\"lazy\" />",
                                        escape_html_attribute(&photo_url)
                                    ));
                                }
                                cursor = close_index + "[/photo]".len();
                                continue;
                            }
                        }
                        "code" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "code")
                            {
                                let code_content = &input[tag_end + 1..close_index];
                                output.push_str("<pre class=\"code\"><code>");
                                output.push_str(&escape_code_text(code_content));
                                output.push_str("</code></pre>");
                                cursor = close_index + "[/code]".len();
                                continue;
                            }
                        }
                        "hr" => {
                            output.push_str("<hr />");
                            if input[tag_end + 1..].starts_with("[/hr]") {
                                cursor = tag_end + 1 + "[/hr]".len();
                            } else {
                                cursor = tag_end + 1;
                            }
                            continue;
                        }
                        "url" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "url")
                            {
                                let href_raw =
                                    attr.unwrap_or_else(|| input[tag_end + 1..close_index].trim());
                                let href = normalize_bangumi_markup_url(href_raw);
                                let (inner, next) =
                                    parse_bangumi_markup_until(input, tag_end + 1, Some("url"));
                                if href.is_empty() {
                                    output.push_str(&inner);
                                } else {
                                    output.push_str(&format!(
                                        "<a href=\"{}\" target=\"_blank\" rel=\"nofollow external noopener noreferrer\" class=\"l\">{}</a>",
                                        escape_html_attribute(&href),
                                        inner
                                    ));
                                }
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
                        "list" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("list"));
                            let is_ordered = attr.map(|a| a == "1" || a == "a").unwrap_or(false);
                            output.push_str(&format_bangumi_list(&inner, is_ordered));
                            cursor = next;
                            continue;
                        }
                        "align" => {
                            let align_val = attr.unwrap_or("left").trim().to_ascii_lowercase();
                            let valid_align = match align_val.as_str() {
                                "center" => "center",
                                "right" => "right",
                                "justify" => "justify",
                                _ => "left",
                            };
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("align"));
                            output.push_str(&format!("<div style=\"text-align:{valid_align};\">"));
                            output.push_str(&inner);
                            output.push_str("</div>");
                            cursor = next;
                            continue;
                        }
                        "font" => {
                            let font_family = sanitize_style_value(attr.unwrap_or(""));
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("font"));
                            output.push_str(&format!(
                                "<span style=\"font-family:{};\">",
                                escape_html_attribute(&font_family)
                            ));
                            output.push_str(&inner);
                            output.push_str("</span>");
                            cursor = next;
                            continue;
                        }
                        "b" | "i" | "u" | "s" | "del" | "strikethrough" | "sub" | "sup"
                        | "right" | "left" | "center" | "size" | "color" => {
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
                                "s" | "del" | "strikethrough" => {
                                    output.push_str(
                                        "<span style=\"text-decoration: line-through;\">",
                                    );
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "sub" => {
                                    output.push_str(
                                        "<sub style=\"vertical-align: sub; font-size: smaller;\">",
                                    );
                                    output.push_str(&inner);
                                    output.push_str("</sub>");
                                }
                                "sup" => {
                                    output.push_str(
                                        "<sup style=\"vertical-align: super; font-size: smaller;\">",
                                    );
                                    output.push_str(&inner);
                                    output.push_str("</sup>");
                                }
                                "right" | "left" | "center" => {
                                    output
                                        .push_str(&format!("<div style=\"text-align:{};\">", name));
                                    output.push_str(&inner);
                                    output.push_str("</div>");
                                }
                                "size" => {
                                    let size_str = attr.unwrap_or("14").trim();
                                    let size = match size_str.to_ascii_lowercase().as_str() {
                                        "small" => 12,
                                        "medium" => 14,
                                        "large" => 18,
                                        "x-large" | "xlarge" => 24,
                                        _ => size_str
                                            .parse::<i32>()
                                            .ok()
                                            .map(|value| value.clamp(8, 72))
                                            .unwrap_or(14),
                                    };
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
                        _ => {
                            if let Some(smile) = bangumi_smile_html(raw_tag) {
                                output.push_str(&smile);
                                cursor = tag_end + 1;
                                continue;
                            }
                        }
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

pub(super) fn strip_bangumi_markup(text: &str) -> String {
    let mut output = String::new();
    let mut cursor = 0;

    while cursor < text.len() {
        if text[cursor..].starts_with('[') {
            if let Some(next_bracket) = text[cursor..].find(']') {
                let tag_end = cursor + next_bracket;
                let raw_tag = &text[cursor + 1..tag_end];
                let name = raw_tag
                    .split_once('=')
                    .map(|(name, _)| name.trim().to_ascii_lowercase())
                    .unwrap_or_else(|| raw_tag.trim().to_ascii_lowercase());

                match name.as_str() {
                    "img" | "photo" => {
                        let closing = format!("[/{name}]");
                        if let Some(close_index) = text[tag_end + 1..].find(&closing) {
                            cursor = tag_end + 1 + close_index + closing.len();
                            continue;
                        }
                    }
                    "code" | "quote" | "mask" | "url" | "list" | "align" | "font" | "b" | "i"
                    | "u" | "s" | "del" | "strikethrough" | "sub" | "sup" | "right" | "left"
                    | "center" | "size" | "color" | "hr" => {
                        cursor = tag_end + 1;
                        if name == "hr" && text[cursor..].starts_with("[/hr]") {
                            cursor += "[/hr]".len();
                        }
                        continue;
                    }
                    _ => {
                        if raw_tag.starts_with('/') {
                            cursor = tag_end + 1;
                            continue;
                        }
                        if bangumi_smile_asset(raw_tag).is_some() {
                            cursor = tag_end + 1;
                            continue;
                        }
                    }
                }
            }
        }

        if text[cursor..].starts_with('(') {
            if let Some(close_offset) = text[cursor + 1..].find(')') {
                let token = &text[cursor + 1..cursor + 1 + close_offset];
                if bangumi_smile_asset(token).is_some() {
                    cursor = cursor + 1 + close_offset + 1;
                    continue;
                }
            }
        }

        let ch = text[cursor..].chars().next().unwrap();
        output.push(ch);
        cursor += ch.len_utf8();
    }

    output
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
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

    #[test]
    fn render_bangumi_markup_renders_code_blocks() {
        let html = render_bangumi_markup("[code]let x = 1;\nlet y = 2;[/code]");
        assert!(html.contains("<pre class=\"code\"><code>let x = 1;\nlet y = 2;</code></pre>"));
    }

    #[test]
    fn render_bangumi_markup_renders_sub_and_sup() {
        let html = render_bangumi_markup("H[sub]2[/sub]O and E=mc[sup]2[/sup]");
        assert!(html.contains("<sub style=\"vertical-align: sub; font-size: smaller;\">2</sub>"));
        assert!(html.contains("<sup style=\"vertical-align: super; font-size: smaller;\">2</sup>"));
    }

    #[test]
    fn render_bangumi_markup_renders_hr() {
        let html = render_bangumi_markup("above\n[hr]\nbelow");
        assert!(html.contains("<hr />"));
    }

    #[test]
    fn render_bangumi_markup_renders_lists() {
        let html = render_bangumi_markup("[list]\n[*]Item A\n[*]Item B\n[/list]");
        assert!(html.contains("<ul><li>Item A</li><li>Item B</li></ul>"));
    }

    #[test]
    fn render_bangumi_markup_renders_align_font_del() {
        let html = render_bangumi_markup("[align=center][font=Arial][del]old[/del][/font][/align]");
        assert!(html.contains("<div style=\"text-align:center;\">"));
        assert!(html.contains("<span style=\"font-family:Arial;\">"));
        assert!(html.contains("<span style=\"text-decoration: line-through;\">old</span>"));
    }

    #[test]
    fn render_bangumi_markup_bracket_smiles() {
        let html = render_bangumi_markup("Hello [bgm38] world");
        assert!(html.contains("/img/smiles/tv/15.gif"));
    }

    #[test]
    fn render_bangumi_markup_renders_photo_and_bgm200() {
        let html = render_bangumi_markup("(bgm200) [photo=167942]c7/a2/871074_k1vH3.jpg[/photo]");
        assert!(html.contains("/img/smiles/tv_vs/bgm_200.png"));
        assert!(html.contains("/pic/photo/l/c7/a2/871074_k1vH3.jpg"));
    }

    #[test]
    fn render_bangumi_markup_blocks_unsafe_link_and_image_schemes() {
        let html = render_bangumi_markup(
            "[url=javascript:alert(1)]unsafe[/url][img]file:///C:/secret.txt[/img]",
        );
        assert_eq!(html, "unsafe");
        assert!(!html.contains("href="));
        assert!(!html.contains("src="));
    }

    #[test]
    fn render_bangumi_markup_keeps_http_and_https_urls() {
        let html = render_bangumi_markup(
            "[url=https://bgm.tv/subject/1]subject[/url][img]http://example.com/a.png[/img]",
        );
        assert!(html.contains("href=\"https://bgm.tv/subject/1\""));
        assert!(html.contains("src=\"http://example.com/a.png\""));
    }

    #[test]
    fn strip_bangumi_markup_removes_images_smiles_and_tags() {
        let clean = strip_bangumi_markup(
            "(bgm200)(bgm200)屎尿屁黄赌毒拉满了说是 [photo=167942]c7/a2/871074_k1vH3.jpg[/photo]",
        );
        assert_eq!(clean, "屎尿屁黄赌毒拉满了说是");

        let clean_formatting =
            strip_bangumi_markup("好希望[b]你的经费一直这样无厘头下去！[/b](blake_30)");
        assert_eq!(clean_formatting, "好希望你的经费一直这样无厘头下去！");
    }
}
