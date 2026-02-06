// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Mikan Player';

  @override
  String get homeTitle => 'Mikan Player';

  @override
  String get statusEnterMagnet => '请输入磁力链接以开始';

  @override
  String get statusInitializing => '正在初始化种子...';

  @override
  String statusPlaying(Object streamUrl) {
    return '正在播放：$streamUrl';
  }

  @override
  String statusError(Object error) {
    return '错误：$error';
  }

  @override
  String get magnetHint => 'magnet:?xt=urn:btih:...';

  @override
  String get playButton => '播放';

  @override
  String get navHome => '首页';

  @override
  String get navTimetable => '放送表';

  @override
  String get navRanking => '排行榜';

  @override
  String get navIndex => '索引';

  @override
  String get navMy => '我的';

  @override
  String get navSettings => '设置';

  @override
  String get searchHint => '搜索番剧';

  @override
  String get historyTitle => '播放历史';

  @override
  String get historySubtitle => '继续上次看的内容';

  @override
  String get favoritesTitle => '我的收藏';

  @override
  String get favoritesSubtitle => '你收藏的番剧';

  @override
  String get downloadTitle => '下载管理';

  @override
  String get downloadSubtitle => '管理已下载的视频';

  @override
  String get aboutTitle => '关于';

  @override
  String version(Object version) {
    return '版本 $version';
  }

  @override
  String get loginPrompt => '点击登录';

  @override
  String get loginSubtitle => '登录同步 Bangumi 数据';

  @override
  String get logoutTitle => '退出登录';

  @override
  String get logoutConfirm => '确定要清除当前用户信息的缓存吗？';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get logout => '退出';

  @override
  String get clearCompleted => '清除已完成';

  @override
  String get noDownloads => '暂无下载任务';

  @override
  String get startDownloadHint => '在播放页面选择资源开始下载';

  @override
  String get deleteTask => '删除任务';

  @override
  String get clearConfirmTitle => '确认清除';

  @override
  String clearConfirmMessage(Object count) {
    return '将清除 $count 个已完成的任务';
  }

  @override
  String get deleteFiles => '同时删除物理文件';

  @override
  String get noCompletedTasks => '没有已完成的任务';

  @override
  String clearedTasks(Object count) {
    return '已清除 $count 个任务';
  }

  @override
  String get downloading => '下载中';

  @override
  String get seeding => '做种中';

  @override
  String get paused => '暂停';

  @override
  String get resume => '恢复';

  @override
  String get pause => '暂停';

  @override
  String get clickToPlay => '点击播放';

  @override
  String peers(Object count) {
    return '$count 个连接';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get dataSourceSettings => '数据源设置';

  @override
  String get dataSourceSubtitle => '设置 bgmlist, bangumi, 蜜柑计划的 base URL';

  @override
  String get searchSettings => '搜索设置';

  @override
  String get searchSubtitle => '设置并发布数量及相关参数';

  @override
  String get cacheManagement => '缓存管理';

  @override
  String get clearCache => '清除全部缓存';

  @override
  String get confirmClearCache => '确认清除缓存';

  @override
  String get clearCacheMessage => '这将删除所有缓存数据，包括番剧信息和图片缓存。确定要继续吗？';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String cacheClearedFailed(Object error) {
    return '清除缓存失败: $error';
  }

  @override
  String get refresh => '刷新';

  @override
  String get loading => '加载中...';

  @override
  String get language => '语言';

  @override
  String get languageSubtitle => '选择应用界面语言';

  @override
  String get chinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get auto => '跟随系统';

  @override
  String get todayBroadcast => '今日放送';

  @override
  String get recentHot => '近期热门';

  @override
  String get viewMore => '查看更多';

  @override
  String get noTodayUpdate => '今天没有更新的番剧哦';

  @override
  String get viewFullTimetable => '查看完整时间表';

  @override
  String get noData => '暂无数据';

  @override
  String get noHistory => '暂无播放记录';

  @override
  String get noFavorites => '暂无收藏';

  @override
  String updateTime(Object time) {
    return '更新时间: $time';
  }

  @override
  String get monday => '周一';

  @override
  String get tuesday => '周二';

  @override
  String get wednesday => '周三';

  @override
  String get thursday => '周四';

  @override
  String get friday => '周五';

  @override
  String get saturday => '周六';

  @override
  String get sunday => '周日';

  @override
  String get others => '其他';

  @override
  String get selectQuarter => '选择季度';

  @override
  String get noAnimeFoundDay => '今天没有找到番剧。';

  @override
  String get errorOccurred => '出错了';

  @override
  String get unknownError => '未知错误';

  @override
  String get retry => '重试';

  @override
  String get networkError => '网络连接失败，请检查网络设置或稍后再试';

  @override
  String get resourceNotFound => '资源未找到 (404)';

  @override
  String get aboutIntro => '自用的看动漫软件，鉴定为对Animeko的拙劣模仿';

  @override
  String get aboutSourceCode => '项目源代码：';

  @override
  String get aboutTechStack => '技术栈';

  @override
  String get aboutDataSources => '数据来源';

  @override
  String get aboutDataSourcesList => 'bgmlist bangumi 蜜柑计划 动漫花园 弹弹play';

  @override
  String get aboutDisclaimer => '网络同步是单向的，所有数据均为本地存储，不会影响在线账号';

  @override
  String get techStackFlutter => 'Flutter：跨平台 UI 构建';

  @override
  String get techStackRust => 'Rust：核心业务逻辑与爬虫';

  @override
  String get techStackIsar => 'Isar：本地数据库';

  @override
  String get techStackMediaKit => 'MediaKit：视频播放核心';

  @override
  String get techStackDanmaku => 'CanvasDanmaku：弹幕渲染';

  @override
  String get sourceMeta => 'Bangumi / bgmlist：番剧元数据与放送表';

  @override
  String get sourceTorrent => '蜜柑计划 / 动漫花园：资源与磁力链接';

  @override
  String get sourceDanmaku => '弹弹play：弹幕数据';
}
