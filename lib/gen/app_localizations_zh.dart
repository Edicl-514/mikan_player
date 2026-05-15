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
  String get statusPending => '等待中';

  @override
  String get statusMetadata => '获取元数据';

  @override
  String get statusChecking => '校验中';

  @override
  String get statusQueued => '排队中';

  @override
  String get statusCompleted => '已完成';

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
  String get downloadSettingsTitle => '下载设置';

  @override
  String get downloadSettingsSaveButton => '保存设置';

  @override
  String get downloadSettingsSaved => '下载设置已保存';

  @override
  String get downloadSettingsInvalidNumber => '请输入有效的限速数值';

  @override
  String get downloadEngineTitle => 'BT 引擎';

  @override
  String get downloadEngineSubtitle => '新建和自动恢复的 BT 任务会使用所选后端';

  @override
  String get downloadParallelTasks => '并行下载任务数';

  @override
  String get downloadParallelHint => '1-10，默认3';

  @override
  String get downloadSpeedLimitsHeader => '速度限制 (0 = 不限速)';

  @override
  String get downloadDownloadLimit => '下载限速 (MB/s)';

  @override
  String get downloadDownloadLimitHint => '0 表示不限速';

  @override
  String get downloadUploadLimit => '上传限速 (MB/s)';

  @override
  String get downloadUploadLimitHint => '0 表示不限速，仅对 BT 生效';

  @override
  String get allowBackgroundDownload => '允许后台下载';

  @override
  String get allowBackgroundDownloadSubtitle => '切到后台时保持下载任务运行';

  @override
  String get keepSeedingMode => '保种模式';

  @override
  String get keepSeedingModeSubtitle => '下载完成转为做种后继续保持后台运行';

  @override
  String get downloadSettingsEntrySubtitle => '并行任务数、限速、BT引擎、后台下载';

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
  String get themeMode => '主题模式';

  @override
  String get themeModeSubtitle => '选择亮色或暗色模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themeSettings => '主题设置';

  @override
  String get themeSettingsSubtitle => '主题模式与颜色设置';

  @override
  String get customThemeColor => '自定义主题色';

  @override
  String get themeColor => '主题色';

  @override
  String get themeColorSubtitle => '选择应用主题色';

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
  String get techStackDatabase => 'Drift：本地 SQLite 数据库';

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

  @override
  String get share => '分享';

  @override
  String get copied => '已复制';

  @override
  String get filterByStatus => '按状态筛选';

  @override
  String get filterAll => '全部';

  @override
  String get filterActive => '进行中';

  @override
  String get filterChecking => '校验中';

  @override
  String get filterCompleted => '已完成';

  @override
  String get filterPaused => '已暂停';

  @override
  String get filterError => '出错';

  @override
  String tasksCount(Object count) {
    return '$count 个任务';
  }

  @override
  String get settingsSubtitle => '应用配置';

  @override
  String get searchHintText => '搜索番剧...';

  @override
  String get searchNoResults => '未找到结果';

  @override
  String get searchEnterKeyword => '输入关键词进行搜索';

  @override
  String searchFailed(Object error) {
    return '搜索失败: $error';
  }

  @override
  String get loginDialogTitle => '登录 Bangumi';

  @override
  String get loginDialogMessage => '请输入 Bangumi 用户名或 ID 获取公开信息';

  @override
  String get loginUsernameLabel => '用户名 / ID';

  @override
  String get loginUsernameHint => '注意：是用户名不是昵称';

  @override
  String get loginError => '登录失败，请检查用户名或网络';

  @override
  String get cannotLoadEpisodes => '无法加载剧集列表';

  @override
  String get pleaseEnterAnimeName => '请先填写动漫名称';

  @override
  String get absoluteEpisodeMustBeInteger => '绝对集数必须是整数';

  @override
  String get relativeEpisodeMustBeInteger => '相对集数必须是整数';

  @override
  String get episodeMustBeGreaterThanZero => '集数必须大于 0';

  @override
  String get save => '保存';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get autoSelectFastestSource => '自动选择最快源';

  @override
  String get refreshPlaybackSource => '刷新播放源';

  @override
  String get playbackSourceSubscriptionUrl => '播放源订阅地址';

  @override
  String get bgmBaseUrl => 'Bgmlist Base URL';

  @override
  String get bangumiBaseUrl => 'Bangumi Base URL';

  @override
  String get mikanBaseUrl => 'Mikan Base URL';

  @override
  String get subscriptionSwitchTitle => '订阅源开关 (全网搜)';

  @override
  String get customSourceDescription => '自定义网络搜视源';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get playbackSourceRefreshed => '播放源已刷新';

  @override
  String playbackSourceRefreshedSynced(Object count) {
    return '播放源已刷新，并同步了 $count 个默认开关';
  }

  @override
  String fastestSourceSwitched(Object latency, Object url) {
    return '已切换至最快源: $url (${latency}ms)';
  }

  @override
  String refreshFailed(Object error) {
    return '刷新失败: $error';
  }

  @override
  String fetchCollectionsFailed(Object error) {
    return '获取收藏失败: $error';
  }

  @override
  String get noLocalFavorites => '暂无本地收藏';

  @override
  String get loginBangumiFirst => '请先登录 Bangumi 账号';

  @override
  String get goToLogin => '去登录';

  @override
  String get noBangumiFavorites => '暂无 Bangumi 收藏数据';

  @override
  String get refreshAllFavorites => '刷新所有收藏';

  @override
  String get rankingTitle => '排行榜';

  @override
  String get rankingTrending => '近期热门';

  @override
  String get rankingRanking => '排行榜';

  @override
  String loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String noRelatedAnime(Object tag) {
    return '没有找到「$tag」相关的动画';
  }

  @override
  String get pageRetry => '重试';

  @override
  String get dataSourceConfigTitle => '数据源配置';

  @override
  String get searchConfigTitle => 'searchConfig';

  @override
  String get captchaConfigTitle => 'captchaConfig';

  @override
  String get dataSourceConfigSave => '保存';

  @override
  String get searchSettingsTitle => '搜索设置';

  @override
  String get maxParallelSearchSources => '最大并行搜索源数量';

  @override
  String get maxParallelSearchSourcesHint => '默认为3，0为不限制（Generic Scraper）';

  @override
  String get webviewScraperSettingsTitle =>
      'WebView Scraper设置 (仅针对Dynamic Webview源)';

  @override
  String get maxWebviewConcurrent => '最大WebView并发数量';

  @override
  String get maxWebviewConcurrentHint => '建议值: 1-3';

  @override
  String get webviewLaunchInterval => 'WebView启动间隔 (毫秒)';

  @override
  String get webviewLaunchIntervalHint => '建议值: 200-1000';

  @override
  String get autoSearchOnlineTitle => '自动搜索在线源';

  @override
  String get autoSearchOnlineSubtitle => '关闭后，播放页将只自动搜索BT源';

  @override
  String get localJsonPathLabel => '本地 JSON 路径（留空使用缓存）';

  @override
  String get animeNameLabel => '动漫名称';

  @override
  String get animeNameHint => '例如：机动战士高达GQuuuuuuX';

  @override
  String get absoluteEpisodeLabel => '绝对集数';

  @override
  String get relativeEpisodeLabel => '相对集数';

  @override
  String get optionalEmptyHint => '可留空';

  @override
  String get sourceFilterLabel => '源名过滤（可选）';

  @override
  String get sourceFilterHint => '大小写不敏感，包含匹配';

  @override
  String get showWebViewDebugSwitch => '显示 WebView 调试开关';

  @override
  String get showWebViewDebugSubtitle => '仅影响调试提取画面显示，不影响搜索逻辑';

  @override
  String get clear => '清空';

  @override
  String get sourceCount => '源数量';

  @override
  String get success => '成功';

  @override
  String get failure => '失败';

  @override
  String get inProgress => '进行中';

  @override
  String get noDebugSearchResult => '暂无结果。输入参数后点击“开始调试搜索”。';

  @override
  String debugStatus(Object status) {
    return '状态: $status';
  }

  @override
  String channelLine(Object line) {
    return '线路: $line';
  }

  @override
  String playPage(Object url) {
    return '播放页: $url';
  }

  @override
  String get extractUrl => '提取URL';

  @override
  String get extractDebugTitle => '可播放 URL 提取调试';

  @override
  String extractFailed(Object error) {
    return '提取失败: $error';
  }

  @override
  String extractSuccess(Object url) {
    return '提取成功: $url';
  }

  @override
  String get logsEmpty => '暂无日志';

  @override
  String get subscriptionDebugTitle => '订阅源调试';

  @override
  String get subscriptionDebugJsonTitle => '订阅源 JSON 调试';

  @override
  String get subscriptionDebugDisabled =>
      '当前构建未启用订阅调试。\n请使用 --dart-define=ENABLE_SUBSCRIPTION_DEBUG=true 启动。';

  @override
  String get subscriptionDebugInfo =>
      '此页面仅用于调试：优先读取本地 JSON，留空时读取程序缓存中的 JSON，不会修改缓存文件、不会覆盖订阅设置、不会影响正式播放流程。';

  @override
  String searchError(Object error) {
    return '搜索错误: $error';
  }

  @override
  String get searchLogs => '搜索日志';

  @override
  String get extractLogs => '提取日志';

  @override
  String get stepPending => '等待中';

  @override
  String get stepSearching => '搜索中';

  @override
  String get stepFetchingDetail => '获取详情页';

  @override
  String get stepFetchingEpisodes => '获取剧集';

  @override
  String get stepExtractingVideo => '提取播放页';

  @override
  String get stepSuccess => '成功';

  @override
  String get stepFailed => '失败';

  @override
  String get characterDetailsLoadFailed => 'Failed to load character details';

  @override
  String get personDetailsLoadFailed => 'Failed to load person details';

  @override
  String get retryButton => 'Retry';

  @override
  String get favoritesTabLocal => '本地收藏';

  @override
  String get favoritesTabBangumi => 'Bangumi 同步';

  @override
  String notFoundAnimeTag(Object tag) {
    return '没有找到「$tag」相关的动画';
  }

  @override
  String get addToLocalFavorites => '已添加到本地收藏';

  @override
  String get removeFromFavorites => '已取消收藏';

  @override
  String get playSourceTitle => '播放源';

  @override
  String get episodeListTitle => '选集';

  @override
  String get relatedRecommendationsTitle => '相关推荐';

  @override
  String get commentsTitle => '评论区';

  @override
  String get allComments => '全部评论';

  @override
  String get noComments => '暂无评论';

  @override
  String get noRelatedRecommendationsText => '暂无相关推荐';

  @override
  String commentsLoadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get initializingPlayback => '正在初始化播放...';

  @override
  String get playbackFailed => '播放失败';

  @override
  String get chooseSourceToWatch => '选择播放源开始观看';

  @override
  String get chooseSourceBelow => '在下方「播放源」中选择资源';

  @override
  String get defaultSort => '默认排序';

  @override
  String get sortByTime => '按时间排序';

  @override
  String get searchOnlineSource => '搜索在线源';

  @override
  String get searchBtSource => '搜索BT源';

  @override
  String get btSearching => '正在搜索BT源...';

  @override
  String btFound(Object count) {
    return '已找到 $count 个BT源';
  }

  @override
  String get btSearchFailed => 'BT搜索失败';

  @override
  String get btNotStarted => '尚未开始搜索BT源';

  @override
  String get btLoaded => '已使用本地资源播放';

  @override
  String get btManualSearchHint => '如需在线源，请点击下方按钮手动搜索';

  @override
  String get btSearchHint => '点击下方按钮开始搜索';

  @override
  String get waitingForPlayPage => '等待匹配播放页...';

  @override
  String get loadingText => '加载中';

  @override
  String get playText => '播放';

  @override
  String get copyMagnetSuccess => '磁力链接已复制';

  @override
  String get downloadStartedHint => '开始下载，可在「我的」页面查看进度';

  @override
  String get noDownloadableOnlineSource => '没有可下载的在线源';

  @override
  String get cannotGetPlaybackUrl => '无法获取播放地址';

  @override
  String get downloadTaskAdded => '已添加到下载任务';

  @override
  String get pauseFailed => '暂停失败';

  @override
  String get resumeFailed => '恢复失败';

  @override
  String get loadedDanmaku => '已加载弹幕';

  @override
  String get currentMatch => '当前匹配';

  @override
  String get searchResult => '搜索结果';

  @override
  String get episodeList => '剧集列表';

  @override
  String danmakuCount(Object count) {
    return '弹幕数量: $count 条';
  }

  @override
  String get danmakuSettingsDisplayTab => '显示设置';

  @override
  String get danmakuSettingsSourceTab => '弹幕源';

  @override
  String get danmakuSettingsVisibilitySection => '显示类型';

  @override
  String get danmakuSettingsStyleSection => '样式设置';

  @override
  String get danmakuSettingsEnable => '显示弹幕';

  @override
  String get danmakuSettingsScrolling => '滚动弹幕';

  @override
  String get danmakuSettingsTop => '顶部弹幕';

  @override
  String get danmakuSettingsBottom => '底部弹幕';

  @override
  String get danmakuSettingsOpacity => '不透明度';

  @override
  String get danmakuSettingsSpeed => '弹幕速度';

  @override
  String danmakuSettingsSpeedValue(Object seconds) {
    return '$seconds秒';
  }

  @override
  String get danmakuSettingsDisplayArea => '显示区域';

  @override
  String get danmakuSettingsFontWeight => '字体字重';

  @override
  String get danmakuSettingsFontWeightUltraLight => '极细';

  @override
  String get danmakuSettingsFontWeightExtraLight => '特细';

  @override
  String get danmakuSettingsFontWeightLight => '细';

  @override
  String get danmakuSettingsFontWeightSemiLight => '较细';

  @override
  String get danmakuSettingsFontWeightRegular => '正常';

  @override
  String get danmakuSettingsFontWeightSemiBold => '较粗';

  @override
  String get danmakuSettingsFontWeightBold => '粗';

  @override
  String get danmakuSettingsFontWeightExtraBold => '特粗';

  @override
  String get danmakuSettingsFontWeightBlack => '极粗';

  @override
  String get subtitlePreviewText => '字幕预览效果';

  @override
  String get noAvailablePlaybackSource => '暂无可用播放源';

  @override
  String get showSubtitles => '显示字幕';

  @override
  String get subtitleTracks => '字幕轨道';

  @override
  String get noEmbeddedSubtitles => '当前视频没有内嵌字幕';

  @override
  String get disableSubtitles => '关闭字幕';

  @override
  String get subtitleStyle => '字幕样式';

  @override
  String get fontSize => '字体大小';

  @override
  String get backgroundOpacity => '背景透明度';

  @override
  String get bottomPadding => '底部边距';

  @override
  String get outlineWidth => '描边宽度';

  @override
  String get fontColor => '字体颜色';

  @override
  String get subtitlePreview => '字幕预览效果';

  @override
  String get noAvailableSource => '暂无可用播放源';

  @override
  String get back => '返回';

  @override
  String get unlock => '解锁';

  @override
  String get lock => '锁定';

  @override
  String get danmaku => '弹幕';

  @override
  String get selectEpisode => '选集';

  @override
  String get skipBack85 => '空降-85s';

  @override
  String get skipForward85 => '空降+85s';

  @override
  String get autoPlayNext => '自动连播';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get normalSpeed => '正常速度';

  @override
  String get playbackSpeedTip => '提示：播放速度会同时影响视频与弹幕的时间同步。';

  @override
  String subtitleTrackCount(Object count) {
    return '共 $count 集';
  }

  @override
  String playWithSource(Object source) {
    return '播放 - $source';
  }

  @override
  String get selectedSourceUnknown => '未知';

  @override
  String get downloadDirTitle => '下载路径';

  @override
  String get downloadDirBrowse => '浏览';

  @override
  String get downloadDirPickerTitle => '选择下载目录';

  @override
  String get bangumiDetailsEpisodes => '剧集';

  @override
  String get bangumiDetailsStory => '简介';

  @override
  String get bangumiDetailsRelatedItems => '相关作品';

  @override
  String get bangumiDetailsTags => '标签';
}
