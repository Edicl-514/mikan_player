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
  String get historyDeleteTooltip => '删除历史记录';

  @override
  String get historySubtitle => '继续上次看的内容';

  @override
  String get favoritesTitle => '我的收藏';

  @override
  String get favoritesRemoveTooltip => '取消收藏';

  @override
  String get favoritesSubtitle => '已收藏的番剧';

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
  String get dataSourceSubtitle => '播放源订阅地址与订阅源开关';

  @override
  String get networkSettings => '网络设置';

  @override
  String get networkSettingsTitle => '网络设置';

  @override
  String get networkSettingsSubtitle => 'base URL、请求方式、反代、ECH 与 DoH';

  @override
  String get networkSectionBaseUrl => 'Base URL';

  @override
  String get networkSectionBangumiMode => 'Bangumi 请求方式';

  @override
  String get networkSectionAdvanced => '高级设置';

  @override
  String get networkBangumiRequestModeLegacy => '旧版';

  @override
  String get networkBangumiRequestModeHybrid => '混合（推荐）';

  @override
  String get networkBangumiRequestModeModern => '新版';

  @override
  String get networkBangumiOfflineBroadcastData => '离线放送数据';

  @override
  String get networkBangumiDataLoading => '加载中…';

  @override
  String get networkBangumiDataNotCached => '未缓存 · 点击下载离线兜底数据';

  @override
  String networkBangumiDataCachedSize(String size) {
    return '已缓存 $size';
  }

  @override
  String networkBangumiDataSyncTime(String time) {
    return '同步于 $time';
  }

  @override
  String networkBangumiDataVersion(String version) {
    return 'v$version';
  }

  @override
  String networkBangumiDataFailedMins(int minutes) {
    return '$minutes分钟前同步失败';
  }

  @override
  String networkBangumiDataFailedHours(int hours) {
    return '$hours小时前同步失败';
  }

  @override
  String get networkBangumiDataRefreshSuccess => '已更新离线放送数据';

  @override
  String get networkBangumiDataRefreshFailed => '更新失败，请检查网络';

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
  String get downloadEngineRqbitDescription =>
      'rqbit 基于 Rust 构建，内存占用低，启动快速，擅长边下边播（串流）场景，适合快速预览视频内容。';

  @override
  String get downloadEngineLibtorrentDescription =>
      'libtorrent 是成熟的 C++ BT 引擎，下载稳定高效，兼容性好，擅长完整下载和资源做种，适合长期保种场景。';

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
  String get clearCacheMessage =>
      '这将删除番剧缓存、全部图片缓存、WebView 网络缓存、Cookie 和网站存储。部分播放源之后可能需要重新验证。确定要继续吗？';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String cacheClearedFailed(Object error) {
    return '清除缓存失败: $error';
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
    return '条目: $subjects, 角色: $characters, 关联: $relations\n时间表: $timetables, 排行榜: $rankings\n应用图片: $imageSize，HTML 图片: $htmlImageSize\nWebView 缓存: $webViewCacheSize，网站数据: $webViewStorageSize\n可清理合计: $totalSize';
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
  String get useMaterial3Color => '使用 Material 颜色';

  @override
  String get useMaterial3ColorSubtitle => '开启时由系统计算色彩阶梯，关闭时严格使用选取的主色';

  @override
  String get pureBackground => '纯净背景';

  @override
  String get pureBackgroundSubtitle => '开启时背景应用纯灰阶颜色，不混入主题色';

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
  String get searchModeTooltip => '切换搜索模式';

  @override
  String get searchKeywordModeLabel => '关键词搜索';

  @override
  String get searchTagModeLabel => 'Tag 搜索';

  @override
  String get searchEnterTag => '输入标签进行搜索';

  @override
  String get searchEnterTagsMulti => '输入标签进行搜索，多个标签用空格分隔';

  @override
  String get searchSortTooltip => '切换排序方式';

  @override
  String get searchSortRank => '排名';

  @override
  String get searchSortMatch => '相关度';

  @override
  String get searchSortHeat => '收藏数';

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
  String get subscriptionSourceTag => '订阅';

  @override
  String get manualSourceTag => '手动';

  @override
  String get subscriptionSourceReadOnly => '订阅源不可编辑，仅可开关或通过订阅更新';

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
  String get indexDateRangeSelected => '区间';

  @override
  String get indexDateRangeUnset => '不限时间范围';

  @override
  String get indexTimeModePoint => '点选';

  @override
  String get indexTimeModeRange => '区间';

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
  String get dataSourceConfigAllowedChars => '允许字符';

  @override
  String get dataSourceConfigBasicInfo => '基本信息';

  @override
  String get dataSourceConfigCaptcha => '验证码';

  @override
  String get dataSourceConfigCaptchaSub => '可选。仅数据源存在验证码时需要配置';

  @override
  String get dataSourceConfigChannelNameRegex => '线路名称正则';

  @override
  String get dataSourceConfigChannelNameRegexHelper => '可用 (?<ch>...) 捕获最终名称';

  @override
  String get dataSourceConfigChannelNameSelector => '线路名称选择器';

  @override
  String get dataSourceConfigChannelNameSelectorHelper => '例如线路、字幕组、播放源 tab';

  @override
  String get dataSourceConfigCookie => 'Cookie';

  @override
  String get dataSourceConfigCookieHelper => '播放视频请求携带的 Cookie，可留空';

  @override
  String get dataSourceConfigDescription => '描述';

  @override
  String get dataSourceConfigDetectSelector => '验证码检测选择器';

  @override
  String get dataSourceConfigDistinguishChannelName => '区分线路名称';

  @override
  String get dataSourceConfigDistinguishChannelNameSub => '关闭后，不同线路中的同名剧集会被去重';

  @override
  String get dataSourceConfigDistinguishSubjectName => '区分条目名称';

  @override
  String get dataSourceConfigDistinguishSubjectNameSub => '关闭后，不同搜索结果中同名剧集会被去重';

  @override
  String dataSourceConfigEditing(String name) {
    return '配置: $name';
  }

  @override
  String get dataSourceConfigEnableCaptcha => '启用验证码处理';

  @override
  String get dataSourceConfigEnableCaptchaSub => '需要绕过详情页验证码时开启';

  @override
  String get dataSourceConfigEnableNestedUrl => '启用嵌套 URL 匹配';

  @override
  String get dataSourceConfigEnableNestedUrlSub => '先从播放器页找到内层播放页，再匹配视频地址';

  @override
  String get dataSourceConfigEpisodeLinkSelector => '列表内链接选择器';

  @override
  String get dataSourceConfigEpisodeLinkSelectorHelper => '留空时使用剧集元素自身 href';

  @override
  String get dataSourceConfigEpisodeListSelector => '剧集列表选择器';

  @override
  String get dataSourceConfigEpisodeSelector => '剧集选择器';

  @override
  String get dataSourceConfigEpisodesFromListSelector => '列表内剧集选择器';

  @override
  String get dataSourceConfigExpectedLength => '验证码长度';

  @override
  String get dataSourceConfigFilterAndPlayer => '过滤和播放器选择';

  @override
  String get dataSourceConfigFilterByEpisodeSort => '使用剧集序号过滤';

  @override
  String get dataSourceConfigFilterByEpisodeSortSub => '要求资源标题包含剧集序号，通常建议开启';

  @override
  String get dataSourceConfigFilterBySubjectName => '使用条目名称过滤';

  @override
  String get dataSourceConfigFilterBySubjectNameSub => '要求资源标题包含条目名称';

  @override
  String get dataSourceConfigFromListEpisodeLinkSelector => '剧集链接选择器';

  @override
  String get dataSourceConfigFromListEpisodeLinkSelectorHelper =>
      '留空时使用剧集元素自身 href';

  @override
  String get dataSourceConfigIconUrl => '图标链接';

  @override
  String get dataSourceConfigIconUrlHint => 'https://...';

  @override
  String get dataSourceConfigImageSelector => '验证码图片选择器';

  @override
  String get dataSourceConfigInputSelector => '输入框选择器';

  @override
  String get dataSourceConfigIntegerRequired => '请输入整数';

  @override
  String dataSourceConfigIntegerRange(int min, int max) {
    return '请输入范围为 $min 到 $max 的整数';
  }

  @override
  String get dataSourceConfigJsonPreviewSub => '用于核对保存内容';

  @override
  String get dataSourceConfigJsonPreviewTitle => '生成的 JSON';

  @override
  String get dataSourceConfigJsonSchemaCaptcha => 'captchaConfig';

  @override
  String get dataSourceConfigJsonSchemaSearch => 'searchConfig';

  @override
  String get dataSourceConfigJsonSchemaNotConfigured => '未配置';

  @override
  String get dataSourceConfigLinkJsonPath => '链接 JsonPath';

  @override
  String get dataSourceConfigMatchVideoUrl => '视频 URL 正则';

  @override
  String get dataSourceConfigMatchVideoUrlHelper => '可用 (?<v>...) 捕获最终播放地址';

  @override
  String get dataSourceConfigName => '名称';

  @override
  String get dataSourceConfigNameHelper => '显示在数据源列表中的名称';

  @override
  String get dataSourceConfigNameJsonPath => '名称 JsonPath';

  @override
  String get dataSourceConfigNestedUrlRegex => '嵌套 URL 正则';

  @override
  String get dataSourceConfigNew => '新建数据源';

  @override
  String get dataSourceConfigNotMarked => '不标记';

  @override
  String get dataSourceConfigPreferShorterName => '优先匹配较短名称';

  @override
  String get dataSourceConfigRefreshSelector => '刷新图片选择器';

  @override
  String get dataSourceConfigReferer => 'Referer';

  @override
  String get dataSourceConfigRefererHelper => '播放视频请求的 Referer';

  @override
  String get dataSourceConfigRequestInterval => '请求间隔 (毫秒)';

  @override
  String get dataSourceConfigRequestIntervalHelper => '每次请求后的等待时间';

  @override
  String get dataSourceConfigRequired => '必填';

  @override
  String get dataSourceConfigResolutionLabel => '标记分辨率';

  @override
  String get dataSourceConfigResolutionHelper => '用于播放器内偏好和过滤';

  @override
  String get dataSourceConfigSaved => '配置已保存';

  @override
  String dataSourceConfigSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get dataSourceConfigSearchUrl => '搜索链接';

  @override
  String dataSourceConfigSearchUrlHelper(String keyword) {
    return '$keyword 会替换为条目名称';
  }

  @override
  String dataSourceConfigSearchUrlHint(String keyword) {
    return 'https://example.com/search?wd=$keyword';
  }

  @override
  String get dataSourceConfigSortRegex => '剧集序号正则';

  @override
  String get dataSourceConfigSortRegexHelper => '建议使用 (?<ep>...) 捕获集数';

  @override
  String get dataSourceConfigStep1ParseResults => '步骤 1：解析搜索结果';

  @override
  String get dataSourceConfigStep1ParseResultsSub => '从搜索结果中提取条目名称和详情页链接';

  @override
  String get dataSourceConfigStep1Search => '步骤 1：搜索条目';

  @override
  String get dataSourceConfigStep1SearchSub => '配置搜索链接和搜索词处理规则';

  @override
  String get dataSourceConfigStep2Channels => '步骤 2：解析线路和剧集';

  @override
  String get dataSourceConfigStep2ChannelsSub => '从详情页提取线路、剧集和播放页链接';

  @override
  String get dataSourceConfigStep3MatchVideo => '步骤 3：匹配视频';

  @override
  String get dataSourceConfigStep3MatchVideoSub => '从播放页提取最终视频地址和请求头';

  @override
  String get dataSourceConfigSubjectFormatA => '单标签';

  @override
  String get dataSourceConfigSubjectFormatIndexed => '多标签';

  @override
  String get dataSourceConfigSubjectFormatJsonPath => 'JsonPath';

  @override
  String get dataSourceConfigChannelFormatIndexGrouped => '线路分组';

  @override
  String get dataSourceConfigChannelFormatNoChannel => '不区分线路';

  @override
  String get dataSourceConfigSubjectLinkSelector => '条目链接选择器';

  @override
  String get dataSourceConfigSubjectLinkSelectorHelper => '从搜索结果页选择条目详情链接';

  @override
  String get dataSourceConfigSubjectNameSelector => '条目名称选择器';

  @override
  String get dataSourceConfigSubjectRemoveSpecial => '去除特殊字符';

  @override
  String get dataSourceConfigSubjectRemoveSpecialSub => '清理符号和部分常见干扰词，提升搜索兼容性';

  @override
  String get dataSourceConfigSubjectUseFirstWord => '仅使用第一个词';

  @override
  String get dataSourceConfigSubjectUseFirstWordSub => '以空格分割条目名后只用第一个词搜索';

  @override
  String get dataSourceConfigSubjectUseNamesCount => '尝试条目名称数量';

  @override
  String get dataSourceConfigSubjectUseNamesCountHelper => '留空使用默认值。1 表示仅使用主名称';

  @override
  String get dataSourceConfigSubmitSelector => '提交按钮选择器';

  @override
  String get dataSourceConfigSubtitleLabel => '标记字幕语言';

  @override
  String get dataSourceConfigSubtitleHelper => '用于播放器内偏好和过滤';

  @override
  String get dataSourceConfigSuccessSelector => '成功页面选择器';

  @override
  String get dataSourceConfigTier => '优先级';

  @override
  String get dataSourceConfigTierHelper => '数字越小优先级越高';

  @override
  String get dataSourceConfigType => '类型';

  @override
  String get dataSourceConfigUseRawBaseUrl => 'Base URL';

  @override
  String get dataSourceConfigUseRawBaseUrlHelper =>
      '可选。用于拼接条目详情页链接，留空时通常从搜索链接推断';

  @override
  String get dataSourceConfigUserAgent => 'User-Agent';

  @override
  String get dataSourceConfigUserAgentHelper => '播放视频请求的 User-Agent';

  @override
  String get dataSourceConfigUseWebViewForCaptchaDetail => '详情页使用 WebView';

  @override
  String get dataSourceConfigCaptchaInitialDelay => '初始等待 (毫秒)';

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
  String get cancelLowPrioritySourcesTitle => '播放后取消低优先级源提取';

  @override
  String get cancelLowPrioritySourcesSubtitle =>
      '开始播放后取消Tier≥1的源的提取，保留Tier 0源以备切换';

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
  String get subscriptionDebugEntryTitle => '订阅调试（本地JSON）';

  @override
  String get subscriptionDebugEntrySubtitle => '手动测试订阅源搜索和可播放URL提取';

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
  String get characterDetailsLoadFailed => '角色详情加载失败';

  @override
  String get personDetailsLoadFailed => '人物详情加载失败';

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
  String get favoriteStatusUpdated => '收藏状态已更新';

  @override
  String favoriteUpdateFailed(Object error) {
    return '更新收藏失败: $error';
  }

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
  String get playerMoreOptions => '更多';

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
  String get bangumiDetailsRelatedSites => '关联站点';

  @override
  String get bangumiDetailsTags => '标签';

  @override
  String get bangumiReverseProxyTitle => '使用 Bangumi 反代镜像';

  @override
  String get bangumiReverseProxyDescription => '开启后将所有Bangumi请求路由到反代地址。';

  @override
  String get bangumiEchTitle => '使用 ECH 加密 SNI';

  @override
  String get bangumiEchDescription =>
      '通过 Encrypted Client Hello 加密真实域名，绕过 SNI 黑名单。中国大陆推荐。';

  @override
  String get bangumiEchRefreshTitle => '刷新 ECH 公钥';

  @override
  String get bangumiEchRefreshDescription =>
      '按优先级从 DoH 列表重新拉取 ECHConfig（缓存约 1 小时）';

  @override
  String bangumiEchRefreshSuccess(Object bytes) {
    return '已更新（$bytes 字节）';
  }

  @override
  String get bangumiEchRefreshFailed => '刷新失败，将回退到普通模式';

  @override
  String get bangumiEchDohListTitle => 'DoH 端点列表';

  @override
  String get bangumiEchDohListDescription =>
      '用于查询 Cloudflare 的 HTTPS RR 以获取 ECH 公钥。按顺序尝试，第一个可用的生效。点击「恢复默认」重置为内置列表。';

  @override
  String get bangumiEchDohListEmpty => '当前为空，使用内置默认 DoH';

  @override
  String get bangumiEchDohAddTitle => '添加 DoH 端点';

  @override
  String get bangumiEchDohAddHint => 'https://your-doh.example/dns-query';

  @override
  String get bangumiEchDohAddInvalid => '请输入以 https:// 开头的 URL';

  @override
  String get bangumiEchDohMoveUp => '上移';

  @override
  String get bangumiEchDohMoveDown => '下移';

  @override
  String get bangumiEchDohRemove => '移除';

  @override
  String get bangumiEchDohReset => '恢复默认';

  @override
  String get bangumiEchDohResetConfirm => '确定清空自定义 DoH 列表并使用内置默认值？';

  @override
  String get bangumiEchDohTestTitle => '测试该 DoH';

  @override
  String bangumiEchDohTestSuccess(Object bytes) {
    return '成功：获取到 $bytes 字节 ECHConfig';
  }

  @override
  String get bangumiEchDohTestFailed => '该 DoH 不可达或返回内容不含 ECHConfig';

  @override
  String bangumiEchDohPriority(Object index) {
    return '优先级 #$index';
  }

  @override
  String get manageUrls => '管理 URL';

  @override
  String get manageUrlsTitle => '管理可选 URL';

  @override
  String get addUrl => '添加';

  @override
  String get addUrlHint => 'https://...';

  @override
  String get builtinUrl => '内置';

  @override
  String get removeUrl => '移除';

  @override
  String get builtinUrlCannotRemove => '内置 URL 不可删除';

  @override
  String get urlAlreadyExists => '该 URL 已存在';

  @override
  String get invalidUrl => '请输入有效的 URL（以 http:// 或 https:// 开头）';

  @override
  String get bangumiBaseUrlHidden => '已启用 ECH 或反代，Bangumi Base URL 不生效';

  @override
  String get closeSettingsBarrier => '关闭设置';

  @override
  String get closeEpisodesBarrier => '关闭选集';

  @override
  String get statusEnabled => '已开启';

  @override
  String get statusDisabled => '已关闭';

  @override
  String get noSubtitlesAvailable => '暂无字幕';

  @override
  String get danmakuSettingsTitle => '弹幕设置';

  @override
  String get subtitleSettingsTitle => '字幕设置';

  @override
  String get commonPlaybackSpeeds => '常用倍速';

  @override
  String playbackSpeedWithNormal(String speed) {
    return '$speed (正常)';
  }

  @override
  String currentSourceOnly(String label) {
    return '当前：$label';
  }

  @override
  String currentSourceWithOnlineCount(String label, int count) {
    return '当前：$label ($count个在线源可切换)';
  }

  @override
  String sourceLabelWithAvailableCount(String label, int count) {
    return '$label ($count个可用)';
  }

  @override
  String get noAvailableSourcesShort => '暂无可用源';

  @override
  String get notPlaying => '未播放';

  @override
  String rewindSeconds(int seconds) {
    return '快退 ${seconds}s';
  }

  @override
  String forwardSeconds(int seconds) {
    return '快进 ${seconds}s';
  }

  @override
  String brightnessPercent(int percent) {
    return '亮度 $percent%';
  }

  @override
  String volumePercent(int percent) {
    return '音量 $percent%';
  }

  @override
  String get longPressFastForward => '长按快进 2x';

  @override
  String get bangumiDetailsTabDetails => '详情';

  @override
  String get bangumiDetailsTabComments => '评论';

  @override
  String get bangumiDetailsCharacters => '角色';

  @override
  String get bangumiDetailsComments => '评论';

  @override
  String get bangumiDetailsNoComments => '暂无评论';

  @override
  String get bangumiDetailsNoSummary => '暂无简介';

  @override
  String get bangumiDetailsFavorite => '收藏';

  @override
  String get bangumiDetailsFavorited => '已收藏';

  @override
  String bangumiDetailsCollectionStats(int wish, int doing, int dropped) {
    return '$wish 收藏 / $doing 在看 / $dropped 抛弃';
  }

  @override
  String bangumiDetailsRatingVotes(int count) {
    return '$count 人评';
  }

  @override
  String bangumiDetailsRatingVotesWithRank(int count, int rank) {
    return '$count 人评 | #$rank';
  }

  @override
  String bangumiDetailsVotes(int count) {
    return '$count 人评分';
  }

  @override
  String bangumiDetailsRanked(int rank) {
    return '排名 #$rank';
  }

  @override
  String get bangumiDetailsCollectWish => '收藏';

  @override
  String get bangumiDetailsCollectDoing => '在看';

  @override
  String get bangumiDetailsCollectDropped => '抛弃';

  @override
  String bangumiDetailsLoadingSection(String title) {
    return '正在加载$title...';
  }

  @override
  String get bangumiDetailsComingSoon => '（即将推出）';

  @override
  String get bangumiDetailsShowTranslation => '点击显示翻译';

  @override
  String get bangumiDetailsShowOriginal => '点击显示原文';

  @override
  String get bangumiDetailsCollapse => '收起';

  @override
  String get bangumiDetailsExpand => '展开';

  @override
  String get bangumiDetailsInformation => '资料';

  @override
  String bangumiDetailsMoreInfoItems(int count) {
    return '还有 $count 项，点击展开查看完整信息';
  }

  @override
  String bangumiDetailsYearMonth(int year, int month) {
    return '$year年 $month月';
  }

  @override
  String bangumiDetailsTotalEpisodes(int count) {
    return '全 $count 话';
  }

  @override
  String get bangumiDetailsZeroEpisodes => '0话';

  @override
  String get bangumiDetailsSiteOnair => '放送';

  @override
  String get bangumiDetailsSiteInfo => '资料';

  @override
  String get bangumiDetailsSiteResource => '资源';

  @override
  String get bangumiDetailsRoleMain => '主角';

  @override
  String get bangumiDetailsRoleSupporting => '配角';

  @override
  String get bangumiDetailsRoleMinor => '闲角';

  @override
  String get bangumiDetailsCvPrefix => 'CV: ';

  @override
  String detailsCommentsCount(int count) {
    return '$count 评论';
  }

  @override
  String detailsCollectsCount(int count) {
    return '$count 收藏';
  }

  @override
  String get detailsCommentsLabel => '评论';

  @override
  String get detailsCollectsLabel => '收藏';

  @override
  String get detailsSectionSummary => '简介';

  @override
  String get detailsSectionInfo => '资料';

  @override
  String get detailsSectionAppearances => '出演作品';

  @override
  String get detailsSectionRelatedWorks => '相关作品';

  @override
  String get detailsSectionVoiceRoles => '配音角色';

  @override
  String detailsWorksCount(int count) {
    return '$count 部作品';
  }

  @override
  String detailsCvName(String name) {
    return 'CV: $name';
  }

  @override
  String get detailsGenderMale => '男性';

  @override
  String get detailsGenderFemale => '女性';

  @override
  String detailsBirthdayYear(int year) {
    return '$year年';
  }

  @override
  String detailsBirthdayMonth(int month) {
    return '$month月';
  }

  @override
  String detailsBirthdayDay(int day) {
    return '$day日';
  }

  @override
  String get detailsBirthdaySeparator => '';

  @override
  String get personCareerSeiyu => '声优';

  @override
  String get personCareerProducer => '制作人';

  @override
  String get personCareerMangaka => '漫画家';

  @override
  String get personCareerArtist => '音乐人';

  @override
  String get personCareerWriter => '作者';

  @override
  String get personCareerIllustrator => '插画家';

  @override
  String get historyEmptyHint => '在播放页开始观看后会自动记录';

  @override
  String homeOriginalWork(String name) {
    return '原作: $name';
  }

  @override
  String homeDirector(String name) {
    return '导演: $name';
  }

  @override
  String homeEpisodeProgress(String sort, String name) {
    return 'EP $sort | $name';
  }

  @override
  String get favoritesStatusWish => '想看';

  @override
  String get favoritesStatusWatched => '看过';

  @override
  String get favoritesStatusWatching => '在看';

  @override
  String get favoritesStatusOnHold => '搁置';

  @override
  String get favoritesStatusDropped => '抛弃';

  @override
  String get favoritesStatusUnknown => '未知';

  @override
  String downloadEpisodeNumber(int number) {
    return '第$number集';
  }

  @override
  String get downloadDeleteRunningConfirm => '此任务正在运行中，确定要停止并删除吗？';

  @override
  String get searchSortDate => '日期';

  @override
  String get searchSortTitle => '名称';

  @override
  String timetableQuarterTitle(int year, int quarter) {
    return '$year年$quarter月';
  }

  @override
  String get indexFilterCategory => '分类';

  @override
  String get indexFilterSource => '来源';

  @override
  String get indexFilterType => '类型';

  @override
  String get indexFilterRegion => '地区';

  @override
  String get indexFilterSort => '排序';

  @override
  String get indexFilterTime => '时间';

  @override
  String get indexFilterMonth => '月份';

  @override
  String get indexUnlimited => '不限';

  @override
  String get indexSortRank => '排名';

  @override
  String get indexSortMatch => '相关度';

  @override
  String get indexSortHeat => '收藏数';

  @override
  String get indexSortTrends => '热度';

  @override
  String get indexSortCollect => '收藏';

  @override
  String get indexSortDate => '日期';

  @override
  String get indexSortTitle => '名称';

  @override
  String get indexCategoryMovie => '剧场版';

  @override
  String get indexCategoryOther => '其他';

  @override
  String get indexSourceOriginal => '原创';

  @override
  String get indexSourceManga => '漫画改';

  @override
  String get indexSourceGame => '游戏改';

  @override
  String get indexSourceNovel => '小说改';

  @override
  String get indexSourceLiveAction => '影视改';

  @override
  String indexMonthLabel(int month) {
    return '$month月';
  }

  @override
  String get indexRegionJapan => '日本';

  @override
  String get indexRegionWestern => '欧美';

  @override
  String get indexRegionChina => '中国';

  @override
  String get indexRegionUsa => '美国';

  @override
  String get indexRegionKorea => '韩国';

  @override
  String get indexRegionFrance => '法国';

  @override
  String get indexRegionHongKong => '中国香港';

  @override
  String get indexRegionUk => '英国';

  @override
  String get indexRegionRussia => '俄罗斯';

  @override
  String get indexRegionSoviet => '苏联';

  @override
  String get indexRegionCzech => '捷克';

  @override
  String get indexRegionTaiwan => '中国台湾';

  @override
  String get indexRegionMalaysia => '马来西亚';

  @override
  String get indexGenreScifi => '科幻';

  @override
  String get indexGenreComedy => '喜剧';

  @override
  String get indexGenreDoujin => '同人';

  @override
  String get indexGenreYuri => '百合';

  @override
  String get indexGenreSchool => '校园';

  @override
  String get indexGenreThriller => '惊悚';

  @override
  String get indexGenreHarem => '后宫';

  @override
  String get indexGenreMecha => '机战';

  @override
  String get indexGenreMystery => '悬疑';

  @override
  String get indexGenreRomance => '恋爱';

  @override
  String get indexGenreFantasy => '奇幻';

  @override
  String get indexGenreDetective => '推理';

  @override
  String get indexGenreSports => '运动';

  @override
  String get indexGenreBoysLove => '耽美';

  @override
  String get indexGenreMusic => '音乐';

  @override
  String get indexGenreAction => '战斗';

  @override
  String get indexGenreAdventure => '冒险';

  @override
  String get indexGenreMoe => '萌系';

  @override
  String get indexGenreIsekai => '穿越';

  @override
  String get indexGenreXuanhuan => '玄幻';

  @override
  String get indexGenreOtome => '乙女';

  @override
  String get indexGenreHorror => '恐怖';

  @override
  String get indexGenreHistory => '历史';

  @override
  String get indexGenreSliceOfLife => '日常';

  @override
  String get indexGenreDrama => '剧情';

  @override
  String get indexGenreWuxia => '武侠';

  @override
  String get indexGenreFood => '美食';

  @override
  String get indexGenreWorkplace => '职场';

  @override
  String get playerMobileEpisodeSelector => '选集';

  @override
  String get playerMobilePlaySource => '播放源';

  @override
  String get playerMobileOfficialPlaySource => '官方播放源';

  @override
  String get playerMobileRelated => '相关推荐';

  @override
  String get playerMobileSummaryAndRecommend => '简介 & 推荐';

  @override
  String playerMobileCommentsTab(int count) {
    return '评论 ($count)';
  }

  @override
  String playerMobilePlayableEpisodeCount(int count) {
    return '$count 集';
  }

  @override
  String get playerPcEpisodeList => '选集';

  @override
  String get playerPcPlaylist => '播放列表';

  @override
  String get playerPcCommentsSection => '评论区';

  @override
  String playerSourceTitleFound(int count, int online, String current) {
    return '已找到 $count 个BT源，$online 个订阅源，当前源：$current';
  }

  @override
  String playerSourceTitleCurrent(String label) {
    return '当前：$label';
  }

  @override
  String get playerSourceTitleFoundMobile => '已找到';

  @override
  String get playerSourceTabBt => 'BT';

  @override
  String get playerSourceTabSubscription => '订阅源';

  @override
  String get playerSourceLabelOnline => '在线源下载';

  @override
  String get playerSourceLabelBt => 'BT下载';

  @override
  String get playerSourceLabelOnlineShort => '在线源';

  @override
  String get playerNoDownloadableSource => '没有可下载的在线源';

  @override
  String get playerAddDownloadTaskFailed => '添加下载任务失败，请稍后重试';

  @override
  String get playerAddDownloadTaskSuccess => '已添加到下载任务';

  @override
  String get playerNoCopyableLink => '没有可复制的下载链接';

  @override
  String get playerDownloadLinkCopied => '下载链接已复制';

  @override
  String get playerDownloadButton => '下载';

  @override
  String get playerCopyDownloadLinkButton => '复制下载链接';

  @override
  String get playerCopyAction => '复制';

  @override
  String get playerPlayButton => '播放';

  @override
  String get playerLoadAction => '加载中';

  @override
  String get playerSampleStatusLocalManual => '已播放本地资源，在线源搜索待手动触发';

  @override
  String get playerSampleStatusAutoDisabled => '在线搜索已关闭，可手动搜索在线源';

  @override
  String get playerSampleStatusNotStarted => '尚未开始搜索在线源';

  @override
  String playerSampleStatusCompleted(int done, int total) {
    return '搜索完成 ($done/$total 个可用)';
  }

  @override
  String get playerSampleStatusFailed => '搜索失败';

  @override
  String get playerSampleSummaryLocalManual => '已使用本地资源播放';

  @override
  String get playerSampleSummaryAutoDisabled => '在线搜索已关闭';

  @override
  String get playerSampleHintLocalManual => '如需在线源，请点击下方按钮手动搜索';

  @override
  String get playerSampleHintAutoDisabled => '点击下方按钮手动搜索在线源';

  @override
  String get playerSampleHintNotStarted => '点击下方按钮开始搜索';

  @override
  String get playerSamplePlayButtonBase => '播放 - ';

  @override
  String playerSamplePlayButtonWithChannel(String source, String channel) {
    return '播放 - $source($channel)';
  }

  @override
  String playerSamplePlayButtonWithSource(String source) {
    return '播放 - $source';
  }

  @override
  String playerWebViewTaskCount(int active, int max) {
    return '并发WebView任务 ($active/$max)';
  }

  @override
  String playerWebViewTaskCountWithPool(int active, int max, String pool) {
    return '并发WebView任务 ($active/$max) · $pool';
  }

  @override
  String get playerWebViewShowDebug => '显示 WebView (调试)';

  @override
  String get playerWebViewWorkerPoolSwitch => '统一 Worker 调度 (Round 7)';

  @override
  String playerWebViewAvailableSources(int count) {
    return '可用源 ($count)';
  }

  @override
  String playerWebViewPerSourceStatus(String status) {
    return 'per-source [p|a|c]: $status';
  }

  @override
  String get playerSearchProgressStepPending => '等待中';

  @override
  String get playerSearchProgressStepSearching => '搜索中...';

  @override
  String get playerSearchProgressStepDetail => '获取详情页...';

  @override
  String get playerSearchProgressStepEpisodes => '获取剧集列表...';

  @override
  String get playerSearchProgressStepExtracting => '提取视频链接...';

  @override
  String get playerSearchProgressStepSuccess => '成功';

  @override
  String get playerSearchProgressStepFoundPlayPage => '找到播放页';

  @override
  String get playerSearchProgressStepFailed => '失败';

  @override
  String playerSearchSessionProgressLine(
    int completed,
    int enabled,
    int activeCaptcha,
    int pendingCaptcha,
  ) {
    return '搜索进度: $completed/$enabled，验证码 $activeCaptcha 运行/$pendingCaptcha 排队';
  }

  @override
  String get playerSearchSessionNotFound => '未在任何源中找到该动画';

  @override
  String get playerSearchSessionAllFailed => '所有源都无法提取视频链接';

  @override
  String playerSearchSessionDone(int count) {
    return '搜索完成，共找到 $count 个可用源';
  }

  @override
  String get playerSearchLocalPlayedHint => '已播放本地资源，可手动搜索在线源';

  @override
  String get playerSearchAutoDisabledHint => '在线搜索已关闭，可手动搜索在线源';

  @override
  String get playerSearchLocalPlayedActionHint => '已播放本地资源，点击刷新可手动搜索在线源';

  @override
  String get playerSearchFetchingSourceList => '正在获取播放源列表...';

  @override
  String get playerSearchNoEnabledSource => '未启用任何播放源';

  @override
  String playerSearchProgressSearchMany(int count) {
    return '正在搜索 $count 个源...';
  }

  @override
  String get playerSearchProgressCaptchaPreflight => '非验证码源先行搜索，验证码源并发预处理中...';

  @override
  String playerWebviewExtractInProgress(int completed, int total, int active) {
    return '提取中: $completed/$total 完成，$active 并发运行';
  }

  @override
  String get playerWebviewCaptchaBypass => '正在跳过验证码';

  @override
  String playerWebviewCaptchaBypassTitle(String label) {
    return '$label - 正在跳过验证码';
  }

  @override
  String get playerWebviewExtracting => '正在提取...';

  @override
  String playerWebviewSchedulerProgress(int completed, int total) {
    return '搜索进度: $completed/$total';
  }

  @override
  String playerWebviewCaptchaActive(int count) {
    return '验证码进行中 $count';
  }

  @override
  String playerWebviewExtractionActive(int active, int max) {
    return '提取并发 $active/$max';
  }

  @override
  String playerPageTitleWithEpisode(String title, int episode) {
    return '$title - 第$episode集';
  }

  @override
  String playerEpisodeNumber(int episode) {
    return '第$episode集';
  }

  @override
  String playerDownloadTaskName(String title, String episode, String source) {
    return '$title - $episode ($source)';
  }

  @override
  String get playerSidePanelPrequel => '前传';

  @override
  String get playerSidePanelSequel => '续集';

  @override
  String get playerSidePanelLoadFailed => '无法获取播放地址';

  @override
  String get playerSidePanelCopyMagnet => '磁力链接已复制';

  @override
  String get playerSidePanelDownloadHint => '开始下载，可在「我的」页面查看进度';

  @override
  String get playerRecommendationsEmpty => '暂无相关推荐';

  @override
  String get playerNoDescription => '暂无简介';

  @override
  String get playerCollapse => '收起';

  @override
  String get playerExpand => '展开';

  @override
  String get playerCommentsTitle => '全部评论';

  @override
  String get playerCommentsEmpty => '暂无评论';

  @override
  String playerCommentsLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String playerCommentsLoadFailedPc(String error) {
    return '加载失败: $error';
  }

  @override
  String get playerCommentsEmptyPc => '暂无评论';

  @override
  String get playerResourceListSearching => '正在搜索BT源...';

  @override
  String playerResourceListFound(int count) {
    return '已找到 $count 个BT源';
  }

  @override
  String get playerResourceListFailed => 'BT搜索失败';

  @override
  String get playerResourceListNotStarted => '尚未开始搜索BT源';

  @override
  String get playerResourceListStartSearch => '点击下方按钮开始搜索';

  @override
  String playerAutoplaySearchDone(int count) {
    return '搜索完成，共找到 $count 个可用源';
  }

  @override
  String get playerSourceControllerAnimeNotFound => '未找到番剧';

  @override
  String playerPlaybackOpenFailed(String error) {
    return '播放失败: $error';
  }

  @override
  String get playerPlaybackStartupTimeout => '当前线路启动超时，请切换其他源';

  @override
  String get playerSortDefault => '默认排序';

  @override
  String get playerSortByTime => '按时间排序';

  @override
  String get playerSubscriptionDebugSearchDirectProbe => '搜索直链 Probe';

  @override
  String get playerSubscriptionDebugProbeInProgress => 'Probe 中...';

  @override
  String get playerSubscriptionDebugProbeNotDone => '未 Probe';

  @override
  String get playerSubscriptionDebugPlayable => '可播放';

  @override
  String get playerSubscriptionDebugNotPlayable => '不可播放';

  @override
  String playerSubscriptionDebugCacheJsonMissing(String path) {
    return '缓存 JSON 不存在: $path';
  }

  @override
  String playerSubscriptionDebugFileMissing(String path) {
    return '文件不存在: $path';
  }

  @override
  String playerSubscriptionDebugStartSearch(
    String anime,
    String abs,
    String relative,
    String filter,
    String jsonSource,
  ) {
    return '开始调试搜索: anime=$anime, abs=$abs, rel=$relative, filter=$filter, json=$jsonSource';
  }

  @override
  String playerSubscriptionDebugSearchError(String error) {
    return '搜索异常: $error';
  }

  @override
  String get playerSubscriptionDebugSearchFinished => '搜索结束';

  @override
  String get playerSubscriptionDebugCaptchaPageClosed => '页面已关闭，无法完成验证码预处理';

  @override
  String get playerSubscriptionDebugCaptchaPreflightFailed => '验证码预处理失败';

  @override
  String playerSubscriptionDebugCaptchaPreflight(
    String name,
    int current,
    int total,
  ) {
    return '$name -> 正在进行验证码预处理 ($current/$total)';
  }

  @override
  String playerSubscriptionDebugCaptchaParseFailed(String error) {
    return '解析captcha源失败: $error';
  }

  @override
  String playerSubscriptionDebugExtractStart(String name) {
    return '开始提取: $name';
  }

  @override
  String get playerSubscriptionDebugStartSearchButton => '开始调试搜索';

  @override
  String get playerSubscriptionDebugManualProbe => '手动 Probe';

  @override
  String get playerSubscriptionDebugProbeActive => 'Probe 中';

  @override
  String playerSubscriptionDebugDirectLink(String url) {
    return '直链: $url';
  }

  @override
  String playerSubscriptionDebugSourceName(String name) {
    return '来源: $name';
  }

  @override
  String playerSubscriptionDebugHeaders(String headers) {
    return 'Headers: $headers';
  }

  @override
  String playerSubscriptionDebugExtractSuccess(String url) {
    return '提取成功: $url';
  }

  @override
  String get playerSubscriptionDebugExtractFailedShort => '提取失败';

  @override
  String playerSubscriptionDebugExtractFailedDetail(String error) {
    return '提取失败: $error';
  }

  @override
  String get playerSubscriptionDebugPostProbe => '提取后 Probe';

  @override
  String get playerSubscriptionDebugJsonCache => '缓存';

  @override
  String get playerSubscriptionDebugJsonLocal => '本地';

  @override
  String get playerSubscriptionDebugJsonPathHint => 'D:\\temp\\online.json，或留空';
}
