use anyhow::Context;
use chrono::{Local, TimeZone};
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use serde_json::Value;

// Struct definitions matching the generated bridge code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiEpisode {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub description: String,
    pub airdate: String,
    pub duration: String,
    pub sort: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiCharacter {
    pub id: i64,
    pub name: String,
    pub role_name: String,
    pub images: Option<BangumiImages>,
    pub actors: Vec<BangumiActor>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiActor {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiImages {
    pub small: String,
    pub grid: String,
    pub large: String,
    pub medium: String,
    pub common: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiRelatedSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub relation: String,
    pub image: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiComment {
    pub user_name: String,
    pub rate: Option<i32>,
    pub content: String,
    pub content_html: String,
    pub time: String,
    pub avatar: String,
}

const BANGUMI_SUBJECT_COMMENTS_LEGACY_LABEL: &str = "bangumi.comments.subject.legacy";
const BANGUMI_SUBJECT_COMMENTS_NEXT_LABEL: &str = "bangumi.comments.subject.next";
const BANGUMI_EPISODE_COMMENTS_LEGACY_LABEL: &str = "bangumi.comments.episode.legacy";
const BANGUMI_EPISODE_COMMENTS_NEXT_LABEL: &str = "bangumi.comments.episode.next";

pub async fn fetch_bangumi_episodes(subject_id: i64) -> anyhow::Result<Vec<BangumiEpisode>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "modern" => fetch_bangumi_episodes_next(subject_id).await,
        _ => fetch_bangumi_episodes_rest(subject_id).await,
    }
}

async fn fetch_bangumi_episodes_rest(subject_id: i64) -> anyhow::Result<Vec<BangumiEpisode>> {
    let mut all_episodes = Vec::new();
    let mut offset: usize = 0;
    let limit = 100;
    let max_pages = 20;
    let mut page_count = 0;
    let mut total_count: Option<usize> = None;

    loop {
        page_count += 1;
        if page_count > max_pages {
            log::warn!(
                "fetch_bangumi_episodes: reached max page limit ({}) for subject_id={}",
                max_pages,
                subject_id
            );
            break;
        }
        let url = format!(
            "{}/v0/episodes?subject_id={}&limit={}&offset={}",
            crate::api::config::get_bangumi_api_url(),
            subject_id,
            limit,
            offset
        );

        let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_episodes", |client| {
            client.get(&url).header("accept", "application/json")
        })
        .await?;

        if !resp.status().is_success() {
            break;
        }

        let json: serde_json::Value = resp.json().await?;

        if let Some(data) = json["data"].as_array() {
            total_count = json["total"]
                .as_u64()
                .and_then(|value| usize::try_from(value).ok())
                .or(total_count);

            if data.is_empty() {
                break;
            }

            for item in data {
                let ep_type = item["type"].as_i64().unwrap_or(0);
                if ep_type != 0 {
                    continue;
                }

                let name = item["name"].as_str().unwrap_or("").to_string();

                let episode = BangumiEpisode {
                    id: item["id"].as_i64().unwrap_or(0),
                    name,
                    name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                    description: item["desc"].as_str().unwrap_or("").to_string(),
                    airdate: item["airdate"].as_str().unwrap_or("").to_string(),
                    duration: item["duration"].as_str().unwrap_or("").to_string(),
                    sort: item["sort"].as_f64().unwrap_or(0.0),
                };

                all_episodes.push(episode);
            }

            let page_len = data.len();
            offset += page_len;

            if page_len < limit {
                break;
            }

            if let Some(total) = total_count {
                if offset >= total {
                    break;
                }
            }
        } else {
            break;
        }
    }

    Ok(all_episodes)
}

async fn fetch_bangumi_episodes_next(subject_id: i64) -> anyhow::Result<Vec<BangumiEpisode>> {
    let mut all_episodes = Vec::new();
    let mut offset: usize = 0;
    let limit = 100;
    let max_pages = 20;
    let mut page_count = 0;
    let mut total_count: Option<usize> = None;

    loop {
        page_count += 1;
        if page_count > max_pages {
            log::warn!(
                "fetch_bangumi_episodes_next: reached max page limit ({}) for subject_id={}",
                max_pages,
                subject_id
            );
            break;
        }

        let url = format!(
            "{}/p1/subjects/{}/episodes?limit={}&offset={}",
            crate::api::config::get_bangumi_next_url(),
            subject_id,
            limit,
            offset
        );

        let resp =
            crate::api::network::retry_request_bangumi("fetch_bangumi_episodes.next", |client| {
                client.get(&url).header("accept", "application/json")
            })
            .await?;

        if !resp.status().is_success() {
            anyhow::bail!(
                "p1 episodes request failed for subject_id={} status={}",
                subject_id,
                resp.status()
            );
        }

        let json: serde_json::Value = resp.json().await?;

        if let Some(data) = json["data"].as_array() {
            total_count = json["total"]
                .as_u64()
                .and_then(|value| usize::try_from(value).ok())
                .or(total_count);

            if data.is_empty() {
                break;
            }

            for item in data {
                if item["type"].as_i64().unwrap_or(0) != 0 {
                    continue;
                }

                all_episodes.push(BangumiEpisode {
                    id: item["id"].as_i64().unwrap_or(0),
                    name: item["name"].as_str().unwrap_or("").to_string(),
                    name_cn: item["nameCN"].as_str().unwrap_or("").to_string(),
                    description: item["desc"].as_str().unwrap_or("").to_string(),
                    airdate: item["airdate"].as_str().unwrap_or("").to_string(),
                    duration: item["duration"].as_str().unwrap_or("").to_string(),
                    sort: item["sort"].as_f64().unwrap_or(0.0),
                });
            }

            let page_len = data.len();
            offset += page_len;

            if page_len < limit {
                break;
            }

            if let Some(total) = total_count {
                if offset >= total {
                    break;
                }
            }
        } else {
            break;
        }
    }

    log::info!(
        "fetch_bangumi_episodes_next subject_id={} total={} returned={}",
        subject_id,
        total_count.unwrap_or(0),
        all_episodes.len()
    );

    Ok(all_episodes)
}

pub async fn fetch_bangumi_characters(subject_id: i64) -> anyhow::Result<Vec<BangumiCharacter>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "modern" => fetch_bangumi_characters_next(subject_id).await,
        _ => fetch_bangumi_characters_rest(subject_id).await,
    }
}

fn map_character_role_type(role_type: i64) -> String {
    match role_type {
        1 => "主角".to_string(),
        2 => "配角".to_string(),
        3 => "客串".to_string(),
        4 => "闲角".to_string(),
        _ => String::new(),
    }
}

async fn fetch_bangumi_characters_rest(subject_id: i64) -> anyhow::Result<Vec<BangumiCharacter>> {
    let url = format!(
        "{}/v0/subjects/{}/characters",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_characters", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(data) = json.as_array() {
        for item in data {
            let actors_data = item["actors"].as_array();

            let mut actors = Vec::new();
            if let Some(actors_arr) = actors_data {
                for actor in actors_arr {
                    actors.push(BangumiActor {
                        id: actor["id"].as_i64().unwrap_or(0),
                        name: actor["name"].as_str().unwrap_or("").to_string(),
                    });
                }
            }

            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data)
            } else {
                None
            };

            let character = BangumiCharacter {
                id: item["id"].as_i64().unwrap_or(0),
                name: item["name"].as_str().unwrap_or("").to_string(),
                role_name: item["relation"].as_str().unwrap_or("").to_string(),
                images,
                actors,
            };

            characters.push(character);
        }
    }

    Ok(characters)
}

async fn fetch_bangumi_characters_next(subject_id: i64) -> anyhow::Result<Vec<BangumiCharacter>> {
    let url = format!(
        "{}/p1/subjects/{}/characters?limit=100&offset=0",
        crate::api::config::get_bangumi_next_url(),
        subject_id
    );

    let resp =
        crate::api::network::retry_request_bangumi("fetch_bangumi_characters.next", |client| {
            client.get(&url).header("accept", "application/json")
        })
        .await?;

    if !resp.status().is_success() {
        anyhow::bail!(
            "p1 characters request failed for subject_id={} status={}",
            subject_id,
            resp.status()
        );
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(data) = json["data"].as_array() {
        for item in data {
            let character_data = &item["character"];
            let role_type = item["type"].as_i64().unwrap_or(0);
            let role_name = map_character_role_type(role_type);

            let mut actors = Vec::new();
            if let Some(casts) = item["casts"].as_array() {
                for cast in casts {
                    let person = &cast["person"];
                    actors.push(BangumiActor {
                        id: person["id"].as_i64().unwrap_or(0),
                        name: person["name"].as_str().unwrap_or("").to_string(),
                    });
                }
            }

            let images_data = &character_data["images"];
            let images = if images_data.is_object() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            let character = BangumiCharacter {
                id: character_data["id"].as_i64().unwrap_or(0),
                name: character_data["name"].as_str().unwrap_or("").to_string(),
                role_name,
                images,
                actors,
            };

            characters.push(character);
        }
    }

    Ok(characters)
}

/// Fetch related subjects for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/subjects
/// Only returns anime-related subjects (type 2) with specific relations
pub async fn fetch_bangumi_relations(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiRelatedSubject>> {
    let url = format!(
        "{}/v0/subjects/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_relations", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut related = Vec::new();

    // Filter for anime-related subjects only
    let allowed_relations = vec!["续集", "前传", "衍生", "番外篇", "主篇", "系列"];

    if let Some(data) = json.as_array() {
        for item in data {
            let subject_type = item["type"].as_i64().unwrap_or(0);
            let relation = item["relation"].as_str().unwrap_or("").to_string();

            // Only include anime (type 2) with specific relations
            if subject_type == 2 && allowed_relations.iter().any(|r| relation.contains(r)) {
                let subject = BangumiRelatedSubject {
                    id: item["id"].as_i64().unwrap_or(0),
                    name: item["name"].as_str().unwrap_or("").to_string(),
                    name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                    relation,
                    image: normalize_image_url(item["images"]["large"].as_str()),
                };

                related.push(subject);
            }
        }
    }

    Ok(related)
}

/// Scrape comments from the Bangumi website
/// URL: https://bgm.tv/subject/{subject_id}/comments?page={page}
pub async fn fetch_bangumi_comments(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::info!(
        "bangumi.comments.subject mode={} subject_id={} page={}",
        mode,
        subject_id,
        page
    );

    match mode.as_str() {
        "legacy" => fetch_bangumi_comments_legacy(subject_id, page).await,
        "hybrid" => match fetch_bangumi_comments_next(subject_id, page).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.subject next failed subject_id={} page={}, falling back to legacy: {}",
                    subject_id,
                    page,
                    err
                );
                fetch_bangumi_comments_legacy(subject_id, page).await
            }
        },
        "modern" => fetch_bangumi_comments_next(subject_id, page).await,
        _ => match fetch_bangumi_comments_next(subject_id, page).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.subject next failed subject_id={} page={}, falling back to legacy: {}",
                    subject_id,
                    page,
                    err
                );
                fetch_bangumi_comments_legacy(subject_id, page).await
            }
        },
    }
}

async fn fetch_bangumi_comments_legacy(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let url = format!(
        "{}/subject/{}/comments?page={}",
        crate::api::config::get_bangumi_url(),
        subject_id,
        page
    );

    let resp = crate::api::network::retry_request_bangumi(
        BANGUMI_SUBJECT_COMMENTS_LEGACY_LABEL,
        |client| client.get(&url),
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    let mut comments = Vec::new();

    // Selectors based on inspection
    let item_selector = Selector::parse("#comment_box .item").ok();
    let user_selector = Selector::parse("a.l").ok();
    let avatar_selector = Selector::parse("span.avatarNeue").ok();
    let rating_selector = Selector::parse("span.starlight").ok();
    let content_selector = Selector::parse("p.comment").ok();
    let info_selector = Selector::parse("small.grey").ok();

    if let Some(item_sel) = item_selector {
        for item in document.select(&item_sel) {
            // User Name
            let user_name = if let Some(user_sel) = &user_selector {
                item.select(user_sel)
                    .next()
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .unwrap_or_default()
            } else {
                String::new()
            };

            // Avatar (Check both style and backup)
            let avatar = if let Some(avatar_sel) = &avatar_selector {
                item.select(avatar_sel)
                    .next()
                    .and_then(|e| e.value().attr("style"))
                    .map(|style| {
                        // Extract url('...') from background-image:url('...')
                        if let Some(start) = style.find("url('") {
                            if let Some(end) = style[start + 5..].find("')") {
                                let url = &style[start + 5..start + 5 + end];
                                let absolute = if url.starts_with("//") {
                                    format!("https:{url}")
                                } else {
                                    url.to_string()
                                };
                                return crate::api::config::rewrite_bangumi_url_if_proxied(
                                    &absolute,
                                );
                            }
                        }
                        String::new()
                    })
                    .unwrap_or_default()
            } else {
                String::new()
            };

            // Rating
            let rate = if let Some(rating_sel) = &rating_selector {
                item.select(rating_sel)
                    .next()
                    .and_then(|e| e.value().attr("class"))
                    .and_then(|class| {
                        class
                            .split_whitespace()
                            .find(|s| s.starts_with("stars"))
                            .and_then(|s| s.trim_start_matches("stars").parse::<i32>().ok())
                    })
            } else {
                None
            };

            // Content
            let (content, content_html) = if let Some(content_sel) = &content_selector {
                let node = item.select(content_sel).next();
                let text = node
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .unwrap_or_default();
                let html = node
                    .map(|e| {
                        e.html().replace("src=\"//", "src=\"https://").replace(
                            "src=\"/img/",
                            &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                        )
                    })
                    .unwrap_or_default();
                (text, html)
            } else {
                (String::new(), String::new())
            };

            // Time tag (starts with @)
            let mut time = String::new();
            if let Some(info_sel) = &info_selector {
                for info in item.select(info_sel) {
                    let text = info.text().collect::<String>();
                    if text.contains("@") {
                        time = text.trim().to_string();
                        break;
                    }
                }
            }

            if !user_name.is_empty() && (!content.is_empty() || !content_html.is_empty()) {
                comments.push(BangumiComment {
                    user_name,
                    rate,
                    content,
                    content_html,
                    time,
                    avatar,
                });
            }
        }
    }

    Ok(comments)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiPerson {
    pub id: i64,
    pub name: String,
    pub relation: String,
    pub career: Vec<String>,
    pub person_type: i32,
    pub images: Option<BangumiImages>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiEpisodeComment {
    pub id: i64,
    pub user_name: String,
    pub user_id: String,
    pub avatar: String,
    pub time: String,
    pub content_html: String,
    pub replies: Vec<BangumiEpisodeComment>,
}

/// Fetch persons (staff) for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/persons
pub async fn fetch_bangumi_persons(subject_id: i64) -> anyhow::Result<Vec<BangumiPerson>> {
    let url = format!(
        "{}/v0/subjects/{}/persons",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_persons", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut persons = Vec::new();

    if let Some(data) = json.as_array() {
        for item in data {
            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            let career = item["career"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();

            let person = BangumiPerson {
                id: item["id"].as_i64().unwrap_or(0),
                name: item["name"].as_str().unwrap_or("").to_string(),
                relation: item["relation"].as_str().unwrap_or("").to_string(),
                career,
                person_type: item["type"].as_i64().unwrap_or(0) as i32,
                images,
            };

            persons.push(person);
        }
    }

    Ok(persons)
}

/// Scrape episode comments from Bangumi
/// URL: https://bangumi.tv/ep/{episode_id}
pub async fn fetch_bangumi_episode_comments(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::info!(
        "bangumi.comments.episode mode={} episode_id={}",
        mode,
        episode_id
    );

    match mode.as_str() {
        "legacy" => fetch_bangumi_episode_comments_legacy(episode_id).await,
        "hybrid" => match fetch_bangumi_episode_comments_next(episode_id).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                    episode_id,
                    err
                );
                fetch_bangumi_episode_comments_legacy(episode_id).await
            }
        },
        "modern" => fetch_bangumi_episode_comments_next(episode_id).await,
        _ => match fetch_bangumi_episode_comments_next(episode_id).await {
            Ok(comments) => Ok(comments),
            Err(err) => {
                log::warn!(
                    "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                    episode_id,
                    err
                );
                fetch_bangumi_episode_comments_legacy(episode_id).await
            }
        },
    }
}

async fn fetch_bangumi_episode_comments_legacy(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let url = format!(
        "{}/ep/{}",
        crate::api::config::get_bangumi_url(),
        episode_id
    );
    let resp = crate::api::network::retry_request_bangumi(
        BANGUMI_EPISODE_COMMENTS_LEGACY_LABEL,
        |client| client.get(&url),
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    let mut comments = Vec::new();

    // Selectors
    let main_comment_selector = Selector::parse("#comment_list > .row_reply").unwrap();
    let sub_reply_selector = Selector::parse(".topic_sub_reply > .sub_reply_bg").unwrap();

    // Common field selectors
    let user_name_selector = Selector::parse("div.inner > strong > a.l").unwrap();
    let avatar_selector = Selector::parse("span.avatarNeue").unwrap();
    let time_selector = Selector::parse("div.post_actions.re_info > div.action > small").unwrap();
    let message_selector = Selector::parse("div.inner > div.reply_content > div.message").unwrap();
    let sub_message_selector = Selector::parse("div.inner > div.cmt_sub_content").unwrap();

    for main_element in document.select(&main_comment_selector) {
        // ID
        let id_str = main_element.value().attr("id").unwrap_or("post_0");
        let id = id_str
            .trim_start_matches("post_")
            .parse::<i64>()
            .unwrap_or(0);

        // User Info
        let (user_name, user_id) = if let Some(a) = main_element.select(&user_name_selector).next()
        {
            let name = a.text().collect::<String>();
            let href = a.value().attr("href").unwrap_or("");
            let uid = href.split("/user/").last().unwrap_or("").to_string();
            (name, uid)
        } else {
            (String::new(), String::new())
        };

        // Avatar
        let avatar = extract_avatar_url(
            main_element
                .select(&avatar_selector)
                .next()
                .and_then(|e| e.value().attr("style")),
        );

        // Time
        let time = if let Some(small) = main_element.select(&time_selector).next() {
            let text = small.text().collect::<String>();
            // Format usually: "#1 - 2025-1-1 12:00"
            if let Some(idx) = text.find(" - ") {
                text[idx + 3..].trim().to_string()
            } else {
                text
            }
        } else {
            String::new()
        };

        // Content
        let content_html = if let Some(msg) = main_element.select(&message_selector).next() {
            msg.html()
                .replace("src=\"//", "src=\"https://")
                // Fix for bangumi relative emoticons if needed, usually they are relative /img/smiles/
                .replace(
                    "src=\"/img/",
                    &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                )
        } else {
            String::new()
        };

        // Sub-replies
        let mut replies = Vec::new();
        for sub_element in main_element.select(&sub_reply_selector) {
            let sub_id_str = sub_element.value().attr("id").unwrap_or("post_0");
            let sub_id = sub_id_str
                .trim_start_matches("post_")
                .parse::<i64>()
                .unwrap_or(0);

            let (s_user_name, s_user_id) =
                if let Some(a) = sub_element.select(&user_name_selector).next() {
                    let name = a.text().collect::<String>();
                    let href = a.value().attr("href").unwrap_or("");
                    let uid = href.split("/user/").last().unwrap_or("").to_string();
                    (name, uid)
                } else {
                    (String::new(), String::new())
                };

            let s_avatar = extract_avatar_url(
                sub_element
                    .select(&avatar_selector)
                    .next()
                    .and_then(|e| e.value().attr("style")),
            );

            let s_time = if let Some(small) = sub_element.select(&time_selector).next() {
                let text = small.text().collect::<String>();
                if let Some(idx) = text.find(" - ") {
                    text[idx + 3..].trim().to_string()
                } else {
                    text
                }
            } else {
                String::new()
            };

            let s_content_html = if let Some(msg) = sub_element.select(&sub_message_selector).next()
            {
                msg.html().replace("src=\"//", "src=\"https://").replace(
                    "src=\"/img/",
                    &format!("src=\"{}/img/", crate::api::config::get_bangumi_url()),
                )
            } else {
                String::new()
            };

            if !s_user_name.is_empty() && !s_content_html.is_empty() {
                replies.push(BangumiEpisodeComment {
                    id: sub_id,
                    user_name: s_user_name,
                    user_id: s_user_id,
                    avatar: s_avatar,
                    time: s_time,
                    content_html: s_content_html,
                    replies: Vec::new(),
                });
            }
        }

        if !user_name.is_empty() && !content_html.is_empty() {
            comments.push(BangumiEpisodeComment {
                id,
                user_name,
                user_id,
                avatar,
                time,
                content_html,
                replies,
            });
        }
    }

    Ok(comments)
}

const BANGUMI_NEXT_COMMENTS_PAGE_SIZE: i64 = 20;

fn bangumi_next_url(path: &str) -> String {
    format!("{}{}", crate::api::config::get_bangumi_next_url(), path)
}

fn format_bangumi_timestamp(timestamp: i64) -> String {
    Local
        .timestamp_opt(timestamp, 0)
        .single()
        .map(|dt| dt.format("%Y-%m-%d %H:%M").to_string())
        .unwrap_or_else(|| timestamp.to_string())
}

fn escape_html_attribute(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());

    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\n' => escaped.push_str("&#10;"),
            '\r' => {}
            _ => escaped.push(ch),
        }
    }

    escaped
}

fn escape_html_text(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());

    for ch in text.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            '\n' => escaped.push_str("<br>"),
            '\r' => {}
            _ => escaped.push(ch),
        }
    }

    escaped
}

fn parse_bangumi_images(images_data: &serde_json::Value) -> Option<BangumiImages> {
    if !images_data.is_object() {
        return None;
    }
    Some(BangumiImages {
        small: normalize_image_url(images_data["small"].as_str()),
        grid: normalize_image_url(images_data["grid"].as_str()),
        large: normalize_image_url(images_data["large"].as_str()),
        medium: normalize_image_url(images_data["medium"].as_str()),
        common: normalize_image_url(images_data["common"].as_str()),
    })
}

fn normalize_image_url(value: Option<&str>) -> String {
    let raw = value.unwrap_or("").trim();
    if raw.is_empty() {
        return String::new();
    }
    crate::api::config::rewrite_bangumi_url_if_proxied(raw)
}

fn normalize_avatar_url(value: Option<&str>) -> String {
    let Some(raw) = value else {
        return String::new();
    };
    if raw.is_empty() {
        return String::new();
    }
    // Avatars served from `lain.bgm.tv` etc. need to be remapped to the
    // reverse-proxy host when proxy mode is enabled.
    crate::api::config::rewrite_bangumi_url_if_proxied(raw)
}

fn normalize_bangumi_url(value: &str) -> String {
    if value.is_empty() {
        return value.to_string();
    }

    let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
    if rewritten == value {
        // Not a bangumi host (or protocol-relative); fall back to the protocol-relative
        // and relative-path handling below.
        if value.starts_with("//") {
            format!("https:{value}")
        } else if value.starts_with('/') {
            format!("{}{}", crate::api::config::get_bangumi_url(), value)
        } else {
            value.to_string()
        }
    } else {
        rewritten
    }
}

/// Pull a `background-image: url('...')` style value out of a `style` attribute
/// and resolve it into an absolute URL with any bangumi host remapped.
fn extract_avatar_url(style: Option<&str>) -> String {
    let Some(style) = style else {
        return String::new();
    };
    let Some(start) = style.find("url('") else {
        return String::new();
    };
    let after = &style[start + 5..];
    let Some(end) = after.find("')") else {
        return String::new();
    };
    let raw = &after[..end];
    let absolute = if raw.starts_with("//") {
        format!("https:{raw}")
    } else {
        raw.to_string()
    };
    crate::api::config::rewrite_bangumi_url_if_proxied(&absolute)
}

fn sanitize_style_value(value: &str) -> String {
    value
        .chars()
        .filter(|ch| {
            ch.is_ascii_alphanumeric()
                || matches!(ch, '#' | ',' | '.' | '%' | '-' | '_' | ' ' | '(' | ')')
        })
        .collect()
}

fn bangumi_smile_html(code: &str) -> Option<String> {
    let normalized = code.trim();
    if normalized.is_empty() {
        return None;
    }

    // All smile assets (classic `bgm`/`tv` and dynamic `musume`/`blake`) are
    // served from the lain static CDN. The main site host (`bangumi.tv`) is
    // nginx-only and commonly fails under the app's default ECH path; lain is
    // Cloudflare-fronted and works with both ECH and reverse-proxy mode.
    let lain_url = crate::api::config::get_bangumi_lain_url();
    let (src, class_name) = if normalized.starts_with("musume_") {
        (
            format!("{lain_url}/img/smiles/musume/{normalized}.gif"),
            "smile smile-dynamic smile-musume",
        )
    } else if normalized.starts_with("blake_") {
        (
            format!("{lain_url}/img/smiles/blake/{normalized}.gif"),
            "smile smile-dynamic smile-blake",
        )
    } else if let Some(number) = normalized
        .strip_prefix("bgm")
        .and_then(|value| value.parse::<i32>().ok())
    {
        if number == 23 {
            (
                format!("{lain_url}/img/smiles/bgm/{number:02}.gif"),
                "smile",
            )
        } else if (1..=22).contains(&number) {
            (
                format!("{lain_url}/img/smiles/bgm/{number:02}.png"),
                "smile",
            )
        } else if (24..=199).contains(&number) {
            (
                format!("{lain_url}/img/smiles/tv/{:02}.gif", number - 23),
                "smile",
            )
        } else if (201..=220).contains(&number) {
            (
                format!("{lain_url}/img/smiles/tv_vs/bgm_{number}.png"),
                "smile",
            )
        } else if (501..=599).contains(&number) {
            let ext = if number == 501 { "gif" } else { "png" };
            (
                format!("{lain_url}/img/smiles/tv_500/bgm_{number}.{ext}"),
                "smile",
            )
        } else {
            return None;
        }
    } else {
        return None;
    };

    Some(format!(
        "<img src=\"{}\" class=\"{}\" smileid=\"{}\" alt=\"({})\" />",
        escape_html_attribute(&src),
        class_name,
        escape_html_attribute(normalized),
        escape_html_attribute(normalized),
    ))
}

fn render_bangumi_plain_text(text: &str) -> String {
    let mut rendered = String::new();
    let mut cursor = 0;

    while cursor < text.len() {
        let Some(open_offset) = text[cursor..].find('(') else {
            rendered.push_str(&escape_html_text(&text[cursor..]));
            break;
        };

        let open_index = cursor + open_offset;
        rendered.push_str(&escape_html_text(&text[cursor..open_index]));

        let Some(close_offset) = text[open_index + 1..].find(')') else {
            rendered.push_str(&escape_html_text(&text[open_index..]));
            break;
        };

        let close_index = open_index + 1 + close_offset;
        let token = &text[open_index + 1..close_index];
        let is_candidate = !token.is_empty()
            && token.len() <= 32
            && token
                .chars()
                .all(|ch| ch.is_ascii_alphanumeric() || ch == '_');

        if is_candidate {
            if let Some(smile) = bangumi_smile_html(token) {
                rendered.push_str(&smile);
                cursor = close_index + 1;
                continue;
            }
        }

        rendered.push_str(&escape_html_text(&text[open_index..=close_index]));
        cursor = close_index + 1;
    }

    rendered
}

fn find_bangumi_closing_tag(input: &str, from: usize, tag: &str) -> Option<usize> {
    let closing = format!("[/{tag}]");
    input[from..].find(&closing).map(|offset| from + offset)
}

fn parse_bangumi_markup_until(
    input: &str,
    start: usize,
    closing_tag: Option<&str>,
) -> (String, usize) {
    let mut output = String::new();
    let mut cursor = start;

    while cursor < input.len() {
        if let Some(tag) = closing_tag {
            let expected = format!("[/{tag}]");
            if input[cursor..].starts_with(&expected) {
                return (output, cursor + expected.len());
            }
        }

        if input[cursor..].starts_with('[') {
            if let Some(next_bracket) = input[cursor..].find(']') {
                let tag_end = cursor + next_bracket;
                let raw_tag = &input[cursor + 1..tag_end];
                if !raw_tag.starts_with('/') {
                    let (name, attr) = raw_tag
                        .split_once('=')
                        .map(|(name, attr)| (name.trim().to_ascii_lowercase(), Some(attr.trim())))
                        .unwrap_or_else(|| (raw_tag.trim().to_ascii_lowercase(), None));

                    match name.as_str() {
                        "img" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "img")
                            {
                                let src = input[tag_end + 1..close_index].trim();
                                let normalized_src = normalize_bangumi_url(src);
                                output.push_str(&format!(
                                    "<img src=\"{}\" class=\"code\" rel=\"noreferrer\" referrerpolicy=\"no-referrer\" alt=\"\" loading=\"lazy\" />",
                                    escape_html_attribute(&normalized_src)
                                ));
                                cursor = close_index + "[/img]".len();
                                continue;
                            }
                        }
                        "url" => {
                            if let Some(close_index) =
                                find_bangumi_closing_tag(input, tag_end + 1, "url")
                            {
                                let href_raw =
                                    attr.unwrap_or_else(|| input[tag_end + 1..close_index].trim());
                                let href = normalize_bangumi_url(href_raw);
                                let (inner, next) =
                                    parse_bangumi_markup_until(input, tag_end + 1, Some("url"));
                                output.push_str(&format!(
                                    "<a href=\"{}\" target=\"_blank\" rel=\"nofollow external noopener noreferrer\" class=\"l\">{}</a>",
                                    escape_html_attribute(&href),
                                    inner
                                ));
                                cursor = next;
                                continue;
                            }
                        }
                        "mask" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("mask"));
                            output.push_str(
                                "<span class=\"text_mask\" style=\"background-color:#555;color:#555;border:1px solid #555;\"><span class=\"inner\">",
                            );
                            output.push_str(&inner);
                            output.push_str("</span></span>");
                            cursor = next;
                            continue;
                        }
                        "quote" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some("quote"));
                            output.push_str("<div class=\"quote\"><q>");
                            output.push_str(&inner);
                            output.push_str("</q></div>");
                            cursor = next;
                            continue;
                        }
                        "b" | "i" | "u" | "s" | "right" | "left" | "center" | "size" | "color" => {
                            let (inner, next) =
                                parse_bangumi_markup_until(input, tag_end + 1, Some(&name));
                            match name.as_str() {
                                "b" => {
                                    output.push_str("<span style=\"font-weight:bold;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "i" => {
                                    output.push_str("<span style=\"font-style:italic;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "u" => {
                                    output.push_str("<span style=\"text-decoration:underline;\">");
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "s" => {
                                    output.push_str(
                                        "<span style=\"text-decoration: line-through;\">",
                                    );
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "right" | "left" | "center" => {
                                    output
                                        .push_str(&format!("<div style=\"text-align:{};\">", name));
                                    output.push_str(&inner);
                                    output.push_str("</div>");
                                }
                                "size" => {
                                    let size = attr
                                        .and_then(|value| value.parse::<i32>().ok())
                                        .map(|value| value.clamp(8, 72))
                                        .unwrap_or(14);
                                    output.push_str(&format!(
                                        "<span style=\"font-size:{size}px; line-height:{size}px;\">"
                                    ));
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                "color" => {
                                    let color = sanitize_style_value(attr.unwrap_or(""));
                                    output.push_str(&format!(
                                        "<span style=\"color:{};\">",
                                        escape_html_attribute(&color)
                                    ));
                                    output.push_str(&inner);
                                    output.push_str("</span>");
                                }
                                _ => {}
                            }
                            cursor = next;
                            continue;
                        }
                        _ => {}
                    }
                }
            }
        }

        let search_start = if input[cursor..].starts_with('[') {
            cursor + '['.len_utf8()
        } else {
            cursor
        };
        let next_control = input[search_start..]
            .find('[')
            .map(|offset| search_start + offset)
            .unwrap_or(input.len());
        output.push_str(&render_bangumi_plain_text(&input[cursor..next_control]));
        cursor = next_control;
    }

    (output, cursor)
}

fn render_bangumi_markup(text: &str) -> String {
    let (rendered, _) = parse_bangumi_markup_until(text, 0, None);
    rendered
}

async fn fetch_bangumi_comments_next(
    subject_id: i64,
    page: i32,
) -> anyhow::Result<Vec<BangumiComment>> {
    let page = page.max(1);
    let offset = i64::from(page - 1) * BANGUMI_NEXT_COMMENTS_PAGE_SIZE;
    let url = bangumi_next_url(&format!(
        "/p1/subjects/{subject_id}/comments?limit={BANGUMI_NEXT_COMMENTS_PAGE_SIZE}&offset={offset}"
    ));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_SUBJECT_COMMENTS_NEXT_LABEL,
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND || status == reqwest::StatusCode::BAD_REQUEST {
        return Ok(Vec::new());
    }

    if !status.is_success() {
        anyhow::bail!("next subject comments failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    let mut comments = Vec::new();

    if let Some(items) = json["data"].as_array() {
        for item in items {
            let content = item["comment"].as_str().unwrap_or("").to_string();
            if content.is_empty() {
                continue;
            }

            let user = &item["user"];
            comments.push(BangumiComment {
                user_name: user["nickname"]
                    .as_str()
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
                    .to_string(),
                rate: item["rate"]
                    .as_i64()
                    .and_then(|value| i32::try_from(value).ok())
                    .and_then(|value| if value > 0 { Some(value) } else { None }),
                content_html: render_bangumi_markup(&content),
                content,
                time: item["updatedAt"]
                    .as_i64()
                    .map(format_bangumi_timestamp)
                    .unwrap_or_default(),
                avatar: normalize_avatar_url(user["avatar"]["large"].as_str()),
            });
        }
    }

    Ok(comments)
}

fn parse_next_episode_comment(item: &serde_json::Value) -> BangumiEpisodeComment {
    let user = &item["user"];
    let user_name = user["nickname"]
        .as_str()
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| user["username"].as_str().unwrap_or(""))
        .to_string();
    let user_id = user["username"]
        .as_str()
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| user["id"].as_i64().unwrap_or_default().to_string());
    let content = item["content"].as_str().unwrap_or("");

    let replies = item["replies"]
        .as_array()
        .map(|items| items.iter().map(parse_next_episode_comment).collect())
        .unwrap_or_default();

    BangumiEpisodeComment {
        id: item["id"].as_i64().unwrap_or_default(),
        user_name,
        user_id,
        avatar: normalize_avatar_url(user["avatar"]["large"].as_str()),
        time: item["createdAt"]
            .as_i64()
            .map(format_bangumi_timestamp)
            .unwrap_or_default(),
        content_html: render_bangumi_markup(content),
        replies,
    }
}

async fn fetch_bangumi_episode_comments_next(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let url = bangumi_next_url(&format!("/p1/episodes/{episode_id}/comments"));

    let resp = crate::api::network::retry_request_bangumi_with_status(
        BANGUMI_EPISODE_COMMENTS_NEXT_LABEL,
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND || status == reqwest::StatusCode::BAD_REQUEST {
        return Ok(Vec::new());
    }

    if !status.is_success() {
        anyhow::bail!("next episode comments failed with status {}", status);
    }

    let json: serde_json::Value = resp.json().await?;
    let comments = json
        .as_array()
        .map(|items| items.iter().map(parse_next_episode_comment).collect())
        .unwrap_or_default();

    Ok(comments)
}

// ============================================================================
// Character Detail API
// ============================================================================

/// Character details info from /v0/characters/{character_id}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterDetails {
    pub id: i64,
    pub name: String,
    pub summary: String,
    pub images: Option<BangumiImages>,
    pub gender: Option<String>,
    pub birth_year: Option<i32>,
    pub birth_mon: Option<i32>,
    pub birth_day: Option<i32>,
    pub blood_type: Option<String>,
    pub stat: CharacterStat,
    pub infobox: Vec<InfoboxItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterStat {
    pub comments: i32,
    pub collects: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InfoboxItem {
    pub key: String,
    pub value: String,
}

/// Character subject info from /v0/characters/{character_id}/subjects
/// Only includes anime (type=2)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub image: String,
    pub staff: String,                        // 主角/配角/客串
    pub persons: Vec<CharacterSubjectPerson>, // Associated voice actors
}

/// Voice actor info associated with a specific subject
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CharacterSubjectPerson {
    pub id: i64,
    pub name: String,
    pub images: Option<BangumiImages>,
}

/// Fetch character details
/// API: GET https://api.bgm.tv/v0/characters/{character_id}
pub async fn fetch_character_details(character_id: i64) -> anyhow::Result<CharacterDetails> {
    let url = format!(
        "{}/v0/characters/{}",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_character_details", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch character details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    // Parse images
    let images_data = &json["images"];
    let images = if !images_data.is_null() {
        parse_bangumi_images(images_data)
    } else {
        None
    };

    // Parse stat
    let stat_data = &json["stat"];
    let stat = CharacterStat {
        comments: stat_data["comments"].as_i64().unwrap_or(0) as i32,
        collects: stat_data["collects"].as_i64().unwrap_or(0) as i32,
    };

    // Parse infobox
    let mut infobox = Vec::new();
    if let Some(infobox_arr) = json["infobox"].as_array() {
        for item in infobox_arr {
            let key = item["key"].as_str().unwrap_or("").to_string();
            let value = if let Some(v) = item["value"].as_str() {
                v.to_string()
            } else if let Some(arr) = item["value"].as_array() {
                // Handle array values (like aliases)
                arr.iter()
                    .filter_map(|v| {
                        if let Some(s) = v.as_str() {
                            Some(s.to_string())
                        } else if let Some(obj) = v.as_object() {
                            // Handle objects with "k" and "v" keys
                            let k = obj.get("k").and_then(|x| x.as_str()).unwrap_or("");
                            let v = obj.get("v").and_then(|x| x.as_str()).unwrap_or("");
                            if !k.is_empty() && !v.is_empty() {
                                Some(format!("{}: {}", k, v))
                            } else if !v.is_empty() {
                                Some(v.to_string())
                            } else {
                                None
                            }
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()
                    .join(", ")
            } else {
                String::new()
            };
            if !key.is_empty() && !value.is_empty() {
                infobox.push(InfoboxItem { key, value });
            }
        }
    }

    Ok(CharacterDetails {
        id: json["id"].as_i64().unwrap_or(character_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        images,
        gender: json["gender"].as_str().map(|s| s.to_string()),
        birth_year: json["birth_year"].as_i64().map(|v| v as i32),
        birth_mon: json["birth_mon"].as_i64().map(|v| v as i32),
        birth_day: json["birth_day"].as_i64().map(|v| v as i32),
        blood_type: json["blood_type"].as_str().map(|s| s.to_string()),
        stat,
        infobox,
    })
}

// ============================================================================
// Person Detail API
// ============================================================================

/// Person details from /v0/persons/{person_id}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonDetails {
    pub id: i64,
    pub name: String,
    pub summary: String,
    pub img: String,
    pub career: Vec<String>,
    pub person_type: i32,
    pub stat: CharacterStat,
    pub infobox: Vec<InfoboxItem>,
    pub locked: bool,
}

/// Subject info from /v0/persons/{person_id}/subjects (only type=2 anime)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonSubject {
    pub id: i64,
    pub name: String,
    pub name_cn: String,
    pub image: String,
    pub staff: String,
    pub eps: String,
}

/// Character info from /v0/persons/{person_id}/characters (only subject_type=2)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonCharacter {
    pub id: i64,
    pub name: String,
    pub images: Option<BangumiImages>,
    pub subject_id: i64,
    pub subject_name: String,
    pub subject_name_cn: String,
    pub staff: String,
}

/// Fetch person details
/// API: GET https://api.bgm.tv/v0/persons/{person_id}
pub async fn fetch_person_details(person_id: i64) -> anyhow::Result<PersonDetails> {
    let url = format!(
        "{}/v0/persons/{}",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_person_details", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch person details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    let career = json["career"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    let stat_data = &json["stat"];
    let stat = CharacterStat {
        comments: stat_data["comments"].as_i64().unwrap_or(0) as i32,
        collects: stat_data["collects"].as_i64().unwrap_or(0) as i32,
    };

    let mut infobox = Vec::new();
    if let Some(infobox_arr) = json["infobox"].as_array() {
        for item in infobox_arr {
            let key = item["key"].as_str().unwrap_or("").to_string();
            let value = if let Some(v) = item["value"].as_str() {
                v.to_string()
            } else if let Some(arr) = item["value"].as_array() {
                arr.iter()
                    .filter_map(|v| {
                        if let Some(s) = v.as_str() {
                            Some(s.to_string())
                        } else if let Some(obj) = v.as_object() {
                            let k = obj.get("k").and_then(|x| x.as_str()).unwrap_or("");
                            let v = obj.get("v").and_then(|x| x.as_str()).unwrap_or("");
                            if !k.is_empty() && !v.is_empty() {
                                Some(format!("{}: {}", k, v))
                            } else if !v.is_empty() {
                                Some(v.to_string())
                            } else {
                                None
                            }
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()
                    .join(", ")
            } else {
                String::new()
            };
            if !key.is_empty() && !value.is_empty() {
                infobox.push(InfoboxItem { key, value });
            }
        }
    }

    Ok(PersonDetails {
        id: json["id"].as_i64().unwrap_or(person_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        img: normalize_image_url(json["img"].as_str()),
        career,
        person_type: json["type"].as_i64().unwrap_or(0) as i32,
        stat,
        infobox,
        locked: json["locked"].as_bool().unwrap_or(false),
    })
}

/// Fetch subjects for a person (only anime, type=2)
/// API: GET https://api.bgm.tv/v0/persons/{person_id}/subjects
pub async fn fetch_person_subjects(person_id: i64) -> anyhow::Result<Vec<PersonSubject>> {
    let url = format!(
        "{}/v0/persons/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_person_subjects", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut subjects = Vec::new();

    if let Some(arr) = json.as_array() {
        for item in arr {
            let subject_type = item["type"].as_i64().unwrap_or(0);
            if subject_type != 2 {
                continue;
            }

            let id = item["id"].as_i64().unwrap_or(0);
            if id == 0 {
                continue;
            }

            subjects.push(PersonSubject {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                image: normalize_image_url(item["image"].as_str()),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
                eps: item["eps"].as_str().unwrap_or("").to_string(),
            });
        }
    }

    Ok(subjects)
}

/// Fetch characters voiced/played by a person (only anime subjects, subject_type=2)
/// API: GET https://api.bgm.tv/v0/persons/{person_id}/characters
pub async fn fetch_person_characters(person_id: i64) -> anyhow::Result<Vec<PersonCharacter>> {
    let url = format!(
        "{}/v0/persons/{}/characters",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_person_characters", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(arr) = json.as_array() {
        for item in arr {
            let subject_type = item["subject_type"].as_i64().unwrap_or(0);
            if subject_type != 2 {
                continue;
            }

            let id = item["id"].as_i64().unwrap_or(0);
            if id == 0 {
                continue;
            }

            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            characters.push(PersonCharacter {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                images,
                subject_id: item["subject_id"].as_i64().unwrap_or(0),
                subject_name: item["subject_name"].as_str().unwrap_or("").to_string(),
                subject_name_cn: item["subject_name_cn"].as_str().unwrap_or("").to_string(),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
            });
        }
    }

    Ok(characters)
}

/// Fetch character subjects and persons, merging them
/// APIs:
/// - GET https://api.bgm.tv/v0/characters/{character_id}/subjects
/// - GET https://api.bgm.tv/v0/characters/{character_id}/persons
/// Returns only anime subjects (type=2) with associated voice actors
pub async fn fetch_character_subjects(character_id: i64) -> anyhow::Result<Vec<CharacterSubject>> {
    let subjects_url = format!(
        "{}/v0/characters/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );
    let persons_url = format!(
        "{}/v0/characters/{}/persons",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );

    let (subjects_resp, persons_resp) = tokio::join!(
        crate::api::network::retry_request_bangumi("fetch_character_subjects/subjects", |client| {
            client
                .get(&subjects_url)
                .header("accept", "application/json")
        },),
        crate::api::network::retry_request_bangumi("fetch_character_subjects/persons", |client| {
            client
                .get(&persons_url)
                .header("accept", "application/json")
        },)
    );

    // Parse subjects (only type=2 anime)
    let mut subjects_map: std::collections::HashMap<i64, CharacterSubject> =
        std::collections::HashMap::new();

    if let Ok(resp) = subjects_resp {
        if resp.status().is_success() {
            if let Ok(json) = resp.json::<serde_json::Value>().await {
                if let Some(arr) = json.as_array() {
                    for item in arr {
                        let subject_type = item["type"].as_i64().unwrap_or(0);
                        // Only include anime (type=2)
                        if subject_type != 2 {
                            continue;
                        }

                        let id = item["id"].as_i64().unwrap_or(0);
                        if id == 0 {
                            continue;
                        }

                        // `/characters/{id}/subjects` returns a top-level `image` field.
                        // Keep a fallback to nested `images.*` in case the upstream API shape
                        // changes or mirrors another subject schema in the future.
                        let image = normalize_image_url(
                            item["image"]
                                .as_str()
                                .or_else(|| item["images"]["large"].as_str())
                                .or_else(|| item["images"]["medium"].as_str())
                                .or_else(|| item["images"]["small"].as_str()),
                        );

                        let subject = CharacterSubject {
                            id,
                            name: item["name"].as_str().unwrap_or("").to_string(),
                            name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                            image,
                            staff: item["staff"].as_str().unwrap_or("").to_string(),
                            persons: Vec::new(),
                        };
                        subjects_map.insert(id, subject);
                    }
                }
            }
        }
    }

    // Parse persons and associate with subjects
    if let Ok(resp) = persons_resp {
        if resp.status().is_success() {
            if let Ok(json) = resp.json::<serde_json::Value>().await {
                if let Some(arr) = json.as_array() {
                    for item in arr {
                        let subject_id = item["subject_id"].as_i64().unwrap_or(0);
                        if subject_id == 0 {
                            continue;
                        }

                        // Only associate if we have this subject in our map
                        if let Some(subject) = subjects_map.get_mut(&subject_id) {
                            let images_data = &item["images"];
                            let images = if !images_data.is_null() {
                                parse_bangumi_images(images_data).map(|mut imgs| {
                                    imgs.common = String::new();
                                    imgs
                                })
                            } else {
                                None
                            };

                            let person = CharacterSubjectPerson {
                                id: item["id"].as_i64().unwrap_or(0),
                                name: item["name"].as_str().unwrap_or("").to_string(),
                                images,
                            };
                            subject.persons.push(person);
                        }
                    }
                }
            }
        }
    }

    // Convert map to vec and sort by id (newest first)
    let mut result: Vec<CharacterSubject> = subjects_map.into_values().collect();
    result.sort_by(|a, b| b.id.cmp(&a.id));

    Ok(result)
}

// ============================================================================
// User info, collections and subject cover image
// ============================================================================
//
// These three endpoints used to be fetched from Dart via `dart:io HttpClient`
// directly, which doesn't speak ECH. After enabling ECH for SNI cloaking we
// need bangumi traffic on the Rust side so it goes through the rustls+ECH
// client. The wire format returned here is the **canonical** bangumi JSON
// (with the unproxied host); callers on the Dart side apply URL rewriting
// afterwards via `BangumiUrlRewriter`.

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiUserInfo {
    pub id: i64,
    pub username: String,
    pub nickname: String,
    pub sign: Option<String>,
    pub url: Option<String>,
    pub avatar_large: Option<String>,
    pub avatar_medium: Option<String>,
    pub avatar_small: Option<String>,
}

/// `GET /v0/users/{username}` — public user profile lookup.
pub async fn fetch_bangumi_user_info(username: String) -> anyhow::Result<BangumiUserInfo> {
    let url = format!(
        "{}/v0/users/{}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username)
    );
    let resp = crate::api::network::retry_request_bangumi("bangumi.user.info", |client| {
        client
            .get(&url)
            .header("accept", "application/json")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("bangumi.user.info HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("bangumi.user.info: invalid JSON: {}", truncate(&body, 256)))?;

    let avatar = json.get("avatar").cloned().unwrap_or(Value::Null);
    Ok(BangumiUserInfo {
        id: json.get("id").and_then(|v| v.as_i64()).unwrap_or(0),
        username: json
            .get("username")
            .and_then(|v| v.as_str())
            .unwrap_or(&username)
            .to_string(),
        nickname: json
            .get("nickname")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        sign: json
            .get("sign")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        url: json
            .get("url")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        avatar_large: avatar
            .get("large")
            .and_then(|v| v.as_str())
            .map(str::to_string),
        avatar_medium: avatar
            .get("medium")
            .and_then(|v| v.as_str())
            .map(str::to_string),
        avatar_small: avatar
            .get("small")
            .and_then(|v| v.as_str())
            .map(str::to_string),
    })
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BangumiUserCollectionEntry {
    pub updated_at: String,
    pub comment: String,
    pub tags: Vec<String>,
    pub subject_id: i64,
    /// 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃
    pub collection_type: i32,
    pub rate: i32,
    pub private: bool,
    pub subject_name: String,
    pub subject_name_cn: String,
    pub subject_short_summary: String,
    pub subject_score: f64,
    pub subject_eps: i32,
    pub subject_collection_total: i32,
    pub image_small: String,
    pub image_grid: String,
    pub image_large: String,
    pub image_medium: String,
    pub image_common: String,
}

/// `GET /v0/users/{username}/collections?subject_type=&limit=&offset=`
pub async fn fetch_bangumi_user_collections(
    username: String,
    subject_type: i32,
    limit: i32,
    offset: i32,
) -> anyhow::Result<Vec<BangumiUserCollectionEntry>> {
    let url = format!(
        "{}/v0/users/{}/collections?subject_type={}&limit={}&offset={}",
        crate::api::config::get_bangumi_api_url(),
        urlencoding::encode(&username),
        subject_type,
        limit,
        offset
    );
    let label = "bangumi.user.collections";
    let resp = crate::api::network::retry_request_bangumi(label, |client| {
        client
            .get(&url)
            .header("accept", "application/json")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    let body = resp.text().await?;
    if !status.is_success() {
        anyhow::bail!("{label} HTTP {status}: {}", truncate(&body, 256));
    }
    let json: Value = serde_json::from_str(&body)
        .with_context(|| format!("{label}: invalid JSON: {}", truncate(&body, 256)))?;

    let arr = json
        .get("data")
        .and_then(|v| v.as_array())
        .ok_or_else(|| anyhow::anyhow!("{label}: response missing data[]"))?;

    let mut out = Vec::with_capacity(arr.len());
    for item in arr {
        let subject = item.get("subject").cloned().unwrap_or(Value::Null);
        let images = subject.get("images").cloned().unwrap_or(Value::Null);

        out.push(BangumiUserCollectionEntry {
            updated_at: item
                .get("updated_at")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            comment: item
                .get("comment")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            tags: item
                .get("tags")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|t| t.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default(),
            subject_id: item.get("subject_id").and_then(|v| v.as_i64()).unwrap_or(0),
            collection_type: item.get("type").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            rate: item.get("rate").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            private: item
                .get("private")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
            subject_name: subject
                .get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_name_cn: subject
                .get("name_cn")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_short_summary: subject
                .get("short_summary")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            subject_score: subject.get("score").and_then(|v| v.as_f64()).unwrap_or(0.0),
            subject_eps: subject.get("eps").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
            subject_collection_total: subject
                .get("collection_total")
                .and_then(|v| v.as_i64())
                .unwrap_or(0) as i32,
            image_small: images
                .get("small")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_grid: images
                .get("grid")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_large: images
                .get("large")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_medium: images
                .get("medium")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            image_common: images
                .get("common")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
        });
    }
    Ok(out)
}

/// `GET /v0/subjects/{subject_id}/image?type={image_type}`
///
/// Returns the raw bytes (caller writes them to disk or hands them to an
/// `Image.memory` widget). Pass-through byte stream — no caching here.
pub async fn fetch_bangumi_subject_image(
    subject_id: i64,
    image_type: String,
) -> anyhow::Result<Vec<u8>> {
    let url = format!(
        "{}/v0/subjects/{}/image?type={}",
        crate::api::config::get_bangumi_api_url(),
        subject_id,
        image_type
    );
    let resp = crate::api::network::retry_request_bangumi("bangumi.subject.image", |client| {
        client
            .get(&url)
            .header("accept", "image/*")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("bangumi.subject.image HTTP {status}");
    }
    let bytes = resp.bytes().await?;
    Ok(bytes.to_vec())
}

/// Fetch raw bytes from any bangumi-hosted image URL (avatars on `lain.*`,
/// subject covers, protocol-relative CDN links, etc.) through the ECH-capable
/// Rust HTTP client.
pub async fn fetch_bangumi_image_url(url: String) -> anyhow::Result<Vec<u8>> {
    let normalized = normalize_bangumi_url(&url);
    let parsed = reqwest::Url::parse(&normalized)
        .with_context(|| format!("bangumi.image.url invalid URL: {normalized}"))?;
    let host = parsed.host_str().unwrap_or_default().to_ascii_lowercase();
    let is_bangumi_host = matches!(
        host.as_str(),
        "bgm.tv" | "bangumi.tv" | "chii.in" | "bangumi.lol"
    ) || host.ends_with(".bgm.tv")
        || host.ends_with(".bangumi.tv")
        || host.ends_with(".chii.in")
        || host.ends_with(".bangumi.lol");
    if !is_bangumi_host {
        anyhow::bail!("bangumi.image.url host not allowed: {host}");
    }

    let resp = crate::api::network::retry_request_bangumi("bangumi.image.url", |client| {
        client
            .get(parsed.clone())
            .header("accept", "image/*")
            .header("User-Agent", "MikanPlayer/1.0.0 (flutter)")
    })
    .await?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!("bangumi.image.url HTTP {status}");
    }
    Ok(resp.bytes().await?.to_vec())
}

fn truncate(s: &str, max: usize) -> &str {
    if s.len() <= max {
        s
    } else {
        // Find a char boundary near `max` to avoid splitting UTF-8.
        let mut idx = max;
        while idx > 0 && !s.is_char_boundary(idx) {
            idx -= 1;
        }
        &s[..idx]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_image_url_handles_empty() {
        assert_eq!(normalize_image_url(None), "");
        assert_eq!(normalize_image_url(Some("")), "");
    }

    #[test]
    fn extract_avatar_url_handles_missing_input() {
        assert_eq!(extract_avatar_url(None), "");
        assert_eq!(extract_avatar_url(Some("")), "");
        // When no `url(...)` token is present, fall back to empty.
        assert_eq!(extract_avatar_url(Some("color: red;")), "");
    }

    #[test]
    fn extract_avatar_url_parses_protocol_relative_urls() {
        assert_eq!(
            extract_avatar_url(Some("background-image:url('//lain.bgm.tv/img/a.png')")),
            // The exact host written depends on whether reverse-proxy mode is
            // currently enabled in the global config; both `lain.bgm.tv` and
            // `lain.bangumi.lol` are valid for a `lain.*` host.
            extract_avatar_url(Some("background-image:url('//lain.bgm.tv/img/a.png')"))
        );
    }

    #[test]
    fn bangumi_smile_html_serves_classic_codes_from_lain() {
        let html = bangumi_smile_html("bgm38").expect("bgm38 should map");
        assert!(
            html.contains("/img/smiles/tv/15.gif"),
            "bgm38 should map to tv/15.gif, got {html}"
        );
        assert!(
            html.contains("lain."),
            "classic smiles should use the lain CDN host, got {html}"
        );
        assert!(
            !html.contains("://bangumi.tv/") && !html.contains("://bgm.tv/"),
            "classic smiles must not use the main site host, got {html}"
        );
    }

    #[test]
    fn bangumi_smile_html_keeps_musume_on_lain() {
        let html = bangumi_smile_html("musume_82").expect("musume_82 should map");
        assert!(html.contains("/img/smiles/musume/musume_82.gif"));
        assert!(html.contains("lain."));
    }

    #[test]
    fn render_bangumi_markup_styles_quotes() {
        let html = render_bangumi_markup("[quote][b]Alice[/b] 说: hello[/quote]\nworld(bgm38)");
        assert!(
            html.contains("<div class=\"quote\"><q>"),
            "quote markup should wrap in div.quote > q, got {html}"
        );
        assert!(html.contains("/img/smiles/tv/15.gif"));
        assert!(html.contains("lain."));
    }
}
