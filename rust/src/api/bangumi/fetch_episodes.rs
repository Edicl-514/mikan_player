use super::types::*;

#[derive(Clone, Copy)]
enum EpisodeSchema {
    Rest,
    Next,
}

fn parse_episode_page(json: &serde_json::Value, schema: EpisodeSchema) -> Vec<BangumiEpisode> {
    json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter(|item| item["type"].as_i64() == Some(0))
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            let name_cn_key = match schema {
                EpisodeSchema::Rest => "name_cn",
                EpisodeSchema::Next => "nameCN",
            };
            Some(BangumiEpisode {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                name_cn: item[name_cn_key].as_str().unwrap_or("").to_string(),
                description: item["desc"].as_str().unwrap_or("").to_string(),
                airdate: item["airdate"].as_str().unwrap_or("").to_string(),
                duration: item["duration"].as_str().unwrap_or("").to_string(),
                sort: item["sort"].as_f64().unwrap_or(0.0),
            })
        })
        .collect()
}

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

        let resp = crate::api::network::retry_request_bangumi_with_status(
            "fetch_bangumi_episodes",
            |client| client.get(&url).header("accept", "application/json"),
            true,
        )
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

            all_episodes.extend(parse_episode_page(&json, EpisodeSchema::Rest));

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

        let resp = crate::api::network::retry_request_bangumi_with_status(
            "fetch_bangumi_episodes.next",
            |client| client.get(&url).header("accept", "application/json"),
            true,
        )
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

            all_episodes.extend(parse_episode_page(&json, EpisodeSchema::Next));

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::Method;
    use serde_json::json;

    fn point_bangumi_at(base_url: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_next_url = base_url.to_string();
        config.bangumi_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn episode_page_normalization_handles_schema_drift_and_invalid_rows() {
        let input = json!({"data": [
            {"id": 1, "type": 0, "name": "EP1", "name_cn": "第一话", "nameCN": "第壹话", "sort": 1.0},
            {"id": 2, "type": 1, "name": "SP"},
            {"id": 0, "type": 0, "name": "Missing id"},
            {"id": 3, "type": "0", "name": "Changed type"},
            {"id": 4, "type": 0, "sort": "4"}
        ]});

        let rest = parse_episode_page(&input, EpisodeSchema::Rest);
        let next = parse_episode_page(&input, EpisodeSchema::Next);
        assert_eq!(rest.len(), 2);
        assert_eq!(rest[0].name_cn, "第一话");
        assert_eq!(next[0].name_cn, "第壹话");
        assert_eq!(rest[1].sort, 0.0);
        assert!(parse_episode_page(&json!({"data": null}), EpisodeSchema::Rest).is_empty());
    }

    #[tokio::test]
    async fn rest_episode_fetch_paginates_by_total_and_preserves_query_offsets() {
        let _config = isolate_runtime_config();
        let first_page = json!({
            "total": 101,
            "data": (1..=100).map(|id| json!({"id": id, "type": 0, "sort": id})).collect::<Vec<_>>()
        });
        let second_page = json!({"total": 101, "data": [{"id": 101, "type": 0, "sort": 101}]});
        let server = TestServer::spawn([TestRoute::sequence(
            Method::GET,
            "/v0/episodes",
            [
                TestResponse::ok(first_page.to_string()),
                TestResponse::ok(second_page.to_string()),
            ],
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let episodes = fetch_bangumi_episodes_rest(55).await.unwrap();
        assert_eq!(episodes.len(), 101);
        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(
            requests[0].uri.query(),
            Some("subject_id=55&limit=100&offset=0")
        );
        assert_eq!(
            requests[1].uri.query(),
            Some("subject_id=55&limit=100&offset=100")
        );
        server.shutdown().await;
    }

    #[tokio::test]
    async fn next_episode_fetch_rejects_error_status_instead_of_returning_partial_success() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/p1/subjects/9/episodes",
            TestResponse::new(axum::http::StatusCode::TOO_MANY_REQUESTS, "rate limited"),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let error = fetch_bangumi_episodes_next(9).await.unwrap_err();
        assert!(error.to_string().contains("429"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn rest_episode_fetch_returns_completed_pages_when_later_page_is_rate_limited() {
        let _config = isolate_runtime_config();
        let first_page = json!({
            "total": 200,
            "data": (1..=100).map(|id| json!({"id": id, "type": 0})).collect::<Vec<_>>()
        });
        let server = TestServer::spawn([TestRoute::sequence(
            Method::GET,
            "/v0/episodes",
            [
                TestResponse::ok(first_page.to_string()),
                TestResponse::new(axum::http::StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ],
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let episodes = fetch_bangumi_episodes_rest(55).await.unwrap();
        assert_eq!(episodes.len(), 100);
        assert_eq!(server.requests().len(), 2);
        server.shutdown().await;
    }
}
