use super::types::*;
use super::util::*;
use anyhow::Context;
use serde_json::Value;

/// The OAuth access token currently stored in `RuntimeConfig`, or an error when
/// the user is not logged in. Authenticated endpoints call this first so they
/// fail fast with a clear message instead of sending an unauthenticated request
/// that the server would reject with a 401.
fn require_access_token() -> anyhow::Result<String> {
    crate::api::config::get_bangumi_access_token()
        .ok_or_else(|| anyhow::anyhow!("not logged in: no Bangumi access token"))
}

fn parse_bangumi_user_info(json: &Value, fallback_username: &str) -> BangumiUserInfo {
    let avatar = &json["avatar"];
    BangumiUserInfo {
        id: json["id"].as_i64().unwrap_or(0),
        username: json["username"]
            .as_str()
            .unwrap_or(fallback_username)
            .to_string(),
        nickname: json["nickname"].as_str().unwrap_or("").to_string(),
        sign: json["sign"].as_str().map(str::to_string),
        url: json["url"].as_str().map(str::to_string),
        avatar_large: avatar["large"].as_str().map(str::to_string),
        avatar_medium: avatar["medium"].as_str().map(str::to_string),
        avatar_small: avatar["small"].as_str().map(str::to_string),
    }
}

fn parse_bangumi_user_collections(json: &Value) -> anyhow::Result<Vec<BangumiUserCollectionEntry>> {
    let label = "bangumi.user.collections";
    let items = json["data"]
        .as_array()
        .ok_or_else(|| anyhow::anyhow!("{label}: response missing data[]"))?;

    Ok(items
        .iter()
        .filter_map(|item| {
            let subject_id = item["subject_id"].as_i64().filter(|id| *id > 0)?;
            let subject = &item["subject"];
            let images = &subject["images"];
            Some(BangumiUserCollectionEntry {
                updated_at: item["updated_at"].as_str().unwrap_or("").to_string(),
                comment: item["comment"].as_str().unwrap_or("").to_string(),
                tags: item["tags"]
                    .as_array()
                    .map(|tags| {
                        tags.iter()
                            .filter_map(|tag| tag.as_str().map(str::to_string))
                            .collect()
                    })
                    .unwrap_or_default(),
                subject_id,
                collection_type: json_i32(&item["type"]).unwrap_or(0),
                rate: json_i32(&item["rate"]).unwrap_or(0),
                private: item["private"].as_bool().unwrap_or(false),
                subject_name: subject["name"].as_str().unwrap_or("").to_string(),
                subject_name_cn: subject["name_cn"].as_str().unwrap_or("").to_string(),
                subject_short_summary: subject["short_summary"].as_str().unwrap_or("").to_string(),
                subject_score: subject["score"].as_f64().unwrap_or(0.0),
                subject_eps: json_i32(&subject["eps"]).unwrap_or(0),
                subject_collection_total: json_i32(&subject["collection_total"]).unwrap_or(0),
                image_small: images["small"].as_str().unwrap_or("").to_string(),
                image_grid: images["grid"].as_str().unwrap_or("").to_string(),
                image_large: images["large"].as_str().unwrap_or("").to_string(),
                image_medium: images["medium"].as_str().unwrap_or("").to_string(),
                image_common: images["common"].as_str().unwrap_or("").to_string(),
            })
        })
        .collect())
}

/// `GET /v0/users/{username}` — public user profile lookup.
pub(crate) async fn fetch_bangumi_user_info(username: String) -> anyhow::Result<BangumiUserInfo> {
    let url = format!(
        "{}/v0/users/{}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username)
    );
    let resp = crate::api::network::retry_request_bangumi_with_status(
        "bangumi.user.info",
        |client| {
            client
                .get(&url)
                .header("accept", "application/json")
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("bangumi.user.info HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("bangumi.user.info: invalid JSON: {}", truncate(&body, 256)))?;

    Ok(parse_bangumi_user_info(&json, &username))
}
/// `GET /v0/users/{username}/collections?subject_type=&limit=&offset=`
pub(crate) async fn fetch_bangumi_user_collections(
    username: String,
    subject_type: i32,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<BangumiUserCollectionEntry>> {
    let url = format!(
        "{}/v0/users/{}/collections?subject_type={}&limit={}&offset={}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username),
        subject_type,
        limit,
        offset
    );
    let label = "bangumi.user.collections";
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .get(&url)
                .header("accept", "application/json")
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;

    parse_bangumi_user_collections(&json)
}

/// `GET /v0/subjects/{subject_id}/image?type={image_type}`
///
/// Returns the raw bytes (caller writes them to disk or hands them to an
/// `Image.memory` widget). Pass-through byte stream — no caching here.
pub(crate) async fn fetch_bangumi_subject_image(
    subject_id: i64,
    image_type: String,
) -> anyhow::Result<Vec<u8>> {
    let url = format!(
        "{}/v0/subjects/{}/image?type={}",
        crate::api::config::get_bangumi_api_url(),
        subject_id,
        image_type
    );
    let resp = crate::api::network::retry_request_bangumi_with_status(
        "bangumi.subject.image",
        |client| {
            client
                .get(&url)
                .header("accept", "image/*")
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("bangumi.subject.image HTTP {status}");
    }
    let bytes = resp.bytes().await?;
    Ok(bytes.to_vec())
}

/// Fetch raw bytes from any bangumi-hosted image URL (avatars on `lain.*`,
/// subject covers, protocol-relative CDN links, etc.) through the ECH-capable
/// Rust HTTP client.
pub(crate) async fn fetch_bangumi_image_url(url: String) -> anyhow::Result<Vec<u8>> {
    let normalized = normalize_bangumi_url(&url);
    let parsed = reqwest::Url::parse(&normalized)
        .with_context(|| format!("bangumi.image.url invalid URL: {normalized}"))?;
    let host = parsed.host_str().unwrap_or_default().to_ascii_lowercase();
    let is_bangumi_host = matches!(
        host.as_str(),
        "bgm.tv" | "bangumi.tv" | "chii.in" | "bangumi.lol"
    ) || host.ends_with(".bgm.tv")
        || host.ends_with(".bangumi.tv")
        || host.ends_with(".chii.in")
        || host.ends_with(".bangumi.lol");
    if !is_bangumi_host {
        anyhow::bail!("bangumi.image.url host not allowed: {host}");
    }

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "bangumi.image.url",
        |client| {
            client
                .get(parsed.clone())
                .header("accept", "image/*")
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("bangumi.image.url HTTP {status}");
    }
    Ok(resp.bytes().await?.to_vec())
}

/// `GET /v0/me` — the authenticated user's own profile. Requires a stored
/// access token; this is how we populate `UserManager` after OAuth login
/// (replacing the old username-based public lookup).
pub(crate) async fn fetch_bangumi_me() -> anyhow::Result<BangumiUserInfo> {
    let token = require_access_token()?;
    let url = format!("{}/v0/me", crate::api::config::get_bangumi_api_url());
    let resp = crate::api::network::retry_request_bangumi_with_status(
        "bangumi.me",
        |client| {
            client
                .get(&url)
                .header("accept", "application/json")
                .header("Authorization", format!("Bearer {token}"))
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("bangumi.me HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("bangumi.me: invalid JSON: {}", truncate(&body, 256)))?;
    Ok(parse_bangumi_user_info(&json, ""))
}

/// `GET /v0/users/{username}/collections` — the authenticated user's own
/// collections. `type_filter` narrows to a single collection state
/// (1=wish … 5=dropped) when `Some`.
///
/// NOTE: unlike the write endpoint, the **list** endpoint does NOT accept the
/// literal `-` alias — `GET /v0/users/-/collections` returns 404 "user doesn't
/// exist". It requires the real `username`. We still send the bearer token so
/// the caller's private collections are included in the response.
pub(crate) async fn fetch_my_bangumi_collections(
    username: String,
    subject_type: i32,
    type_filter: Option<i32>,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<BangumiUserCollectionEntry>> {
    let token = require_access_token()?;
    let mut url = format!(
        "{}/v0/users/{}/collections?subject_type={}&limit={}&offset={}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username),
        subject_type,
        limit,
        offset
    );
    if let Some(type_filter) = type_filter {
        url.push_str(&format!("&type={type_filter}"));
    }
    let label = "bangumi.me.collections";
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .get(&url)
                .header("accept", "application/json")
                .header("Authorization", format!("Bearer {token}"))
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;
    parse_bangumi_user_collections(&json)
}

/// Read one authenticated collection state. A missing collection is a normal
/// result and is represented as `None`.
pub(crate) async fn fetch_my_bangumi_collection_type(
    subject_id: i64,
) -> anyhow::Result<Option<i32>> {
    let token = require_access_token()?;
    let url = format!(
        "{}/v0/users/-/collections/{}",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );
    let label = "bangumi.me.collection";
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .get(&url)
                .header("accept", "application/json")
                .header("Authorization", format!("Bearer {token}"))
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND {
        return Ok(None);
    }
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&text, 256));
    }
    let body = resp.text().await.context("bangumi collection read body")?;
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;
    Ok(json_i32(&json["type"]).filter(|value| matches!(value, 1 | 2 | 3 | 4 | 5)))
}

/// `POST /v0/users/-/collections/{subject_id}` — create or update the
/// authenticated user's collection for a subject (idempotent per the Bangumi
/// docs). `collection_type` is required (1=wish … 5=dropped); the rest are only
/// sent when `Some`, so an unset field leaves the server value untouched.
///
/// `rate` of `0` clears the score; `1..=10` sets it. Returns nothing — callers
/// re-fetch if they need the canonical stored state.
pub(crate) async fn update_bangumi_collection(
    subject_id: i64,
    collection_type: i32,
    rate: Option<i32>,
    comment: Option<String>,
    private: Option<bool>,
    tags: Option<Vec<String>>,
) -> anyhow::Result<()> {
    let token = require_access_token()?;
    let url = format!(
        "{}/v0/users/-/collections/{}",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let mut payload = serde_json::Map::new();
    payload.insert("type".to_string(), Value::from(collection_type));
    if let Some(rate) = rate {
        payload.insert("rate".to_string(), Value::from(rate));
    }
    if let Some(comment) = comment {
        payload.insert("comment".to_string(), Value::from(comment));
    }
    if let Some(private) = private {
        payload.insert("private".to_string(), Value::from(private));
    }
    if let Some(tags) = tags {
        payload.insert("tags".to_string(), Value::from(tags));
    }
    let body = Value::Object(payload);

    let label = "bangumi.collection.update";
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .post(&url)
                .header("accept", "application/json")
                .header("Authorization", format!("Bearer {token}"))
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
                .json(&body)
        },
        true,
    )
    .await?;
    let status = resp.status();
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&text, 256));
    }
    Ok(())
}

/// `DELETE /v0/users/-/collections/{subject_id}` — remove the authenticated
/// user's collection entry for a subject.
pub(crate) async fn delete_bangumi_collection(subject_id: i64) -> anyhow::Result<()> {
    let token = require_access_token()?;
    let url = format!(
        "{}/v0/users/-/collections/{}",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );
    let label = "bangumi.collection.delete";
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .delete(&url)
                .header("accept", "application/json")
                .header("Authorization", format!("Bearer {token}"))
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
        },
        true,
    )
    .await?;
    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND {
        return Ok(());
    }
    if !status.is_success() {
        let text = resp.text().await.unwrap_or_default();
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&text, 256));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::{Method, StatusCode};
    use serde_json::json;

    fn point_bangumi_at(base_url: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn user_info_defaults_missing_and_type_changed_fields() {
        let user = parse_bangumi_user_info(
            &json!({
                "id": "7",
                "nickname": "<b>Alice</b>",
                "sign": null,
                "avatar": {"large": 7, "small": "//lain.bgm.tv/a.jpg"}
            }),
            "fallback",
        );
        assert_eq!(user.id, 0);
        assert_eq!(user.username, "fallback");
        assert_eq!(user.nickname, "<b>Alice</b>");
        assert_eq!(user.sign, None);
        assert_eq!(user.avatar_large, None);
        assert_eq!(user.avatar_small.as_deref(), Some("//lain.bgm.tv/a.jpg"));
    }

    #[test]
    fn collections_preserve_unknown_enum_and_reject_overflow_and_missing_identity() {
        let collections = parse_bangumi_user_collections(&json!({"data": [
            {"subject_id": 1, "type": 99, "rate": 2147483648_i64, "tags": ["tag", null], "subject": {"eps": 2147483648_i64, "collection_total": 8}},
            {"subject_id": 0, "type": 3},
            {"type": 3}
        ]})).unwrap();
        assert_eq!(collections.len(), 1);
        assert_eq!(collections[0].collection_type, 99);
        assert_eq!(collections[0].rate, 0);
        assert_eq!(collections[0].tags, ["tag"]);
        assert_eq!(collections[0].subject_eps, 0);
        assert_eq!(collections[0].subject_collection_total, 8);
        assert!(parse_bangumi_user_collections(&json!({"data": null})).is_err());
    }

    #[tokio::test]
    async fn user_fetch_encodes_username_and_reports_api_error_body() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/users/alice%2Ftest",
            TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "slow down"),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let error = fetch_bangumi_user_info("alice/test".to_string())
            .await
            .unwrap_err();
        assert!(error.to_string().contains("429"));
        assert!(error.to_string().contains("slow down"));
        assert_eq!(server.requests().len(), 3);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn collections_fetch_sends_pagination_query_and_accept_header() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/users/alice/collections",
            TestResponse::ok(
                json!({"data": [{"subject_id": 7, "type": 3, "subject": {"name": "Anime"}}]})
                    .to_string(),
            ),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let result = fetch_bangumi_user_collections("alice".to_string(), 2, 30, 60)
            .await
            .unwrap();
        assert_eq!(result.len(), 1);
        let request = &server.requests()[0];
        assert_eq!(
            request.uri.query(),
            Some("subject_type=2&limit=30&offset=60")
        );
        assert_eq!(request.headers["accept"], "application/json");
        server.shutdown().await;
    }

    #[tokio::test]
    async fn subject_image_fetch_returns_raw_bytes_and_rejects_error_status() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/v0/subjects/7/image",
                TestResponse::ok([0_u8, 1, 2, 255].as_slice()),
            ),
            TestRoute::get(
                "/v0/subjects/8/image",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url());

        assert_eq!(
            fetch_bangumi_subject_image(7, "large".to_string())
                .await
                .unwrap(),
            [0, 1, 2, 255]
        );
        assert!(
            fetch_bangumi_subject_image(8, "large".to_string())
                .await
                .is_err()
        );
        assert_eq!(server.requests()[0].uri.query(), Some("type=large"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn arbitrary_image_fetch_rejects_non_bangumi_hosts_before_network() {
        let error = fetch_bangumi_image_url("https://example.com/image.jpg".to_string())
            .await
            .unwrap_err();
        assert!(error.to_string().contains("host not allowed"));
    }

    #[tokio::test]
    async fn authenticated_endpoints_fail_fast_without_a_token() {
        let _config = isolate_runtime_config();
        crate::api::config::clear_bangumi_access_token();
        assert!(
            fetch_bangumi_me()
                .await
                .unwrap_err()
                .to_string()
                .contains("not logged in")
        );
        assert!(
            fetch_my_bangumi_collections("alice".to_string(), 2, None, 30, 0)
                .await
                .unwrap_err()
                .to_string()
                .contains("not logged in")
        );
        assert!(
            update_bangumi_collection(7, 3, None, None, None, None)
                .await
                .unwrap_err()
                .to_string()
                .contains("not logged in")
        );
        assert!(
            delete_bangumi_collection(7)
                .await
                .unwrap_err()
                .to_string()
                .contains("not logged in")
        );
    }

    #[tokio::test]
    async fn me_sends_bearer_and_parses_profile() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/me",
            TestResponse::ok(
                json!({"id": 42, "username": "alice", "nickname": "Alice"}).to_string(),
            ),
        )])
        .await;
        point_bangumi_at(&server.base_url());
        crate::api::config::set_bangumi_access_token("tok-123".to_string());

        let user = fetch_bangumi_me().await.unwrap();
        assert_eq!(user.id, 42);
        assert_eq!(user.username, "alice");
        assert_eq!(
            server.requests()[0].headers["authorization"],
            "Bearer tok-123"
        );
        server.shutdown().await;
    }

    #[tokio::test]
    async fn my_collections_send_type_filter_only_when_nonzero() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/users/alice/collections",
            TestResponse::ok(
                json!({"data": [{"subject_id": 7, "type": 3, "subject": {"name": "Anime"}}]})
                    .to_string(),
            ),
        )])
        .await;
        point_bangumi_at(&server.base_url());
        crate::api::config::set_bangumi_access_token("tok".to_string());

        fetch_my_bangumi_collections("alice".to_string(), 2, None, 30, 0)
            .await
            .unwrap();
        fetch_my_bangumi_collections("alice".to_string(), 2, Some(3), 30, 60)
            .await
            .unwrap();
        let requests = server.requests();
        assert_eq!(
            requests[0].uri.query(),
            Some("subject_type=2&limit=30&offset=0")
        );
        assert_eq!(
            requests[1].uri.query(),
            Some("subject_type=2&limit=30&offset=60&type=3")
        );
        server.shutdown().await;
    }

    #[tokio::test]
    async fn collection_update_omits_absent_optional_fields() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::post(
            "/v0/users/-/collections/7",
            TestResponse::new(StatusCode::ACCEPTED, ""),
        )])
        .await;
        point_bangumi_at(&server.base_url());
        crate::api::config::set_bangumi_access_token("tok".to_string());

        update_bangumi_collection(7, 3, Some(8), None, None, None)
            .await
            .unwrap();
        let request = &server.requests()[0];
        let body: serde_json::Value = serde_json::from_slice(&request.body).unwrap();
        assert_eq!(body["type"], 3);
        assert_eq!(body["rate"], 8);
        assert!(body.get("comment").is_none());
        assert!(body.get("tags").is_none());
        assert_eq!(request.headers["authorization"], "Bearer tok");
        server.shutdown().await;
    }

    #[tokio::test]
    async fn collection_delete_sends_bearer() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::new(
            Method::DELETE,
            "/v0/users/-/collections/7",
            TestResponse::new(StatusCode::NO_CONTENT, ""),
        )])
        .await;
        point_bangumi_at(&server.base_url());
        crate::api::config::set_bangumi_access_token("tok".to_string());

        delete_bangumi_collection(7).await.unwrap();
        let request = &server.requests()[0];
        assert_eq!(request.method, Method::DELETE);
        assert_eq!(request.headers["authorization"], "Bearer tok");
        server.shutdown().await;
    }
}
