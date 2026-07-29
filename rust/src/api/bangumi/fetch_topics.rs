use super::fetch_comments::{
    bangumi_comment_state_can_view_content, parse_comment_reaction, parse_next_episode_comment,
};
use super::markup::render_bangumi_markup;
use super::types::*;
use super::util::*;

pub(super) const BANGUMI_SUBJECT_TOPICS_NEXT_LABEL: &str = "bangumi.topics.subject.next";
pub(super) const BANGUMI_TOPIC_DETAIL_NEXT_LABEL: &str = "bangumi.topic.detail.next";
pub(super) const BANGUMI_NEXT_TOPICS_PAGE_SIZE: i64 = 20;

/// p1 `TopicDisplay`: only `1` is publicly listed. `0` is banned and `2` is
/// awaiting moderator review.
const BANGUMI_TOPIC_DISPLAY_NORMAL: i32 = 1;

/// Whether a topic may appear in a public list.
///
/// `display` gates visibility outright. `state` uses the same enum as post
/// state, but for a *topic* most values are benign moderator actions (`1` closed,
/// `5` silenced) that keep the thread readable — only the delete states remove it.
fn bangumi_topic_is_listable(state: i32, display: i32) -> bool {
    display == BANGUMI_TOPIC_DISPLAY_NORMAL && !matches!(state, 6 | 7)
}

/// Reply count as reported by p1. The field is `replyCount`; the other two are
/// tolerated only so a rename upstream degrades to a stale count instead of `0`.
fn parse_topic_reply_count(item: &serde_json::Value) -> Option<i32> {
    json_i32(&item["replyCount"])
        .or_else(|| json_i32(&item["repliesCount"]))
        .or_else(|| json_i32(&item["replies"]))
}

fn parse_comment_reactions(
    item: &serde_json::Value,
    current_user_id: Option<i64>,
) -> Vec<BangumiCommentReaction> {
    item["reactions"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|reaction| parse_comment_reaction(reaction, current_user_id))
        .collect()
}

fn parse_bangumi_topics_next(json: &serde_json::Value) -> BangumiTopicsPage {
    let raw = json["data"].as_array();
    let fetched_count = raw.map_or(0, |items| items.len() as i32);

    let topics = raw
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = json_i64(&item["id"])?;

            // Absent `state` / `display` are treated as "normal" so an upstream
            // field rename degrades to showing the thread rather than blanking
            // the whole discussion tab.
            let state = json_i32(&item["state"]).unwrap_or(0);
            let display = json_i32(&item["display"]).unwrap_or(BANGUMI_TOPIC_DISPLAY_NORMAL);
            if !bangumi_topic_is_listable(state, display) {
                return None;
            }

            let user = parse_user_object(item);

            Some(BangumiTopic {
                id,
                user_id: parse_user_id(user),
                user_name: parse_user_name(user),
                avatar: parse_user_avatar(user),
                title: item["title"].as_str().unwrap_or_default().to_string(),
                time: item["createdAt"]
                    .as_i64()
                    .map(format_bangumi_timestamp)
                    .unwrap_or_default(),
                updated_at: item["updatedAt"]
                    .as_i64()
                    .map(format_bangumi_timestamp)
                    .unwrap_or_default(),
                replies_count: parse_topic_reply_count(item).unwrap_or(0),
            })
        })
        .collect::<Vec<_>>();

    BangumiTopicsPage {
        topics,
        total: json_i32(&json["total"]).filter(|total| *total >= 0),
        fetched_count,
    }
}

pub(crate) async fn fetch_bangumi_subject_topics(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<BangumiTopicsPage> {
    let page = page.max(1);
    let offset = i64::from(page - 1) * BANGUMI_NEXT_TOPICS_PAGE_SIZE;
    let (url, access_token, _) = bangumi_next_request(&format!(
        "/p1/subjects/{subject_id}/topics?limit={BANGUMI_NEXT_TOPICS_PAGE_SIZE}&offset={offset}"
    ));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_SUBJECT_TOPICS_NEXT_LABEL,
        move |client| {
            let request = client.get(&url).header("accept", "application/json");
            match &access_token {
                Some(token) => request.header("Authorization", format!("Bearer {token}")),
                None => request,
            }
        },
        true,
    )
    .await?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND || status == reqwest::StatusCode::BAD_REQUEST {
        return Ok(BangumiTopicsPage {
            topics: Vec::new(),
            total: Some(0),
            fetched_count: 0,
        });
    }

    if !status.is_success() {
        anyhow::bail!("next subject topics failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_topics_next(&json))
}

/// The opening post of a topic, plus whether it was taken off the reply list.
struct BangumiTopicOpeningPost {
    user_id: String,
    user_name: String,
    avatar: String,
    time: String,
    content: String,
    content_state: i32,
    reactions: Vec<BangumiCommentReaction>,
    consumed_first_reply: bool,
}

/// Locate the opening post.
///
/// p1's `SubjectTopic` / `GroupTopic` carry no `content` of their own: floor 1 is
/// the opening post and arrives as `replies[0]`. The top-level `content` branch
/// exists only for shapes that do inline a body, and is not reached today.
fn parse_bangumi_topic_opening_post(
    json: &serde_json::Value,
    first_reply: Option<&serde_json::Value>,
    current_user_id: Option<i64>,
) -> BangumiTopicOpeningPost {
    let inline_content = json["content"].as_str().filter(|value| !value.is_empty());

    if let Some(content) = inline_content {
        let user = parse_user_object(json);
        // A topic's own `state` is not a comment state, so it cannot be handed to
        // the comment gate: an admin-closed topic (`1`) still shows its body.
        // Only the delete states must suppress content.
        let topic_state = json_i32(&json["state"]).unwrap_or(0);
        let content_state = if matches!(topic_state, 6 | 7) { 6 } else { 0 };

        return BangumiTopicOpeningPost {
            user_id: parse_user_id(user),
            user_name: parse_user_name(user),
            avatar: parse_user_avatar(user),
            time: json["createdAt"]
                .as_i64()
                .map(format_bangumi_timestamp)
                .unwrap_or_default(),
            content: content.to_string(),
            content_state,
            reactions: parse_comment_reactions(json, current_user_id),
            consumed_first_reply: false,
        };
    }

    let Some(first) = first_reply else {
        let user = parse_user_object(json);
        return BangumiTopicOpeningPost {
            user_id: parse_user_id(user),
            user_name: parse_user_name(user),
            avatar: parse_user_avatar(user),
            time: json["createdAt"]
                .as_i64()
                .map(format_bangumi_timestamp)
                .unwrap_or_default(),
            content: String::new(),
            content_state: 0,
            reactions: Vec::new(),
            consumed_first_reply: false,
        };
    };

    let user = parse_user_object(first);
    BangumiTopicOpeningPost {
        user_id: parse_user_id(user),
        user_name: parse_user_name(user),
        avatar: parse_user_avatar(user),
        time: first["createdAt"]
            .as_i64()
            .or_else(|| json["createdAt"].as_i64())
            .map(format_bangumi_timestamp)
            .unwrap_or_default(),
        content: first["content"].as_str().unwrap_or_default().to_string(),
        content_state: json_i32(&first["state"]).unwrap_or(0),
        reactions: parse_comment_reactions(first, current_user_id),
        consumed_first_reply: true,
    }
}

pub(crate) async fn fetch_bangumi_topic_detail(
    topic_id: i64,
) -> anyhow::Result<BangumiTopicDetail> {
    let (url, access_token, current_user_id) =
        bangumi_next_request(&format!("/p1/subjects/-/topics/{topic_id}"));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_TOPIC_DETAIL_NEXT_LABEL,
        move |client| {
            let request = client.get(&url).header("accept", "application/json");
            match &access_token {
                Some(token) => request.header("Authorization", format!("Bearer {token}")),
                None => request,
            }
        },
        true,
    )
    .await?;

    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("next topic detail failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;

    let raw_replies = json["replies"]
        .as_array()
        .or_else(|| json["posts"].as_array());
    let opening = parse_bangumi_topic_opening_post(
        &json,
        raw_replies.and_then(|replies| replies.first()),
        current_user_id,
    );

    let replies: Vec<BangumiEpisodeComment> = raw_replies
        .map(|items| {
            items
                .iter()
                .skip(usize::from(opening.consumed_first_reply))
                .map(|item| parse_next_episode_comment(item, current_user_id))
                .collect()
        })
        .unwrap_or_default();

    // Enforce the moderation gate here too: a deleted opening post must not have
    // its BBCode rendered even if upstream still returns the text.
    let visible_content = if bangumi_comment_state_can_view_content(opening.content_state) {
        opening.content.as_str()
    } else {
        ""
    };

    Ok(BangumiTopicDetail {
        id: json_i64(&json["id"]).unwrap_or(topic_id),
        title: json["title"].as_str().unwrap_or_default().to_string(),
        user_id: opening.user_id,
        user_name: opening.user_name,
        avatar: opening.avatar,
        time: opening.time,
        updated_at: json["updatedAt"]
            .as_i64()
            .map(format_bangumi_timestamp)
            .unwrap_or_default(),
        replies_count: parse_topic_reply_count(&json).unwrap_or_else(|| replies.len() as i32),
        content: visible_content.to_string(),
        content_html: render_bangumi_markup(visible_content),
        content_state: opening.content_state,
        reactions: opening.reactions,
        replies,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    fn point_bangumi_at(base_url: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_next_url = base_url.to_string();
        config.bangumi_url = base_url.to_string();
        config.bangumi_request_mode = "modern".to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    /// Mirrors a real `GET /p1/subjects/{id}/topics` row: the reply count field is
    /// `replyCount`, the author is `creator`, and `state` / `display` are present.
    fn real_shape_topic_row() -> serde_json::Value {
        json!({
            "id": 24339,
            "title": "找了半天，终于找到全集和匹配的字幕啦！",
            "creatorID": 651247,
            "parentID": 12,
            "replyCount": 24,
            "createdAt": 1673637413,
            "updatedAt": 1738840274,
            "state": 0,
            "display": 1,
            "creator": {
                "id": 651247,
                "username": "moyis",
                "nickname": "Uaoko",
                "avatar": {
                    "small": "https://lain.bgm.tv/r/100/pic/user/l/000/65/12/651247.jpg",
                    "medium": "https://lain.bgm.tv/r/200/pic/user/l/000/65/12/651247.jpg",
                    "large": "https://lain.bgm.tv/pic/user/l/000/65/12/651247.jpg"
                },
                "group": 10,
                "sign": "好烦T_T",
                "joinedAt": 1639228242
            }
        })
    }

    #[test]
    fn parse_topics_reads_reply_count_and_creator_from_real_p1_shape() {
        let page = parse_bangumi_topics_next(&json!({
            "total": 1,
            "data": [real_shape_topic_row()],
        }));

        assert_eq!(page.total, Some(1));
        assert_eq!(page.fetched_count, 1);
        assert_eq!(page.topics.len(), 1);

        let topic = &page.topics[0];
        assert_eq!(topic.id, 24339);
        assert_eq!(topic.title, "找了半天，终于找到全集和匹配的字幕啦！");
        // Regression guard: p1 names this `replyCount`, so reading `replies` /
        // `repliesCount` alone silently rendered 0 on every card.
        assert_eq!(topic.replies_count, 24);
        assert_eq!(topic.user_id, "moyis");
        assert_eq!(topic.user_name, "Uaoko");
        assert_eq!(
            topic.avatar,
            "https://lain.bgm.tv/pic/user/l/000/65/12/651247.jpg"
        );
    }

    #[test]
    fn parse_topics_drops_deleted_and_undisplayed_rows_but_keeps_fetched_count() {
        let mut closed = real_shape_topic_row();
        closed["id"] = json!(1);
        closed["state"] = json!(1); // admin closed — still readable

        let mut silenced = real_shape_topic_row();
        silenced["id"] = json!(2);
        silenced["state"] = json!(5); // silenced — still readable

        let mut user_deleted = real_shape_topic_row();
        user_deleted["id"] = json!(3);
        user_deleted["state"] = json!(6);

        let mut admin_deleted = real_shape_topic_row();
        admin_deleted["id"] = json!(4);
        admin_deleted["state"] = json!(7);

        let mut pending_review = real_shape_topic_row();
        pending_review["id"] = json!(5);
        pending_review["display"] = json!(2);

        let mut banned = real_shape_topic_row();
        banned["id"] = json!(6);
        banned["display"] = json!(0);

        let page = parse_bangumi_topics_next(&json!({
            "total": 6,
            "data": [closed, silenced, user_deleted, admin_deleted, pending_review, banned],
        }));

        assert_eq!(
            page.topics.iter().map(|t| t.id).collect::<Vec<_>>(),
            vec![1, 2]
        );
        // Pagination advances on rows fetched, not rows kept, so a page that is
        // entirely moderated away does not look like the end of the list.
        assert_eq!(page.fetched_count, 6);
        assert_eq!(page.total, Some(6));
    }

    #[test]
    fn parse_topics_treats_missing_state_and_display_as_visible() {
        let mut row = real_shape_topic_row();
        row.as_object_mut().unwrap().remove("state");
        row.as_object_mut().unwrap().remove("display");

        let page = parse_bangumi_topics_next(&json!({"total": 1, "data": [row]}));
        assert_eq!(page.topics.len(), 1);
    }

    #[test]
    fn opening_post_comes_from_first_reply_when_topic_has_no_content() {
        let json = json!({
            "id": 24339,
            "title": "Topic",
            "replyCount": 24,
            "state": 0,
            "display": 1,
            "creator": { "username": "starter", "nickname": "Starter" },
            "replies": [
                {
                    "id": 3001,
                    "content": "[b]opening[/b]",
                    "state": 0,
                    "createdAt": 1600000000,
                    "creator": { "username": "starter", "nickname": "Starter" },
                    "reactions": [{"value": 38, "users": [{"id": 99}]}]
                },
                {
                    "id": 3002,
                    "content": "floor two",
                    "state": 0,
                    "createdAt": 1600000500,
                    "creator": { "username": "bob", "nickname": "Bob" }
                }
            ]
        });

        let opening = parse_bangumi_topic_opening_post(&json, Some(&json["replies"][0]), Some(99));
        assert!(opening.consumed_first_reply);
        assert_eq!(opening.content, "[b]opening[/b]");
        assert_eq!(opening.user_name, "Starter");
        assert_eq!(opening.reactions.len(), 1);
        assert!(opening.reactions[0].reacted);
    }

    #[test]
    fn deleted_opening_post_is_not_rendered() {
        let json = json!({
            "id": 1,
            "title": "Topic",
            "replies": [
                {
                    "id": 3001,
                    "content": "text upstream still returns",
                    "state": 6,
                    "createdAt": 1600000000,
                    "creator": { "username": "gone", "nickname": "Gone" }
                }
            ]
        });

        let opening = parse_bangumi_topic_opening_post(&json, Some(&json["replies"][0]), None);
        assert_eq!(opening.content_state, 6);
        assert!(!bangumi_comment_state_can_view_content(
            opening.content_state
        ));
    }

    #[test]
    fn inline_content_keeps_body_for_closed_topic_but_hides_deleted_one() {
        let closed = json!({"content": "body", "state": 1});
        let opening = parse_bangumi_topic_opening_post(&closed, None, None);
        assert!(!opening.consumed_first_reply);
        // Topic state 1 is "admin closed", not a comment state — the body stays.
        assert_eq!(opening.content_state, 0);
        assert!(bangumi_comment_state_can_view_content(
            opening.content_state
        ));

        let deleted = json!({"content": "body", "state": 7});
        let opening = parse_bangumi_topic_opening_post(&deleted, None, None);
        assert!(!bangumi_comment_state_can_view_content(
            opening.content_state
        ));
    }

    #[tokio::test]
    async fn fetch_topics_and_topic_detail_work_with_mock_server() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/p1/subjects/42/topics",
                TestResponse::ok(json!({"total": 1, "data": [real_shape_topic_row()]}).to_string()),
            ),
            TestRoute::get(
                "/p1/subjects/-/topics/24339",
                TestResponse::ok(
                    json!({
                        "id": 24339,
                        "title": "Test Topic Detail",
                        "replyCount": 24,
                        "state": 0,
                        "display": 1,
                        "creator": { "username": "moyis", "nickname": "Uaoko" },
                        "createdAt": 1600000000,
                        "updatedAt": 1600001000,
                        "replies": [
                            {
                                "id": 3001,
                                "content": "[b]Topic main text[/b]",
                                "state": 0,
                                "creator": { "username": "moyis", "nickname": "Uaoko" },
                                "createdAt": 1600000000,
                                "reactions": []
                            },
                            {
                                "id": 3002,
                                "content": "First floor reply",
                                "state": 0,
                                "creator": { "username": "bob", "nickname": "Bob" },
                                "createdAt": 1600000500,
                                "reactions": [],
                                "replies": [
                                    {
                                        "id": 3003,
                                        "content": "sub reply",
                                        "state": 0,
                                        "creator": { "username": "carol", "nickname": "Carol" },
                                        "createdAt": 1600000600
                                    }
                                ]
                            }
                        ]
                    })
                    .to_string(),
                ),
            ),
        ])
        .await;

        point_bangumi_at(&server.base_url());

        let topics_page = fetch_bangumi_subject_topics(42, 1).await.unwrap();
        assert_eq!(topics_page.topics.len(), 1);
        assert_eq!(topics_page.topics[0].replies_count, 24);
        assert_eq!(topics_page.fetched_count, 1);

        let detail = fetch_bangumi_topic_detail(24339).await.unwrap();
        assert_eq!(detail.title, "Test Topic Detail");
        assert_eq!(detail.user_name, "Uaoko");
        assert!(
            detail
                .content_html
                .contains("<span style=\"font-weight:bold;\">Topic main text</span>")
        );
        assert_eq!(detail.replies_count, 24);
        // The opening post is floor 1; it must not be repeated in the reply list.
        assert_eq!(detail.replies.len(), 1);
        assert_eq!(detail.replies[0].user_name, "Bob");
        assert_eq!(detail.replies[0].replies.len(), 1);
        assert_eq!(detail.replies[0].replies[0].user_name, "Carol");

        server.shutdown().await;
    }

    #[tokio::test]
    async fn fetch_topics_returns_empty_page_for_missing_subject() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/p1/subjects/999/topics",
            TestResponse::new(StatusCode::NOT_FOUND, "missing"),
        )])
        .await;

        point_bangumi_at(&server.base_url());

        let page = fetch_bangumi_subject_topics(999, 1).await.unwrap();
        assert!(page.topics.is_empty());
        assert_eq!(page.total, Some(0));
        assert_eq!(page.fetched_count, 0);

        server.shutdown().await;
    }
}
