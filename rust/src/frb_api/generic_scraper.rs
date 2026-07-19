use crate::api::generic_scraper as gs_impl;
use crate::frb_api::contract;

fn validate_source_update(update: &gs_impl::SourceConfigUpdate) -> anyhow::Result<()> {
    contract::require_non_blank("update.name", &update.name)?;
    if let Some(new_name) = update.new_name.as_deref() {
        contract::require_non_blank("update.new_name", new_name)?;
    }
    Ok(())
}

fn validate_runtime_overrides(
    runtime_overrides: &[gs_impl::SourceRuntimeOverride],
) -> anyhow::Result<()> {
    let names: Vec<_> = runtime_overrides
        .iter()
        .map(|item| item.source_name.clone())
        .collect();
    contract::require_non_blank_items("runtime_overrides.source_name", &names)
}

pub fn invalidate_source_config_cache() {
    gs_impl::invalidate_source_config_cache();
}

pub async fn refresh_playback_source_config() -> anyhow::Result<String> {
    contract::public_result(
        "refresh_playback_source_config",
        gs_impl::refresh_playback_source_config().await,
    )
}

pub async fn preload_playback_sources() -> anyhow::Result<()> {
    contract::public_result(
        "preload_playback_sources",
        gs_impl::preload_playback_sources().await,
    )
}

pub async fn get_playback_sources() -> anyhow::Result<Vec<gs_impl::SourceState>> {
    contract::public_result(
        "get_playback_sources",
        gs_impl::get_playback_sources().await,
    )
}

pub async fn update_single_source_config(
    update: gs_impl::SourceConfigUpdate,
) -> anyhow::Result<()> {
    const API: &str = "update_single_source_config";
    contract::public_result(API, validate_source_update(&update))?;
    contract::public_result(API, gs_impl::update_single_source_config(update).await)
}

pub async fn add_source_config(new_config: gs_impl::SourceConfigUpdate) -> anyhow::Result<()> {
    const API: &str = "add_source_config";
    contract::public_result(API, validate_source_update(&new_config))?;
    contract::public_result(API, gs_impl::add_source_config(new_config).await)
}

pub async fn generic_search_play_pages(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<Vec<gs_impl::SearchPlayResult>> {
    const API: &str = "generic_search_play_pages";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::generic_search_play_pages(anime_name, absolute_episode, relative_episode).await,
    )
}

pub async fn generic_search_play_pages_stream(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<gs_impl::SearchPlayResult>,
) -> anyhow::Result<()> {
    const API: &str = "generic_search_play_pages_stream";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::generic_search_play_pages_stream(
            anime_name,
            absolute_episode,
            relative_episode,
            sink,
        )
        .await,
    )
}

pub async fn get_enabled_source_names() -> anyhow::Result<Vec<String>> {
    contract::public_result(
        "get_enabled_source_names",
        gs_impl::get_enabled_source_names().await,
    )
}

pub async fn generic_search_with_progress(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    const API: &str = "generic_search_with_progress";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::generic_search_with_progress(anime_name, absolute_episode, relative_episode, sink)
            .await,
    )
}

pub async fn generic_search_with_progress_runtime(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    target_source_names: Option<Vec<String>>,
    runtime_overrides: Vec<gs_impl::SourceRuntimeOverride>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    const API: &str = "generic_search_with_progress_runtime";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    if let Some(names) = target_source_names.as_deref() {
        contract::public_result(
            API,
            contract::require_non_blank_items("target_source_names", names),
        )?;
    }
    contract::public_result(API, validate_runtime_overrides(&runtime_overrides))?;
    let target_source_names = target_source_names.filter(|names| !names.is_empty());
    contract::public_result(
        API,
        gs_impl::generic_search_with_progress_runtime(
            anime_name,
            absolute_episode,
            relative_episode,
            target_source_names,
            runtime_overrides,
            sink,
        )
        .await,
    )
}

pub async fn debug_search_with_local_json(
    json_path: String,
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    source_name_filter: Option<String>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    const API: &str = "debug_search_with_local_json";
    contract::public_result(API, contract::require_non_blank("json_path", &json_path))?;
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::debug_search_with_local_json(
            json_path,
            anime_name,
            absolute_episode,
            relative_episode,
            source_name_filter,
            sink,
        )
        .await,
    )
}

pub async fn debug_search_with_local_json_runtime(
    json_path: String,
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    source_name_filter: Option<String>,
    runtime_overrides: Vec<gs_impl::SourceRuntimeOverride>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    const API: &str = "debug_search_with_local_json_runtime";
    contract::public_result(API, contract::require_non_blank("json_path", &json_path))?;
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(API, validate_runtime_overrides(&runtime_overrides))?;
    contract::public_result(
        API,
        gs_impl::debug_search_with_local_json_runtime(
            json_path,
            anime_name,
            absolute_episode,
            relative_episode,
            source_name_filter,
            runtime_overrides,
            sink,
        )
        .await,
    )
}

pub async fn generic_search_and_play_with_episode(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    const API: &str = "generic_search_and_play_with_episode";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::generic_search_and_play_with_episode(
            anime_name,
            absolute_episode,
            relative_episode,
        )
        .await,
    )
}

pub async fn generic_search_and_play(anime_name: String) -> anyhow::Result<String> {
    const API: &str = "generic_search_and_play";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(API, gs_impl::generic_search_and_play(anime_name).await)
}

pub async fn generic_search_with_channels(
    anime_name: String,
) -> anyhow::Result<Vec<gs_impl::SearchResultWithChannels>> {
    const API: &str = "generic_search_with_channels";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(API, gs_impl::generic_search_with_channels(anime_name).await)
}

pub async fn generic_search_with_channels_stream(
    anime_name: String,
    sink: crate::frb_generated::StreamSink<gs_impl::SearchResultWithChannels>,
) -> anyhow::Result<()> {
    const API: &str = "generic_search_with_channels_stream";
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    contract::public_result(
        API,
        gs_impl::generic_search_with_channels_stream(anime_name, sink).await,
    )
}

pub async fn get_episode_play_url(
    source_name: String,
    anime_name: String,
    channel_index: usize,
    episode_number: Option<u32>,
    runtime_override: Option<gs_impl::SourceRuntimeOverride>,
) -> anyhow::Result<gs_impl::SearchPlayResult> {
    const API: &str = "get_episode_play_url";
    contract::public_result(
        API,
        contract::require_non_blank("source_name", &source_name),
    )?;
    contract::public_result(API, contract::require_non_blank("anime_name", &anime_name))?;
    if let Some(runtime_override) = runtime_override.as_ref() {
        contract::public_result(
            API,
            contract::require_non_blank(
                "runtime_override.source_name",
                &runtime_override.source_name,
            ),
        )?;
        if runtime_override.source_name != source_name {
            return contract::public_result(
                API,
                Err(anyhow::anyhow!(
                    "invalid argument `runtime_override.source_name`: must match `source_name`"
                )),
            );
        }
    }
    contract::public_result(
        API,
        gs_impl::get_episode_play_url(
            source_name,
            anime_name,
            channel_index,
            episode_number,
            runtime_override,
        )
        .await,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn empty_update() -> gs_impl::SourceConfigUpdate {
        gs_impl::SourceConfigUpdate {
            name: " ".to_string(),
            new_name: None,
            tier: None,
            default_subtitle_language: None,
            default_resolution: None,
            search_url: None,
            icon_url: None,
            description: None,
            search_config_json: None,
            captcha_config_json: None,
        }
    }

    #[tokio::test]
    async fn invalid_non_stream_arguments_fail_before_config_or_network_access() {
        assert_eq!(
            generic_search_play_pages(" ".to_string(), None, None)
                .await
                .unwrap_err()
                .to_string(),
            "generic_search_play_pages: invalid argument `anime_name`: must not be blank"
        );
        assert_eq!(
            add_source_config(empty_update())
                .await
                .unwrap_err()
                .to_string(),
            "add_source_config: invalid argument `update.name`: must not be blank"
        );
        let mismatch = gs_impl::SourceRuntimeOverride {
            source_name: "other".to_string(),
            cookies: None,
            search_page_html: None,
            search_page_url: None,
            detail_page_html: None,
            detail_page_url: None,
            skip_search_error: None,
        };
        assert_eq!(
            get_episode_play_url(
                "source".to_string(),
                "anime".to_string(),
                0,
                None,
                Some(mismatch),
            )
            .await
            .unwrap_err()
            .to_string(),
            "get_episode_play_url: invalid argument `runtime_override.source_name`: must match `source_name`"
        );
    }
}
