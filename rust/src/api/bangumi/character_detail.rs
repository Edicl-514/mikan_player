use super::types::*;
use super::util::*;

/// Fetch character details
/// API: GET https://api.bgm.tv/v0/characters/{character_id}
pub async fn fetch_character_details(character_id: i64) -> anyhow::Result<CharacterDetails> {
    let url = format!(
        "{}/v0/characters/{}",
        crate::api::config::get_bangumi_api_url(),
        character_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_character_details", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Err(anyhow::anyhow!(
            "Failed to fetch character details: {}",
            resp.status()
        ));
    }

    let json: serde_json::Value = resp.json().await?;

    // Parse images
    let images_data = &json["images"];
    let images = if !images_data.is_null() {
        parse_bangumi_images(images_data)
    } else {
        None
    };

    // Parse stat
    let stat_data = &json["stat"];
    let stat = CharacterStat {
        comments: stat_data["comments"].as_i64().unwrap_or(0) as i32,
        collects: stat_data["collects"].as_i64().unwrap_or(0) as i32,
    };

    // Parse infobox
    let mut infobox = Vec::new();
    if let Some(infobox_arr) = json["infobox"].as_array() {
        for item in infobox_arr {
            let key = item["key"].as_str().unwrap_or("").to_string();
            let value = if let Some(v) = item["value"].as_str() {
                v.to_string()
            } else if let Some(arr) = item["value"].as_array() {
                // Handle array values (like aliases)
                arr.iter()
                    .filter_map(|v| {
                        if let Some(s) = v.as_str() {
                            Some(s.to_string())
                        } else if let Some(obj) = v.as_object() {
                            // Handle objects with "k" and "v" keys
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

    Ok(CharacterDetails {
        id: json["id"].as_i64().unwrap_or(character_id),
        name: json["name"].as_str().unwrap_or("").to_string(),
        summary: json["summary"].as_str().unwrap_or("").to_string(),
        images,
        gender: json["gender"].as_str().map(|s| s.to_string()),
        birth_year: json["birth_year"].as_i64().map(|v| v as i32),
        birth_mon: json["birth_mon"].as_i64().map(|v| v as i32),
        birth_day: json["birth_day"].as_i64().map(|v| v as i32),
        blood_type: json["blood_type"].as_str().map(|s| s.to_string()),
        stat,
        infobox,
    })
}
/// Fetch character subjects and persons, merging them
/// APIs:
/// - GET https://api.bgm.tv/v0/characters/{character_id}/subjects
/// - GET https://api.bgm.tv/v0/characters/{character_id}/persons
/// Returns only anime subjects (type=2) with associated voice actors
pub async fn fetch_character_subjects(character_id: i64) -> anyhow::Result<Vec<CharacterSubject>> {
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
        crate::api::network::retry_request_bangumi("fetch_character_subjects/subjects", |client| {
            client
                .get(&subjects_url)
                .header("accept", "application/json")
        },),
        crate::api::network::retry_request_bangumi("fetch_character_subjects/persons", |client| {
            client
                .get(&persons_url)
                .header("accept", "application/json")
        },)
    );

    // Parse subjects (only type=2 anime)
    let mut subjects_map: std::collections::HashMap<i64, CharacterSubject> =
        std::collections::HashMap::new();

    if let Ok(resp) = subjects_resp {
        if resp.status().is_success() {
            if let Ok(json) = resp.json::<serde_json::Value>().await {
                if let Some(arr) = json.as_array() {
                    for item in arr {
                        let subject_type = item["type"].as_i64().unwrap_or(0);
                        // Only include anime (type=2)
                        if subject_type != 2 {
                            continue;
                        }

                        let id = item["id"].as_i64().unwrap_or(0);
                        if id == 0 {
                            continue;
                        }

                        // `/characters/{id}/subjects` returns a top-level `image` field.
                        // Keep a fallback to nested `images.*` in case the upstream API shape
                        // changes or mirrors another subject schema in the future.
                        let image = normalize_image_url(
                            item["image"]
                                .as_str()
                                .or_else(|| item["images"]["large"].as_str())
                                .or_else(|| item["images"]["medium"].as_str())
                                .or_else(|| item["images"]["small"].as_str()),
                        );

                        let subject = CharacterSubject {
                            id,
                            name: item["name"].as_str().unwrap_or("").to_string(),
                            name_cn: item["name_cn"].as_str().unwrap_or("").to_string(),
                            image,
                            staff: item["staff"].as_str().unwrap_or("").to_string(),
                            persons: Vec::new(),
                        };
                        subjects_map.insert(id, subject);
                    }
                }
            }
        }
    }

    // Parse persons and associate with subjects
    if let Ok(resp) = persons_resp {
        if resp.status().is_success() {
            if let Ok(json) = resp.json::<serde_json::Value>().await {
                if let Some(arr) = json.as_array() {
                    for item in arr {
                        let subject_id = item["subject_id"].as_i64().unwrap_or(0);
                        if subject_id == 0 {
                            continue;
                        }

                        // Only associate if we have this subject in our map
                        if let Some(subject) = subjects_map.get_mut(&subject_id) {
                            let images_data = &item["images"];
                            let images = if !images_data.is_null() {
                                parse_bangumi_images(images_data).map(|mut imgs| {
                                    imgs.common = String::new();
                                    imgs
                                })
                            } else {
                                None
                            };

                            let person = CharacterSubjectPerson {
                                id: item["id"].as_i64().unwrap_or(0),
                                name: item["name"].as_str().unwrap_or("").to_string(),
                                images,
                            };
                            subject.persons.push(person);
                        }
                    }
                }
            }
        }
    }

    // Convert map to vec and sort by id (newest first)
    let mut result: Vec<CharacterSubject> = subjects_map.into_values().collect();
    result.sort_by(|a, b| b.id.cmp(&a.id));

    Ok(result)
}

// ============================================================================
