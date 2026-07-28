use super::fetch_comments::{parse_comment_reaction, parse_next_episode_comment};
use super::markup::{render_bangumi_markup, strip_bangumi_markup};
use super::types::*;
use super::util::*;

pub(super) const BANGUMI_SUBJECT_REVIEWS_NEXT_LABEL: &str = "bangumi.reviews.subject.next";
pub(super) const BANGUMI_BLOG_DETAIL_NEXT_LABEL: &str = "bangumi.blog.detail.next";
pub(super) const BANGUMI_BLOG_COMMENTS_NEXT_LABEL: &str = "bangumi.blog.comments.next";
pub(super) const BANGUMI_NEXT_REVIEWS_PAGE_SIZE: i64 = 20;

fn parse_bangumi_reviews_next(json: &serde_json::Value) -> BangumiReviewsPage {
    let reviews = json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let user = &item["user"];
            let entry = &item["entry"];

            let entry_id = json_i64(&entry["id"]).or_else(|| json_i64(&item["id"]))?;
            let title = entry["title"].as_str().unwrap_or_default().to_string();
            let summary_raw = entry["summary"].as_str().unwrap_or_default();
            let summary = strip_bangumi_markup(summary_raw);

            let user_name = user["nickname"]
                .as_str()
                .filter(|value| !value.is_empty())
                .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
                .to_string();
            let user_id = user["username"]
                .as_str()
                .filter(|value| !value.is_empty())
                .map(str::to_string)
                .unwrap_or_else(|| json_i64(&user["id"]).unwrap_or_default().to_string());

            let avatar = normalize_avatar_url(user["avatar"]["large"].as_str());
            let time = entry["createdAt"]
                .as_i64()
                .map(format_bangumi_timestamp)
                .unwrap_or_default();
            let replies_count = json_i32(&entry["replies"]).unwrap_or(0);

            Some(BangumiReview {
                id: json_i64(&item["id"]).unwrap_or(entry_id),
                entry_id,
                user_id,
                user_name,
                avatar,
                title,
                summary,
                time,
                replies_count,
            })
        })
        .collect::<Vec<_>>();

    BangumiReviewsPage {
        reviews,
        total: json_i32(&json["total"]).filter(|total| *total >= 0),
    }
}

pub(crate) async fn fetch_bangumi_subject_reviews(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<BangumiReviewsPage> {
    let page = page.max(1);
    let offset = i64::from(page - 1) * BANGUMI_NEXT_REVIEWS_PAGE_SIZE;
    let (url, access_token, _) = bangumi_next_request(&format!(
        "/p1/subjects/{subject_id}/reviews?limit={BANGUMI_NEXT_REVIEWS_PAGE_SIZE}&offset={offset}"
    ));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_SUBJECT_REVIEWS_NEXT_LABEL,
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
        return Ok(BangumiReviewsPage {
            reviews: Vec::new(),
            total: Some(0),
        });
    }

    if !status.is_success() {
        anyhow::bail!("next subject reviews failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_reviews_next(&json))
}

pub(crate) async fn fetch_bangumi_blog_detail(entry_id: i64) -> anyhow::Result<BangumiBlogDetail> {
    let (url, access_token, current_user_id) =
        bangumi_next_request(&format!("/p1/blogs/{entry_id}"));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_BLOG_DETAIL_NEXT_LABEL,
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
        anyhow::bail!("next blog detail failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    let user = &json["user"];
    let user_name = user["nickname"]
        .as_str()
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
        .to_string();
    let user_id = user["username"]
        .as_str()
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| json_i64(&user["id"]).unwrap_or_default().to_string());

    let content = json["content"].as_str().unwrap_or_default();
    let tags = json["tags"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|t| t.as_str().map(str::to_string))
        .collect();

    let reactions = json["reactions"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| parse_comment_reaction(item, current_user_id))
        .collect();

    Ok(BangumiBlogDetail {
        id: json_i64(&json["id"]).unwrap_or(entry_id),
        title: json["title"].as_str().unwrap_or_default().to_string(),
        summary: json["summary"].as_str().unwrap_or_default().to_string(),
        content: content.to_string(),
        content_html: render_bangumi_markup(content),
        user_id,
        user_name,
        avatar: normalize_avatar_url(user["avatar"]["large"].as_str()),
        time: json["createdAt"]
            .as_i64()
            .map(format_bangumi_timestamp)
            .unwrap_or_default(),
        replies_count: json_i32(&json["replies"]).unwrap_or(0),
        tags,
        reactions,
    })
}

pub(crate) async fn fetch_bangumi_blog_comments(
    entry_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let (url, access_token, current_user_id) =
        bangumi_next_request(&format!("/p1/blogs/{entry_id}/comments"));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_BLOG_COMMENTS_NEXT_LABEL,
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
        return Ok(Vec::new());
    }

    if !status.is_success() {
        anyhow::bail!("next blog comments failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    let comments = json
        .as_array()
        .map(|items| {
            items
                .iter()
                .map(|item| parse_next_episode_comment(item, current_user_id))
                .collect()
        })
        .unwrap_or_default();

    Ok(comments)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
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

    #[test]
    fn parse_bangumi_reviews_next_extracts_fields_correctly() {
        let json = json!({
            "total": 1,
            "data": [
                {
                    "id": 10,
                    "user": {
                        "id": 123,
                        "username": "reviewer_alice",
                        "nickname": "Alice",
                        "avatar": { "large": "//lain.bgm.tv/pic/user/l/000/00/01.jpg" }
                    },
                    "entry": {
                        "id": 1001,
                        "title": "A Great Masterpiece",
                        "summary": "This review analyzes the themes...",
                        "createdAt": 1700000000,
                        "replies": 5
                    }
                }
            ]
        });

        let page = parse_bangumi_reviews_next(&json);
        assert_eq!(page.total, Some(1));
        assert_eq!(page.reviews.len(), 1);

        let review = &page.reviews[0];
        assert_eq!(review.id, 10);
        assert_eq!(review.entry_id, 1001);
        assert_eq!(review.user_id, "reviewer_alice");
        assert_eq!(review.user_name, "Alice");
        assert_eq!(
            review.avatar,
            "https://lain.bgm.tv/pic/user/l/000/00/01.jpg"
        );
        assert_eq!(review.title, "A Great Masterpiece");
        assert_eq!(review.summary, "This review analyzes the themes...");
        assert_eq!(review.replies_count, 5);
    }

    #[tokio::test]
    async fn fetch_reviews_and_blog_detail_work_with_mock_server() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/p1/subjects/42/reviews",
                TestResponse::ok(json!({
                    "total": 1,
                    "data": [
                        {
                            "id": 101,
                            "user": { "username": "bob", "nickname": "Bob" },
                            "entry": { "id": 501, "title": "Test Review", "summary": "Short", "createdAt": 1600000000, "replies": 2 }
                        }
                    ]
                }).to_string()),
            ),
            TestRoute::get(
                "/p1/blogs/501",
                TestResponse::ok(json!({
                    "id": 501,
                    "title": "Test Review Detail",
                    "summary": "Short",
                    "content": "[b]Hello World[/b]",
                    "user": { "username": "bob", "nickname": "Bob" },
                    "createdAt": 1600000000,
                    "replies": 2,
                    "tags": ["anime", "review"]
                }).to_string()),
            ),
            TestRoute::get(
                "/p1/blogs/501/comments",
                TestResponse::ok(json!([
                    {
                        "id": 1,
                        "content": "Nice review!",
                        "state": 0,
                        "user": { "username": "charlie", "nickname": "Charlie" },
                        "createdAt": 1600000050,
                        "reactions": [{"value": 38, "users": [{"id": 99}]}]
                    }
                ]).to_string()),
            ),
        ])
        .await;

        point_bangumi_at(&server.base_url());
        {
            let mut config = crate::api::config::CONFIG.write().unwrap();
            config.bangumi_access_token = Some("token".to_string());
            config.bangumi_user_id = Some(99);
        }

        let reviews_page = fetch_bangumi_subject_reviews(42, 1).await.unwrap();
        assert_eq!(reviews_page.reviews.len(), 1);
        assert_eq!(reviews_page.reviews[0].title, "Test Review");

        let blog = fetch_bangumi_blog_detail(501).await.unwrap();
        assert_eq!(blog.title, "Test Review Detail");
        assert!(
            blog.content_html
                .contains("<span style=\"font-weight:bold;\">Hello World</span>")
        );
        assert_eq!(blog.tags, vec!["anime", "review"]);

        let comments = fetch_bangumi_blog_comments(501).await.unwrap();
        assert_eq!(comments.len(), 1);
        assert_eq!(comments[0].user_name, "Charlie");
        assert!(comments[0].reactions[0].reacted);

        let requests = server.requests();
        assert_eq!(requests.len(), 3);
        assert_eq!(requests[0].uri.query(), Some("limit=20&offset=0"),);
        for request in requests {
            assert_eq!(
                request
                    .headers
                    .get("authorization")
                    .and_then(|value| value.to_str().ok()),
                Some("Bearer token"),
            );
        }

        server.shutdown().await;
    }
}
