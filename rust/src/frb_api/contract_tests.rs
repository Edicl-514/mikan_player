use crate::api::bangumi::{BangumiEpisodeComment, BangumiImages};
use crate::api::crawler::{AnimeInfo, BangumiDataSiteEntry};
use crate::api::generic_scraper::{
    ChannelInfo, EpisodeInfo, SearchPlayResult, SearchResultWithChannels, SearchStep,
    SourceConfigUpdate, SourceRuntimeOverride, SourceSearchProgress,
};
use crate::frb_generated::{SseDecode, SseEncode};
use flutter_rust_bridge::for_generated::{
    Dart2RustMessageSse, SseDeserializer, SseSerializer, into_leak_vec_ptr,
};
use serde::Serialize;
use serde::de::DeserializeOwned;
use std::collections::HashMap;

fn serde_round_trip<T>(value: &T) -> T
where
    T: Serialize + DeserializeOwned,
{
    serde_json::from_value(serde_json::to_value(value).unwrap()).unwrap()
}

#[cfg(not(target_family = "wasm"))]
fn frb_sse_round_trip<T>(value: T) -> T
where
    T: SseEncode + SseDecode,
{
    let mut serializer = SseSerializer::new();
    value.sse_encode(&mut serializer);
    let bytes = serializer.cursor.into_inner();
    let data_len = i32::try_from(bytes.len()).unwrap();
    let (ptr, rust_vec_len) = into_leak_vec_ptr(bytes);
    let message = unsafe { Dart2RustMessageSse::from_wire(ptr, rust_vec_len, data_len) };
    let mut deserializer = SseDeserializer::new(message);
    let decoded = T::sse_decode(&mut deserializer);
    deserializer.end();
    decoded
}

fn assert_same_json<T: Serialize>(actual: &T, expected: &T) {
    assert_eq!(
        serde_json::to_value(actual).unwrap(),
        serde_json::to_value(expected).unwrap()
    );
}

#[test]
fn bangumi_and_crawler_dtos_round_trip_through_serde_and_frb_sse() {
    let reply = BangumiEpisodeComment {
        id: 2,
        user_name: "reply-user".to_string(),
        user_id: "reply".to_string(),
        avatar: "//lain.bgm.tv/reply.jpg".to_string(),
        time: "2026-07-20".to_string(),
        content_html: "<p>reply</p>".to_string(),
        replies: Vec::new(),
    };
    let comment = BangumiEpisodeComment {
        id: 1,
        user_name: "root-user".to_string(),
        user_id: "root".to_string(),
        avatar: "https://lain.bgm.tv/root.jpg".to_string(),
        time: "2026-07-20".to_string(),
        content_html: "<p>root</p>".to_string(),
        replies: vec![reply],
    };
    assert_same_json(&serde_round_trip(&comment), &comment);
    assert_same_json(&frb_sse_round_trip(comment.clone()), &comment);

    let anime = AnimeInfo {
        title: "Anime".to_string(),
        sub_title: Some("Sub title".to_string()),
        bangumi_id: Some("505258".to_string()),
        mikan_id: None,
        cover_url: Some("https://lain.bgm.tv/cover.jpg".to_string()),
        site_url: None,
        broadcast_day: Some("Sunday".to_string()),
        broadcast_time: Some("00:00".to_string()),
        score: Some(8.5),
        rank: Some(42),
        tags: vec!["TV".to_string(), "Japan".to_string()],
        full_json: Some("{\"id\":505258}".to_string()),
    };
    assert_same_json(&serde_round_trip(&anime), &anime);
    assert_same_json(&frb_sse_round_trip(anime.clone()), &anime);

    let site: BangumiDataSiteEntry = serde_json::from_value(serde_json::json!({
        "site": "mikan",
        "title": "Mikan",
        "url": "https://mikanani.me/Home/Bangumi/1",
        "kind": "resource"
    }))
    .unwrap();
    assert_eq!(site.comment, None);
}

#[test]
fn generic_scraper_dtos_round_trip_and_keep_backward_defaults() {
    let mut headers = HashMap::new();
    headers.insert("referer".to_string(), "https://example.test/".to_string());
    let play = SearchPlayResult {
        source_name: "Source".to_string(),
        play_page_url: "https://example.test/play/1".to_string(),
        video_regex: "video=(.+)".to_string(),
        direct_video_url: None,
        cookies: Some("session=1".to_string()),
        headers: Some(headers.clone()),
        channel_name: Some("Line A".to_string()),
        channel_index: Some(1),
        captcha_config_json: None,
        enable_nested_url: true,
        match_nested_url: Some("src=([^ ]+)".to_string()),
    };
    assert_same_json(&serde_round_trip(&play), &play);
    assert_same_json(&frb_sse_round_trip(play.clone()), &play);

    let channels = SearchResultWithChannels {
        source_name: "Source".to_string(),
        detail_url: "https://example.test/detail/1".to_string(),
        matched_title: "Anime".to_string(),
        channels: vec![ChannelInfo {
            name: "Line A".to_string(),
            index: 1,
        }],
        episodes: vec![EpisodeInfo {
            name: "Episode 1".to_string(),
            url: "https://example.test/play/1".to_string(),
            episode_number: Some(1),
            channel_index: 1,
        }],
        video_regex: "video".to_string(),
        cookies: None,
        headers: Some(headers.clone()),
        default_subtitle_language: Some("zh-CN".to_string()),
        default_resolution: Some("1080p".to_string()),
    };
    assert_same_json(&serde_round_trip(&channels), &channels);
    assert_same_json(&frb_sse_round_trip(channels.clone()), &channels);

    let progress = SourceSearchProgress {
        source_name: "Source".to_string(),
        step: SearchStep::Success,
        error: None,
        play_page_url: Some("https://example.test/play/1".to_string()),
        video_regex: Some("video".to_string()),
        direct_video_url: None,
        cookies: None,
        headers: Some(headers),
        channel_name: Some("Line A".to_string()),
        channel_index: Some(1),
        all_channels: Some(channels.channels.clone()),
        captcha_config_json: None,
        enable_nested_url: true,
        match_nested_url: None,
    };
    assert_same_json(&serde_round_trip(&progress), &progress);
    assert_same_json(&frb_sse_round_trip(progress.clone()), &progress);

    let minimal_play: SearchPlayResult = serde_json::from_value(serde_json::json!({
        "source_name": "Source",
        "play_page_url": "https://example.test/play/1",
        "video_regex": "video"
    }))
    .unwrap();
    assert!(!minimal_play.enable_nested_url);
    assert_eq!(minimal_play.channel_index, None);

    let runtime: SourceRuntimeOverride =
        serde_json::from_value(serde_json::json!({"sourceName": "Source"})).unwrap();
    assert_eq!(runtime.cookies, None);
    assert_eq!(runtime.skip_search_error, None);

    let update: SourceConfigUpdate =
        serde_json::from_value(serde_json::json!({"name": "Source"})).unwrap();
    assert_eq!(update.new_name, None);
    assert_eq!(update.search_config_json, None);

    let images = BangumiImages {
        small: "small".to_string(),
        grid: "grid".to_string(),
        large: "large".to_string(),
        medium: "medium".to_string(),
        common: "common".to_string(),
    };
    assert_same_json(&serde_round_trip(&images), &images);
}
