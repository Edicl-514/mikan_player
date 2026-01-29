use log::{debug, info, warn};
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanSearchResult {
    pub id: String,
    pub name: String,
    pub image_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanEpisodeResource {
    pub title: String,
    pub magnet: String,
    pub size: String,
    pub update_time: String,
    pub episode: Option<i32>,
}

// Simple Levenshtein distance implementation
fn levenshtein(s1: &str, s2: &str) -> usize {
    let v1: Vec<char> = s1.chars().collect();
    let v2: Vec<char> = s2.chars().collect();
    let l1 = v1.len();
    let l2 = v2.len();

    let mut matrix = vec![vec![0; l2 + 1]; l1 + 1];

    for i in 0..=l1 {
        matrix[i][0] = i;
    }
    for j in 0..=l2 {
        matrix[0][j] = j;
    }

    for i in 1..=l1 {
        for j in 1..=l2 {
            let cost = if v1[i - 1] == v2[j - 1] { 0 } else { 1 };
            matrix[i][j] = (matrix[i - 1][j] + 1)
                .min(matrix[i][j - 1] + 1)
                .min(matrix[i - 1][j - 1] + cost);
        }
    }

    matrix[l1][l2]
}

// Calculate similarity (0.0 to 1.0)
fn similarity(s1: &str, s2: &str) -> f64 {
    let distance = levenshtein(s1, s2);
    let max_len = s1.chars().count().max(s2.chars().count());
    if max_len == 0 {
        return 1.0;
    }
    1.0 - (distance as f64 / max_len as f64)
}

lazy_static::lazy_static! {
    static ref SEASON_RE: regex::Regex = regex::Regex::new(r"(?i)第[一二三四五六七八九十\d]+季|Part\s*\d+|\d+(st|nd|rd|th)\s*Season|Season\s*\d+").unwrap();
}

pub async fn search_mikan_anime(name_cn: String) -> anyhow::Result<Option<MikanSearchResult>> {
    let cleaned_name = name_cn.trim();
    let punctuation = |c: char| -> bool {
        c.is_ascii_punctuation()
            || "。！，、？（）《》【】“”‘’「」『』〜～·•ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫ".contains(c)
    };

    // 1. Replace all punctuation with spaces
    let mut cleaned = name_cn
        .chars()
        .map(|c| if punctuation(c) { ' ' } else { c })
        .collect::<String>();

    // 2. Remove season related keywords using regex
    cleaned = SEASON_RE.replace_all(&cleaned, " ").to_string();

    // 3. Split by whitespace and pick the longest segment
    let segments: Vec<&str> = cleaned
        .split_whitespace()
        .filter(|s| s.chars().count() >= 1)
        .collect();

    let final_search_str = segments
        .iter()
        .max_by_key(|s| s.chars().count())
        .map(|s| s.to_string())
        .unwrap_or_else(|| cleaned_name.to_string());

    info!(
        "Searching Mikan for anime: {} (Processed from {})",
        final_search_str, name_cn
    );

    let url = format!(
        "{}/Home/Search?searchstr={}",
        crate::api::config::get_mikan_url(),
        final_search_str
    );
    debug!("Mikan search URL: {}", url);
    let client = crate::api::network::create_client()?;
    let resp = client.get(&url).send().await?.text().await?;
    let document = Html::parse_document(&resp);

    let list_selector = Selector::parse(".an-ul li a").unwrap();
    let text_selector = Selector::parse(".an-text").unwrap();
    let bg_selector = Selector::parse(".b-lazy").unwrap();

    let mut results = Vec::new();

    for element in document.select(&list_selector) {
        let href = element.value().attr("href").unwrap_or("");
        if !href.contains("/Home/Bangumi/") {
            continue;
        }
        let id = href.split('/').last().unwrap_or("").to_string();

        let name = element
            .select(&text_selector)
            .next()
            .map(|e| e.attr("title").unwrap_or("").to_string())
            .unwrap_or_default();

        let style = element
            .select(&bg_selector)
            .next()
            .map(|e| e.attr("style").unwrap_or("").to_string())
            .unwrap_or_default();

        let image_url = if let Some(start) = style.find("url('") {
            if let Some(end) = style[start + 5..].find("'") {
                format!(
                    "{}{}",
                    crate::api::config::get_mikan_url(),
                    &style[start + 5..start + 5 + end]
                )
            } else if let Some(start2) = style.find("url(&quot;") {
                if let Some(end2) = style[start2 + 10..].find("&quot;") {
                    format!(
                        "{}{}",
                        crate::api::config::get_mikan_url(),
                        &style[start2 + 10..start2 + 10 + end2]
                    )
                } else {
                    "".to_string()
                }
            } else {
                "".to_string()
            }
        } else {
            "".to_string()
        };

        // Use the original cleaned name for similarity to match the correct season
        let sim = similarity(cleaned_name, &name);
        debug!(
            "Found result: {} (ID: {}) Image: {} Similarity: {}",
            name, id, image_url, sim
        );
        results.push((
            MikanSearchResult {
                id,
                name,
                image_url,
            },
            sim,
        ));
    }

    results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    if let Some(best) = results.first() {
        info!(
            "Selected Mikan anime: {} (ID: {}) with similarity {}",
            best.0.name, best.0.id, best.1
        );
        Ok(Some(best.0.clone()))
    } else {
        warn!("No Mikan anime found for search: {}", final_search_str);
        Ok(None)
    }
}

fn extract_episode(title: &str) -> Option<i32> {
    let re_chars = ['[', ']', '【', '】', '(', ')', ' ', '-', '_'];
    let parts: Vec<&str> = title
        .split(|c| re_chars.contains(&c))
        .filter(|s| !s.is_empty())
        .collect();

    for part in parts.iter().rev() {
        if let Ok(num) = part.parse::<i32>() {
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

fn parse_mikan_resources_from_html(
    html_content: &str,
    current_episode_sort: i32,
) -> Vec<MikanEpisodeResource> {
    let document = Html::parse_document(html_content);
    let table_selector = Selector::parse(".episode-table tbody tr").unwrap();
    let name_selector = Selector::parse(".magnet-link-wrap").unwrap();
    let size_selector = Selector::parse("td:nth-child(3)").unwrap();
    let time_selector = Selector::parse("td:nth-child(4)").unwrap();
    let magnet_selector = Selector::parse(".js-magnet").unwrap();

    let mut resources = Vec::new();

    for row in document.select(&table_selector) {
        let name_el = row.select(&name_selector).next();
        let magnet_el = row.select(&magnet_selector).next();

        if let (Some(name_el), Some(magnet_el)) = (name_el, magnet_el) {
            let title = name_el.text().collect::<String>();
            let magnet = magnet_el
                .attr("data-clipboard-text")
                .unwrap_or("")
                .to_string();

            let size = row
                .select(&size_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();
            let update_time = row
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();

            let episode = extract_episode(&title);

            if let Some(ep) = episode {
                if ep == current_episode_sort {
                    debug!("Matched resource: {} (EP {}) Magnet: {}", title, ep, magnet);
                    resources.push(MikanEpisodeResource {
                        title: title.clone(),
                        magnet,
                        size,
                        update_time,
                        episode: Some(ep),
                    });
                }
            }
        }
    }
    resources
}

fn get_mikan_expand_urls(html_content: &str, mikan_id: &str) -> Vec<String> {
    let document = Html::parse_document(html_content);
    let expand_selector = Selector::parse(".js-expand-episode").unwrap();
    let mut expand_urls = Vec::new();

    for btn in document.select(&expand_selector) {
        let group_id = btn.attr("data-subtitlegroupid").unwrap_or("");
        let take = btn.attr("data-take").unwrap_or("");

        if !group_id.is_empty() && !take.is_empty() {
            let expand_url = format!(
                "{}/Home/ExpandEpisodeTable?bangumiId={}&subtitleGroupId={}&take={}",
                crate::api::config::get_mikan_url(),
                mikan_id,
                group_id,
                take
            );
            expand_urls.push(expand_url);
        }
    }
    expand_urls
}

pub async fn get_mikan_resources(
    mikan_id: String,
    current_episode_sort: i32,
) -> anyhow::Result<Vec<MikanEpisodeResource>> {
    info!(
        "Fetching Mikan resources for ID: {} Episode: {}",
        mikan_id, current_episode_sort
    );
    let url = format!(
        "{}/Home/Bangumi/{}",
        crate::api::config::get_mikan_url(),
        mikan_id
    );
    debug!("Mikan bangumi URL: {}", url);
    let client = crate::api::network::create_client()?;
    let resp = client.get(&url).send().await?.text().await?;

    let mut resources = parse_mikan_resources_from_html(&resp, current_episode_sort);

    // Check for "Show More" buttons
    let expand_urls = get_mikan_expand_urls(&resp, &mikan_id);

    if !expand_urls.is_empty() {
        info!(
            "Found {} 'Show More' buttons, fetching extra resources...",
            expand_urls.len()
        );
        for expand_url in expand_urls {
            debug!("Fetching expanded resources: {}", expand_url);
            match client.get(&expand_url).send().await {
                Ok(resp) => {
                    if let Ok(html) = resp.text().await {
                        let extra = parse_mikan_resources_from_html(&html, current_episode_sort);
                        resources.extend(extra);
                    }
                }
                Err(e) => warn!(
                    "Failed to fetch expanded resources from {}: {}",
                    expand_url, e
                ),
            }
        }
    }

    info!("Found {} total matching resources.", resources.len());
    Ok(resources)
}
