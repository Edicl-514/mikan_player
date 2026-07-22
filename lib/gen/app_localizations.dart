import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Mikan Player'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In zh, this message translates to:
  /// **'Mikan Player'**
  String get homeTitle;

  /// No description provided for @statusEnterMagnet.
  ///
  /// In zh, this message translates to:
  /// **'请输入磁力链接以开始'**
  String get statusEnterMagnet;

  /// No description provided for @statusInitializing.
  ///
  /// In zh, this message translates to:
  /// **'正在初始化种子...'**
  String get statusInitializing;

  /// No description provided for @statusPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放：{streamUrl}'**
  String statusPlaying(Object streamUrl);

  /// No description provided for @statusError.
  ///
  /// In zh, this message translates to:
  /// **'错误：{error}'**
  String statusError(Object error);

  /// No description provided for @magnetHint.
  ///
  /// In zh, this message translates to:
  /// **'magnet:?xt=urn:btih:...'**
  String get magnetHint;

  /// No description provided for @playButton.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playButton;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navTimetable.
  ///
  /// In zh, this message translates to:
  /// **'放送表'**
  String get navTimetable;

  /// No description provided for @navRanking.
  ///
  /// In zh, this message translates to:
  /// **'排行榜'**
  String get navRanking;

  /// No description provided for @navIndex.
  ///
  /// In zh, this message translates to:
  /// **'索引'**
  String get navIndex;

  /// No description provided for @navMy.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMy;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索番剧'**
  String get searchHint;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放历史'**
  String get historyTitle;

  /// No description provided for @historyDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除历史记录'**
  String get historyDeleteTooltip;

  /// No description provided for @historySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'继续上次看的内容'**
  String get historySubtitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get favoritesTitle;

  /// No description provided for @favoritesRemoveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get favoritesRemoveTooltip;

  /// No description provided for @favoritesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已收藏的番剧'**
  String get favoritesSubtitle;

  /// No description provided for @downloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get downloadTitle;

  /// No description provided for @downloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理已下载的视频'**
  String get downloadSubtitle;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String version(Object version);

  /// No description provided for @loginPrompt.
  ///
  /// In zh, this message translates to:
  /// **'点击登录'**
  String get loginPrompt;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录同步 Bangumi 数据'**
  String get loginSubtitle;

  /// No description provided for @logoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logoutTitle;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除当前用户信息的缓存吗？'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get logout;

  /// No description provided for @clearCompleted.
  ///
  /// In zh, this message translates to:
  /// **'清除已完成'**
  String get clearCompleted;

  /// No description provided for @noDownloads.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载任务'**
  String get noDownloads;

  /// No description provided for @startDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'在播放页面选择资源开始下载'**
  String get startDownloadHint;

  /// No description provided for @deleteTask.
  ///
  /// In zh, this message translates to:
  /// **'删除任务'**
  String get deleteTask;

  /// No description provided for @clearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get clearConfirmTitle;

  /// No description provided for @clearConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将清除 {count} 个已完成的任务'**
  String clearConfirmMessage(Object count);

  /// No description provided for @deleteFiles.
  ///
  /// In zh, this message translates to:
  /// **'同时删除物理文件'**
  String get deleteFiles;

  /// No description provided for @noCompletedTasks.
  ///
  /// In zh, this message translates to:
  /// **'没有已完成的任务'**
  String get noCompletedTasks;

  /// No description provided for @clearedTasks.
  ///
  /// In zh, this message translates to:
  /// **'已清除 {count} 个任务'**
  String clearedTasks(Object count);

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// No description provided for @seeding.
  ///
  /// In zh, this message translates to:
  /// **'做种中'**
  String get seeding;

  /// No description provided for @paused.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get paused;

  /// No description provided for @statusPending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get statusPending;

  /// No description provided for @statusMetadata.
  ///
  /// In zh, this message translates to:
  /// **'获取元数据'**
  String get statusMetadata;

  /// No description provided for @statusChecking.
  ///
  /// In zh, this message translates to:
  /// **'校验中'**
  String get statusChecking;

  /// No description provided for @statusQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get statusQueued;

  /// No description provided for @statusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusCompleted;

  /// No description provided for @resume.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @clickToPlay.
  ///
  /// In zh, this message translates to:
  /// **'点击播放'**
  String get clickToPlay;

  /// No description provided for @peers.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个连接'**
  String peers(Object count);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @dataSourceSettings.
  ///
  /// In zh, this message translates to:
  /// **'数据源设置'**
  String get dataSourceSettings;

  /// No description provided for @dataSourceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'播放源订阅地址与订阅源开关'**
  String get dataSourceSubtitle;

  /// No description provided for @networkSettings.
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get networkSettings;

  /// No description provided for @networkSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络设置'**
  String get networkSettingsTitle;

  /// No description provided for @networkSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'base URL、请求方式、反代、ECH 与 DoH'**
  String get networkSettingsSubtitle;

  /// No description provided for @networkSectionBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get networkSectionBaseUrl;

  /// No description provided for @networkSectionBangumiMode.
  ///
  /// In zh, this message translates to:
  /// **'Bangumi 请求方式'**
  String get networkSectionBangumiMode;

  /// No description provided for @networkSectionAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get networkSectionAdvanced;

  /// No description provided for @networkBangumiRequestModeLegacy.
  ///
  /// In zh, this message translates to:
  /// **'旧版'**
  String get networkBangumiRequestModeLegacy;

  /// No description provided for @networkBangumiRequestModeHybrid.
  ///
  /// In zh, this message translates to:
  /// **'混合（推荐）'**
  String get networkBangumiRequestModeHybrid;

  /// No description provided for @networkBangumiRequestModeModern.
  ///
  /// In zh, this message translates to:
  /// **'新版'**
  String get networkBangumiRequestModeModern;

  /// No description provided for @networkBangumiOfflineBroadcastData.
  ///
  /// In zh, this message translates to:
  /// **'离线放送数据'**
  String get networkBangumiOfflineBroadcastData;

  /// No description provided for @networkBangumiDataLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get networkBangumiDataLoading;

  /// No description provided for @networkBangumiDataNotCached.
  ///
  /// In zh, this message translates to:
  /// **'未缓存 · 点击下载离线兜底数据'**
  String get networkBangumiDataNotCached;

  /// Status line for cached broadcast data, where {size} is a localized size like '1.2 MB' or '512 KB'.
  ///
  /// In zh, this message translates to:
  /// **'已缓存 {size}'**
  String networkBangumiDataCachedSize(String size);

  /// Status line shown after the cached size, where {time} is a localized date-time string.
  ///
  /// In zh, this message translates to:
  /// **'同步于 {time}'**
  String networkBangumiDataSyncTime(String time);

  /// Version suffix shown after the cached size and sync time.
  ///
  /// In zh, this message translates to:
  /// **'v{version}'**
  String networkBangumiDataVersion(String version);

  /// Status suffix shown when the last sync failed less than an hour ago.
  ///
  /// In zh, this message translates to:
  /// **'{minutes}分钟前同步失败'**
  String networkBangumiDataFailedMins(int minutes);

  /// Status suffix shown when the last sync failed an hour or more ago.
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时前同步失败'**
  String networkBangumiDataFailedHours(int hours);

  /// No description provided for @networkBangumiDataRefreshSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已更新离线放送数据'**
  String get networkBangumiDataRefreshSuccess;

  /// No description provided for @networkBangumiDataRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败，请检查网络'**
  String get networkBangumiDataRefreshFailed;

  /// No description provided for @searchSettings.
  ///
  /// In zh, this message translates to:
  /// **'搜索设置'**
  String get searchSettings;

  /// No description provided for @searchSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置并发布数量及相关参数'**
  String get searchSubtitle;

  /// No description provided for @downloadSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载设置'**
  String get downloadSettingsTitle;

  /// No description provided for @downloadSettingsSaveButton.
  ///
  /// In zh, this message translates to:
  /// **'保存设置'**
  String get downloadSettingsSaveButton;

  /// No description provided for @downloadSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'下载设置已保存'**
  String get downloadSettingsSaved;

  /// No description provided for @downloadSettingsInvalidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的限速数值'**
  String get downloadSettingsInvalidNumber;

  /// No description provided for @downloadEngineTitle.
  ///
  /// In zh, this message translates to:
  /// **'BT 引擎'**
  String get downloadEngineTitle;

  /// No description provided for @downloadEngineSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'新建和自动恢复的 BT 任务会使用所选后端'**
  String get downloadEngineSubtitle;

  /// No description provided for @downloadEngineRqbitDescription.
  ///
  /// In zh, this message translates to:
  /// **'rqbit 基于 Rust 构建，内存占用低，启动快速，擅长边下边播（串流）场景，适合快速预览视频内容。'**
  String get downloadEngineRqbitDescription;

  /// No description provided for @downloadEngineLibtorrentDescription.
  ///
  /// In zh, this message translates to:
  /// **'libtorrent 是成熟的 C++ BT 引擎，下载稳定高效，兼容性好，擅长完整下载和资源做种，适合长期保种场景。'**
  String get downloadEngineLibtorrentDescription;

  /// No description provided for @downloadParallelTasks.
  ///
  /// In zh, this message translates to:
  /// **'并行下载任务数'**
  String get downloadParallelTasks;

  /// No description provided for @downloadParallelHint.
  ///
  /// In zh, this message translates to:
  /// **'1-10，默认3'**
  String get downloadParallelHint;

  /// No description provided for @downloadSpeedLimitsHeader.
  ///
  /// In zh, this message translates to:
  /// **'速度限制 (0 = 不限速)'**
  String get downloadSpeedLimitsHeader;

  /// No description provided for @downloadDownloadLimit.
  ///
  /// In zh, this message translates to:
  /// **'下载限速 (MB/s)'**
  String get downloadDownloadLimit;

  /// No description provided for @downloadDownloadLimitHint.
  ///
  /// In zh, this message translates to:
  /// **'0 表示不限速'**
  String get downloadDownloadLimitHint;

  /// No description provided for @downloadUploadLimit.
  ///
  /// In zh, this message translates to:
  /// **'上传限速 (MB/s)'**
  String get downloadUploadLimit;

  /// No description provided for @downloadUploadLimitHint.
  ///
  /// In zh, this message translates to:
  /// **'0 表示不限速，仅对 BT 生效'**
  String get downloadUploadLimitHint;

  /// No description provided for @allowBackgroundDownload.
  ///
  /// In zh, this message translates to:
  /// **'允许后台下载'**
  String get allowBackgroundDownload;

  /// No description provided for @allowBackgroundDownloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切到后台时保持下载任务运行'**
  String get allowBackgroundDownloadSubtitle;

  /// No description provided for @keepSeedingMode.
  ///
  /// In zh, this message translates to:
  /// **'保种模式'**
  String get keepSeedingMode;

  /// No description provided for @keepSeedingModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载完成转为做种后继续保持后台运行'**
  String get keepSeedingModeSubtitle;

  /// No description provided for @downloadSettingsEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'并行任务数、限速、BT引擎、后台下载'**
  String get downloadSettingsEntrySubtitle;

  /// No description provided for @cacheManagement.
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get cacheManagement;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清除全部缓存'**
  String get clearCache;

  /// No description provided for @confirmClearCache.
  ///
  /// In zh, this message translates to:
  /// **'确认清除缓存'**
  String get confirmClearCache;

  /// No description provided for @clearCacheMessage.
  ///
  /// In zh, this message translates to:
  /// **'这将删除番剧缓存、全部图片缓存、WebView 网络缓存、Cookie 和网站存储。部分播放源之后可能需要重新验证。确定要继续吗？'**
  String get clearCacheMessage;

  /// No description provided for @cacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'缓存已清除'**
  String get cacheCleared;

  /// No description provided for @cacheClearedFailed.
  ///
  /// In zh, this message translates to:
  /// **'清除缓存失败: {error}'**
  String cacheClearedFailed(Object error);

  /// Summary of database cache counts and all clearable cache sizes shown in Settings.
  ///
  /// In zh, this message translates to:
  /// **'条目: {subjects}, 角色: {characters}, 关联: {relations}\n时间表: {timetables}, 排行榜: {rankings}\n应用图片: {imageSize}，HTML 图片: {htmlImageSize}\nWebView 缓存: {webViewCacheSize}，网站数据: {webViewStorageSize}\n可清理合计: {totalSize}'**
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
  );

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用界面语言'**
  String get languageSubtitle;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @auto.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get auto;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @themeModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择亮色或暗色模式'**
  String get themeModeSubtitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @themeSettings.
  ///
  /// In zh, this message translates to:
  /// **'主题设置'**
  String get themeSettings;

  /// No description provided for @themeSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主题模式与颜色设置'**
  String get themeSettingsSubtitle;

  /// No description provided for @customThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'自定义主题色'**
  String get customThemeColor;

  /// No description provided for @themeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get themeColor;

  /// No description provided for @themeColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用主题色'**
  String get themeColorSubtitle;

  /// No description provided for @useMaterial3Color.
  ///
  /// In zh, this message translates to:
  /// **'使用 Material 颜色'**
  String get useMaterial3Color;

  /// No description provided for @useMaterial3ColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启时由系统计算色彩阶梯，关闭时严格使用选取的主色'**
  String get useMaterial3ColorSubtitle;

  /// No description provided for @pureBackground.
  ///
  /// In zh, this message translates to:
  /// **'纯净背景'**
  String get pureBackground;

  /// No description provided for @pureBackgroundSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启时背景应用纯灰阶颜色，不混入主题色'**
  String get pureBackgroundSubtitle;

  /// No description provided for @todayBroadcast.
  ///
  /// In zh, this message translates to:
  /// **'今日放送'**
  String get todayBroadcast;

  /// No description provided for @recentHot.
  ///
  /// In zh, this message translates to:
  /// **'近期热门'**
  String get recentHot;

  /// No description provided for @viewMore.
  ///
  /// In zh, this message translates to:
  /// **'查看更多'**
  String get viewMore;

  /// No description provided for @noTodayUpdate.
  ///
  /// In zh, this message translates to:
  /// **'今天没有更新的番剧哦'**
  String get noTodayUpdate;

  /// No description provided for @viewFullTimetable.
  ///
  /// In zh, this message translates to:
  /// **'查看完整时间表'**
  String get viewFullTimetable;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @noHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放记录'**
  String get noHistory;

  /// No description provided for @noFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get noFavorites;

  /// No description provided for @updateTime.
  ///
  /// In zh, this message translates to:
  /// **'更新时间: {time}'**
  String updateTime(Object time);

  /// No description provided for @monday.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get sunday;

  /// No description provided for @others.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get others;

  /// No description provided for @selectQuarter.
  ///
  /// In zh, this message translates to:
  /// **'选择季度'**
  String get selectQuarter;

  /// No description provided for @noAnimeFoundDay.
  ///
  /// In zh, this message translates to:
  /// **'今天没有找到番剧。'**
  String get noAnimeFoundDay;

  /// No description provided for @errorOccurred.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get errorOccurred;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络设置或稍后再试'**
  String get networkError;

  /// No description provided for @resourceNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源未找到 (404)'**
  String get resourceNotFound;

  /// No description provided for @aboutIntro.
  ///
  /// In zh, this message translates to:
  /// **'自用的看动漫软件，鉴定为对Animeko的拙劣模仿'**
  String get aboutIntro;

  /// No description provided for @aboutSourceCode.
  ///
  /// In zh, this message translates to:
  /// **'项目源代码：'**
  String get aboutSourceCode;

  /// No description provided for @aboutTechStack.
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get aboutTechStack;

  /// No description provided for @aboutDataSources.
  ///
  /// In zh, this message translates to:
  /// **'数据来源'**
  String get aboutDataSources;

  /// No description provided for @aboutDataSourcesList.
  ///
  /// In zh, this message translates to:
  /// **'bgmlist bangumi 蜜柑计划 动漫花园 弹弹play'**
  String get aboutDataSourcesList;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'网络同步是单向的，所有数据均为本地存储，不会影响在线账号'**
  String get aboutDisclaimer;

  /// No description provided for @techStackFlutter.
  ///
  /// In zh, this message translates to:
  /// **'Flutter：跨平台 UI 构建'**
  String get techStackFlutter;

  /// No description provided for @techStackRust.
  ///
  /// In zh, this message translates to:
  /// **'Rust：核心业务逻辑与爬虫'**
  String get techStackRust;

  /// No description provided for @techStackDatabase.
  ///
  /// In zh, this message translates to:
  /// **'Drift：本地 SQLite 数据库'**
  String get techStackDatabase;

  /// No description provided for @techStackMediaKit.
  ///
  /// In zh, this message translates to:
  /// **'MediaKit：视频播放核心'**
  String get techStackMediaKit;

  /// No description provided for @techStackDanmaku.
  ///
  /// In zh, this message translates to:
  /// **'CanvasDanmaku：弹幕渲染'**
  String get techStackDanmaku;

  /// No description provided for @sourceMeta.
  ///
  /// In zh, this message translates to:
  /// **'Bangumi / bgmlist：番剧元数据与放送表'**
  String get sourceMeta;

  /// No description provided for @sourceTorrent.
  ///
  /// In zh, this message translates to:
  /// **'蜜柑计划 / 动漫花园：资源与磁力链接'**
  String get sourceTorrent;

  /// No description provided for @sourceDanmaku.
  ///
  /// In zh, this message translates to:
  /// **'弹弹play：弹幕数据'**
  String get sourceDanmaku;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @filterByStatus.
  ///
  /// In zh, this message translates to:
  /// **'按状态筛选'**
  String get filterByStatus;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get filterActive;

  /// No description provided for @filterChecking.
  ///
  /// In zh, this message translates to:
  /// **'校验中'**
  String get filterChecking;

  /// No description provided for @filterCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get filterCompleted;

  /// No description provided for @filterPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get filterPaused;

  /// No description provided for @filterError.
  ///
  /// In zh, this message translates to:
  /// **'出错'**
  String get filterError;

  /// No description provided for @tasksCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String tasksCount(Object count);

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'应用配置'**
  String get settingsSubtitle;

  /// No description provided for @searchHintText.
  ///
  /// In zh, this message translates to:
  /// **'搜索番剧...'**
  String get searchHintText;

  /// No description provided for @searchModeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换搜索模式'**
  String get searchModeTooltip;

  /// No description provided for @searchKeywordModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'关键词搜索'**
  String get searchKeywordModeLabel;

  /// No description provided for @searchTagModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'Tag 搜索'**
  String get searchTagModeLabel;

  /// No description provided for @searchEnterTag.
  ///
  /// In zh, this message translates to:
  /// **'输入标签进行搜索'**
  String get searchEnterTag;

  /// No description provided for @searchEnterTagsMulti.
  ///
  /// In zh, this message translates to:
  /// **'输入标签进行搜索，多个标签用空格分隔'**
  String get searchEnterTagsMulti;

  /// No description provided for @searchSortTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切换排序方式'**
  String get searchSortTooltip;

  /// No description provided for @searchSortRank.
  ///
  /// In zh, this message translates to:
  /// **'排名'**
  String get searchSortRank;

  /// No description provided for @searchSortMatch.
  ///
  /// In zh, this message translates to:
  /// **'相关度'**
  String get searchSortMatch;

  /// No description provided for @searchSortHeat.
  ///
  /// In zh, this message translates to:
  /// **'收藏数'**
  String get searchSortHeat;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到结果'**
  String get searchNoResults;

  /// No description provided for @searchEnterKeyword.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词进行搜索'**
  String get searchEnterKeyword;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(Object error);

  /// No description provided for @loginDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录 Bangumi'**
  String get loginDialogTitle;

  /// No description provided for @loginDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'请输入 Bangumi 用户名或 ID 获取公开信息'**
  String get loginDialogMessage;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名 / ID'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'注意：是用户名不是昵称'**
  String get loginUsernameHint;

  /// No description provided for @loginError.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查用户名或网络'**
  String get loginError;

  /// No description provided for @cannotLoadEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'无法加载剧集列表'**
  String get cannotLoadEpisodes;

  /// No description provided for @pleaseEnterAnimeName.
  ///
  /// In zh, this message translates to:
  /// **'请先填写动漫名称'**
  String get pleaseEnterAnimeName;

  /// No description provided for @absoluteEpisodeMustBeInteger.
  ///
  /// In zh, this message translates to:
  /// **'绝对集数必须是整数'**
  String get absoluteEpisodeMustBeInteger;

  /// No description provided for @relativeEpisodeMustBeInteger.
  ///
  /// In zh, this message translates to:
  /// **'相对集数必须是整数'**
  String get relativeEpisodeMustBeInteger;

  /// No description provided for @episodeMustBeGreaterThanZero.
  ///
  /// In zh, this message translates to:
  /// **'集数必须大于 0'**
  String get episodeMustBeGreaterThanZero;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @restoreDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefault;

  /// No description provided for @autoSelectFastestSource.
  ///
  /// In zh, this message translates to:
  /// **'自动选择最快源'**
  String get autoSelectFastestSource;

  /// No description provided for @refreshPlaybackSource.
  ///
  /// In zh, this message translates to:
  /// **'刷新播放源'**
  String get refreshPlaybackSource;

  /// No description provided for @playbackSourceSubscriptionUrl.
  ///
  /// In zh, this message translates to:
  /// **'播放源订阅地址'**
  String get playbackSourceSubscriptionUrl;

  /// No description provided for @bgmBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Bgmlist Base URL'**
  String get bgmBaseUrl;

  /// No description provided for @bangumiBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Bangumi Base URL'**
  String get bangumiBaseUrl;

  /// No description provided for @mikanBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Mikan Base URL'**
  String get mikanBaseUrl;

  /// No description provided for @subscriptionSwitchTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅源开关 (全网搜)'**
  String get subscriptionSwitchTitle;

  /// No description provided for @customSourceDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义网络搜视源'**
  String get customSourceDescription;

  /// No description provided for @subscriptionSourceTag.
  ///
  /// In zh, this message translates to:
  /// **'订阅'**
  String get subscriptionSourceTag;

  /// No description provided for @manualSourceTag.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get manualSourceTag;

  /// No description provided for @subscriptionSourceReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'订阅源不可编辑，仅可开关或通过订阅更新'**
  String get subscriptionSourceReadOnly;

  /// No description provided for @settingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'设置已保存'**
  String get settingsSaved;

  /// No description provided for @playbackSourceRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'播放源已刷新'**
  String get playbackSourceRefreshed;

  /// No description provided for @playbackSourceRefreshedSynced.
  ///
  /// In zh, this message translates to:
  /// **'播放源已刷新，并同步了 {count} 个默认开关'**
  String playbackSourceRefreshedSynced(Object count);

  /// No description provided for @fastestSourceSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换至最快源: {url} ({latency}ms)'**
  String fastestSourceSwitched(Object latency, Object url);

  /// No description provided for @refreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败: {error}'**
  String refreshFailed(Object error);

  /// No description provided for @fetchCollectionsFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取收藏失败: {error}'**
  String fetchCollectionsFailed(Object error);

  /// No description provided for @noLocalFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无本地收藏'**
  String get noLocalFavorites;

  /// No description provided for @loginBangumiFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先登录 Bangumi 账号'**
  String get loginBangumiFirst;

  /// No description provided for @goToLogin.
  ///
  /// In zh, this message translates to:
  /// **'去登录'**
  String get goToLogin;

  /// No description provided for @noBangumiFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无 Bangumi 收藏数据'**
  String get noBangumiFavorites;

  /// No description provided for @refreshAllFavorites.
  ///
  /// In zh, this message translates to:
  /// **'刷新所有收藏'**
  String get refreshAllFavorites;

  /// No description provided for @rankingTitle.
  ///
  /// In zh, this message translates to:
  /// **'排行榜'**
  String get rankingTitle;

  /// No description provided for @rankingTrending.
  ///
  /// In zh, this message translates to:
  /// **'近期热门'**
  String get rankingTrending;

  /// No description provided for @rankingRanking.
  ///
  /// In zh, this message translates to:
  /// **'排行榜'**
  String get rankingRanking;

  /// No description provided for @indexDateRangeSelected.
  ///
  /// In zh, this message translates to:
  /// **'区间'**
  String get indexDateRangeSelected;

  /// No description provided for @indexDateRangeUnset.
  ///
  /// In zh, this message translates to:
  /// **'不限时间范围'**
  String get indexDateRangeUnset;

  /// No description provided for @indexTimeModePoint.
  ///
  /// In zh, this message translates to:
  /// **'点选'**
  String get indexTimeModePoint;

  /// No description provided for @indexTimeModeRange.
  ///
  /// In zh, this message translates to:
  /// **'区间'**
  String get indexTimeModeRange;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String loadFailed(Object error);

  /// No description provided for @noRelatedAnime.
  ///
  /// In zh, this message translates to:
  /// **'没有找到「{tag}」相关的动画'**
  String noRelatedAnime(Object tag);

  /// No description provided for @pageRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get pageRetry;

  /// No description provided for @dataSourceConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据源配置'**
  String get dataSourceConfigTitle;

  /// No description provided for @searchConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'searchConfig'**
  String get searchConfigTitle;

  /// No description provided for @captchaConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'captchaConfig'**
  String get captchaConfigTitle;

  /// No description provided for @dataSourceConfigSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get dataSourceConfigSave;

  /// No description provided for @dataSourceConfigAllowedChars.
  ///
  /// In zh, this message translates to:
  /// **'允许字符'**
  String get dataSourceConfigAllowedChars;

  /// No description provided for @dataSourceConfigBasicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get dataSourceConfigBasicInfo;

  /// No description provided for @dataSourceConfigCaptcha.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get dataSourceConfigCaptcha;

  /// No description provided for @dataSourceConfigCaptchaSub.
  ///
  /// In zh, this message translates to:
  /// **'可选。仅数据源存在验证码时需要配置'**
  String get dataSourceConfigCaptchaSub;

  /// No description provided for @dataSourceConfigChannelNameRegex.
  ///
  /// In zh, this message translates to:
  /// **'线路名称正则'**
  String get dataSourceConfigChannelNameRegex;

  /// No description provided for @dataSourceConfigChannelNameRegexHelper.
  ///
  /// In zh, this message translates to:
  /// **'可用 (?<ch>...) 捕获最终名称'**
  String get dataSourceConfigChannelNameRegexHelper;

  /// No description provided for @dataSourceConfigChannelNameSelector.
  ///
  /// In zh, this message translates to:
  /// **'线路名称选择器'**
  String get dataSourceConfigChannelNameSelector;

  /// No description provided for @dataSourceConfigChannelNameSelectorHelper.
  ///
  /// In zh, this message translates to:
  /// **'例如线路、字幕组、播放源 tab'**
  String get dataSourceConfigChannelNameSelectorHelper;

  /// No description provided for @dataSourceConfigCookie.
  ///
  /// In zh, this message translates to:
  /// **'Cookie'**
  String get dataSourceConfigCookie;

  /// No description provided for @dataSourceConfigCookieHelper.
  ///
  /// In zh, this message translates to:
  /// **'播放视频请求携带的 Cookie，可留空'**
  String get dataSourceConfigCookieHelper;

  /// No description provided for @dataSourceConfigDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get dataSourceConfigDescription;

  /// No description provided for @dataSourceConfigDetectSelector.
  ///
  /// In zh, this message translates to:
  /// **'验证码检测选择器'**
  String get dataSourceConfigDetectSelector;

  /// No description provided for @dataSourceConfigDistinguishChannelName.
  ///
  /// In zh, this message translates to:
  /// **'区分线路名称'**
  String get dataSourceConfigDistinguishChannelName;

  /// No description provided for @dataSourceConfigDistinguishChannelNameSub.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，不同线路中的同名剧集会被去重'**
  String get dataSourceConfigDistinguishChannelNameSub;

  /// No description provided for @dataSourceConfigDistinguishSubjectName.
  ///
  /// In zh, this message translates to:
  /// **'区分条目名称'**
  String get dataSourceConfigDistinguishSubjectName;

  /// No description provided for @dataSourceConfigDistinguishSubjectNameSub.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，不同搜索结果中同名剧集会被去重'**
  String get dataSourceConfigDistinguishSubjectNameSub;

  /// AppBar title when editing an existing data source.
  ///
  /// In zh, this message translates to:
  /// **'配置: {name}'**
  String dataSourceConfigEditing(String name);

  /// No description provided for @dataSourceConfigEnableCaptcha.
  ///
  /// In zh, this message translates to:
  /// **'启用验证码处理'**
  String get dataSourceConfigEnableCaptcha;

  /// No description provided for @dataSourceConfigEnableCaptchaSub.
  ///
  /// In zh, this message translates to:
  /// **'需要绕过详情页验证码时开启'**
  String get dataSourceConfigEnableCaptchaSub;

  /// No description provided for @dataSourceConfigEnableNestedUrl.
  ///
  /// In zh, this message translates to:
  /// **'启用嵌套 URL 匹配'**
  String get dataSourceConfigEnableNestedUrl;

  /// No description provided for @dataSourceConfigEnableNestedUrlSub.
  ///
  /// In zh, this message translates to:
  /// **'先从播放器页找到内层播放页，再匹配视频地址'**
  String get dataSourceConfigEnableNestedUrlSub;

  /// No description provided for @dataSourceConfigEpisodeLinkSelector.
  ///
  /// In zh, this message translates to:
  /// **'列表内链接选择器'**
  String get dataSourceConfigEpisodeLinkSelector;

  /// No description provided for @dataSourceConfigEpisodeLinkSelectorHelper.
  ///
  /// In zh, this message translates to:
  /// **'留空时使用剧集元素自身 href'**
  String get dataSourceConfigEpisodeLinkSelectorHelper;

  /// No description provided for @dataSourceConfigEpisodeListSelector.
  ///
  /// In zh, this message translates to:
  /// **'剧集列表选择器'**
  String get dataSourceConfigEpisodeListSelector;

  /// No description provided for @dataSourceConfigEpisodeSelector.
  ///
  /// In zh, this message translates to:
  /// **'剧集选择器'**
  String get dataSourceConfigEpisodeSelector;

  /// No description provided for @dataSourceConfigEpisodesFromListSelector.
  ///
  /// In zh, this message translates to:
  /// **'列表内剧集选择器'**
  String get dataSourceConfigEpisodesFromListSelector;

  /// No description provided for @dataSourceConfigExpectedLength.
  ///
  /// In zh, this message translates to:
  /// **'验证码长度'**
  String get dataSourceConfigExpectedLength;

  /// No description provided for @dataSourceConfigFilterAndPlayer.
  ///
  /// In zh, this message translates to:
  /// **'过滤和播放器选择'**
  String get dataSourceConfigFilterAndPlayer;

  /// No description provided for @dataSourceConfigFilterByEpisodeSort.
  ///
  /// In zh, this message translates to:
  /// **'使用剧集序号过滤'**
  String get dataSourceConfigFilterByEpisodeSort;

  /// No description provided for @dataSourceConfigFilterByEpisodeSortSub.
  ///
  /// In zh, this message translates to:
  /// **'要求资源标题包含剧集序号，通常建议开启'**
  String get dataSourceConfigFilterByEpisodeSortSub;

  /// No description provided for @dataSourceConfigFilterBySubjectName.
  ///
  /// In zh, this message translates to:
  /// **'使用条目名称过滤'**
  String get dataSourceConfigFilterBySubjectName;

  /// No description provided for @dataSourceConfigFilterBySubjectNameSub.
  ///
  /// In zh, this message translates to:
  /// **'要求资源标题包含条目名称'**
  String get dataSourceConfigFilterBySubjectNameSub;

  /// No description provided for @dataSourceConfigFromListEpisodeLinkSelector.
  ///
  /// In zh, this message translates to:
  /// **'剧集链接选择器'**
  String get dataSourceConfigFromListEpisodeLinkSelector;

  /// No description provided for @dataSourceConfigFromListEpisodeLinkSelectorHelper.
  ///
  /// In zh, this message translates to:
  /// **'留空时使用剧集元素自身 href'**
  String get dataSourceConfigFromListEpisodeLinkSelectorHelper;

  /// No description provided for @dataSourceConfigIconUrl.
  ///
  /// In zh, this message translates to:
  /// **'图标链接'**
  String get dataSourceConfigIconUrl;

  /// No description provided for @dataSourceConfigIconUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://...'**
  String get dataSourceConfigIconUrlHint;

  /// No description provided for @dataSourceConfigImageSelector.
  ///
  /// In zh, this message translates to:
  /// **'验证码图片选择器'**
  String get dataSourceConfigImageSelector;

  /// No description provided for @dataSourceConfigInputSelector.
  ///
  /// In zh, this message translates to:
  /// **'输入框选择器'**
  String get dataSourceConfigInputSelector;

  /// No description provided for @dataSourceConfigIntegerRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入整数'**
  String get dataSourceConfigIntegerRequired;

  /// Validation error when a numeric source configuration field is outside the range Rust accepts.
  ///
  /// In zh, this message translates to:
  /// **'请输入范围为 {min} 到 {max} 的整数'**
  String dataSourceConfigIntegerRange(int min, int max);

  /// No description provided for @dataSourceConfigJsonPreviewSub.
  ///
  /// In zh, this message translates to:
  /// **'用于核对保存内容'**
  String get dataSourceConfigJsonPreviewSub;

  /// No description provided for @dataSourceConfigJsonPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成的 JSON'**
  String get dataSourceConfigJsonPreviewTitle;

  /// No description provided for @dataSourceConfigJsonSchemaCaptcha.
  ///
  /// In zh, this message translates to:
  /// **'captchaConfig'**
  String get dataSourceConfigJsonSchemaCaptcha;

  /// No description provided for @dataSourceConfigJsonSchemaSearch.
  ///
  /// In zh, this message translates to:
  /// **'searchConfig'**
  String get dataSourceConfigJsonSchemaSearch;

  /// No description provided for @dataSourceConfigJsonSchemaNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get dataSourceConfigJsonSchemaNotConfigured;

  /// No description provided for @dataSourceConfigLinkJsonPath.
  ///
  /// In zh, this message translates to:
  /// **'链接 JsonPath'**
  String get dataSourceConfigLinkJsonPath;

  /// No description provided for @dataSourceConfigMatchVideoUrl.
  ///
  /// In zh, this message translates to:
  /// **'视频 URL 正则'**
  String get dataSourceConfigMatchVideoUrl;

  /// No description provided for @dataSourceConfigMatchVideoUrlHelper.
  ///
  /// In zh, this message translates to:
  /// **'可用 (?<v>...) 捕获最终播放地址'**
  String get dataSourceConfigMatchVideoUrlHelper;

  /// No description provided for @dataSourceConfigName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get dataSourceConfigName;

  /// No description provided for @dataSourceConfigNameHelper.
  ///
  /// In zh, this message translates to:
  /// **'显示在数据源列表中的名称'**
  String get dataSourceConfigNameHelper;

  /// No description provided for @dataSourceConfigNameJsonPath.
  ///
  /// In zh, this message translates to:
  /// **'名称 JsonPath'**
  String get dataSourceConfigNameJsonPath;

  /// No description provided for @dataSourceConfigNestedUrlRegex.
  ///
  /// In zh, this message translates to:
  /// **'嵌套 URL 正则'**
  String get dataSourceConfigNestedUrlRegex;

  /// No description provided for @dataSourceConfigNew.
  ///
  /// In zh, this message translates to:
  /// **'新建数据源'**
  String get dataSourceConfigNew;

  /// No description provided for @dataSourceConfigNotMarked.
  ///
  /// In zh, this message translates to:
  /// **'不标记'**
  String get dataSourceConfigNotMarked;

  /// No description provided for @dataSourceConfigPreferShorterName.
  ///
  /// In zh, this message translates to:
  /// **'优先匹配较短名称'**
  String get dataSourceConfigPreferShorterName;

  /// No description provided for @dataSourceConfigRefreshSelector.
  ///
  /// In zh, this message translates to:
  /// **'刷新图片选择器'**
  String get dataSourceConfigRefreshSelector;

  /// No description provided for @dataSourceConfigReferer.
  ///
  /// In zh, this message translates to:
  /// **'Referer'**
  String get dataSourceConfigReferer;

  /// No description provided for @dataSourceConfigRefererHelper.
  ///
  /// In zh, this message translates to:
  /// **'播放视频请求的 Referer'**
  String get dataSourceConfigRefererHelper;

  /// No description provided for @dataSourceConfigRequestInterval.
  ///
  /// In zh, this message translates to:
  /// **'请求间隔 (毫秒)'**
  String get dataSourceConfigRequestInterval;

  /// No description provided for @dataSourceConfigRequestIntervalHelper.
  ///
  /// In zh, this message translates to:
  /// **'每次请求后的等待时间'**
  String get dataSourceConfigRequestIntervalHelper;

  /// No description provided for @dataSourceConfigRequired.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get dataSourceConfigRequired;

  /// No description provided for @dataSourceConfigResolutionLabel.
  ///
  /// In zh, this message translates to:
  /// **'标记分辨率'**
  String get dataSourceConfigResolutionLabel;

  /// No description provided for @dataSourceConfigResolutionHelper.
  ///
  /// In zh, this message translates to:
  /// **'用于播放器内偏好和过滤'**
  String get dataSourceConfigResolutionHelper;

  /// No description provided for @dataSourceConfigSaved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get dataSourceConfigSaved;

  /// SnackBar message shown when saving the data source fails.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String dataSourceConfigSaveFailed(String error);

  /// No description provided for @dataSourceConfigSearchUrl.
  ///
  /// In zh, this message translates to:
  /// **'搜索链接'**
  String get dataSourceConfigSearchUrl;

  /// Helper text under the search URL field explaining the {keyword} placeholder.
  ///
  /// In zh, this message translates to:
  /// **'{keyword} 会替换为条目名称'**
  String dataSourceConfigSearchUrlHelper(String keyword);

  /// Example URL shown as the hint of the search URL field.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/search?wd={keyword}'**
  String dataSourceConfigSearchUrlHint(String keyword);

  /// No description provided for @dataSourceConfigSortRegex.
  ///
  /// In zh, this message translates to:
  /// **'剧集序号正则'**
  String get dataSourceConfigSortRegex;

  /// No description provided for @dataSourceConfigSortRegexHelper.
  ///
  /// In zh, this message translates to:
  /// **'建议使用 (?<ep>...) 捕获集数'**
  String get dataSourceConfigSortRegexHelper;

  /// No description provided for @dataSourceConfigStep1ParseResults.
  ///
  /// In zh, this message translates to:
  /// **'步骤 1：解析搜索结果'**
  String get dataSourceConfigStep1ParseResults;

  /// No description provided for @dataSourceConfigStep1ParseResultsSub.
  ///
  /// In zh, this message translates to:
  /// **'从搜索结果中提取条目名称和详情页链接'**
  String get dataSourceConfigStep1ParseResultsSub;

  /// No description provided for @dataSourceConfigStep1Search.
  ///
  /// In zh, this message translates to:
  /// **'步骤 1：搜索条目'**
  String get dataSourceConfigStep1Search;

  /// No description provided for @dataSourceConfigStep1SearchSub.
  ///
  /// In zh, this message translates to:
  /// **'配置搜索链接和搜索词处理规则'**
  String get dataSourceConfigStep1SearchSub;

  /// No description provided for @dataSourceConfigStep2Channels.
  ///
  /// In zh, this message translates to:
  /// **'步骤 2：解析线路和剧集'**
  String get dataSourceConfigStep2Channels;

  /// No description provided for @dataSourceConfigStep2ChannelsSub.
  ///
  /// In zh, this message translates to:
  /// **'从详情页提取线路、剧集和播放页链接'**
  String get dataSourceConfigStep2ChannelsSub;

  /// No description provided for @dataSourceConfigStep3MatchVideo.
  ///
  /// In zh, this message translates to:
  /// **'步骤 3：匹配视频'**
  String get dataSourceConfigStep3MatchVideo;

  /// No description provided for @dataSourceConfigStep3MatchVideoSub.
  ///
  /// In zh, this message translates to:
  /// **'从播放页提取最终视频地址和请求头'**
  String get dataSourceConfigStep3MatchVideoSub;

  /// No description provided for @dataSourceConfigSubjectFormatA.
  ///
  /// In zh, this message translates to:
  /// **'单标签'**
  String get dataSourceConfigSubjectFormatA;

  /// No description provided for @dataSourceConfigSubjectFormatIndexed.
  ///
  /// In zh, this message translates to:
  /// **'多标签'**
  String get dataSourceConfigSubjectFormatIndexed;

  /// No description provided for @dataSourceConfigSubjectFormatJsonPath.
  ///
  /// In zh, this message translates to:
  /// **'JsonPath'**
  String get dataSourceConfigSubjectFormatJsonPath;

  /// No description provided for @dataSourceConfigChannelFormatIndexGrouped.
  ///
  /// In zh, this message translates to:
  /// **'线路分组'**
  String get dataSourceConfigChannelFormatIndexGrouped;

  /// No description provided for @dataSourceConfigChannelFormatNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'不区分线路'**
  String get dataSourceConfigChannelFormatNoChannel;

  /// No description provided for @dataSourceConfigSubjectLinkSelector.
  ///
  /// In zh, this message translates to:
  /// **'条目链接选择器'**
  String get dataSourceConfigSubjectLinkSelector;

  /// No description provided for @dataSourceConfigSubjectLinkSelectorHelper.
  ///
  /// In zh, this message translates to:
  /// **'从搜索结果页选择条目详情链接'**
  String get dataSourceConfigSubjectLinkSelectorHelper;

  /// No description provided for @dataSourceConfigSubjectNameSelector.
  ///
  /// In zh, this message translates to:
  /// **'条目名称选择器'**
  String get dataSourceConfigSubjectNameSelector;

  /// No description provided for @dataSourceConfigSubjectRemoveSpecial.
  ///
  /// In zh, this message translates to:
  /// **'去除特殊字符'**
  String get dataSourceConfigSubjectRemoveSpecial;

  /// No description provided for @dataSourceConfigSubjectRemoveSpecialSub.
  ///
  /// In zh, this message translates to:
  /// **'清理符号和部分常见干扰词，提升搜索兼容性'**
  String get dataSourceConfigSubjectRemoveSpecialSub;

  /// No description provided for @dataSourceConfigSubjectUseFirstWord.
  ///
  /// In zh, this message translates to:
  /// **'仅使用第一个词'**
  String get dataSourceConfigSubjectUseFirstWord;

  /// No description provided for @dataSourceConfigSubjectUseFirstWordSub.
  ///
  /// In zh, this message translates to:
  /// **'以空格分割条目名后只用第一个词搜索'**
  String get dataSourceConfigSubjectUseFirstWordSub;

  /// No description provided for @dataSourceConfigSubjectUseNamesCount.
  ///
  /// In zh, this message translates to:
  /// **'尝试条目名称数量'**
  String get dataSourceConfigSubjectUseNamesCount;

  /// No description provided for @dataSourceConfigSubjectUseNamesCountHelper.
  ///
  /// In zh, this message translates to:
  /// **'留空使用默认值。1 表示仅使用主名称'**
  String get dataSourceConfigSubjectUseNamesCountHelper;

  /// No description provided for @dataSourceConfigSubmitSelector.
  ///
  /// In zh, this message translates to:
  /// **'提交按钮选择器'**
  String get dataSourceConfigSubmitSelector;

  /// No description provided for @dataSourceConfigSubtitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标记字幕语言'**
  String get dataSourceConfigSubtitleLabel;

  /// No description provided for @dataSourceConfigSubtitleHelper.
  ///
  /// In zh, this message translates to:
  /// **'用于播放器内偏好和过滤'**
  String get dataSourceConfigSubtitleHelper;

  /// No description provided for @dataSourceConfigSuccessSelector.
  ///
  /// In zh, this message translates to:
  /// **'成功页面选择器'**
  String get dataSourceConfigSuccessSelector;

  /// No description provided for @dataSourceConfigTier.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get dataSourceConfigTier;

  /// No description provided for @dataSourceConfigTierHelper.
  ///
  /// In zh, this message translates to:
  /// **'数字越小优先级越高'**
  String get dataSourceConfigTierHelper;

  /// No description provided for @dataSourceConfigType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get dataSourceConfigType;

  /// No description provided for @dataSourceConfigUseRawBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get dataSourceConfigUseRawBaseUrl;

  /// No description provided for @dataSourceConfigUseRawBaseUrlHelper.
  ///
  /// In zh, this message translates to:
  /// **'可选。用于拼接条目详情页链接，留空时通常从搜索链接推断'**
  String get dataSourceConfigUseRawBaseUrlHelper;

  /// No description provided for @dataSourceConfigUserAgent.
  ///
  /// In zh, this message translates to:
  /// **'User-Agent'**
  String get dataSourceConfigUserAgent;

  /// No description provided for @dataSourceConfigUserAgentHelper.
  ///
  /// In zh, this message translates to:
  /// **'播放视频请求的 User-Agent'**
  String get dataSourceConfigUserAgentHelper;

  /// No description provided for @dataSourceConfigUseWebViewForCaptchaDetail.
  ///
  /// In zh, this message translates to:
  /// **'详情页使用 WebView'**
  String get dataSourceConfigUseWebViewForCaptchaDetail;

  /// No description provided for @dataSourceConfigCaptchaInitialDelay.
  ///
  /// In zh, this message translates to:
  /// **'初始等待 (毫秒)'**
  String get dataSourceConfigCaptchaInitialDelay;

  /// No description provided for @searchSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索设置'**
  String get searchSettingsTitle;

  /// No description provided for @maxParallelSearchSources.
  ///
  /// In zh, this message translates to:
  /// **'最大并行搜索源数量'**
  String get maxParallelSearchSources;

  /// No description provided for @maxParallelSearchSourcesHint.
  ///
  /// In zh, this message translates to:
  /// **'默认为3，0为不限制（Generic Scraper）'**
  String get maxParallelSearchSourcesHint;

  /// No description provided for @webviewScraperSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'WebView Scraper设置 (仅针对Dynamic Webview源)'**
  String get webviewScraperSettingsTitle;

  /// No description provided for @maxWebviewConcurrent.
  ///
  /// In zh, this message translates to:
  /// **'最大WebView并发数量'**
  String get maxWebviewConcurrent;

  /// No description provided for @maxWebviewConcurrentHint.
  ///
  /// In zh, this message translates to:
  /// **'建议值: 1-3'**
  String get maxWebviewConcurrentHint;

  /// No description provided for @webviewLaunchInterval.
  ///
  /// In zh, this message translates to:
  /// **'WebView启动间隔 (毫秒)'**
  String get webviewLaunchInterval;

  /// No description provided for @webviewLaunchIntervalHint.
  ///
  /// In zh, this message translates to:
  /// **'建议值: 200-1000'**
  String get webviewLaunchIntervalHint;

  /// No description provided for @autoSearchOnlineTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动搜索在线源'**
  String get autoSearchOnlineTitle;

  /// No description provided for @autoSearchOnlineSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，播放页将只自动搜索BT源'**
  String get autoSearchOnlineSubtitle;

  /// No description provided for @cancelLowPrioritySourcesTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放后取消低优先级源提取'**
  String get cancelLowPrioritySourcesTitle;

  /// No description provided for @cancelLowPrioritySourcesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开始播放后取消Tier≥1的源的提取，保留Tier 0源以备切换'**
  String get cancelLowPrioritySourcesSubtitle;

  /// No description provided for @localJsonPathLabel.
  ///
  /// In zh, this message translates to:
  /// **'本地 JSON 路径（留空使用缓存）'**
  String get localJsonPathLabel;

  /// No description provided for @animeNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'动漫名称'**
  String get animeNameLabel;

  /// No description provided for @animeNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：机动战士高达GQuuuuuuX'**
  String get animeNameHint;

  /// No description provided for @absoluteEpisodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'绝对集数'**
  String get absoluteEpisodeLabel;

  /// No description provided for @relativeEpisodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'相对集数'**
  String get relativeEpisodeLabel;

  /// No description provided for @optionalEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'可留空'**
  String get optionalEmptyHint;

  /// No description provided for @sourceFilterLabel.
  ///
  /// In zh, this message translates to:
  /// **'源名过滤（可选）'**
  String get sourceFilterLabel;

  /// No description provided for @sourceFilterHint.
  ///
  /// In zh, this message translates to:
  /// **'大小写不敏感，包含匹配'**
  String get sourceFilterHint;

  /// No description provided for @showWebViewDebugSwitch.
  ///
  /// In zh, this message translates to:
  /// **'显示 WebView 调试开关'**
  String get showWebViewDebugSwitch;

  /// No description provided for @showWebViewDebugSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅影响调试提取画面显示，不影响搜索逻辑'**
  String get showWebViewDebugSubtitle;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @sourceCount.
  ///
  /// In zh, this message translates to:
  /// **'源数量'**
  String get sourceCount;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @failure.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failure;

  /// No description provided for @inProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get inProgress;

  /// No description provided for @noDebugSearchResult.
  ///
  /// In zh, this message translates to:
  /// **'暂无结果。输入参数后点击“开始调试搜索”。'**
  String get noDebugSearchResult;

  /// No description provided for @debugStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态: {status}'**
  String debugStatus(Object status);

  /// No description provided for @channelLine.
  ///
  /// In zh, this message translates to:
  /// **'线路: {line}'**
  String channelLine(Object line);

  /// No description provided for @playPage.
  ///
  /// In zh, this message translates to:
  /// **'播放页: {url}'**
  String playPage(Object url);

  /// No description provided for @extractUrl.
  ///
  /// In zh, this message translates to:
  /// **'提取URL'**
  String get extractUrl;

  /// No description provided for @extractDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'可播放 URL 提取调试'**
  String get extractDebugTitle;

  /// No description provided for @extractFailed.
  ///
  /// In zh, this message translates to:
  /// **'提取失败: {error}'**
  String extractFailed(Object error);

  /// No description provided for @extractSuccess.
  ///
  /// In zh, this message translates to:
  /// **'提取成功: {url}'**
  String extractSuccess(Object url);

  /// No description provided for @logsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get logsEmpty;

  /// No description provided for @subscriptionDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅源调试'**
  String get subscriptionDebugTitle;

  /// No description provided for @subscriptionDebugEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅调试（本地JSON）'**
  String get subscriptionDebugEntryTitle;

  /// No description provided for @subscriptionDebugEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'手动测试订阅源搜索和可播放URL提取'**
  String get subscriptionDebugEntrySubtitle;

  /// No description provided for @subscriptionDebugJsonTitle.
  ///
  /// In zh, this message translates to:
  /// **'订阅源 JSON 调试'**
  String get subscriptionDebugJsonTitle;

  /// No description provided for @subscriptionDebugDisabled.
  ///
  /// In zh, this message translates to:
  /// **'当前构建未启用订阅调试。\n请使用 --dart-define=ENABLE_SUBSCRIPTION_DEBUG=true 启动。'**
  String get subscriptionDebugDisabled;

  /// No description provided for @subscriptionDebugInfo.
  ///
  /// In zh, this message translates to:
  /// **'此页面仅用于调试：优先读取本地 JSON，留空时读取程序缓存中的 JSON，不会修改缓存文件、不会覆盖订阅设置、不会影响正式播放流程。'**
  String get subscriptionDebugInfo;

  /// No description provided for @searchError.
  ///
  /// In zh, this message translates to:
  /// **'搜索错误: {error}'**
  String searchError(Object error);

  /// No description provided for @searchLogs.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志'**
  String get searchLogs;

  /// No description provided for @extractLogs.
  ///
  /// In zh, this message translates to:
  /// **'提取日志'**
  String get extractLogs;

  /// No description provided for @stepPending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get stepPending;

  /// No description provided for @stepSearching.
  ///
  /// In zh, this message translates to:
  /// **'搜索中'**
  String get stepSearching;

  /// No description provided for @stepFetchingDetail.
  ///
  /// In zh, this message translates to:
  /// **'获取详情页'**
  String get stepFetchingDetail;

  /// No description provided for @stepFetchingEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'获取剧集'**
  String get stepFetchingEpisodes;

  /// No description provided for @stepExtractingVideo.
  ///
  /// In zh, this message translates to:
  /// **'提取播放页'**
  String get stepExtractingVideo;

  /// No description provided for @stepSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get stepSuccess;

  /// No description provided for @stepFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get stepFailed;

  /// No description provided for @characterDetailsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'角色详情加载失败'**
  String get characterDetailsLoadFailed;

  /// No description provided for @personDetailsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'人物详情加载失败'**
  String get personDetailsLoadFailed;

  /// No description provided for @retryButton.
  ///
  /// In zh, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @favoritesTabLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地收藏'**
  String get favoritesTabLocal;

  /// No description provided for @favoritesTabBangumi.
  ///
  /// In zh, this message translates to:
  /// **'Bangumi 同步'**
  String get favoritesTabBangumi;

  /// No description provided for @notFoundAnimeTag.
  ///
  /// In zh, this message translates to:
  /// **'没有找到「{tag}」相关的动画'**
  String notFoundAnimeTag(Object tag);

  /// No description provided for @addToLocalFavorites.
  ///
  /// In zh, this message translates to:
  /// **'已添加到本地收藏'**
  String get addToLocalFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get removeFromFavorites;

  /// No description provided for @favoriteStatusUpdated.
  ///
  /// In zh, this message translates to:
  /// **'收藏状态已更新'**
  String get favoriteStatusUpdated;

  /// No description provided for @favoriteUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新收藏失败: {error}'**
  String favoriteUpdateFailed(Object error);

  /// No description provided for @playSourceTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放源'**
  String get playSourceTitle;

  /// No description provided for @episodeListTitle.
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get episodeListTitle;

  /// No description provided for @relatedRecommendationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'相关推荐'**
  String get relatedRecommendationsTitle;

  /// No description provided for @commentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'评论区'**
  String get commentsTitle;

  /// No description provided for @allComments.
  ///
  /// In zh, this message translates to:
  /// **'全部评论'**
  String get allComments;

  /// No description provided for @noComments.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get noComments;

  /// No description provided for @noRelatedRecommendationsText.
  ///
  /// In zh, this message translates to:
  /// **'暂无相关推荐'**
  String get noRelatedRecommendationsText;

  /// No description provided for @commentsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String commentsLoadFailed(Object error);

  /// No description provided for @initializingPlayback.
  ///
  /// In zh, this message translates to:
  /// **'正在初始化播放...'**
  String get initializingPlayback;

  /// No description provided for @playbackFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get playbackFailed;

  /// No description provided for @chooseSourceToWatch.
  ///
  /// In zh, this message translates to:
  /// **'选择播放源开始观看'**
  String get chooseSourceToWatch;

  /// No description provided for @chooseSourceBelow.
  ///
  /// In zh, this message translates to:
  /// **'在下方「播放源」中选择资源'**
  String get chooseSourceBelow;

  /// No description provided for @defaultSort.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get defaultSort;

  /// No description provided for @sortByTime.
  ///
  /// In zh, this message translates to:
  /// **'按时间排序'**
  String get sortByTime;

  /// No description provided for @searchOnlineSource.
  ///
  /// In zh, this message translates to:
  /// **'搜索在线源'**
  String get searchOnlineSource;

  /// No description provided for @searchBtSource.
  ///
  /// In zh, this message translates to:
  /// **'搜索BT源'**
  String get searchBtSource;

  /// No description provided for @btSearching.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索BT源...'**
  String get btSearching;

  /// No description provided for @btFound.
  ///
  /// In zh, this message translates to:
  /// **'已找到 {count} 个BT源'**
  String btFound(Object count);

  /// No description provided for @btSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'BT搜索失败'**
  String get btSearchFailed;

  /// No description provided for @btNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'尚未开始搜索BT源'**
  String get btNotStarted;

  /// No description provided for @btLoaded.
  ///
  /// In zh, this message translates to:
  /// **'已使用本地资源播放'**
  String get btLoaded;

  /// No description provided for @btManualSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'如需在线源，请点击下方按钮手动搜索'**
  String get btManualSearchHint;

  /// No description provided for @btSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮开始搜索'**
  String get btSearchHint;

  /// No description provided for @waitingForPlayPage.
  ///
  /// In zh, this message translates to:
  /// **'等待匹配播放页...'**
  String get waitingForPlayPage;

  /// No description provided for @loadingText.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get loadingText;

  /// No description provided for @playText.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playText;

  /// No description provided for @copyMagnetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'磁力链接已复制'**
  String get copyMagnetSuccess;

  /// No description provided for @downloadStartedHint.
  ///
  /// In zh, this message translates to:
  /// **'开始下载，可在「我的」页面查看进度'**
  String get downloadStartedHint;

  /// No description provided for @noDownloadableOnlineSource.
  ///
  /// In zh, this message translates to:
  /// **'没有可下载的在线源'**
  String get noDownloadableOnlineSource;

  /// No description provided for @cannotGetPlaybackUrl.
  ///
  /// In zh, this message translates to:
  /// **'无法获取播放地址'**
  String get cannotGetPlaybackUrl;

  /// No description provided for @downloadTaskAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加到下载任务'**
  String get downloadTaskAdded;

  /// No description provided for @pauseFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂停失败'**
  String get pauseFailed;

  /// No description provided for @resumeFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get resumeFailed;

  /// No description provided for @loadedDanmaku.
  ///
  /// In zh, this message translates to:
  /// **'已加载弹幕'**
  String get loadedDanmaku;

  /// No description provided for @currentMatch.
  ///
  /// In zh, this message translates to:
  /// **'当前匹配'**
  String get currentMatch;

  /// No description provided for @searchResult.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchResult;

  /// No description provided for @episodeList.
  ///
  /// In zh, this message translates to:
  /// **'剧集列表'**
  String get episodeList;

  /// No description provided for @danmakuCount.
  ///
  /// In zh, this message translates to:
  /// **'弹幕数量: {count} 条'**
  String danmakuCount(Object count);

  /// No description provided for @danmakuSettingsDisplayTab.
  ///
  /// In zh, this message translates to:
  /// **'显示设置'**
  String get danmakuSettingsDisplayTab;

  /// No description provided for @danmakuSettingsSourceTab.
  ///
  /// In zh, this message translates to:
  /// **'弹幕源'**
  String get danmakuSettingsSourceTab;

  /// No description provided for @danmakuSettingsVisibilitySection.
  ///
  /// In zh, this message translates to:
  /// **'显示类型'**
  String get danmakuSettingsVisibilitySection;

  /// No description provided for @danmakuSettingsStyleSection.
  ///
  /// In zh, this message translates to:
  /// **'样式设置'**
  String get danmakuSettingsStyleSection;

  /// No description provided for @danmakuSettingsEnable.
  ///
  /// In zh, this message translates to:
  /// **'显示弹幕'**
  String get danmakuSettingsEnable;

  /// No description provided for @danmakuSettingsScrolling.
  ///
  /// In zh, this message translates to:
  /// **'滚动弹幕'**
  String get danmakuSettingsScrolling;

  /// No description provided for @danmakuSettingsTop.
  ///
  /// In zh, this message translates to:
  /// **'顶部弹幕'**
  String get danmakuSettingsTop;

  /// No description provided for @danmakuSettingsBottom.
  ///
  /// In zh, this message translates to:
  /// **'底部弹幕'**
  String get danmakuSettingsBottom;

  /// No description provided for @danmakuSettingsOpacity.
  ///
  /// In zh, this message translates to:
  /// **'不透明度'**
  String get danmakuSettingsOpacity;

  /// No description provided for @danmakuSettingsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'弹幕速度'**
  String get danmakuSettingsSpeed;

  /// No description provided for @danmakuSettingsSpeedValue.
  ///
  /// In zh, this message translates to:
  /// **'{seconds}秒'**
  String danmakuSettingsSpeedValue(Object seconds);

  /// No description provided for @danmakuSettingsDisplayArea.
  ///
  /// In zh, this message translates to:
  /// **'显示区域'**
  String get danmakuSettingsDisplayArea;

  /// No description provided for @danmakuSettingsFontWeight.
  ///
  /// In zh, this message translates to:
  /// **'字体字重'**
  String get danmakuSettingsFontWeight;

  /// No description provided for @danmakuSettingsFontWeightUltraLight.
  ///
  /// In zh, this message translates to:
  /// **'极细'**
  String get danmakuSettingsFontWeightUltraLight;

  /// No description provided for @danmakuSettingsFontWeightExtraLight.
  ///
  /// In zh, this message translates to:
  /// **'特细'**
  String get danmakuSettingsFontWeightExtraLight;

  /// No description provided for @danmakuSettingsFontWeightLight.
  ///
  /// In zh, this message translates to:
  /// **'细'**
  String get danmakuSettingsFontWeightLight;

  /// No description provided for @danmakuSettingsFontWeightSemiLight.
  ///
  /// In zh, this message translates to:
  /// **'较细'**
  String get danmakuSettingsFontWeightSemiLight;

  /// No description provided for @danmakuSettingsFontWeightRegular.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get danmakuSettingsFontWeightRegular;

  /// No description provided for @danmakuSettingsFontWeightSemiBold.
  ///
  /// In zh, this message translates to:
  /// **'较粗'**
  String get danmakuSettingsFontWeightSemiBold;

  /// No description provided for @danmakuSettingsFontWeightBold.
  ///
  /// In zh, this message translates to:
  /// **'粗'**
  String get danmakuSettingsFontWeightBold;

  /// No description provided for @danmakuSettingsFontWeightExtraBold.
  ///
  /// In zh, this message translates to:
  /// **'特粗'**
  String get danmakuSettingsFontWeightExtraBold;

  /// No description provided for @danmakuSettingsFontWeightBlack.
  ///
  /// In zh, this message translates to:
  /// **'极粗'**
  String get danmakuSettingsFontWeightBlack;

  /// No description provided for @subtitlePreviewText.
  ///
  /// In zh, this message translates to:
  /// **'字幕预览效果'**
  String get subtitlePreviewText;

  /// No description provided for @noAvailablePlaybackSource.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用播放源'**
  String get noAvailablePlaybackSource;

  /// No description provided for @showSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'显示字幕'**
  String get showSubtitles;

  /// No description provided for @subtitleTracks.
  ///
  /// In zh, this message translates to:
  /// **'字幕轨道'**
  String get subtitleTracks;

  /// No description provided for @noEmbeddedSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'当前视频没有内嵌字幕'**
  String get noEmbeddedSubtitles;

  /// No description provided for @disableSubtitles.
  ///
  /// In zh, this message translates to:
  /// **'关闭字幕'**
  String get disableSubtitles;

  /// No description provided for @subtitleStyle.
  ///
  /// In zh, this message translates to:
  /// **'字幕样式'**
  String get subtitleStyle;

  /// No description provided for @fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// No description provided for @backgroundOpacity.
  ///
  /// In zh, this message translates to:
  /// **'背景透明度'**
  String get backgroundOpacity;

  /// No description provided for @bottomPadding.
  ///
  /// In zh, this message translates to:
  /// **'底部边距'**
  String get bottomPadding;

  /// No description provided for @outlineWidth.
  ///
  /// In zh, this message translates to:
  /// **'描边宽度'**
  String get outlineWidth;

  /// No description provided for @fontColor.
  ///
  /// In zh, this message translates to:
  /// **'字体颜色'**
  String get fontColor;

  /// No description provided for @subtitlePreview.
  ///
  /// In zh, this message translates to:
  /// **'字幕预览效果'**
  String get subtitlePreview;

  /// No description provided for @noAvailableSource.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用播放源'**
  String get noAvailableSource;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @playerMoreOptions.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get playerMoreOptions;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @lock.
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get lock;

  /// No description provided for @danmaku.
  ///
  /// In zh, this message translates to:
  /// **'弹幕'**
  String get danmaku;

  /// No description provided for @selectEpisode.
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get selectEpisode;

  /// No description provided for @skipBack85.
  ///
  /// In zh, this message translates to:
  /// **'空降-85s'**
  String get skipBack85;

  /// No description provided for @skipForward85.
  ///
  /// In zh, this message translates to:
  /// **'空降+85s'**
  String get skipForward85;

  /// No description provided for @autoPlayNext.
  ///
  /// In zh, this message translates to:
  /// **'自动连播'**
  String get autoPlayNext;

  /// No description provided for @playbackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get playbackSpeed;

  /// No description provided for @normalSpeed.
  ///
  /// In zh, this message translates to:
  /// **'正常速度'**
  String get normalSpeed;

  /// No description provided for @playbackSpeedTip.
  ///
  /// In zh, this message translates to:
  /// **'提示：播放速度会同时影响视频与弹幕的时间同步。'**
  String get playbackSpeedTip;

  /// No description provided for @subtitleTrackCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 集'**
  String subtitleTrackCount(Object count);

  /// No description provided for @playWithSource.
  ///
  /// In zh, this message translates to:
  /// **'播放 - {source}'**
  String playWithSource(Object source);

  /// No description provided for @selectedSourceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get selectedSourceUnknown;

  /// No description provided for @downloadDirTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载路径'**
  String get downloadDirTitle;

  /// No description provided for @downloadDirBrowse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get downloadDirBrowse;

  /// No description provided for @downloadDirPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择下载目录'**
  String get downloadDirPickerTitle;

  /// No description provided for @bangumiDetailsEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'剧集'**
  String get bangumiDetailsEpisodes;

  /// No description provided for @bangumiDetailsStory.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get bangumiDetailsStory;

  /// No description provided for @bangumiDetailsRelatedItems.
  ///
  /// In zh, this message translates to:
  /// **'相关作品'**
  String get bangumiDetailsRelatedItems;

  /// No description provided for @bangumiDetailsRelatedSites.
  ///
  /// In zh, this message translates to:
  /// **'关联站点'**
  String get bangumiDetailsRelatedSites;

  /// No description provided for @bangumiDetailsTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get bangumiDetailsTags;

  /// No description provided for @bangumiReverseProxyTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 Bangumi 反代镜像'**
  String get bangumiReverseProxyTitle;

  /// No description provided for @bangumiReverseProxyDescription.
  ///
  /// In zh, this message translates to:
  /// **'开启后将所有Bangumi请求路由到反代地址。'**
  String get bangumiReverseProxyDescription;

  /// No description provided for @bangumiEchTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 ECH 加密 SNI'**
  String get bangumiEchTitle;

  /// No description provided for @bangumiEchDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过 Encrypted Client Hello 加密真实域名，绕过 SNI 黑名单。中国大陆推荐。'**
  String get bangumiEchDescription;

  /// No description provided for @bangumiEchRefreshTitle.
  ///
  /// In zh, this message translates to:
  /// **'刷新 ECH 公钥'**
  String get bangumiEchRefreshTitle;

  /// No description provided for @bangumiEchRefreshDescription.
  ///
  /// In zh, this message translates to:
  /// **'按优先级从 DoH 列表重新拉取 ECHConfig（缓存约 1 小时）'**
  String get bangumiEchRefreshDescription;

  /// No description provided for @bangumiEchRefreshSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已更新（{bytes} 字节）'**
  String bangumiEchRefreshSuccess(Object bytes);

  /// No description provided for @bangumiEchRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败，将回退到普通模式'**
  String get bangumiEchRefreshFailed;

  /// No description provided for @bangumiEchDohListTitle.
  ///
  /// In zh, this message translates to:
  /// **'DoH 端点列表'**
  String get bangumiEchDohListTitle;

  /// No description provided for @bangumiEchDohListDescription.
  ///
  /// In zh, this message translates to:
  /// **'用于查询 Cloudflare 的 HTTPS RR 以获取 ECH 公钥。按顺序尝试，第一个可用的生效。点击「恢复默认」重置为内置列表。'**
  String get bangumiEchDohListDescription;

  /// No description provided for @bangumiEchDohListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前为空，使用内置默认 DoH'**
  String get bangumiEchDohListEmpty;

  /// No description provided for @bangumiEchDohAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加 DoH 端点'**
  String get bangumiEchDohAddTitle;

  /// No description provided for @bangumiEchDohAddHint.
  ///
  /// In zh, this message translates to:
  /// **'https://your-doh.example/dns-query'**
  String get bangumiEchDohAddHint;

  /// No description provided for @bangumiEchDohAddInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入以 https:// 开头的 URL'**
  String get bangumiEchDohAddInvalid;

  /// No description provided for @bangumiEchDohMoveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get bangumiEchDohMoveUp;

  /// No description provided for @bangumiEchDohMoveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get bangumiEchDohMoveDown;

  /// No description provided for @bangumiEchDohRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get bangumiEchDohRemove;

  /// No description provided for @bangumiEchDohReset.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get bangumiEchDohReset;

  /// No description provided for @bangumiEchDohResetConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定清空自定义 DoH 列表并使用内置默认值？'**
  String get bangumiEchDohResetConfirm;

  /// No description provided for @bangumiEchDohTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试该 DoH'**
  String get bangumiEchDohTestTitle;

  /// No description provided for @bangumiEchDohTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功：获取到 {bytes} 字节 ECHConfig'**
  String bangumiEchDohTestSuccess(Object bytes);

  /// No description provided for @bangumiEchDohTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'该 DoH 不可达或返回内容不含 ECHConfig'**
  String get bangumiEchDohTestFailed;

  /// No description provided for @bangumiEchDohPriority.
  ///
  /// In zh, this message translates to:
  /// **'优先级 #{index}'**
  String bangumiEchDohPriority(Object index);

  /// No description provided for @manageUrls.
  ///
  /// In zh, this message translates to:
  /// **'管理 URL'**
  String get manageUrls;

  /// No description provided for @manageUrlsTitle.
  ///
  /// In zh, this message translates to:
  /// **'管理可选 URL'**
  String get manageUrlsTitle;

  /// No description provided for @addUrl.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addUrl;

  /// No description provided for @addUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://...'**
  String get addUrlHint;

  /// No description provided for @builtinUrl.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get builtinUrl;

  /// No description provided for @removeUrl.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeUrl;

  /// No description provided for @builtinUrlCannotRemove.
  ///
  /// In zh, this message translates to:
  /// **'内置 URL 不可删除'**
  String get builtinUrlCannotRemove;

  /// No description provided for @urlAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'该 URL 已存在'**
  String get urlAlreadyExists;

  /// No description provided for @invalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 URL（以 http:// 或 https:// 开头）'**
  String get invalidUrl;

  /// No description provided for @bangumiBaseUrlHidden.
  ///
  /// In zh, this message translates to:
  /// **'已启用 ECH 或反代，Bangumi Base URL 不生效'**
  String get bangumiBaseUrlHidden;

  /// Modal barrier label for dismissing the player settings panel.
  ///
  /// In zh, this message translates to:
  /// **'关闭设置'**
  String get closeSettingsBarrier;

  /// Modal barrier label for dismissing the episode side panel.
  ///
  /// In zh, this message translates to:
  /// **'关闭选集'**
  String get closeEpisodesBarrier;

  /// Generic enabled/on status subtitle in player settings.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get statusEnabled;

  /// Generic disabled/off status subtitle in player settings.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get statusDisabled;

  /// Subtitle menu status when the current video has no tracks.
  ///
  /// In zh, this message translates to:
  /// **'暂无字幕'**
  String get noSubtitlesAvailable;

  /// Player settings submenu title for danmaku.
  ///
  /// In zh, this message translates to:
  /// **'弹幕设置'**
  String get danmakuSettingsTitle;

  /// Player settings submenu title for subtitles.
  ///
  /// In zh, this message translates to:
  /// **'字幕设置'**
  String get subtitleSettingsTitle;

  /// Section header for playback speed presets.
  ///
  /// In zh, this message translates to:
  /// **'常用倍速'**
  String get commonPlaybackSpeeds;

  /// Playback speed label with normal-speed tag.
  ///
  /// In zh, this message translates to:
  /// **'{speed} (正常)'**
  String playbackSpeedWithNormal(String speed);

  /// Source menu subtitle when a non-online label is playing.
  ///
  /// In zh, this message translates to:
  /// **'当前：{label}'**
  String currentSourceOnly(String label);

  /// Source menu subtitle with online source count.
  ///
  /// In zh, this message translates to:
  /// **'当前：{label} ({count}个在线源可切换)'**
  String currentSourceWithOnlineCount(String label, int count);

  /// Source menu subtitle for the active online source.
  ///
  /// In zh, this message translates to:
  /// **'{label} ({count}个可用)'**
  String sourceLabelWithAvailableCount(String label, int count);

  /// Short empty-source status in the player settings source menu.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用源'**
  String get noAvailableSourcesShort;

  /// Display label when no source is currently playing. Internal sentinel remains Chinese.
  ///
  /// In zh, this message translates to:
  /// **'未播放'**
  String get notPlaying;

  /// Mobile gesture overlay for rewinding.
  ///
  /// In zh, this message translates to:
  /// **'快退 {seconds}s'**
  String rewindSeconds(int seconds);

  /// Mobile gesture overlay for seeking forward.
  ///
  /// In zh, this message translates to:
  /// **'快进 {seconds}s'**
  String forwardSeconds(int seconds);

  /// Mobile brightness gesture overlay.
  ///
  /// In zh, this message translates to:
  /// **'亮度 {percent}%'**
  String brightnessPercent(int percent);

  /// Mobile volume gesture overlay.
  ///
  /// In zh, this message translates to:
  /// **'音量 {percent}%'**
  String volumePercent(int percent);

  /// Mobile long-press 2x speed overlay label.
  ///
  /// In zh, this message translates to:
  /// **'长按快进 2x'**
  String get longPressFastForward;

  /// Mobile bangumi details tab label.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get bangumiDetailsTabDetails;

  /// Mobile bangumi comments tab label.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get bangumiDetailsTabComments;

  /// Bangumi details characters section title.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get bangumiDetailsCharacters;

  /// Bangumi details comments section title.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get bangumiDetailsComments;

  /// Empty comments state on bangumi details.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get bangumiDetailsNoComments;

  /// Fallback when subject summary is missing.
  ///
  /// In zh, this message translates to:
  /// **'暂无简介'**
  String get bangumiDetailsNoSummary;

  /// Favorite action when the subject is not favorited.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get bangumiDetailsFavorite;

  /// Favorite action when the subject is already favorited.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get bangumiDetailsFavorited;

  /// Mobile header collection totals row.
  ///
  /// In zh, this message translates to:
  /// **'{wish} 收藏 / {doing} 在看 / {dropped} 抛弃'**
  String bangumiDetailsCollectionStats(int wish, int doing, int dropped);

  /// Mobile rating vote count without rank.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人评'**
  String bangumiDetailsRatingVotes(int count);

  /// Mobile rating vote count with rank.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人评 | #{rank}'**
  String bangumiDetailsRatingVotesWithRank(int count, int rank);

  /// Wide layout rating card vote count.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人评分'**
  String bangumiDetailsVotes(int count);

  /// Wide layout ranking label.
  ///
  /// In zh, this message translates to:
  /// **'排名 #{rank}'**
  String bangumiDetailsRanked(int rank);

  /// Collection bucket label for wish.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get bangumiDetailsCollectWish;

  /// Collection bucket label for currently watching.
  ///
  /// In zh, this message translates to:
  /// **'在看'**
  String get bangumiDetailsCollectDoing;

  /// Collection bucket label for dropped.
  ///
  /// In zh, this message translates to:
  /// **'抛弃'**
  String get bangumiDetailsCollectDropped;

  /// Section loading placeholder body.
  ///
  /// In zh, this message translates to:
  /// **'正在加载{title}...'**
  String bangumiDetailsLoadingSection(String title);

  /// Secondary line under section loading placeholders.
  ///
  /// In zh, this message translates to:
  /// **'（即将推出）'**
  String get bangumiDetailsComingSoon;

  /// Summary toggle hint when original text is shown.
  ///
  /// In zh, this message translates to:
  /// **'点击显示翻译'**
  String get bangumiDetailsShowTranslation;

  /// Summary toggle hint when translation is shown.
  ///
  /// In zh, this message translates to:
  /// **'点击显示原文'**
  String get bangumiDetailsShowOriginal;

  /// Infobox collapse control.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get bangumiDetailsCollapse;

  /// Infobox expand control.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get bangumiDetailsExpand;

  /// Infobox section heading on bangumi details.
  ///
  /// In zh, this message translates to:
  /// **'资料'**
  String get bangumiDetailsInformation;

  /// Infobox hidden-item count hint.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 项，点击展开查看完整信息'**
  String bangumiDetailsMoreInfoItems(int count);

  /// Compact air date shown as year + month.
  ///
  /// In zh, this message translates to:
  /// **'{year}年 {month}月'**
  String bangumiDetailsYearMonth(int year, int month);

  /// Episode total status when count is positive.
  ///
  /// In zh, this message translates to:
  /// **'全 {count} 话'**
  String bangumiDetailsTotalEpisodes(int count);

  /// Episode total status when count is unknown/zero.
  ///
  /// In zh, this message translates to:
  /// **'0话'**
  String get bangumiDetailsZeroEpisodes;

  /// Related site kind badge for on-air sources.
  ///
  /// In zh, this message translates to:
  /// **'放送'**
  String get bangumiDetailsSiteOnair;

  /// Related site kind badge for info sources.
  ///
  /// In zh, this message translates to:
  /// **'资料'**
  String get bangumiDetailsSiteInfo;

  /// Related site kind badge for resource sources.
  ///
  /// In zh, this message translates to:
  /// **'资源'**
  String get bangumiDetailsSiteResource;

  /// Displayed character role badge for main cast.
  ///
  /// In zh, this message translates to:
  /// **'主角'**
  String get bangumiDetailsRoleMain;

  /// Displayed character role badge for supporting cast.
  ///
  /// In zh, this message translates to:
  /// **'配角'**
  String get bangumiDetailsRoleSupporting;

  /// Displayed character role badge for minor cast.
  ///
  /// In zh, this message translates to:
  /// **'闲角'**
  String get bangumiDetailsRoleMinor;

  /// Voice actor prefix before the person name.
  ///
  /// In zh, this message translates to:
  /// **'CV: '**
  String get bangumiDetailsCvPrefix;

  /// Character/person header comments chip.
  ///
  /// In zh, this message translates to:
  /// **'{count} 评论'**
  String detailsCommentsCount(int count);

  /// Character/person header collects chip.
  ///
  /// In zh, this message translates to:
  /// **'{count} 收藏'**
  String detailsCollectsCount(int count);

  /// Character/person stat column label for comments.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get detailsCommentsLabel;

  /// Character/person stat column label for collects.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get detailsCollectsLabel;

  /// Summary section title on character/person details.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get detailsSectionSummary;

  /// Infobox section title on character/person details.
  ///
  /// In zh, this message translates to:
  /// **'资料'**
  String get detailsSectionInfo;

  /// Appearances section title for seiyuu/character works.
  ///
  /// In zh, this message translates to:
  /// **'出演作品'**
  String get detailsSectionAppearances;

  /// Related works section title for non-seiyuu persons.
  ///
  /// In zh, this message translates to:
  /// **'相关作品'**
  String get detailsSectionRelatedWorks;

  /// Voice roles section title on person details.
  ///
  /// In zh, this message translates to:
  /// **'配音角色'**
  String get detailsSectionVoiceRoles;

  /// Number of works under a character group on person details.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部作品'**
  String detailsWorksCount(int count);

  /// CV chip showing the voice actor name.
  ///
  /// In zh, this message translates to:
  /// **'CV: {name}'**
  String detailsCvName(String name);

  /// Displayed male gender label.
  ///
  /// In zh, this message translates to:
  /// **'男性'**
  String get detailsGenderMale;

  /// Displayed female gender label.
  ///
  /// In zh, this message translates to:
  /// **'女性'**
  String get detailsGenderFemale;

  /// Birthday year fragment.
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String detailsBirthdayYear(int year);

  /// Birthday month fragment.
  ///
  /// In zh, this message translates to:
  /// **'{month}月'**
  String detailsBirthdayMonth(int month);

  /// Birthday day fragment.
  ///
  /// In zh, this message translates to:
  /// **'{day}日'**
  String detailsBirthdayDay(int day);

  /// Separator placed between birthday year/month/day fragments. Empty for locales whose fragments already include the unit, otherwise a short readable separator such as '-'.
  ///
  /// In zh, this message translates to:
  /// **''**
  String get detailsBirthdaySeparator;

  /// Person career badge for voice actor.
  ///
  /// In zh, this message translates to:
  /// **'声优'**
  String get personCareerSeiyu;

  /// Person career badge for producer.
  ///
  /// In zh, this message translates to:
  /// **'制作人'**
  String get personCareerProducer;

  /// Person career badge for mangaka.
  ///
  /// In zh, this message translates to:
  /// **'漫画家'**
  String get personCareerMangaka;

  /// Person career badge for music artist.
  ///
  /// In zh, this message translates to:
  /// **'音乐人'**
  String get personCareerArtist;

  /// Person career badge for writer.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get personCareerWriter;

  /// Person career badge for illustrator.
  ///
  /// In zh, this message translates to:
  /// **'插画家'**
  String get personCareerIllustrator;

  /// Secondary empty-state hint on the history page.
  ///
  /// In zh, this message translates to:
  /// **'在播放页开始观看后会自动记录'**
  String get historyEmptyHint;

  /// Home anime card original-work line.
  ///
  /// In zh, this message translates to:
  /// **'原作: {name}'**
  String homeOriginalWork(String name);

  /// Home anime card director line.
  ///
  /// In zh, this message translates to:
  /// **'导演: {name}'**
  String homeDirector(String name);

  /// Continue-watching card episode progress line.
  ///
  /// In zh, this message translates to:
  /// **'EP {sort} | {name}'**
  String homeEpisodeProgress(String sort, String name);

  /// Bangumi collection status: wish.
  ///
  /// In zh, this message translates to:
  /// **'想看'**
  String get favoritesStatusWish;

  /// Bangumi collection status: watched.
  ///
  /// In zh, this message translates to:
  /// **'看过'**
  String get favoritesStatusWatched;

  /// Bangumi collection status: watching.
  ///
  /// In zh, this message translates to:
  /// **'在看'**
  String get favoritesStatusWatching;

  /// Bangumi collection status: on hold.
  ///
  /// In zh, this message translates to:
  /// **'搁置'**
  String get favoritesStatusOnHold;

  /// Bangumi collection status: dropped.
  ///
  /// In zh, this message translates to:
  /// **'抛弃'**
  String get favoritesStatusDropped;

  /// Bangumi collection status: unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get favoritesStatusUnknown;

  /// Download task episode number label.
  ///
  /// In zh, this message translates to:
  /// **'第{number}集'**
  String downloadEpisodeNumber(int number);

  /// Confirm deleting an active download task.
  ///
  /// In zh, this message translates to:
  /// **'此任务正在运行中，确定要停止并删除吗？'**
  String get downloadDeleteRunningConfirm;

  /// Search sort option by date.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get searchSortDate;

  /// Search sort option by title.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get searchSortTitle;

  /// Fallback timetable archive title for current quarter.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{quarter}月'**
  String timetableQuarterTitle(int year, int quarter);

  /// Index browser filter group: category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get indexFilterCategory;

  /// Index browser filter group: source.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get indexFilterSource;

  /// Index browser filter group: type/genre.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get indexFilterType;

  /// Index browser filter group: region.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get indexFilterRegion;

  /// Index browser filter group: sort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get indexFilterSort;

  /// Index browser time filter group.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get indexFilterTime;

  /// Index browser month filter group.
  ///
  /// In zh, this message translates to:
  /// **'月份'**
  String get indexFilterMonth;

  /// Index browser unrestricted filter option.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get indexUnlimited;

  /// Index/search sort by rank.
  ///
  /// In zh, this message translates to:
  /// **'排名'**
  String get indexSortRank;

  /// Index/search sort by match score.
  ///
  /// In zh, this message translates to:
  /// **'相关度'**
  String get indexSortMatch;

  /// Index/search sort by collect/heat count.
  ///
  /// In zh, this message translates to:
  /// **'收藏数'**
  String get indexSortHeat;

  /// Index sort by trends.
  ///
  /// In zh, this message translates to:
  /// **'热度'**
  String get indexSortTrends;

  /// Legacy index sort by collect.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get indexSortCollect;

  /// Index sort by date.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get indexSortDate;

  /// Index sort by title.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get indexSortTitle;

  /// Index category option for theatrical movies.
  ///
  /// In zh, this message translates to:
  /// **'剧场版'**
  String get indexCategoryMovie;

  /// Index category/other option.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get indexCategoryOther;

  /// Index source option: original.
  ///
  /// In zh, this message translates to:
  /// **'原创'**
  String get indexSourceOriginal;

  /// Index source option: manga adaptation.
  ///
  /// In zh, this message translates to:
  /// **'漫画改'**
  String get indexSourceManga;

  /// Index source option: game adaptation.
  ///
  /// In zh, this message translates to:
  /// **'游戏改'**
  String get indexSourceGame;

  /// Index source option: novel adaptation.
  ///
  /// In zh, this message translates to:
  /// **'小说改'**
  String get indexSourceNovel;

  /// Index source option: live-action adaptation.
  ///
  /// In zh, this message translates to:
  /// **'影视改'**
  String get indexSourceLiveAction;

  /// Index month chip label.
  ///
  /// In zh, this message translates to:
  /// **'{month}月'**
  String indexMonthLabel(int month);

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get indexRegionJapan;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'欧美'**
  String get indexRegionWestern;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'中国'**
  String get indexRegionChina;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'美国'**
  String get indexRegionUsa;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'韩国'**
  String get indexRegionKorea;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'法国'**
  String get indexRegionFrance;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'中国香港'**
  String get indexRegionHongKong;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'英国'**
  String get indexRegionUk;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'俄罗斯'**
  String get indexRegionRussia;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'苏联'**
  String get indexRegionSoviet;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'捷克'**
  String get indexRegionCzech;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'中国台湾'**
  String get indexRegionTaiwan;

  /// Index region option.
  ///
  /// In zh, this message translates to:
  /// **'马来西亚'**
  String get indexRegionMalaysia;

  /// No description provided for @indexGenreScifi.
  ///
  /// In zh, this message translates to:
  /// **'科幻'**
  String get indexGenreScifi;

  /// No description provided for @indexGenreComedy.
  ///
  /// In zh, this message translates to:
  /// **'喜剧'**
  String get indexGenreComedy;

  /// No description provided for @indexGenreDoujin.
  ///
  /// In zh, this message translates to:
  /// **'同人'**
  String get indexGenreDoujin;

  /// No description provided for @indexGenreYuri.
  ///
  /// In zh, this message translates to:
  /// **'百合'**
  String get indexGenreYuri;

  /// No description provided for @indexGenreSchool.
  ///
  /// In zh, this message translates to:
  /// **'校园'**
  String get indexGenreSchool;

  /// No description provided for @indexGenreThriller.
  ///
  /// In zh, this message translates to:
  /// **'惊悚'**
  String get indexGenreThriller;

  /// No description provided for @indexGenreHarem.
  ///
  /// In zh, this message translates to:
  /// **'后宫'**
  String get indexGenreHarem;

  /// No description provided for @indexGenreMecha.
  ///
  /// In zh, this message translates to:
  /// **'机战'**
  String get indexGenreMecha;

  /// No description provided for @indexGenreMystery.
  ///
  /// In zh, this message translates to:
  /// **'悬疑'**
  String get indexGenreMystery;

  /// No description provided for @indexGenreRomance.
  ///
  /// In zh, this message translates to:
  /// **'恋爱'**
  String get indexGenreRomance;

  /// No description provided for @indexGenreFantasy.
  ///
  /// In zh, this message translates to:
  /// **'奇幻'**
  String get indexGenreFantasy;

  /// No description provided for @indexGenreDetective.
  ///
  /// In zh, this message translates to:
  /// **'推理'**
  String get indexGenreDetective;

  /// No description provided for @indexGenreSports.
  ///
  /// In zh, this message translates to:
  /// **'运动'**
  String get indexGenreSports;

  /// No description provided for @indexGenreBoysLove.
  ///
  /// In zh, this message translates to:
  /// **'耽美'**
  String get indexGenreBoysLove;

  /// No description provided for @indexGenreMusic.
  ///
  /// In zh, this message translates to:
  /// **'音乐'**
  String get indexGenreMusic;

  /// No description provided for @indexGenreAction.
  ///
  /// In zh, this message translates to:
  /// **'战斗'**
  String get indexGenreAction;

  /// No description provided for @indexGenreAdventure.
  ///
  /// In zh, this message translates to:
  /// **'冒险'**
  String get indexGenreAdventure;

  /// No description provided for @indexGenreMoe.
  ///
  /// In zh, this message translates to:
  /// **'萌系'**
  String get indexGenreMoe;

  /// No description provided for @indexGenreIsekai.
  ///
  /// In zh, this message translates to:
  /// **'穿越'**
  String get indexGenreIsekai;

  /// No description provided for @indexGenreXuanhuan.
  ///
  /// In zh, this message translates to:
  /// **'玄幻'**
  String get indexGenreXuanhuan;

  /// No description provided for @indexGenreOtome.
  ///
  /// In zh, this message translates to:
  /// **'乙女'**
  String get indexGenreOtome;

  /// No description provided for @indexGenreHorror.
  ///
  /// In zh, this message translates to:
  /// **'恐怖'**
  String get indexGenreHorror;

  /// No description provided for @indexGenreHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get indexGenreHistory;

  /// No description provided for @indexGenreSliceOfLife.
  ///
  /// In zh, this message translates to:
  /// **'日常'**
  String get indexGenreSliceOfLife;

  /// No description provided for @indexGenreDrama.
  ///
  /// In zh, this message translates to:
  /// **'剧情'**
  String get indexGenreDrama;

  /// No description provided for @indexGenreWuxia.
  ///
  /// In zh, this message translates to:
  /// **'武侠'**
  String get indexGenreWuxia;

  /// No description provided for @indexGenreFood.
  ///
  /// In zh, this message translates to:
  /// **'美食'**
  String get indexGenreFood;

  /// No description provided for @indexGenreWorkplace.
  ///
  /// In zh, this message translates to:
  /// **'职场'**
  String get indexGenreWorkplace;

  /// No description provided for @playerMobileEpisodeSelector.
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get playerMobileEpisodeSelector;

  /// No description provided for @playerMobilePlaySource.
  ///
  /// In zh, this message translates to:
  /// **'播放源'**
  String get playerMobilePlaySource;

  /// No description provided for @playerMobileOfficialPlaySource.
  ///
  /// In zh, this message translates to:
  /// **'官方播放源'**
  String get playerMobileOfficialPlaySource;

  /// No description provided for @playerMobileRelated.
  ///
  /// In zh, this message translates to:
  /// **'相关推荐'**
  String get playerMobileRelated;

  /// No description provided for @playerMobileSummaryAndRecommend.
  ///
  /// In zh, this message translates to:
  /// **'简介 & 推荐'**
  String get playerMobileSummaryAndRecommend;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'评论 ({count})'**
  String playerMobileCommentsTab(int count);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'{count} 集'**
  String playerMobilePlayableEpisodeCount(int count);

  /// No description provided for @playerPcEpisodeList.
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get playerPcEpisodeList;

  /// No description provided for @playerPcPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playerPcPlaylist;

  /// No description provided for @playerPcCommentsSection.
  ///
  /// In zh, this message translates to:
  /// **'评论区'**
  String get playerPcCommentsSection;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'已找到 {count} 个BT源，{online} 个订阅源，当前源：{current}'**
  String playerSourceTitleFound(int count, int online, String current);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'当前：{label}'**
  String playerSourceTitleCurrent(String label);

  /// No description provided for @playerSourceTitleFoundMobile.
  ///
  /// In zh, this message translates to:
  /// **'已找到'**
  String get playerSourceTitleFoundMobile;

  /// No description provided for @playerSourceTabBt.
  ///
  /// In zh, this message translates to:
  /// **'BT'**
  String get playerSourceTabBt;

  /// No description provided for @playerSourceTabSubscription.
  ///
  /// In zh, this message translates to:
  /// **'订阅源'**
  String get playerSourceTabSubscription;

  /// No description provided for @playerSourceLabelOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线源下载'**
  String get playerSourceLabelOnline;

  /// No description provided for @playerSourceLabelBt.
  ///
  /// In zh, this message translates to:
  /// **'BT下载'**
  String get playerSourceLabelBt;

  /// No description provided for @playerSourceLabelOnlineShort.
  ///
  /// In zh, this message translates to:
  /// **'在线源'**
  String get playerSourceLabelOnlineShort;

  /// No description provided for @playerNoDownloadableSource.
  ///
  /// In zh, this message translates to:
  /// **'没有可下载的在线源'**
  String get playerNoDownloadableSource;

  /// No description provided for @playerAddDownloadTaskFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加下载任务失败，请稍后重试'**
  String get playerAddDownloadTaskFailed;

  /// No description provided for @playerAddDownloadTaskSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已添加到下载任务'**
  String get playerAddDownloadTaskSuccess;

  /// No description provided for @playerNoCopyableLink.
  ///
  /// In zh, this message translates to:
  /// **'没有可复制的下载链接'**
  String get playerNoCopyableLink;

  /// No description provided for @playerDownloadLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'下载链接已复制'**
  String get playerDownloadLinkCopied;

  /// No description provided for @playerDownloadButton.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get playerDownloadButton;

  /// No description provided for @playerCopyDownloadLinkButton.
  ///
  /// In zh, this message translates to:
  /// **'复制下载链接'**
  String get playerCopyDownloadLinkButton;

  /// No description provided for @playerCopyAction.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get playerCopyAction;

  /// No description provided for @playerPlayButton.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playerPlayButton;

  /// No description provided for @playerLoadAction.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get playerLoadAction;

  /// No description provided for @playerSampleStatusLocalManual.
  ///
  /// In zh, this message translates to:
  /// **'已播放本地资源，在线源搜索待手动触发'**
  String get playerSampleStatusLocalManual;

  /// No description provided for @playerSampleStatusAutoDisabled.
  ///
  /// In zh, this message translates to:
  /// **'在线搜索已关闭，可手动搜索在线源'**
  String get playerSampleStatusAutoDisabled;

  /// No description provided for @playerSampleStatusNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'尚未开始搜索在线源'**
  String get playerSampleStatusNotStarted;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'搜索完成 ({done}/{total} 个可用)'**
  String playerSampleStatusCompleted(int done, int total);

  /// No description provided for @playerSampleStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get playerSampleStatusFailed;

  /// No description provided for @playerSampleSummaryLocalManual.
  ///
  /// In zh, this message translates to:
  /// **'已使用本地资源播放'**
  String get playerSampleSummaryLocalManual;

  /// No description provided for @playerSampleSummaryAutoDisabled.
  ///
  /// In zh, this message translates to:
  /// **'在线搜索已关闭'**
  String get playerSampleSummaryAutoDisabled;

  /// No description provided for @playerSampleHintLocalManual.
  ///
  /// In zh, this message translates to:
  /// **'如需在线源，请点击下方按钮手动搜索'**
  String get playerSampleHintLocalManual;

  /// No description provided for @playerSampleHintAutoDisabled.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮手动搜索在线源'**
  String get playerSampleHintAutoDisabled;

  /// No description provided for @playerSampleHintNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮开始搜索'**
  String get playerSampleHintNotStarted;

  /// No description provided for @playerSamplePlayButtonBase.
  ///
  /// In zh, this message translates to:
  /// **'播放 - '**
  String get playerSamplePlayButtonBase;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'播放 - {source}({channel})'**
  String playerSamplePlayButtonWithChannel(String source, String channel);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'播放 - {source}'**
  String playerSamplePlayButtonWithSource(String source);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'并发WebView任务 ({active}/{max})'**
  String playerWebViewTaskCount(int active, int max);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'并发WebView任务 ({active}/{max}) · {pool}'**
  String playerWebViewTaskCountWithPool(int active, int max, String pool);

  /// No description provided for @playerWebViewShowDebug.
  ///
  /// In zh, this message translates to:
  /// **'显示 WebView (调试)'**
  String get playerWebViewShowDebug;

  /// No description provided for @playerWebViewWorkerPoolSwitch.
  ///
  /// In zh, this message translates to:
  /// **'统一 Worker 调度 (Round 7)'**
  String get playerWebViewWorkerPoolSwitch;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'可用源 ({count})'**
  String playerWebViewAvailableSources(int count);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'per-source [p|a|c]: {status}'**
  String playerWebViewPerSourceStatus(String status);

  /// No description provided for @playerSearchProgressStepPending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get playerSearchProgressStepPending;

  /// No description provided for @playerSearchProgressStepSearching.
  ///
  /// In zh, this message translates to:
  /// **'搜索中...'**
  String get playerSearchProgressStepSearching;

  /// No description provided for @playerSearchProgressStepDetail.
  ///
  /// In zh, this message translates to:
  /// **'获取详情页...'**
  String get playerSearchProgressStepDetail;

  /// No description provided for @playerSearchProgressStepEpisodes.
  ///
  /// In zh, this message translates to:
  /// **'获取剧集列表...'**
  String get playerSearchProgressStepEpisodes;

  /// No description provided for @playerSearchProgressStepExtracting.
  ///
  /// In zh, this message translates to:
  /// **'提取视频链接...'**
  String get playerSearchProgressStepExtracting;

  /// No description provided for @playerSearchProgressStepSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get playerSearchProgressStepSuccess;

  /// No description provided for @playerSearchProgressStepFoundPlayPage.
  ///
  /// In zh, this message translates to:
  /// **'找到播放页'**
  String get playerSearchProgressStepFoundPlayPage;

  /// No description provided for @playerSearchProgressStepFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get playerSearchProgressStepFailed;

  /// Composite progress line shown while search + captcha pre-flight are running.
  ///
  /// In zh, this message translates to:
  /// **'搜索进度: {completed}/{enabled}，验证码 {activeCaptcha} 运行/{pendingCaptcha} 排队'**
  String playerSearchSessionProgressLine(
    int completed,
    int enabled,
    int activeCaptcha,
    int pendingCaptcha,
  );

  /// No description provided for @playerSearchSessionNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未在任何源中找到该动画'**
  String get playerSearchSessionNotFound;

  /// No description provided for @playerSearchSessionAllFailed.
  ///
  /// In zh, this message translates to:
  /// **'所有源都无法提取视频链接'**
  String get playerSearchSessionAllFailed;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'搜索完成，共找到 {count} 个可用源'**
  String playerSearchSessionDone(int count);

  /// No description provided for @playerSearchLocalPlayedHint.
  ///
  /// In zh, this message translates to:
  /// **'已播放本地资源，可手动搜索在线源'**
  String get playerSearchLocalPlayedHint;

  /// No description provided for @playerSearchAutoDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'在线搜索已关闭，可手动搜索在线源'**
  String get playerSearchAutoDisabledHint;

  /// No description provided for @playerSearchLocalPlayedActionHint.
  ///
  /// In zh, this message translates to:
  /// **'已播放本地资源，点击刷新可手动搜索在线源'**
  String get playerSearchLocalPlayedActionHint;

  /// No description provided for @playerSearchFetchingSourceList.
  ///
  /// In zh, this message translates to:
  /// **'正在获取播放源列表...'**
  String get playerSearchFetchingSourceList;

  /// No description provided for @playerSearchNoEnabledSource.
  ///
  /// In zh, this message translates to:
  /// **'未启用任何播放源'**
  String get playerSearchNoEnabledSource;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索 {count} 个源...'**
  String playerSearchProgressSearchMany(int count);

  /// No description provided for @playerSearchProgressCaptchaPreflight.
  ///
  /// In zh, this message translates to:
  /// **'非验证码源先行搜索，验证码源并发预处理中...'**
  String get playerSearchProgressCaptchaPreflight;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'提取中: {completed}/{total} 完成，{active} 并发运行'**
  String playerWebviewExtractInProgress(int completed, int total, int active);

  /// No description provided for @playerWebviewCaptchaBypass.
  ///
  /// In zh, this message translates to:
  /// **'正在跳过验证码'**
  String get playerWebviewCaptchaBypass;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'{label} - 正在跳过验证码'**
  String playerWebviewCaptchaBypassTitle(String label);

  /// No description provided for @playerWebviewExtracting.
  ///
  /// In zh, this message translates to:
  /// **'正在提取...'**
  String get playerWebviewExtracting;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'搜索进度: {completed}/{total}'**
  String playerWebviewSchedulerProgress(int completed, int total);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'验证码进行中 {count}'**
  String playerWebviewCaptchaActive(int count);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'提取并发 {active}/{max}'**
  String playerWebviewExtractionActive(int active, int max);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'{title} - 第{episode}集'**
  String playerPageTitleWithEpisode(String title, int episode);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'第{episode}集'**
  String playerEpisodeNumber(int episode);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'{title} - {episode} ({source})'**
  String playerDownloadTaskName(String title, String episode, String source);

  /// No description provided for @playerSidePanelPrequel.
  ///
  /// In zh, this message translates to:
  /// **'前传'**
  String get playerSidePanelPrequel;

  /// No description provided for @playerSidePanelSequel.
  ///
  /// In zh, this message translates to:
  /// **'续集'**
  String get playerSidePanelSequel;

  /// No description provided for @playerSidePanelLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取播放地址'**
  String get playerSidePanelLoadFailed;

  /// No description provided for @playerSidePanelCopyMagnet.
  ///
  /// In zh, this message translates to:
  /// **'磁力链接已复制'**
  String get playerSidePanelCopyMagnet;

  /// No description provided for @playerSidePanelDownloadHint.
  ///
  /// In zh, this message translates to:
  /// **'开始下载，可在「我的」页面查看进度'**
  String get playerSidePanelDownloadHint;

  /// No description provided for @playerRecommendationsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无相关推荐'**
  String get playerRecommendationsEmpty;

  /// No description provided for @playerNoDescription.
  ///
  /// In zh, this message translates to:
  /// **'暂无简介'**
  String get playerNoDescription;

  /// No description provided for @playerCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get playerCollapse;

  /// No description provided for @playerExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get playerExpand;

  /// No description provided for @playerCommentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'全部评论'**
  String get playerCommentsTitle;

  /// No description provided for @playerCommentsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get playerCommentsEmpty;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String playerCommentsLoadFailed(String error);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String playerCommentsLoadFailedPc(String error);

  /// No description provided for @playerCommentsEmptyPc.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get playerCommentsEmptyPc;

  /// No description provided for @playerResourceListSearching.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索BT源...'**
  String get playerResourceListSearching;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'已找到 {count} 个BT源'**
  String playerResourceListFound(int count);

  /// No description provided for @playerResourceListFailed.
  ///
  /// In zh, this message translates to:
  /// **'BT搜索失败'**
  String get playerResourceListFailed;

  /// No description provided for @playerResourceListNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'尚未开始搜索BT源'**
  String get playerResourceListNotStarted;

  /// No description provided for @playerResourceListStartSearch.
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮开始搜索'**
  String get playerResourceListStartSearch;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'搜索完成，共找到 {count} 个可用源'**
  String playerAutoplaySearchDone(int count);

  /// No description provided for @playerSourceControllerAnimeNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到番剧'**
  String get playerSourceControllerAnimeNotFound;

  /// Shown when media_kit fails to open an online source URL.
  ///
  /// In zh, this message translates to:
  /// **'播放失败: {error}'**
  String playerPlaybackOpenFailed(String error);

  /// No description provided for @playerPlaybackStartupTimeout.
  ///
  /// In zh, this message translates to:
  /// **'当前线路启动超时，请切换其他源'**
  String get playerPlaybackStartupTimeout;

  /// No description provided for @playerSortDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get playerSortDefault;

  /// No description provided for @playerSortByTime.
  ///
  /// In zh, this message translates to:
  /// **'按时间排序'**
  String get playerSortByTime;

  /// No description provided for @playerSubscriptionDebugSearchDirectProbe.
  ///
  /// In zh, this message translates to:
  /// **'搜索直链 Probe'**
  String get playerSubscriptionDebugSearchDirectProbe;

  /// No description provided for @playerSubscriptionDebugProbeInProgress.
  ///
  /// In zh, this message translates to:
  /// **'Probe 中...'**
  String get playerSubscriptionDebugProbeInProgress;

  /// No description provided for @playerSubscriptionDebugProbeNotDone.
  ///
  /// In zh, this message translates to:
  /// **'未 Probe'**
  String get playerSubscriptionDebugProbeNotDone;

  /// No description provided for @playerSubscriptionDebugPlayable.
  ///
  /// In zh, this message translates to:
  /// **'可播放'**
  String get playerSubscriptionDebugPlayable;

  /// No description provided for @playerSubscriptionDebugNotPlayable.
  ///
  /// In zh, this message translates to:
  /// **'不可播放'**
  String get playerSubscriptionDebugNotPlayable;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'缓存 JSON 不存在: {path}'**
  String playerSubscriptionDebugCacheJsonMissing(String path);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在: {path}'**
  String playerSubscriptionDebugFileMissing(String path);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'开始调试搜索: anime={anime}, abs={abs}, rel={relative}, filter={filter}, json={jsonSource}'**
  String playerSubscriptionDebugStartSearch(
    String anime,
    String abs,
    String relative,
    String filter,
    String jsonSource,
  );

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'搜索异常: {error}'**
  String playerSubscriptionDebugSearchError(String error);

  /// No description provided for @playerSubscriptionDebugSearchFinished.
  ///
  /// In zh, this message translates to:
  /// **'搜索结束'**
  String get playerSubscriptionDebugSearchFinished;

  /// No description provided for @playerSubscriptionDebugCaptchaPageClosed.
  ///
  /// In zh, this message translates to:
  /// **'页面已关闭，无法完成验证码预处理'**
  String get playerSubscriptionDebugCaptchaPageClosed;

  /// No description provided for @playerSubscriptionDebugCaptchaPreflightFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证码预处理失败'**
  String get playerSubscriptionDebugCaptchaPreflightFailed;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'{name} -> 正在进行验证码预处理 ({current}/{total})'**
  String playerSubscriptionDebugCaptchaPreflight(
    String name,
    int current,
    int total,
  );

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'解析captcha源失败: {error}'**
  String playerSubscriptionDebugCaptchaParseFailed(String error);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'开始提取: {name}'**
  String playerSubscriptionDebugExtractStart(String name);

  /// No description provided for @playerSubscriptionDebugStartSearchButton.
  ///
  /// In zh, this message translates to:
  /// **'开始调试搜索'**
  String get playerSubscriptionDebugStartSearchButton;

  /// No description provided for @playerSubscriptionDebugManualProbe.
  ///
  /// In zh, this message translates to:
  /// **'手动 Probe'**
  String get playerSubscriptionDebugManualProbe;

  /// No description provided for @playerSubscriptionDebugProbeActive.
  ///
  /// In zh, this message translates to:
  /// **'Probe 中'**
  String get playerSubscriptionDebugProbeActive;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'直链: {url}'**
  String playerSubscriptionDebugDirectLink(String url);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'来源: {name}'**
  String playerSubscriptionDebugSourceName(String name);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'Headers: {headers}'**
  String playerSubscriptionDebugHeaders(String headers);

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'提取成功: {url}'**
  String playerSubscriptionDebugExtractSuccess(String url);

  /// No description provided for @playerSubscriptionDebugExtractFailedShort.
  ///
  /// In zh, this message translates to:
  /// **'提取失败'**
  String get playerSubscriptionDebugExtractFailedShort;

  /// Player UI message with typed placeholders.
  ///
  /// In zh, this message translates to:
  /// **'提取失败: {error}'**
  String playerSubscriptionDebugExtractFailedDetail(String error);

  /// No description provided for @playerSubscriptionDebugPostProbe.
  ///
  /// In zh, this message translates to:
  /// **'提取后 Probe'**
  String get playerSubscriptionDebugPostProbe;

  /// No description provided for @playerSubscriptionDebugJsonCache.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get playerSubscriptionDebugJsonCache;

  /// No description provided for @playerSubscriptionDebugJsonLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get playerSubscriptionDebugJsonLocal;

  /// No description provided for @playerSubscriptionDebugJsonPathHint.
  ///
  /// In zh, this message translates to:
  /// **'D:\\temp\\online.json，或留空'**
  String get playerSubscriptionDebugJsonPathHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
