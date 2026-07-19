use super::types::*;
use super::util::*;

fn parse_character_details(json: &serde_json::Value, character_id: i64) -> CharacterDetails {
    let images = parse_bangumi_images(&json["images"]);
    let stat = CharacterStat {
        comments: json_i32(&json["stat"]["comments"]).unwrap_or(0),
        collects: json_i32(&json["stat"]["collects"]).unwrap_or(0),
    };

    CharacterDetails {
        id: json["id"].as_i64().unwrap_or(character_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        images,
        gender: json["gender"].as_str().map(str::to_string),
        birth_year: json_i32(&json["birth_year"]),
        birth_mon: json_i32(&json["birth_mon"]),
        birth_day: json_i32(&json["birth_day"]),
        blood_type: json["blood_type"].as_str().map(str::to_string),
        stat,
        infobox: parse_infobox(&json["infobox"]),
    }
}

fn parse_character_subjects(
    subjects_json: &serde_json::Value,
    persons_json: &serde_json::Value,
) -> Vec<CharacterSubject> {
    let mut subjects_map = std::collections::HashMap::new();

    if let Some(subjects) = subjects_json.as_array() {
        for item in subjects {
            if item["type"].as_i64() != Some(2) {
                continue;
            }

            let Some(id) = item["id"].as_i64().filter(|id| *id > 0) else {
                continue;
            };
            let image = normalize_image_url(
                item["image"]
                    .as_str()
                    .or_else(|| item["images"]["large"].as_str())
                    .or_else(|| item["images"]["medium"].as_str())
                    .or_else(|| item["images"]["small"].as_str()),
            );

            subjects_map.insert(
                id,
                CharacterSubject {
                    id,
                    name: item["name"].as_str().unwrap_or("").to_string(),
                    name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                    image,
                    staff: item["staff"].as_str().unwrap_or("").to_string(),
                    persons: Vec::new(),
                },
            );
        }
    }

    if let Some(persons) = persons_json.as_array() {
        for item in persons {
            let Some(subject) = item["subject_id"]
                .as_i64()
                .and_then(|subject_id| subjects_map.get_mut(&subject_id))
            else {
                continue;
            };
            let Some(id) = item["id"].as_i64().filter(|id| *id > 0) else {
                continue;
            };

            let images = parse_bangumi_images(&item["images"]).map(|mut images| {
                images.common = String::new();
                images
            });
            subject.persons.push(CharacterSubjectPerson {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                images,
            });
        }
    }

    let mut result: Vec<_> = subjects_map.into_values().collect();
    result.sort_by(|a, b| b.id.cmp(&a.id));
    result
}

/// Fetch character details
/// API: GET https://api.bgm.tv/v0/characters/{character_id}
pub(crate) async fn fetch_character_details(character_id: i64) -> anyhow::Result<CharacterDetails> {
    let url = format!(
        "{}/v0/characters/{}",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_character_details",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch character details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    Ok(parse_character_details(&json, character_id))
}
/// Fetch character subjects and persons, merging them
/// APIs:
/// - GET https://api.bgm.tv/v0/characters/{character_id}/subjects
/// - GET https://api.bgm.tv/v0/characters/{character_id}/persons
/// Returns only anime subjects (type=2) with associated voice actors
pub(crate) async fn fetch_character_subjects(
    character_id: i64,
) -> anyhow::Result<Vec<CharacterSubject>> {
    let subjects_url = format!(
        "{}/v0/characters/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );
    let persons_url = format!(
        "{}/v0/characters/{}/persons",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );

    let (subjects_resp, persons_resp) = tokio::join!(
        crate::api::network::retry_request_bangumi_with_status(
            "fetch_character_subjects/subjects",
            |client| client
                .get(&subjects_url)
                .header("accept", "application/json"),
            true,
        ),
        crate::api::network::retry_request_bangumi_with_status(
            "fetch_character_subjects/persons",
            |client| client
                .get(&persons_url)
                .header("accept", "application/json"),
            true,
        )
    );

    let subjects_json = match subjects_resp {
        Ok(resp) if resp.status().is_success() => resp.json().await.unwrap_or_default(),
        _ => serde_json::Value::Null,
    };
    let persons_json = match persons_resp {
        Ok(resp) if resp.status().is_success() => resp.json().await.unwrap_or_default(),
        _ => serde_json::Value::Null,
    };

    Ok(parse_character_subjects(&subjects_json, &persons_json))
}

// ============================================================================

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
        config.bangumi_url = base_url.to_string();
        config.bangumi_use_ech = false;
        config.bangumi_use_reverse_proxy = false;
    }

    #[test]
    fn character_details_normalize_missing_types_and_infobox_values() {
        let details = parse_character_details(
            &json!({
                "name": "角色 <script>",
                "summary": null,
                "images": null,
                "birth_year": 2147483648_i64,
                "birth_mon": "7",
                "stat": {"comments": 5, "collects": 2147483648_i64},
                "infobox": [{"key": "别名", "value": ["A", {"k": "日文", "v": "B"}]}]
            }),
            77,
        );

        assert_eq!(details.id, 77);
        assert_eq!(details.name, "角色 <script>");
        assert_eq!(details.summary, "");
        assert!(details.images.is_none());
        assert_eq!(details.birth_year, None);
        assert_eq!(details.birth_mon, None);
        assert_eq!(details.stat.comments, 5);
        assert_eq!(details.stat.collects, 0);
        assert_eq!(details.infobox[0].value, "A, 日文: B");
    }

    #[test]
    fn character_subjects_merge_partial_data_filter_invalid_rows_and_sort() {
        let subjects = json!([
            {"id": 10, "type": 2, "name": "Old", "image": "/img/old.jpg", "staff": "主角"},
            {"id": 20, "type": 2, "name": "New", "images": {"medium": "//lain.bgm.tv/new.jpg"}},
            {"id": 0, "type": 2, "name": "Missing id"},
            {"id": 30, "type": 1, "name": "Book"}
        ]);
        let persons = json!([
            {"id": 8, "subject_id": 10, "name": "Actor", "images": {}},
            {"id": 0, "subject_id": 10, "name": "Missing id"},
            {"id": 9, "subject_id": 999, "name": "Unmatched"}
        ]);

        let parsed = parse_character_subjects(&subjects, &persons);
        assert_eq!(
            parsed.iter().map(|item| item.id).collect::<Vec<_>>(),
            [20, 10]
        );
        assert_eq!(parsed[1].persons.len(), 1);
        assert_eq!(parsed[1].persons[0].id, 8);
        assert!(
            parse_character_subjects(&subjects, &serde_json::Value::Null)[1]
                .persons
                .is_empty()
        );
    }

    #[tokio::test]
    async fn character_subject_fetch_keeps_subjects_when_persons_endpoint_is_rate_limited() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/v0/characters/7/subjects",
                TestResponse::ok(json!([{"id": 10, "type": 2, "name": "Anime"}]).to_string()),
            ),
            TestRoute::get(
                "/v0/characters/7/persons",
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ),
            TestRoute::get(
                "/v0/characters/8",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
        ])
        .await;
        point_bangumi_at(&server.base_url());

        let subjects = fetch_character_subjects(7).await.unwrap();
        assert_eq!(subjects.len(), 1);
        assert!(subjects[0].persons.is_empty());
        let error = fetch_character_details(8).await.unwrap_err();
        assert!(
            error
                .to_string()
                .contains("Failed to fetch character details: 404")
        );
        server.shutdown().await;
    }
}
