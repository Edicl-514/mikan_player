use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use librqbit::{
    AddTorrent, AddTorrentOptions, AddTorrentResponse, Session, SessionOptions, api::Api,
    api::TorrentIdOrHash, http_api::HttpApi,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::Mutex;

pub fn init_engine(cache_dir: String, download_dir: String) {
    // Initialize config with paths
    crate::api::config::init_config(cache_dir, download_dir);

    // Disable heavy logs from rqbit and related crates
    env_logger::Builder::from_env(
        env_logger::Env::default()
            .default_filter_or("info,librqbit=off,librqbit_dht=off,tracing=off"),
    )
    .init();
    flutter_rust_bridge::setup_default_user_utils();
    log::info!("Mikan Player Rust engine initialized");

    if let Some(proxy) = crate::api::network::get_system_proxy() {
        log::info!("Detected system proxy: {}", proxy);
    } else {
        log::info!("No system proxy detected.");
    }
}

pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}

pub fn update_config(bgm: String, bangumi: String, mikan: String, playback_sub: String) {
    crate::api::config::update_config(bgm, bangumi, mikan, playback_sub);
}

pub fn set_disabled_sources(sources: Vec<String>) {
    crate::api::config::set_disabled_sources(sources);
}

pub async fn get_playback_sources() -> Vec<crate::api::generic_scraper::SourceState> {
    match crate::api::generic_scraper::get_playback_sources().await {
        Ok(s) => s,
        Err(e) => {
            log::error!("Failed to get playback sources: {}", e);
            vec![]
        }
    }
}

/// 预加载播放源配置（应用启动和设置更改时调用）
/// 这会尝试从订阅地址拉取最新的配置，失败时使用本地备份
pub async fn preload_playback_source_config() -> String {
    log::info!("Starting to preload playback source config...");
    match crate::api::generic_scraper::preload_playback_sources().await {
        Ok(_) => {
            log::info!("Playback source config preloaded successfully");
            "success".to_string()
        }
        Err(e) => {
            log::warn!("Failed to preload playback source config: {}", e);
            format!("error: {}", e)
        }
    }
}

/// 刷新播放源配置（从订阅地址重新拉取并保存到本地缓存）
/// 只在用户点击刷新按钮时调用
pub async fn refresh_playback_source_config() -> String {
    log::info!("Starting to refresh playback source config from subscription URL...");
    match crate::api::generic_scraper::refresh_playback_source_config().await {
        Ok(_) => {
            log::info!("Playback source config refreshed successfully");
            "success".to_string()
        }
        Err(e) => {
            log::error!("Failed to refresh playback source config: {}", e);
            format!("error: {}", e)
        }
    }
}

struct AppState {
    session: Arc<Session>,
}

lazy_static! {
    static ref STATE: Arc<Mutex<Option<Arc<tokio::sync::Mutex<AppState>>>>> =
        Arc::new(Mutex::new(None));
}

// Initialize session and server if not already running
async fn ensure_initialized() -> anyhow::Result<Arc<tokio::sync::Mutex<AppState>>> {
    let mut state_guard = STATE.lock().await;
    if let Some(state) = state_guard.as_ref() {
        return Ok(state.clone());
    }

    let mut options = SessionOptions::default();
    // Enable a TCP listener for incoming peer connections.
    // Using a high port range avoids the legacy 6881-6889 ports that some ISPs throttle.
    // NOTE: `None` disables listening entirely in librqbit.
    options.listen_port_range = Some(49152..65535);

    // Enable UPnP for NAT traversal
    options.enable_upnp_port_forwarding = true;

    // Buffer some disk writes in memory to reduce small-write overhead on Windows.
    // This can noticeably improve throughput on some machines (AV/indexing/slow disks).
    // Value is in megabytes.
    options.defer_writes_up_to = Some(64);

    // Enable DHT for better peer discovery (especially for magnets)
    // This is crucial for discovering peers from magnet links
    options.disable_dht = false;

    // Disable DHT persistence on Android to avoid initialization errors.
    // Some Android file systems or permission settings can cause issues with the DHT state file.
    #[cfg(target_os = "android")]
    {
        options.disable_dht_persistence = true;
    }
    #[cfg(not(target_os = "android"))]
    {
        options.disable_dht_persistence = false;
    }

    // Optimize peer connections for faster downloads
    options.peer_opts = Some(librqbit::PeerConnectionOptions {
        // Increase timeouts to allow slower peers to connect
        connect_timeout: Some(std::time::Duration::from_secs(20)),
        read_write_timeout: Some(std::time::Duration::from_secs(60)),
        ..Default::default()
    });

    // Note: librqbit 8.1.1 may not have disable_pex option
    // PEX is usually enabled by default in modern BitTorrent clients

    // Use the provided download directory from config
    let download_dir = std::path::PathBuf::from(crate::api::config::get_download_dir());

    if !download_dir.exists() {
        std::fs::create_dir_all(&download_dir)?;
    }

    log::info!("Torrent data directory: {:?}", download_dir);
    let session = Session::new_with_opts(download_dir, options).await?;

    if let Some(port) = session.tcp_listen_port() {
        log::info!("rqbit incoming TCP listener: 0.0.0.0:{}", port);
    } else {
        log::warn!("rqbit incoming TCP listener is DISABLED (no listen port)");
    }

    let api = Api::new(session.clone(), None, None);

    let http_api = HttpApi::new(api, None);

    // Start HTTP Server on port 3000
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = tokio::net::TcpListener::bind(addr).await?;

    // Spawn server in background
    tokio::spawn(async move {
        if let Err(e) = http_api.make_http_api_and_run(listener, None).await {
            log::error!("HttpApi server error: {}", e);
        }
    });

    let app_state = Arc::new(tokio::sync::Mutex::new(AppState {
        session: session.clone(),
    }));

    *state_guard = Some(app_state.clone());
    Ok(app_state)
}

pub async fn start_torrent(magnet: String) -> String {
    // Demo fallback for quick testing
    if magnet.contains("demo") || magnet.is_empty() {
        return "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
            .to_string();
    }

    let state = match ensure_initialized().await {
        Ok(s) => s,
        Err(e) => return format!("Error initializing engine: {}", e),
    };

    let state_guard = state.lock().await;

    // Add Torrent
    let mut magnet = magnet;

    // Log original magnet link (truncated for safety)
    let magnet_preview = if magnet.len() > 200 {
        format!("{}...", &magnet[..200])
    } else {
        magnet.clone()
    };
    log::info!("Original magnet link: {}", magnet_preview);

    // Count original trackers in the magnet link
    let original_tracker_count = magnet.matches("&tr=").count();
    log::info!(
        "Original magnet contains {} trackers",
        original_tracker_count
    );

    // Inject high-quality trackers.
    // These are especially helpful for anime resources and general torrents.
    let trackers = [
        // Anime-specific trackers (critical for anime content)
        "&tr=http://share.camoe.cn:8080/announce",
        "&tr=http://t.acg.rip:6699/announce",
        "&tr=http://tracker.kamigami.org:2710/announce",
        "&tr=https://tr.bangumi.moe:9696/announce",
        "&tr=http://tr.bangumi.moe:6969/announce",
        "&tr=http://open.acgtracker.com:1096/announce",
        // Popular stable public trackers (Best of 2025)
        "&tr=udp://tracker.opentrackr.org:1337/announce",
        "&tr=udp://open.tracker.cl:1337/announce",
        "&tr=udp://9.rarbg.me:2970/announce",
        "&tr=udp://p4p.arenabg.com:1337/announce",
        "&tr=udp://tracker.torrent.eu.org:451/announce",
        "&tr=udp://tracker.doko.moe:6969/announce",
        "&tr=https://trackers.mlz.io:443/announce",
        "&tr=udp://tracker.moeking.me:6969/announce",
        "&tr=udp://open.stealth.si:80/announce",
        "&tr=udp://exodus.desync.com:6969/announce",
        "&tr=udp://open.demonii.com:1337/announce",
        "&tr=udp://explodie.org:6969/announce",
        "&tr=udp://tracker.openbittorrent.com:6969/announce",
        "&tr=http://tracker.openbittorrent.com:80/announce",
        "&tr=udp://opentracker.i2p.rocks:6969/announce",
        "&tr=https://opentracker.i2p.rocks:443/announce",
        "&tr=wss://tracker.openwebtorrent.com",
    ];

    let mut added_tracker_count = 0;
    // Use a HashSet to track existing trackers for faster valid checking (optional but good practice)
    // Here we just simple check constraint
    for tr in trackers {
        // Simple deduplication check
        if !magnet.contains(tr) {
            magnet.push_str(tr);
            added_tracker_count += 1;
        }
    }

    let final_tracker_count = magnet.matches("&tr=").count();
    log::info!(
        "Added {} new trackers, total {} trackers in final magnet link",
        added_tracker_count,
        final_tracker_count
    );

    // Optimized Torrent Options for streaming
    let mut add_opts = AddTorrentOptions::default();

    // Use sequential mode for streaming - downloads pieces in order
    // This is crucial for video playback
    add_opts.overwrite = true;
    add_opts.only_files_regex = None; // We'll select the file after getting metadata
    add_opts.output_folder = None; // Use default download folder

    // Enable initial peer fetch to get more peers quickly
    add_opts.initial_peers = None; // Let it use tracker announces

    // List mode should be false to actually download
    add_opts.list_only = false;

    // Force reannounce to trackers to get fresh peer list
    add_opts.force_tracker_interval = None; // Use default tracker intervals

    let torrent = AddTorrent::from_url(magnet.clone());

    // We get a handle and ID from the response
    let response = match state_guard
        .session
        .add_torrent(torrent, Some(add_opts))
        .await
    {
        Ok(res) => res,
        Err(e) => return format!("Error adding torrent: {}", e),
    };

    let (_id, handle) = match response {
        AddTorrentResponse::Added(id, h) => (id, h),
        AddTorrentResponse::AlreadyManaged(id, h) => (id, h),
        AddTorrentResponse::ListOnly(_) => return "Error: Torrent is list-only mode".to_string(),
    };

    // Release the lock before waiting for metadata to avoid blocking other API calls (like stop_torrent)
    drop(state_guard);

    // Wait for metadata to ensure file list is populated
    if let Err(e) = handle.wait_until_initialized().await {
        return format!("Error waiting for metadata: {}", e);
    }

    // Find largest file (video)
    let info_hash = handle.info_hash().as_string();

    // Log tracker information for debugging
    // This helps verify that trackers are being used correctly
    let stats = handle.stats();
    if let Some(live) = &stats.live {
        log::info!(
            "Torrent status: state={:?}, peers={}, download_speed={:.2} MB/s",
            stats.state,
            live.snapshot.peer_stats.live,
            live.download_speed.mbps
        );
    }

    let (largest_file_idx, largest_len) = handle
        .with_metadata(|meta| {
            let mut largest_idx = 0;
            let mut largest_len = 0;
            if let Ok(file_iter) = meta.info.iter_file_details() {
                for (idx, file) in file_iter.enumerate() {
                    if file.len > largest_len {
                        largest_len = file.len;
                        largest_idx = idx;
                    }
                }
            }
            (largest_idx, largest_len)
        })
        .unwrap_or((0, 0));

    if largest_len == 0 {
        return "Error: No files found in torrent".to_string();
    }

    // Note: In librqbit 8.x, sequential download and file selection are handled differently
    // The HTTP streaming endpoint will handle sequential piece requests automatically
    // We rely on the stream endpoint to prioritize downloading pieces in order

    // Pause briefly to allow peer connections to establish
    // This gives the torrent client time to connect to more peers before streaming starts
    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;

    log::info!(
        "Streaming file index {} from torrent {} (size: {} bytes)",
        largest_file_idx,
        info_hash,
        largest_len
    );

    // Get current stats for debugging
    let stats = handle.stats();
    if let Some(live) = &stats.live {
        log::info!(
            "Torrent state: {:?}, download speed: {:.2} MB/s",
            stats.state,
            live.download_speed.mbps
        );
    } else {
        log::info!("Torrent state: {:?}, not yet live", stats.state);
    }

    // Construct stream URL
    format!(
        "http://127.0.0.1:3000/torrents/{}/stream/{}",
        info_hash, largest_file_idx
    )
}

/// Torrent download statistics
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct TorrentStats {
    pub info_hash: String,
    pub name: String,
    pub state: String,
    pub progress: f64,
    pub download_speed: f64, // bytes per second
    pub upload_speed: f64,   // bytes per second
    pub downloaded: u64,     // bytes
    pub total_size: u64,     // bytes
    pub peers: u32,
    pub seeders: u32,
}

/// Detailed tracker status information
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct TrackerInfo {
    pub url: String,
    pub status: String,
    pub peers: u32,
    pub last_announce: String,
}

/// Get tracker information for a specific torrent
pub async fn get_tracker_info(info_hash: String) -> Vec<TrackerInfo> {
    let state = match ensure_initialized().await {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    let state_guard = state.lock().await;
    let info_hash_lower = info_hash.to_lowercase();

    // Find the torrent by info hash and get tracker info
    state_guard.session.with_torrents(|torrents| {
        for (_id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                // Note: librqbit may not expose detailed tracker info in the public API
                // This is a placeholder for future implementation
                // For now, we return basic info
                log::info!("Getting tracker info for torrent: {}", info_hash);

                // Return empty vec as librqbit doesn't expose tracker details easily
                return vec![];
            }
        }
        vec![]
    })
}

/// Get detailed stats for all active torrents
pub async fn get_torrent_stats() -> Vec<TorrentStats> {
    let state = match ensure_initialized().await {
        Ok(s) => s,
        Err(_) => return vec![],
    };

    let state_guard = state.lock().await;

    // Use the session's torrent iteration method - collect data inside closure
    let results: Vec<TorrentStats> = state_guard.session.with_torrents(|torrents| {
        let mut collected = Vec::new();
        for (id, handle) in torrents {
            let stats = handle.stats();
            let info_hash = handle.info_hash().as_string().to_lowercase();

            // Get torrent name from metadata
            let name = handle
                .with_metadata(|meta| {
                    meta.info
                        .name
                        .as_ref()
                        .map(|s| s.to_string())
                        .unwrap_or_else(|| format!("Torrent {}", id))
                })
                .unwrap_or_else(|_| format!("Torrent {}", id));

            // Get total size
            let total_size: u64 = handle
                .with_metadata(|meta| {
                    meta.info
                        .iter_file_lengths()
                        .ok()
                        .map(|iter| iter.sum::<u64>())
                        .unwrap_or(0)
                })
                .unwrap_or(0);

            let (download_speed, upload_speed, downloaded, peers, seeders) =
                if let Some(live) = &stats.live {
                    (
                        live.download_speed.mbps,
                        live.upload_speed.mbps,
                        stats.progress_bytes,
                        live.snapshot.peer_stats.live as u32,
                        live.snapshot.peer_stats.seen as u32,
                    )
                } else {
                    (0.0, 0.0, stats.progress_bytes, 0, 0)
                };

            let progress = if total_size > 0 {
                (downloaded as f64 / total_size as f64) * 100.0
            } else {
                0.0
            };

            collected.push(TorrentStats {
                info_hash,
                name,
                state: format!("{:?}", stats.state),
                progress,
                download_speed: download_speed as f64 * 1024.0 * 1024.0, // Convert from MB/s to bytes/s
                upload_speed: upload_speed as f64 * 1024.0 * 1024.0,
                downloaded,
                total_size,
                peers,
                seeders,
            });
        }
        collected
    });

    results
}

/// Get torrent download stats for debugging
/// Returns stats for currently active torrents
pub async fn get_all_torrents_info() -> String {
    let stats = get_torrent_stats().await;

    if stats.is_empty() {
        return "No active torrents".to_string();
    }

    let mut result = String::from("Active Torrents:\n");
    for s in stats {
        result.push_str(&format!(
            "- {} ({:.1}%): {:.2} MB/s down, {} peers\n",
            s.name,
            s.progress,
            s.download_speed / 1024.0 / 1024.0,
            s.peers
        ));
    }

    result
}

/// Stop and remove a torrent by info hash
pub async fn stop_torrent(info_hash: String, delete_files: bool) -> bool {
    let state = match ensure_initialized().await {
        Ok(s) => s,
        Err(_) => return false,
    };

    let state_guard = state.lock().await;
    let info_hash_lower = info_hash.to_lowercase();

    // Find the torrent ID by info hash
    let torrent_id = state_guard.session.with_torrents(|torrents| {
        for (id, handle) in torrents {
            if handle.info_hash().as_string().to_lowercase() == info_hash_lower {
                return Some(id);
            }
        }
        None
    });

    if let Some(id) = torrent_id {
        match state_guard
            .session
            .delete(TorrentIdOrHash::Id(id), delete_files)
            .await
        {
            Ok(_) => {
                log::info!(
                    "Successfully stopped torrent: {} (delete_files: {})",
                    info_hash,
                    delete_files
                );
                true
            }
            Err(e) => {
                log::error!("Failed to stop torrent {}: {}", info_hash, e);
                false
            }
        }
    } else {
        log::warn!("Torrent not found: {}", info_hash);
        false
    }
}
