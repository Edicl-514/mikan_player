use super::types::*;
use super::util::*;

pub async fn fetch_bangumi_characters(subject_id: i64) -> anyhow::Result<Vec<BangumiCharacter>> {
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

pub(super) async fn fetch_bangumi_characters_rest(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiCharacter>> {
    let url = format!(
        "{}/v0/subjects/{}/characters",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_characters", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(data) = json.as_array() {
        for item in data {
            let actors_data = item["actors"].as_array();

            let mut actors = Vec::new();
            if let Some(actors_arr) = actors_data {
                for actor in actors_arr {
                    actors.push(BangumiActor {
                        id: actor["id"].as_i64().unwrap_or(0),
                        name: actor["name"].as_str().unwrap_or("").to_string(),
                    });
                }
            }

            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data)
            } else {
                None
            };

            let character = BangumiCharacter {
                id: item["id"].as_i64().unwrap_or(0),
                name: item["name"].as_str().unwrap_or("").to_string(),
                role_name: item["relation"].as_str().unwrap_or("").to_string(),
                images,
                actors,
            };

            characters.push(character);
        }
    }

    Ok(characters)
}

pub(super) async fn fetch_bangumi_characters_next(
    subject_id: i64,
) -> anyhow::Result<Vec<BangumiCharacter>> {
    let url = format!(
        "{}/p1/subjects/{}/characters?limit=100&offset=0",
        crate::api::config::get_bangumi_next_url(),
        subject_id
    );

    let resp =
        crate::api::network::retry_request_bangumi("fetch_bangumi_characters.next", |client| {
            client.get(&url).header("accept", "application/json")
        })
        .await?;

    if !resp.status().is_success() {
        anyhow::bail!(
            "p1 characters request failed for subject_id={} status={}",
            subject_id,
            resp.status()
        );
    }

    let json: serde_json::Value = resp.json().await?;
    let mut characters = Vec::new();

    if let Some(data) = json["data"].as_array() {
        for item in data {
            let character_data = &item["character"];
            let role_type = item["type"].as_i64().unwrap_or(0);
            let role_name = map_character_role_type(role_type);

            let mut actors = Vec::new();
            if let Some(casts) = item["casts"].as_array() {
                for cast in casts {
                    let person = &cast["person"];
                    actors.push(BangumiActor {
                        id: person["id"].as_i64().unwrap_or(0),
                        name: person["name"].as_str().unwrap_or("").to_string(),
                    });
                }
            }

            let images_data = &character_data["images"];
            let images = if images_data.is_object() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            let character = BangumiCharacter {
                id: character_data["id"].as_i64().unwrap_or(0),
                name: character_data["name"].as_str().unwrap_or("").to_string(),
                role_name,
                images,
                actors,
            };

            characters.push(character);
        }
    }

    Ok(characters)
}
