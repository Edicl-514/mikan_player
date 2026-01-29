use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanSearchResult {
    pub id: String,
    pub name: String,
    pub image_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MikanEpisodeResource {
    pub title: String,
    pub magnet: String,
    pub size: String,
    pub update_time: String,
    pub episode: Option<i32>,
}

// Simple Levenshtein distance implementation
fn levenshtein(s1: &str, s2: &str) -> usize {
    let v1: Vec<char> = s1.chars().collect();
    let v2: Vec<char> = s2.chars().collect();
    let l1 = v1.len();
    let l2 = v2.len();

    let mut matrix = vec![vec![0; l2 + 1]; l1 + 1];

    for i in 0..=l1 {
        matrix[i][0] = i;
    }
    for j in 0..=l2 {
        matrix[0][j] = j;
    }

    for i in 1..=l1 {
        for j in 1..=l2 {
            let cost = if v1[i - 1] == v2[j - 1] { 0 } else { 1 };
            matrix[i][j] = (matrix[i - 1][j] + 1)
                .min(matrix[i][j - 1] + 1)
                .min(matrix[i - 1][j - 1] + cost);
        }
    }

    matrix[l1][l2]
}

// Calculate similarity (0.0 to 1.0)
fn similarity(s1: &str, s2: &str) -> f64 {
    let distance = levenshtein(s1, s2);
    let max_len = s1.chars().count().max(s2.chars().count());
    if max_len == 0 {
        return 1.0;
    }
    1.0 - (distance as f64 / max_len as f64)
}

pub async fn search_mikan_anime(name_cn: String) -> anyhow::Result<Option<MikanSearchResult>> {
    // 1. Preprocess name: Remove Common suffixes like " 第2部分", " Season 2" etc.
    // Heuristic: Split by space and take the first part if it looks like a prefix,
    // or just use the name as is if it's short.
    // The user example: "叹气的亡灵想隐退 第2部分" -> "叹气的亡灵想隐退"
    // We can try to split by ' ' and take the first part if the second part starts with "第" or "Part" or "Season"

    let parts: Vec<&str> = name_cn.split_whitespace().collect();
    let search_str = if parts.len() > 1
        && (parts[1].starts_with("第")
            || parts[1].to_lowercase().starts_with("part")
            || parts[1].to_lowercase().starts_with("season"))
    {
        parts[0]
    } else {
        &name_cn
    };

    let url = format!("https://mikanani.me/Home/Search?searchstr={}", search_str);
    let client = reqwest::Client::new();
    let resp = client.get(&url).send().await?.text().await?;
    let document = Html::parse_document(&resp);

    let list_selector = Selector::parse(".an-ul li a").unwrap();
    let text_selector = Selector::parse(".an-text").unwrap();
    let bg_selector = Selector::parse(".b-lazy").unwrap();

    let mut results = Vec::new();

    for element in document.select(&list_selector) {
        let href = element.value().attr("href").unwrap_or("");
        // href should be like /Home/Bangumi/3416
        if !href.contains("/Home/Bangumi/") {
            continue;
        }
        let id = href.split('/').last().unwrap_or("").to_string();

        let name = element
            .select(&text_selector)
            .next()
            .map(|e| e.attr("title").unwrap_or("").to_string())
            .unwrap_or_default();

        let style = element
            .select(&bg_selector)
            .next()
            .map(|e| e.attr("style").unwrap_or("").to_string())
            .unwrap_or_default();

        // Extract url from style="background-image: url('/images/...')"
        // rough extract
        let image_url = if let Some(start) = style.find("url('") {
            if let Some(end) = style[start + 5..].find("'") {
                format!("https://mikanani.me{}", &style[start + 5..start + 5 + end])
            } else if let Some(start2) = style.find("url(&quot;") {
                if let Some(end2) = style[start2 + 10..].find("&quot;") {
                    format!(
                        "https://mikanani.me{}",
                        &style[start2 + 10..start2 + 10 + end2]
                    )
                } else {
                    "".to_string()
                }
            } else {
                "".to_string()
            }
        } else {
            "".to_string()
        };

        let sim = similarity(search_str, &name);
        results.push((
            MikanSearchResult {
                id,
                name,
                image_url,
            },
            sim,
        ));
    }

    // Sort by similarity descending
    results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    if let Some(best) = results.first() {
        Ok(Some(best.0.clone()))
    } else {
        Ok(None)
    }
}

fn extract_episode(title: &str) -> Option<i32> {
    // Regex would be good here but regular expressions crate might not be imported.
    // Checking Cargo.toml, "regex" is not listed.
    // I should probably manually parse or request to add regex crate.
    // Manual parsing: iterate words, check if they look like episode numbers.
    // Common patterns: [01], - 01, 第01话.

    // Simplest approach: Look for number that is likely an episode (1-999).
    // Usually it's isolated or enclosed.
    // Let's iterate over tokens.

    // Clean string: replace [ ] 【 】 -  with space

    // Better strategy: Identify patterns.
    // [12] or - 12 or 第12话/集 or SP01

    // Let's try splitting by common delimiters.
    let re_chars = ['[', ']', '【', '】', '(', ')', ' ', '-', '_'];
    let parts: Vec<&str> = title
        .split(|c| re_chars.contains(&c))
        .filter(|s| !s.is_empty())
        .collect();

    for part in parts.iter().rev() {
        // Usually episode is at the end or middle-end
        if let Ok(num) = part.parse::<i32>() {
            // Filters years like 2025, resolutions like 1080
            if num > 0
                && num < 1000
                && num != 720
                && num != 1080
                && num != 2160
                && num != 264
                && num != 265
            {
                return Some(num);
            }
        }
    }
    None
}

pub async fn get_mikan_resources(
    mikan_id: String,
    current_episode_sort: i32,
) -> anyhow::Result<Vec<MikanEpisodeResource>> {
    let url = format!("https://mikanani.me/Home/Bangumi/{}", mikan_id);
    let client = reqwest::Client::new();
    let resp = client.get(&url).send().await?.text().await?;
    let document = Html::parse_document(&resp);

    let table_selector = Selector::parse(".episode-table tbody tr").unwrap();
    let name_selector = Selector::parse(".magnet-link-wrap").unwrap();
    let size_selector = Selector::parse("td:nth-child(3)").unwrap();
    let time_selector = Selector::parse("td:nth-child(4)").unwrap();
    let magnet_selector = Selector::parse(".js-magnet").unwrap();

    let mut resources = Vec::new();

    for row in document.select(&table_selector) {
        let name_el = row.select(&name_selector).next();
        let magnet_el = row.select(&magnet_selector).next();

        if let (Some(name_el), Some(magnet_el)) = (name_el, magnet_el) {
            let title = name_el.text().collect::<String>();
            // magnet link is in data-clipboard-text
            let magnet = magnet_el
                .attr("data-clipboard-text")
                .unwrap_or("")
                .to_string();

            let size = row
                .select(&size_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();
            let update_time = row
                .select(&time_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();

            let episode = extract_episode(&title);

            // Only add if episode matches or if we want all?
            // User requirement: "提取集数，选取与当前集数匹配的资源"
            if let Some(ep) = episode {
                if ep == current_episode_sort {
                    resources.push(MikanEpisodeResource {
                        title: title.clone(),
                        magnet,
                        size,
                        update_time,
                        episode: Some(ep),
                    });
                }
            } else {
                // Maybe fallback: if we can't extract, maybe include it?
                // But safer to assume if we can't find episode, it might not match.
            }
        }
    }

    Ok(resources)
}
