pub(super) fn merge_cookie_strings(
    configured: Option<&str>,
    runtime: Option<&str>,
) -> Option<String> {
    let mut ordered_names: Vec<String> = Vec::new();
    let mut cookies = std::collections::HashMap::<String, String>::new();

    for raw in [configured, runtime].into_iter().flatten() {
        for part in raw.split(';') {
            let trimmed = part.trim();
            if trimmed.is_empty() {
                continue;
            }

            let mut segments = trimmed.splitn(2, '=');
            let name = segments.next().unwrap_or("").trim();
            let value = segments.next().unwrap_or("").trim();
            if name.is_empty() {
                continue;
            }

            let key = name.to_string();
            if !cookies.contains_key(&key) {
                ordered_names.push(key.clone());
            }
            cookies.insert(key, value.to_string());
        }
    }

    if ordered_names.is_empty() {
        None
    } else {
        Some(
            ordered_names
                .into_iter()
                .filter_map(|name| {
                    cookies
                        .get(&name)
                        .map(|value| format!("{}={}", name, value))
                })
                .collect::<Vec<_>>()
                .join("; "),
        )
    }
}

pub(super) fn apply_cookie_header(
    request: reqwest::RequestBuilder,
    cookies: Option<&str>,
) -> reqwest::RequestBuilder {
    if let Some(cookies) = cookies.filter(|s| !s.trim().is_empty()) {
        request.header("Cookie", cookies)
    } else {
        request
    }
}

pub(super) fn apply_browser_page_headers(
    request: reqwest::RequestBuilder,
    target_url: &str,
    referer: Option<&str>,
) -> reqwest::RequestBuilder {
    let fallback_referer = url::Url::parse(target_url).ok().and_then(|u| {
        let origin = u.origin().ascii_serialization();
        (origin != "null").then(|| format!("{origin}/"))
    });

    let mut request = request
        .header(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
             (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0",
        )
        .header(
            "sec-ch-ua",
            "\"Microsoft Edge\";v=\"147\", \"Not.A/Brand\";v=\"8\", \"Chromium\";v=\"147\"",
        )
        .header("sec-ch-ua-mobile", "?0")
        .header("sec-ch-ua-platform", "\"Windows\"")
        .header(
            "Accept",
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,\
             image/webp,image/apng,*/*;q=0.8",
        )
        .header("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8,en-US;q=0.7")
        .header("Sec-Fetch-Dest", "document")
        .header("Sec-Fetch-Mode", "navigate")
        .header("Sec-Fetch-Site", "same-origin")
        .header("Sec-Fetch-User", "?1")
        .header("Priority", "u=0, i")
        .header("Upgrade-Insecure-Requests", "1");

    if let Some(value) = referer
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.to_string())
        .or(fallback_referer)
    {
        request = request.header("Referer", value);
    }

    request
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use axum::http::Method;

    #[test]
    fn runtime_cookies_override_configured_values_without_reordering() {
        assert_eq!(
            merge_cookie_strings(
                Some("session=old; theme=dark"),
                Some("session=new; token=abc")
            ),
            Some("session=new; theme=dark; token=abc".to_string())
        );
    }

    #[test]
    fn empty_cookie_inputs_produce_no_header_value() {
        assert_eq!(merge_cookie_strings(Some(" ; "), None), None);
    }

    #[tokio::test]
    async fn browser_headers_preserve_custom_headers_cookies_and_referer_port() {
        let server = TestServer::spawn([TestRoute::get("/page", TestResponse::ok("ok"))]).await;
        let client = reqwest::Client::builder().no_proxy().build().unwrap();
        let target_url = server.url("/page");
        let cookies = merge_cookie_strings(
            Some("session=configured; theme=dark"),
            Some("session=runtime; token=secret"),
        );

        let response = apply_browser_page_headers(
            apply_cookie_header(
                client.get(&target_url).header("x-custom-source", "kept"),
                cookies.as_deref(),
            ),
            &target_url,
            None,
        )
        .send()
        .await
        .unwrap();
        assert!(response.status().is_success());

        let requests = server.requests();
        let request = &requests[0];
        assert_eq!(request.headers["x-custom-source"], "kept");
        assert_eq!(
            request.headers["cookie"],
            "session=runtime; theme=dark; token=secret"
        );
        assert_eq!(
            request.headers["referer"],
            format!("{}/", server.base_url())
        );
        assert!(
            request.headers["user-agent"]
                .to_str()
                .unwrap()
                .contains("Edg/147")
        );
        assert_eq!(server.request_count(Method::GET, "/page"), 1);

        server.shutdown().await;
    }

    #[tokio::test]
    async fn explicit_referer_overrides_fallback_origin() {
        let server = TestServer::spawn([TestRoute::get("/page", TestResponse::ok("ok"))]).await;
        let client = reqwest::Client::builder().no_proxy().build().unwrap();

        apply_browser_page_headers(
            client.get(server.url("/page")),
            &server.url("/page"),
            Some("https://origin.example/detail/7"),
        )
        .send()
        .await
        .unwrap();

        assert_eq!(
            server.requests()[0].headers["referer"],
            "https://origin.example/detail/7"
        );
        server.shutdown().await;
    }
}
