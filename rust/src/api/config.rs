use lazy_static::lazy_static;
use std::sync::RwLock;

pub struct RuntimeConfig {
    pub bgmlist_url: String,
    pub bangumi_url: String,
    pub mikan_url: String,
    pub playback_sub_url: String,
    pub disabled_sources: Vec<String>,
    pub cache_dir: String,
    pub download_dir: String,
}

lazy_static! {
    pub static ref CONFIG: RwLock<RuntimeConfig> = RwLock::new(RuntimeConfig {
        bgmlist_url: "https://bgmlist.com".to_string(),
        bangumi_url: "https://bangumi.tv".to_string(),
        mikan_url: "https://mikanani.kas.pub".to_string(),
        playback_sub_url: "https://gitee.com/edicl/online-subscription/raw/master/online.json".to_string(),
        disabled_sources: vec![],
        cache_dir: ".".to_string(),
        download_dir: "downloads".to_string(),
    });
}

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

pub fn update_config(bgm: String, bangumi: String, mikan: String, playback_sub: String) {
    let mut config = CONFIG.write().unwrap();
    config.bgmlist_url = normalize_url(&bgm);
    config.bangumi_url = normalize_url(&bangumi);
    config.mikan_url = normalize_url(&mikan);
    config.playback_sub_url = playback_sub.trim().to_string();
    log::info!(
        "Config updated: bgm={}, bangumi={}, mikan={}, playback_sub={}",
        config.bgmlist_url,
        config.bangumi_url,
        config.mikan_url,
        config.playback_sub_url
    );
}

pub fn get_bgmlist_url() -> String {
    CONFIG.read().unwrap().bgmlist_url.clone()
}

pub fn get_bangumi_url() -> String {
    CONFIG.read().unwrap().bangumi_url.clone()
}

pub fn get_bangumi_api_url() -> String {
    let base = get_bangumi_url();
    if base.contains("bangumi.tv") || base.contains("bgm.tv") {
        "https://api.bgm.tv".to_string()
    } else {
        base
    }
}

pub fn get_mikan_url() -> String {
    CONFIG.read().unwrap().mikan_url.clone()
}

pub fn get_playback_sub_url() -> String {
    CONFIG.read().unwrap().playback_sub_url.clone()
}

pub fn get_cache_dir() -> String {
    CONFIG.read().unwrap().cache_dir.clone()
}

pub fn get_download_dir() -> String {
    CONFIG.read().unwrap().download_dir.clone()
}

pub fn set_disabled_sources(sources: Vec<String>) {
    let mut config = CONFIG.write().unwrap();
    config.disabled_sources = sources;
    log::info!("Disabled sources updated: {:?}", config.disabled_sources);
}

pub fn is_source_enabled(name: &str) -> bool {
    !CONFIG
        .read()
        .unwrap()
        .disabled_sources
        .contains(&name.to_string())
}
