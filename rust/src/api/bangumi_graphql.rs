use anyhow::Context;
use std::collections::HashMap;

// Re-export so `flutter_rust_bridge_codegen` regenerates `frb_generated.rs`
// with `Value` in scope. The generated file does
//   use crate::api::bangumi_graphql::*;
// and the auto-generated `SseDecode` impls reference the bare name `Value`.
#[allow(unused_imports)]
pub use serde_json::Value;

const BANGUMI_SUBJECT_GRAPHQL_BATCH_SIZE: usize = 20;
const BANGUMI_SUBJECT_GRAPHQL_FRAGMENT: &str = r#"
fragment SubjectFragment on Subject {
  id
  type
  name
  name_cn
  images { large common }
  episodes(limit: 100) {
    id
    type
    name
    name_cn
    airdate
    description
    duration
    sort
  }
  infobox {
    key
    values {
      k
      v
    }
  }
  summary
  eps
  collection { collect doing dropped on_hold wish }
  airtime { date }
  rating { count rank score total }
  nsfw
  tags { count name }
}
"#;

const BANGUMI_LIGHT_SUBJECT_GRAPHQL_FRAGMENT: &str = r#"
fragment Ep on Episode {
  id
  type
  name
  name_cn
  airdate
  sort
}

fragment LightSubjectFragment on Subject {
  id
  type
  name
  name_cn
  images { large }
  airtime { date }
  tags { count name }
  episodes(limit: 100) { ...Ep }
}
"#;

pub async fn execute_bangumi_graphql(
    action_name: &str,
    query: &str,
    variables: Value,
) -> anyhow::Result<Value> {
    let url = format!("{}/v0/graphql", crate::api::config::get_bangumi_api_url());
    let payload = serde_json::json!({
        "query": query,
        "variables": variables,
    });
    let label = format!("{}.request", action_name);

    let resp = crate::api::network::retry_request_bangumi_with_status(
        &label,
        |client| {
            client
                .post(&url)
                .header("Content-Type", "application/json")
                .header("accept", "application/json")
                .json(&payload)
        },
        true,
    )
    .await?;

    let status = resp.status();
    let body = resp
        .text()
        .await
        .with_context(|| format!("failed to read graphql response body for {}", action_name))?;

    if !status.is_success() {
        log::warn!(
            "bangumi graphql request returned non-success status action={} status={} body={}",
            action_name,
            status,
            body
        );
    }

    serde_json::from_str::<Value>(&body).with_context(|| {
        format!(
            "failed to parse graphql response for {} status={} body={}",
            action_name,
            status,
            body.chars().take(256).collect::<String>()
        )
    })
}

pub async fn fetch_subject_details_graphql_batch(ids: &[i64]) -> HashMap<i64, Value> {
    let mut results = HashMap::new();

    for chunk in ids.chunks(BANGUMI_SUBJECT_GRAPHQL_BATCH_SIZE) {
        let query = build_subject_batch_graphql_query(chunk.len());
        let mut variables = serde_json::Map::new();
        for (index, id) in chunk.iter().enumerate() {
            variables.insert(format!("id{}", index), serde_json::json!(id));
        }

        let raw = match execute_bangumi_graphql(
            "bangumi.graphql.subject_batch",
            &query,
            Value::Object(variables),
        )
        .await
        {
            Ok(raw) => raw,
            Err(err) => {
                log::warn!(
                    "fill_anime_details graphql chunk failed ids={:?} error={}",
                    chunk,
                    err
                );
                continue;
            }
        };

        if let Some(errors) = raw["errors"].as_array().filter(|errors| !errors.is_empty()) {
            log::warn!(
                "fill_anime_details graphql returned errors ids={:?} errors={}",
                chunk,
                Value::Array(errors.clone())
            );
        }

        let Some(data) = raw["data"].as_object() else {
            log::warn!(
                "fill_anime_details graphql missing data ids={:?} payload={}",
                chunk,
                raw
            );
            continue;
        };

        for (index, id) in chunk.iter().enumerate() {
            let key = format!("s{}", index);
            if let Some(subject) = data.get(&key).filter(|subject| !subject.is_null()) {
                results.insert(*id, normalize_graphql_subject_json(subject));
            }
        }
    }

    results
}

pub async fn fetch_light_subject_details_graphql(subject_id: i64) -> anyhow::Result<Value> {
    let query = format!(
        "{}\nquery LightSubjectQuery($id: Int!) {{\n  subject(id: $id) {{ ...LightSubjectFragment }}\n}}",
        BANGUMI_LIGHT_SUBJECT_GRAPHQL_FRAGMENT
    );
    let raw = execute_bangumi_graphql(
        "bangumi.graphql.light_subject",
        &query,
        serde_json::json!({ "id": subject_id }),
    )
    .await?;

    if let Some(errors) = raw["errors"].as_array().filter(|errors| !errors.is_empty()) {
        log::warn!(
            "bangumi graphql light subject returned errors subject_id={} errors={}",
            subject_id,
            Value::Array(errors.clone())
        );
    }

    let Some(data) = raw["data"].as_object() else {
        anyhow::bail!(
            "bangumi graphql light subject missing data subject_id={} payload={}",
            subject_id,
            raw
        );
    };

    let subject = data
        .get("subject")
        .filter(|subject| !subject.is_null())
        .ok_or_else(|| {
            anyhow::anyhow!(
                "bangumi graphql light subject returned null for subject_id={}",
                subject_id
            )
        })?;

    Ok(subject.clone())
}

pub fn normalize_light_subject_graphql_json(subject: &Value) -> Value {
    let mut normalized = subject.as_object().cloned().unwrap_or_default();

    let meta_tags = subject["tags"]
        .as_array()
        .map(|tags| {
            tags.iter()
                .filter_map(|tag| tag["name"].as_str().map(|name| name.to_string()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    if let Some(images) = normalized
        .get_mut("images")
        .and_then(|value| value.as_object_mut())
    {
        remap_image_field(images, "large");
        if images.get("large").is_none() {
            images.insert("large".to_string(), Value::String(String::new()));
        }
    }

    let airtime_date = normalized
        .get("airtime")
        .and_then(|value| value.get("date"))
        .and_then(|value| value.as_str())
        .map(|value| Value::String(value.to_string()))
        .unwrap_or(Value::Null);

    let episodes = normalized
        .get("episodes")
        .and_then(|value| value.as_array())
        .cloned()
        .unwrap_or_default();

    normalized.insert("date".to_string(), airtime_date);
    normalized.insert("meta_tags".to_string(), serde_json::json!(meta_tags));
    normalized.insert("episodes".to_string(), Value::Array(episodes));

    Value::Object(normalized)
}

pub fn normalize_graphql_subject_json(subject: &Value) -> Value {
    let mut normalized = subject.as_object().cloned().unwrap_or_default();

    let normalized_infobox = subject["infobox"]
        .as_array()
        .map(|items| {
            items
                .iter()
                .map(|item| {
                    serde_json::json!({
                        "key": item["key"].as_str().unwrap_or(""),
                        "value": item["values"].as_array().cloned().unwrap_or_default(),
                    })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    let meta_tags = subject["tags"]
        .as_array()
        .map(|tags| {
            tags.iter()
                .filter_map(|tag| tag["name"].as_str().map(|name| name.to_string()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    if let Some(images) = normalized
        .get_mut("images")
        .and_then(|value| value.as_object_mut())
    {
        remap_image_field(images, "large");
        remap_image_field(images, "common");
        if images.get("large").is_none() {
            images.insert("large".to_string(), Value::String(String::new()));
        }
        if images.get("common").is_none() {
            images.insert("common".to_string(), Value::String(String::new()));
        }
    }

    if let Some(rating) = normalized
        .get_mut("rating")
        .and_then(|value| value.as_object_mut())
    {
        if let Some(score_str) = rating.get("score").and_then(|value| value.as_str()) {
            let score = score_str
                .parse::<f64>()
                .ok()
                .filter(|score| score.is_finite())
                .map(|score| serde_json::json!(score))
                .unwrap_or(Value::Null);
            rating.insert("score".to_string(), score);
        }
    }

    let airtime_date = normalized
        .get("airtime")
        .and_then(|value| value.get("date"))
        .and_then(|value| value.as_str())
        .map(|value| Value::String(value.to_string()))
        .unwrap_or(Value::Null);
    let total_episodes = normalized
        .get("eps")
        .and_then(|value| value.as_i64())
        .map(|value| serde_json::json!(value))
        .unwrap_or(Value::Null);
    let episodes = normalized
        .get("episodes")
        .and_then(|value| value.as_array())
        .cloned()
        .unwrap_or_default();

    normalized.insert("infobox".to_string(), Value::Array(normalized_infobox));
    normalized.insert("meta_tags".to_string(), serde_json::json!(meta_tags));
    normalized.insert("date".to_string(), airtime_date);
    normalized.insert("total_episodes".to_string(), total_episodes);
    normalized.insert("episodes".to_string(), Value::Array(episodes));

    Value::Object(normalized)
}

fn remap_image_field(images: &mut serde_json::Map<String, Value>, key: &str) {
    if let Some(value) = images.get(key).and_then(|value| value.as_str()) {
        let rewritten = crate::api::config::rewrite_bangumi_url_if_proxied(value);
        if rewritten != value {
            images.insert(key.to_string(), Value::String(rewritten));
        }
    }
}

fn build_subject_batch_graphql_query(size: usize) -> String {
    let mut query = String::from(BANGUMI_SUBJECT_GRAPHQL_FRAGMENT);
    query.push_str("query BatchGetSubjectQuery(");

    for i in 0..size {
        if i > 0 {
            query.push_str(", ");
        }
        query.push_str(&format!("$id{}: Int!", i));
    }

    query.push_str(") {\n");
    for i in 0..size {
        query.push_str(&format!(
            "  s{}: subject(id: $id{}) {{ ...SubjectFragment }}\n",
            i, i
        ));
    }
    query.push('}');
    query
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::{Method, StatusCode};

    fn point_bangumi_at(base_url: &str) {
        let mut config = crate::api::config::CONFIG.write().unwrap();
        config.bangumi_api_url = base_url.to_string();
        config.bangumi_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn normalize_graphql_subject_json_matches_existing_consumers() {
        let input = serde_json::json!({
            "id": 543360,
            "name": "Test",
            "name_cn": "测试",
            "images": {
                "large": "https://example.com/large.jpg",
                "common": "https://example.com/common.jpg"
            },
            "infobox": [
                {
                    "key": "别名",
                    "values": [
                        { "k": null, "v": "Alias A" },
                        { "k": null, "v": "Alias B" }
                    ]
                }
            ],
            "summary": "Summary",
            "eps": 12,
            "collection": {
                "collect": 1,
                "doing": 2,
                "dropped": 3,
                "on_hold": 4,
                "wish": 5
            },
            "airtime": { "date": "2026-04-10" },
            "rating": {
                "count": [0,0,0,0,0,0,0,0,0,0],
                "rank": 7,
                "score": "7.58",
                "total": 99
            },
            "nsfw": false,
            "tags": [
                { "count": 10, "name": "百合" },
                { "count": 8, "name": "日常" }
            ]
        });

        let normalized = normalize_graphql_subject_json(&input);

        assert_eq!(normalized["rating"]["score"].as_f64(), Some(7.58));
        assert_eq!(normalized["date"].as_str(), Some("2026-04-10"));
        assert_eq!(normalized["total_episodes"].as_i64(), Some(12));
        assert_eq!(normalized["meta_tags"][0].as_str(), Some("百合"));
        assert_eq!(normalized["infobox"][0]["key"].as_str(), Some("别名"));
        assert!(normalized["infobox"][0]["value"].is_array());
        assert_eq!(
            normalized["infobox"][0]["value"][0]["v"].as_str(),
            Some("Alias A")
        );
    }

    #[test]
    fn normalize_light_subject_graphql_json_preserves_tags() {
        let input = serde_json::json!({
            "id": 543360,
            "name": "Test",
            "name_cn": "测试",
            "images": {
                "large": "https://example.com/large.jpg"
            },
            "airtime": { "date": "2026-04-10" },
            "tags": [
                { "count": 10, "name": "百合" },
                { "count": 8, "name": "日常" }
            ],
            "episodes": []
        });

        let normalized = normalize_light_subject_graphql_json(&input);

        assert_eq!(normalized["date"].as_str(), Some("2026-04-10"));
        assert_eq!(normalized["meta_tags"][0].as_str(), Some("百合"));
        assert_eq!(normalized["meta_tags"][1].as_str(), Some("日常"));
    }

    #[test]
    fn graphql_normalizers_stabilize_missing_and_type_changed_fields() {
        let normalized = normalize_graphql_subject_json(&serde_json::json!({
            "images": {},
            "infobox": [{"key": "别名", "values": null}],
            "tags": [{"name": "valid"}, {"name": null}],
            "rating": {"score": "NaN"},
            "airtime": {"date": 20260719},
            "eps": "12",
            "episodes": null
        }));
        assert_eq!(normalized["images"]["large"], "");
        assert_eq!(normalized["images"]["common"], "");
        assert!(
            normalized["infobox"][0]["value"]
                .as_array()
                .unwrap()
                .is_empty()
        );
        assert_eq!(normalized["meta_tags"], serde_json::json!(["valid"]));
        assert!(normalized["rating"]["score"].is_null());
        assert!(normalized["date"].is_null());
        assert!(normalized["total_episodes"].is_null());
        assert!(normalized["episodes"].as_array().unwrap().is_empty());

        let light = normalize_light_subject_graphql_json(&serde_json::json!({
            "images": {}, "airtime": {"date": false}, "tags": null, "episodes": null
        }));
        assert_eq!(light["images"]["large"], "");
        assert!(light["date"].is_null());
        assert!(light["meta_tags"].as_array().unwrap().is_empty());
        assert!(light["episodes"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn execute_graphql_preserves_json_error_body_on_http_error() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::post(
            "/v0/graphql",
            TestResponse::new(
                StatusCode::TOO_MANY_REQUESTS,
                serde_json::json!({"errors": [{"message": "rate limited"}]}).to_string(),
            ),
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let raw = execute_bangumi_graphql("test.graphql", "query Test { ping }", Value::Null)
            .await
            .unwrap();
        assert_eq!(raw["errors"][0]["message"], "rate limited");
        let request = &server.requests()[0];
        assert_eq!(request.headers["content-type"], "application/json");
        let body: Value = serde_json::from_slice(&request.body).unwrap();
        assert_eq!(body["query"], "query Test { ping }");
        server.shutdown().await;
    }

    #[tokio::test]
    async fn graphql_batch_keeps_partial_data_and_chunks_over_twenty_ids() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::sequence(
            Method::POST,
            "/v0/graphql",
            [
                TestResponse::ok(
                    serde_json::json!({
                        "errors": [{"message": "s1 unavailable"}],
                        "data": {"s0": {"id": 1, "eps": 12, "tags": []}, "s1": null}
                    })
                    .to_string(),
                ),
                TestResponse::ok(
                    serde_json::json!({"data": {"s0": {"id": 21, "eps": 1, "tags": []}}})
                        .to_string(),
                ),
            ],
        )])
        .await;
        point_bangumi_at(&server.base_url());

        let ids = (1..=21).collect::<Vec<_>>();
        let results = fetch_subject_details_graphql_batch(&ids).await;
        assert_eq!(results.len(), 2);
        assert_eq!(results[&1]["total_episodes"], 12);
        assert_eq!(results[&21]["total_episodes"], 1);
        let requests = server.requests();
        assert_eq!(requests.len(), 2);
        let first_body: Value = serde_json::from_slice(&requests[0].body).unwrap();
        let second_body: Value = serde_json::from_slice(&requests[1].body).unwrap();
        assert_eq!(first_body["variables"]["id19"], 20);
        assert_eq!(second_body["variables"]["id0"], 21);
        server.shutdown().await;
    }

    #[tokio::test]
    async fn light_graphql_accepts_partial_success_and_rejects_missing_subject() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::sequence(
            Method::POST,
            "/v0/graphql",
            [
                TestResponse::ok(
                    serde_json::json!({
                        "errors": [{"message": "optional field failed"}],
                        "data": {"subject": {"id": 7, "tags": []}}
                    })
                    .to_string(),
                ),
                TestResponse::ok(serde_json::json!({"data": {"subject": null}}).to_string()),
            ],
        )])
        .await;
        point_bangumi_at(&server.base_url());

        assert_eq!(
            fetch_light_subject_details_graphql(7).await.unwrap()["id"],
            7
        );
        let error = fetch_light_subject_details_graphql(8).await.unwrap_err();
        assert!(error.to_string().contains("returned null"));
        server.shutdown().await;
    }
}
