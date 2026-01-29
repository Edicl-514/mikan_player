use anyhow::Result;
use log::info;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DmhyResource {
    pub title: String,
    pub magnet: String,
    pub size: String,
    pub publish_date: String,
    pub episode: Option<i32>,
}

#[derive(Debug, Deserialize)]
struct Rss {
    channel: Channel,
}

#[derive(Debug, Deserialize)]
struct Channel {
    #[serde(rename = "item", default)]
    items: Vec<Item>,
}

#[derive(Debug, Deserialize)]
struct Item {
    title: String,
    enclosure: Option<Enclosure>,
    #[serde(rename = "pubDate")]
    pub_date: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Enclosure {
    #[serde(rename = "@url")]
    url: String,
    #[serde(rename = "@length")]
    length: String,
}

fn extract_episode(title: &str) -> Option<i32> {
    // Reusing the logic from mikan.rs or similar robust logic
    let re_chars = ['[', ']', '【', '】', '(', ')', ' ', '-', '_'];
    let parts: Vec<&str> = title
        .split(|c| re_chars.contains(&c))
        .filter(|s| !s.is_empty())
        .collect();

    for part in parts.iter().rev() {
        if let Ok(num) = part.parse::<i32>() {
            // Basic heuristic to avoid resolutions like 720, 1080, etc.
            if num > 0
                && num < 1000
                && num != 720
                && num != 1080
                && num != 2160
                && num != 264
                && num != 265
            {
                return Some(num);
            }
        }
    }
    None
}

fn format_size(size_bytes: u64) -> String {
    const UNITS: [&str; 4] = ["B", "KB", "MB", "GB"];
    let mut size = size_bytes as f64;
    let mut unit_idx = 0;

    while size >= 1024.0 && unit_idx < UNITS.len() - 1 {
        size /= 1024.0;
        unit_idx += 1;
    }

    format!("{:.1} {}", size, UNITS[unit_idx])
}

pub async fn fetch_dmhy_resources(
    subject_id: String,
    target_episode: i32,
) -> Result<Vec<DmhyResource>> {
    info!(
        "Fetching DMHY resources for Subject ID: {}, Episode: {}",
        subject_id, target_episode
    );

    let url = format!("https://api.animes.garden/feed.xml?subject={}", subject_id);
    let client = crate::api::network::create_client()?;

    let xml_content = client
        .get(&url)
        .header("accept", "application/xml")
        .send()
        .await?
        .text()
        .await?;

    let rss: Rss = quick_xml::de::from_str(&xml_content)?;

    let mut resources = Vec::new();

    for item in rss.channel.items {
        if let Some(enclosure) = item.enclosure {
            let episode = extract_episode(&item.title);

            if let Some(ep) = episode {
                if ep == target_episode {
                    let size_bytes = enclosure.length.parse::<u64>().unwrap_or(0);
                    let size_str = format_size(size_bytes);

                    resources.push(DmhyResource {
                        title: item.title,
                        magnet: enclosure.url,
                        size: size_str,
                        publish_date: item.pub_date.unwrap_or_default(),
                        episode: Some(ep),
                    });
                }
            }
        }
    }

    info!("Found {} matching DMHY resources", resources.len());
    Ok(resources)
}
