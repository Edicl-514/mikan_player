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
    pub time: String,
    pub avatar: String,
}

/// Fetch episodes for a subject
/// API: GET https://api.bgm.tv/v0/episodes?subject_id={subject_id}&limit=100&offset=0
pub async fn fetch_bangumi_episodes(subject_id: i64) -> anyhow::Result<Vec<BangumiEpisode>> {
    let client = reqwest::Client::builder()
        .user_agent("MikanPlayer/1.0 (https://github.com/your-repo/mikan_player)")
        .build()?;

    let mut all_episodes = Vec::new();
    let mut offset = 0;
    let limit = 100;

    loop {
        let url = format!(
            "https://api.bgm.tv/v0/episodes?subject_id={}&limit={}&offset={}",
            subject_id, limit, offset
        );

        let resp = client
            .get(&url)
            .header("accept", "application/json")
            .send()
            .await?;

        if !resp.status().is_success() {
            break;
        }

        let json: serde_json::Value = resp.json().await?;

        if let Some(data) = json["data"].as_array() {
            if data.is_empty() {
                break;
            }

            for item in data {
                let name = item["name"].as_str().unwrap_or("").to_string();

                // Skip episodes with empty name -> logic moved to Dart (filtered by date)
                // if name.is_empty() {
                //    continue;
                // }

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

            offset += limit;
        } else {
            break;
        }
    }

    Ok(all_episodes)
}

/// Fetch characters for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/characters
pub async fn fetch_bangumi_characters(subject_id: i64) -> anyhow::Result<Vec<BangumiCharacter>> {
    let client = reqwest::Client::builder()
        .user_agent("MikanPlayer/1.0 (https://github.com/your-repo/mikan_player)")
        .build()?;

    let url = format!("https://api.bgm.tv/v0/subjects/{}/characters", subject_id);

    let resp = client
        .get(&url)
        .header("accept", "application/json")
        .send()
        .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(data) = json.as_array() {
        for item in data {
            // The actors data is directly in the item
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

            // Images are directly in the item
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

/// Fetch related subjects for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/subjects
/// Only returns anime-related subjects (type 2) with specific relations
pub async fn fetch_bangumi_relations(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiRelatedSubject>> {
    let client = reqwest::Client::builder()
        .user_agent("MikanPlayer/1.0 (https://github.com/your-repo/mikan_player)")
        .build()?;

    let url = format!("https://api.bgm.tv/v0/subjects/{}/subjects", subject_id);

    let resp = client
        .get(&url)
        .header("accept", "application/json")
        .send()
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
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        .build()?;

    let url = format!(
        "https://bgm.tv/subject/{}/comments?page={}",
        subject_id, page
    );

    let resp = client.get(&url).send().await?;

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
            let content = if let Some(content_sel) = &content_selector {
                item.select(content_sel)
                    .next()
                    .map(|e| e.text().collect::<String>().trim().to_string())
                    .unwrap_or_default()
            } else {
                String::new()
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

            if !user_name.is_empty() && !content.is_empty() {
                comments.push(BangumiComment {
                    user_name,
                    rate,
                    content,
                    time,
                    avatar,
                });
            }
        }
    }

    Ok(comments)
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

/// Scrape episode comments from Bangumi
/// URL: https://bangumi.tv/ep/{episode_id}
pub async fn fetch_bangumi_episode_comments(
    episode_id: i64,
) -> anyhow::Result<Vec<BangumiEpisodeComment>> {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        .build()?;

    let url = format!("https://bangumi.tv/ep/{}", episode_id);
    let resp = client.get(&url).send().await?;

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
                .replace("src=\"/img/", "src=\"https://bangumi.tv/img/")
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
                msg.html()
                    .replace("src=\"//", "src=\"https://")
                    .replace("src=\"/img/", "src=\"https://bangumi.tv/img/")
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
