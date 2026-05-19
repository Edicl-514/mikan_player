use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RankingAnime {
    pub title: String,
    pub bangumi_id: String,
    pub cover_url: String,
    pub score: Option<f64>,
    pub rank: Option<i32>,
    pub info: String,
    pub original_title: Option<String>,
}

pub async fn fetch_bangumi_ranking(
    sort_type: String,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "legacy" => fetch_bangumi_browser_html(sort_type, "".to_string(), vec![], page).await,
        "hybrid" | "modern" if sort_type == "trends" => fetch_bangumi_trending_next(page).await,
        "hybrid" | "modern" => fetch_bangumi_browser_api(&sort_type, "", &[], page).await,
        _ => {
            if sort_type == "trends" {
                fetch_bangumi_trending_next(page).await
            } else {
                fetch_bangumi_browser_api(&sort_type, "", &[], page).await
            }
        }
    }
}

pub async fn fetch_bangumi_browser(
    sort_type: String,
    year: String,
    tags: Vec<String>,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "legacy" => fetch_bangumi_browser_html(sort_type, year, tags, page).await,
        "hybrid" | "modern" => fetch_bangumi_browser_api(&sort_type, &year, &tags, page).await,
        _ => fetch_bangumi_browser_api(&sort_type, &year, &tags, page).await,
    }
}

async fn fetch_bangumi_browser_html(
    sort_type: String,
    year: String,
    tags: Vec<String>,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mut url = reqwest::Url::parse(&format!(
        "{}/anime/browser",
        crate::api::config::get_bangumi_url()
    ))?;

    {
        let mut path_segments = url
            .path_segments_mut()
            .map_err(|_| anyhow::anyhow!("Invalid base URL"))?;

        for tag in tags {
            if !tag.is_empty() && tag != "全部" {
                path_segments.push(&tag);
            }
        }

        if !year.is_empty() && year != "不限" {
            path_segments.push("airtime");
            path_segments.push(&year);
        }
    }

    url.query_pairs_mut()
        .append_pair("sort", &sort_type)
        .append_pair("page", &page.to_string());

    let url_str = url.to_string();
    let resp =
        crate::api::network::retry_request("fetch_bangumi_browser", |client| client.get(&url_str))
            .await?
            .error_for_status()?;
    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    Ok(parse_bangumi_list(&document))
}

pub async fn search_bangumi_subject(
    keyword: String,
    sort_type: String,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "legacy" => search_bangumi_subject_html(keyword, page).await,
        "hybrid" | "modern" => fetch_bangumi_search_api(&keyword, &sort_type, page).await,
        _ => fetch_bangumi_search_api(&keyword, &sort_type, page).await,
    }
}

pub async fn search_bangumi_tag(
    tag: String,
    sort_type: String,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mode = crate::api::config::get_bangumi_request_mode();
    match mode.as_str() {
        "legacy" => search_bangumi_tag_html(tag, sort_type, page).await,
        "hybrid" | "modern" => fetch_bangumi_browser_api(&sort_type, "", &[tag], page).await,
        _ => fetch_bangumi_browser_api(&sort_type, "", &[tag], page).await,
    }
}

async fn search_bangumi_subject_html(
    keyword: String,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let url = format!(
        "{}/subject_search/{}?cat=2&page={}",
        crate::api::config::get_bangumi_url(),
        urlencoding::encode(&keyword),
        page
    );

    let resp =
        crate::api::network::retry_request("search_bangumi_subject", |client| client.get(&url))
            .await?
            .error_for_status()?;
    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    Ok(parse_bangumi_list(&document))
}

async fn search_bangumi_tag_html(
    tag: String,
    sort_type: String,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let mut url = reqwest::Url::parse(&format!(
        "{}/anime/tag",
        crate::api::config::get_bangumi_url()
    ))?;

    {
        let mut path_segments = url
            .path_segments_mut()
            .map_err(|_| anyhow::anyhow!("Invalid base URL"))?;

        if !tag.is_empty() && tag != "全部" {
            path_segments.push(&tag);
        }
    }

    url.query_pairs_mut()
        .append_pair("sort", &sort_type)
        .append_pair("page", &page.to_string());

    let resp = crate::api::network::retry_request("bangumi.search.tag.legacy", |client| {
        client.get(url.as_str())
    })
    .await?
    .error_for_status()?;
    let html = resp.text().await?;
    let document = Html::parse_document(&html);

    Ok(parse_bangumi_list(&document))
}

async fn fetch_bangumi_search_api(
    keyword: &str,
    sort_type: &str,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let body = json!({
        "keyword": keyword,
        "sort": normalize_api_sort_type(sort_type),
        "filter": {
            "type": [2],
            "rank": [">0"]
        }
    });

    fetch_bangumi_subjects_v0("bangumi.search.api", body, page).await
}

async fn fetch_bangumi_browser_api(
    sort_type: &str,
    year: &str,
    tags: &[String],
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let body = json!({
        "sort": normalize_api_sort_type(sort_type),
        "filter": Value::Object(build_api_subject_filter(year, tags)),
    });

    fetch_bangumi_subjects_v0("bangumi.browser.api", body, page).await
}

async fn fetch_bangumi_trending_next(page: i32) -> anyhow::Result<Vec<RankingAnime>> {
    let offset = ((page.max(1) - 1) * 20).to_string();
    let limit = "20";
    let base_url = crate::api::config::get_bangumi_next_url();
    let url = format!("{base_url}/p1/trending/subjects?type=2&limit={limit}&offset={offset}");

    let resp = crate::api::network::retry_request("bangumi.trending.next", |client| {
        client.get(&url).header("accept", "application/json")
    })
    .await?;

    let json: Value = resp.json().await?;
    Ok(parse_bangumi_next_trending_results(&json))
}

async fn fetch_bangumi_subjects_v0(
    label: &str,
    body: Value,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let offset = ((page.max(1) - 1) * 24).to_string();
    let limit = "24".to_string();
    let url = format!(
        "{}/v0/search/subjects",
        crate::api::config::get_bangumi_api_url()
    );

    let resp = crate::api::network::retry_request(label, |client| {
        client
            .post(&url)
            .query(&[("limit", limit.as_str()), ("offset", offset.as_str())])
            .header("Content-Type", "application/json")
            .header("accept", "application/json")
            .json(&body)
    })
    .await?;

    let json: serde_json::Value = resp.json().await?;
    Ok(parse_bangumi_search_results(&json))
}

fn normalize_api_sort_type(sort_type: &str) -> &str {
    match sort_type {
        "rank" => "rank",
        "match" | "date" | "title" => "match",
        "heat" | "collects" | "trends" => "heat",
        _ => "rank",
    }
}

fn build_api_subject_filter(year: &str, tags: &[String]) -> serde_json::Map<String, Value> {
    let mut filter = serde_json::Map::new();
    filter.insert("type".to_string(), json!([2]));
    filter.insert("rank".to_string(), json!([">0"]));

    let normalized_tags: Vec<String> = tags
        .iter()
        .filter(|tag| !tag.is_empty() && tag.as_str() != "全部")
        .cloned()
        .collect();
    if !normalized_tags.is_empty() {
        filter.insert("tag".to_string(), json!(normalized_tags));
    }

    if let Some(air_date) = build_air_date_filter(year) {
        filter.insert("air_date".to_string(), json!(air_date));
    }

    filter
}

fn build_air_date_filter(year: &str) -> Option<Vec<String>> {
    let trimmed = year.trim();
    if trimmed.is_empty() || trimmed == "不限" {
        return None;
    }

    if let Some((year_part, month_part)) = trimmed.split_once('-') {
        let month = month_part.parse::<u32>().ok()?;
        if !(1..=12).contains(&month) {
            return None;
        }

        let next_year = if month == 12 {
            year_part.parse::<i32>().ok()?.checked_add(1)?.to_string()
        } else {
            year_part.to_string()
        };
        let next_month = if month == 12 { 1 } else { month + 1 };

        return Some(vec![
            format!(">={}-{:02}-01", year_part, month),
            format!("<{}-{:02}-01", next_year, next_month),
        ]);
    }

    Some(vec![
        format!(">={}-01-01", trimmed),
        format!("<{}-01-01", trimmed.parse::<i32>().ok()?.checked_add(1)?),
    ])
}

fn parse_bangumi_search_results(json: &Value) -> Vec<RankingAnime> {
    json["data"]
        .as_array()
        .map(|items| items.iter().filter_map(parse_bangumi_search_item).collect())
        .unwrap_or_default()
}

fn parse_bangumi_next_trending_results(json: &Value) -> Vec<RankingAnime> {
    json["data"]
        .as_array()
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    item.get("subject")
                        .filter(|subject| subject.is_object())
                        .or(Some(item))
                        .and_then(parse_bangumi_search_item)
                })
                .collect()
        })
        .unwrap_or_default()
}

fn parse_bangumi_search_item(item: &Value) -> Option<RankingAnime> {
    let bangumi_id = item["id"]
        .as_i64()
        .map(|value| value.to_string())
        .or_else(|| item["id"].as_str().map(|value| value.to_string()))?;

    let original_title = item["name"].as_str().map(|value| value.trim().to_string());
    let name_cn = item["name_cn"].as_str().unwrap_or("").trim();
    let title = if !name_cn.is_empty() {
        name_cn.to_string()
    } else {
        original_title.clone().unwrap_or_default()
    };

    if title.is_empty() {
        return None;
    }

    let mut cover_url = item["images"]["large"]
        .as_str()
        .or_else(|| item["images"]["common"].as_str())
        .or_else(|| item["images"]["medium"].as_str())
        .or_else(|| item["images"]["small"].as_str())
        .unwrap_or("")
        .to_string();
    if cover_url.starts_with("//") {
        cover_url = format!("https:{}", cover_url);
    }

    let score = item["score"]
        .as_f64()
        .or_else(|| item["rating"]["score"].as_f64());
    let rank = item["rank"]
        .as_i64()
        .or_else(|| item["rating"]["rank"].as_i64())
        .map(|value| value as i32);

    let info = build_subject_info(item);
    let normalized_original_title =
        original_title.filter(|value| !value.is_empty() && *value != title);

    Some(RankingAnime {
        title,
        bangumi_id,
        cover_url,
        score,
        rank,
        info,
        original_title: normalized_original_title,
    })
}

fn build_subject_info(item: &Value) -> String {
    let mut parts = Vec::new();

    if let Some(date) = item["date"].as_str().filter(|value| !value.is_empty()) {
        parts.push(date.to_string());
    }
    if let Some(platform) = item["platform"].as_str().filter(|value| !value.is_empty()) {
        parts.push(platform.to_string());
    }

    if parts.is_empty() {
        if let Some(tags) = item["meta_tags"].as_array() {
            parts.extend(
                tags.iter()
                    .filter_map(|tag| tag.as_str())
                    .filter(|tag| !tag.is_empty())
                    .take(3)
                    .map(|tag| tag.to_string()),
            );
        }
    }

    parts.join(" / ")
}

fn parse_bangumi_list(document: &Html) -> Vec<RankingAnime> {
    let item_selector = Selector::parse("#browserItemList > li.item").unwrap();
    let title_selector = Selector::parse("h3 > a.l").unwrap();
    let original_title_selector = Selector::parse("h3 > small.grey").unwrap();
    let cover_selector = Selector::parse("img.cover").unwrap();
    let info_selector = Selector::parse("p.info").unwrap();
    let score_selector = Selector::parse("small.fade").unwrap();
    let rank_selector = Selector::parse("span.rank").unwrap();

    let mut results = Vec::new();

    for item in document.select(&item_selector) {
        let title_el = item.select(&title_selector).next();
        let title = title_el
            .map(|e| e.text().collect::<String>())
            .unwrap_or_default();

        let href = title_el.and_then(|e| e.value().attr("href")).unwrap_or("");
        let bangumi_id = href.split('/').last().unwrap_or("").to_string();

        if bangumi_id.is_empty() {
            continue;
        }

        let original_title = item
            .select(&original_title_selector)
            .next()
            .map(|e| e.text().collect::<String>().trim().to_string());

        let cover_el = item.select(&cover_selector).next();
        let mut cover_url = cover_el
            .and_then(|e| e.value().attr("src"))
            .unwrap_or("")
            .to_string();
        if cover_url.starts_with("//") {
            cover_url = format!("https:{}", cover_url);
        }

        let info = item
            .select(&info_selector)
            .next()
            .map(|e| e.text().collect::<String>().trim().to_string())
            .unwrap_or_default();

        let score_text = item
            .select(&score_selector)
            .next()
            .map(|e| e.text().collect::<String>())
            .unwrap_or_default();
        let score = score_text.parse::<f64>().ok();

        let rank_text = item
            .select(&rank_selector)
            .next()
            .map(|e| e.text().collect::<String>())
            .unwrap_or_default();
        let rank = rank_text.replace("Rank", "").trim().parse::<i32>().ok();

        results.push(RankingAnime {
            title,
            bangumi_id,
            cover_url,
            score,
            rank,
            info,
            original_title,
        });
    }

    results
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_air_date_filter_supports_year_and_month() {
        assert_eq!(
            build_air_date_filter("2025"),
            Some(vec![">=2025-01-01".to_string(), "<2026-01-01".to_string(),])
        );
        assert_eq!(
            build_air_date_filter("2025-04"),
            Some(vec![">=2025-04-01".to_string(), "<2025-05-01".to_string(),])
        );
        assert_eq!(
            build_air_date_filter("2025-12"),
            Some(vec![">=2025-12-01".to_string(), "<2026-01-01".to_string(),])
        );
    }

    #[test]
    fn parse_bangumi_search_results_maps_v0_payload() {
        let input = json!({
            "data": [
                {
                    "id": 543360,
                    "name": "Kamiina Botan",
                    "name_cn": "上伊那牡丹",
                    "date": "2026-04-10",
                    "platform": "TV",
                    "images": { "large": "https://example.com/cover.jpg" },
                    "score": 7.58,
                    "rank": 123,
                    "meta_tags": ["百合", "日常"]
                }
            ]
        });

        let results = parse_bangumi_search_results(&input);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].bangumi_id, "543360");
        assert_eq!(results[0].title, "上伊那牡丹");
        assert_eq!(results[0].original_title.as_deref(), Some("Kamiina Botan"));
        assert_eq!(results[0].info, "2026-04-10 / TV");
        assert_eq!(results[0].score, Some(7.58));
        assert_eq!(results[0].rank, Some(123));
    }

    #[test]
    fn parse_bangumi_next_trending_results_maps_subject_payload() {
        let input = json!({
            "data": [
                {
                    "subject": {
                        "id": 543360,
                        "name": "Kamiina Botan",
                        "name_cn": "上伊那牡丹",
                        "date": "2026-04-10",
                        "platform": "TV",
                        "images": { "large": "https://example.com/cover.jpg" },
                        "rating": { "score": 7.58, "rank": 123 },
                        "meta_tags": ["百合", "日常"]
                    }
                }
            ],
            "total": 1
        });

        let results = parse_bangumi_next_trending_results(&input);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].bangumi_id, "543360");
        assert_eq!(results[0].title, "上伊那牡丹");
        assert_eq!(results[0].original_title.as_deref(), Some("Kamiina Botan"));
        assert_eq!(results[0].info, "2026-04-10 / TV");
        assert_eq!(results[0].score, Some(7.58));
        assert_eq!(results[0].rank, Some(123));
    }

    #[test]
    fn normalize_api_sort_type_maps_supported_values() {
        assert_eq!(normalize_api_sort_type("rank"), "rank");
        assert_eq!(normalize_api_sort_type("match"), "match");
        assert_eq!(normalize_api_sort_type("heat"), "heat");
        assert_eq!(normalize_api_sort_type("collects"), "heat");
        assert_eq!(normalize_api_sort_type("trends"), "heat");
        assert_eq!(normalize_api_sort_type("date"), "match");
        assert_eq!(normalize_api_sort_type("title"), "match");
        assert_eq!(normalize_api_sort_type("unknown"), "rank");
    }

    #[test]
    fn legacy_tag_search_url_matches_bangumi_route_shape() {
        let mut url = reqwest::Url::parse("https://bangumi.tv/anime/tag").unwrap();
        {
            let mut path_segments = url.path_segments_mut().unwrap();
            path_segments.push("百合");
        }
        url.query_pairs_mut()
            .append_pair("sort", "collects")
            .append_pair("page", "2");

        assert_eq!(
            url.as_str(),
            "https://bangumi.tv/anime/tag/%E7%99%BE%E5%90%88?sort=collects&page=2"
        );
    }

    #[test]
    fn build_api_subject_filter_includes_rank_floor() {
        let filter = build_api_subject_filter("2025-04", &[String::from("tv")]);
        assert_eq!(filter.get("type"), Some(&json!([2])));
        assert_eq!(filter.get("rank"), Some(&json!([">0"])));
        assert_eq!(filter.get("tag"), Some(&json!(["tv"])));
        assert_eq!(
            filter.get("air_date"),
            Some(&json!([">=2025-04-01", "<2025-05-01"]))
        );
    }
}
