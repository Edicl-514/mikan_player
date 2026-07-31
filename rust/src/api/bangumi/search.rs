use super::types::*;
use super::util::*;
use serde_json::json;

const BANGUMI_NEXT_SEARCH_PAGE_SIZE: i64 = 20;

/// Search characters through `POST /p1/search/characters`.
pub(crate) async fn search_bangumi_characters(
    keyword: String,
    page: i32,
) -> anyhow::Result<Vec<BangumiCharacterSearchResult>> {
    let json = search_bangumi_next("characters", keyword, page).await?;
    Ok(parse_character_search_results(&json))
}

/// Search persons through `POST /p1/search/persons`.
pub(crate) async fn search_bangumi_persons(
    keyword: String,
    page: i32,
) -> anyhow::Result<Vec<BangumiPersonSearchResult>> {
    let json = search_bangumi_next("persons", keyword, page).await?;
    Ok(parse_person_search_results(&json))
}

async fn search_bangumi_next(
    kind: &str,
    keyword: String,
    page: i32,
) -> anyhow::Result<serde_json::Value> {
    let offset = (i64::from(page.max(1)) - 1) * BANGUMI_NEXT_SEARCH_PAGE_SIZE;
    let (base_url, access_token, _) = bangumi_next_request("");
    let url = format!(
        "{base_url}/p1/search/{kind}?limit={BANGUMI_NEXT_SEARCH_PAGE_SIZE}&offset={offset}"
    );
    let body = json!({ "keyword": keyword });

    let resp = crate::api::network::retry_request_bangumi(
        &format!("bangumi.search.{kind}.next"),
        move |client| {
            let request = client
                .post(&url)
                .header("accept", "application/json")
                .json(&body);
            match &access_token {
                Some(token) => request.header("Authorization", format!("Bearer {token}")),
                None => request,
            }
        },
    )
    .await?;

    Ok(resp.json().await?)
}

fn parse_character_search_results(json: &serde_json::Value) -> Vec<BangumiCharacterSearchResult> {
    json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            Some(BangumiCharacterSearchResult {
                id,
                name: item["name"].as_str().unwrap_or_default().to_string(),
                name_cn: item["nameCN"].as_str().unwrap_or_default().to_string(),
                role: json_i32(&item["role"]).unwrap_or_default(),
                info: item["info"].as_str().unwrap_or_default().to_string(),
                images: parse_bangumi_images(&item["images"]),
            })
        })
        .collect()
}

fn parse_person_search_results(json: &serde_json::Value) -> Vec<BangumiPersonSearchResult> {
    json["data"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|item| {
            let id = item["id"].as_i64().filter(|id| *id > 0)?;
            let career = item["career"]
                .as_array()
                .into_iter()
                .flatten()
                .filter_map(|career| career.as_str().map(str::to_string))
                .collect();
            Some(BangumiPersonSearchResult {
                id,
                name: item["name"].as_str().unwrap_or_default().to_string(),
                name_cn: item["nameCN"].as_str().unwrap_or_default().to_string(),
                person_type: json_i32(&item["type"]).unwrap_or_default(),
                info: item["info"].as_str().unwrap_or_default().to_string(),
                career,
                images: parse_bangumi_images(&item["images"]),
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::http_server::{TestResponse, TestRoute, TestServer};
    use crate::test_support::state::isolate_runtime_config;
    use axum::http::{Method, StatusCode};
    use serde_json::json;

    #[test]
    fn search_result_parsers_normalize_optional_fields_and_drop_invalid_ids() {
        let characters = parse_character_search_results(&json!({"data": [
            {"id": 1, "name": "Role", "nameCN": "角色", "role": 1, "info": "", "images": {}},
            {"id": 0, "name": "ignored"}
        ]}));
        assert_eq!(characters.len(), 1);
        assert_eq!(characters[0].images.as_ref().unwrap().small, "");

        let persons = parse_person_search_results(&json!({"data": [
            {"id": 2, "name": "Person", "career": ["seiyu", null], "type": 1},
            {"id": "3", "name": "ignored"}
        ]}));
        assert_eq!(persons.len(), 1);
        assert_eq!(persons[0].career, ["seiyu"]);
    }

    #[tokio::test]
    async fn character_search_posts_keyword_and_uses_page_offset() {
        let _config = isolate_runtime_config();
        let server = TestServer::spawn([TestRoute::post(
            "/p1/search/characters",
            TestResponse::new(StatusCode::OK, json!({"data": []}).to_string()),
        )])
        .await;
        {
            let mut config = crate::api::config::CONFIG.write().unwrap();
            config.bangumi_next_url = server.base_url();
            config.bangumi_access_token = None;
            config.bangumi_use_ech = false;
            config.bangumi_use_reverse_proxy = false;
        }

        assert!(
            search_bangumi_characters("Role".to_string(), 2)
                .await
                .unwrap()
                .is_empty()
        );

        let requests = server.requests();
        assert_eq!(requests.len(), 1);
        let request = &requests[0];
        assert_eq!(request.method, Method::POST);
        assert_eq!(request.uri.path(), "/p1/search/characters");
        assert_eq!(request.uri.query(), Some("limit=20&offset=20"));
        assert_eq!(
            serde_json::from_slice::<serde_json::Value>(&request.body).unwrap(),
            json!({"keyword": "Role"})
        );
        server.shutdown().await;
    }
}
