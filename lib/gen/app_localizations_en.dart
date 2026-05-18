// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get historySubtitle => 'Continue watching';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesSubtitle => 'Your collected anime';

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
  String get dataSourceSubtitle => 'Base URLs for bgmlist, bangumi, and mikan';

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
      'This will delete all cached data, including anime info and images. Continue?';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String cacheClearedFailed(Object error) {
    return 'Failed to clear cache: $error';
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
  String get maxWebviewConcurrent => 'Max concurrent WebViews';

  @override
  String get maxWebviewConcurrentHint => 'Recommended: 1-3';

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
  String get bangumiDetailsTags => 'Tags';
}
