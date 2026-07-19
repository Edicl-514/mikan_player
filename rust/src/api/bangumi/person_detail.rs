use super::types::*;
use super::util::*;

fn parse_person_details(json: &serde_json::Value, person_id: i64) -> PersonDetails {
    PersonDetails {
        id: json["id"].as_i64().unwrap_or(person_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        img: normalize_image_url(json["img"].as_str()),
        career: json["career"]
            .as_array()
            .map(|values| {
                values
                    .iter()
                    .filter_map(|value| value.as_str().map(str::to_string))
                    .collect()
            })
            .unwrap_or_default(),
        person_type: json_i32(&json["type"]).unwrap_or(0),
        stat: CharacterStat {
            comments: json_i32(&json["stat"]["comments"]).unwrap_or(0),
            collects: json_i32(&json["stat"]["collects"]).unwrap_or(0),
        },
        infobox: parse_infobox(&json["infobox"]),
        locked: json["locked"].as_bool().unwrap_or(false),
    }
}

fn parse_person_subjects(json: &serde_json::Value) -> Vec<PersonSubject> {
    json.as_array()
        .into_iter()
        .flatten()
        .filter(|item| item["type"].as_i64() == Some(2))
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            Some(PersonSubject {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                image: normalize_image_url(item["image"].as_str()),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
                eps: item["eps"].as_str().unwrap_or("").to_string(),
            })
        })
        .collect()
}

fn parse_person_characters(json: &serde_json::Value) -> Vec<PersonCharacter> {
    json.as_array()
        .into_iter()
        .flatten()
        .filter(|item| item["subject_type"].as_i64() == Some(2))
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            let images = parse_bangumi_images(&item["images"]).map(|mut images| {
                images.common = String::new();
                images
            });
            Some(PersonCharacter {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                images,
                subject_id: item["subject_id"].as_i64().unwrap_or(0),
                subject_name: item["subject_name"].as_str().unwrap_or("").to_string(),
                subject_name_cn: item["subject_name_cn"].as_str().unwrap_or("").to_string(),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
            })
        })
        .collect()
}

/// Fetch person details
/// API: GET https://api.bgm.tv/v0/persons/{person_id}
pub(crate) async fn fetch_person_details(person_id: i64) -> anyhow::Result<PersonDetails> {
    let url = format!(
        "{}/v0/persons/{}",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_person_details",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch person details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    Ok(parse_person_details(&json, person_id))
}

/// Fetch subjects for a person (only anime, type=2)
/// API: GET https://api.bgm.tv/v0/persons/{person_id}/subjects
pub(crate) async fn fetch_person_subjects(person_id: i64) -> anyhow::Result<Vec<PersonSubject>> {
    let url = format!(
        "{}/v0/persons/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_person_subjects",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_person_subjects(&json))
}

/// Fetch characters voiced/played by a person (only anime subjects, subject_type=2)
/// API: GET https://api.bgm.tv/v0/persons/{person_id}/characters
pub(crate) async fn fetch_person_characters(
    person_id: i64,
) -> anyhow::Result<Vec<PersonCharacter>> {
    let url = format!(
        "{}/v0/persons/{}/characters",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi_with_status(
        "fetch_person_characters",
        |client| client.get(&url).header("accept", "application/json"),
        true,
    )
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_person_characters(&json))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::StatusCode;
    use serde_json::json;

    #[test]
    fn person_details_normalize_type_changes_and_mixed_infobox() {
        let details = parse_person_details(
            &json!({
                "name": "声优 & Staff",
                "career": ["声优", null, 7, "歌手"],
                "type": 2147483648_i64,
                "stat": {"comments": "1", "collects": 2},
                "infobox": [{"key": "别名", "value": [{"v": "Alias"}]}],
                "locked": "false"
            }),
            88,
        );

        assert_eq!(details.id, 88);
        assert_eq!(details.career, ["声优", "歌手"]);
        assert_eq!(details.person_type, 0);
        assert_eq!(details.stat.comments, 0);
        assert_eq!(details.stat.collects, 2);
        assert_eq!(details.infobox[0].value, "Alias");
        assert!(!details.locked);
    }

    #[test]
    fn person_subject_and_character_lists_filter_non_anime_and_missing_ids() {
        let subjects = parse_person_subjects(&json!([
            {"id": 1, "type": 2, "name": "Anime", "eps": 12},
            {"id": 0, "type": 2, "name": "Missing"},
            {"id": 2, "type": 1, "name": "Book"}
        ]));
        assert_eq!(subjects.len(), 1);
        assert_eq!(subjects[0].eps, "");

        let characters = parse_person_characters(&json!([
            {"id": 3, "subject_type": 2, "name": "角色", "images": null},
            {"id": 0, "subject_type": 2},
            {"id": 4, "subject_type": "2"}
        ]));
        assert_eq!(characters.len(), 1);
        assert_eq!(characters[0].id, 3);
        assert!(characters[0].images.is_none());
        assert!(parse_person_subjects(&serde_json::Value::Null).is_empty());
    }

    #[tokio::test]
    async fn person_fetch_uses_custom_detail_error_and_empty_list_fallbacks() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([
            TestRoute::get(
                "/v0/persons/7",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
            TestRoute::get(
                "/v0/persons/7/subjects",
                TestResponse::new(StatusCode::TOO_MANY_REQUESTS, "rate limited"),
            ),
            TestRoute::get(
                "/v0/persons/7/characters",
                TestResponse::new(StatusCode::NOT_FOUND, "missing"),
            ),
        ])
        .await;
        {
            let mut config = crate::api::config::CONFIG.write().unwrap();
            config.bangumi_api_url = server.base_url();
            config.bangumi_url = server.base_url();
            config.bangumi_use_ech = false;
            config.bangumi_use_reverse_proxy = false;
        }

        assert!(
            fetch_person_details(7)
                .await
                .unwrap_err()
                .to_string()
                .contains("Failed to fetch person details: 404")
        );
        assert!(fetch_person_subjects(7).await.unwrap().is_empty());
        assert!(fetch_person_characters(7).await.unwrap().is_empty());
        server.shutdown().await;
    }
}
