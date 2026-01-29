use lazy_static::lazy_static;
use std::sync::RwLock;

pub struct RuntimeConfig {
    pub bgmlist_url: String,
    pub bangumi_url: String,
    pub mikan_url: String,
    pub bt_sub_url: String,
    pub playback_sub_url: String,
}

lazy_static! {
    pub static ref CONFIG: RwLock<RuntimeConfig> = RwLock::new(RuntimeConfig {
        bgmlist_url: "https://bgmlist.com".to_string(),
        bangumi_url: "https://bangumi.tv".to_string(),
        mikan_url: "https://mikanani.kas.pub".to_string(),
        bt_sub_url: "https://sub.creamycake.org/v1/bt1.json".to_string(),
        playback_sub_url: "https://sub.creamycake.org/v1/css1.json".to_string(),
    });
}

fn normalize_url(url: &str) -> String {
    let mut s = url.trim().to_string();
    while s.ends_with('/') {
        s.pop();
    }
    s
}

pub fn update_config(
    bgm: String,
    bangumi: String,
    mikan: String,
    bt_sub: String,
    playback_sub: String,
) {
    let mut config = CONFIG.write().unwrap();
    config.bgmlist_url = normalize_url(&bgm);
    config.bangumi_url = normalize_url(&bangumi);
    config.mikan_url = normalize_url(&mikan);
    config.bt_sub_url = bt_sub.trim().to_string();
    config.playback_sub_url = playback_sub.trim().to_string();
    log::info!(
        "Config updated: bgm={}, bangumi={}, mikan={}, bt_sub={}, playback_sub={}",
        config.bgmlist_url,
        config.bangumi_url,
        config.mikan_url,
        config.bt_sub_url,
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

pub fn get_bt_sub_url() -> String {
    CONFIG.read().unwrap().bt_sub_url.clone()
}

pub fn get_playback_sub_url() -> String {
    CONFIG.read().unwrap().playback_sub_url.clone()
}
