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
  String get techStackIsar => 'Isar: Local Database';

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
}
