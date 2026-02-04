#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

use log::warn;
use reqwest::{Client, Proxy};
use std::process::Command;
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
        // 1. Check ProxyEnable
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
            // Proxy not enabled
            return None;
        }

        // 2. Get ProxyServer
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
        // Output format check: ... ProxyServer    REG_SZ    127.0.0.1:7890 ...
        for line in stdout.lines() {
            if line.contains("ProxyServer") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                // last part should be the address
                if let Some(addr) = parts.last() {
                    // It might be "http=127.0.0.1:7890;https=127.0.0.1:7890" or just "127.0.0.1:7890"
                    let target_addr = if addr.contains("=") {
                        // Try to find the http= part
                        addr.split(';')
                            .find(|s| s.starts_with("http="))
                            .map(|s| s.trim_start_matches("http="))
                            .or_else(|| {
                                // Fallback to just splitting by = if http= not found but someone used =
                                addr.split('=').last()
                            })
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

    // Fallback or other OS
    None
}

#[flutter_rust_bridge::frb(ignore)]
pub fn create_client() -> reqwest::Result<Client> {
    let mut builder = Client::builder()
        .user_agent("MikanPlayer/1.0")
        .timeout(Duration::from_secs(30));

    if let Some(proxy_url) = get_system_proxy() {
        match Proxy::all(&proxy_url) {
            Ok(proxy) => {
                builder = builder.proxy(proxy);
            }
            Err(e) => {
                warn!("Failed to create proxy from {}: {}", proxy_url, e);
            }
        }
    } else {
        // Fallback to strict system proxy checking if needed, or just none.
        // reqwest's Proxy::system() might be good to add as a fallback?
        // But user asked to "if detected... use it". If I failed to detect but system has it configured in a way I missed?
        // Let's stick to explicit detection for now as requested.
    }

    builder.build()
}
