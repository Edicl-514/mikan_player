use super::types::*;
use super::util::*;
use scraper::{Html, Selector};

use super::markup::render_bangumi_markup;

pub(super) const BANGUMI_SUBJECT_COMMENTS_LEGACY_LABEL: &str = "bangumi.comments.subject.legacy";
pub(super) const BANGUMI_SUBJECT_COMMENTS_NEXT_LABEL: &str = "bangumi.comments.subject.next";
pub(super) const BANGUMI_EPISODE_COMMENTS_LEGACY_LABEL: &str = "bangumi.comments.episode.legacy";
pub(super) const BANGUMI_EPISODE_COMMENTS_NEXT_LABEL: &str = "bangumi.comments.episode.next";

fn parse_bangumi_comments_next(json: &serde_json::Value) -> Vec<BangumiComment> {
    json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let content = item["comment"].as_str()?.trim();
            if content.is_empty() {
                return None;
            }
            let user = &item["user"];
            let rate = json_i32(&item["rate"]).filter(|rate| (1..=10).contains(rate));

            Some(BangumiComment {
                user_name: user["nickname"]
                    .as_str()
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
                    .to_string(),
                rate,
                content: content.to_string(),
                content_html: render_bangumi_markup(content),
                time: item["updatedAt"]
                    .as_i64()
                    .map(format_bangumi_timestamp)
                    .unwrap_or_default(),
                avatar: normalize_avatar_url(user["avatar"]["large"].as_str()),
            })
        })
        .collect()
}

/// Scrape comments from the Bangumi website
/// URL: https://bgm.tv/subject/{subject_id}/comments?page={page}
pub(crate) async fn fetch_bangumi_comments(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::info!(
        "bangumi.comments.subject mode={} subject_id={} page={}",
        mode,
        subject_id,
        page
    );

    match mode.as_str() {
        "legacy" => fetch_bangumi_comments_legacy(subject_id, page).await,
        "hybrid" => match fetch_bangumi_comments_next(subject_id, page).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.subject next failed subject_id={} page={}, falling back to legacy: {}",
                    subject_id,
                    page,
                    err
                );
                fetch_bangumi_comments_legacy(subject_id, page).await
            }
        },
        "modern" => fetch_bangumi_comments_next(subject_id, page).await,
        _ => match fetch_bangumi_comments_next(subject_id, page).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.subject next failed subject_id={} page={}, falling back to legacy: {}",
                    subject_id,
                    page,
                    err
                );
                fetch_bangumi_comments_legacy(subject_id, page).await
            }
        },
    }
}

pub(super) async fn fetch_bangumi_comments_legacy(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let url = format!(
        "{}/subject/{}/comments?page={}",
        crate::api::config::get_bangumi_url(),
        subject_id,
        page
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_SUBJECT_COMMENTS_LEGACY_LABEL,
        |client| client.get(&url),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    let mut comments = Vec::new();

    // Selectors based on inspection
    let item_selector = Selector::parse("#comment_box .item").ok();
    let user_selector = Selector::parse("a.l").ok();
    let avatar_selector = Selector::parse("span.avatarNeue").ok();
    let rating_selector = Selector::parse("span.starlight").ok();
    let content_selector = Selector::parse("p.comment").ok();
    let info_selector = Selector::parse("small.grey").ok();

    if let Some(item_sel) = item_selector {
        for item in document.select(&item_sel) {
            // User Name
            let user_name = if let Some(user_sel) = &user_selector {
                item.select(user_sel)
                    .next()
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .unwrap_or_default()
            } else {
                String::new()
            };

            // Avatar (Check both style and backup)
            let avatar = if let Some(avatar_sel) = &avatar_selector {
                extract_avatar_url(
                    item.select(avatar_sel)
                        .next()
                        .and_then(|element| element.value().attr("style")),
                )
            } else {
                String::new()
            };

            // Rating
            let rate = if let Some(rating_sel) = &rating_selector {
                item.select(rating_sel)
                    .next()
                    .and_then(|e| e.value().attr("class"))
                    .and_then(|class| {
                        class
                            .split_whitespace()
                            .find(|s| s.starts_with("stars"))
                            .and_then(|s| s.trim_start_matches("stars").parse::<i32>().ok())
                    })
            } else {
                None
            };

            // Content
            let (content, content_html) = if let Some(content_sel) = &content_selector {
                let node = item.select(content_sel).next();
                let text = node
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .unwrap_or_default();
                let html = node
                    .map(|e| {
                        e.html().replace("src=\"//", "src=\"https://").replace(
                            "src=\"/img/",
                            &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                        )
                    })
                    .unwrap_or_default();
                (text, html)
            } else {
                (String::new(), String::new())
            };

            // Time tag (starts with @)
            let mut time = String::new();
            if let Some(info_sel) = &info_selector {
                for info in item.select(info_sel) {
                    let text = info.text().collect::<String>();
                    if text.contains("@") {
                        time = text.trim().to_string();
                        break;
                    }
                }
            }

            if !user_name.is_empty() && (!content.is_empty() || !content_html.is_empty()) {
                comments.push(BangumiComment {
                    user_name,
                    rate,
                    content,
                    content_html,
                    time,
                    avatar,
                });
            }
        }
    }

    Ok(comments)
}
/// Scrape episode comments from Bangumi
/// URL: https://bangumi.tv/ep/{episode_id}
pub(crate) async fn fetch_bangumi_episode_comments(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::info!(
        "bangumi.comments.episode mode={} episode_id={}",
        mode,
        episode_id
    );

    match mode.as_str() {
        "legacy" => fetch_bangumi_episode_comments_legacy(episode_id).await,
        "hybrid" => match fetch_bangumi_episode_comments_next(episode_id).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                    episode_id,
                    err
                );
                fetch_bangumi_episode_comments_legacy(episode_id).await
            }
        },
        "modern" => fetch_bangumi_episode_comments_next(episode_id).await,
        _ => match fetch_bangumi_episode_comments_next(episode_id).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                    episode_id,
                    err
                );
                fetch_bangumi_episode_comments_legacy(episode_id).await
            }
        },
    }
}

pub(super) async fn fetch_bangumi_episode_comments_legacy(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let url = format!(
        "{}/ep/{}",
        crate::api::config::get_bangumi_url(),
        episode_id
    );
    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_EPISODE_COMMENTS_LEGACY_LABEL,
        |client| client.get(&url),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    let mut comments = Vec::new();

    // Selectors
    let main_comment_selector = Selector::parse("#comment_list > .row_reply").unwrap();
    let sub_reply_selector = Selector::parse(".topic_sub_reply > .sub_reply_bg").unwrap();

    // Common field selectors
    let user_name_selector = Selector::parse("div.inner > strong > a.l").unwrap();
    let avatar_selector = Selector::parse("span.avatarNeue").unwrap();
    let time_selector = Selector::parse("div.post_actions.re_info > div.action > small").unwrap();
    let message_selector = Selector::parse("div.inner > div.reply_content > div.message").unwrap();
    let sub_message_selector = Selector::parse("div.inner > div.cmt_sub_content").unwrap();

    for main_element in document.select(&main_comment_selector) {
        // ID
        let id_str = main_element.value().attr("id").unwrap_or("post_0");
        let id = id_str
            .trim_start_matches("post_")
            .parse::<i64>()
            .unwrap_or(0);

        // User Info
        let (user_name, user_id) = if let Some(a) = main_element.select(&user_name_selector).next()
        {
            let name = a.text().collect::<String>();
            let href = a.value().attr("href").unwrap_or("");
            let uid = href.split("/user/").last().unwrap_or("").to_string();
            (name, uid)
        } else {
            (String::new(), String::new())
        };

        // Avatar
        let avatar = extract_avatar_url(
            main_element
                .select(&avatar_selector)
                .next()
                .and_then(|e| e.value().attr("style")),
        );

        // Time
        let time = if let Some(small) = main_element.select(&time_selector).next() {
            let text = small.text().collect::<String>();
            // Format usually: "#1 - 2025-1-1 12:00"
            if let Some(idx) = text.find(" - ") {
                text[idx + 3..].trim().to_string()
            } else {
                text
            }
        } else {
            String::new()
        };

        // Content
        let content_html = if let Some(msg) = main_element.select(&message_selector).next() {
            msg.html()
                .replace("src=\"//", "src=\"https://")
                // Fix for bangumi relative emoticons if needed, usually they are relative /img/smiles/
                .replace(
                    "src=\"/img/",
                    &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                )
        } else {
            String::new()
        };

        // Sub-replies
        let mut replies = Vec::new();
        for sub_element in main_element.select(&sub_reply_selector) {
            let sub_id_str = sub_element.value().attr("id").unwrap_or("post_0");
            let sub_id = sub_id_str
                .trim_start_matches("post_")
                .parse::<i64>()
                .unwrap_or(0);

            let (s_user_name, s_user_id) =
                if let Some(a) = sub_element.select(&user_name_selector).next() {
                    let name = a.text().collect::<String>();
                    let href = a.value().attr("href").unwrap_or("");
                    let uid = href.split("/user/").last().unwrap_or("").to_string();
                    (name, uid)
                } else {
                    (String::new(), String::new())
                };

            let s_avatar = extract_avatar_url(
                sub_element
                    .select(&avatar_selector)
                    .next()
                    .and_then(|e| e.value().attr("style")),
            );

            let s_time = if let Some(small) = sub_element.select(&time_selector).next() {
                let text = small.text().collect::<String>();
                if let Some(idx) = text.find(" - ") {
                    text[idx + 3..].trim().to_string()
                } else {
                    text
                }
            } else {
                String::new()
            };

            let s_content_html = if let Some(msg) = sub_element.select(&sub_message_selector).next()
            {
                msg.html().replace("src=\"//", "src=\"https://").replace(
                    "src=\"/img/",
                    &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                )
            } else {
                String::new()
            };

            if !s_user_name.is_empty() && !s_content_html.is_empty() {
                replies.push(BangumiEpisodeComment {
                    id: sub_id,
                    user_name: s_user_name,
                    user_id: s_user_id,
                    avatar: s_avatar,
                    time: s_time,
                    content_html: s_content_html,
                    replies: Vec::new(),
                });
            }
        }

        if !user_name.is_empty() && !content_html.is_empty() {
            comments.push(BangumiEpisodeComment {
                id,
                user_name,
                user_id,
                avatar,
                time,
                content_html,
                replies,
            });
        }
    }

    Ok(comments)
}

pub(super) async fn fetch_bangumi_comments_next(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let page = page.max(1);
    let offset = i64::from(page - 1) * BANGUMI_NEXT_COMMENTS_PAGE_SIZE;
    let url = bangumi_next_url(&format!(
        "/p1/subjects/{subject_id}/comments?limit={BANGUMI_NEXT_COMMENTS_PAGE_SIZE}&offset={offset}"
    ));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_SUBJECT_COMMENTS_NEXT_LABEL,
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND || status == reqwest::StatusCode::BAD_REQUEST {
        return Ok(Vec::new());
    }

    if !status.is_success() {
        anyhow::bail!("next subject comments failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_comments_next(&json))
}

pub(super) fn parse_next_episode_comment(item: &serde_json::Value) -> BangumiEpisodeComment {
    let user = &item["user"];
    let user_name = user["nickname"]
        .as_str()
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
        .to_string();
    let user_id = user["username"]
        .as_str()
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| user["id"].as_i64().unwrap_or_default().to_string());
    let content = item["content"].as_str().unwrap_or("");

    let replies = item["replies"]
        .as_array()
        .map(|items| items.iter().map(parse_next_episode_comment).collect())
        .unwrap_or_default();

    BangumiEpisodeComment {
        id: item["id"].as_i64().unwrap_or_default(),
        user_name,
        user_id,
        avatar: normalize_avatar_url(user["avatar"]["large"].as_str()),
        time: item["createdAt"]
            .as_i64()
            .map(format_bangumi_timestamp)
            .unwrap_or_default(),
        content_html: render_bangumi_markup(content),
        replies,
    }
}

pub(super) async fn fetch_bangumi_episode_comments_next(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let url = bangumi_next_url(&format!("/p1/episodes/{episode_id}/comments"));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_EPISODE_COMMENTS_NEXT_LABEL,
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND || status == reqwest::StatusCode::BAD_REQUEST {
        return Ok(Vec::new());
    }

    if !status.is_success() {
        anyhow::bail!("next episode comments failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    let comments = json
        .as_array()
        .map(|items| items.iter().map(parse_next_episode_comment).collect())
        .unwrap_or_default();

    Ok(comments)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    fn point_bangumi_at(base_url: &str, mode: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_next_url = base_url.to_string();
        config.bangumi_url = base_url.to_string();
        config.bangumi_request_mode = mode.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn next_subject_comments_escape_markup_and_validate_rating_range() {
        let comments = parse_bangumi_comments_next(&json!({"data": [
            {
                "comment": "[b]bold[/b] <script>alert(1)</script> (bgm38)",
                "rate": 10,
                "user": {"nickname": "", "username": "alice", "avatar": {"large": "//lain.bgm.tv/a.jpg"}}
            },
            {"comment": "rate too high", "rate": 11, "user": {"nickname": "Bob"}},
            {"comment": "overflow", "rate": 2147483648_i64, "user": {}},
            {"comment": "   ", "rate": 5}
        ]}));

        assert_eq!(comments.len(), 3);
        assert_eq!(comments[0].user_name, "alice");
        assert_eq!(comments[0].rate, Some(10));
        assert!(
            comments[0]
                .content_html
                .contains("<span style=\"font-weight:bold;\">bold</span>")
        );
        assert!(comments[0].content_html.contains("&lt;script&gt;"));
        assert!(!comments[0].content_html.contains("<script>"));
        assert_eq!(comments[1].rate, None);
        assert_eq!(comments[2].rate, None);
    }

    #[test]
    fn next_episode_comments_normalize_recursive_replies_without_executing_markup() {
        let comment = parse_next_episode_comment(&json!({
            "id": 1,
            "content": "[url=https://example.com]link[/url]<img src=x>",
            "user": {"id": 7, "nickname": "Nick"},
            "replies": [{"id": 2, "content": "[b]reply[/b]", "user": {"username": "bob"}}]
        }));

        assert_eq!(comment.user_id, "7");
        assert!(comment.content_html.contains("&lt;img src=x&gt;"));
        assert_eq!(comment.replies.len(), 1);
        assert_eq!(comment.replies[0].user_id, "bob");
        assert!(
            comment.replies[0]
                .content_html
                .contains("<span style=\"font-weight:bold;\">reply</span>")
        );
    }

    #[tokio::test]
    async fn next_subject_comments_clamp_page_and_map_not_found_to_empty() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/p1/subjects/7/comments",
            TestResponse::new(StatusCode::NOT_FOUND, "missing"),
        )])
        .await;
        point_bangumi_at(&server.base_url(), "modern");

        assert!(
            fetch_bangumi_comments_next(7, i32::MIN)
                .await
                .unwrap()
                .is_empty()
        );
        assert_eq!(server.requests()[0].uri.query(), Some("limit=20&offset=0"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn hybrid_subject_comments_fall_back_to_legacy_html() {
        let _config = isolate_runtime_config();
        let legacy_html = r#"
            <div id="comment_box"><div class="item">
              <a class="l">Legacy User</a>
              <span class="avatarNeue" style="background-image:url(&quot;//lain.bgm.tv/avatar.jpg&quot;)"></span>
              <span class="starlight stars8"></span>
              <p class="comment">legacy <b>content</b><script>not executed</script></p>
              <small class="grey">#1 @ 2026-07-19</small>
            </div></div>
        "#;
        let server = TestServer::spawn([
            TestRoute::get(
                "/p1/subjects/7/comments",
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ),
            TestRoute::get(
                "/subject/7/comments",
                TestResponse::ok(legacy_html).with_header("content-type", "text/html"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url(), "hybrid");

        let comments = fetch_bangumi_comments(7, 2).await.unwrap();
        assert_eq!(comments.len(), 1);
        assert_eq!(comments[0].user_name, "Legacy User");
        assert_eq!(comments[0].rate, Some(8));
        assert_eq!(comments[0].avatar, "https://lain.bgm.tv/avatar.jpg");
        assert!(
            comments[0]
                .content_html
                .contains("<script>not executed</script>")
        );
        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(requests[1].uri.query(), Some("page=2"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn modern_episode_comments_returns_nested_json_and_errors_on_rate_limit() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/p1/episodes/8/comments",
                TestResponse::ok(json!([{"id": 1, "content": "hello", "user": {"username": "alice"}, "replies": []}]).to_string()),
            ),
            TestRoute::get(
                "/p1/episodes/9/comments",
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url(), "modern");

        assert_eq!(fetch_bangumi_episode_comments(8).await.unwrap().len(), 1);
        assert!(fetch_bangumi_episode_comments(9).await.is_err());
        server.shutdown().await;
    }
}
