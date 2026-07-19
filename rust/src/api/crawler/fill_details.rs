use super::types::*;
use std::collections::{HashMap, HashSet};

fn positive_subject_id(raw: &str) -> Option<i64> {
    raw.trim().parse::<i64>().ok().filter(|id| *id > 0)
}

fn valid_score(value: f64) -> bool {
    value.is_finite() && (0.0..=10.0).contains(&value)
}

fn valid_rank(value: i64) -> Option<i32> {
    i32::try_from(value).ok().filter(|rank| *rank > 0)
}

fn normalized_tags(json: &serde_json::Value) -> Vec<String> {
    let mut tags: Vec<String> = json["meta_tags"]
        .as_array()
        .map(|meta_tags| {
            meta_tags
                .iter()
                .filter_map(|tag| tag.as_str())
                .map(str::trim)
                .filter(|tag| !tag.is_empty())
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_else(|| {
            json["tags"]
                .as_array()
                .map(|tags| {
                    tags.iter()
                        .filter_map(|tag| tag["name"].as_str())
                        .map(str::trim)
                        .filter(|tag| !tag.is_empty())
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default()
        });
    tags.sort();
    tags.dedup();
    tags
}

pub(crate) async fn fill_anime_details(animes: Vec<AnimeInfo>) -> anyhow::Result<Vec<AnimeInfo>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    let mut results = animes;

    let graphql_details = match mode.as_str() {
        "legacy" => std::collections::HashMap::new(),
        _ => {
            let mut seen_ids = HashSet::new();
            let ids: Vec<i64> = results
                .iter()
                .filter_map(|anime| anime.bangumi_id.as_deref())
                .filter_map(positive_subject_id)
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
    let mut fallback_indices: HashMap<i64, Vec<usize>> = HashMap::new();

    for (index, anime) in results.iter_mut().enumerate() {
        let Some(id) = anime.bangumi_id.as_deref().and_then(positive_subject_id) else {
            continue;
        };

        let used_graphql = graphql_details
            .get(&id)
            .map(|json| {
                apply_subject_details(anime, json);
            })
            .is_some();

        if !used_graphql {
            fallback_indices.entry(id).or_default().push(index);
        }
    }

    let fallback_tasks: Vec<_> = fallback_indices
        .into_iter()
        .map(|(id, indices)| {
            tokio::spawn(async move {
                let json = if is_modern {
                    let p1_json = fetch_subject_details_next_p1_json(id).await?;
                    normalize_next_subject_json(&p1_json)
                } else {
                    fetch_subject_details_rest_json(&id.to_string()).await?
                };
                Ok::<_, anyhow::Error>((indices, json))
            })
        })
        .collect();

    for task in fallback_tasks {
        match task.await {
            Ok(Ok((indices, json))) => {
                for index in indices {
                    if let Some(anime) = results.get_mut(index) {
                        apply_subject_details(anime, &json);
                    }
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

                if normalized_item.get("value").is_none()
                    && let Some(values) = normalized_item.get("values").cloned()
                {
                    normalized_item.insert("value".to_string(), values);
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

    if let Some(rating) = normalized.get_mut("rating").and_then(|v| v.as_object_mut())
        && let Some(score_str) = rating.get("score").and_then(|v| v.as_str())
        && let Ok(score) = score_str.parse::<f64>()
        && valid_score(score)
    {
        rating.insert("score".to_string(), serde_json::json!(score));
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
        .map(str::trim)
        .filter(|url| !url.is_empty())
        .or_else(|| {
            json["images"]["common"]
                .as_str()
                .map(str::trim)
                .filter(|url| !url.is_empty())
        });
    let cover_is_missing = anime
        .cover_url
        .as_deref()
        .map(str::trim)
        .is_none_or(str::is_empty);
    if cover_is_missing && let Some(image_url) = image_url {
        anime.cover_url = Some(crate::api::config::rewrite_bangumi_url_if_proxied(
            image_url,
        ));
    }

    if !anime.score.is_some_and(valid_score)
        && let Some(score) = json["rating"]["score"]
            .as_f64()
            .filter(|score| valid_score(*score))
    {
        anime.score = Some(score);
    }
    if anime.rank.is_none_or(|rank| rank <= 0)
        && let Some(rank) = json["rating"]["rank"].as_i64().and_then(valid_rank)
    {
        anime.rank = Some(rank);
    }

    if !anime.tags.iter().any(|tag| !tag.trim().is_empty()) {
        anime.tags = normalized_tags(json);
    }
    if anime
        .full_json
        .as_deref()
        .map(str::trim)
        .is_none_or(str::is_empty)
    {
        anime.full_json = Some(json.to_string());
    }
}

pub(crate) async fn fetch_light_subject_details(subject_id: i64) -> anyhow::Result<AnimeInfo> {
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
        .map(crate::api::config::rewrite_bangumi_url_if_proxied);
    let score = json["rating"]["score"]
        .as_f64()
        .filter(|score| valid_score(*score));
    let rank = json["rating"]["rank"].as_i64().and_then(valid_rank);
    let tags = normalized_tags(json);

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

pub(crate) async fn fetch_extra_subjects(
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
    let Some(captures) = regex::Regex::new(r"^(\d{4})q([1-4])$")
        .ok()
        .and_then(|re| re.captures(year_quarter))
    else {
        return Ok(vec![]);
    };
    let Some(year) = captures
        .get(1)
        .and_then(|value| value.as_str().parse::<i32>().ok())
    else {
        return Ok(vec![]);
    };
    let q_str = captures.get(2).map(|value| value.as_str()).unwrap_or("");

    // Determine date range (Next quarter start is exclusive bound)
    let (start_date, end_date) = match q_str {
        "1" => (format!("{}-01-01", year), format!("{}-04-01", year)),
        "2" => (format!("{}-04-01", year), format!("{}-07-01", year)),
        "3" => (format!("{}-07-01", year), format!("{}-10-01", year)),
        "4" => (format!("{}-10-01", year), format!("{}-01-01", year + 1)),
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
    let mut seen_ids: HashSet<i64> = existing_ids
        .iter()
        .filter_map(|id| positive_subject_id(id))
        .collect();

    for task in tasks {
        if let Ok(Some(json)) = task.await
            && let Some(data) = json["data"].as_array()
        {
            for item in data {
                // Normalize ID for deduplication
                let id = if let Some(n) = item["id"].as_i64().filter(|id| *id > 0) {
                    n
                } else if let Some(s) = item["id"].as_str() {
                    let Some(id) = positive_subject_id(s) else {
                        continue;
                    };
                    id
                } else {
                    continue;
                };
                if seen_ids.contains(&id) {
                    continue;
                }
                let id_str = id.to_string();

                // Map to AnimeInfo
                let name = item["name"].as_str().unwrap_or("").trim();
                let name_cn = item["name_cn"].as_str().unwrap_or("").trim();
                let title = if !name_cn.is_empty() {
                    name_cn.to_string()
                } else {
                    name.to_string()
                };

                if title.is_empty() {
                    continue;
                }
                seen_ids.insert(id);

                let date = item["date"].as_str().unwrap_or("").trim().to_string();
                let cover = item["images"]["large"]
                    .as_str()
                    .map(crate::api::config::rewrite_bangumi_url_if_proxied);

                let score = item["score"]
                    .as_f64()
                    .or_else(|| item["rating"]["score"].as_f64())
                    .filter(|score| valid_score(*score));

                let rank = item["rank"]
                    .as_i64()
                    .or_else(|| item["rating"]["rank"].as_i64())
                    .and_then(valid_rank);

                let anime = AnimeInfo {
                    title: title.clone(),
                    sub_title: if name_cn.is_empty() {
                        None
                    } else {
                        (!name.is_empty()).then(|| name.to_string())
                    },
                    bangumi_id: Some(id_str.clone()),
                    mikan_id: None,
                    cover_url: cover,
                    site_url: None,
                    broadcast_day: None, // Will show in "Other"
                    broadcast_time: if date.is_empty() { None } else { Some(date) },
                    score,
                    rank,
                    tags: normalized_tags(item),
                    full_json: Some(item.to_string()),
                };

                // Final check to avoid dupes within the search results themselves (unlikely with pagination but distinct IDs possible?)
                // The set check above handles cross-list dupes.
                // To handle within-list helper dupes (if any), we could maintain a local set, but pagination shouldn't overlap.

                new_animes.push(anime);
            }
        }
    }

    // Sort logic handled by caller? User said "Sort by date".
    // The UI currently sorts each group by `broadcast_time`.
    // Since we set `broadcast_time` to `date`, they will be sorted by date in the UI.

    Ok(new_animes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::{Method, StatusCode};
    use serde_json::json;

    fn anime(title: &str, bangumi_id: Option<&str>) -> AnimeInfo {
        AnimeInfo {
            title: title.to_string(),
            sub_title: None,
            bangumi_id: bangumi_id.map(str::to_string),
            mikan_id: None,
            cover_url: None,
            site_url: None,
            broadcast_day: None,
            broadcast_time: None,
            score: None,
            rank: None,
            tags: Vec::new(),
            full_json: None,
        }
    }

    fn point_bangumi_at(base_url: &str, mode: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_url = base_url.to_string();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_next_url = base_url.to_string();
        config.bangumi_request_mode = mode.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn apply_details_fills_only_missing_or_invalid_fields() {
        let details = json!({
            "images": {"large": "https://images.test/new.jpg"},
            "rating": {"score": 8.5, "rank": 12},
            "meta_tags": ["B", "A", "A", " "],
            "name": "new payload"
        });
        let mut existing = anime("Existing", Some("1"));
        existing.cover_url = Some("https://images.test/existing.jpg".to_string());
        existing.score = Some(9.0);
        existing.rank = Some(3);
        existing.tags = vec!["Existing tag".to_string()];
        existing.full_json = Some("existing-json".to_string());
        apply_subject_details(&mut existing, &details);

        assert_eq!(
            existing.cover_url.as_deref(),
            Some("https://images.test/existing.jpg")
        );
        assert_eq!(existing.score, Some(9.0));
        assert_eq!(existing.rank, Some(3));
        assert_eq!(existing.tags, ["Existing tag"]);
        assert_eq!(existing.full_json.as_deref(), Some("existing-json"));

        let mut missing = anime("Missing", Some("2"));
        missing.cover_url = Some(" ".to_string());
        missing.score = Some(f64::NAN);
        missing.rank = Some(-1);
        missing.full_json = Some(" ".to_string());
        apply_subject_details(&mut missing, &details);
        assert_eq!(
            missing.cover_url.as_deref(),
            Some("https://images.test/new.jpg")
        );
        assert_eq!(missing.score, Some(8.5));
        assert_eq!(missing.rank, Some(12));
        assert_eq!(missing.tags, ["A", "B"]);
        let expected_json = details.to_string();
        assert_eq!(missing.full_json.as_deref(), Some(expected_json.as_str()));
    }

    #[test]
    fn detail_normalization_rejects_non_finite_scores_and_rank_overflow() {
        let next = normalize_next_subject_json(&json!({
            "rating": {"score": "NaN", "rank": i64::MAX},
            "images": {}
        }));
        assert_eq!(next["rating"]["score"], "NaN");

        let built = build_light_subject_from_json(7, &next);
        assert!(built.score.is_none());
        assert!(built.rank.is_none());

        let mut target = anime("Target", Some("7"));
        apply_subject_details(
            &mut target,
            &json!({"rating": {"score": 11.0, "rank": i64::MAX}}),
        );
        assert!(target.score.is_none());
        assert!(target.rank.is_none());
    }

    #[tokio::test]
    async fn partial_fallback_failure_preserves_order_and_deduplicates_requests() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/v0/subjects/1",
                TestResponse::ok(
                    r#"{"images":{"large":"https://images.test/1.jpg"},"rating":{"score":8.5,"rank":12},"meta_tags":["B","A"]}"#,
                ),
            ),
            TestRoute::get(
                "/v0/subjects/2",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url(), "legacy");

        let first = anime("First", Some("1"));
        let mut failed = anime("Failed", Some("2"));
        failed.cover_url = Some("https://images.test/keep.jpg".to_string());
        let mut duplicate = anime("Duplicate", Some("1"));
        duplicate.score = Some(9.5);
        duplicate.tags = vec!["keep".to_string()];
        let invalid = anime("Invalid", Some("not-an-id"));

        let result = fill_anime_details(vec![first, failed, duplicate, invalid])
            .await
            .unwrap();
        assert_eq!(
            result
                .iter()
                .map(|anime| anime.title.as_str())
                .collect::<Vec<_>>(),
            ["First", "Failed", "Duplicate", "Invalid"]
        );
        assert_eq!(
            result[0].cover_url.as_deref(),
            Some("https://images.test/1.jpg")
        );
        assert_eq!(result[0].tags, ["A", "B"]);
        assert_eq!(
            result[1].cover_url.as_deref(),
            Some("https://images.test/keep.jpg")
        );
        assert_eq!(result[2].score, Some(9.5));
        assert_eq!(result[2].tags, ["keep"]);
        assert_eq!(result[2].rank, Some(12));
        assert!(result[3].full_json.is_none());
        assert_eq!(server.request_count(Method::GET, "/v0/subjects/1"), 1);
        assert_eq!(server.request_count(Method::GET, "/v0/subjects/2"), 1);
        assert_eq!(server.request_count(Method::GET, "/v0/subjects/0"), 0);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn invalid_unicode_quarter_returns_empty_without_panicking_or_network() {
        let result = fetch_extra_bangumi_subjects("测试季度", &HashSet::new())
            .await
            .unwrap();
        assert!(result.is_empty());
        assert!(
            fetch_extra_bangumi_subjects("2025q9", &HashSet::new())
                .await
                .unwrap()
                .is_empty()
        );
    }
}
