use super::types::*;

pub(crate) async fn fetch_bangumi_episodes(subject_id: i64) -> anyhow::Result<Vec<BangumiEpisode>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "modern" => fetch_bangumi_episodes_next(subject_id).await,
        _ => fetch_bangumi_episodes_rest(subject_id).await,
    }
}

pub(super) async fn fetch_bangumi_episodes_rest(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiEpisode>> {
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

pub(super) async fn fetch_bangumi_episodes_next(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiEpisode>> {
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
