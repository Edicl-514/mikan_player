// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get playerAppFullscreen => 'App fullscreen';

  @override
  String get playerAppFullscreenExit => 'Exit app fullscreen';

  @override
  String get playerWindowFullscreen => 'Window fullscreen';

  @override
  String get playerWindowFullscreenExit => 'Exit window fullscreen';

  @override
  String get appTitle => 'Mikan Player';

  @override
  String get homeTitle => 'Mikan Player';

  @override
  String get statusEnterMagnet => 'Enter a magnet link to start';

  @override
  String get statusInitializing => 'Initializing torrent...';

  @override
  String statusPlaying(Object streamUrl) {
    return 'Playing: $streamUrl';
  }

  @override
  String statusError(Object error) {
    return 'Error: $error';
  }

  @override
  String get magnetHint => 'magnet:?xt=urn:btih:...';

  @override
  String get playButton => 'Play';

  @override
  String get navHome => 'Home';

  @override
  String get navTimetable => 'Schedule';

  @override
  String get navRanking => 'Ranking';

  @override
  String get navIndex => 'Index';

  @override
  String get navMy => 'My';

  @override
  String get navSettings => 'Settings';

  @override
  String get searchHint => 'Search Anime';

  @override
  String get historyTitle => 'History';

  @override
  String get historyDeleteTooltip => 'Delete history entry';

  @override
  String get historySubtitle => 'Continue watching';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesRemoveTooltip => 'Remove from favorites';

  @override
  String get favoritesSubtitle => 'Collected anime';

  @override
  String get downloadTitle => 'Downloads';

  @override
  String get downloadSubtitle => 'Manage downloaded videos';

  @override
  String get aboutTitle => 'About';

  @override
  String version(Object version) {
    return 'Version $version';
  }

  @override
  String get loginPrompt => 'Click to Login';

  @override
  String get loginSubtitle => 'Sync Bangumi data';

  @override
  String get logoutTitle => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to clear the user cache?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get logout => 'Logout';

  @override
  String get clearCompleted => 'Clear Completed';

  @override
  String get noDownloads => 'No download tasks';

  @override
  String get startDownloadHint =>
      'Select a resource on the player page to start downloading';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String get clearConfirmTitle => 'Confirm Clear';

  @override
  String clearConfirmMessage(Object count) {
    return 'Will clear $count completed tasks';
  }

  @override
  String get deleteFiles => 'Also delete physical files';

  @override
  String get noCompletedTasks => 'No completed tasks';

  @override
  String clearedTasks(Object count) {
    return 'Cleared $count tasks';
  }

  @override
  String get downloading => 'Downloading';

  @override
  String get seeding => 'Seeding';

  @override
  String get paused => 'Paused';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusMetadata => 'Fetching metadata';

  @override
  String get statusChecking => 'Verifying';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get clickToPlay => 'Click to play';

  @override
  String peers(Object count) {
    return '$count peers';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get dataSourceSettings => 'Data Source Settings';

  @override
  String get dataSourceSubtitle =>
      'Playback source subscription URL and source toggles';

  @override
  String get networkSettings => 'Network Settings';

  @override
  String get networkSettingsTitle => 'Network Settings';

  @override
  String get networkSettingsSubtitle =>
      'Base URLs, request mode, reverse proxy, ECH and DoH';

  @override
  String get networkSectionBaseUrl => 'Base URL';

  @override
  String get networkSectionBangumiMode => 'Bangumi request mode';

  @override
  String get networkSectionAdvanced => 'Advanced';

  @override
  String get networkBangumiRequestModeLegacy => 'Legacy';

  @override
  String get networkBangumiRequestModeHybrid => 'Hybrid (recommended)';

  @override
  String get networkBangumiRequestModeModern => 'Modern';

  @override
  String get networkBangumiOfflineBroadcastData => 'Offline broadcast data';

  @override
  String get networkBangumiDataLoading => 'Loading…';

  @override
  String get networkBangumiDataNotCached =>
      'Not cached — tap to download the offline fallback data';

  @override
  String networkBangumiDataCachedSize(String size) {
    return 'Cached $size';
  }

  @override
  String networkBangumiDataSyncTime(String time) {
    return 'Synced at $time';
  }

  @override
  String networkBangumiDataVersion(String version) {
    return 'v$version';
  }

  @override
  String networkBangumiDataFailedMins(int minutes) {
    return 'Last sync failed $minutes min ago';
  }

  @override
  String networkBangumiDataFailedHours(int hours) {
    return 'Last sync failed $hours h ago';
  }

  @override
  String get networkBangumiDataRefreshSuccess =>
      'Offline broadcast data updated';

  @override
  String get networkBangumiDataRefreshFailed =>
      'Update failed — please check your network';

  @override
  String get searchSettings => 'Search Settings';

  @override
  String get searchSubtitle => 'WebView concurrency and search parameters';

  @override
  String get downloadSettingsTitle => 'Download Settings';

  @override
  String get downloadSettingsSaveButton => 'Save settings';

  @override
  String get downloadSettingsSaved => 'Download settings saved';

  @override
  String get downloadSettingsInvalidNumber =>
      'Please enter a valid speed limit';

  @override
  String get downloadEngineTitle => 'BT Engine';

  @override
  String get downloadEngineSubtitle =>
      'New and auto-resumed BT tasks will use the selected backend';

  @override
  String get downloadEngineRqbitDescription =>
      'rqbit is built in Rust with low memory usage and fast startup. It excels at stream-while-downloading, making it a good fit for quickly previewing video content.';

  @override
  String get downloadEngineLibtorrentDescription =>
      'libtorrent is a mature C++ BT engine known for stable, efficient downloads and broad compatibility. It is well suited for full downloads and long-term seeding.';

  @override
  String get downloadParallelTasks => 'Parallel download tasks';

  @override
  String get downloadParallelHint => '1-10, default 3';

  @override
  String get downloadSpeedLimitsHeader => 'Speed Limits (0 = unlimited)';

  @override
  String get downloadDownloadLimit => 'Download limit (MB/s)';

  @override
  String get downloadDownloadLimitHint => '0 means unlimited';

  @override
  String get downloadUploadLimit => 'Upload limit (MB/s)';

  @override
  String get downloadUploadLimitHint => '0 means unlimited, BT only';

  @override
  String get allowBackgroundDownload => 'Allow background downloads';

  @override
  String get allowBackgroundDownloadSubtitle =>
      'Keep download tasks running after the app moves to the background';

  @override
  String get keepSeedingMode => 'Seeding mode';

  @override
  String get keepSeedingModeSubtitle =>
      'Keep running in the background after downloads switch to seeding';

  @override
  String get downloadSettingsEntrySubtitle =>
      'Parallel tasks, limits, BT engine, and background downloads';

  @override
  String get cacheManagement => 'Cache Management';

  @override
  String get clearCache => 'Clear All Cache';

  @override
  String get confirmClearCache => 'Confirm cache clear';

  @override
  String get clearCacheMessage =>
      'This will delete anime cache, all image caches, WebView network cache, cookies, and website storage. Some playback sources may require verification again. Continue?';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String cacheClearedFailed(Object error) {
    return 'Failed to clear cache: $error';
  }

  @override
  String cacheStatsSummary(
    int subjects,
    int characters,
    int relations,
    int timetables,
    int rankings,
    String imageSize,
    String htmlImageSize,
    String webViewCacheSize,
    String webViewStorageSize,
    String totalSize,
  ) {
    return 'Subjects: $subjects, Characters: $characters, Relations: $relations\nSchedule: $timetables, Rankings: $rankings\nApp images: $imageSize, HTML images: $htmlImageSize\nWebView cache: $webViewCacheSize, website data: $webViewStorageSize\nTotal clearable: $totalSize';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get loading => 'Loading...';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Select application language';

  @override
  String get chinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String get auto => 'System Default';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeModeSubtitle => 'Choose light or dark mode';

  @override
  String get themeModeSystem => 'System Default';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeSettings => 'Theme Settings';

  @override
  String get themeSettingsSubtitle => 'Theme mode and color settings';

  @override
  String get customThemeColor => 'Custom Theme Color';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get themeColorSubtitle => 'Choose app accent color';

  @override
  String get useMaterial3Color => 'Use Material Color';

  @override
  String get useMaterial3ColorSubtitle =>
      'Enable to use systemic color palette calculation, disable to use strict seed color';

  @override
  String get pureBackground => 'Pure Background';

  @override
  String get pureBackgroundSubtitle =>
      'Enable to use pure grayscale backgrounds without mixing theme color';

  @override
  String get todayBroadcast => 'Today\'s Broadcast';

  @override
  String get recentHot => 'Recent Hot';

  @override
  String get viewMore => 'View More';

  @override
  String get noTodayUpdate => 'No updates today';

  @override
  String get viewFullTimetable => 'View full timetable';

  @override
  String get noData => 'No data';

  @override
  String get noHistory => 'No history';

  @override
  String get noFavorites => 'No favorites';

  @override
  String updateTime(Object time) {
    return 'Update time: $time';
  }

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get others => 'Others';

  @override
  String get selectQuarter => 'Select Quarter';

  @override
  String get noAnimeFoundDay => 'No anime found for this day.';

  @override
  String get errorOccurred => 'Error occurred';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get retry => 'Retry';

  @override
  String get networkError =>
      'Network error, please check your settings or try again later';

  @override
  String get resourceNotFound => 'Resource not found (404)';

  @override
  String get aboutIntro =>
      'Personal anime watching software, identified as a clumsy imitation of Animeko';

  @override
  String get aboutSourceCode => 'Project Source Code: ';

  @override
  String get aboutTechStack => 'Tech Stack';

  @override
  String get aboutDataSources => 'Data Sources';

  @override
  String get aboutDataSourcesList =>
      'bgmlist bangumi Mikan Project DMHY DanDanPlay';

  @override
  String get aboutDisclaimer =>
      'Network synchronization is one-way, all data is stored locally and will not affect online accounts';

  @override
  String get techStackFlutter => 'Flutter: Cross-platform UI';

  @override
  String get techStackRust => 'Rust: Core Logic & Scraper';

  @override
  String get techStackDatabase => 'Drift: Local SQLite Database';

  @override
  String get techStackMediaKit => 'MediaKit: Video Player';

  @override
  String get techStackDanmaku => 'CanvasDanmaku: Danmaku Rendering';

  @override
  String get sourceMeta => 'Bangumi / bgmlist: Metadata & Schedule';

  @override
  String get sourceTorrent => 'Mikan / DMHY: Torrents & Magnets';

  @override
  String get sourceDanmaku => 'DanDanPlay: Danmaku';

  @override
  String get share => 'Share';

  @override
  String get copied => 'Copied';

  @override
  String get filterByStatus => 'Filter by Status';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterChecking => 'Verifying';

  @override
  String get filterCompleted => 'Completed';

  @override
  String get filterPaused => 'Paused';

  @override
  String get filterError => 'Error';

  @override
  String tasksCount(Object count) {
    return '$count tasks';
  }

  @override
  String get settingsSubtitle => 'App configuration';

  @override
  String get searchHintText => 'Search anime...';

  @override
  String get searchModeTooltip => 'Switch search mode';

  @override
  String get searchKeywordModeLabel => 'Keyword search';

  @override
  String get searchTagModeLabel => 'Tag search';

  @override
  String get searchEnterTag => 'Enter a tag to search';

  @override
  String get searchEnterTagsMulti =>
      'Enter tags to search, separated by spaces';

  @override
  String get searchSortTooltip => 'Switch sort order';

  @override
  String get searchSortRank => 'Ranking';

  @override
  String get searchSortMatch => 'Relevance';

  @override
  String get searchSortHeat => 'Favorites';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchEnterKeyword => 'Enter a keyword to search';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get loginDialogTitle => 'Login Bangumi';

  @override
  String get loginDialogMessage =>
      'Enter Bangumi username or ID to fetch public info';

  @override
  String get loginUsernameLabel => 'Username / ID';

  @override
  String get loginUsernameHint => 'Note: username, not nickname';

  @override
  String get loginError => 'Login failed, please check username or network';

  @override
  String get bangumiLoginTitle => 'Login with Bangumi';

  @override
  String get bangumiLoginInitError =>
      'Could not start login. The app may be missing its Bangumi credentials.';

  @override
  String get bangumiLoginCallbackError =>
      'The login callback could not be verified. Please try again.';

  @override
  String get bangumiSyncCollections => 'Sync collections';

  @override
  String get bangumiSyncStarted => 'Syncing collections...';

  @override
  String get bangumiSyncDone => 'Collections synced';

  @override
  String get bangumiSyncFailed => 'Sync failed, please try again later';

  @override
  String bangumiSyncFailedWithError(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String get bangumiLoginModeTitle => 'Choose collection mode';

  @override
  String get bangumiSyncMode => 'Sync mode';

  @override
  String get bangumiPublicMode => 'Public mode';

  @override
  String get bangumiSyncModeDescription =>
      'Authorize Bangumi and merge local collections with your cloud collection';

  @override
  String get bangumiPublicModeDescription =>
      'Enter a user ID or username to read public collections without changing the account';

  @override
  String get continueButton => 'Continue';

  @override
  String get cannotLoadEpisodes => 'Unable to load episode list';

  @override
  String get pleaseEnterAnimeName => 'Please enter anime name first';

  @override
  String get absoluteEpisodeMustBeInteger =>
      'Absolute episode must be an integer';

  @override
  String get relativeEpisodeMustBeInteger =>
      'Relative episode must be an integer';

  @override
  String get episodeMustBeGreaterThanZero => 'Episode must be greater than 0';

  @override
  String get save => 'Save';

  @override
  String get restoreDefault => 'Restore defaults';

  @override
  String get autoSelectFastestSource => 'Auto-select fastest source';

  @override
  String get refreshPlaybackSource => 'Refresh playback sources';

  @override
  String get playbackSourceSubscriptionUrl =>
      'Playback source subscription URL';

  @override
  String get bgmBaseUrl => 'Bgmlist Base URL';

  @override
  String get bangumiBaseUrl => 'Bangumi Base URL';

  @override
  String get mikanBaseUrl => 'Mikan Base URL';

  @override
  String get subscriptionSwitchTitle => 'Subscription toggles (global search)';

  @override
  String get customSourceDescription => 'Custom web search source';

  @override
  String get subscriptionSourceTag => 'Subscription';

  @override
  String get manualSourceTag => 'Manual';

  @override
  String get subscriptionSourceReadOnly =>
      'Subscription sources are read-only; toggle them or refresh the subscription to update';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get playbackSourceRefreshed => 'Playback sources refreshed';

  @override
  String playbackSourceRefreshedSynced(Object count) {
    return 'Playback sources refreshed, synced $count default switches';
  }

  @override
  String fastestSourceSwitched(Object latency, Object url) {
    return 'Switched to the fastest source: $url (${latency}ms)';
  }

  @override
  String refreshFailed(Object error) {
    return 'Refresh failed: $error';
  }

  @override
  String fetchCollectionsFailed(Object error) {
    return 'Failed to fetch collections: $error';
  }

  @override
  String get noLocalFavorites => 'No local favorites';

  @override
  String get loginBangumiFirst => 'Please log in to a Bangumi account first';

  @override
  String get goToLogin => 'Go to login';

  @override
  String get noBangumiFavorites => 'No Bangumi collection data';

  @override
  String get refreshAllFavorites => 'Refresh all favorites';

  @override
  String get rankingTitle => 'Ranking';

  @override
  String get rankingTrending => 'Recent Hot';

  @override
  String get rankingRanking => 'Ranking';

  @override
  String get indexDateRangeSelected => 'Range';

  @override
  String get indexDateRangeUnset => 'No date range';

  @override
  String get indexTimeModePoint => 'Point';

  @override
  String get indexTimeModeRange => 'Range';

  @override
  String loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String noRelatedAnime(Object tag) {
    return 'No anime related to \"$tag\" was found';
  }

  @override
  String get pageRetry => 'Retry';

  @override
  String get dataSourceConfigTitle => 'Data source config';

  @override
  String get searchConfigTitle => 'searchConfig';

  @override
  String get captchaConfigTitle => 'captchaConfig';

  @override
  String get dataSourceConfigSave => 'Save';

  @override
  String get dataSourceConfigAllowedChars => 'Allowed characters';

  @override
  String get dataSourceConfigBasicInfo => 'Basic information';

  @override
  String get dataSourceConfigCaptcha => 'Captcha';

  @override
  String get dataSourceConfigCaptchaSub =>
      'Optional. Configure only if the data source uses a captcha';

  @override
  String get dataSourceConfigChannelNameRegex => 'Channel name regex';

  @override
  String get dataSourceConfigChannelNameRegexHelper =>
      'You can use (?<ch>...) to capture the final name';

  @override
  String get dataSourceConfigChannelNameSelector => 'Channel name selector';

  @override
  String get dataSourceConfigChannelNameSelectorHelper =>
      'For example: channel, subtitle group, or play source tab';

  @override
  String get dataSourceConfigCookie => 'Cookie';

  @override
  String get dataSourceConfigCookieHelper =>
      'Cookie sent with video requests; can be left empty';

  @override
  String get dataSourceConfigDescription => 'Description';

  @override
  String get dataSourceConfigDetectSelector => 'Captcha detect selector';

  @override
  String get dataSourceConfigDistinguishChannelName =>
      'Distinguish channel names';

  @override
  String get dataSourceConfigDistinguishChannelNameSub =>
      'When disabled, same-named episodes from different channels are deduplicated';

  @override
  String get dataSourceConfigDistinguishSubjectName =>
      'Distinguish subject names';

  @override
  String get dataSourceConfigDistinguishSubjectNameSub =>
      'When disabled, same-named episodes from different search results are deduplicated';

  @override
  String dataSourceConfigEditing(String name) {
    return 'Edit: $name';
  }

  @override
  String get dataSourceConfigEnableCaptcha => 'Enable captcha handling';

  @override
  String get dataSourceConfigEnableCaptchaSub =>
      'Turn on to bypass a captcha on the detail page';

  @override
  String get dataSourceConfigEnableNestedUrl => 'Enable nested URL matching';

  @override
  String get dataSourceConfigEnableNestedUrlSub =>
      'First find the inner play page from the player page, then match the video URL';

  @override
  String get dataSourceConfigEpisodeLinkSelector =>
      'Episode link selector (inside list)';

  @override
  String get dataSourceConfigEpisodeLinkSelectorHelper =>
      'When empty, the episode element\'s own href is used';

  @override
  String get dataSourceConfigEpisodeListSelector => 'Episode list selector';

  @override
  String get dataSourceConfigEpisodeSelector => 'Episode selector';

  @override
  String get dataSourceConfigEpisodesFromListSelector =>
      'Episode selector (inside list)';

  @override
  String get dataSourceConfigExpectedLength => 'Captcha length';

  @override
  String get dataSourceConfigFilterAndPlayer => 'Filter and player selection';

  @override
  String get dataSourceConfigFilterByEpisodeSort => 'Filter by episode number';

  @override
  String get dataSourceConfigFilterByEpisodeSortSub =>
      'Resource titles must include the episode number; usually recommended on';

  @override
  String get dataSourceConfigFilterBySubjectName => 'Filter by subject name';

  @override
  String get dataSourceConfigFilterBySubjectNameSub =>
      'Resource titles must include the subject name';

  @override
  String get dataSourceConfigFromListEpisodeLinkSelector =>
      'Episode link selector';

  @override
  String get dataSourceConfigFromListEpisodeLinkSelectorHelper =>
      'When empty, the episode element\'s own href is used';

  @override
  String get dataSourceConfigIconUrl => 'Icon URL';

  @override
  String get dataSourceConfigIconUrlHint => 'https://...';

  @override
  String get dataSourceConfigImageSelector => 'Captcha image selector';

  @override
  String get dataSourceConfigInputSelector => 'Input selector';

  @override
  String get dataSourceConfigIntegerRequired => 'Please enter an integer';

  @override
  String dataSourceConfigIntegerRange(int min, int max) {
    return 'Enter an integer from $min to $max';
  }

  @override
  String get dataSourceConfigJsonPreviewSub =>
      'Used to review the saved content';

  @override
  String get dataSourceConfigJsonPreviewTitle => 'Generated JSON';

  @override
  String get dataSourceConfigJsonSchemaCaptcha => 'captchaConfig';

  @override
  String get dataSourceConfigJsonSchemaSearch => 'searchConfig';

  @override
  String get dataSourceConfigJsonSchemaNotConfigured => 'Not configured';

  @override
  String get dataSourceConfigLinkJsonPath => 'Link JsonPath';

  @override
  String get dataSourceConfigMatchVideoUrl => 'Video URL regex';

  @override
  String get dataSourceConfigMatchVideoUrlHelper =>
      'You can use (?<v>...) to capture the final play URL';

  @override
  String get dataSourceConfigName => 'Name';

  @override
  String get dataSourceConfigNameHelper => 'Name shown in the data source list';

  @override
  String get dataSourceConfigNameJsonPath => 'Name JsonPath';

  @override
  String get dataSourceConfigNestedUrlRegex => 'Nested URL regex';

  @override
  String get dataSourceConfigNew => 'New data source';

  @override
  String get dataSourceConfigNotMarked => 'Not tagged';

  @override
  String get dataSourceConfigPreferShorterName => 'Prefer shorter names';

  @override
  String get dataSourceConfigRefreshSelector => 'Refresh image selector';

  @override
  String get dataSourceConfigReferer => 'Referer';

  @override
  String get dataSourceConfigRefererHelper =>
      'Referer sent with the video request';

  @override
  String get dataSourceConfigRequestInterval => 'Request interval (ms)';

  @override
  String get dataSourceConfigRequestIntervalHelper =>
      'Wait time between requests';

  @override
  String get dataSourceConfigRequired => 'Required';

  @override
  String get dataSourceConfigResolutionLabel => 'Tag resolution';

  @override
  String get dataSourceConfigResolutionHelper =>
      'Used for player preferences and filtering';

  @override
  String get dataSourceConfigSaved => 'Configuration saved';

  @override
  String dataSourceConfigSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get dataSourceConfigSearchUrl => 'Search URL';

  @override
  String dataSourceConfigSearchUrlHelper(String keyword) {
    return '$keyword is replaced with the subject name';
  }

  @override
  String dataSourceConfigSearchUrlHint(String keyword) {
    return 'https://example.com/search?wd=$keyword';
  }

  @override
  String get dataSourceConfigSortRegex => 'Episode number regex';

  @override
  String get dataSourceConfigSortRegexHelper =>
      'Recommended: use (?<ep>...) to capture the episode number';

  @override
  String get dataSourceConfigStep1ParseResults =>
      'Step 1: parse search results';

  @override
  String get dataSourceConfigStep1ParseResultsSub =>
      'Extract subject names and detail page links from the search results';

  @override
  String get dataSourceConfigStep1Search => 'Step 1: search subjects';

  @override
  String get dataSourceConfigStep1SearchSub =>
      'Configure the search URL and search-term processing rules';

  @override
  String get dataSourceConfigStep2Channels =>
      'Step 2: parse channels and episodes';

  @override
  String get dataSourceConfigStep2ChannelsSub =>
      'Extract channels, episodes, and play page links from the detail page';

  @override
  String get dataSourceConfigStep3MatchVideo => 'Step 3: match video';

  @override
  String get dataSourceConfigStep3MatchVideoSub =>
      'Extract the final video URL and request headers from the play page';

  @override
  String get dataSourceConfigSubjectFormatA => 'Single label';

  @override
  String get dataSourceConfigSubjectFormatIndexed => 'Multiple labels';

  @override
  String get dataSourceConfigSubjectFormatJsonPath => 'JsonPath';

  @override
  String get dataSourceConfigChannelFormatIndexGrouped => 'Channel grouped';

  @override
  String get dataSourceConfigChannelFormatNoChannel => 'No channel';

  @override
  String get dataSourceConfigSubjectLinkSelector => 'Subject link selector';

  @override
  String get dataSourceConfigSubjectLinkSelectorHelper =>
      'Choose the subject detail page link from the search results';

  @override
  String get dataSourceConfigSubjectNameSelector => 'Subject name selector';

  @override
  String get dataSourceConfigSubjectRemoveSpecial =>
      'Remove special characters';

  @override
  String get dataSourceConfigSubjectRemoveSpecialSub =>
      'Strip symbols and common noise words to improve search compatibility';

  @override
  String get dataSourceConfigSubjectUseFirstWord => 'Use only the first word';

  @override
  String get dataSourceConfigSubjectUseFirstWordSub =>
      'Split the subject name on spaces and use only the first word for searching';

  @override
  String get dataSourceConfigSubjectUseNamesCount =>
      'Number of subject name attempts';

  @override
  String get dataSourceConfigSubjectUseNamesCountHelper =>
      'Leave empty to use the default. 1 means only the primary name is used';

  @override
  String get dataSourceConfigSubmitSelector => 'Submit button selector';

  @override
  String get dataSourceConfigSubtitleLabel => 'Tag subtitle language';

  @override
  String get dataSourceConfigSubtitleHelper =>
      'Used for player preferences and filtering';

  @override
  String get dataSourceConfigSuccessSelector => 'Success page selector';

  @override
  String get dataSourceConfigTier => 'Priority';

  @override
  String get dataSourceConfigTierHelper => 'Lower numbers have higher priority';

  @override
  String get dataSourceConfigType => 'Type';

  @override
  String get dataSourceConfigUseRawBaseUrl => 'Base URL';

  @override
  String get dataSourceConfigUseRawBaseUrlHelper =>
      'Optional. Used to build subject detail page links; usually inferred from the search URL when empty';

  @override
  String get dataSourceConfigUserAgent => 'User-Agent';

  @override
  String get dataSourceConfigUserAgentHelper =>
      'User-Agent sent with the video request';

  @override
  String get dataSourceConfigUseWebViewForCaptchaDetail =>
      'Use WebView for the detail page';

  @override
  String get dataSourceConfigCaptchaInitialDelay => 'Initial wait (ms)';

  @override
  String get searchSettingsTitle => 'Search settings';

  @override
  String get maxParallelSearchSources => 'Max parallel search sources';

  @override
  String get maxParallelSearchSourcesHint =>
      'Default 3, 0 means unlimited (Generic Scraper)';

  @override
  String get webviewScraperSettingsTitle =>
      'WebView Scraper settings (Dynamic WebView sources only)';

  @override
  String get maxWebviewConcurrent => 'App-wide WebView limit';

  @override
  String get maxWebviewConcurrentHint =>
      'Shared by all Player pages; recommended: 1-3';

  @override
  String get webviewLaunchInterval => 'WebView launch interval (ms)';

  @override
  String get webviewLaunchIntervalHint => 'Recommended: 200-1000';

  @override
  String get autoSearchOnlineTitle => 'Auto search online sources';

  @override
  String get autoSearchOnlineSubtitle =>
      'When disabled, the player page will only auto-search BT sources';

  @override
  String get cancelLowPrioritySourcesTitle =>
      'Cancel low-priority source extraction after playback';

  @override
  String get cancelLowPrioritySourcesSubtitle =>
      'After playback starts, cancel extraction of Tier≥1 sources; keep Tier 0 sources as alternates';

  @override
  String get localJsonPathLabel => 'Local JSON path (leave empty to use cache)';

  @override
  String get animeNameLabel => 'Anime name';

  @override
  String get animeNameHint => 'For example: Mobile Suit Gundam GQuuuuuuX';

  @override
  String get absoluteEpisodeLabel => 'Absolute episode';

  @override
  String get relativeEpisodeLabel => 'Relative episode';

  @override
  String get optionalEmptyHint => 'Can be left empty';

  @override
  String get sourceFilterLabel => 'Source name filter (optional)';

  @override
  String get sourceFilterHint => 'Case-insensitive, contains match';

  @override
  String get showWebViewDebugSwitch => 'Show WebView debug switch';

  @override
  String get showWebViewDebugSubtitle =>
      'Only affects the debug extraction view, not the search logic';

  @override
  String get clear => 'Clear';

  @override
  String get sourceCount => 'Source count';

  @override
  String get success => 'Success';

  @override
  String get failure => 'Failure';

  @override
  String get inProgress => 'In progress';

  @override
  String get noDebugSearchResult =>
      'No results yet. Fill in the parameters and tap \"Start debug search\".';

  @override
  String debugStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String channelLine(Object line) {
    return 'Channel: $line';
  }

  @override
  String playPage(Object url) {
    return 'Play page: $url';
  }

  @override
  String get extractUrl => 'Extract URL';

  @override
  String get extractDebugTitle => 'Playable URL extraction debug';

  @override
  String extractFailed(Object error) {
    return 'Extraction failed: $error';
  }

  @override
  String extractSuccess(Object url) {
    return 'Extraction succeeded: $url';
  }

  @override
  String get logsEmpty => 'No logs yet';

  @override
  String get subscriptionDebugTitle => 'Subscription debug';

  @override
  String get subscriptionDebugEntryTitle => 'Subscription debug (local JSON)';

  @override
  String get subscriptionDebugEntrySubtitle =>
      'Manually test subscription-source search and playable URL extraction';

  @override
  String get subscriptionDebugJsonTitle => 'Subscription JSON debug';

  @override
  String get subscriptionDebugDisabled =>
      'This build does not have subscription debug enabled.\nStart the app with --dart-define=ENABLE_SUBSCRIPTION_DEBUG=true.';

  @override
  String get subscriptionDebugInfo =>
      'This page is for debugging only: it prefers local JSON, falls back to the cached JSON when left empty, and will not modify cache files, override subscription settings, or affect the normal playback flow.';

  @override
  String searchError(Object error) {
    return 'Search error: $error';
  }

  @override
  String get searchLogs => 'Search logs';

  @override
  String get extractLogs => 'Extraction logs';

  @override
  String get stepPending => 'Pending';

  @override
  String get stepSearching => 'Searching';

  @override
  String get stepFetchingDetail => 'Fetching detail page';

  @override
  String get stepFetchingEpisodes => 'Fetching episodes';

  @override
  String get stepExtractingVideo => 'Extracting play page';

  @override
  String get stepSuccess => 'Success';

  @override
  String get stepFailed => 'Failed';

  @override
  String get characterDetailsLoadFailed => 'Failed to load character details';

  @override
  String get personDetailsLoadFailed => 'Failed to load person details';

  @override
  String get retryButton => 'Retry';

  @override
  String get favoritesTabLocal => 'Local favorites';

  @override
  String get favoritesTabBangumi => 'Bangumi sync';

  @override
  String notFoundAnimeTag(Object tag) {
    return 'No anime related to \"$tag\" was found';
  }

  @override
  String get addToLocalFavorites => 'Added to local favorites';

  @override
  String get removeFromFavorites => 'Removed from favorites';

  @override
  String get favoriteStatusUpdated => 'Favorite status updated';

  @override
  String favoriteUpdateFailed(Object error) {
    return 'Failed to update favorite: $error';
  }

  @override
  String get bangumiCollectionEditorTitle => 'Edit Bangumi collection';

  @override
  String get bangumiCollectionStatus => 'Collection status';

  @override
  String get bangumiCollectionRating => 'My rating';

  @override
  String get bangumiCollectionNotRated => 'Not rated';

  @override
  String bangumiCollectionRatingValue(int rating) {
    return '$rating / 10';
  }

  @override
  String get bangumiCollectionComment => 'My comment';

  @override
  String get bangumiCollectionCommentHint =>
      'Share your thoughts about this title';

  @override
  String get bangumiCollectionTags => 'My tags';

  @override
  String get bangumiCollectionTagInputHint => 'Enter a tag and press Return';

  @override
  String get bangumiCollectionAddTag => 'Add tag';

  @override
  String get bangumiCollectionSuggestedTags => 'Subject tags';

  @override
  String get bangumiCollectionPrivate => 'Private collection';

  @override
  String get bangumiCollectionPrivateDescription => 'Visible only to you';

  @override
  String get bangumiCollectionSave => 'Save collection';

  @override
  String get bangumiCollectionRemove => 'Remove collection';

  @override
  String get bangumiCollectionAdded => 'Added to Bangumi collection';

  @override
  String get bangumiCollectionUpdated => 'Bangumi collection updated';

  @override
  String bangumiCollectionLoadFailed(Object error) {
    return 'Failed to load Bangumi collection: $error';
  }

  @override
  String bangumiCollectionUpdateFailed(Object error) {
    return 'Failed to update Bangumi collection: $error';
  }

  @override
  String bangumiCollectionInvalidTag(Object tag) {
    return 'Tags cannot contain whitespace: $tag';
  }

  @override
  String get collectionConflictTitle => 'Collection conflicts';

  @override
  String collectionConflictDescription(Object count) {
    return '$count entries have different local and Bangumi statuses. Choose which version to keep.';
  }

  @override
  String collectionConflictIndex(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get collectionResolveConflicts => 'Apply choices';

  @override
  String get collectionKeepLocal => 'Keep local';

  @override
  String get collectionKeepBangumi => 'Keep Bangumi';

  @override
  String get collectionSourceLocal => 'Local collection';

  @override
  String get collectionConflictStatus => 'Status';

  @override
  String get collectionConflictUpdated => 'Updated';

  @override
  String get collectionConflictFieldStatus => 'Collection status';

  @override
  String get collectionConflictFieldRate => 'Rating';

  @override
  String get collectionConflictFieldComment => 'Comment';

  @override
  String get collectionConflictFieldTags => 'Tags';

  @override
  String get collectionConflictFieldPrivate => 'Privacy';

  @override
  String get collectionConflictRemoteDeleted => 'Deleted on Bangumi';

  @override
  String get collectionConflictReupload => 'Re-upload to Bangumi';

  @override
  String get collectionConflictDeleteLocal => 'Delete local collection';

  @override
  String get collectionConflictPrivateYes => 'Private';

  @override
  String get collectionConflictPrivateNo => 'Public';

  @override
  String get collectionConflictNotSet => 'Not set';

  @override
  String get collectionConflictEmpty => 'Empty';

  @override
  String get collectionConflictResolveNext => 'Apply and next';

  @override
  String get collectionConflictResolvePrevious => 'Previous';

  @override
  String get playSourceTitle => 'Play sources';

  @override
  String get episodeListTitle => 'Episodes';

  @override
  String get relatedRecommendationsTitle => 'Related recommendations';

  @override
  String get commentsTitle => 'Comments';

  @override
  String get allComments => 'All comments';

  @override
  String get noComments => 'No comments';

  @override
  String get noRelatedRecommendationsText => 'No related recommendations';

  @override
  String commentsLoadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get initializingPlayback => 'Initializing playback...';

  @override
  String get playbackFailed => 'Playback failed';

  @override
  String get chooseSourceToWatch => 'Choose a source to start watching';

  @override
  String get chooseSourceBelow =>
      'Select a resource in the \"Play sources\" section below';

  @override
  String get defaultSort => 'Default sort';

  @override
  String get sortByTime => 'Sort by time';

  @override
  String get searchOnlineSource => 'Search online sources';

  @override
  String get searchBtSource => 'Search BT sources';

  @override
  String get btSearching => 'Searching BT sources...';

  @override
  String btFound(Object count) {
    return 'Found $count BT sources';
  }

  @override
  String get btSearchFailed => 'BT search failed';

  @override
  String get btNotStarted => 'BT search has not started yet';

  @override
  String get btLoaded => 'Playing local resource';

  @override
  String get btManualSearchHint =>
      'For online sources, tap the button below to search manually';

  @override
  String get btSearchHint => 'Tap the button below to start searching';

  @override
  String get waitingForPlayPage => 'Waiting for a matching play page...';

  @override
  String get loadingText => 'Loading';

  @override
  String get playText => 'Play';

  @override
  String get copyMagnetSuccess => 'Magnet link copied';

  @override
  String get downloadStartedHint =>
      'Download started, you can check progress on the \"My\" page';

  @override
  String get noDownloadableOnlineSource => 'No downloadable online source';

  @override
  String get cannotGetPlaybackUrl => 'Unable to get playback URL';

  @override
  String get downloadTaskAdded => 'Added to download tasks';

  @override
  String get pauseFailed => 'Pause failed';

  @override
  String get resumeFailed => 'Resume failed';

  @override
  String get loadedDanmaku => 'Danmaku loaded';

  @override
  String get currentMatch => 'Current match';

  @override
  String get searchResult => 'Search results';

  @override
  String get episodeList => 'Episode list';

  @override
  String danmakuCount(Object count) {
    return '$count danmaku entries';
  }

  @override
  String get danmakuSettingsDisplayTab => 'Display settings';

  @override
  String get danmakuSettingsSourceTab => 'Danmaku source';

  @override
  String get danmakuSettingsVisibilitySection => 'Display type';

  @override
  String get danmakuSettingsStyleSection => 'Style settings';

  @override
  String get danmakuSettingsEnable => 'Show danmaku';

  @override
  String get danmakuSettingsScrolling => 'Scrolling danmaku';

  @override
  String get danmakuSettingsTop => 'Top danmaku';

  @override
  String get danmakuSettingsBottom => 'Bottom danmaku';

  @override
  String get danmakuSettingsOpacity => 'Opacity';

  @override
  String get danmakuSettingsSpeed => 'Danmaku speed';

  @override
  String danmakuSettingsSpeedValue(Object seconds) {
    return '${seconds}s';
  }

  @override
  String get danmakuSettingsDisplayArea => 'Display area';

  @override
  String get danmakuSettingsFontWeight => 'Font weight';

  @override
  String get danmakuSettingsFontWeightUltraLight => 'Ultra light';

  @override
  String get danmakuSettingsFontWeightExtraLight => 'Extra light';

  @override
  String get danmakuSettingsFontWeightLight => 'Light';

  @override
  String get danmakuSettingsFontWeightSemiLight => 'Semi light';

  @override
  String get danmakuSettingsFontWeightRegular => 'Regular';

  @override
  String get danmakuSettingsFontWeightSemiBold => 'Semi bold';

  @override
  String get danmakuSettingsFontWeightBold => 'Bold';

  @override
  String get danmakuSettingsFontWeightExtraBold => 'Extra bold';

  @override
  String get danmakuSettingsFontWeightBlack => 'Black';

  @override
  String get subtitlePreviewText => 'Subtitle preview';

  @override
  String get noAvailablePlaybackSource => 'No available playback source';

  @override
  String get showSubtitles => 'Show subtitles';

  @override
  String get subtitleTracks => 'Subtitle tracks';

  @override
  String get noEmbeddedSubtitles => 'This video has no embedded subtitles';

  @override
  String get disableSubtitles => 'Disable subtitles';

  @override
  String get subtitleStyle => 'Subtitle style';

  @override
  String get fontSize => 'Font size';

  @override
  String get backgroundOpacity => 'Background opacity';

  @override
  String get bottomPadding => 'Bottom padding';

  @override
  String get outlineWidth => 'Outline width';

  @override
  String get fontColor => 'Font color';

  @override
  String get subtitlePreview => 'Subtitle preview';

  @override
  String get noAvailableSource => 'No available source';

  @override
  String get back => 'Back';

  @override
  String get playerMoreOptions => 'More';

  @override
  String get unlock => 'Unlock';

  @override
  String get lock => 'Lock';

  @override
  String get danmaku => 'Danmaku';

  @override
  String get selectEpisode => 'Episodes';

  @override
  String get skipBack85 => 'Skip -85s';

  @override
  String get skipForward85 => 'Skip +85s';

  @override
  String get autoPlayNext => 'Auto play next';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get normalSpeed => 'Normal';

  @override
  String get playbackSpeedTip =>
      'Tip: playback speed affects both video and danmaku synchronization.';

  @override
  String subtitleTrackCount(Object count) {
    return '$count episodes';
  }

  @override
  String playWithSource(Object source) {
    return 'Play - $source';
  }

  @override
  String get selectedSourceUnknown => 'Unknown';

  @override
  String get downloadDirTitle => 'Download Path';

  @override
  String get downloadDirBrowse => 'Browse';

  @override
  String get downloadDirPickerTitle => 'Select Download Directory';

  @override
  String get bangumiDetailsEpisodes => 'Episodes';

  @override
  String get bangumiDetailsStory => 'Story';

  @override
  String get bangumiDetailsRelatedItems => 'Related Items';

  @override
  String get bangumiDetailsRelatedSites => 'Related Sites';

  @override
  String get bangumiDetailsTags => 'Tags';

  @override
  String get bangumiReverseProxyTitle => 'Use Bangumi reverse proxy';

  @override
  String get bangumiReverseProxyDescription =>
      'When enabled, all Bangumi requests are routed through the mirror.';

  @override
  String get bangumiEchTitle => 'Encrypt SNI with ECH';

  @override
  String get bangumiEchDescription =>
      'Hide the real hostname via Encrypted Client Hello to bypass SNI blacklists. Recommended in mainland China.';

  @override
  String get bangumiEchRefreshTitle => 'Refresh ECH public key';

  @override
  String get bangumiEchRefreshDescription =>
      'Re-fetch the ECHConfig from the DoH list in priority order (cached for ~1 hour)';

  @override
  String bangumiEchRefreshSuccess(Object bytes) {
    return 'Updated ($bytes bytes)';
  }

  @override
  String get bangumiEchRefreshFailed =>
      'Refresh failed — will fall back to plain mode';

  @override
  String get bangumiEchDohListTitle => 'DoH endpoint list';

  @override
  String get bangumiEchDohListDescription =>
      'Used to query Cloudflare\'s HTTPS RR for the ECH public key. Tried in order; the first reachable one wins. Tap \"Reset to defaults\" to restore the built-in list.';

  @override
  String get bangumiEchDohListEmpty => 'Empty — using built-in defaults';

  @override
  String get bangumiEchDohAddTitle => 'Add DoH endpoint';

  @override
  String get bangumiEchDohAddHint => 'https://your-doh.example/dns-query';

  @override
  String get bangumiEchDohAddInvalid => 'URL must start with https://';

  @override
  String get bangumiEchDohMoveUp => 'Move up';

  @override
  String get bangumiEchDohMoveDown => 'Move down';

  @override
  String get bangumiEchDohRemove => 'Remove';

  @override
  String get bangumiEchDohReset => 'Reset to defaults';

  @override
  String get bangumiEchDohResetConfirm =>
      'Clear your custom DoH list and fall back to the built-in defaults?';

  @override
  String get bangumiEchDohTestTitle => 'Test this DoH';

  @override
  String bangumiEchDohTestSuccess(Object bytes) {
    return 'OK — received $bytes bytes of ECHConfig';
  }

  @override
  String get bangumiEchDohTestFailed =>
      'Unreachable or response contained no ECHConfig';

  @override
  String bangumiEchDohPriority(Object index) {
    return 'Priority #$index';
  }

  @override
  String get manageUrls => 'Manage URLs';

  @override
  String get manageUrlsTitle => 'Manage selectable URLs';

  @override
  String get addUrl => 'Add';

  @override
  String get addUrlHint => 'https://...';

  @override
  String get builtinUrl => 'Built-in';

  @override
  String get removeUrl => 'Remove';

  @override
  String get builtinUrlCannotRemove => 'Built-in URLs cannot be removed';

  @override
  String get urlAlreadyExists => 'This URL already exists';

  @override
  String get invalidUrl =>
      'Enter a valid URL (starting with http:// or https://)';

  @override
  String get bangumiBaseUrlHidden =>
      'ECH or reverse proxy is enabled — Bangumi Base URL is hidden';

  @override
  String get closeSettingsBarrier => 'Close settings';

  @override
  String get closeEpisodesBarrier => 'Close episodes';

  @override
  String get statusEnabled => 'On';

  @override
  String get statusDisabled => 'Off';

  @override
  String get noSubtitlesAvailable => 'No subtitles';

  @override
  String get danmakuSettingsTitle => 'Danmaku settings';

  @override
  String get subtitleSettingsTitle => 'Subtitle settings';

  @override
  String get commonPlaybackSpeeds => 'Common speeds';

  @override
  String playbackSpeedWithNormal(String speed) {
    return '$speed (Normal)';
  }

  @override
  String currentSourceOnly(String label) {
    return 'Current: $label';
  }

  @override
  String currentSourceWithOnlineCount(String label, int count) {
    return 'Current: $label ($count online sources)';
  }

  @override
  String sourceLabelWithAvailableCount(String label, int count) {
    return '$label ($count available)';
  }

  @override
  String get noAvailableSourcesShort => 'No sources available';

  @override
  String get notPlaying => 'Not playing';

  @override
  String rewindSeconds(int seconds) {
    return 'Rewind ${seconds}s';
  }

  @override
  String forwardSeconds(int seconds) {
    return 'Forward ${seconds}s';
  }

  @override
  String brightnessPercent(int percent) {
    return 'Brightness $percent%';
  }

  @override
  String volumePercent(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get longPressFastForward => 'Hold for 2x';

  @override
  String get bangumiDetailsTabDetails => 'Details';

  @override
  String get bangumiDetailsTabComments => 'Comments';

  @override
  String get bangumiDetailsCharacters => 'Characters';

  @override
  String get bangumiDetailsComments => 'Comments';

  @override
  String get bangumiDetailsNoComments => 'No comments yet';

  @override
  String get bangumiDetailsNoSummary => 'No summary';

  @override
  String get bangumiDetailsFavorite => 'Favorite';

  @override
  String get bangumiDetailsFavorited => 'Favorited';

  @override
  String bangumiDetailsCollectionStats(int wish, int doing, int dropped) {
    return '$wish wish / $doing watching / $dropped dropped';
  }

  @override
  String bangumiDetailsRatingVotes(int count) {
    return '$count votes';
  }

  @override
  String bangumiDetailsRatingVotesWithRank(int count, int rank) {
    return '$count votes | #$rank';
  }

  @override
  String bangumiDetailsVotes(int count) {
    return '$count votes';
  }

  @override
  String bangumiDetailsRanked(int rank) {
    return 'Ranked #$rank';
  }

  @override
  String get bangumiDetailsCollectWish => 'Wish';

  @override
  String get bangumiDetailsCollectDoing => 'Watching';

  @override
  String get bangumiDetailsCollectDropped => 'Dropped';

  @override
  String bangumiDetailsLoadingSection(String title) {
    return 'Loading $title...';
  }

  @override
  String get bangumiDetailsComingSoon => '(Coming Soon)';

  @override
  String get bangumiDetailsShowTranslation => 'Tap to show translation';

  @override
  String get bangumiDetailsShowOriginal => 'Tap to show original';

  @override
  String get bangumiDetailsCollapse => 'Collapse';

  @override
  String get bangumiDetailsExpand => 'Expand';

  @override
  String get bangumiDetailsInformation => 'Information';

  @override
  String bangumiDetailsMoreInfoItems(int count) {
    return '$count more items — tap Expand for full info';
  }

  @override
  String bangumiDetailsYearMonth(int year, int month) {
    return '$month/$year';
  }

  @override
  String bangumiDetailsTotalEpisodes(int count) {
    return '$count episodes';
  }

  @override
  String get bangumiDetailsZeroEpisodes => '0 episodes';

  @override
  String get bangumiDetailsSiteOnair => 'On air';

  @override
  String get bangumiDetailsSiteInfo => 'Info';

  @override
  String get bangumiDetailsSiteResource => 'Resource';

  @override
  String get bangumiDetailsRoleMain => 'Main';

  @override
  String get bangumiDetailsRoleSupporting => 'Supporting';

  @override
  String get bangumiDetailsRoleMinor => 'Minor';

  @override
  String get bangumiDetailsCvPrefix => 'CV: ';

  @override
  String detailsCommentsCount(int count) {
    return '$count comments';
  }

  @override
  String detailsCollectsCount(int count) {
    return '$count collects';
  }

  @override
  String get detailsCommentsLabel => 'Comments';

  @override
  String get detailsCollectsLabel => 'Collects';

  @override
  String get detailsSectionSummary => 'Summary';

  @override
  String get detailsSectionInfo => 'Information';

  @override
  String get detailsSectionAppearances => 'Appearances';

  @override
  String get detailsSectionRelatedWorks => 'Related works';

  @override
  String get detailsSectionVoiceRoles => 'Voice roles';

  @override
  String detailsWorksCount(int count) {
    return '$count works';
  }

  @override
  String detailsCvName(String name) {
    return 'CV: $name';
  }

  @override
  String get detailsGenderMale => 'Male';

  @override
  String get detailsGenderFemale => 'Female';

  @override
  String detailsBirthdayYear(int year) {
    return '$year';
  }

  @override
  String detailsBirthdayMonth(int month) {
    return '$month';
  }

  @override
  String detailsBirthdayDay(int day) {
    return '$day';
  }

  @override
  String get detailsBirthdaySeparator => '-';

  @override
  String get personCareerSeiyu => 'Voice actor';

  @override
  String get personCareerProducer => 'Producer';

  @override
  String get personCareerMangaka => 'Mangaka';

  @override
  String get personCareerArtist => 'Musician';

  @override
  String get personCareerWriter => 'Writer';

  @override
  String get personCareerIllustrator => 'Illustrator';

  @override
  String get historyEmptyHint =>
      'History appears after you start watching on the player page';

  @override
  String homeOriginalWork(String name) {
    return 'Original: $name';
  }

  @override
  String homeDirector(String name) {
    return 'Director: $name';
  }

  @override
  String homeEpisodeProgress(String sort, String name) {
    return 'EP $sort | $name';
  }

  @override
  String get favoritesStatusWish => 'Wish';

  @override
  String get favoritesStatusWatched => 'Watched';

  @override
  String get favoritesStatusWatching => 'Watching';

  @override
  String get favoritesStatusOnHold => 'On hold';

  @override
  String get favoritesStatusDropped => 'Dropped';

  @override
  String get favoritesStatusUnknown => 'Unknown';

  @override
  String downloadEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get downloadDeleteRunningConfirm =>
      'This task is still running. Stop and delete it?';

  @override
  String get searchSortDate => 'Date';

  @override
  String get searchSortTitle => 'Title';

  @override
  String timetableQuarterTitle(int year, int quarter) {
    return '$year Q$quarter';
  }

  @override
  String get indexFilterCategory => 'Category';

  @override
  String get indexFilterSource => 'Source';

  @override
  String get indexFilterType => 'Genre';

  @override
  String get indexFilterRegion => 'Region';

  @override
  String get indexFilterSort => 'Sort';

  @override
  String get indexFilterTime => 'Time';

  @override
  String get indexFilterMonth => 'Month';

  @override
  String get indexUnlimited => 'Any';

  @override
  String get indexSortRank => 'Rank';

  @override
  String get indexSortMatch => 'Match';

  @override
  String get indexSortHeat => 'Collects';

  @override
  String get indexSortTrends => 'Trends';

  @override
  String get indexSortCollect => 'Collect';

  @override
  String get indexSortDate => 'Date';

  @override
  String get indexSortTitle => 'Title';

  @override
  String get indexCategoryMovie => 'Movie';

  @override
  String get indexCategoryOther => 'Other';

  @override
  String get indexSourceOriginal => 'Original';

  @override
  String get indexSourceManga => 'Manga';

  @override
  String get indexSourceGame => 'Game';

  @override
  String get indexSourceNovel => 'Novel';

  @override
  String get indexSourceLiveAction => 'Live action';

  @override
  String indexMonthLabel(int month) {
    return '$month';
  }

  @override
  String get indexRegionJapan => 'Japan';

  @override
  String get indexRegionWestern => 'Western';

  @override
  String get indexRegionChina => 'China';

  @override
  String get indexRegionUsa => 'United States';

  @override
  String get indexRegionKorea => 'Korea';

  @override
  String get indexRegionFrance => 'France';

  @override
  String get indexRegionHongKong => 'Hong Kong';

  @override
  String get indexRegionUk => 'United Kingdom';

  @override
  String get indexRegionRussia => 'Russia';

  @override
  String get indexRegionSoviet => 'Soviet Union';

  @override
  String get indexRegionCzech => 'Czechia';

  @override
  String get indexRegionTaiwan => 'Taiwan';

  @override
  String get indexRegionMalaysia => 'Malaysia';

  @override
  String get indexGenreScifi => 'Sci-Fi';

  @override
  String get indexGenreComedy => 'Comedy';

  @override
  String get indexGenreDoujin => 'Doujin';

  @override
  String get indexGenreYuri => 'Yuri';

  @override
  String get indexGenreSchool => 'School';

  @override
  String get indexGenreThriller => 'Thriller';

  @override
  String get indexGenreHarem => 'Harem';

  @override
  String get indexGenreMecha => 'Mecha';

  @override
  String get indexGenreMystery => 'Mystery';

  @override
  String get indexGenreRomance => 'Romance';

  @override
  String get indexGenreFantasy => 'Fantasy';

  @override
  String get indexGenreDetective => 'Detective';

  @override
  String get indexGenreSports => 'Sports';

  @override
  String get indexGenreBoysLove => 'BL';

  @override
  String get indexGenreMusic => 'Music';

  @override
  String get indexGenreAction => 'Action';

  @override
  String get indexGenreAdventure => 'Adventure';

  @override
  String get indexGenreMoe => 'Moe';

  @override
  String get indexGenreIsekai => 'Isekai';

  @override
  String get indexGenreXuanhuan => 'Xuanhuan';

  @override
  String get indexGenreOtome => 'Otome';

  @override
  String get indexGenreHorror => 'Horror';

  @override
  String get indexGenreHistory => 'History';

  @override
  String get indexGenreSliceOfLife => 'Slice of Life';

  @override
  String get indexGenreDrama => 'Drama';

  @override
  String get indexGenreWuxia => 'Wuxia';

  @override
  String get indexGenreFood => 'Food';

  @override
  String get indexGenreWorkplace => 'Workplace';

  @override
  String get playerMobileEpisodeSelector => 'Episodes';

  @override
  String get playerMobilePlaySource => 'Play sources';

  @override
  String get playerMobileOfficialPlaySource => 'Official sources';

  @override
  String get playerMobileRelated => 'Related';

  @override
  String get playerMobileSummaryAndRecommend => 'Summary & recommendations';

  @override
  String playerMobileCommentsTab(int count) {
    return 'Comments ($count)';
  }

  @override
  String playerMobilePlayableEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Episodes',
      one: '1 Episode',
      zero: 'No episodes',
    );
    return '$_temp0';
  }

  @override
  String get playerPcEpisodeList => 'Episodes';

  @override
  String get playerPcPlaylist => 'Playlist';

  @override
  String get playerPcCommentsSection => 'Comments';

  @override
  String playerSourceTitleFound(int count, int online, String current) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count BT sources',
      one: 'Found 1 BT source',
    );
    String _temp1 = intl.Intl.pluralLogic(
      online,
      locale: localeName,
      other: '$online subscriptions',
      one: '1 subscription',
    );
    return '$_temp0, $_temp1, current: $current';
  }

  @override
  String playerSourceTitleCurrent(String label) {
    return 'Current: $label';
  }

  @override
  String get playerSourceTitleFoundMobile => 'Found';

  @override
  String get playerSourceTabBt => 'BT';

  @override
  String get playerSourceTabSubscription => 'Subscriptions';

  @override
  String get playerSourceLabelOnline => 'Online source';

  @override
  String get playerSourceLabelBt => 'BT download';

  @override
  String get playerSourceLabelOnlineShort => 'Online';

  @override
  String get playerNoDownloadableSource => 'No downloadable online source';

  @override
  String get playerAddDownloadTaskFailed =>
      'Failed to add download task, please try again';

  @override
  String get playerAddDownloadTaskSuccess => 'Added to download tasks';

  @override
  String get playerNoCopyableLink => 'No copyable download link';

  @override
  String get playerDownloadLinkCopied => 'Download link copied';

  @override
  String get playerDownloadButton => 'Download';

  @override
  String get playerCopyDownloadLinkButton => 'Copy link';

  @override
  String get playerCopyAction => 'Copy';

  @override
  String get playerPlayButton => 'Play';

  @override
  String get playerLoadAction => 'Loading';

  @override
  String get playerSampleStatusLocalManual =>
      'Playing local source; online search requires manual trigger';

  @override
  String get playerSampleStatusAutoDisabled =>
      'Online search disabled; you can search manually';

  @override
  String get playerSampleStatusNotStarted =>
      'Online search has not started yet';

  @override
  String playerSampleStatusCompleted(int done, int total) {
    return 'Search done ($done/$total available)';
  }

  @override
  String get playerSampleStatusFailed => 'Search failed';

  @override
  String get playerSampleSummaryLocalManual => 'Playing local source';

  @override
  String get playerSampleSummaryAutoDisabled => 'Online search disabled';

  @override
  String get playerSampleHintLocalManual =>
      'For online sources, tap the button below to search manually';

  @override
  String get playerSampleHintAutoDisabled =>
      'Tap the button below to search online manually';

  @override
  String get playerSampleHintNotStarted =>
      'Tap the button below to start searching';

  @override
  String get playerSamplePlayButtonBase => 'Play - ';

  @override
  String playerSamplePlayButtonWithChannel(String source, String channel) {
    return 'Play - $source($channel)';
  }

  @override
  String playerSamplePlayButtonWithSource(String source) {
    return 'Play - $source';
  }

  @override
  String playerWebViewTaskCount(int active, int max) {
    return 'Concurrent WebView tasks ($active/$max)';
  }

  @override
  String playerWebViewTaskCountWithPool(int active, int max, String pool) {
    return 'Concurrent WebView tasks ($active/$max) · $pool';
  }

  @override
  String get playerWebViewShowDebug => 'Show WebView (debug)';

  @override
  String get playerWebViewWorkerPoolSwitch => 'Unified worker pool (Round 7)';

  @override
  String playerWebViewAvailableSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count available sources',
      one: '1 available source',
      zero: 'No available sources',
    );
    return '$_temp0';
  }

  @override
  String playerWebViewPerSourceStatus(String status) {
    return 'per-source [p|a|c]: $status';
  }

  @override
  String get playerSearchProgressStepPending => 'Pending';

  @override
  String get playerSearchProgressStepSearching => 'Searching...';

  @override
  String get playerSearchProgressStepDetail => 'Fetching detail...';

  @override
  String get playerSearchProgressStepEpisodes => 'Fetching episodes...';

  @override
  String get playerSearchProgressStepExtracting => 'Extracting video link...';

  @override
  String get playerSearchProgressStepSuccess => 'Success';

  @override
  String get playerSearchProgressStepFoundPlayPage => 'Found play page';

  @override
  String get playerSearchProgressStepFailed => 'Failed';

  @override
  String playerSearchSessionProgressLine(
    int completed,
    int enabled,
    int activeCaptcha,
    int pendingCaptcha,
  ) {
    return 'Search progress: $completed/$enabled, captcha $activeCaptcha running/$pendingCaptcha queued';
  }

  @override
  String get playerSearchSessionNotFound =>
      'No matching anime found in any source';

  @override
  String get playerSearchSessionAllFailed =>
      'All sources failed to extract the video link';

  @override
  String playerSearchSessionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search done, $count usable sources found',
      one: 'Search done, 1 usable source found',
      zero: 'Search done, no usable sources found',
    );
    return '$_temp0';
  }

  @override
  String get playerSearchLocalPlayedHint =>
      'Playing local source; you can search online manually';

  @override
  String get playerSearchAutoDisabledHint =>
      'Online search disabled; you can search online manually';

  @override
  String get playerSearchLocalPlayedActionHint =>
      'Playing local source; tap refresh to search online manually';

  @override
  String get playerSearchFetchingSourceList => 'Loading source list...';

  @override
  String get playerSearchNoEnabledSource => 'No play source enabled';

  @override
  String playerSearchProgressSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Searching $count sources...',
      one: 'Searching 1 source...',
    );
    return '$_temp0';
  }

  @override
  String get playerSearchProgressCaptchaPreflight =>
      'Non-captcha sources first; captcha pre-flight runs in parallel...';

  @override
  String playerWebviewExtractInProgress(int completed, int total, int active) {
    return 'Extracting: $completed/$total done, $active running';
  }

  @override
  String get playerWebviewCaptchaBypass => 'Bypassing captcha';

  @override
  String playerWebviewCaptchaBypassTitle(String label) {
    return '$label - bypassing captcha';
  }

  @override
  String get playerWebviewExtracting => 'Extracting...';

  @override
  String playerWebviewSchedulerProgress(int completed, int total) {
    return 'Search progress: $completed/$total';
  }

  @override
  String playerWebviewCaptchaActive(int count) {
    return 'Captcha in progress: $count';
  }

  @override
  String playerWebviewExtractionActive(int active, int max) {
    return 'Extraction concurrency $active/$max';
  }

  @override
  String playerPageTitleWithEpisode(String title, int episode) {
    return '$title - Episode $episode';
  }

  @override
  String playerEpisodeNumber(int episode) {
    return 'Episode $episode';
  }

  @override
  String playerDownloadTaskName(String title, String episode, String source) {
    return '$title - $episode ($source)';
  }

  @override
  String get playerSidePanelPrequel => 'Prequel';

  @override
  String get playerSidePanelSequel => 'Sequel';

  @override
  String get playerSidePanelLoadFailed => 'Unable to get play URL';

  @override
  String get playerSidePanelCopyMagnet => 'Magnet link copied';

  @override
  String get playerSidePanelDownloadHint =>
      'Download started, check progress on the \"My\" page';

  @override
  String get playerRecommendationsEmpty => 'No related recommendations';

  @override
  String get playerNoDescription => 'No description';

  @override
  String get playerCollapse => 'Collapse';

  @override
  String get playerExpand => 'Expand';

  @override
  String get playerCommentsTitle => 'All comments';

  @override
  String get playerCommentsEmpty => 'No comments';

  @override
  String playerCommentsLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String playerCommentsLoadFailedPc(String error) {
    return 'Load failed: $error';
  }

  @override
  String get playerCommentsEmptyPc => 'No comments';

  @override
  String get playerResourceListSearching => 'Searching BT sources...';

  @override
  String playerResourceListFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count BT sources',
      one: 'Found 1 BT source',
      zero: 'No BT sources found',
    );
    return '$_temp0';
  }

  @override
  String get playerResourceListFailed => 'BT search failed';

  @override
  String get playerResourceListNotStarted => 'BT search has not started yet';

  @override
  String get playerResourceListStartSearch =>
      'Tap the button below to start searching';

  @override
  String playerAutoplaySearchDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search done, $count usable sources found',
      one: 'Search done, 1 usable source found',
      zero: 'Search done, no usable sources found',
    );
    return '$_temp0';
  }

  @override
  String get playerSourceControllerAnimeNotFound => 'Anime not found';

  @override
  String playerPlaybackOpenFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String get playerPlaybackStartupTimeout =>
      'This source timed out on startup. Try another source.';

  @override
  String get playerSortDefault => 'Default sort';

  @override
  String get playerSortByTime => 'Sort by time';

  @override
  String get playerSubscriptionDebugSearchDirectProbe =>
      'Search direct-link probe';

  @override
  String get playerSubscriptionDebugProbeInProgress => 'Probing...';

  @override
  String get playerSubscriptionDebugProbeNotDone => 'Not probed';

  @override
  String get playerSubscriptionDebugPlayable => 'Playable';

  @override
  String get playerSubscriptionDebugNotPlayable => 'Not playable';

  @override
  String playerSubscriptionDebugCacheJsonMissing(String path) {
    return 'Cache JSON not found: $path';
  }

  @override
  String playerSubscriptionDebugFileMissing(String path) {
    return 'File not found: $path';
  }

  @override
  String playerSubscriptionDebugStartSearch(
    String anime,
    String abs,
    String relative,
    String filter,
    String jsonSource,
  ) {
    return 'Start debug search: anime=$anime, abs=$abs, rel=$relative, filter=$filter, json=$jsonSource';
  }

  @override
  String playerSubscriptionDebugSearchError(String error) {
    return 'Search error: $error';
  }

  @override
  String get playerSubscriptionDebugSearchFinished => 'Search finished';

  @override
  String get playerSubscriptionDebugCaptchaPageClosed =>
      'Page closed, cannot complete captcha pre-flight';

  @override
  String get playerSubscriptionDebugCaptchaPreflightFailed =>
      'Captcha pre-flight failed';

  @override
  String playerSubscriptionDebugCaptchaPreflight(
    String name,
    int current,
    int total,
  ) {
    return '$name -> running captcha pre-flight ($current/$total)';
  }

  @override
  String playerSubscriptionDebugCaptchaParseFailed(String error) {
    return 'Failed to parse captcha source: $error';
  }

  @override
  String playerSubscriptionDebugExtractStart(String name) {
    return 'Start extract: $name';
  }

  @override
  String get playerSubscriptionDebugStartSearchButton => 'Start debug search';

  @override
  String get playerSubscriptionDebugManualProbe => 'Manual probe';

  @override
  String get playerSubscriptionDebugProbeActive => 'Probing';

  @override
  String playerSubscriptionDebugDirectLink(String url) {
    return 'Direct link: $url';
  }

  @override
  String playerSubscriptionDebugSourceName(String name) {
    return 'Source: $name';
  }

  @override
  String playerSubscriptionDebugHeaders(String headers) {
    return 'Headers: $headers';
  }

  @override
  String playerSubscriptionDebugExtractSuccess(String url) {
    return 'Extract success: $url';
  }

  @override
  String get playerSubscriptionDebugExtractFailedShort => 'Extract failed';

  @override
  String playerSubscriptionDebugExtractFailedDetail(String error) {
    return 'Extract failed: $error';
  }

  @override
  String get playerSubscriptionDebugPostProbe => 'Post-extract probe';

  @override
  String get playerSubscriptionDebugJsonCache => 'cache';

  @override
  String get playerSubscriptionDebugJsonLocal => 'local';

  @override
  String get playerSubscriptionDebugJsonPathHint =>
      'D:\\temp\\online.json, or leave empty';
}
