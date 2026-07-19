use anyhow::Context;
#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

use log::warn;
use reqwest::{Client, ClientBuilder, Proxy, StatusCode};
use rustls::{ClientConfig, RootCertStore};
use std::error::Error as StdError;
use std::net::SocketAddr;
#[cfg(target_os = "windows")]
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, LazyLock, RwLock};
use std::time::Duration;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x08000000;
const DEFAULT_USER_AGENT: &str = "MikanPlayer/1.0";

pub(crate) fn get_system_proxy() -> Option<String> {
    #[cfg(target_os = "windows")]
    {
        let output = Command::new("reg")
            .creation_flags(CREATE_NO_WINDOW)
            .args(&[
                "query",
                "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                "/v",
                "ProxyEnable",
            ])
            .output()
            .ok()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        if !stdout.contains("0x1") {
            return None;
        }

        let output = Command::new("reg")
            .creation_flags(CREATE_NO_WINDOW)
            .args(&[
                "query",
                "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                "/v",
                "ProxyServer",
            ])
            .output()
            .ok()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if line.contains("ProxyServer") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if let Some(addr) = parts.last() {
                    let target_addr = if addr.contains("=") {
                        addr.split(';')
                            .find(|s| s.starts_with("http="))
                            .map(|s| s.trim_start_matches("http="))
                            .or_else(|| addr.split('=').last())
                            .unwrap_or(addr)
                    } else {
                        addr
                    };

                    let proxy_url = if !target_addr.starts_with("http") {
                        format!("http://{}", target_addr)
                    } else {
                        target_addr.to_string()
                    };
                    return Some(proxy_url);
                }
            }
        }
    }

    None
}

/// The shared plain-SNI reqwest client. Used for everything that does NOT go
/// to a Cloudflare-hosted bangumi endpoint (mikan, dmhy, dandanplay, DoH, etc.).
static SHARED_CLIENT: LazyLock<Client> =
    LazyLock::new(|| create_client().expect("Failed to create shared HTTP client"));

pub(crate) fn get_shared_client() -> &'static Client {
    &SHARED_CLIENT
}

struct EchClientSlot {
    client: &'static Client,
    epoch: u64,
}

static ECH_CLIENT_SLOT: RwLock<Option<EchClientSlot>> = RwLock::new(None);
static ECH_EPOCH: AtomicU64 = AtomicU64::new(0);

pub(crate) fn invalidate_ech_client() {
    ECH_EPOCH.fetch_add(1, Ordering::SeqCst);
}

/// Get (or lazily build) the ECH-enabled reqwest client used for bangumi
/// requests when `bangumi_use_ech` is on. Holds the bytes needed by rustls
/// for HPKE; the cached `EchConfig` is read from `crate::api::ech`.
///
/// Falls back to the plain client when ECH hasn't been fetched yet — caller
/// paths keep working unchanged. The caller may force a refresh via
/// `crate::api::ech::refresh_bangumi_ech_config`.
///
/// The client is rebuilt when the ECHConfig cache is refreshed (tracked by
/// `ECH_EPOCH`) so that key rotations take effect without a process restart.
/// Each rebuilt client is leaked into `'static` — this is acceptable because
/// there are at most a handful of rebuilds per process lifetime (one per
/// ECHConfig key rotation, roughly daily).
pub(crate) fn get_ech_client() -> &'static Client {
    let current_epoch = ECH_EPOCH.load(Ordering::SeqCst);

    let needs_rebuild = {
        let guard = ECH_CLIENT_SLOT.read().unwrap();
        match guard.as_ref() {
            Some(slot) => slot.epoch != current_epoch,
            None => true,
        }
    };

    if needs_rebuild {
        let mut guard = ECH_CLIENT_SLOT.write().unwrap();
        match guard.as_ref() {
            Some(slot) if slot.epoch == current_epoch => {}
            _ => {
                let client: &'static Client = match build_ech_client() {
                    Ok(c) => Box::leak(Box::new(c)),
                    Err(e) => {
                        log::warn!(
                            "ECH client unavailable ({}); falling back to shared client",
                            e
                        );
                        get_shared_client()
                    }
                };
                *guard = Some(EchClientSlot {
                    client,
                    epoch: current_epoch,
                });
            }
        }
    }

    let guard = ECH_CLIENT_SLOT.read().unwrap();
    guard.as_ref().unwrap().client
}

fn build_ech_client() -> anyhow::Result<Client> {
    let ech_cfg = crate::api::ech::current_ech_config()
        .ok_or_else(|| anyhow::anyhow!("ECHConfig not in cache yet"))?;

    // Pin every bangumi host directly to the Cloudflare edge IPs advertised in
    // the HTTPS RR's `ipv4hint`. The GFW poisons the system resolver for
    // `*.bgm.tv` / `chii.in` (it returns Facebook sinkhole IPs such as
    // 31.13.94.41), so without pinning the ECH-encrypted ClientHello still
    // dials a blocked IP and the handshake times out. Pinning makes reqwest
    // skip DNS entirely for these hosts and connect to a real Cloudflare anycast
    // address — mirroring the custom DialContext in the Go ECH demo. Port 0
    // tells reqwest to use the URL's conventional port (443 for https).
    let pinned_ips = crate::api::ech::current_ech_resolve_ips();
    let pinned_addrs: Vec<SocketAddr> = pinned_ips
        .iter()
        .map(|ip| SocketAddr::new(*ip, 0))
        .collect();

    let roots = RootCertStore {
        roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
    };
    let provider = Arc::new(rustls::crypto::aws_lc_rs::default_provider());
    let tls_config = ClientConfig::builder_with_provider(provider.clone())
        .with_ech(ech_cfg.into())
        .context("rustls ConfigBuilder::with_ech")?
        .with_root_certificates(roots)
        .with_no_client_auth();

    let mut builder =
        configure_client_builder(Client::builder()).tls_backend_preconfigured(tls_config);

    let hosts = crate::api::config::bangumi_canonical_hosts();
    if !pinned_addrs.is_empty() {
        for host in &hosts {
            builder = builder.resolve_to_addrs(host, &pinned_addrs);
        }
        log::info!(
            "ECH client: pinned {} bangumi host(s) to {} Cloudflare edge IP(s)",
            hosts.len(),
            pinned_addrs.len()
        );
    } else {
        log::warn!(
            "ECH client: no ipv4hint available — bangumi hosts will resolve via the system \
             DNS (likely poisoned in mainland China); the ECH handshake may time out"
        );
    }

    if let Some(proxy_url) = get_system_proxy() {
        match Proxy::all(&proxy_url) {
            Ok(proxy) => {
                builder = builder.proxy(proxy);
            }
            Err(e) => {
                warn!("Failed to create proxy from {}: {}", proxy_url, e);
            }
        }
    }

    Ok(builder.build()?)
}

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn create_client() -> reqwest::Result<Client> {
    let roots = RootCertStore {
        roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
    };
    let tls_config =
        ClientConfig::builder_with_provider(rustls::crypto::aws_lc_rs::default_provider().into())
            .with_safe_default_protocol_versions()
            .expect("rustls safe default protocol versions should be valid")
            .with_root_certificates(roots)
            .with_no_client_auth();

    let mut builder =
        configure_client_builder(Client::builder()).tls_backend_preconfigured(tls_config);

    if let Some(proxy_url) = get_system_proxy() {
        match Proxy::all(&proxy_url) {
            Ok(proxy) => {
                builder = builder.proxy(proxy);
            }
            Err(e) => {
                warn!("Failed to create proxy from {}: {}", proxy_url, e);
            }
        }
    }

    builder.build()
}

fn configure_client_builder(builder: ClientBuilder) -> ClientBuilder {
    builder
        .user_agent(DEFAULT_USER_AGENT)
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(30))
        .tcp_keepalive(Some(Duration::from_secs(60)))
        .pool_idle_timeout(Duration::from_secs(90))
        .pool_max_idle_per_host(4)
}

#[derive(Clone, Copy, Debug)]
struct RetryPolicy {
    max_retries: u32,
    initial_delay: Duration,
}

impl RetryPolicy {
    fn delay_before_retry(self, retry_index: u32) -> Duration {
        (0..retry_index).fold(self.initial_delay, |delay, _| delay.saturating_mul(2))
    }
}

const DEFAULT_RETRY_POLICY: RetryPolicy = RetryPolicy {
    max_retries: 2,
    initial_delay: Duration::from_millis(500),
};

fn is_transient_status(status: StatusCode) -> bool {
    matches!(
        status,
        StatusCode::REQUEST_TIMEOUT
            | StatusCode::TOO_EARLY
            | StatusCode::TOO_MANY_REQUESTS
            | StatusCode::INTERNAL_SERVER_ERROR
            | StatusCode::BAD_GATEWAY
            | StatusCode::SERVICE_UNAVAILABLE
            | StatusCode::GATEWAY_TIMEOUT
    )
}

fn is_certificate_error(error: &(dyn StdError + 'static)) -> bool {
    let mut current = Some(error);
    while let Some(error) = current {
        if matches!(
            error.downcast_ref::<rustls::Error>(),
            Some(rustls::Error::InvalidCertificate(_))
        ) {
            return true;
        }
        let message = error.to_string().to_ascii_lowercase();
        if message.contains("certificate")
            && (message.contains("invalid")
                || message.contains("unknown issuer")
                || message.contains("unknownissuer")
                || message.contains("not valid"))
        {
            return true;
        }
        current = error.source();
    }
    false
}

fn is_transient_error(e: &reqwest::Error) -> bool {
    (e.is_timeout() || e.is_connect()) && !is_certificate_error(e)
}

fn request_error_log_summary(e: &reqwest::Error) -> &'static str {
    if e.is_timeout() {
        "request timed out"
    } else if is_certificate_error(e) {
        "TLS certificate validation failed"
    } else if e.is_connect() {
        "connection failed"
    } else {
        "request failed"
    }
}

/// Returns the ECH client when ECH is enabled and the ECHConfig is cached,
/// otherwise the plain shared client. The caller **must** only use this for
/// bangumi-domain requests — the embedded `EchConfig` targets Cloudflare's
/// shared `cloudflare-ech.com` public name.
pub(crate) fn client_for_bangumi() -> &'static Client {
    if crate::api::config::get_bangumi_use_ech() && crate::api::ech::has_ech_config() {
        get_ech_client()
    } else {
        get_shared_client()
    }
}

pub(crate) async fn retry_request(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
) -> anyhow::Result<reqwest::Response> {
    retry_request_with_status(label, request_fn, false).await
}

pub(crate) async fn retry_request_with_status(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
    allow_error_status: bool,
) -> anyhow::Result<reqwest::Response> {
    let client = get_shared_client();
    retry_request_inner(label, request_fn, allow_error_status, client).await
}

/// Like [`retry_request`] but routes through the ECH-capable client when
/// ECH is enabled. **Only use this for bangumi-domain requests** (bgm.tv,
/// bangumi.tv, chii.in, api.bgm.tv, next.bgm.tv, lain.bgm.tv, etc.).
pub(crate) async fn retry_request_bangumi(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
) -> anyhow::Result<reqwest::Response> {
    retry_request_bangumi_with_status(label, request_fn, false).await
}

pub(crate) async fn retry_request_bangumi_with_status(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
    allow_error_status: bool,
) -> anyhow::Result<reqwest::Response> {
    if crate::api::config::get_bangumi_use_ech() {
        if let Err(e) = crate::api::ech::ensure_fresh_ech_config().await {
            log::warn!(
                "ECHConfig unavailable for {label} ({}); falling back to plain client",
                e
            );
        }
    }
    let client = client_for_bangumi();
    retry_request_inner(label, request_fn, allow_error_status, client).await
}

async fn retry_request_inner(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
    allow_error_status: bool,
    client: &Client,
) -> anyhow::Result<reqwest::Response> {
    retry_request_inner_with_policy(
        label,
        request_fn,
        allow_error_status,
        client,
        DEFAULT_RETRY_POLICY,
    )
    .await
}

async fn retry_request_inner_with_policy(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
    allow_error_status: bool,
    client: &Client,
    policy: RetryPolicy,
) -> anyhow::Result<reqwest::Response> {
    let max_attempts = policy.max_retries + 1;

    for attempt in 0..max_attempts {
        let builder = request_fn(client);
        match builder.send().await {
            Ok(resp) => {
                let status = resp.status();
                if is_transient_status(status) && attempt < policy.max_retries {
                    let delay = policy.delay_before_retry(attempt);
                    log::warn!(
                        "{}: HTTP {} on attempt {}/{}, retrying in {}ms",
                        label,
                        status,
                        attempt + 1,
                        max_attempts,
                        delay.as_millis()
                    );
                    if !delay.is_zero() {
                        tokio::time::sleep(delay).await;
                    }
                    continue;
                }
                if allow_error_status {
                    return Ok(resp);
                }
                return match resp.error_for_status() {
                    Ok(resp) => Ok(resp),
                    Err(error) => Err(error.without_url().into()),
                };
            }
            Err(e) if is_transient_error(&e) && attempt < policy.max_retries => {
                let delay = policy.delay_before_retry(attempt);
                log::warn!(
                    "{}: {} on attempt {}/{}, retrying in {}ms",
                    label,
                    request_error_log_summary(&e),
                    attempt + 1,
                    max_attempts,
                    delay.as_millis()
                );
                if !delay.is_zero() {
                    tokio::time::sleep(delay).await;
                }
                continue;
            }
            Err(e) => {
                return Err(e.without_url().into());
            }
        }
    }

    unreachable!()
}

#[cfg(test)]
mod net_tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use axum::http::Method;
    use brotli::CompressorWriter;
    use flate2::Compression;
    use flate2::write::GzEncoder;
    use rcgen::generate_simple_self_signed;
    use serde_json::Value;
    use std::io::Write;
    use std::sync::atomic::{AtomicUsize, Ordering as AtomicOrdering};
    use tokio::net::TcpListener;
    use tokio_rustls::TlsAcceptor;

    const NO_RETRY_DELAY: RetryPolicy = RetryPolicy {
        max_retries: 2,
        initial_delay: Duration::ZERO,
    };

    fn no_proxy_client() -> Client {
        configure_client_builder(Client::builder())
            .no_proxy()
            .build()
            .unwrap()
    }

    fn gzip_bytes(input: &[u8]) -> Vec<u8> {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(input).unwrap();
        encoder.finish().unwrap()
    }

    fn brotli_bytes(input: &[u8]) -> Vec<u8> {
        let mut output = Vec::new();
        {
            let mut encoder = CompressorWriter::new(&mut output, 4096, 5, 22);
            encoder.write_all(input).unwrap();
        }
        output
    }

    #[test]
    fn retry_policy_classifies_statuses_and_uses_exponential_backoff() {
        for status in [
            StatusCode::REQUEST_TIMEOUT,
            StatusCode::TOO_EARLY,
            StatusCode::TOO_MANY_REQUESTS,
            StatusCode::INTERNAL_SERVER_ERROR,
            StatusCode::BAD_GATEWAY,
            StatusCode::SERVICE_UNAVAILABLE,
            StatusCode::GATEWAY_TIMEOUT,
        ] {
            assert!(is_transient_status(status), "{status} should be transient");
        }
        for status in [
            StatusCode::BAD_REQUEST,
            StatusCode::NOT_FOUND,
            StatusCode::NOT_IMPLEMENTED,
            StatusCode::HTTP_VERSION_NOT_SUPPORTED,
        ] {
            assert!(!is_transient_status(status), "{status} should be permanent");
        }

        assert_eq!(
            DEFAULT_RETRY_POLICY.delay_before_retry(0),
            Duration::from_millis(500)
        );
        assert_eq!(
            DEFAULT_RETRY_POLICY.delay_before_retry(1),
            Duration::from_millis(1000)
        );
    }

    #[tokio::test]
    async fn transient_statuses_retry_until_success_without_real_backoff() {
        let server = TestServer::spawn([TestRoute::sequence(
            Method::GET,
            "/retry",
            [
                TestResponse::new(StatusCode::SERVICE_UNAVAILABLE, "busy"),
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "slow down"),
                TestResponse::ok("ready"),
            ],
        )])
        .await;
        let client = no_proxy_client();

        let response = retry_request_inner_with_policy(
            "rt5.retry",
            |client| client.get(server.url("/retry")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();

        assert_eq!(response.text().await.unwrap(), "ready");
        assert_eq!(server.request_count(Method::GET, "/retry"), 3);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn permanent_statuses_return_immediately_and_allow_error_status_preserves_response() {
        let server = TestServer::spawn([
            TestRoute::get(
                "/not-implemented",
                TestResponse::new(StatusCode::NOT_IMPLEMENTED, "unsupported"),
            ),
            TestRoute::get(
                "/allowed",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
            TestRoute::get(
                "/transient-allowed",
                TestResponse::new(StatusCode::SERVICE_UNAVAILABLE, "still busy"),
            ),
        ])
        .await;
        let client = no_proxy_client();

        let error = retry_request_inner_with_policy(
            "rt5.permanent",
            |client| client.get(server.url("/not-implemented")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap_err();
        assert_eq!(
            error.downcast_ref::<reqwest::Error>().unwrap().status(),
            Some(StatusCode::NOT_IMPLEMENTED)
        );
        assert_eq!(server.request_count(Method::GET, "/not-implemented"), 1);

        let allowed = retry_request_inner_with_policy(
            "rt5.allowed",
            |client| client.get(server.url("/allowed")),
            true,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert_eq!(allowed.status(), StatusCode::NOT_FOUND);
        assert_eq!(allowed.text().await.unwrap(), "missing");
        assert_eq!(server.request_count(Method::GET, "/allowed"), 1);

        let transient = retry_request_inner_with_policy(
            "rt5.transient_allowed",
            |client| client.get(server.url("/transient-allowed")),
            true,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert_eq!(transient.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(server.request_count(Method::GET, "/transient-allowed"), 3);

        server.shutdown().await;
    }

    #[tokio::test]
    async fn client_follows_redirects_and_decodes_gzip_and_brotli() {
        let gzip_payload = "gzip response with Unicode: 番剧";
        let brotli_payload = "brotli response with Unicode: 弹幕";
        let server = TestServer::spawn([
            TestRoute::get(
                "/redirect",
                TestResponse::redirect(StatusCode::TEMPORARY_REDIRECT, "/gzip"),
            ),
            TestRoute::get(
                "/gzip",
                TestResponse::ok(gzip_bytes(gzip_payload.as_bytes()))
                    .with_header("content-encoding", "gzip")
                    .with_header("content-type", "text/plain; charset=utf-8"),
            ),
            TestRoute::get(
                "/brotli",
                TestResponse::ok(brotli_bytes(brotli_payload.as_bytes()))
                    .with_header("content-encoding", "br")
                    .with_header("content-type", "text/plain; charset=utf-8"),
            ),
        ])
        .await;
        let client = no_proxy_client();

        let redirected = retry_request_inner_with_policy(
            "rt5.redirect",
            |client| client.get(server.url("/redirect")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert_eq!(redirected.url().path(), "/gzip");
        assert_eq!(redirected.text().await.unwrap(), gzip_payload);

        let brotli = retry_request_inner_with_policy(
            "rt5.brotli",
            |client| client.get(server.url("/brotli")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert_eq!(brotli.text().await.unwrap(), brotli_payload);

        assert_eq!(server.request_count(Method::GET, "/redirect"), 1);
        assert_eq!(server.request_count(Method::GET, "/gzip"), 1);
        assert_eq!(server.request_count(Method::GET, "/brotli"), 1);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn empty_large_and_truncated_bodies_have_stable_semantics() {
        let large_body = vec![b'x'; 2 * 1024 * 1024];
        let server = TestServer::spawn([
            TestRoute::get("/empty", TestResponse::ok("")),
            TestRoute::get("/large", TestResponse::ok(large_body.clone())),
            TestRoute::get(
                "/truncated",
                TestResponse::ok("")
                    .with_chunks(["partial-", "payload"], Duration::ZERO)
                    .with_body_error_after_chunks(
                        "simulated connection reset",
                        Duration::from_millis(20),
                    ),
            ),
        ])
        .await;
        let client = no_proxy_client();

        let empty = retry_request_inner_with_policy(
            "rt5.empty",
            |client| client.get(server.url("/empty")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert!(empty.bytes().await.unwrap().is_empty());

        let large = retry_request_inner_with_policy(
            "rt5.large",
            |client| client.get(server.url("/large")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        assert_eq!(large.bytes().await.unwrap().as_ref(), large_body.as_slice());

        let truncated = retry_request_inner_with_policy(
            "rt5.truncated",
            |client| client.get(server.url("/truncated")),
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap();
        let body_error = truncated.bytes().await.unwrap_err();
        assert!(
            body_error.is_body() || body_error.is_decode(),
            "unexpected truncated-body error: {body_error:#?}"
        );
        assert_eq!(server.request_count(Method::GET, "/truncated"), 1);

        server.shutdown().await;
    }

    #[tokio::test]
    async fn timeout_and_connection_failures_retry_exactly_three_attempts() {
        let server = TestServer::spawn([TestRoute::get(
            "/slow",
            TestResponse::ok("late").with_delay(Duration::from_millis(200)),
        )])
        .await;
        let timeout_client = Client::builder()
            .no_proxy()
            .timeout(Duration::from_millis(25))
            .build()
            .unwrap();
        let timeout_attempts = AtomicUsize::new(0);

        let timeout_error = retry_request_inner_with_policy(
            "rt5.timeout",
            |client| {
                timeout_attempts.fetch_add(1, AtomicOrdering::SeqCst);
                client.get(server.url("/slow"))
            },
            false,
            &timeout_client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap_err();
        let timeout_error = timeout_error.downcast_ref::<reqwest::Error>().unwrap();
        assert!(timeout_error.is_timeout());
        assert_eq!(timeout_attempts.load(AtomicOrdering::SeqCst), 3);
        assert_eq!(server.request_count(Method::GET, "/slow"), 3);
        server.shutdown().await;

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let refused_url = format!(
            "http://{}/?token=url-secret",
            listener.local_addr().unwrap()
        );
        drop(listener);
        let connect_client = Client::builder()
            .no_proxy()
            .connect_timeout(Duration::from_millis(100))
            .build()
            .unwrap();
        let connect_attempts = AtomicUsize::new(0);
        let connect_error = retry_request_inner_with_policy(
            "rt5.connect",
            |client| {
                connect_attempts.fetch_add(1, AtomicOrdering::SeqCst);
                client
                    .get(&refused_url)
                    .header("cookie", "session=cookie-secret")
                    .header("referer", "https://example.invalid/referer-secret")
            },
            false,
            &connect_client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap_err();
        let propagated_error = format!("{connect_error:#}");
        for secret in ["url-secret", "cookie-secret", "referer-secret"] {
            assert!(!propagated_error.contains(secret));
        }
        let connect_error = connect_error.downcast_ref::<reqwest::Error>().unwrap();
        assert!(connect_error.is_connect());
        assert_eq!(connect_attempts.load(AtomicOrdering::SeqCst), 3);
        let log_summary = request_error_log_summary(connect_error);
        assert!(matches!(
            log_summary,
            "connection failed" | "request timed out"
        ));
        for secret in ["url-secret", "cookie-secret", "referer-secret"] {
            assert!(!log_summary.contains(secret));
        }
    }

    #[tokio::test]
    async fn invalid_certificate_is_permanent_and_not_retried() {
        let certified = generate_simple_self_signed(vec!["localhost".to_string()]).unwrap();
        let certificate = certified.cert.der().clone();
        let private_key =
            rustls::pki_types::PrivatePkcs8KeyDer::from(certified.signing_key.serialize_der());
        let tls_config = rustls::ServerConfig::builder()
            .with_no_client_auth()
            .with_single_cert(vec![certificate], private_key.into())
            .unwrap();
        let acceptor = TlsAcceptor::from(Arc::new(tls_config));
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let accepted = Arc::new(AtomicUsize::new(0));
        let accepted_for_server = Arc::clone(&accepted);
        let server_task = tokio::spawn(async move {
            loop {
                let Ok((stream, _)) = listener.accept().await else {
                    break;
                };
                accepted_for_server.fetch_add(1, AtomicOrdering::SeqCst);
                let acceptor = acceptor.clone();
                tokio::spawn(async move {
                    let _ = acceptor.accept(stream).await;
                });
            }
        });
        let client = Client::builder()
            .no_proxy()
            .timeout(Duration::from_secs(1))
            .build()
            .unwrap();
        let attempts = AtomicUsize::new(0);
        let url = format!("https://{address}/");

        let error = retry_request_inner_with_policy(
            "rt5.invalid_certificate",
            |client| {
                attempts.fetch_add(1, AtomicOrdering::SeqCst);
                client.get(&url)
            },
            false,
            &client,
            NO_RETRY_DELAY,
        )
        .await
        .unwrap_err();
        let request_error = error.downcast_ref::<reqwest::Error>().unwrap();
        assert!(is_certificate_error(request_error));
        assert!(!is_transient_error(request_error));
        assert_eq!(
            request_error_log_summary(request_error),
            "TLS certificate validation failed"
        );
        assert_eq!(attempts.load(AtomicOrdering::SeqCst), 1);
        assert_eq!(accepted.load(AtomicOrdering::SeqCst), 1);

        server_task.abort();
        let _ = server_task.await;
    }

    #[tokio::test]
    async fn configured_client_sends_the_product_user_agent() {
        let server = TestServer::spawn([TestRoute::get("/ua", TestResponse::ok("ok"))]).await;
        let client = no_proxy_client();

        client.get(server.url("/ua")).send().await.unwrap();

        assert_eq!(
            server.requests()[0].headers["user-agent"],
            DEFAULT_USER_AGENT
        );
        server.shutdown().await;
    }

    /// End-to-end regression: the ECH client must actually reach the bangumi
    /// JSON API. This is the exact bug that motivated DNS pinning — without
    /// `resolve_to_addrs` the handshake dials a GFW-poisoned (Facebook) IP and
    /// times out even though the SNI is encrypted.
    ///
    /// Ignored by default (needs live network + a reachable DoH endpoint). Run:
    ///   cargo test --manifest-path rust/Cargo.toml ech_pinned -- --ignored --nocapture
    #[tokio::test]
    #[ignore = "requires live network + a reachable DoH endpoint"]
    async fn ech_pinned_client_reaches_bangumi_api() {
        // Prime the ECHConfig cache; this also caches the ipv4hint addresses.
        let bytes = crate::api::ech::fetch_cloudflare_ech_bytes()
            .await
            .expect("ECHConfig fetch failed");
        assert!(!bytes.is_empty(), "ECHConfig bytes should be non-empty");

        let ips = crate::api::ech::current_ech_resolve_ips();
        assert!(
            !ips.is_empty(),
            "ipv4hint should be cached alongside the ECHConfig"
        );

        // Force a rebuild so the ECH client picks up the pinning.
        invalidate_ech_client();
        let client = get_ech_client();

        let resp = client
            .get("https://api.bgm.tv/v0/subjects/265")
            .header("accept", "application/json")
            .send()
            .await
            .expect("request to api.bgm.tv failed (ECH/DNS pinning broken?)");

        assert!(
            resp.status().is_success(),
            "expected HTTP 2xx, got {}",
            resp.status()
        );

        let v: Value = resp.json().await.expect("body is not JSON");
        assert_eq!(v["id"].as_i64(), Some(265), "unexpected subject id");
    }
}
