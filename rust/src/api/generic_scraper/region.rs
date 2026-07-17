use super::types::{ExportedMediaSourceDataList, MediaSource, SampleRoot};
use std::sync::RwLock;
use std::sync::atomic::{AtomicBool, Ordering};
use tokio::sync::Mutex as TokioMutex;

lazy_static::lazy_static! {
    static ref CURRENT_REGION: RwLock<Option<String>> = RwLock::new(None);
    static ref REGION_DETECTION_MUTEX: TokioMutex<()> = TokioMutex::new(());
    static ref REGION_DETECTION_ATTEMPTED: AtomicBool = AtomicBool::new(false);
}

pub(super) async fn detect_current_region() -> Option<String> {
    // Fast path: already detected
    if let Some(region) = current_region_option() {
        return Some(region);
    }

    if REGION_DETECTION_ATTEMPTED.load(Ordering::Acquire) {
        return None;
    }

    // Slow path: serialize concurrent callers to avoid duplicate HTTP requests
    let _lock = REGION_DETECTION_MUTEX.lock().await;

    // Double-check after acquiring the lock
    if let Some(region) = current_region_option() {
        return Some(region);
    }

    if REGION_DETECTION_ATTEMPTED.load(Ordering::Acquire) {
        return None;
    }

    let region = detect_current_region_once().await;
    REGION_DETECTION_ATTEMPTED.store(true, Ordering::Release);
    region
}

/// Per-request timeout for any single region-detection endpoint. Kept short so
/// a slow endpoint can't drag the whole race — the goal is "first responder
/// wins".
pub(super) const REGION_ENDPOINT_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(5);

/// Geolocation endpoints raced concurrently during region detection. Each entry
/// is `(label, json_field)` where `json_field` is the JSON key holding the
/// ISO-3166 alpha-2 country code (case-insensitive). Ordered by typical
/// reliability / latency; the first successful response wins.
pub(super) const REGION_DETECTION_ENDPOINTS: &[(&str, &str)] = &[
    ("https://ipapi.co/json/", "country_code"),
    ("https://ipwho.is/", "country_code"),
    ("https://ipinfo.io/json", "country"),
    ("https://ifconfig.co/json", "country_iso"),
    ("https://api.myip.com/", "country_code"),
];

pub(super) async fn detect_current_region_once() -> Option<String> {
    let mut tasks = Vec::with_capacity(REGION_DETECTION_ENDPOINTS.len());
    for (url, field) in REGION_DETECTION_ENDPOINTS {
        let url = *url;
        let field = *field;
        tasks.push(tokio::spawn(async move {
            fetch_region_from_endpoint(&url, &field).await
        }));
    }

    // Poll the spawned tasks. We don't use `select_all` because the futures
    // would be polled in lockstep; a manual loop lets us return as soon as the
    // first task resolves and ignore the rest. The inner timeout guarantees
    // every task completes within `REGION_ENDPOINT_TIMEOUT` even if the
    // underlying TCP connect hangs.
    let total = tasks.len();
    for _ in 0..total {
        let (result, _idx, remaining) = futures::future::select_all(tasks).await;
        tasks = remaining;
        match result {
            Ok(Some(region)) => {
                if let Ok(mut guard) = CURRENT_REGION.write() {
                    *guard = Some(region.clone());
                }
                tasks.clear();
                return Some(region);
            }
            Ok(None) => continue,
            Err(e) => {
                log::warn!("Region detection task join error: {}", e);
                continue;
            }
        }
    }

    log::warn!("All region detection endpoints failed");
    None
}

pub(super) async fn fetch_region_from_endpoint(url: &str, field: &str) -> Option<String> {
    let response = match tokio::time::timeout(
        REGION_ENDPOINT_TIMEOUT,
        crate::api::network::retry_request("detect_current_region", |cl| {
            cl.get(url).timeout(REGION_ENDPOINT_TIMEOUT)
        }),
    )
    .await
    {
        Ok(Ok(resp)) => resp,
        Ok(Err(e)) => {
            log::warn!("Failed to request region endpoint {}: {}", url, e);
            return None;
        }
        Err(_) => {
            log::warn!(
                "Region endpoint {} timed out after {:?}",
                url,
                REGION_ENDPOINT_TIMEOUT
            );
            return None;
        }
    };

    let payload: serde_json::Value = match response.json().await {
        Ok(json) => json,
        Err(e) => {
            log::warn!("Failed to parse region response from {}: {}", url, e);
            return None;
        }
    };

    // ip-api.com wraps its payload in a `status` field; treat any non-success
    // status as a failed response so we fall through to the next endpoint.
    if let Some(status) = payload.get("status").and_then(|v| v.as_str()) {
        if !status.eq_ignore_ascii_case("success") {
            log::warn!("Region endpoint {} returned status={}", url, status);
            return None;
        }
    }

    payload
        .get(field)
        .or_else(|| payload.get("country"))
        .or_else(|| payload.get("country_code"))
        .or_else(|| payload.get("country_iso"))
        .and_then(|value| value.as_str())
        .map(|value| value.trim().to_uppercase())
        .filter(|value| !value.is_empty() && value.len() == 2)
}

pub(super) async fn detect_current_region_with_retry(max_attempts: usize) -> Option<String> {
    let attempts = max_attempts.max(1);

    if let Some(region) = current_region_option() {
        return Some(region);
    }

    let _lock = REGION_DETECTION_MUTEX.lock().await;

    if let Some(region) = current_region_option() {
        return Some(region);
    }

    if REGION_DETECTION_ATTEMPTED.load(Ordering::Acquire) {
        return None;
    }

    for attempt in 1..=attempts {
        if let Some(region) = detect_current_region_once().await {
            REGION_DETECTION_ATTEMPTED.store(true, Ordering::Release);
            return Some(region);
        }

        if attempt < attempts {
            log::warn!(
                "Region detection attempt {}/{} failed, retrying...",
                attempt,
                attempts
            );
        }
    }

    log::warn!(
        "Region detection failed after {} attempts, falling back to unrestricted sources",
        attempts
    );
    REGION_DETECTION_ATTEMPTED.store(true, Ordering::Release);
    None
}

pub(super) fn normalize_region(value: &str) -> String {
    value.trim().to_uppercase()
}

pub(super) fn source_is_restricted(source: &MediaSource, region: Option<&str>) -> bool {
    let Some(current_region) = region else {
        return false;
    };

    let Some(restricted_regions) = &source.arguments.restricted_region else {
        return false;
    };

    restricted_regions
        .iter()
        .map(|item| normalize_region(item))
        .any(|item| item == current_region)
}

pub(super) fn filter_restricted_sources(
    mut sources: Vec<MediaSource>,
    region: Option<&str>,
) -> Vec<MediaSource> {
    if region.is_none() {
        return sources;
    }

    sources.retain(|source| !source_is_restricted(source, region));
    sources
}

pub(super) fn filter_root_by_region(root: SampleRoot, region: Option<&str>) -> SampleRoot {
    if region.is_none() {
        return root;
    }
    SampleRoot {
        exported_media_source_data_list: ExportedMediaSourceDataList {
            media_sources: filter_restricted_sources(
                root.exported_media_source_data_list.media_sources,
                region,
            ),
        },
    }
}

pub(super) fn current_region_option() -> Option<String> {
    CURRENT_REGION.read().ok().and_then(|guard| guard.clone())
}

pub(super) async fn detect_and_filter_root(root: SampleRoot) -> SampleRoot {
    let region = detect_current_region().await;
    filter_root_by_region(root, region.as_deref())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_region_codes_for_comparison() {
        assert_eq!(normalize_region(" cn "), "CN");
        assert_eq!(normalize_region("hk"), "HK");
    }
}
