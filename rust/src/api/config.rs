use lazy_static::lazy_static;
use std::sync::RwLock;

pub struct RuntimeConfig {
    pub bgmlist_url: String,
    pub bangumi_url: String,
    pub bangumi_api_url: String,
    pub bangumi_next_url: String,
    pub bangumi_lain_url: String,
    pub bangumi_use_reverse_proxy: bool,
    pub bangumi_use_ech: bool,
    /// User-configured DoH endpoint list for fetching Cloudflare's ECHConfig.
    /// Ordered: index 0 is tried first. Empty means "use the compiled-in
    /// defaults from `crate::api::ech::DEFAULT_DOH_ENDPOINTS`".
    pub bangumi_doh_endpoints: Vec<String>,
    pub mikan_url: String,
    pub playback_sub_url: String,
    pub bangumi_request_mode: String,
    pub disabled_sources: Vec<String>,
    pub cache_dir: String,
    pub download_dir: String,
    pub max_concurrent_searches: u32,
}

lazy_static! {
    pub static ref CONFIG: RwLock<RuntimeConfig> = RwLock::new(RuntimeConfig {
        bgmlist_url: "https://bgmlist.com".to_string(),
        bangumi_url: "https://bangumi.tv".to_string(),
        bangumi_api_url: "https://api.bgm.tv".to_string(),
        bangumi_next_url: "https://next.bgm.tv".to_string(),
        bangumi_lain_url: "https://lain.bgm.tv".to_string(),
        bangumi_use_reverse_proxy: false,
        bangumi_use_ech: true,
        bangumi_doh_endpoints: vec![],
        mikan_url: "https://mikanani.kas.pub".to_string(),
        playback_sub_url: "https://gitee.com/edicl/online-subscription/raw/master/online.json"
            .to_string(),
        bangumi_request_mode: "hybrid".to_string(),
        disabled_sources: vec![],
        cache_dir: ".".to_string(),
        download_dir: "downloads".to_string(),
        max_concurrent_searches: 3,
    });
}

/// Host mapping table for bangumi reverse proxies.
///
/// The bangumi reverse-proxy landscape keeps changing (e.g. `bangumi.one` -> `bangumi.lol`),
/// so we centralise the host pairings here. Update this table whenever the upstream mirror
/// domain rotates.
///
/// Format: `(real_host, mirror_host)` where `real_host` is the canonical bangumi host
/// (bgm.tv / bangumi.tv / chii.in / api.bgm.tv / next.bgm.tv / lain.bgm.tv /
/// fast.bgm.tv / doujin.bgm.tv) and `mirror_host` is the corresponding reverse-proxy
/// host that fronts the same upstream.
///
/// === Interaction with ECH (`bangumi_use_ech`) ===
/// ECH (`bangumi_use_ech`) and the reverse-proxy toggle (`bangumi_use_reverse_proxy`)
/// are **independent** runtime flags with no schema-level conflict, but their effective
/// product is:
///
///   * `use_ech=off, use_proxy=off` — direct to `*.bgm.tv` / `chii.in`. Will fail in
///     mainland China where the firewall RSTs on the SNI.
///   * `use_ech=on,  use_proxy=off` — direct to `*.bgm.tv` / `chii.in` but with the
///     inner SNI HPKE-encrypted under Cloudflare's shared `cloudflare-ech.com`
///     public name. Works when every real bangumi domain is on Cloudflare (true
///     today; covers `api.bgm.tv`, `next.bgm.tv`, `lain.bgm.tv`, `bgm.tv`,
///     `bangumi.tv`, `chii.in`).
///   * `use_ech=off, use_proxy=on`  — direct to the `*.bangumi.lol` mirrors.
///     Depends on the mirrors being reachable.
///   * `use_ech=on,  use_proxy=on`  — direct to the `*.bangumi.lol` mirrors with
///     HPKE encryption. Works only when the mirror is also Cloudflare-fronted
///     with ECH enabled; not guaranteed for arbitrary mirror operators.
///
/// See `crate::api::ech` for the ECH plumbing.
const BANGUMI_HOST_PAIRS: &[(&str, &str)] = &[
    // Main site
    ("bangumi.tv", "bangumi.lol"),
    ("bgm.tv", "bangumi.lol"),
    ("chii.in", "bangumi.lol"),
    // API
    ("api.bgm.tv", "api.bangumi.lol"),
    // Modern API (next.bgm.tv / p1)
    ("next.bgm.tv", "next.bangumi.lol"),
    // Static asset CDNs
    ("lain.bgm.tv", "lain.bangumi.lol"),
    ("fast.bgm.tv", "fast.bangumi.lol"),
    ("doujin.bgm.tv", "doujin.bangumi.lol"),
];

fn normalize_url(url: &str) -> String {
    let mut s = url.trim().to_string();
    while s.ends_with('/') {
        s.pop();
    }
    s
}

pub fn init_config(cache_dir: String, download_dir: String) {
    let mut config = CONFIG.write().unwrap();
    config.cache_dir = cache_dir;
    config.download_dir = download_dir;
    log::info!(
        "Config initialized: cache_dir={}, download_dir={}",
        config.cache_dir,
        config.download_dir
    );
}

pub fn update_config(
    bgm: String,
    bangumi: String,
    mikan: String,
    playback_sub: String,
    use_reverse_proxy: bool,
) {
    let mut config = CONFIG.write().unwrap();
    config.bgmlist_url = normalize_url(&bgm);
    config.bangumi_url = normalize_url(&bangumi);
    config.mikan_url = normalize_url(&mikan);
    config.playback_sub_url = playback_sub.trim().to_string();
    apply_reverse_proxy_settings(&mut config, use_reverse_proxy);
    log::info!(
        "Config updated: bgm={}, bangumi={}, mikan={}, playback_sub={}, use_reverse_proxy={}",
        config.bgmlist_url,
        config.bangumi_url,
        config.mikan_url,
        config.playback_sub_url,
        config.bangumi_use_reverse_proxy,
    );
}

fn apply_reverse_proxy_settings(config: &mut RuntimeConfig, use_reverse_proxy: bool) {
    config.bangumi_use_reverse_proxy = use_reverse_proxy;
    if use_reverse_proxy {
        // Force every bangumi base URL to its canonical real-host form so the
        // request fan-out mirrors what the user originally configured (with no
        // legacy `bangumi.tv` aliasing leaks that some mirrors don't accept).
        // The actual host rewrite happens in `remap_bangumi_host`.
        if config.bangumi_url.is_empty() {
            config.bangumi_url = "https://bangumi.tv".to_string();
        }
    }
}

pub fn set_bangumi_reverse_proxy(enabled: bool) {
    let mut config = CONFIG.write().unwrap();
    config.bangumi_use_reverse_proxy = enabled;
    log::info!(
        "Bangumi reverse proxy {}",
        if enabled { "enabled" } else { "disabled" }
    );
}

pub fn get_bangumi_reverse_proxy() -> bool {
    CONFIG.read().unwrap().bangumi_use_reverse_proxy
}

pub fn set_bangumi_use_ech(enabled: bool) {
    let mut config = CONFIG.write().unwrap();
    config.bangumi_use_ech = enabled;
    log::info!(
        "Bangumi ECH {}",
        if enabled { "enabled" } else { "disabled" }
    );
}

pub fn get_bangumi_use_ech() -> bool {
    CONFIG.read().unwrap().bangumi_use_ech
}

pub fn get_bgmlist_url() -> String {
    CONFIG.read().unwrap().bgmlist_url.clone()
}

pub fn get_bgmlist_api_url() -> String {
    format!("{}/api/v1", CONFIG.read().unwrap().bgmlist_url.clone())
}

/// The `bangumi-data` major/minor version we track. We pin to the `0.3`
/// line **without** a patch number so that unpkg and jsDelivr automatically
/// resolve to the latest `0.3.x` release. This way the offline cache stays
/// current without requiring a manual version+hash bump on every upstream
/// release (the package updates several times per week).
///
/// Integrity: we forgo a hard-coded SHA-512 in favour of JSON-structure
/// validation at download time (see `verify_bangumi_data_payload` in
/// `crawler.rs`). A full hash pin is impractical for a package that
/// updates this frequently; structural validation still catches truncated
/// or malformed CDN responses.
#[flutter_rust_bridge::frb(ignore)]
pub const BANGUMI_DATA_VERSION: &str = "0.3";

/// Ordered CDN URL candidates for the offline `bangumi-data` fallback. The
/// caller iterates the list top-to-bottom and uses the first one that returns
/// a usable, integrity-verified payload.
///
/// Order rationale:
///   1. jsDelivr (Cloudflare-fronted, served from many POPs worldwide;
///      often more reliable from mainland China; faster in benchmarks).
///   2. unpkg (also Cloudflare-fronted; quick for non-CN users; reaches CN via the
///      HK edge per CF-Ray observations; sometimes rate-limited from CN).
///   3. npm registry tarball (the source of truth; tarball download has the
///      auth baked-in via `integrity`, but extracting on the fly adds
///      complexity, so we stop before that).
#[flutter_rust_bridge::frb(ignore)]
pub fn get_bangumi_data_cdn_urls() -> Vec<String> {
    vec![
        format!(
            "https://cdn.jsdelivr.net/npm/bangumi-data@{}/dist/data.json",
            BANGUMI_DATA_VERSION
        ),
        format!(
            "https://unpkg.com/bangumi-data@{}/dist/data.json",
            BANGUMI_DATA_VERSION
        ),
    ]
}

/// Returns the expected SHA-512 hex digest of the canonical `bangumi-data`
/// payload. Since we now float on `@0.3` there is no single pinned hash;
/// this function returns `""` so that the legacy caller in `verify_bangumi_data_payload`
/// can skip the hash check while still performing structural validation.
#[flutter_rust_bridge::frb(ignore)]
pub fn get_bangumi_data_sha512_hex() -> &'static str {
    ""
}

pub fn get_bangumi_url() -> String {
    let config = CONFIG.read().unwrap();
    bangumi_url_for_proxy_mode(&config.bangumi_url, config.bangumi_use_reverse_proxy)
}

pub fn get_bangumi_api_url() -> String {
    let config = CONFIG.read().unwrap();
    if config.bangumi_use_reverse_proxy {
        bangumi_url_for_proxy_mode(&config.bangumi_api_url, true)
    } else {
        // Legacy behaviour: keep the hard-coded api.bgm.tv mapping when the user
        // is using the canonical bangumi.tv / bgm.tv / chii.in endpoints.
        let base = &config.bangumi_url;
        if base.contains("bangumi.tv") || base.contains("bgm.tv") || base.contains("chii.in") {
            "https://api.bgm.tv".to_string()
        } else {
            base.clone()
        }
    }
}

pub fn get_bangumi_next_url() -> String {
    let config = CONFIG.read().unwrap();
    bangumi_url_for_proxy_mode(&config.bangumi_next_url, config.bangumi_use_reverse_proxy)
}

pub fn get_bangumi_lain_url() -> String {
    let config = CONFIG.read().unwrap();
    bangumi_url_for_proxy_mode(&config.bangumi_lain_url, config.bangumi_use_reverse_proxy)
}

fn bangumi_url_for_proxy_mode(url: &str, use_reverse_proxy: bool) -> String {
    if use_reverse_proxy {
        rewrite_bangumi_url(url, true)
    } else {
        url.to_string()
    }
}

/// Rewrite a bangumi URL coming back from an API response (cover images, avatars,
/// share links, etc.) to its mirror host **only when the user has opted into the
/// reverse proxy**. When proxying is disabled the input is returned unchanged so
/// the canonical bangumi.tv / bgm.tv / lain.bgm.tv hosts are preserved.
///
/// Use this for any value derived from upstream data. The raw [`rewrite_bangumi_url`]
/// (which always rewrites when `to_mirror` is true) should be reserved for base-URL
/// construction and for converting mirror hosts back to their canonical form.
pub fn rewrite_bangumi_url_if_proxied(raw: &str) -> String {
    if CONFIG.read().unwrap().bangumi_use_reverse_proxy {
        rewrite_bangumi_url(raw, true)
    } else {
        raw.to_string()
    }
}

pub fn get_mikan_url() -> String {
    CONFIG.read().unwrap().mikan_url.clone()
}

pub fn get_playback_sub_url() -> String {
    CONFIG.read().unwrap().playback_sub_url.clone()
}

pub fn set_bangumi_request_mode(mode: String) {
    let normalized = match mode.trim().to_ascii_lowercase().as_str() {
        "legacy" => "legacy",
        "modern" => "modern",
        _ => "hybrid",
    };

    let mut config = CONFIG.write().unwrap();
    config.bangumi_request_mode = normalized.to_string();
    log::info!(
        "Bangumi request mode updated to: {}",
        config.bangumi_request_mode
    );
}

pub fn get_bangumi_request_mode() -> String {
    CONFIG.read().unwrap().bangumi_request_mode.clone()
}

pub fn get_cache_dir() -> String {
    CONFIG.read().unwrap().cache_dir.clone()
}

pub fn get_download_dir() -> String {
    CONFIG.read().unwrap().download_dir.clone()
}

pub fn set_download_dir(dir: String) {
    let mut config = CONFIG.write().unwrap();
    config.download_dir = dir.clone();
    log::info!("Download directory updated to: {}", dir);
}

pub fn set_disabled_sources(sources: Vec<String>) {
    {
        let mut config = CONFIG.write().unwrap();
        config.disabled_sources = sources;
        log::info!("Disabled sources updated: {:?}", config.disabled_sources);
    }
    crate::api::generic_scraper::invalidate_source_config_cache();
}

pub fn is_source_enabled(name: &str) -> bool {
    !CONFIG
        .read()
        .unwrap()
        .disabled_sources
        .contains(&name.to_string())
}

pub fn set_max_concurrent_searches(limit: u32) {
    let mut config = CONFIG.write().unwrap();
    config.max_concurrent_searches = limit;
    log::info!("Max concurrent searches set to: {}", limit);
}

pub fn get_max_concurrent_searches() -> u32 {
    CONFIG.read().unwrap().max_concurrent_searches
}

/// Returns the user-configured DoH endpoint list (ordered, first = highest
/// priority). Empty means "no user override — use the compiled-in defaults".
pub fn get_bangumi_doh_endpoints() -> Vec<String> {
    CONFIG.read().unwrap().bangumi_doh_endpoints.clone()
}

/// Replace the user-configured DoH endpoint list. Invalid entries (empty,
/// non-https, not a valid URL) are filtered out so we don't store something
/// we know is unusable. Invalidates the ECH client so the next request
/// rebuilds its rustls config with the new DoH list.
pub fn set_bangumi_doh_endpoints(endpoints: Vec<String>) {
    let cleaned: Vec<String> = endpoints
        .into_iter()
        .map(|s| normalize_url(&s))
        .filter(|s| !s.is_empty() && s.starts_with("https://"))
        .collect();
    {
        let mut config = CONFIG.write().unwrap();
        config.bangumi_doh_endpoints = cleaned.clone();
    }
    log::info!(
        "Bangumi DoH endpoint list updated: {:?}",
        cleaned
    );
    crate::api::network::invalidate_ech_client();
}

/// Append `endpoint` to the end of the user DoH list. Returns the new
/// length of the list. Returns 0 (and does nothing) when the endpoint is
/// not a valid https URL.
pub fn add_bangumi_doh_endpoint(endpoint: String) -> usize {
    let cleaned = normalize_url(&endpoint);
    if cleaned.is_empty() || !cleaned.starts_with("https://") {
        log::warn!("Rejecting non-https DoH endpoint: {endpoint}");
        return 0;
    }
    let len;
    let mut added = false;
    {
        let mut config = CONFIG.write().unwrap();
        if !config.bangumi_doh_endpoints.iter().any(|s| s == &cleaned) {
            config.bangumi_doh_endpoints.push(cleaned.clone());
            added = true;
        }
        len = config.bangumi_doh_endpoints.len();
    }
    if added {
        crate::api::network::invalidate_ech_client();
    }
    log::info!("Added DoH endpoint {} (total {})", cleaned, len);
    len
}

/// Remove every occurrence of `endpoint` (exact match after normalisation)
/// from the user DoH list. Returns the new length of the list.
pub fn remove_bangumi_doh_endpoint(endpoint: String) -> usize {
    let target = normalize_url(&endpoint);
    let (len, removed);
    {
        let mut config = CONFIG.write().unwrap();
        let before = config.bangumi_doh_endpoints.len();
        config.bangumi_doh_endpoints.retain(|s| s != &target);
        removed = config.bangumi_doh_endpoints.len() != before;
        len = config.bangumi_doh_endpoints.len();
    }
    if removed {
        crate::api::network::invalidate_ech_client();
    }
    log::info!("Removed DoH endpoint {} (remaining {})", target, len);
    len
}

/// Move the entry currently at `from` to position `to`. Out-of-range indices
/// are clamped silently. No-op when `from == to`. Returns the resulting list
/// so the caller can echo it back to the UI.
pub fn move_bangumi_doh_endpoint(from: usize, to: usize) -> Vec<String> {
    let mut config = CONFIG.write().unwrap();
    let len = config.bangumi_doh_endpoints.len();
    if len == 0 || from >= len {
        return config.bangumi_doh_endpoints.clone();
    }
    let from_clamped = from.min(len - 1);
    let to_clamped = to.min(len.saturating_sub(1));
    if from_clamped == to_clamped {
        return config.bangumi_doh_endpoints.clone();
    }
    let item = config.bangumi_doh_endpoints.remove(from_clamped);
    config.bangumi_doh_endpoints.insert(to_clamped, item);
    let snapshot = config.bangumi_doh_endpoints.clone();
    drop(config);
    crate::api::network::invalidate_ech_client();
    log::info!(
        "Moved DoH endpoint {} -> {} (now {:?})",
        from_clamped,
        to_clamped,
        snapshot
    );
    snapshot
}

/// Reset the user DoH list back to empty (= "use compiled-in defaults").
pub fn reset_bangumi_doh_endpoints() {
    let mut config = CONFIG.write().unwrap();
    let was_non_empty = !config.bangumi_doh_endpoints.is_empty();
    config.bangumi_doh_endpoints.clear();
    drop(config);
    if was_non_empty {
        crate::api::network::invalidate_ech_client();
    }
    log::info!("Bangumi DoH endpoints reset to defaults");
}

/// Resolve the canonical real-host for a given bangumi host (i.e. the form the upstream
/// mirror expects). When reverse proxying is enabled this maps the public alias
/// (e.g. `bangumi.lol`) back to its upstream (e.g. `bangumi.tv`) so consumers always see
/// consistent host strings.
fn canonical_bangumi_host(host: &str) -> Option<&'static str> {
    let lower = host.to_ascii_lowercase();
    for (real, mirror) in BANGUMI_HOST_PAIRS {
        if lower == *mirror {
            return Some(real);
        }
    }
    for (real, _) in BANGUMI_HOST_PAIRS {
        if lower == *real {
            return Some(real);
        }
    }
    None
}

fn mirror_for_host(host: &str) -> Option<&'static str> {
    let lower = host.to_ascii_lowercase();
    for (real, mirror) in BANGUMI_HOST_PAIRS {
        if lower == *real {
            return Some(mirror);
        }
    }
    None
}

/// Rewrite a bangumi host from its canonical real form to the mirror form (when reverse
/// proxying is enabled), or vice-versa. Returns `None` if the host is not a bangumi host
/// we know about.
pub fn remap_bangumi_host(host: &str, to_mirror: bool) -> Option<String> {
    if to_mirror {
        mirror_for_host(host).map(|value| value.to_string())
    } else {
        canonical_bangumi_host(host).map(|value| value.to_string())
    }
}

/// The canonical (real) bangumi host names backed by Cloudflare —
/// `bgm.tv`, `bangumi.tv`, `chii.in`, `api.bgm.tv`, `next.bgm.tv`, `lain.bgm.tv`,
/// `fast.bgm.tv`, `doujin.bgm.tv`.
///
/// Used to pin the ECH client's DNS to Cloudflare edge IPs so GFW DNS poisoning
/// (the system resolver returns Facebook sinkhole IPs for these hosts) is
/// bypassed — see `crate::api::network::build_ech_client`.
#[flutter_rust_bridge::frb(ignore)]
pub fn bangumi_canonical_hosts() -> Vec<&'static str> {
    BANGUMI_HOST_PAIRS.iter().map(|(real, _)| *real).collect()
}

/// Rewrite all bangumi hosts inside a URL. If `to_mirror` is true the URL is rewritten to
/// use the reverse-proxy host; if false it is rewritten back to the canonical real host.
/// Returns the input unchanged when the URL is not parseable or has no known bangumi host.
pub fn rewrite_bangumi_url(raw: &str, to_mirror: bool) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return trimmed.to_string();
    }

    let value = trimmed.to_string();

    // Handle protocol-relative URLs like `//lain.bgm.tv/...`.
    if let Some(rest) = value.strip_prefix("//") {
        let rewritten = rewrite_host_in_authority(rest, to_mirror);
        return format!("//{rewritten}");
    }

    if let Some((scheme, rest)) = split_scheme(&value) {
        let rewritten = rewrite_host_in_authority(rest, to_mirror);
        return format!("{scheme}://{rewritten}");
    }

    value
}

fn split_scheme(value: &str) -> Option<(&str, &str)> {
    let idx = value.find("://")?;
    let scheme = &value[..idx];
    if scheme.is_empty() || !scheme.chars().all(|c| c.is_ascii_alphanumeric()) {
        return None;
    }
    Some((scheme, &value[idx + 3..]))
}

fn rewrite_host_in_authority(authority_and_path: &str, to_mirror: bool) -> String {
    // The authority segment runs from the start until the first `/`, `?`, `#`, or end.
    let end = authority_and_path
        .find(|c: char| c == '/' || c == '?' || c == '#')
        .unwrap_or(authority_and_path.len());
    let (authority, tail) = authority_and_path.split_at(end);
    if authority.is_empty() {
        return authority_and_path.to_string();
    }

    let (host_port, user_info) = match authority.rsplit_once('@') {
        Some((user, hp)) => (hp, Some(user)),
        None => (authority, None),
    };

    let host = host_port
        .rsplit_once(':')
        .map(|(h, _)| h)
        .unwrap_or(host_port);

    let new_host = match remap_bangumi_host(host, to_mirror) {
        Some(value) => value,
        None => return authority_and_path.to_string(),
    };

    let new_host_port = if let Some((_, port)) = host_port.rsplit_once(':') {
        format!("{new_host}:{port}")
    } else {
        new_host
    };

    let new_authority = match user_info {
        Some(user) => format!("{user}@{new_host_port}"),
        None => new_host_port,
    };

    format!("{new_authority}{tail}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rewrite_bangumi_url_swaps_real_to_mirror() {
        assert_eq!(
            rewrite_bangumi_url("https://bangumi.tv/subject/1", true),
            "https://bangumi.lol/subject/1"
        );
        assert_eq!(
            rewrite_bangumi_url("https://api.bgm.tv/v0/subjects/1", true),
            "https://api.bangumi.lol/v0/subjects/1"
        );
        assert_eq!(
            rewrite_bangumi_url("https://lain.bgm.tv/img/icon.png", true),
            "https://lain.bangumi.lol/img/icon.png"
        );
        assert_eq!(
            rewrite_bangumi_url("https://bgm.tv/subject/1?foo=bar#frag", true),
            "https://bangumi.lol/subject/1?foo=bar#frag"
        );
    }

    #[test]
    fn rewrite_bangumi_url_handles_protocol_relative() {
        assert_eq!(
            rewrite_bangumi_url("//lain.bgm.tv/img/icon.png", true),
            "//lain.bangumi.lol/img/icon.png"
        );
    }

    #[test]
    fn rewrite_bangumi_url_handles_relative_paths() {
        // Relative paths don't carry a host; we can't rewrite them in isolation.
        assert_eq!(rewrite_bangumi_url("/subject/1", true), "/subject/1");
    }

    #[test]
    fn rewrite_bangumi_url_passes_through_unknown_hosts() {
        assert_eq!(
            rewrite_bangumi_url("https://example.com/foo", true),
            "https://example.com/foo"
        );
    }

    #[test]
    fn proxy_mode_url_helper_applies_mapping_only_when_enabled() {
        assert_eq!(
            bangumi_url_for_proxy_mode("https://api.bgm.tv", true),
            "https://api.bangumi.lol"
        );
        assert_eq!(
            bangumi_url_for_proxy_mode("https://next.bgm.tv", true),
            "https://next.bangumi.lol"
        );
        assert_eq!(
            bangumi_url_for_proxy_mode("https://lain.bgm.tv", true),
            "https://lain.bangumi.lol"
        );
        assert_eq!(
            bangumi_url_for_proxy_mode("https://bangumi.tv", false),
            "https://bangumi.tv"
        );
    }

    #[test]
    fn if_proxied_respects_the_runtime_flag() {
        // Disabled (the default): API-response URLs must be left untouched so the
        // canonical hosts are preserved.
        set_bangumi_reverse_proxy(false);
        assert_eq!(
            rewrite_bangumi_url_if_proxied("https://lain.bgm.tv/img/icon.png"),
            "https://lain.bgm.tv/img/icon.png"
        );

        // Enabled: the same URL is rewritten to the mirror host.
        set_bangumi_reverse_proxy(true);
        assert_eq!(
            rewrite_bangumi_url_if_proxied("https://lain.bgm.tv/img/icon.png"),
            "https://lain.bangumi.lol/img/icon.png"
        );

        // Reset so this test does not leak state into others sharing CONFIG.
        set_bangumi_reverse_proxy(false);
    }
}
