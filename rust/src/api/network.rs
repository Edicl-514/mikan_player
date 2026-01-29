use log::warn;
use reqwest::{Client, Proxy};
use std::process::Command;
use std::time::Duration;

#[derive(Debug)]
pub struct ProxyConfig {
    pub url: String,
}

pub fn get_system_proxy() -> Option<String> {
    #[cfg(target_os = "windows")]
    {
        // 1. Check ProxyEnable
        let output = Command::new("reg")
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
                    // Basic validation: needs specific format?
                    // It might be "http=127.0.0.1:7890;https=..." or just "127.0.0.1:7890"
                    // If it doesn't start with http, assume http
                    let proxy_url = if addr.contains("=") {
                        // complex string, maybe just take the first one or ignore
                        // For simplicity, if it's complex, we might skip parsing or try safe extraction
                        // Let's assume standard "IP:PORT" for now common in simple proxy setups
                        return None; // Too complex to parse reliably without better logic
                    } else {
                        if !addr.starts_with("http") {
                            format!("http://{}", addr)
                        } else {
                            addr.to_string()
                        }
                    };
                    return Some(proxy_url);
                }
            }
        }
    }

    // Fallback or other OS
    None
}

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
