#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

use log::warn;
use reqwest::{Client, Proxy};
use rustls::{ClientConfig, RootCertStore};
#[cfg(target_os = "windows")]
use std::process::Command;
use std::sync::LazyLock;
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

static SHARED_CLIENT: LazyLock<Client> =
    LazyLock::new(|| create_client().expect("Failed to create shared HTTP client"));

pub fn get_shared_client() -> &'static Client {
    &SHARED_CLIENT
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

pub async fn retry_request(
    label: &str,
    request_fn: impl Fn(&Client) -> reqwest::RequestBuilder,
) -> anyhow::Result<reqwest::Response> {
    let client = get_shared_client();
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
