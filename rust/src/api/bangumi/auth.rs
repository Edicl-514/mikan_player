//! Bangumi OAuth 2.0 (Authorization Code flow).
//!
//! The `client_secret` does not cross the FRB boundary: the authorization
//! `code` → token exchange, and the later refresh, happen here in Rust. This is
//! an ownership boundary, not a secrecy guarantee: credentials embedded in a
//! distributed client binary can still be extracted and must be treated as
//! recoverable/rotatable by release engineering.
//!
//! Credentials are read from compile-time env vars injected by `build.rs`
//! (`BANGUMI_APP_ID` / `BANGUMI_APP_SECRET`), mirroring `danmaku.rs`.

use super::types::*;
use super::util::truncate;
use anyhow::Context;
use serde_json::Value;

/// OAuth endpoints live on the main site and *must* target `bgm.tv` (not the
/// `bangumi.tv` alias) — a POST to `bangumi.tv/oauth/access_token` 301-redirects
/// to `bgm.tv` and reqwest drops the form body across the redirect, failing the
/// exchange. OAuth also deliberately bypasses the optional content reverse
/// proxy because these requests contain credentials and user tokens.
fn oauth_access_token_url() -> String {
    format!(
        "{}/oauth/access_token",
        crate::api::config::get_bangumi_oauth_url()
    )
}

/// The OAuth authorization page URL the login WebView opens. Built in Rust so
/// the `bgm.tv` host and the `client_id` live in one place; `redirect_uri` must
/// match the one later passed to [`exchange_bangumi_oauth_code`] byte-for-byte.
pub(crate) fn bangumi_oauth_authorize_url(redirect_uri: String) -> anyhow::Result<String> {
    let client_id = get_client_id()?;
    Ok(format!(
        "{}/oauth/authorize?client_id={}&response_type=code&scope={}&redirect_uri={}",
        crate::api::config::get_bangumi_oauth_url(),
        urlencoding::encode(&client_id),
        urlencoding::encode("write:collection"),
        urlencoding::encode(&redirect_uri)
    ))
}

/// Read the OAuth `client_id` (`BANGUMI_APP_ID`) baked in at compile time.
fn get_client_id() -> anyhow::Result<String> {
    match option_env!("BANGUMI_APP_ID") {
        Some(v) if !v.is_empty() => Ok(v.to_string()),
        _ => anyhow::bail!("BANGUMI_APP_ID not set during compilation"),
    }
}

/// Read the OAuth `client_secret` (`BANGUMI_APP_SECRET`) baked in at compile
/// time. The value is never logged or returned across the bridge.
fn get_client_secret() -> anyhow::Result<String> {
    match option_env!("BANGUMI_APP_SECRET") {
        Some(v) if !v.is_empty() => Ok(v.to_string()),
        _ => anyhow::bail!("BANGUMI_APP_SECRET not set during compilation"),
    }
}

/// The OAuth `client_id` is not a secret (it appears in the authorization URL
/// that the WebView opens), so we expose it to Dart for building that URL.
pub(crate) fn bangumi_oauth_client_id() -> anyhow::Result<String> {
    get_client_id()
}

fn parse_oauth_token(json: &Value) -> anyhow::Result<BangumiOAuthToken> {
    let access_token = json["access_token"]
        .as_str()
        .filter(|s| !s.is_empty())
        .ok_or_else(|| anyhow::anyhow!("oauth: response missing access_token"))?
        .to_string();
    let refresh_token = json["refresh_token"].as_str().unwrap_or("").to_string();
    let expires_in = json["expires_in"].as_i64().unwrap_or(0);
    let user_id = json["user_id"].as_i64().unwrap_or(0);
    Ok(BangumiOAuthToken {
        access_token,
        refresh_token,
        expires_in,
        user_id,
    })
}

async fn post_oauth_form(
    label: &'static str,
    form: Vec<(&'static str, String)>,
) -> anyhow::Result<BangumiOAuthToken> {
    let url = oauth_access_token_url();
    // `reqwest` is built with `default-features = false`, which drops the
    // `.form()` helper. Encode the `application/x-www-form-urlencoded` body
    // ourselves with the `urlencoding` crate (already a direct dependency).
    let body = form
        .iter()
        .map(|(key, value)| {
            format!(
                "{}={}",
                urlencoding::encode(key),
                urlencoding::encode(value)
            )
        })
        .collect::<Vec<_>>()
        .join("&");
    let resp = crate::api::network::retry_request_bangumi_with_status(
        label,
        |client| {
            client
                .post(&url)
                .header("accept", "application/json")
                .header("content-type", "application/x-www-form-urlencoded")
                .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
                .body(body.clone())
        },
        true,
    )
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        // The body may echo the (invalid) code but never the secret; still
        // truncate so we don't dump a huge error page into logs.
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;
    parse_oauth_token(&json)
}

/// Exchange an authorization `code` (captured from the OAuth redirect) for an
/// access/refresh token pair. `redirect_uri` must byte-for-byte match the one
/// used to build the authorization URL.
pub(crate) async fn exchange_bangumi_oauth_code(
    code: String,
    redirect_uri: String,
) -> anyhow::Result<BangumiOAuthToken> {
    let client_id = get_client_id()?;
    let client_secret = get_client_secret()?;
    post_oauth_form(
        "bangumi.oauth.exchange",
        vec![
            ("grant_type", "authorization_code".to_string()),
            ("client_id", client_id),
            ("client_secret", client_secret),
            ("code", code),
            ("redirect_uri", redirect_uri),
        ],
    )
    .await
}

/// Refresh an expired/expiring access token using the stored `refresh_token`.
pub(crate) async fn refresh_bangumi_oauth_token(
    refresh_token: String,
    redirect_uri: String,
) -> anyhow::Result<BangumiOAuthToken> {
    let client_id = get_client_id()?;
    let client_secret = get_client_secret()?;
    post_oauth_form(
        "bangumi.oauth.refresh",
        vec![
            ("grant_type", "refresh_token".to_string()),
            ("client_id", client_id),
            ("client_secret", client_secret),
            ("refresh_token", refresh_token),
            ("redirect_uri", redirect_uri),
        ],
    )
    .await
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
        config.bangumi_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn parse_defaults_missing_optional_fields_and_requires_access_token() {
        let token = parse_oauth_token(&json!({
            "access_token": "abc",
            "expires_in": 2592000,
            "user_id": 7
        }))
        .unwrap();
        assert_eq!(token.access_token, "abc");
        assert_eq!(token.refresh_token, "");
        assert_eq!(token.expires_in, 2592000);
        assert_eq!(token.user_id, 7);

        assert!(parse_oauth_token(&json!({"token_type": "Bearer"})).is_err());
    }

    #[tokio::test]
    async fn exchange_posts_form_and_parses_tokens() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::post(
            "/oauth/access_token",
            TestResponse::ok(
                json!({
                    "access_token": "at",
                    "refresh_token": "rt",
                    "expires_in": 2592000,
                    "user_id": 42
                })
                .to_string(),
            ),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let token = exchange_bangumi_oauth_code(
            "the-code".to_string(),
            "http://127.0.0.1:0/callback".to_string(),
        )
        .await
        .unwrap();
        assert_eq!(token.access_token, "at");
        assert_eq!(token.refresh_token, "rt");
        assert_eq!(token.user_id, 42);

        let request = &server.requests()[0];
        let body = String::from_utf8_lossy(&request.body);
        assert!(body.contains("grant_type=authorization_code"));
        assert!(body.contains("code=the-code"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn exchange_reports_http_error_body() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::post(
            "/oauth/access_token",
            TestResponse::new(StatusCode::BAD_REQUEST, "invalid code"),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let error = exchange_bangumi_oauth_code("bad".to_string(), "uri".to_string())
            .await
            .unwrap_err();
        assert!(error.to_string().contains("400"));
        assert!(error.to_string().contains("invalid code"));
        server.shutdown().await;
    }
}
