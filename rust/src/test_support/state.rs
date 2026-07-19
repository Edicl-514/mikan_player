use crate::api::config::{CONFIG, RuntimeConfig};
use std::sync::{Mutex, MutexGuard};

static PROCESS_CONFIG_TEST_LOCK: Mutex<()> = Mutex::new(());

/// Serializes tests that mutate the process-wide runtime config and restores
/// the complete snapshot when the guard is dropped, including during unwind.
pub(crate) struct RuntimeConfigGuard {
    snapshot: Option<RuntimeConfig>,
    _lock: MutexGuard<'static, ()>,
}

pub(crate) fn isolate_runtime_config() -> RuntimeConfigGuard {
    let lock = PROCESS_CONFIG_TEST_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    let snapshot = CONFIG
        .read()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .clone();
    RuntimeConfigGuard {
        snapshot: Some(snapshot),
        _lock: lock,
    }
}

impl Drop for RuntimeConfigGuard {
    fn drop(&mut self) {
        if let Some(snapshot) = self.snapshot.take() {
            *CONFIG
                .write()
                .unwrap_or_else(|poisoned| poisoned.into_inner()) = snapshot;
        }
        crate::api::crawler::invalidate_bangumi_data_cache();
        crate::api::generic_scraper::invalidate_source_config_cache();
        crate::api::network::invalidate_ech_client();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runtime_config_guard_restores_the_complete_snapshot() {
        let guard = isolate_runtime_config();
        let original = guard.snapshot.as_ref().unwrap();
        let original_cache_dir = original.cache_dir.clone();
        let original_download_dir = original.download_dir.clone();
        let original_proxy = original.bangumi_use_reverse_proxy;
        crate::api::config::init_config(
            "fixture-cache".to_string(),
            "fixture-download".to_string(),
        );
        crate::api::config::set_bangumi_reverse_proxy(!original_proxy);
        drop(guard);

        assert_eq!(crate::api::config::get_cache_dir(), original_cache_dir);
        assert_eq!(
            crate::api::config::get_download_dir(),
            original_download_dir
        );
        assert_eq!(
            crate::api::config::get_bangumi_reverse_proxy(),
            original_proxy
        );
    }
}
