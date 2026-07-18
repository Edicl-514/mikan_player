use crate::api::generic_scraper as gs_impl;

pub fn invalidate_source_config_cache() {
    gs_impl::invalidate_source_config_cache();
}

pub async fn refresh_playback_source_config() -> anyhow::Result<String> {
    gs_impl::refresh_playback_source_config().await
}

pub async fn preload_playback_sources() -> anyhow::Result<()> {
    gs_impl::preload_playback_sources().await
}

pub async fn get_playback_sources() -> anyhow::Result<Vec<gs_impl::SourceState>> {
    gs_impl::get_playback_sources().await
}

pub async fn update_single_source_config(
    update: gs_impl::SourceConfigUpdate,
) -> anyhow::Result<()> {
    gs_impl::update_single_source_config(update).await
}

pub async fn add_source_config(new_config: gs_impl::SourceConfigUpdate) -> anyhow::Result<()> {
    gs_impl::add_source_config(new_config).await
}

pub async fn generic_search_play_pages(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<Vec<gs_impl::SearchPlayResult>> {
    gs_impl::generic_search_play_pages(anime_name, absolute_episode, relative_episode).await
}

pub async fn generic_search_play_pages_stream(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<gs_impl::SearchPlayResult>,
) -> anyhow::Result<()> {
    gs_impl::generic_search_play_pages_stream(anime_name, absolute_episode, relative_episode, sink)
        .await
}

pub async fn get_enabled_source_names() -> anyhow::Result<Vec<String>> {
    gs_impl::get_enabled_source_names().await
}

pub async fn generic_search_with_progress(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    gs_impl::generic_search_with_progress(anime_name, absolute_episode, relative_episode, sink)
        .await
}

pub async fn generic_search_with_progress_runtime(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    target_source_names: Option<Vec<String>>,
    runtime_overrides: Vec<gs_impl::SourceRuntimeOverride>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    gs_impl::generic_search_with_progress_runtime(
        anime_name,
        absolute_episode,
        relative_episode,
        target_source_names,
        runtime_overrides,
        sink,
    )
    .await
}

pub async fn debug_search_with_local_json(
    json_path: String,
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
    source_name_filter: Option<String>,
    sink: crate::frb_generated::StreamSink<gs_impl::SourceSearchProgress>,
) -> anyhow::Result<()> {
    gs_impl::debug_search_with_local_json(
        json_path,
        anime_name,
        absolute_episode,
        relative_episode,
        source_name_filter,
        sink,
    )
    .await
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
    gs_impl::debug_search_with_local_json_runtime(
        json_path,
        anime_name,
        absolute_episode,
        relative_episode,
        source_name_filter,
        runtime_overrides,
        sink,
    )
    .await
}

pub async fn generic_search_and_play_with_episode(
    anime_name: String,
    absolute_episode: Option<u32>,
    relative_episode: Option<u32>,
) -> anyhow::Result<String> {
    gs_impl::generic_search_and_play_with_episode(anime_name, absolute_episode, relative_episode)
        .await
}

pub async fn generic_search_and_play(anime_name: String) -> anyhow::Result<String> {
    gs_impl::generic_search_and_play(anime_name).await
}

pub async fn generic_search_with_channels(
    anime_name: String,
) -> anyhow::Result<Vec<gs_impl::SearchResultWithChannels>> {
    gs_impl::generic_search_with_channels(anime_name).await
}

pub async fn generic_search_with_channels_stream(
    anime_name: String,
    sink: crate::frb_generated::StreamSink<gs_impl::SearchResultWithChannels>,
) -> anyhow::Result<()> {
    gs_impl::generic_search_with_channels_stream(anime_name, sink).await
}

pub async fn get_episode_play_url(
    source_name: String,
    anime_name: String,
    channel_index: usize,
    episode_number: Option<u32>,
    runtime_override: Option<gs_impl::SourceRuntimeOverride>,
) -> anyhow::Result<gs_impl::SearchPlayResult> {
    gs_impl::get_episode_play_url(
        source_name,
        anime_name,
        channel_index,
        episode_number,
        runtime_override,
    )
    .await
}
