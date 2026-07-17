use super::types::*;
use std::collections::HashSet;

pub async fn fill_anime_details(animes: Vec<AnimeInfo>) -> anyhow::Result<Vec<AnimeInfo>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    let mut results = animes;

    let graphql_details = match mode.as_str() {
        "legacy" => std::collections::HashMap::new(),
        "hybrid" | "modern" | _ => {
            let mut seen_ids = HashSet::new();
            let ids: Vec<i64> = results
                .iter()
                .filter_map(|anime| anime.bangumi_id.as_deref())
                .filter_map(|id| id.parse::<i64>().ok())
                .filter(|id| seen_ids.insert(*id))
                .collect();

            log::info!(
                "fill_anime_details strategy=graphql_then_rest mode={} batch_size={}",
                mode,
                ids.len()
            );
            crate::api::bangumi_graphql::fetch_subject_details_graphql_batch(&ids).await
        }
    };

    let is_modern = mode == "modern";
    let mut fallback_tasks: Vec<
        tokio::task::JoinHandle<anyhow::Result<(usize, serde_json::Value)>>,
    > = Vec::new();

    for (index, anime) in results.iter_mut().enumerate() {
        let Some(id) = anime.bangumi_id.clone() else {
            continue;
        };

        let used_graphql = id
            .parse::<i64>()
            .ok()
            .and_then(|parsed_id| graphql_details.get(&parsed_id))
            .map(|json| {
                apply_subject_details(anime, json);
            })
            .is_some();

        if !used_graphql {
            if is_modern {
                fallback_tasks.push(tokio::spawn(async move {
                    let p1_json =
                        fetch_subject_details_next_p1_json(id.parse::<i64>().unwrap_or(0)).await?;
                    Ok((index, normalize_next_subject_json(&p1_json)))
                }));
            } else {
                fallback_tasks.push(tokio::spawn(async move {
                    let json = fetch_subject_details_rest_json(&id).await?;
                    Ok((index, json))
                }));
            }
        }
    }

    for task in fallback_tasks {
        match task.await {
            Ok(Ok((index, json))) => {
                if let Some(anime) = results.get_mut(index) {
                    apply_subject_details(anime, &json);
                }
            }
            Ok(Err(err)) => {
                log::warn!("fill_anime_details fallback task failed: {}", err);
            }
            Err(err) => {
                log::warn!("fill_anime_details fallback task join error: {}", err);
            }
        }
    }

    Ok(results)
}

pub(super) async fn fetch_subject_details_rest_json(id: &str) -> anyhow::Result<serde_json::Value> {
    let api_url = format!(
        "{}/v0/subjects/{}",
        crate::api::config::get_bangumi_api_url(),
        id
    );
    let label = format!("fill_anime_details.subject.{}", id);
    let resp = crate::api::network::retry_request_bangumi(&label, |client| {
        client.get(&api_url).header("accept", "application/json")
    })
    .await?;

    Ok(resp.json::<serde_json::Value>().await?)
}

pub(super) async fn fetch_subject_details_next_p1_json(
    id: i64,
) -> anyhow::Result<serde_json::Value> {
    let url = format!(
        "{}/p1/subjects/{}",
        crate::api::config::get_bangumi_next_url(),
        id
    );
    let label = format!("fetch_subject_details_next_p1.subject.{}", id);
    let resp = crate::api::network::retry_request_bangumi(&label, |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        anyhow::bail!(
            "p1 subject request failed for id={} status={}",
            id,
            resp.status()
        );
    }

    Ok(resp.json::<serde_json::Value>().await?)
}

pub(super) fn normalize_next_subject_json(subject: &serde_json::Value) -> serde_json::Value {
    let mut normalized = subject.as_object().cloned().unwrap_or_default();

    if let Some(name_cn) = normalized.get("nameCN").and_then(|v| v.as_str()) {
        normalized.insert("name_cn".to_string(), serde_json::json!(name_cn));
    }

    if let Some(meta_tags) = normalized.get("metaTags").and_then(|v| v.as_array()) {
        normalized.insert("meta_tags".to_string(), serde_json::json!(meta_tags));
    }

    if let Some(infobox_items) = normalized.get("infobox").and_then(|v| v.as_array()) {
        let normalized_infobox: Vec<serde_json::Value> = infobox_items
            .iter()
            .map(|item| {
                let mut normalized_item = item.as_object().cloned().unwrap_or_default();

                if normalized_item.get("value").is_none() {
                    if let Some(values) = normalized_item.get("values").cloned() {
                        normalized_item.insert("value".to_string(), values);
                    }
                }

                serde_json::Value::Object(normalized_item)
            })
            .collect();

        normalized.insert("infobox".to_string(), serde_json::json!(normalized_infobox));
    }

    let airtime_date = normalized
        .get("airtime")
        .and_then(|v| v.get("date"))
        .cloned()
        .unwrap_or(serde_json::Value::Null);
    normalized.insert("date".to_string(), airtime_date);

    if let Some(collection) = normalized.get("collection").and_then(|v| v.as_object()) {
        let mut normalized_collection = serde_json::Map::new();
        let mapping = [
            ("1", "wish"),
            ("2", "collect"),
            ("3", "doing"),
            ("4", "on_hold"),
            ("5", "dropped"),
        ];
        for (num_key, name_key) in mapping {
            if let Some(count) = collection.get(num_key).and_then(|v| v.as_i64()) {
                normalized_collection.insert(name_key.to_string(), serde_json::json!(count));
            }
        }
        normalized.insert(
            "collection".to_string(),
            serde_json::Value::Object(normalized_collection),
        );
    }

    if let Some(images) = normalized.get_mut("images").and_then(|v| v.as_object_mut()) {
        if let Some(value) = images.get("large").and_then(|v| v.as_str()) {
            let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
            if rewritten != value {
                images.insert("large".to_string(), serde_json::Value::String(rewritten));
            }
        }
        if let Some(value) = images.get("common").and_then(|v| v.as_str()) {
            let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
            if rewritten != value {
                images.insert("common".to_string(), serde_json::Value::String(rewritten));
            }
        }
        if images.get("large").is_none() {
            images.insert(
                "large".to_string(),
                serde_json::Value::String(String::new()),
            );
        }
        if images.get("common").is_none() {
            images.insert(
                "common".to_string(),
                serde_json::Value::String(String::new()),
            );
        }
    }

    if let Some(rating) = normalized.get_mut("rating").and_then(|v| v.as_object_mut()) {
        if let Some(score_str) = rating.get("score").and_then(|v| v.as_str()) {
            if let Ok(score) = score_str.parse::<f64>() {
                rating.insert("score".to_string(), serde_json::json!(score));
            }
        }
    }

    let total_episodes = normalized
        .get("eps")
        .cloned()
        .unwrap_or(serde_json::Value::Null);
    normalized.insert("total_episodes".to_string(), total_episodes);

    serde_json::Value::Object(normalized)
}

pub(super) fn apply_subject_details(anime: &mut AnimeInfo, json: &serde_json::Value) {
    let image_url = json["images"]["large"]
        .as_str()
        .filter(|url| !url.is_empty())
        .or_else(|| {
            json["images"]["common"]
                .as_str()
                .filter(|url| !url.is_empty())
        });
    if let Some(image_url) = image_url {
        anime.cover_url = Some(crate::api::config::rewrite_bangumi_url_if_proxied(
            image_url,
        ));
    }

    if let Some(score) = json["rating"]["score"].as_f64() {
        anime.score = Some(score);
    }
    if let Some(rank) = json["rating"]["rank"].as_i64() {
        anime.rank = Some(rank as i32);
    }

    let mut tags: Vec<String> = json["meta_tags"]
        .as_array()
        .map(|meta_tags| {
            meta_tags
                .iter()
                .filter_map(|tag| tag.as_str().map(|value| value.to_string()))
                .collect()
        })
        .unwrap_or_else(|| {
            json["tags"]
                .as_array()
                .map(|tags| {
                    tags.iter()
                        .filter_map(|tag| tag["name"].as_str().map(|value| value.to_string()))
                        .collect()
                })
                .unwrap_or_default()
        });
    tags.sort();
    tags.dedup();
    anime.tags = tags;
    anime.full_json = Some(json.to_string());
}

pub async fn fetch_light_subject_details(subject_id: i64) -> anyhow::Result<AnimeInfo> {
    let mode = crate::api::config::get_bangumi_request_mode();
    log::debug!(
        "fetch_light_subject_details mode={} subject_id={}",
        mode,
        subject_id
    );

    match mode.as_str() {
        "legacy" => {
            let json = fetch_subject_details_rest_json(&subject_id.to_string()).await?;
            Ok(build_light_subject_from_json(subject_id, &json))
        }
        "hybrid" => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed, falling back to REST: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => fetch_subject_details_rest_json(&subject_id.to_string()).await?,
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
        "modern" => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed for modern mode, falling back to p1: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => {
                    let p1_json = fetch_subject_details_next_p1_json(subject_id).await?;
                    normalize_next_subject_json(&p1_json)
                }
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
        _ => {
            let graphql_result =
                match crate::api::bangumi_graphql::fetch_light_subject_details_graphql(subject_id)
                    .await
                {
                    Ok(raw) => Some(
                        crate::api::bangumi_graphql::normalize_light_subject_graphql_json(&raw),
                    ),
                    Err(err) => {
                        log::warn!(
                            "fetch_light_subject_details graphql failed, falling back to REST: {}",
                            err
                        );
                        None
                    }
                };

            let json = match graphql_result {
                Some(json) => json,
                None => fetch_subject_details_rest_json(&subject_id.to_string()).await?,
            };

            Ok(build_light_subject_from_json(subject_id, &json))
        }
    }
}

pub(super) fn build_light_subject_from_json(
    subject_id: i64,
    json: &serde_json::Value,
) -> AnimeInfo {
    let title = json["name"].as_str().unwrap_or("").to_string();
    let sub_title = json["name_cn"].as_str().unwrap_or("").to_string();
    let cover_url = json["images"]["large"]
        .as_str()
        .filter(|url| !url.is_empty())
        .or_else(|| {
            json["images"]["common"]
                .as_str()
                .filter(|url| !url.is_empty())
        })
        .map(|url| crate::api::config::rewrite_bangumi_url_if_proxied(url));
    let score = json["rating"]["score"].as_f64();
    let rank = json["rating"]["rank"].as_i64().map(|value| value as i32);

    let mut tags: Vec<String> = json["meta_tags"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        })
        .unwrap_or_else(|| {
            json["tags"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|tag| tag["name"].as_str().map(String::from))
                        .collect()
                })
                .unwrap_or_default()
        });
    tags.sort();
    tags.dedup();

    AnimeInfo {
        title,
        sub_title: if sub_title.is_empty() {
            None
        } else {
            Some(sub_title)
        },
        bangumi_id: Some(subject_id.to_string()),
        mikan_id: None,
        cover_url,
        site_url: None,
        broadcast_day: None,
        broadcast_time: None,
        score,
        rank,
        tags,
        full_json: Some(json.to_string()),
    }
}

pub async fn fetch_extra_subjects(
    year_quarter: String,
    existing_ids: Vec<String>,
) -> anyhow::Result<Vec<AnimeInfo>> {
    let existing_set: HashSet<String> = existing_ids.into_iter().collect();

    fetch_extra_bangumi_subjects(&year_quarter, &existing_set).await
}

pub(super) async fn fetch_extra_bangumi_subjects(
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

    let init_resp =
        match crate::api::network::retry_request_bangumi("fetch_extra_subjects.init", |client| {
            client
                .post(&url)
                .query(&[("limit", "1"), ("offset", "0")])
                .header("Content-Type", "application/json")
                .header("accept", "application/json")
                .json(&body_json)
        })
        .await
        {
            Ok(resp) => resp,
            Err(err) => {
                log::warn!("fetch_extra_subjects.init failed: {}", err);
                return Ok(vec![]);
            }
        };

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
        let body_c = body_json.clone();
        let page_url = url.clone();

        tasks.push(tokio::spawn(async move {
            let label = format!("fetch_extra_subjects.page.offset_{}", offset);
            match crate::api::network::retry_request_bangumi(&label, |client| {
                client
                    .post(&page_url)
                    .query(&[
                        ("limit", &limit.to_string()),
                        ("offset", &offset.to_string()),
                    ])
                    .header("Content-Type", "application/json")
                    .header("accept", "application/json")
                    .json(&body_c)
            })
            .await
            {
                Ok(resp) => resp.json::<serde_json::Value>().await.ok(),
                Err(err) => {
                    log::warn!("{} failed: {}", label, err);
                    None
                }
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
                    let cover = item["images"]["large"]
                        .as_str()
                        .map(|s| crate::api::config::rewrite_bangumi_url_if_proxied(s));

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
