use anyhow::Context;
use serde_json::Value;
use std::collections::HashMap;

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

    let resp = crate::api::network::retry_request(&label, |client| {
        client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("accept", "application/json")
            .json(&payload)
    })
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
            "failed to parse graphql response for {} with query {}",
            action_name, query
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
        .cloned()
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
                        "value": item["values"].clone(),
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
            if let Ok(score) = score_str.parse::<f64>() {
                rating.insert("score".to_string(), serde_json::json!(score));
            }
        }
    }

    let airtime_date = normalized
        .get("airtime")
        .and_then(|value| value.get("date"))
        .cloned()
        .unwrap_or(Value::Null);
    let total_episodes = normalized.get("eps").cloned().unwrap_or(Value::Null);
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
}
