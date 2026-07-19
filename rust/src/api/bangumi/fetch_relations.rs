use super::types::*;
use super::util::*;

const ALLOWED_RELATIONS: &[&str] = &["续集", "前传", "衍生", "番外篇", "主篇", "系列"];

fn parse_bangumi_relations(json: &serde_json::Value) -> Vec<BangumiRelatedSubject> {
    json.as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            if item["type"].as_i64() != Some(2) {
                return None;
            }
            let relation = item["relation"].as_str().unwrap_or("");
            if !ALLOWED_RELATIONS
                .iter()
                .any(|allowed| relation.contains(allowed))
            {
                return None;
            }
            let id = item["id"].as_i64().filter(|id| *id > 0)?;

            Some(BangumiRelatedSubject {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                relation: relation.to_string(),
                image: normalize_image_url(
                    item["images"]["large"]
                        .as_str()
                        .or_else(|| item["image"].as_str()),
                ),
            })
        })
        .collect()
}

/// Fetch related subjects for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/subjects
/// Only returns anime-related subjects (type 2) with specific relations
pub(crate) async fn fetch_bangumi_relations(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiRelatedSubject>> {
    let url = format!(
        "{}/v0/subjects/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_bangumi_relations",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_relations(&json))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    #[test]
    fn relations_keep_supported_anime_rows_and_filter_invalid_identity() {
        let _config = isolate_runtime_config();
        crate::api::config::set_bangumi_reverse_proxy(false);
        let relations = parse_bangumi_relations(&json!([
            {"id": 1, "type": 2, "relation": "续集", "name": "S2", "image": "//lain.bgm.tv/s2.jpg"},
            {"id": 2, "type": 2, "relation": "角色出演"},
            {"id": 3, "type": 1, "relation": "前传"},
            {"id": 0, "type": 2, "relation": "番外篇"},
            {"id": 4, "type": "2", "relation": "系列"}
        ]));

        assert_eq!(relations.len(), 1);
        assert_eq!(relations[0].id, 1);
        assert_eq!(relations[0].image, "https://lain.bgm.tv/s2.jpg");
        assert!(parse_bangumi_relations(&json!({})).is_empty());
    }

    #[tokio::test]
    async fn relations_fetch_maps_rate_limit_to_empty() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::get(
            "/v0/subjects/7/subjects",
            TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
        )])
        .await;
        {
            let mut config = crate::api::config::CONFIG.write().unwrap();
            config.bangumi_api_url = server.base_url();
            config.bangumi_url = server.base_url();
            config.bangumi_use_ech = false;
            config.bangumi_use_reverse_proxy = false;
        }

        assert!(fetch_bangumi_relations(7).await.unwrap().is_empty());
        server.shutdown().await;
    }
}
