use super::types::*;
use super::util::*;

const BANGUMI_NEXT_CHARACTERS_PAGE_SIZE: i64 = 100;

pub(crate) async fn fetch_bangumi_characters(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiCharacter>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "modern" => fetch_bangumi_characters_next(subject_id).await,
        _ => fetch_bangumi_characters_rest(subject_id).await,
    }
}

pub(super) fn map_character_role_type(role_type: i64) -> String {
    match role_type {
        1 => "主角".to_string(),
        2 => "配角".to_string(),
        3 => "客串".to_string(),
        4 => "闲角".to_string(),
        _ => String::new(),
    }
}

fn parse_bangumi_characters_rest(json: &serde_json::Value) -> Vec<BangumiCharacter> {
    json.as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            let actors = item["actors"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(|actor| {
                    let id = actor["id"].as_i64().filter(|id| *id > 0)?;
                    Some(BangumiActor {
                        id,
                        name: actor["name"].as_str().unwrap_or("").to_string(),
                    })
                })
                .collect();

            Some(BangumiCharacter {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                role_name: item["relation"].as_str().unwrap_or("").to_string(),
                images: parse_bangumi_images(&item["images"]),
                actors,
            })
        })
        .collect()
}

fn parse_bangumi_characters_next(json: &serde_json::Value) -> Vec<BangumiCharacter> {
    json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let character = &item["character"];
            let id = character["id"].as_i64().filter(|id| *id > 0)?;
            let actors = item["casts"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(|cast| {
                    let person = &cast["person"];
                    let id = person["id"].as_i64().filter(|id| *id > 0)?;
                    Some(BangumiActor {
                        id,
                        name: person["name"].as_str().unwrap_or("").to_string(),
                    })
                })
                .collect();
            let images = parse_bangumi_images(&character["images"]).map(|mut images| {
                images.common = String::new();
                images
            });

            Some(BangumiCharacter {
                id,
                name: character["name"].as_str().unwrap_or("").to_string(),
                role_name: map_character_role_type(item["type"].as_i64().unwrap_or(0)),
                images,
                actors,
            })
        })
        .collect()
}

pub(super) async fn fetch_bangumi_characters_rest(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiCharacter>> {
    let url = format!(
        "{}/v0/subjects/{}/characters",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_bangumi_characters",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_characters_rest(&json))
}

pub(super) async fn fetch_bangumi_characters_next(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiCharacter>> {
    let mut characters = Vec::new();
    let mut offset = 0_i64;

    loop {
        let url = format!(
            "{}/p1/subjects/{}/characters?limit={}&offset={}",
            crate::api::config::get_bangumi_next_url(),
            subject_id,
            BANGUMI_NEXT_CHARACTERS_PAGE_SIZE,
            offset
        );

        let resp = crate::api::network::retry_request_bangumi_with_status(
            "fetch_bangumi_characters.next",
            |client| client.get(&url).header("accept", "application/json"),
            true,
        )
        .await?;

        if !resp.status().is_success() {
            anyhow::bail!(
                "p1 characters request failed for subject_id={} status={}",
                subject_id,
                resp.status()
            );
        }

        let json: serde_json::Value = resp.json().await?;
        let fetched_count = json["data"].as_array().map_or(0, |data| data.len()) as i64;
        let total = json["total"].as_i64().filter(|total| *total >= 0);
        characters.extend(parse_bangumi_characters_next(&json));

        if fetched_count == 0 {
            break;
        }
        offset += fetched_count;

        if total.is_some_and(|total| offset >= total)
            || (total.is_none() && fetched_count < BANGUMI_NEXT_CHARACTERS_PAGE_SIZE)
        {
            break;
        }
    }

    Ok(characters)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    fn point_bangumi_at(base_url: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_next_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn rest_character_normalization_filters_invalid_ids_and_actor_shapes() {
        let characters = parse_bangumi_characters_rest(&json!([
            {"id": 1, "name": "主角", "relation": "主角", "actors": [{"id": 9, "name": "CV"}, {"id": 0}]},
            {"id": 0, "name": "Missing"},
            {"id": "2", "name": "Type changed"}
        ]));

        assert_eq!(characters.len(), 1);
        assert_eq!(characters[0].actors.len(), 1);
        assert!(characters[0].images.is_none());
    }

    #[test]
    fn next_character_normalization_maps_known_and_unknown_roles() {
        let characters = parse_bangumi_characters_next(&json!({"data": [
            {"type": 1, "character": {"id": 1, "name": "A", "images": {}}, "casts": [{"person": {"id": 5, "name": "Actor"}}]},
            {"type": 99, "character": {"id": 2, "name": "B"}},
            {"type": 2, "character": {"id": 0}}
        ]}));

        assert_eq!(characters.len(), 2);
        assert_eq!(characters[0].role_name, "主角");
        assert_eq!(characters[1].role_name, "");
        assert_eq!(characters[0].images.as_ref().unwrap().common, "");
        assert!(parse_bangumi_characters_next(&json!({"data": null})).is_empty());
    }

    #[tokio::test]
    async fn character_fetch_applies_rest_empty_and_next_error_status_policies() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/v0/subjects/7/characters",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
            TestRoute::get(
                "/p1/subjects/8/characters",
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url());

        assert!(fetch_bangumi_characters_rest(7).await.unwrap().is_empty());
        let error = fetch_bangumi_characters_next(8).await.unwrap_err();
        assert!(error.to_string().contains("status=429"));
        server.shutdown().await;
    }

    #[tokio::test]
    async fn next_character_fetch_follows_total_and_advances_by_raw_rows() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::sequence(
            axum::http::Method::GET,
            "/p1/subjects/9/characters",
            [
                TestResponse::ok(
                    json!({
                        "total": 2,
                        "data": [
                            {"type": 1, "character": {"id": 0, "name": "filtered"}}
                        ]
                    })
                    .to_string(),
                ),
                TestResponse::ok(
                    json!({
                        "total": 2,
                        "data": [
                            {"type": 2, "character": {"id": 2, "name": "second"}}
                        ]
                    })
                    .to_string(),
                ),
            ],
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let characters = fetch_bangumi_characters_next(9).await.unwrap();

        assert_eq!(characters.len(), 1);
        assert_eq!(characters[0].id, 2);
        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(requests[0].uri.query(), Some("limit=100&offset=0"));
        assert_eq!(requests[1].uri.query(), Some("limit=100&offset=1"));
        server.shutdown().await;
    }
}
