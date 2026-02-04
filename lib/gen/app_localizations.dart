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

  /// No description provided for @favoritesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你收藏的番剧'**
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
  /// **'设置 bgmlist, bangumi, 蜜柑计划的 base URL'**
  String get dataSourceSubtitle;

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
  /// **'这将删除所有缓存数据，包括番剧信息和图片缓存。确定要继续吗？'**
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
