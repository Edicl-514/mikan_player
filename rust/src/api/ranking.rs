use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};

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
    fetch_bangumi_browser(sort_type, "".to_string(), vec![], page).await
}

pub async fn fetch_bangumi_browser(
    sort_type: String,
    year: String,
    tags: Vec<String>,
    page: i32,
) -> anyhow::Result<Vec<RankingAnime>> {
    let client = crate::api::network::create_client()?;

    let mut url = reqwest::Url::parse("https://bangumi.tv/anime/browser")?;

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

    let resp = client.get(url).send().await?;
    let html = resp.text().await?;
    let document = Html::parse_document(&html);

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

    Ok(results)
}
