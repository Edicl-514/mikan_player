use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use serde_json;
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimeInfo {
    pub title: String,
    pub sub_title: Option<String>,
    pub bangumi_id: Option<String>,
    pub mikan_id: Option<String>,
    pub cover_url: Option<String>,
    pub site_url: Option<String>,
    pub broadcast_day: Option<String>,
    pub broadcast_time: Option<String>,
    pub score: Option<f64>,
    pub rank: Option<i32>,
    pub tags: Vec<String>,
    pub full_json: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchiveQuarter {
    pub year: String,
    pub quarter: String,
    pub title: String,
}

pub async fn fetch_archive_list() -> anyhow::Result<Vec<ArchiveQuarter>> {
    let url = format!("{}/archive", crate::api::config::get_bgmlist_url());
    let client = crate::api::network::create_client()?;
    let resp = client.get(url).send().await?.text().await?;
    let document = Html::parse_document(&resp);

    // Each year is an h3, followed by a list of months/quarters as a or li
    // Actually, looking at the markdown, it's like:
    // ### 2026年
    // 1. [2026年1月](https://bgmlist.com/archive/2026q1)

    let mut archives = Vec::new();
    let selector = Selector::parse("h3, a").unwrap();

    let mut current_year = String::new();

    for element in document.select(&selector) {
        if element.value().name() == "h3" {
            current_year = element
                .text()
                .collect::<String>()
                .replace("年", "")
                .trim()
                .to_string();
        } else if element.value().name() == "a" {
            let href = element.value().attr("href").unwrap_or("");
            if href.contains("/archive/") && !href.ends_with("/archive") {
                let title = element.text().collect::<String>();
                // href is like /archive/2026q1
                let quarter = href.split('/').last().unwrap_or("").to_string();
                // Filter out the year part from quarter if it's there
                // e.g. 2026q1 remains 2026q1

                if !current_year.is_empty() {
                    archives.push(ArchiveQuarter {
                        year: current_year.clone(),
                        quarter,
                        title,
                    });
                }
            }
        }
    }

    // Sort by quarter in descending order (e.g., 2026q1 > 2025q4 > 2025q3 ...)
    archives.sort_by(|a, b| b.quarter.cmp(&a.quarter));

    Ok(archives)
}

pub async fn fetch_schedule_basic(year_quarter: String) -> anyhow::Result<Vec<AnimeInfo>> {
    let url = format!(
        "{}/archive/{}",
        crate::api::config::get_bgmlist_url(),
        year_quarter
    );
    let client = crate::api::network::create_client()?;
    let resp = client.get(&url).send().await?.text().await?;
    let mut animes = Vec::new();

    {
        let document = Html::parse_document(&resp);

        // Select all anime root items. The hashes after __ might change, so we use starts-with.
        let root_selector = Selector::parse("[class*=\"BangumiItem_root__\"]").unwrap();
        let title_selector = Selector::parse("[class*=\"BangumiItem_title__\"]").unwrap();
        let sub_title_selector = Selector::parse("[class*=\"BangumiItem_subTitle__\"]").unwrap();
        let time_selector = Selector::parse("[class*=\"BangumiItem_jpTime__\"] dd").unwrap();
        let link_selector = Selector::parse("a").unwrap();

        for root in document.select(&root_selector) {
            let title = root
                .select(&title_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string())
                .unwrap_or_default();

            if title.is_empty() {
                continue;
            }

            let sub_title = root
                .select(&sub_title_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string());

            let time_str = root
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>().trim().to_string());

            let mut broadcast_day = None;
            let mut broadcast_time = None;

            if let Some(ts) = time_str {
                // ts is like "周一 00:00"
                let parts: Vec<&str> = ts.split_whitespace().collect();
                if parts.len() >= 2 {
                    broadcast_day = Some(parts[0].to_string());
                    broadcast_time = Some(parts[1].to_string());
                } else if parts.len() == 1 {
                    if parts[0].contains(':') {
                        broadcast_time = Some(parts[0].to_string());
                    } else {
                        broadcast_day = Some(parts[0].to_string());
                    }
                }
            }

            let mut anime = AnimeInfo {
                title,
                sub_title,
                bangumi_id: None,
                mikan_id: None,
                cover_url: None,
                site_url: None,
                broadcast_day,
                broadcast_time,
                score: None,
                rank: None,
                tags: Vec::new(),
                full_json: None,
            };

            for link in root.select(&link_selector) {
                let href = link.value().attr("href").unwrap_or("");
                let text = link.text().collect::<String>();

                if href.contains("bangumi.tv/subject/") || href.contains("bgm.tv/subject/") {
                    let id = href.split('/').last().unwrap_or("").to_string();
                    anime.bangumi_id = Some(id);
                } else if href.contains("mikanani.me/Home/Bangumi/")
                    || href.contains("mikanani.kas.pub/Home/Bangumi/")
                {
                    let id = href.split('/').last().unwrap_or("").to_string();
                    anime.mikan_id = Some(id);
                } else if text.contains("官网") || text.contains("官方网站") {
                    anime.site_url = Some(href.to_string());
                }
            }
            animes.push(anime);
        }
    }

    Ok(animes)
}

pub async fn fill_anime_details(animes: Vec<AnimeInfo>) -> anyhow::Result<Vec<AnimeInfo>> {
    let client = crate::api::network::create_client()?;

    let mut tasks = Vec::new();
    for mut anime in animes {
        let client_clone = client.clone();
        tasks.push(tokio::spawn(async move {
            if let Some(ref id) = anime.bangumi_id {
                let api_url = format!(
                    "{}/v0/subjects/{}",
                    crate::api::config::get_bangumi_api_url(),
                    id
                );
                if let Ok(resp) = client_clone.get(api_url).send().await {
                    if let Ok(json) = resp.json::<serde_json::Value>().await {
                        if let Some(image_url) = json["images"]["large"].as_str() {
                            anime.cover_url = Some(image_url.to_string());
                        }
                        if let Some(score) = json["rating"]["score"].as_f64() {
                            anime.score = Some(score);
                        }
                        if let Some(rank) = json["rating"]["rank"].as_i64() {
                            anime.rank = Some(rank as i32);
                        }
                        if let Some(meta_tags) = json["meta_tags"].as_array() {
                            let mut tags: Vec<String> = meta_tags
                                .iter()
                                .filter_map(|t| t.as_str().map(|s| s.to_string()))
                                .collect();
                            tags.sort();
                            tags.dedup();
                            anime.tags = tags;
                        }
                        anime.full_json = Some(json.to_string());
                    }
                }
            }
            anime
        }));
    }

    let mut results = Vec::new();
    for task in tasks {
        if let Ok(anime) = task.await {
            results.push(anime);
        }
    }

    Ok(results)
}

pub async fn fetch_extra_subjects(
    year_quarter: String,
    existing_ids: Vec<String>,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let client = crate::api::network::create_client()?;

    let existing_set: HashSet<String> = existing_ids.into_iter().collect();

    fetch_extra_bangumi_subjects(&client, &year_quarter, &existing_set).await
}

async fn fetch_extra_bangumi_subjects(
    client: &reqwest::Client,
    year_quarter: &str,
    existing_ids: &HashSet<String>,
) -> anyhow::Result<Vec<AnimeInfo>> {
    // Parse year and quarter
    if year_quarter.len() < 6 {
        return Ok(vec![]);
    }
    let year_str = &year_quarter[..4];
    let q_str = &year_quarter[4..];
    let year: i32 = year_str.parse().unwrap_or(2025);

    // Determine date range (Next quarter start is exclusive bound)
    let (start_date, end_date) = match q_str {
        "q1" => (format!("{}-01-01", year), format!("{}-04-01", year)),
        "q2" => (format!("{}-04-01", year), format!("{}-07-01", year)),
        "q3" => (format!("{}-07-01", year), format!("{}-10-01", year)),
        "q4" => (format!("{}-10-01", year), format!("{}-01-01", year + 1)),
        _ => return Ok(vec![]),
    };

    let url = format!(
        "{}/v0/search/subjects",
        crate::api::config::get_bangumi_api_url()
    );

    // Initial request to get total
    // Using limit=1 to minimize load
    let body_json = serde_json::json!({
        "filter": {
            "type": [2],
            "air_date": [format!(">={}", start_date), format!("<{}", end_date)],
            "tag": ["日本"]
        }
    });

    let init_resp = client
        .post(url)
        .query(&[("limit", "1"), ("offset", "0")])
        .header("Content-Type", "application/json")
        .header("accept", "application/json")
        .json(&body_json)
        .send()
        .await?;

    if !init_resp.status().is_success() {
        return Ok(vec![]);
    }

    let init_json: serde_json::Value = init_resp.json().await?;
    let total = init_json["total"].as_u64().unwrap_or(0);

    if total == 0 {
        return Ok(vec![]);
    }

    // Concurrent fetch logic
    let limit = 20;
    let num_pages = (total as f64 / limit as f64).ceil() as u64;
    let mut tasks = Vec::new();

    for i in 0..num_pages {
        let offset = i * limit;
        let client_c = client.clone();
        let body_c = body_json.clone();

        tasks.push(tokio::spawn(async move {
            let resp = client_c
                .post(format!(
                    "{}/v0/search/subjects",
                    crate::api::config::get_bangumi_api_url()
                ))
                .query(&[
                    ("limit", &limit.to_string()),
                    ("offset", &offset.to_string()),
                ])
                .header("Content-Type", "application/json")
                .header("accept", "application/json")
                .json(&body_c)
                .send()
                .await;

            match resp {
                Ok(r) => r.json::<serde_json::Value>().await.ok(),
                Err(_) => None,
            }
        }));
    }

    let mut new_animes = Vec::new();

    for task in tasks {
        if let Ok(Some(json)) = task.await {
            if let Some(data) = json["data"].as_array() {
                for item in data {
                    // Normalize ID for deduplication
                    let id_str = if let Some(n) = item["id"].as_u64() {
                        n.to_string()
                    } else if let Some(s) = item["id"].as_str() {
                        s.to_string()
                    } else {
                        continue;
                    };

                    if existing_ids.contains(&id_str) {
                        continue;
                    }

                    // Map to AnimeInfo
                    let name = item["name"].as_str().unwrap_or("");
                    let name_cn = item["name_cn"].as_str().unwrap_or("");
                    let title = if !name_cn.is_empty() {
                        name_cn.to_string()
                    } else {
                        name.to_string()
                    };

                    if title.is_empty() {
                        continue;
                    }

                    let date = item["date"].as_str().unwrap_or("").to_string();
                    let cover = item["images"]["large"].as_str().map(|s| s.to_string());

                    let score = item["score"]
                        .as_f64()
                        .or_else(|| item["rating"]["score"].as_f64());

                    let rank = item["rank"]
                        .as_i64()
                        .or_else(|| item["rating"]["rank"].as_i64())
                        .map(|r| r as i32);

                    let anime = AnimeInfo {
                        title: title.clone(),
                        sub_title: if name_cn.is_empty() {
                            None
                        } else {
                            Some(name.to_string())
                        },
                        bangumi_id: Some(id_str.clone()),
                        mikan_id: None,
                        cover_url: cover,
                        site_url: None,
                        broadcast_day: None, // Will show in "Other"
                        broadcast_time: if date.is_empty() { None } else { Some(date) },
                        score,
                        rank,
                        tags: item["meta_tags"]
                            .as_array()
                            .map(|arr| {
                                arr.iter()
                                    .filter_map(|v| v.as_str().map(String::from))
                                    .collect()
                            })
                            .unwrap_or_default(),
                        full_json: Some(item.to_string()),
                    };

                    // Final check to avoid dupes within the search results themselves (unlikely with pagination but distinct IDs possible?)
                    // The set check above handles cross-list dupes.
                    // To handle within-list helper dupes (if any), we could maintain a local set, but pagination shouldn't overlap.

                    new_animes.push(anime);
                }
            }
        }
    }

    // Sort logic handled by caller? User said "Sort by date".
    // The UI currently sorts each group by `broadcast_time`.
    // Since we set `broadcast_time` to `date`, they will be sorted by date in the UI.

    Ok(new_animes)
}
