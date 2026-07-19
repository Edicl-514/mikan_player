use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceState {
    pub name: String,
    pub description: String,
    pub icon_url: String,
    pub tier: i32,
    pub default_subtitle_language: String,
    pub default_resolution: String,
    pub search_url: String,
    pub search_config_json: String,
    pub captcha_config_json: Option<String>,
    pub enabled: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SourceRuntimeOverride {
    #[serde(rename = "sourceName")]
    pub source_name: String,
    pub cookies: Option<String>,
    #[serde(rename = "searchPageHtml")]
    pub search_page_html: Option<String>,
    #[serde(rename = "searchPageUrl")]
    pub search_page_url: Option<String>,
    #[serde(rename = "detailPageHtml")]
    pub detail_page_html: Option<String>,
    #[serde(rename = "detailPageUrl")]
    pub detail_page_url: Option<String>,
    #[serde(rename = "skipSearchError")]
    pub skip_search_error: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SampleRoot {
    #[serde(rename = "exportedMediaSourceDataList")]
    pub exported_media_source_data_list: ExportedMediaSourceDataList,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ExportedMediaSourceDataList {
    #[serde(rename = "mediaSources")]
    pub media_sources: Vec<MediaSource>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MediaSource {
    #[serde(rename = "factoryId")]
    pub factory_id: String,
    pub arguments: SourceArguments,
    #[serde(flatten)]
    pub extra: std::collections::HashMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct OcrConstraints {
    #[serde(rename = "expectedLength")]
    pub expected_length: Option<u32>,
    #[serde(rename = "allowedChars")]
    pub allowed_chars: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct CaptchaConfig {
    pub enable: bool,
    #[serde(rename = "type")]
    pub captcha_type: Option<String>,
    #[serde(rename = "detectSelector")]
    pub detect_selector: Option<String>,
    #[serde(rename = "successSelector")]
    pub success_selector: Option<String>,
    #[serde(rename = "imageSelector")]
    pub image_selector: Option<String>,
    #[serde(rename = "inputSelector")]
    pub input_selector: Option<String>,
    #[serde(rename = "submitSelector")]
    pub submit_selector: Option<String>,
    #[serde(rename = "refreshSelector")]
    pub refresh_selector: Option<String>,
    #[serde(rename = "initialDelayMs")]
    pub initial_delay_ms: Option<u64>,
    #[serde(rename = "ocrConstraints")]
    pub ocr_constraints: Option<OcrConstraints>,
    #[serde(flatten)]
    pub extra: std::collections::HashMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SourceArguments {
    pub name: String,
    pub description: Option<String>,
    #[serde(rename = "iconUrl")]
    pub icon_url: Option<String>,
    pub tier: Option<i32>,
    #[serde(rename = "restrictedRegion")]
    pub restricted_region: Option<Vec<String>>,
    #[serde(rename = "searchConfig")]
    pub search_config: SearchConfig,
    #[serde(rename = "captchaConfig")]
    pub captcha_config: Option<CaptchaConfig>,
    #[serde(flatten)]
    pub extra: std::collections::HashMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SearchConfig {
    #[serde(rename = "searchUrl")]
    pub search_url: String,

    #[serde(rename = "defaultSubtitleLanguage")]
    pub default_subtitle_language: Option<String>,

    #[serde(rename = "defaultResolution")]
    pub default_resolution: Option<String>,

    // Subject format selector
    #[serde(rename = "subjectFormatId")]
    pub subject_format_id: Option<String>,

    // Selectors for result list
    #[serde(rename = "selectorSubjectFormatA")]
    pub selector_subject_format_a: Option<SelectorSubjectFormatA>,
    #[serde(rename = "selectorSubjectFormatIndexed")]
    pub selector_subject_format_indexed: Option<SelectorSubjectFormatIndexed>,

    // Channel format selector: "index-grouped" (多线路) or "no-channel" (无线路区分)
    #[serde(rename = "channelFormatId")]
    pub channel_format_id: Option<String>,

    // Selectors for channel/episodes
    #[serde(rename = "selectorChannelFormatFlattened")]
    pub selector_channel_format_flattened: Option<SelectorChannelFormatFlattened>,
    #[serde(rename = "selectorChannelFormatNoChannel")]
    pub selector_channel_format_no_channel: Option<SelectorChannelFormatNoChannel>,

    // Video matching
    #[serde(rename = "matchVideo")]
    pub match_video: MatchVideo,

    #[serde(flatten)]
    pub extra: std::collections::HashMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorSubjectFormatA {
    #[serde(rename = "selectLists")]
    pub select_lists: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorSubjectFormatIndexed {
    #[serde(rename = "selectNames")]
    pub select_names: String,
    #[serde(rename = "selectLinks")]
    pub select_links: String,
    #[serde(rename = "preferShorterName")]
    pub prefer_shorter_name: Option<bool>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorChannelFormatFlattened {
    /// 选择channel名称的CSS选择器（如线路A、简中、繁中等）
    #[serde(rename = "selectChannelNames")]
    pub select_channel_names: Option<String>,
    /// 从channel名称中提取名字的正则表达式，使用命名捕获组 (?<ch>...)
    #[serde(rename = "matchChannelName")]
    pub match_channel_name: Option<String>,
    #[serde(rename = "selectEpisodeLists")]
    pub select_episode_lists: String,
    #[serde(rename = "selectEpisodesFromList")]
    pub select_episodes_from_list: String,
    /// 从剧集链接元素中提取链接的CSS选择器（可选，默认从元素自身href获取）
    #[serde(rename = "selectEpisodeLinksFromList")]
    pub select_episode_links_from_list: Option<String>,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SelectorChannelFormatNoChannel {
    #[serde(rename = "selectEpisodes")]
    pub select_episodes: String,
    /// 从剧集元素中提取链接的CSS选择器（可选，默认从元素自身href获取）
    #[serde(rename = "selectEpisodeLinks")]
    pub select_episode_links: Option<String>,
    #[serde(rename = "matchEpisodeSortFromName")]
    pub match_episode_sort_from_name: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MatchVideo {
    #[serde(rename = "matchVideoUrl")]
    pub match_video_url: String,

    #[serde(rename = "enableNestedUrl")]
    pub enable_nested_url: Option<bool>,

    #[serde(rename = "matchNestedUrl")]
    pub match_nested_url: Option<String>,

    #[serde(rename = "cookies")]
    pub cookies: Option<String>,

    #[serde(rename = "addHeadersToVideo")]
    pub add_headers_to_video: Option<std::collections::HashMap<String, String>>,

    #[serde(flatten)]
    pub extra: std::collections::HashMap<String, serde_json::Value>,
}

/// Channel（线路）信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelInfo {
    /// Channel 名称（如"线路A"、"简中"、"繁中"等）
    pub name: String,
    /// Channel 索引
    pub index: usize,
}

/// 剧集信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeInfo {
    /// 剧集名称/标题
    pub name: String,
    /// 剧集URL
    pub url: String,
    /// 剧集号（如果能解析出来）
    pub episode_number: Option<u32>,
    /// 所属channel索引
    pub channel_index: usize,
}

/// 包含多channel信息的搜索结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResultWithChannels {
    /// 源名称
    pub source_name: String,
    /// 动画详情页URL
    pub detail_url: String,
    /// 匹配到的动画名称
    pub matched_title: String,
    /// 所有可用的channels（线路）
    pub channels: Vec<ChannelInfo>,
    /// 所有剧集列表（按channel分组）
    pub episodes: Vec<EpisodeInfo>,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: String,
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers
    pub headers: Option<std::collections::HashMap<String, String>>,
    /// 默认字幕语言
    pub default_subtitle_language: Option<String>,
    /// 默认分辨率
    pub default_resolution: Option<String>,
}

/// 搜索结果：包含播放页面URL和视频URL匹配正则
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchPlayResult {
    /// 源名称
    pub source_name: String,
    /// 播放页面 URL
    pub play_page_url: String,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: String,
    /// 直接解析得到的视频URL（如果有）
    pub direct_video_url: Option<String>,
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers (Referer, User-Agent etc)
    pub headers: Option<std::collections::HashMap<String, String>>,
    /// Channel 名称（如果有多channel）
    pub channel_name: Option<String>,
    /// Channel 索引
    pub channel_index: Option<usize>,
    /// 验证码配置JSON（如果该源启用了captcha绕过）
    pub captcha_config_json: Option<String>,
    /// 是否启用嵌套URL匹配
    #[serde(default)]
    pub enable_nested_url: bool,
    /// 嵌套URL匹配正则
    pub match_nested_url: Option<String>,
}
/// 搜索进度状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SearchStep {
    /// 等待中
    Pending,
    /// 正在搜索
    Searching,
    /// 正在获取详情页
    FetchingDetail,
    /// 正在获取剧集列表
    FetchingEpisodes,
    /// 正在提取视频URL
    ExtractingVideo,
    /// 搜索成功
    Success,
    /// 搜索失败
    Failed,
}

/// 带状态的搜索进度
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceSearchProgress {
    /// 源名称
    pub source_name: String,
    /// 当前搜索步骤
    pub step: SearchStep,
    /// 错误信息（如果有）
    pub error: Option<String>,
    /// 播放页面 URL（如果找到）
    pub play_page_url: Option<String>,
    /// 用于匹配视频URL的正则表达式
    pub video_regex: Option<String>,
    /// 直接解析得到的视频URL（如果有）
    pub direct_video_url: Option<String>,
    /// 播放所需的 Cookie
    pub cookies: Option<String>,
    /// 播放所需的 Headers
    pub headers: Option<std::collections::HashMap<String, String>>,
    /// Channel 名称（如果有多channel）
    pub channel_name: Option<String>,
    /// Channel 索引
    pub channel_index: Option<usize>,
    /// 所有可用的channels（搜索成功时填充）
    pub all_channels: Option<Vec<ChannelInfo>>,
    /// 验证码配置JSON（如果该源启用了captcha绕过）
    pub captcha_config_json: Option<String>,
    /// 是否启用嵌套URL匹配
    #[serde(default)]
    pub enable_nested_url: bool,
    /// 嵌套URL匹配正则
    pub match_nested_url: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceConfigUpdate {
    pub name: String,
    pub new_name: Option<String>,
    pub tier: Option<i32>,
    pub default_subtitle_language: Option<String>,
    pub default_resolution: Option<String>,
    pub search_url: Option<String>,
    pub icon_url: Option<String>,
    pub description: Option<String>,
    pub search_config_json: Option<String>,
    pub captcha_config_json: Option<String>,
}
