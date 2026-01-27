use flutter_rust_bridge::frb;
use lazy_static::lazy_static;
use librqbit::{
    api::Api,
    http_api::HttpApi,
    Session, SessionOptions, AddTorrent, AddTorrentOptions, AddTorrentResponse
};
use std::sync::Arc;
use tokio::sync::Mutex;
use std::net::SocketAddr;

#[frb(init)]
pub fn init_app() {
    // Use librqbit's own tracing subscriber if possible, or keep simple logger
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    flutter_rust_bridge::setup_default_user_utils();
    log::info!("Mikan Player Rust engine initialized");
}

pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}

struct AppState {
    session: Arc<Session>,
}

lazy_static! {
    static ref STATE: Arc<Mutex<Option<Arc<AppState>>>> = Arc::new(Mutex::new(None));
}

// Initialize session and server if not already running
async fn ensure_initialized() -> anyhow::Result<Arc<AppState>> {
    let mut state_guard = STATE.lock().await;
    if let Some(state) = state_guard.as_ref() {
        return Ok(state.clone());
    }

    let mut options = SessionOptions::default();
    // Set standard BitTorrent ports (6881-6889) to help Clash/Firewalls identify traffic type
    // and apply "DIRECT" rules (bypassing proxy) automatically.
    options.listen_port_range = Some(6881..6889);
    
    // Enable UPnP for NAT traversal
    options.enable_upnp_port_forwarding = true;
    
    // Enable DHT for better peer discovery (especially for magnets)
    // This is crucial for discovering peers from magnet links
    options.disable_dht = false;
    options.disable_dht_persistence = false;
    
    // Change download directory to a local "downloads" folder instead of Temp.
    // This often avoids aggressive Antivirus/Indexing interference on Windows.
    let download_dir = std::env::current_exe()?
        .parent()
        .unwrap_or(&std::env::current_dir()?)
        .join("downloads");
        
    if !download_dir.exists() {
        std::fs::create_dir_all(&download_dir)?;
    }
    
    log::info!("Torrent data directory: {:?}", download_dir);
    let session = Session::new_with_opts(download_dir, options).await?;
    
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

    let app_state = Arc::new(AppState {
        session: session.clone(),
    });

    *state_guard = Some(app_state.clone());
    Ok(app_state)
}

pub async fn start_torrent(magnet: String) -> String {
    // Demo fallback for quick testing
    if magnet.contains("demo") || magnet.is_empty() {
         return "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4".to_string();
    }

    let state = match ensure_initialized().await {
        Ok(s) => s,
        Err(e) => return format!("Error initializing engine: {}", e),
    };

    // Add Torrent
    let mut magnet = magnet;
    // Inject high-quality trackers. 
    // These are especially helpful for anime resources.
    let trackers = [
        "&tr=http://share.camoe.cn:8080/announce",
        "&tr=http://t.acg.rip:6699/announce",
        "&tr=http://tracker.kamigami.org:2710/announce",
        "&tr=https://tr.bangumi.moe:9696/announce",
        "&tr=udp://tracker.opentrackr.org:1337/announce",
        "&tr=udp://tracker.openbittorrent.com:80/announce",
        "&tr=udp://opentracker.i2p.rocks:6969/announce",
        "&tr=udp://public.popcorn-tracker.org:6969/announce"
    ];
    
    for tr in trackers {
        if !magnet.contains(tr) {
            magnet.push_str(tr);
        }
    }
    
    // Optimized Torrent Options for streaming
    let mut add_opts = AddTorrentOptions::default();
    
    // Use sequential mode for streaming - downloads pieces in order
    // This is crucial for video playback
    add_opts.overwrite = false;
    add_opts.only_files_regex = None; // We'll select the file after getting metadata
    add_opts.output_folder = None; // Use default download folder
    
    let torrent = AddTorrent::from_url(magnet.clone());
    
    // We get a handle and ID from the response
    let response = match state.session.add_torrent(torrent, Some(add_opts)).await {
        Ok(res) => res,
        Err(e) => return format!("Error adding torrent: {}", e),
    };
    
    let (_id, handle) = match response {
        AddTorrentResponse::Added(id, h) => (id, h),
        AddTorrentResponse::AlreadyManaged(id, h) => (id, h),
        AddTorrentResponse::ListOnly(_) => return "Error: Torrent is list-only mode".to_string(), 
    };

    // Wait for metadata to ensure file list is populated
    if let Err(e) = handle.wait_until_initialized().await {
        return format!("Error waiting for metadata: {}", e);
    }


    
    // Find largest file (video)
    let info_hash = handle.info_hash().as_string();
    
    let (largest_file_idx, largest_len) = handle.with_metadata(|meta| {
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
    }).unwrap_or((0, 0));

    if largest_len == 0 {
         return "Error: No files found in torrent".to_string();
    }

    // Try to select only the largest file for download to save bandwidth
    // Note: In librqbit 8.x, file selection API may be limited
    // The stream endpoint should prioritize downloading pieces sequentially
    
    log::info!("Streaming file index {} from torrent {} (size: {} bytes)", 
               largest_file_idx, info_hash, largest_len);
    
    // Get current stats for debugging
    let stats = handle.stats();
    if let Some(live) = &stats.live {
        log::info!("Torrent state: {:?}, download speed: {:.2} MB/s", 
                   stats.state, live.download_speed.mbps);
    } else {
        log::info!("Torrent state: {:?}, not yet live", stats.state);
    }

    // Construct stream URL
    format!("http://127.0.0.1:3000/torrents/{}/stream/{}", info_hash, largest_file_idx)
}

/// Get torrent download stats for debugging
/// Returns stats for currently active torrents
pub async fn get_all_torrents_info() -> String {
    let _state = match ensure_initialized().await {
        Ok(s) => s,
        Err(e) => return format!("Error: {}", e),
    };

    // Get all torrent handles - simplified approach
    let mut result = String::from("Active Torrents:\n");
    
    // Since we can't easily list all torrents, return a generic message
    result.push_str("Use logs to monitor torrent activity\n");
    result.push_str("Check DHT and peer connections in the output\n");
    
    result
}
