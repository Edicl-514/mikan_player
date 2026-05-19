use chrono::{Local, TimeZone};
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};

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

        let resp = crate::api::network::retry_request("fetch_bangumi_episodes", |client| {
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

        let resp = crate::api::network::retry_request("fetch_bangumi_episodes.next", |client| {
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

    let resp = crate::api::network::retry_request("fetch_bangumi_characters", |client| {
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
                Some(BangumiImages {
                    small: images_data["small"].as_str().unwrap_or("").to_string(),
                    grid: images_data["grid"].as_str().unwrap_or("").to_string(),
                    large: images_data["large"].as_str().unwrap_or("").to_string(),
                    medium: images_data["medium"].as_str().unwrap_or("").to_string(),
                    common: images_data["common"].as_str().unwrap_or("").to_string(),
                })
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

    let resp = crate::api::network::retry_request("fetch_bangumi_characters.next", |client| {
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
                Some(BangumiImages {
                    small: images_data["small"].as_str().unwrap_or("").to_string(),
                    grid: images_data["grid"].as_str().unwrap_or("").to_string(),
                    large: images_data["large"].as_str().unwrap_or("").to_string(),
                    medium: images_data["medium"].as_str().unwrap_or("").to_string(),
                    common: String::new(),
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

    let resp = crate::api::network::retry_request("fetch_bangumi_relations", |client| {
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
                    image: item["images"]["large"].as_str().unwrap_or("").to_string(),
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
        "hybrid" => {
            match fetch_bangumi_comments_next(subject_id, page).await {
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
            }
        }
        "modern" => fetch_bangumi_comments_next(subject_id, page).await,
        _ => {
            match fetch_bangumi_comments_next(subject_id, page).await {
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
            }
        }
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

    let resp =
        crate::api::network::retry_request(BANGUMI_SUBJECT_COMMENTS_LEGACY_LABEL, |client| {
            client.get(&url)
        })
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
                                if url.starts_with("//") {
                                    return format!("https:{}", url);
                                }
                                return url.to_string();
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

    let resp = crate::api::network::retry_request("fetch_bangumi_persons", |client| {
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
                let small = images_data["small"].as_str().unwrap_or("").to_string();
                let large = images_data["large"].as_str().unwrap_or("").to_string();
                let medium = images_data["medium"].as_str().unwrap_or("").to_string();
                let grid = images_data["grid"].as_str().unwrap_or("").to_string();
                // Only create images if at least one URL is non-empty
                if !small.is_empty() || !large.is_empty() || !medium.is_empty() {
                    Some(BangumiImages {
                        small,
                        grid,
                        large,
                        medium,
                        common: String::new(),
                    })
                } else {
                    None
                }
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
        "hybrid" => {
            match fetch_bangumi_episode_comments_next(episode_id).await {
                Ok(comments) => Ok(comments),
                Err(err) => {
                    log::warn!(
                        "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                        episode_id,
                        err
                    );
                    fetch_bangumi_episode_comments_legacy(episode_id).await
                }
            }
        }
        "modern" => fetch_bangumi_episode_comments_next(episode_id).await,
        _ => {
            match fetch_bangumi_episode_comments_next(episode_id).await {
                Ok(comments) => Ok(comments),
                Err(err) => {
                    log::warn!(
                        "bangumi.comments.episode next failed episode_id={}, falling back to legacy: {}",
                        episode_id,
                        err
                    );
                    fetch_bangumi_episode_comments_legacy(episode_id).await
                }
            }
        }
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
    let resp =
        crate::api::network::retry_request(BANGUMI_EPISODE_COMMENTS_LEGACY_LABEL, |client| {
            client.get(&url)
        })
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
        let avatar = if let Some(span) = main_element.select(&avatar_selector).next() {
            if let Some(style) = span.value().attr("style") {
                // background-image:url('...')
                if let Some(start) = style.find("url('") {
                    if let Some(end) = style[start + 5..].find("')") {
                        let url = &style[start + 5..start + 5 + end];
                        if url.starts_with("//") {
                            format!("https:{}", url)
                        } else {
                            url.to_string()
                        }
                    } else {
                        String::new()
                    }
                } else {
                    String::new()
                }
            } else {
                String::new()
            }
        } else {
            String::new()
        };

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

            let s_avatar = if let Some(span) = sub_element.select(&avatar_selector).next() {
                if let Some(style) = span.value().attr("style") {
                    if let Some(start) = style.find("url('") {
                        if let Some(end) = style[start + 5..].find("')") {
                            let url = &style[start + 5..start + 5 + end];
                            if url.starts_with("//") {
                                format!("https:{}", url)
                            } else {
                                url.to_string()
                            }
                        } else {
                            String::new()
                        }
                    } else {
                        String::new()
                    }
                } else {
                    String::new()
                }
            } else {
                String::new()
            };

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

fn escape_html(text: &str) -> String {
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

fn normalize_avatar_url(value: Option<&str>) -> String {
    value.unwrap_or("").to_string()
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

    let resp = crate::api::network::retry_request_with_status(
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
                content_html: escape_html(&content),
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
        content_html: escape_html(content),
        replies,
    }
}

async fn fetch_bangumi_episode_comments_next(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let url = bangumi_next_url(&format!("/p1/episodes/{episode_id}/comments"));

    let resp = crate::api::network::retry_request_with_status(
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

    let resp = crate::api::network::retry_request("fetch_character_details", |client| {
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
        Some(BangumiImages {
            small: images_data["small"].as_str().unwrap_or("").to_string(),
            grid: images_data["grid"].as_str().unwrap_or("").to_string(),
            large: images_data["large"].as_str().unwrap_or("").to_string(),
            medium: images_data["medium"].as_str().unwrap_or("").to_string(),
            common: images_data["common"].as_str().unwrap_or("").to_string(),
        })
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

    let resp = crate::api::network::retry_request("fetch_person_details", |client| {
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
        img: json["img"].as_str().unwrap_or("").to_string(),
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

    let resp = crate::api::network::retry_request("fetch_person_subjects", |client| {
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
                image: item["image"].as_str().unwrap_or("").to_string(),
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

    let resp = crate::api::network::retry_request("fetch_person_characters", |client| {
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
                let large = images_data["large"].as_str().unwrap_or("").to_string();
                let medium = images_data["medium"].as_str().unwrap_or("").to_string();
                let small = images_data["small"].as_str().unwrap_or("").to_string();
                if !large.is_empty() || !medium.is_empty() || !small.is_empty() {
                    Some(BangumiImages {
                        small,
                        grid: images_data["grid"].as_str().unwrap_or("").to_string(),
                        large,
                        medium,
                        common: String::new(),
                    })
                } else {
                    None
                }
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
        crate::api::network::retry_request("fetch_character_subjects/subjects", |client| client
            .get(&subjects_url)
            .header("accept", "application/json"),),
        crate::api::network::retry_request("fetch_character_subjects/persons", |client| client
            .get(&persons_url)
            .header("accept", "application/json"),)
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
                        let image = item["image"]
                            .as_str()
                            .or_else(|| item["images"]["large"].as_str())
                            .or_else(|| item["images"]["medium"].as_str())
                            .or_else(|| item["images"]["small"].as_str())
                            .unwrap_or("")
                            .to_string();

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
                                Some(BangumiImages {
                                    small: images_data["small"].as_str().unwrap_or("").to_string(),
                                    grid: images_data["grid"].as_str().unwrap_or("").to_string(),
                                    large: images_data["large"].as_str().unwrap_or("").to_string(),
                                    medium: images_data["medium"]
                                        .as_str()
                                        .unwrap_or("")
                                        .to_string(),
                                    common: String::new(),
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
