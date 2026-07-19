use super::types::*;
use super::util::*;

fn parse_bangumi_persons(json: &serde_json::Value) -> Vec<BangumiPerson> {
    json.as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            let images = parse_bangumi_images(&item["images"]).map(|mut images| {
                images.common = String::new();
                images
            });
            let career = item["career"]
                .as_array()
                .map(|values| {
                    values
                        .iter()
                        .filter_map(|value| value.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default();

            Some(BangumiPerson {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                relation: item["relation"].as_str().unwrap_or("").to_string(),
                career,
                person_type: json_i32(&item["type"]).unwrap_or(0),
                images,
            })
        })
        .collect()
}

/// Fetch persons (staff) for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/persons
pub(crate) async fn fetch_bangumi_persons(subject_id: i64) -> anyhow::Result<Vec<BangumiPerson>> {
    let url = format!(
        "{}/v0/subjects/{}/persons",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_bangumi_persons",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_persons(&json))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    #[test]
    fn persons_normalize_optional_fields_and_reject_invalid_identity() {
        let persons = parse_bangumi_persons(&json!([
            {"id": 1, "name": "Alice", "career": ["声优", null], "type": 2, "images": {}},
            {"id": 2, "name": "Overflow", "type": 2147483648_i64},
            {"id": 0, "name": "Missing id"},
            {"name": "Absent id"}
        ]));

        assert_eq!(persons.len(), 2);
        assert_eq!(persons[0].career, ["声优"]);
        assert_eq!(persons[0].images.as_ref().unwrap().common, "");
        assert_eq!(persons[1].person_type, 0);
        assert!(parse_bangumi_persons(&serde_json::Value::Null).is_empty());
    }

    #[tokio::test]
    async fn persons_fetch_maps_not_found_to_empty() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/subjects/7/persons",
            TestResponse::new(StatusCode::NOT_FOUND, "missing"),
        )])
        .await;
        {
            let mut config = crate::api::config::CONFIG.write().unwrap();
            config.bangumi_api_url = server.base_url();
            config.bangumi_url = server.base_url();
            config.bangumi_use_ech = false;
            config.bangumi_use_reverse_proxy = false;
        }

        assert!(fetch_bangumi_persons(7).await.unwrap().is_empty());
        server.shutdown().await;
    }
}
