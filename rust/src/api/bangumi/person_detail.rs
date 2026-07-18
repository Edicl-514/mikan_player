use super::types::*;
use super::util::*;

/// Fetch person details
/// API: GET https://api.bgm.tv/v0/persons/{person_id}
pub(crate) async fn fetch_person_details(person_id: i64) -> anyhow::Result<PersonDetails> {
    let url = format!(
        "{}/v0/persons/{}",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_person_details", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch person details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    let career = json["career"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    let stat_data = &json["stat"];
    let stat = CharacterStat {
        comments: stat_data["comments"].as_i64().unwrap_or(0) as i32,
        collects: stat_data["collects"].as_i64().unwrap_or(0) as i32,
    };

    let mut infobox = Vec::new();
    if let Some(infobox_arr) = json["infobox"].as_array() {
        for item in infobox_arr {
            let key = item["key"].as_str().unwrap_or("").to_string();
            let value = if let Some(v) = item["value"].as_str() {
                v.to_string()
            } else if let Some(arr) = item["value"].as_array() {
                arr.iter()
                    .filter_map(|v| {
                        if let Some(s) = v.as_str() {
                            Some(s.to_string())
                        } else if let Some(obj) = v.as_object() {
                            let k = obj.get("k").and_then(|x| x.as_str()).unwrap_or("");
                            let v = obj.get("v").and_then(|x| x.as_str()).unwrap_or("");
                            if !k.is_empty() && !v.is_empty() {
                                Some(format!("{}: {}", k, v))
                            } else if !v.is_empty() {
                                Some(v.to_string())
                            } else {
                                None
                            }
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()
                    .join(", ")
            } else {
                String::new()
            };
            if !key.is_empty() && !value.is_empty() {
                infobox.push(InfoboxItem { key, value });
            }
        }
    }

    Ok(PersonDetails {
        id: json["id"].as_i64().unwrap_or(person_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        img: normalize_image_url(json["img"].as_str()),
        career,
        person_type: json["type"].as_i64().unwrap_or(0) as i32,
        stat,
        infobox,
        locked: json["locked"].as_bool().unwrap_or(false),
    })
}

/// Fetch subjects for a person (only anime, type=2)
/// API: GET https://api.bgm.tv/v0/persons/{person_id}/subjects
pub(crate) async fn fetch_person_subjects(person_id: i64) -> anyhow::Result<Vec<PersonSubject>> {
    let url = format!(
        "{}/v0/persons/{}/subjects",
        crate::api::config::get_bangumi_api_url(),
        person_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_person_subjects", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut subjects = Vec::new();

    if let Some(arr) = json.as_array() {
        for item in arr {
            let subject_type = item["type"].as_i64().unwrap_or(0);
            if subject_type != 2 {
                continue;
            }

            let id = item["id"].as_i64().unwrap_or(0);
            if id == 0 {
                continue;
            }

            subjects.push(PersonSubject {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                image: normalize_image_url(item["image"].as_str()),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
                eps: item["eps"].as_str().unwrap_or("").to_string(),
            });
        }
    }

    Ok(subjects)
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

    let resp = crate::api::network::retry_request_bangumi("fetch_person_characters", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(arr) = json.as_array() {
        for item in arr {
            let subject_type = item["subject_type"].as_i64().unwrap_or(0);
            if subject_type != 2 {
                continue;
            }

            let id = item["id"].as_i64().unwrap_or(0);
            if id == 0 {
                continue;
            }

            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            characters.push(PersonCharacter {
                id,
                name: item["name"].as_str().unwrap_or("").to_string(),
                images,
                subject_id: item["subject_id"].as_i64().unwrap_or(0),
                subject_name: item["subject_name"].as_str().unwrap_or("").to_string(),
                subject_name_cn: item["subject_name_cn"].as_str().unwrap_or("").to_string(),
                staff: item["staff"].as_str().unwrap_or("").to_string(),
            });
        }
    }

    Ok(characters)
}
