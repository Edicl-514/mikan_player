// ECH (Encrypted Client Hello) support for bypassing SNI-based blocking.
//
// === What this does ===
// All bangumi sites (bgm.tv / bangumi.tv / chii.in / api.bgm.tv / next.bgm.tv /
// lain.bgm.tv / fast.bgm.tv / doujin.bgm.tv) sit behind Cloudflare and have
// ECH enabled with the shared `public_name = cloudflare-ech.com`. By offering
// an ECH ClientHello to the Cloudflare edge, the inner SNI (the real hostname)
// is HPKE-encrypted so an on-path firewall cannot see it. The edge decrypts
// it, routes to the requested origin, and returns the real certificate.
//
// This module:
//   1. Fetches Cloudflare's ECHConfigList from DNS via DoH (HTTPS RR type=65
//      on `cloudflare-ech.com`).
//   2. Caches the parsed `EchConfig` (rustls does not allow serializing the
//      cached form without re-running HPKE setup, so we rebuild on demand from
//      the cached raw bytes).
//   3. Exposes `install_into_client_config` so the shared reqwest client can
//      pick up ECH when `bangumi_use_ech` is on.
//
// === DoH endpoints ===
// The default Cloudflare DoH endpoint (`https://cloudflare-dns.com/dns-query`)
// is itself blocked by the GFW inside mainland China, so we keep an ordered
// list of DoH endpoints and walk it on every refresh, picking the first one
// that returns a parseable ECHConfig. The Dart settings UI lets the user add /
// remove / reorder entries; the runtime list is loaded from `config.rs` on
// startup and on every refresh.
//
// === Failure modes ===
//   - All DoH endpoints fail: log + return None so the HTTP client falls back
//     to plaintext SNI. Caller code is unchanged.
//   - rustls cannot parse the ECHConfigList: same fallback.
//   - Stale ECHConfig (server rotated its key): rustls handles ECH retry
//     transparently and uses the server-supplied retry_configs. Cloudflare
//     rotates frequently, so the cache TTL is intentionally short.
//
// === Thread-safety ===
// `ECH_CACHE` uses `std::sync::RwLock`. All reads return owned data; the inner
// `bytes` are immutable after publish.
use anyhow::Context;
use rustls::client::EchConfig;
use rustls::crypto::aws_lc_rs::hpke::ALL_SUPPORTED_SUITES;
use rustls::pki_types::EchConfigListBytes;
use std::sync::RwLock;
use std::time::{Duration, Instant};

/// `cloudflare-ech.com` is the shared `public_name` used by every Cloudflare
/// zone with ECH enabled — querying its HTTPS RR yields one ECHConfigList
/// that works for `api.bgm.tv`, `next.bgm.tv`, `bgm.tv`, `chii.in`, etc.
pub const ECH_QUERY_NAME: &str = "cloudflare-ech.com";

/// Default DoH endpoints tried in order. Cloudflare's own DoH is unreachable
/// from mainland China (RST by the GFW), so we keep several third-party DoH
/// endpoints as fallbacks. The user can override this list from the settings
/// UI — see [`crate::api::config::get_bangumi_doh_endpoints`].
///
/// These endpoints MUST accept `application/dns-json` (Google/Cloudflare DoH
/// JSON shape) and return at least one `Answer` of type HTTPS (65) containing
/// an `ech=` SvcParam.
pub const DEFAULT_DOH_ENDPOINTS: &[&str] = &[
    "https://doh.090227.xyz/SB-query",
    "https://dns.alidns.com/dns-query",
    "https://doh.pub/dns-query",
];

/// ECHConfig TTL. Cloudflare rotates the HPKE public key frequently (a single
/// cached config is typically rejected within hours), so 1h is a safe upper
/// bound. Each new handshake that fails with `server rejected ECH` will trigger
/// a fresh fetch on the next request.
pub const ECH_CACHE_TTL: Duration = Duration::from_secs(60 * 60);
pub const ECH_RETRY_AFTER_FAILURE: Duration = Duration::from_secs(5 * 60);
const DOH_TIMEOUT_SECS: u64 = 8;

#[derive(Clone, Debug)]
struct CachedEch {
    bytes: Vec<u8>,
    fetched_at: Instant,
}

static ECH_CACHE: RwLock<Option<CachedEch>> = RwLock::new(None);
static LAST_FAILED_AT: RwLock<Option<Instant>> = RwLock::new(None);

fn is_cache_entry_fresh(entry: &CachedEch) -> bool {
    entry.fetched_at.elapsed() < ECH_CACHE_TTL
}

/// Build a rustls `EchConfig` from cached raw bytes. Re-runs HPKE setup
/// each time — that's cheap relative to the actual handshake.
fn build_ech_config(bytes: &[u8]) -> anyhow::Result<EchConfig> {
    let list = EchConfigListBytes::from(bytes.to_vec());
    EchConfig::new(list, ALL_SUPPORTED_SUITES).context("rustls EchConfig::new")
}

/// Resolve the effective DoH endpoint list: user overrides from config take
/// precedence; fall back to the compiled-in defaults if the user list is empty.
fn doh_endpoints() -> Vec<String> {
    let user_list = crate::api::config::get_bangumi_doh_endpoints();
    if !user_list.is_empty() {
        user_list
    } else {
        DEFAULT_DOH_ENDPOINTS.iter().map(|s| s.to_string()).collect()
    }
}

/// Fetch (or return cached) Cloudflare ECHConfig bytes.
///
/// Returns `None` on any failure (all DoH endpoints unreachable, no HTTPS RR,
/// parse error). Backed off after a failure to avoid hammering the DoH
/// endpoints.
pub async fn fetch_cloudflare_ech_bytes() -> anyhow::Result<Vec<u8>> {
    // Honor the failure back-off window: if we recently failed, don't try again
    // until ECH_RETRY_AFTER_FAILURE has elapsed.
    {
        let last = LAST_FAILED_AT.read().unwrap().clone();
        if let Some(t) = last {
            if t.elapsed() < ECH_RETRY_AFTER_FAILURE {
                return Err(anyhow::anyhow!(
                    "ECHConfig fetch in back-off ({}s remaining)",
                    (ECH_RETRY_AFTER_FAILURE - t.elapsed()).as_secs()
                ));
            }
        }
    }

    // Serve from cache when fresh.
    {
        let guard = ECH_CACHE.read().unwrap();
        if let Some(c) = guard.as_ref() {
            if c.fetched_at.elapsed() < ECH_CACHE_TTL {
                return Ok(c.bytes.clone());
            }
        }
    }

    // Cache miss or stale: walk the DoH list in order. The first endpoint to
    // return a parseable ECHConfig wins.
    let endpoints = doh_endpoints();
    log::info!(
        "ECH: fetching fresh ECHConfig from {} DoH endpoint(s)",
        endpoints.len()
    );

    let mut last_err: Option<anyhow::Error> = None;
    for endpoint in &endpoints {
        match fetch_from_single_doh(endpoint).await {
            Ok(bytes) => {
                *LAST_FAILED_AT.write().unwrap() = None;
                log::info!(
                    "ECH: cached {} bytes of ECHConfig from {}",
                    bytes.len(),
                    endpoint
                );
                return Ok(bytes);
            }
            Err(e) => {
                log::warn!("ECH: DoH endpoint {} failed: {e}", endpoint);
                last_err = Some(e);
            }
        }
    }

    mark_failed();
    Err(last_err.unwrap_or_else(|| anyhow::anyhow!("no DoH endpoints configured")))
}

/// Fetch the ECHConfig from a single DoH endpoint. Returns the raw bytes of
/// the `ech` SvcParam, or an error describing why this endpoint failed.
async fn fetch_from_single_doh(endpoint: &str) -> anyhow::Result<Vec<u8>> {
    let url = format!("{endpoint}?name={ECH_QUERY_NAME}&type=HTTPS");

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(DOH_TIMEOUT_SECS))
        .user_agent("MikanPlayer/1.0")
        .build()
        .context("build DoH client")?;

    let resp = client
        .get(&url)
        .header("accept", "application/dns-json")
        .send()
        .await
        .context("DoH GET")?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!("DoH HTTP {}", resp.status()));
    }

    let body: serde_json::Value = resp.json().await.context("parse DoH JSON")?;

    let ech_b64 = body
        .get("Answer")
        .and_then(|a| a.as_array())
        .and_then(|arr| arr.first())
        .and_then(|entry| entry.get("data"))
        .and_then(|d| d.as_str())
        .ok_or_else(|| anyhow::anyhow!("DoH response missing Answer[0].data"))?;

    let bytes = parse_echconfig_from_https_svcb(ech_b64)
        .ok_or_else(|| anyhow::anyhow!("no ech= param in HTTPS RR data"))?;

    // Verify rustls can parse it before publishing.
    build_ech_config(&bytes).context("rustls rejected freshly-fetched ECHConfig")?;

    {
        let mut guard = ECH_CACHE.write().unwrap();
        *guard = Some(CachedEch {
            bytes: bytes.clone(),
            fetched_at: Instant::now(),
        });
    }

    Ok(bytes)
}

/// Force-refresh the cached ECHConfig (e.g. from the settings UI).
pub async fn refresh_bangumi_ech_config() -> anyhow::Result<usize> {
    {
        let mut g = ECH_CACHE.write().unwrap();
        *g = None;
    }
    *LAST_FAILED_AT.write().unwrap() = None;
    let bytes = fetch_cloudflare_ech_bytes().await?;
    crate::api::network::invalidate_ech_client();
    Ok(bytes.len())
}

/// Ensure we have a fresh-enough ECHConfig in cache before attempting an ECH
/// handshake. Returns `true` when a network refresh was performed.
pub(crate) async fn ensure_fresh_ech_config() -> anyhow::Result<bool> {
    {
        let guard = ECH_CACHE.read().unwrap();
        if let Some(cached) = guard.as_ref() {
            if is_cache_entry_fresh(cached) {
                return Ok(false);
            }
        }
    }

    fetch_cloudflare_ech_bytes().await?;
    crate::api::network::invalidate_ech_client();
    Ok(true)
}

/// Returns a fresh `EchConfig` ready to plug into a `rustls::ClientConfig`,
/// or `None` if ECH isn't available right now.
pub(crate) fn current_ech_config() -> Option<EchConfig> {
    let guard = ECH_CACHE.read().unwrap();
    let bytes = guard.as_ref()?;
    if !is_cache_entry_fresh(bytes) {
        return None;
    }
    build_ech_config(&bytes.bytes).ok()
}

/// Cheap "is an ECHConfig cached?" check for the routing decision in
/// [`crate::api::network::client_for_bangumi`]. Does NOT rebuild the rustls
/// `EchConfig` (which re-runs HPKE suite selection + allocation), so it is
/// safe to call on every request.
pub(crate) fn has_ech_config() -> bool {
    ECH_CACHE
        .read()
        .unwrap()
        .as_ref()
        .is_some_and(is_cache_entry_fresh)
}

fn mark_failed() {
    *LAST_FAILED_AT.write().unwrap() = Some(Instant::now());
}

/// Parse an HTTPS RR `data` field and return the raw `ech` SvcParam value
/// (a binary ECHConfigList, per RFC 9460).
///
/// Two `data` shapes are handled:
///   1. RFC 3597 generic wire format, emitted by Cloudflare/Google DoH JSON:
///        `\# <rdlength> <hex byte> <hex byte> ...`
///      Here the `ech` value is binary (no base64), so we hex-decode the rdata
///      and walk the SVCB param list. **This is what production receives.**
///   2. Presentation format some DoH servers emit (kept as a fallback):
///        `1 . alpn="h2,h3" ipv4hint=... ech=<base64 ECHConfigList>`
fn parse_echconfig_from_https_svcb(data: &str) -> Option<Vec<u8>> {
    let tokens: Vec<&str> = data.split_whitespace().collect();

    // (1) RFC 3597 generic wire format: "\# <rdlength> <hex> <hex> ..."
    if tokens.first() == Some(&"\\#") && tokens.len() >= 2 {
        let hex: String = tokens[2..].concat();
        let rdata = hex::decode(&hex).ok()?;
        return extract_ech_param(&rdata);
    }

    // (2) Presentation format fallback: look for an `ech=<base64>` token.
    for token in &tokens {
        if let Some(rest) = token.strip_prefix("ech=") {
            use base64::Engine;
            return base64::engine::general_purpose::STANDARD
                .decode(rest)
                .ok();
        }
    }
    None
}

/// Walk a parsed SVCB/HTTPS RDATA blob and return the raw bytes of the `ech`
/// SvcParam (SvcParamKey = 5). Per RFC 9460 the value is already the binary
/// ECHConfigList — there is no base64 layer to undo.
///
/// RDATA layout: `SvcPriority(2) | TargetName(labels..0x00) | SvcParams...`
/// where each SvcParam is `key(2) | len(2) | value(len)`.
fn extract_ech_param(mut rdata: &[u8]) -> Option<Vec<u8>> {
    // SvcPriority (2 bytes).
    if rdata.len() < 2 {
        return None;
    }
    rdata = &rdata[2..];

    // TargetName: length-prefixed labels, terminated by a 0-length label.
    loop {
        let (&len, rest) = rdata.split_first()?;
        rdata = rest;
        if len == 0 {
            break;
        }
        let len = len as usize;
        if rdata.len() < len {
            return None;
        }
        rdata = &rdata[len..];
    }

    // SvcParams: repeated { key: u16, len: u16, value: [u8; len] }.
    while rdata.len() >= 4 {
        let key = u16::from_be_bytes([rdata[0], rdata[1]]);
        let len = u16::from_be_bytes([rdata[2], rdata[3]]) as usize;
        rdata = &rdata[4..];
        if rdata.len() < len {
            return None;
        }
        if key == 5 {
            // SvcParamKey 5 == `ech`.
            return Some(rdata[..len].to_vec());
        }
        rdata = &rdata[len..];
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Real Cloudflare DoH response for `cloudflare-ech.com` (type=HTTPS),
    /// captured 2026-06. The `data` field is RFC 3597 generic wire format —
    /// exactly what `fetch_cloudflare_ech_bytes` receives in production. This
    /// is the case the old parser silently failed on.
    const REAL_DOH_DATA: &str = "\\# 136 00 01 00 00 01 00 06 02 68 33 02 68 32 00 04 00 08 68 12 0a 76 68 12 0b 76 00 05 00 47 00 45 fe 0d 00 41 79 00 20 00 20 ae 18 f0 a2 c4 de e9 cb 30 77 f0 c3 b7 93 b5 48 86 58 22 4d d6 22 3b a6 90 3d ae f4 9f 98 7f 5e 00 04 00 01 00 01 00 12 63 6c 6f 75 64 66 6c 61 72 65 2d 65 63 68 2e 63 6f 6d 00 00 00 06 00 20 26 06 47 00 00 00 00 00 00 00 00 00 68 12 0a 76 26 06 47 00 00 00 00 00 00 00 00 00 68 12 0b 76";

    #[test]
    fn parses_real_cloudflare_doh_response() {
        let parsed = parse_echconfig_from_https_svcb(REAL_DOH_DATA).expect("must parse");

        // The ech SvcParam value is 71 bytes (its len field is 0x0047).
        assert_eq!(parsed.len(), 71, "ech value length");
        // ECHConfigList begins with the length-prefixed ECHConfig, then the
        // 0x0fe0d ECH version marker.
        assert_eq!(&parsed[0..2], &[0x00, 0x45], "ECHConfig length prefix");
        assert_eq!(&parsed[2..4], &[0xfe, 0x0d], "ECH version 0x0fe0d");

        // rustls must accept the freshly-parsed bytes.
        assert!(
            build_ech_config(&parsed).is_ok(),
            "rustls rejected the parsed ECHConfig"
        );
    }

    #[test]
    fn parses_presentation_format_fallback() {
        let data = r#"1 . alpn="h2,h3" ipv4hint=104.16.0.0 ech=AEX+DQBBDAAgACD2tpX44dE776O1qEe4pBYcf9gV2sYonx2xzeulGUbiNgAEAAEAAQASY2xvdWRmbGFyZS1lY2guY29tAAA="#;
        let parsed = parse_echconfig_from_https_svcb(data).unwrap();
        assert!(!parsed.is_empty());
    }

    #[test]
    fn missing_ech_param_returns_none() {
        // RFC 3597 rdata with SvcPriority + root TargetName and no SvcParams.
        let data = "\\# 3 00 01 00";
        assert!(parse_echconfig_from_https_svcb(data).is_none());
    }

    #[test]
    fn presentation_format_without_ech_returns_none() {
        let data = r#"1 . alpn="h2,h3" ipv4hint=104.16.0.0"#;
        assert!(parse_echconfig_from_https_svcb(data).is_none());
    }

    #[test]
    fn truncated_rdata_returns_none() {
        // SvcPriority only, no TargetName terminator.
        assert!(extract_ech_param(&[0x00, 0x01]).is_none());
    }

    #[test]
    fn default_doh_endpoints_are_non_empty_and_https() {
        assert!(!DEFAULT_DOH_ENDPOINTS.is_empty());
        for ep in DEFAULT_DOH_ENDPOINTS {
            assert!(ep.starts_with("https://"), "DoH must be HTTPS: {ep}");
        }
    }
}
