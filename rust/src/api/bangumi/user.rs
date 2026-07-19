use super::types::*;
use super::util::*;
use anyhow::Context;
use serde_json::Value;

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
        assert_eq!(server.requests().len(), 1);
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
}
