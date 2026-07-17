use super::types::*;
use super::util::*;

/// Fetch persons (staff) for a subject
/// API: GET https://api.bgm.tv/v0/subjects/{subject_id}/persons
pub async fn fetch_bangumi_persons(subject_id: i64) -> anyhow::Result<Vec<BangumiPerson>> {
    let url = format!(
        "{}/v0/subjects/{}/persons",
        crate::api::config::get_bangumi_api_url(),
        subject_id
    );

    let resp = crate::api::network::retry_request_bangumi("fetch_bangumi_persons", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    if !resp.status().is_success() {
        return Ok(Vec::new());
    }

    let json: serde_json::Value = resp.json().await?;
    let mut persons = Vec::new();

    if let Some(data) = json.as_array() {
        for item in data {
            let images_data = &item["images"];
            let images = if !images_data.is_null() {
                parse_bangumi_images(images_data).map(|mut imgs| {
                    imgs.common = String::new();
                    imgs
                })
            } else {
                None
            };

            let career = item["career"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();

            let person = BangumiPerson {
                id: item["id"].as_i64().unwrap_or(0),
                name: item["name"].as_str().unwrap_or("").to_string(),
                relation: item["relation"].as_str().unwrap_or("").to_string(),
                career,
                person_type: item["type"].as_i64().unwrap_or(0) as i32,
                images,
            };

            persons.push(person);
        }
    }

    Ok(persons)
}
