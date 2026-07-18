use super::types::*;
use super::util::*;
use anyhow::Context;
use serde_json::Value;

/// `GET /v0/users/{username}` — public user profile lookup.
pub(crate) async fn fetch_bangumi_user_info(username: String) -> anyhow::Result<BangumiUserInfo> {
    let url = format!(
        "{}/v0/users/{}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username)
    );
    let resp = crate::api::network::retry_request_bangumi("bangumi.user.info", |client| {
        client
            .get(&url)
            .header("accept", "application/json")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("bangumi.user.info HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("bangumi.user.info: invalid JSON: {}", truncate(&body, 256)))?;

    let avatar = json.get("avatar").cloned().unwrap_or(Value::Null);
    Ok(BangumiUserInfo {
        id: json.get("id").and_then(|v| v.as_i64()).unwrap_or(0),
        username: json
            .get("username")
            .and_then(|v| v.as_str())
            .unwrap_or(&username)
            .to_string(),
        nickname: json
            .get("nickname")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        sign: json
            .get("sign")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        url: json
            .get("url")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        avatar_large: avatar
            .get("large")
            .and_then(|v| v.as_str())
            .map(str::to_string),
        avatar_medium: avatar
            .get("medium")
            .and_then(|v| v.as_str())
            .map(str::to_string),
        avatar_small: avatar
            .get("small")
            .and_then(|v| v.as_str())
            .map(str::to_string),
    })
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
    let resp = crate::api::network::retry_request_bangumi(label, |client| {
        client
            .get(&url)
            .header("accept", "application/json")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;

    let arr = json
        .get("data")
        .and_then(|v| v.as_array())
        .ok_or_else(|| anyhow::anyhow!("{label}: response missing data[]"))?;

    let mut out = Vec::with_capacity(arr.len());
    for item in arr {
        let subject = item.get("subject").cloned().unwrap_or(Value::Null);
        let images = subject.get("images").cloned().unwrap_or(Value::Null);

        out.push(BangumiUserCollectionEntry {
            updated_at: item
                .get("updated_at")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            comment: item
                .get("comment")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            tags: item
                .get("tags")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|t| t.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default(),
            subject_id: item.get("subject_id").and_then(|v| v.as_i64()).unwrap_or(0),
            collection_type: item.get("type").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            rate: item.get("rate").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            private: item
                .get("private")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
            subject_name: subject
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_name_cn: subject
                .get("name_cn")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_short_summary: subject
                .get("short_summary")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_score: subject.get("score").and_then(|v| v.as_f64()).unwrap_or(0.0),
            subject_eps: subject.get("eps").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            subject_collection_total: subject
                .get("collection_total")
                .and_then(|v| v.as_i64())
                .unwrap_or(0) as i32,
            image_small: images
                .get("small")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_grid: images
                .get("grid")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_large: images
                .get("large")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_medium: images
                .get("medium")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_common: images
                .get("common")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
        });
    }
    Ok(out)
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
    let resp = crate::api::network::retry_request_bangumi("bangumi.subject.image", |client| {
        client
            .get(&url)
            .header("accept", "image/*")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
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

    let resp = crate::api::network::retry_request_bangumi("bangumi.image.url", |client| {
        client
            .get(parsed.clone())
            .header("accept", "image/*")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("bangumi.image.url HTTP {status}");
    }
    Ok(resp.bytes().await?.to_vec())
}
