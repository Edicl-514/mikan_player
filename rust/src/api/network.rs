use anyhow::Context;
#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

use log::warn;
use reqwest::{Client, Proxy};
use rustls::{ClientConfig, RootCertStore};
#[cfg(target_os = "windows")]
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, LazyLock, RwLock};
use std::time::Duration;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x08000000;

#[derive(Debug)]
pub struct ProxyConfig {
    pub url: String,
}

pub fn get_system_proxy() -> Option<String> {
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

pub fn get_shared_client() -> &'static Client {
    &SHARED_CLIENT
}

struct EchClientSlot {
    client: &'static Client,
    epoch: u64,
}

static ECH_CLIENT_SLOT: RwLock<Option<EchClientSlot>> = RwLock::new(None);
static ECH_EPOCH: AtomicU64 = AtomicU64::new(0);

pub fn invalidate_ech_client() {
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
pub fn get_ech_client() -> &'static Client {
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

    let roots = RootCertStore {
        roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
    };
    let provider = Arc::new(rustls::crypto::aws_lc_rs::default_provider());
    let tls_config = ClientConfig::builder_with_provider(provider.clone())
        .with_ech(ech_cfg.into())
        .context("rustls ConfigBuilder::with_ech")?
        .with_root_certificates(roots)
        .with_no_client_auth();

    let mut builder = Client::builder()
        .user_agent("MikanPlayer/1.0")
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(30))
        .tcp_keepalive(Some(Duration::from_secs(60)))
        .pool_idle_timeout(Duration::from_secs(90))
        .pool_max_idle_per_host(4)
        .tls_backend_preconfigured(tls_config);

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
pub fn create_client() -> reqwest::Result<Client> {
    let roots = RootCertStore {
        roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
    };
    let tls_config =
        ClientConfig::builder_with_provider(rustls::crypto::aws_lc_rs::default_provider().into())
            .with_safe_default_protocol_versions()
            .expect("rustls safe default protocol versions should be valid")
            .with_root_certificates(roots)
            .with_no_client_auth();

    let mut builder = Client::builder()
        .user_agent("MikanPlayer/1.0")
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(30))
        .tcp_keepalive(Some(Duration::from_secs(60)))
        .pool_idle_timeout(Duration::from_secs(90))
        .pool_max_idle_per_host(4)
        .tls_backend_preconfigured(tls_config);

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

const MAX_RETRIES: u32 = 2;
const INITIAL_DELAY_MS: u64 = 500;

fn is_transient_error(e: &reqwest::Error) -> bool {
    e.is_timeout() || e.is_connect()
}

/// Returns the ECH client when ECH is enabled and the ECHConfig is cached,
/// otherwise the plain shared client. The caller **must** only use this for
/// bangumi-domain requests — the embedded `EchConfig` targets Cloudflare's
/// shared `cloudflare-ech.com` public name.
pub fn client_for_bangumi() -> &'static Client {
    if crate::api::config::get_bangumi_use_ech()
        && crate::api::ech::has_ech_config()
    {
        get_ech_client()
    } else {
        get_shared_client()
    }
}

#[deprecated(note = "Use client_for_bangumi or retry_request_bangumi instead")]
pub fn select_client() -> &'static Client {
    get_shared_client()
}

pub async fn retry_request(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
) -> anyhow::Result<reqwest::Response> {
    retry_request_with_status(label, request_fn, false).await
}

pub async fn retry_request_with_status(
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
pub async fn retry_request_bangumi(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
) -> anyhow::Result<reqwest::Response> {
    retry_request_bangumi_with_status(label, request_fn, false).await
}

pub async fn retry_request_bangumi_with_status(
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
    let mut delay = Duration::from_millis(INITIAL_DELAY_MS);

    for attempt in 0..=MAX_RETRIES {
        let builder = request_fn(client);
        match builder.send().await {
            Ok(resp) => {
                let status = resp.status();
                if status.is_server_error() && attempt < MAX_RETRIES {
                    log::warn!(
                        "{}: HTTP {} on attempt {}/{}, retrying in {}ms",
                        label,
                        status,
                        attempt + 1,
                        MAX_RETRIES + 1,
                        delay.as_millis()
                    );
                    tokio::time::sleep(delay).await;
                    delay *= 2;
                    continue;
                }
                if allow_error_status {
                    return Ok(resp);
                }
                return Ok(resp.error_for_status()?);
            }
            Err(e) if is_transient_error(&e) && attempt < MAX_RETRIES => {
                log::warn!(
                    "{}: {} on attempt {}/{}, retrying in {}ms",
                    label,
                    e,
                    attempt + 1,
                    MAX_RETRIES + 1,
                    delay.as_millis()
                );
                tokio::time::sleep(delay).await;
                delay *= 2;
                continue;
            }
            Err(e) => {
                return Err(e.into());
            }
        }
    }

    unreachable!()
}
