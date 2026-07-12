import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/services/video_url_probe.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/services/header_injection_proxy.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/reusable_browser_worker.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/ui/widgets/video_player_controls.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/utils/source_channel_key.dart';
import 'package:mikan_player/ui/widgets/bangumi_site_launcher.dart';
import 'package:mikan_player/ui/widgets/site_icon_map.dart';

import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/player/player_source_helpers.dart';
import 'package:mikan_player/ui/pages/player/player_episode_controller.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_recommendations.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_resource_list.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_pump_decisions.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_state_transitions.dart';

class _CaptchaPreflightTask {
  final String taskKey;
  final String label;
  final SourceState source;
  final String? searchKeyword;
  final String? initialUrl;
  final String? referer;
  final String? initialCookies;
  final CaptchaConfig captchaConfig;
  final int loadToken;
  final void Function(_CaptchaPreflightTask task, CaptchaBypassResult result)
  onResult;

  const _CaptchaPreflightTask({
    required this.taskKey,
    required this.label,
    required this.source,
    this.searchKeyword,
    this.initialUrl,
    this.referer,
    this.initialCookies,
    required this.captchaConfig,
    required this.loadToken,
    required this.onResult,
  });
}

class PlayerPage extends StatefulWidget {
  static int get kDefaultMaxConcurrentWebViews => Platform.isAndroid ? 2 : 3;

  final AnimeInfo anime;
  final BangumiEpisode currentEpisode;
  final List<BangumiEpisode> allEpisodes;
  final int? startPositionMs; // optional start position in milliseconds
  final String? btStreamUrl; // optional BT stream URL to play directly

  const PlayerPage({
    super.key,
    required this.anime,
    required this.currentEpisode,
    required this.allEpisodes,
    this.startPositionMs,
    this.btStreamUrl,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late TabController _mobileTabController;
  late ScrollController _pcEpisodeScrollController;
  late ScrollController _mobileEpisodeScrollController;
  final ScrollController _mobileInfoScrollController =
      createPlatformScrollController();
  final ScrollController _pcMainScrollController =
      createPlatformScrollController();
  final ScrollController _pcSidebarScrollController =
      createPlatformScrollController();
  final ScrollController _commentsScrollController =
      createPlatformScrollController();
  bool _isDescriptionExpanded = false;
  bool _isEpisodesExpanded = false;

  List<BangumiEpisodeComment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;
  String _commentSortMode = 'default'; // 'default' or 'time'

  List<RankingAnime> _recommendations = [];
  bool _isLoadingRecommendations = false;

  List<BangumiDataSiteEntry> _onairSites = [];

  // Mikan Source
  bool _isLoadingMikan = false;
  String? _mikanError;
  MikanSearchResult? _mikanAnime;
  List<MikanEpisodeResource> _mikanResources = [];

  // DMHY Source
  bool _isLoadingDmhy = false;
  String? _dmhyError;
  List<DmhyResource> _dmhyResources = [];

  // Sample Source
  bool _isLoadingSample = false;
  String? _sampleError;
  String? _sampleVideoUrl;
  List<SearchPlayResult> _samplePlayPages = [];
  List<SearchPlayResult> _sampleSuccessfulSources = []; // 成功获取到视频URL的源列表
  int _selectedSourceIndex = 0; // 当前选中的源索引
  // 并发WebView管理
  final Map<String, bool> _activeWebViews =
      {}; // 正在运行的WebView (sourceName -> isActive)
  final Map<String, String> _webViewStatus =
      {}; // WebView状态消息 (sourceName -> message)
  final Set<String> _failedWebViewPageKeys = {}; // 提取失败的WebView Key
  final Set<String> _resolvingChannelPlayPageKeys = {}; // 正在解析的频道播放页
  final Queue<_CaptchaPreflightTask> _pendingCaptchaTasks =
      Queue<_CaptchaPreflightTask>();
  final Map<String, _CaptchaPreflightTask> _activeCaptchaTasks =
      <String, _CaptchaPreflightTask>{};
  final List<StreamSubscription<SourceSearchProgress>> _searchSubscriptions =
      <StreamSubscription<SourceSearchProgress>>[];
  int _maxConcurrentWebViews = PlayerPage.kDefaultMaxConcurrentWebViews;
  bool _cancelLowPrioritySourcesOnPlay = true;
  int _webViewLaunchInterval = 200;
  int _sampleLoadToken = 0;
  bool _showWebView = false; // 是否显示 WebView（调试用）

  // ── Phase 2 B6：统一的长期 WebView worker 调度状态对象 ──
  //
  // 原 5 个 page-owned 字段（`_pumpCoordinator`、`_webViewWorkerSlots`、
  // `_activeVideoJobs`、`_activeCaptchaJobs`、`_nextWebViewWorkerId`）
  // 已折叠为本 [`_scheduler`] 实例，其统一 slot 池 + 双向反查表 + 单调
  // workerId 命名空间 + pump/dedup 协调器全归该对象管理。完整 doc
  // comments 与公开 API 详见
  // `lib/ui/pages/player/player_webview_scheduler.dart`；本页只持有调度
  // 状态、读只读视图、把所有 mutation 路由到 scheduler 方法。
  final PlayerWebViewScheduler _scheduler = PlayerWebViewScheduler();

  // 集数 / 当前集 状态对象。Phase 2 责任拆分：本页原先散落的「当前集」、「可播
  // 集列表」、「当前集 ValueNotifier」三处状态全归该对象管理。本页只读只读视图、
  // 把所有 mutation 路由到 controller 方法（`selectEpisode` / `resolveByOffset`
  // / `reset`），side-effect fan-out（player stop / source reload / danmaku /
  // history / setState）仍留在本页。完整 doc comments 详见
  // `lib/ui/pages/player/player_episode_controller.dart`。
  late final PlayerEpisodeController _episodeController;

  /// Round 4 Stage 3：pageKey → 入队序号。`_samplePlayPages` 每次新增播放页
  /// 后都会按 tier 重新 `sort()`，原始 `List` 下标不再稳定反映 arrival 顺序。
  /// 这里在每次 `_samplePlayPages.add` 时分配一个单调递增的序号，供
  /// source-affinity 调度在 tier 相同时做“进入 pending 更早优先”的稳定 tie
  /// break。新搜索开始时随 `_samplePlayPages` 清空一并 reset。
  final Map<String, int> _pageEnqueueSeq = {};
  int _nextPageEnqueueSeq = 0;

  /// Round 3 feature flag。默认 true（worker pool 模式）。
  /// 调试面板提供 live toggle；fallback 路径用旧 per-task widget 一次模型，
  /// 行为完全等价于 Round 2 之前。
  bool _useWorkerPool = true;

  /// Phase 0 调试计数：WebView widget 创建/销毁、视频/验证码 job 生命周期。
  /// 仅统计与日志，绝不参与调度。每次新搜索开始时 `reset()`，
  /// 供后续 worker pool 重构对比基线指标。
  final WebViewSchedulerStats _webviewStats = WebViewSchedulerStats();
  // 一旦某 Tier-0 源被接受并开始播放，记录其 pageKey。用于在其后取消其他低优先级
  // 提取任务，并在它们的迟到 onResult 回调里跳过 probe/autoplay，避免劫持播放。
  // 在新搜索/新剧集开始时重置为 null（与 _hasAutoPlayed 同步）。
  String? _acceptedSourcePageKey;

  // Auto Play Logic
  bool _hasAutoPlayed = false;
  bool _isAutoPlayNextEnabled = true;
  bool _autoSearchOnline = true;
  bool _disableAutoSourceSearchForCurrentEpisode = false;
  bool _autoPlaySearchedSource = true;
  double _playbackSpeed = 1.0;

  // 每个源的搜索进度状态
  Map<String, SourceSearchProgress> _sourceProgressMap = {};
  Map<String, SourceRuntimeOverride> _captchaRuntimeOverrides = {};
  List<String> _enabledSourceNames = []; // 所有已启用的源名称

  // Active Source
  String _activeSource = 'bt'; // 'bt' or 'sample'
  bool _isSourceControlExpanded = false;

  // Video Player
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerInitialized = false;
  final ValueNotifier<bool> _mobilePlayerLockNotifier = ValueNotifier(false);
  late final ValueNotifier<String> _videoTitleNotifier;
  final ValueNotifier<List<SearchPlayResult>> _availableSourcesNotifier =
      ValueNotifier(const <SearchPlayResult>[]);
  final ValueNotifier<String> _playingSourceLabelNotifier = ValueNotifier(
    '未播放',
  );
  bool _isLoadingVideo =
      false; // Keep for general UI loading (like initial search or player overlay)
  String? _loadingMagnet; // Track which specific magnet is being loaded
  String? _currentStreamUrl;
  String? _videoError;
  String _playingSourceLabel = '未播放';
  final DownloadManager _downloadManager = DownloadManager();

  // Current online source for downloading
  SearchPlayResult? _currentOnlineSource;

  // Danmaku
  final DanmakuService _danmakuService = DanmakuService();
  final ValueNotifier<double> _currentVideoTimeNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _isVideoPausedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showDanmakuSettingsNotifier = ValueNotifier(false);
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _completedSubscription;

  // Subtitle
  final SubtitleService _subtitleService = SubtitleService();

  // Playback History
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  int? _pendingStartPositionMs;
  int _lastSavedPositionMs = 0;
  static const int _saveIntervalMs = 5000;
  static const Duration _manualSeekGracePeriod = Duration(seconds: 3);
  static const Duration _positionResetGracePeriod = Duration(seconds: 4);
  static const Duration _unexpectedJumpMinimum = Duration(seconds: 30);
  static const Duration _unexpectedJumpRecoveryOffset = Duration(seconds: 5);
  static const Duration _unexpectedJumpSourceMinimum = Duration(seconds: 60);
  static const Duration _manualBackwardSeekMinimum = Duration(seconds: 10);

  /// 进入播放页后给首帧 / 转场动画留出的保护延时，避免页面刚加载时
  /// 在线源搜索 / WebView 启动 / 弹幕加载等重操作与动画争抢主线程。
  static const Duration _entryAnimationGuard = Duration(milliseconds: 350);
  Duration _furthestObservedPosition = Duration.zero;
  DateTime? _lastUserInteractionAt;
  DateTime? _allowPositionResetUntil;
  bool _isRecoveringUnexpectedJump = false;

  // Header Injection Proxy
  final HeaderInjectionProxy _headerProxy = HeaderInjectionProxy();
  final VideoUrlProbeService _videoUrlProbeService = VideoUrlProbeService();
  final ValueNotifier<String> _sampleStatusMessageNotifier = ValueNotifier('');
  final Set<String> _playableSourceKeys = <String>{};
  final Set<String> _probingSourceKeys = <String>{};
  final Set<String> _failedPlaybackSourceKeys = <String>{};
  static const Duration _autoPlayStartupTimeout = Duration(seconds: 10);
  Timer? _playStartupTimer;
  String? _pendingPlaySourceKey;
  bool _isAutoPlayFallbackInProgress = false;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _pcEpisodeScrollController = createPlatformScrollController();
    _mobileEpisodeScrollController = ScrollController();

    _episodeController = PlayerEpisodeController(
      allEpisodes: widget.allEpisodes,
      initialEpisode: widget.currentEpisode,
    );
    _videoTitleNotifier = ValueNotifier(
      '${widget.anime.title} - 第${_episodeController.currentEpisode.sort.toInt()}集',
    );
    _playingSourceLabelNotifier.value = _playingSourceLabel;

    _pendingStartPositionMs = widget.startPositionMs;

    _savePlaybackHistory();

    // Initialize video player
    _player = Player();
    _videoController = VideoController(_player);
    _isPlayerInitialized = true;

    // Bind subtitle service to player
    _subtitleService.bindPlayer(_player);

    // Start header injection proxy
    _headerProxy.start();

    // Subscribe to player position for danmaku sync
    _positionSubscription = _player.stream.position.listen((position) {
      if (mounted) {
        if (position > Duration.zero) {
          _clearPlaybackStartupWatchdog();
        }
        _handleUnexpectedPositionJump(position);
        _currentVideoTimeNotifier.value = position.inMilliseconds / 1000.0;

        try {
          final posMs = position.inMilliseconds;
          if ((posMs - _lastSavedPositionMs).abs() >= _saveIntervalMs) {
            _lastSavedPositionMs = posMs;
            _historyManager.addOrUpdate(
              anime: widget.anime,
              currentEpisode: _episodeController.currentEpisode,
              allEpisodes: widget.allEpisodes,
              lastPositionMs: posMs,
            );
          }
        } catch (e) {
          debugPrint('Error saving playback position: $e');
        }
      }
    });

    // Subscribe to playing state for danmaku pause
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (mounted) {
        _isVideoPausedNotifier.value = !playing;
        if (playing) {
          _clearPlaybackStartupWatchdog();
        }
        // Save position when paused
        if (!playing) {
          try {
            final posMs = (_currentVideoTimeNotifier.value * 1000).toInt();
            _historyManager.addOrUpdate(
              anime: widget.anime,
              currentEpisode: _episodeController.currentEpisode,
              allEpisodes: widget.allEpisodes,
              lastPositionMs: posMs,
            );
            _lastSavedPositionMs = posMs;
          } catch (e) {
            debugPrint('Error saving position on pause: $e');
          }
        }
      }
    });

    // Subscribe to player completion for auto-play next
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed && _isAutoPlayNextEnabled && mounted) {
        // Guard against spurious completion (e.g. BT stream hiccups).
        final duration = _player.state.duration;
        final position = _player.state.position;
        if (duration > const Duration(seconds: 10) &&
            position < duration * 0.9) {
          debugPrint(
            '[Player] Ignored premature completion at '
            '${position.inSeconds}s / ${duration.inSeconds}s',
          );
          return;
        }
        debugPrint('[Player] Video completed, auto-playing next episode...');
        _onSkipNext();
      }
    });

    _scheduleDeferredEntryWork();
  }

  /// 把进入播放页时启动的"重活"（评论 / 推荐 / 番剧 onair / 弹幕 / 在线源
  /// 搜索等）统一延后到首帧 + 转场动画结束之后再触发，避免页面刚加载时
  /// 多个网络请求 / WebView 启动 / 弹幕解析同时争抢主线程导致首屏卡一下。
  void _scheduleDeferredEntryWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(_entryAnimationGuard);
      if (!mounted) return;
      unawaited(_loadComments());
      unawaited(_loadRecommendations());
      unawaited(_loadOnairSites());
      unawaited(_loadDanmaku());
      unawaited(_initializePlaybackAndSourceLoading());
    });
  }

  Future<void> _initializePlaybackAndSourceLoading() async {
    var hasDownloadedPlayback = false;

    // Check if we have a direct BT stream URL to play
    if (widget.btStreamUrl != null) {
      _playBtStreamUrl(widget.btStreamUrl!);
      hasDownloadedPlayback = true;
    } else {
      // Check for existing BT download for this episode
      hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    await _loadSettings(autoLoadSample: !hasDownloadedPlayback);

    if (!mounted || hasDownloadedPlayback) {
      return;
    }

    _loadMikanSource();
    _loadDmhySource();
  }

  /// Check existing downloads for this episode and auto-play with BT priority.
  Future<bool> _checkAndPlayExistingBtDownload() async {
    // Check BT first
    final btTask = _downloadManager.getAvailableBtTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );

    if (btTask != null) {
      final streamUrl = await _downloadManager.getOrCreateStreamUrl(btTask.id);
      if (!mounted || streamUrl == null) {
        return false;
      }
      debugPrint(
        '[Player] Found existing BT download for this episode: ${btTask.name}',
      );
      _playBtStreamUrl(streamUrl);
      return true;
    }

    // Check completed HTTP download
    final httpTask = _downloadManager.getCompletedHttpTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );
    if (httpTask != null && httpTask.localFilePath != null) {
      final filePath = httpTask.localFilePath!;
      final file = File(filePath);
      if (await file.exists()) {
        if (!mounted) return false;
        debugPrint(
          '[Player] Found existing HTTP download for this episode: ${httpTask.name}',
        );
        setState(() {
          _currentStreamUrl = filePath;
          _sampleVideoUrl = filePath;
          _hasAutoPlayed = true;
          _playingSourceLabel = '在线源下载';
          _isLoadingVideo = false;
          _videoError = null;
        });
        _publishPlayerControlSourceState();
        _temporarilyAllowPositionReset();
        _player.open(Media(filePath), play: true).then((_) async {
          await _applyPlaybackSpeed();
          await _applyPendingStartPosition();
        });
        return true;
      }
    }

    return false;
  }

  /// Play a BT stream URL directly
  void _playBtStreamUrl(String streamUrl) {
    setState(() {
      _currentStreamUrl = streamUrl;
      _sampleVideoUrl = streamUrl; // Prevent online sources from auto-playing
      _currentOnlineSource = null;
      _hasAutoPlayed = true; // Mark as already auto-played
      _playingSourceLabel = 'BT下载';
      _isLoadingVideo = false;
      _videoError = null;
    });
    _publishPlayerControlSourceState();

    // 通知下载管理器BT流现在活跃（防止libtorrent流被移除）
    final btHash = _extractBtHashFromStreamUrl(streamUrl);
    if (btHash != null) {
      DownloadManager().setActiveStream(btHash);
      debugPrint(
        '[Player] Notified DownloadManager: stream active for $btHash',
      );
    }

    debugPrint('[Player] Playing BT stream: $streamUrl');
    _temporarilyAllowPositionReset();
    _player.open(Media(streamUrl), play: true).then((_) async {
      await _applyPlaybackSpeed();
      await _applyPendingStartPosition();
    });
  }

  /// 从BT流URL中提取info hash
  String? _extractBtHashFromStreamUrl(String streamUrl) {
    // libtorrent: http://127.0.0.1:PORT/stream/HASH/INDEX
    // rqbit: http://127.0.0.1:3000/torrents/HASH/stream/INDEX
    final ltRegex = RegExp(r'/streams?/([a-fA-F0-9]+)/');
    final rqbitRegex = RegExp(r'/torrents/([a-fA-F0-9]+)/');

    for (final regex in [ltRegex, rqbitRegex]) {
      final match = regex.firstMatch(streamUrl);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Download the currently playing online source
  Future<void> _onDownloadCurrentSource() async {
    final source = _currentOnlineSource;
    if (source == null || source.directVideoUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可下载的在线源')));
      }
      return;
    }

    // Merge headers and cookies
    final headers = <String, String>{
      if (source.headers != null) ...source.headers!,
    };

    final episodeName = _episodeController.currentEpisode.nameCn.isNotEmpty
        ? _episodeController.currentEpisode.nameCn
        : _episodeController.currentEpisode.name;
    final downloadName =
        '${widget.anime.title} - ${episodeName.isNotEmpty ? episodeName : '第${_episodeController.currentEpisode.sort.toInt()}集'} (${source.sourceName})';

    try {
      await _downloadManager.startHttpDownload(
        url: source.directVideoUrl!,
        name: downloadName,
        headers: headers.isNotEmpty ? headers : null,
        cookies: source.cookies,
        animeName: widget.anime.title,
        episodeNumber: _episodeController.currentEpisode.sort.toInt(),
      );
    } catch (e) {
      debugPrint('[Download] Failed to add current online source: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加下载任务失败，请稍后重试')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加到下载任务')));
    }
  }

  void _onCopyCurrentSourceUrl() {
    final url = _currentOnlineSource?.directVideoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可复制的下载链接')));
      }
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
    }
  }

  Widget _buildCurrentSourceActionButtons({bool compact = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canAct =
        _currentOnlineSource != null &&
        _currentOnlineSource!.directVideoUrl != null;
    final iconColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHigh;
    final border = isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.3);
    final fontSize = compact ? 12.0 : 13.0;
    final iconSize = compact ? 14.0 : 16.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) {
      return Opacity(
        opacity: canAct ? 1.0 : 0.4,
        child: InkWell(
          onTap: canAct ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(icon: Icons.download, label: "下载", onTap: _onDownloadCurrentSource),
        const SizedBox(width: 8),
        btn(icon: Icons.link, label: "复制下载链接", onTap: _onCopyCurrentSourceUrl),
      ],
    );
  }

  Future<void> _applyPendingStartPosition() async {
    if (_pendingStartPositionMs != null) {
      final targetPosition = _pendingStartPositionMs!;
      _pendingStartPositionMs = null;

      try {
        // Wait for media to be ready (duration > 0)
        await for (final duration in _player.stream.duration) {
          if (duration.inMilliseconds > 0) {
            // Media is ready, now seek
            _temporarilyAllowPositionReset();
            await _player.seek(Duration(milliseconds: targetPosition));
            debugPrint('[Seek] Applied start position: ${targetPosition}ms');
            break;
          }
        }
      } catch (e) {
        debugPrint('Error applying start position: $e');
      }
    }
  }

  Future<void> _loadSettings({bool autoLoadSample = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlaybackSpeed = (prefs.getDouble('playback_speed') ?? 1.0)
          .clamp(0.25, 3.0)
          .toDouble();
      if (mounted) {
        setState(() {
          _isAutoPlayNextEnabled = prefs.getBool('auto_play_next') ?? true;
          _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
          _maxConcurrentWebViews =
              prefs.getInt('max_concurrent_webviews') ??
              PlayerPage.kDefaultMaxConcurrentWebViews;
          _trimIdleWebViewWorkerSlotsToBudget();
          _cancelLowPrioritySourcesOnPlay =
              prefs.getBool('cancel_low_priority_sources_on_play') ?? true;
          _webViewLaunchInterval =
              prefs.getInt('webview_launch_interval') ?? 200;
          _playbackSpeed = savedPlaybackSpeed;
        });
      }
      await _applyPlaybackSpeed();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    // Load sample source after settings to respect _autoSearchOnline
    if (mounted && autoLoadSample) {
      _loadSampleSource();
    }
  }

  Future<void> _saveAutoPlaySetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_next', value);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _savePlaybackSpeedSetting(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('playback_speed', value);
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _applyPlaybackSpeed() async {
    try {
      await _player.setRate(_playbackSpeed);
    } catch (e) {
      debugPrint('Error applying playback speed: $e');
    }
  }

  void _onPlaybackSpeedChanged(double value) {
    final clampedSpeed = value.clamp(0.25, 3.0).toDouble();
    setState(() {
      _playbackSpeed = clampedSpeed;
    });
    unawaited(_applyPlaybackSpeed());
    unawaited(_savePlaybackSpeedSetting(clampedSpeed));
  }

  // Load danmaku based on anime title and episode
  Future<void> _loadDanmaku() async {
    final animeTitle = widget.anime.title;
    final n = _episodeController.currentEpisodeNumbersAgainst(
      widget.allEpisodes,
    );
    final episodeNumber = n.absolute;
    final relativeEpNumber = n.relative;

    debugPrint(
      '[Danmaku] Loading danmaku for: $animeTitle EP$episodeNumber (rel: $relativeEpNumber)',
    );

    // Prefer Bangumi TV subject_id if available for more accurate matching
    if (widget.anime.bangumiId != null && widget.anime.bangumiId!.isNotEmpty) {
      final subjectId = int.tryParse(widget.anime.bangumiId!);
      if (subjectId != null) {
        debugPrint('[Danmaku] Using Bangumi TV subject_id: $subjectId');
        await _danmakuService.loadDanmakuByBangumiId(
          subjectId,
          episodeNumber.toString(),
          relativeEpisode: relativeEpNumber,
          animeTitle: animeTitle, // 传入动漫名称用于失败重试
        );
        return;
      }
    }

    // Fallback to title-based search
    debugPrint('[Danmaku] Using title-based search');
    await _danmakuService.loadDanmakuByTitle(
      animeTitle,
      episodeNumber.toString(),
      relativeEpisode: relativeEpNumber,
    );
  }

  Future<void> _loadComments() async {
    if (_episodeController.currentEpisode.id == 0) return;

    setState(() {
      _isLoadingComments = true;
      _commentsError = null;
    });

    try {
      final comments = await fetchBangumiEpisodeComments(
        episodeId: _episodeController.currentEpisode.id,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _sortComments();
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading comments: $e");
      if (mounted) {
        setState(() {
          _commentsError = e.toString();
          _isLoadingComments = false;
        });
      }
    }
  }

  void _sortComments() {
    if (_commentSortMode == 'default') {
      _comments.sort((a, b) => a.id.compareTo(b.id));
    } else {
      _comments.sort((a, b) => b.time.compareTo(a.time));
    }
  }

  Future<void> _loadOnairSites() async {
    try {
      final bangumiId = widget.anime.bangumiId;
      final mikanId = widget.anime.mikanId;
      List<BangumiDataSiteEntry> sites = [];
      if (bangumiId != null && bangumiId.isNotEmpty) {
        sites = await BangumiDataService.getSites(bangumiId);
      }
      if (sites.isEmpty && mikanId != null && mikanId.isNotEmpty) {
        sites = await BangumiDataService.getSitesByMikan(mikanId);
      }
      final onair = sites.where((s) => s.kind == 'onair').toList();
      if (mounted && onair.isNotEmpty) {
        setState(() {
          _onairSites = onair;
        });
      }
    } catch (e) {
      debugPrint('Failed to load onair sites: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final List<RankingAnime> results = [];
      final Set<String> addedIds = {};
      final isLegacyMode =
          BangumiRequestModeService.notifier.value == BangumiRequestMode.legacy;
      debugPrint(
        '[Recommendations] Start loading for '
        '${widget.anime.bangumiId ?? "unknown"} / ${widget.anime.title}, '
        'mode=${BangumiRequestModeService.notifier.value.value}, '
        'tagSort=${isLegacyMode ? "collects" : "trends"}',
      );

      // 0. Add current anime ID to exclude list
      if (widget.anime.bangumiId != null) {
        addedIds.add(widget.anime.bangumiId!);
      }

      // 1. Fetch Relations (Sequel/Prequel)
      if (widget.anime.bangumiId != null) {
        final id = int.tryParse(widget.anime.bangumiId!);
        if (id != null) {
          try {
            final relations = await fetchBangumiRelations(subjectId: id);

            // Prioritize Prequel/Sequel
            final pres = relations
                .where((r) => r.relation == '前传' || r.relation == '续集')
                .toList();
            final others = relations
                .where((r) => r.relation != '前传' && r.relation != '续集')
                .toList();
            debugPrint(
              '[Recommendations] Relations fetched for $id: total=${relations.length}, '
              'priority=${pres.length}, others=${others.length}',
            );

            for (var r in [...pres, ...others]) {
              final bid = r.id.toString();
              if (addedIds.contains(bid)) continue;

              results.add(
                RankingAnime(
                  title: r.nameCn.isNotEmpty ? r.nameCn : r.name,
                  bangumiId: bid,
                  coverUrl: r.image,
                  info: r.relation,
                  rank: null,
                  score: null,
                  originalTitle: null,
                ),
              );
              addedIds.add(bid);
            }
          } catch (e) {
            debugPrint("[Recommendations] Error fetching relations: $e");
          }
        }
      }

      // 2. Tag-based Search
      final validTags = await _resolveRecommendationTags();
      debugPrint(
        '[Recommendations] Resolved tags for '
        '${widget.anime.bangumiId ?? widget.anime.title}: count=${validTags.length}, tags=$validTags',
      );

      if (validTags.isNotEmpty) {
        // Limit results: more tags => fewer per tag
        int limitPerTag = (12 / validTags.length).ceil();
        if (limitPerTag < 2) limitPerTag = 2;
        if (limitPerTag > 5) limitPerTag = 5;

        // Take max 5 tags to search
        final searchTags = validTags.take(5).toList();
        debugPrint(
          '[Recommendations] Searching tags: $searchTags, limitPerTag=$limitPerTag',
        );

        // Fetch in parallel
        final futures = searchTags.map((tag) async {
          try {
            final items = await fetchBangumiBrowser(
              sortType: isLegacyMode ? 'collects' : 'trends',
              year: '',
              tags: [tag],
              page: 1,
            );
            debugPrint(
              '[Recommendations] Tag "$tag" returned ${items.length} items',
            );
            return items;
          } catch (e) {
            debugPrint('[Recommendations] Tag "$tag" search failed: $e');
            return <RankingAnime>[];
          }
        });

        final tagGroups = await Future.wait(futures);

        for (var group in tagGroups) {
          int count = 0;
          for (var item in group) {
            if (count >= limitPerTag) break;
            if (!addedIds.contains(item.bangumiId)) {
              results.add(item);
              addedIds.add(item.bangumiId);
              count++;
            }
          }
        }
      } else {
        debugPrint(
          '[Recommendations] Skip tag search because resolved tags are empty',
        );
      }

      if (mounted) {
        setState(() {
          _recommendations = results;
          _isLoadingRecommendations = false;
        });
      }
      debugPrint(
        '[Recommendations] Finished loading for '
        '${widget.anime.bangumiId ?? widget.anime.title}: total=${results.length}',
      );
    } catch (e) {
      debugPrint("[Recommendations] Error loading recommendations: $e");
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _loadDmhySource() async {
    if (widget.anime.bangumiId == null) return;

    setState(() {
      _isLoadingDmhy = true;
      _dmhyError = null;
      _dmhyResources = [];
    });

    try {
      final resources = await fetchDmhyResources(
        subjectId: widget.anime.bangumiId!,
        targetEpisode: _episodeController.currentEpisode.sort.toInt(),
      );

      if (mounted) {
        setState(() {
          _dmhyResources = resources;
          _isLoadingDmhy = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading DMHY source: $e");
      if (mounted) {
        setState(() {
          _dmhyError = e.toString();
          _isLoadingDmhy = false;
        });
      }
    }
  }

  Future<void> _loadMikanSource() async {
    debugPrint("[Mikan] Starting search for playback sources...");
    debugPrint("[Mikan] Target anime title: ${widget.anime.title}");
    debugPrint(
      "[Mikan] Current episode sort: ${_episodeController.currentEpisode.sort}",
    );

    setState(() {
      _isLoadingMikan = true;
      _mikanError = null;
      _mikanResources = [];
    });

    try {
      // ── Fast path: use bangumi-data index to skip web search ──
      // In hybrid/modern mode, try to resolve mikan id directly from the
      // cached bangumi-data JSON.  If the anime already carries a mikanId
      // (populated from bangumi-data on the schedule page) or if
      // BangumiDataService can look one up by bangumi id, we jump straight
      // to getMikanResources — no HTTP search request needed.
      final isNonLegacy =
          BangumiRequestModeService.notifier.value != BangumiRequestMode.legacy;

      String? resolvedMikanId;

      if (isNonLegacy) {
        // Prefer the mikanId that came with the AnimeInfo (it was derived
        // from bangumi-data already on the schedule/details page).
        if (widget.anime.mikanId != null && widget.anime.mikanId!.isNotEmpty) {
          resolvedMikanId = widget.anime.mikanId;
          debugPrint(
            "[Mikan] Fast path: using mikanId from AnimeInfo: $resolvedMikanId",
          );
        } else if (widget.anime.bangumiId != null &&
            widget.anime.bangumiId!.isNotEmpty) {
          resolvedMikanId = await BangumiDataService.getMikanId(
            widget.anime.bangumiId,
          );
          if (resolvedMikanId != null) {
            debugPrint(
              "[Mikan] Fast path: resolved mikanId=$resolvedMikanId from bangumiId=${widget.anime.bangumiId}",
            );
          }
        }
      }

      if (resolvedMikanId != null) {
        final result = MikanSearchResult(
          id: resolvedMikanId,
          name: widget.anime.title,
          imageUrl: '',
        );

        if (mounted) {
          setState(() {
            _mikanAnime = result;
          });
        }

        if (_episodeController.currentEpisode.id != 0) {
          final resources = await getMikanResources(
            mikanId: resolvedMikanId,
            currentEpisodeSort: _episodeController.currentEpisode.sort.toInt(),
          );
          debugPrint(
            "[Mikan] Fast path: Found ${resources.length} resources for EP ${_episodeController.currentEpisode.sort.toInt()}",
          );
          if (mounted) {
            setState(() {
              _mikanResources = resources;
              _isLoadingMikan = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoadingMikan = false;
            });
          }
        }
        return; // fast path done
      }

      // ── Fallback: web search on Mikan ──
      final result = await searchMikanAnime(nameCn: widget.anime.title);

      if (result == null) {
        debugPrint(
          "[Mikan] No anime found on Mikan for title: ${widget.anime.title}",
        );
        if (mounted) {
          setState(() {
            _isLoadingMikan = false;
            _mikanError = "未找到番剧";
          });
        }
        return;
      }

      debugPrint(
        "[Mikan] Found matching anime: ${result.name} (ID: ${result.id})",
      );

      if (mounted) {
        setState(() {
          _mikanAnime = result;
        });
      }

      if (_episodeController.currentEpisode.id != 0) {
        final resources = await getMikanResources(
          mikanId: result.id,
          currentEpisodeSort: _episodeController.currentEpisode.sort.toInt(),
        );

        debugPrint(
          "[Mikan] Initial load: Found ${resources.length} resources for EP ${_episodeController.currentEpisode.sort.toInt()}",
        );

        if (mounted) {
          setState(() {
            _mikanResources = resources;
            _isLoadingMikan = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMikan = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading Mikan source: $e");
      if (mounted) {
        setState(() {
          _mikanError = e.toString();
          _isLoadingMikan = false;
        });
      }
    }
  }

  Map<String, int> _sourceTiers = {};

  List<String> _extractAliasesFromBangumiJson(String? fullJson) {
    if (fullJson == null || fullJson.isEmpty) return [];

    try {
      final data = jsonDecode(fullJson);
      if (data is! Map) return [];

      final infobox = data['infobox'];
      if (infobox is! List) return [];

      final aliases = <String>[];
      for (final item in infobox) {
        if (item is! Map) continue;
        final key = item['key']?.toString() ?? '';
        final lowerKey = key.toLowerCase();
        final isAliasKey =
            key.contains('别名') ||
            key.contains('別名') ||
            key.contains('别称') ||
            lowerKey.contains('alias');
        if (!isAliasKey) continue;

        final value = item['value'];
        final values = <String>[];
        if (value is List) {
          for (final v in value) {
            if (v is Map && v['v'] != null) {
              values.add(v['v'].toString());
            } else if (v != null) {
              values.add(v.toString());
            }
          }
        } else if (value != null) {
          values.add(value.toString());
        }

        for (final raw in values) {
          for (final part in raw.split(RegExp(r'[\\/、,，;；·・]'))) {
            final trimmed = part.trim();
            if (trimmed.isNotEmpty) {
              aliases.add(trimmed);
            }
          }
        }
      }

      return aliases;
    } catch (_) {
      return [];
    }
  }

  String _buildSearchNameForSources() {
    final title = widget.anime.title.trim();
    final candidates = <String>[];

    void addCandidate(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      candidates.add(trimmed);
    }

    addCandidate(title);
    addCandidate(widget.anime.subTitle);
    for (final alias in _extractAliasesFromBangumiJson(widget.anime.fullJson)) {
      addCandidate(alias);
    }

    final unique = <String>[];
    final seen = <String>{};
    for (final item in candidates) {
      final key = item.toLowerCase();
      if (seen.add(key)) {
        unique.add(item);
      }
    }

    if (unique.isEmpty) {
      return title;
    }

    return unique.join('||');
  }

  String _buildCaptchaPreflightKeyword() {
    final fullSearchName = _buildSearchNameForSources();
    for (final item in fullSearchName.split('||')) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return widget.anime.title.trim();
  }

  List<String> _extractRecommendationTagsFromBangumiJson(String? fullJson) {
    if (fullJson == null || fullJson.isEmpty) return const [];

    try {
      final data = jsonDecode(fullJson);
      if (data is! Map) return const [];

      final tags = <String>[];

      final metaTags = data['meta_tags'];
      if (metaTags is List) {
        for (final item in metaTags) {
          final value = item?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            tags.add(value);
          }
        }
      }

      final detailTags = data['tags'];
      if (detailTags is List) {
        for (final item in detailTags) {
          if (item is Map) {
            final value = item['name']?.toString().trim() ?? '';
            if (value.isNotEmpty) {
              tags.add(value);
            }
          } else {
            final value = item?.toString().trim() ?? '';
            if (value.isNotEmpty) {
              tags.add(value);
            }
          }
        }
      }

      final unique = <String>[];
      final seen = <String>{};
      for (final tag in tags) {
        final key = tag.toLowerCase();
        if (seen.add(key)) {
          unique.add(tag);
        }
      }
      return unique;
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _resolveRecommendationTags() async {
    final directTags = normalizeRecommendationTags(widget.anime.tags);
    if (directTags.isNotEmpty) {
      debugPrint(
        '[Recommendations] Using widget tags for ${widget.anime.bangumiId ?? widget.anime.title}: $directTags',
      );
      return directTags;
    }

    final jsonTags = normalizeRecommendationTags(
      _extractRecommendationTagsFromBangumiJson(widget.anime.fullJson),
    );
    if (jsonTags.isNotEmpty) {
      debugPrint(
        '[Recommendations] Using fullJson tags for ${widget.anime.bangumiId ?? widget.anime.title}: $jsonTags',
      );
      return jsonTags;
    }

    final subjectId = int.tryParse(widget.anime.bangumiId ?? '');
    if (subjectId == null) {
      debugPrint(
        '[Recommendations] No bangumiId and no local tags for ${widget.anime.title}',
      );
      return const [];
    }

    try {
      final detail = await fetchLightSubjectDetails(subjectId: subjectId);
      final resolvedTags = normalizeRecommendationTags([
        ...detail.tags,
        ..._extractRecommendationTagsFromBangumiJson(detail.fullJson),
      ]);
      debugPrint(
        '[Recommendations] Using fetched detail tags for $subjectId: $resolvedTags',
      );
      return resolvedTags;
    } catch (e) {
      debugPrint('[Recommendations] Error resolving tags for $subjectId: $e');
      return const [];
    }
  }

  Future<void> _cancelSearchSubscriptions() async {
    if (_searchSubscriptions.isEmpty) {
      return;
    }
    final pending = List<StreamSubscription<SourceSearchProgress>>.from(
      _searchSubscriptions,
    );
    _searchSubscriptions.clear();
    for (final subscription in pending) {
      try {
        await subscription.cancel();
      } catch (e) {
        debugPrint('[SampleSearch] cancel subscription failed: $e');
      }
    }
  }

  void _queueCaptchaPreflightTask({
    required String taskKey,
    required String label,
    required SourceState source,
    String? searchKeyword,
    String? initialUrl,
    String? referer,
    String? initialCookies,
    required int loadToken,
    required void Function(
      _CaptchaPreflightTask task,
      CaptchaBypassResult result,
    )
    onResult,
  }) {
    final captchaConfig = CaptchaConfig.tryParse(source.captchaConfigJson);
    if (captchaConfig == null) {
      return;
    }

    final alreadyPending = _pendingCaptchaTasks.any(
      (task) => task.taskKey == taskKey,
    );
    if (alreadyPending || _activeCaptchaTasks.containsKey(taskKey)) {
      return;
    }

    _pendingCaptchaTasks.add(
      _CaptchaPreflightTask(
        taskKey: taskKey,
        label: label,
        source: source,
        searchKeyword: searchKeyword,
        initialUrl: initialUrl,
        referer: referer,
        initialCookies: initialCookies,
        captchaConfig: captchaConfig,
        loadToken: loadToken,
        onResult: onResult,
      ),
    );
  }

  void _queueSearchCaptchaPreflightTask({
    required SourceState source,
    required String searchKeyword,
    required int loadToken,
    required void Function(SourceRuntimeOverride runtimeOverride) onCompleted,
  }) {
    _queueCaptchaPreflightTask(
      taskKey: 'search:${source.name}',
      label: source.name,
      source: source,
      searchKeyword: searchKeyword,
      loadToken: loadToken,
      onResult: (task, result) {
        final runtimeOverride = result.success
            ? SourceRuntimeOverride(
                sourceName: task.source.name,
                cookies: result.cookies,
                searchPageHtml: result.searchPageHtml,
                searchPageUrl: result.searchPageUrl,
                detailPageHtml: result.detailPageHtml,
                detailPageUrl: result.detailPageUrl,
              )
            : SourceRuntimeOverride(
                sourceName: task.source.name,
                skipSearchError: result.error ?? 'Captcha preflight failed',
              );

        _handleSearchCaptchaPreflightResult(
          task: task,
          runtimeOverride: runtimeOverride,
          onCompleted: onCompleted,
        );
      },
    );
  }

  bool _isSearchStepFinished(SearchStep step) {
    return step == SearchStep.success || step == SearchStep.failed;
  }

  bool _isSourceSearchFinished() {
    if (_enabledSourceNames.isEmpty) {
      return false;
    }
    for (final sourceName in _enabledSourceNames) {
      final progress = _sourceProgressMap[sourceName];
      if (progress == null || !_isSearchStepFinished(progress.step)) {
        return false;
      }
    }
    return true;
  }

  /// Round 4 Stage 3：把 [page] 追加到 `_samplePlayPages` 的统一入口。
  ///
  /// `_samplePlayPages` 每次接受完新增项后都会按 tier `sort()`，导致 `List`
  /// 下标不再稳定反映 arrival 顺序，而 source-affinity 调度需要在 tier 相同
  /// 时按“进入 pending 更早”做稳定 tie break。这里在 `add` 的同时把
  /// 单调递增的序号写入 [`_pageEnqueueSeq`]（key 为 pageKey），保证调度器
  /// 任何时候都能拿到稳定的 arrival 顺序。
  void _addSamplePlayPage(SearchPlayResult page) {
    _samplePlayPages.add(page);
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    _pageEnqueueSeq[pageKey] = _nextPageEnqueueSeq++;
    // 5B step 3：warm 同源 worker 候选已不再局限于 captcha slot —— 统一
    // 表中所有 idle（kind == null）且 lastSourceName 命中的 slot 都能
    // 在下次 pump 接到该 pageKey，affinity 选取会优先命中。这里日志沿用
    // 旧文案便于回归对比。
    final warmWorkerIds =
        _scheduler.slots.values
            .where(
              (slot) => slot.isIdle && slot.lastSourceName == page.sourceName,
            )
            .map((slot) => slot.workerId)
            .toList()
          ..sort();
    if (warmWorkerIds.isNotEmpty) {
      debugPrint(
        '[WebViewScheduler] pending video $pageKey can reuse warm '
        'worker=${warmWorkerIds.first}',
      );
    }
  }

  /// Per-page extraction-eligibility predicate.
  ///
  ///行为等价于原 `_collectPendingWebViewExtractionTasks` 内联 `where` 闭包，
  /// 抽出来是为了让 `_collectPendingWebViewExtractionTasks`、`_hasPendingWebViewExtractionTasks`
  /// 与 Phase 0 的 `webviewSchedulerStats` 调度诊断共用同一份过滤规则，避免
  /// 后续 worker pool 重构时多处规则漂移。
  bool _pageIsPendingForExtraction(SearchPlayResult page) {
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    final hasPlayPageUrl = page.playPageUrl.trim().isNotEmpty;
    final alreadySuccessful = _sampleSuccessfulSources.any(
      (s) => _buildSourceChannelKey(s.sourceName, s.channelIndex) == pageKey,
    );
    final alreadyActive = _useWorkerPool
        ? _scheduler.activeVideoJobs.containsKey(pageKey)
        : _activeWebViews.containsKey(pageKey);
    final alreadyFailed = _failedWebViewPageKeys.contains(pageKey);
    // A source whose WebView extraction just finished is being probed
    // asynchronously (_probingSourceKeys) or has already been registered as
    // playable (_playableSourceKeys). It MUST be excluded here, otherwise
    // _onWebViewResult removes it from _activeWebViews and the pool pump
    // (running synchronously in the same setState) re-queues it before the
    // probe completes. Because the WebViewVideoExtractorWidget is reused with
    // the same ValueKey, its State keeps _isCompleted=true and a cancelled
    // timeout, so it never fires onResult again and never times out — a
    // zombie that permanently occupies a concurrency slot.
    final isProbing = _probingSourceKeys.contains(pageKey);
    final alreadyPlayable = _playableSourceKeys.contains(pageKey);
    // Note: extraction eligibility is keyed on the full source+channel
    // pageKey, NOT on sourceName alone. Each channel of a source has its own
    // distinct play page URL, so multiple channels of the same source may be
    // extracted concurrently. Guarding by sourceName here previously caused
    // only one channel per source to ever be extracted (and a stuck/zombie
    // WebView would block its siblings forever).
    return hasPlayPageUrl &&
        !alreadySuccessful &&
        !alreadyActive &&
        !alreadyFailed &&
        !isProbing &&
        !alreadyPlayable;
  }

  List<SearchPlayResult> _collectPendingWebViewExtractionTasks() {
    final pending = _samplePlayPages
        .where(_pageIsPendingForExtraction)
        .toList();

    pending.sort((a, b) {
      final tierA = _sourceTiers[a.sourceName] ?? 999;
      final tierB = _sourceTiers[b.sourceName] ?? 999;
      return tierA.compareTo(tierB);
    });

    return pending;
  }

  bool _hasPendingWebViewExtractionTasks() {
    return _collectPendingWebViewExtractionTasks().isNotEmpty;
  }

  int get _activeWebViewTaskCount {
    if (_useWorkerPool) {
      return _scheduler.activeVideoJobCount + _activeCaptchaTasks.length;
    }
    return _activeWebViews.length + _activeCaptchaTasks.length;
  }

  int get _webViewWorkerSlotCount => _scheduler.workerCount;

  static const int _webViewWorkerFailureThreshold = 3;

  String _webViewWorkerPoolLabel() {
    if (!_useWorkerPool) {
      return 'legacy';
    }
    final videoCount = _scheduler.slots.values
        .where((slot) => slot.kind == WebViewWorkerKind.video)
        .length;
    final captchaCount = _scheduler.slots.values
        .where((slot) => slot.kind == WebViewWorkerKind.captcha)
        .length;
    return 'slots $_webViewWorkerSlotCount/$_maxConcurrentWebViews '
        '(video $videoCount, captcha $captchaCount)';
  }

  String _workerHealthLabel(WebViewWorkerHealth health) {
    return switch (health) {
      WebViewWorkerHealth.idle => 'idle',
      WebViewWorkerHealth.running => 'running',
      WebViewWorkerHealth.cancelling => 'cancelling',
      WebViewWorkerHealth.unhealthy => 'unhealthy',
    };
  }

  void _recordVideoWorkerResult(String pageKey, VideoExtractResult result) {
    final failed = !result.success || result.timedOut;
    final markedUnhealthy = _scheduler.recordVideoWorkerResult(
      pageKey,
      failed,
      _webViewWorkerFailureThreshold,
    );
    if (markedUnhealthy) {
      final workerId = _scheduler.activeVideoJobs[pageKey];
      debugPrint(
        '[WebViewScheduler] video worker=$workerId marked unhealthy '
        'after ${_scheduler.slotOf(workerId)?.consecutiveFailures} '
        'consecutive failures',
      );
    }
  }

  void _recordCaptchaWorkerResult(String taskKey, CaptchaBypassResult result) {
    final failed = !result.success;
    final markedUnhealthy = _scheduler.recordCaptchaWorkerResult(
      taskKey,
      failed,
      _webViewWorkerFailureThreshold,
    );
    if (markedUnhealthy) {
      final workerId = _scheduler.activeCaptchaJobs[taskKey];
      debugPrint(
        '[WebViewScheduler] captcha worker=$workerId marked unhealthy '
        'after ${_scheduler.slotOf(workerId)?.consecutiveFailures} '
        'consecutive failures',
      );
    }
  }

  /// 把 scheduler 在 trim/acquire 过程中腾退的 idle slot 逐个复刻原来的
  /// `[WebViewScheduler] disposed idle ... worker=...` 日志。scheduler 本身
  /// 不持有 logging 职责，所以把腾退结果返回到本页来打点。
  void _logDisposedIdleSlots(List<WebViewWorkerSlotSnapshot> disposed) {
    for (final slot in disposed) {
      final kindLabel = switch (slot.kind) {
        WebViewWorkerKind.video => 'video',
        WebViewWorkerKind.captcha => 'captcha',
        null => 'idle',
      };
      debugPrint(
        '[WebViewScheduler] disposed idle $kindLabel worker=${slot.workerId} '
        'to keep unified slot budget',
      );
    }
  }

  bool _trimIdleWebViewWorkerSlotsToBudget() {
    if (!_useWorkerPool) return false;
    final removed = _scheduler.trimIdleWorkerSlotsToBudget(
      useWorkerPool: _useWorkerPool,
      maxConcurrent: _maxConcurrentWebViews,
    );
    _logDisposedIdleSlots(removed);
    return removed.isNotEmpty;
  }

  bool _startOneCaptchaTask() {
    if (_pendingCaptchaTasks.isEmpty) {
      return false;
    }
    if (_activeWebViewTaskCount >= _maxConcurrentWebViews) {
      return false;
    }

    final task = _pendingCaptchaTasks.removeFirst();
    if (_useWorkerPool) {
      final slot = _acquireIdleCaptchaWorkerSlot();
      if (slot == null) {
        _pendingCaptchaTasks.addFirst(task);
        return false;
      }
      _scheduler.startCaptchaJob(slot, task.taskKey, task.source.name);
    }
    _activeCaptchaTasks[task.taskKey] = task;
    _webViewStatus[task.taskKey] = '正在跳过验证码...';
    _webviewStats.onCaptchaJobStarted(task.taskKey, task.source.name);
    return true;
  }

  /// 5B step 3：取一个 idle（kind == null）slot 用来跑 captcha job。
  /// 不区分原来 captcha/video 两条路径 —— 统一 slot 表里 kind == null
  /// 即空闲 worker，可被任意 kind 复用。
  WebViewWorkerSlotSnapshot? _acquireIdleCaptchaWorkerSlot() {
    final result = _scheduler.acquireIdleCaptchaWorkerSlot(
      useWorkerPool: _useWorkerPool,
      maxConcurrent: _maxConcurrentWebViews,
    );
    _logDisposedIdleSlots(result.disposedIdleSlots);
    if (result.slot != null && result.createdNew) {
      debugPrint(
        '[CaptchaScheduler] created worker=${result.slot!.workerId} for captcha '
        '(${_webViewWorkerPoolLabel()})',
      );
    }
    return result.slot;
  }

  bool _startOneWebViewExtractionTask() {
    if (_activeWebViewTaskCount >= _maxConcurrentWebViews) {
      return false;
    }

    final pending = _collectPendingWebViewExtractionTasks();
    if (pending.isEmpty) {
      return false;
    }

    if (_useWorkerPool) {
      // Round 4 Stage 3：source-affinity 调度。先按 affinity 偏好挑一个 idle
      // worker（lastSourceName 命中 pending 同源 job 的 worker 优先，保证它
      // 能复用已 warm 的同源 InAppWebView），再让该 worker 用
      // [`_selectNextVideoJobForWorker`] 选取 job。这样同源多 channel 在单
      // worker 连续空闲时会连续落在同一个 worker，而慢多 channel 源又不会
      // 霸占全部 slot（soft limit）。
      final slot = _acquireIdleVideoWorkerSlotForAffinity(pending);
      if (slot == null) {
        // 理论上不会达到：_activeWebViewTaskCount 已 guard。容错退出。
        return false;
      }
      final page = _selectNextVideoJobForWorker(slot, pending);
      if (page == null) {
        return false;
      }
      final pageKey = _buildSourceChannelKey(
        page.sourceName,
        page.channelIndex,
      );
      _scheduler.startVideoJob(slot, pageKey, page.sourceName);
      _webViewStatus[pageKey] = '正在提取...';
      _webviewStats.onVideoJobStarted(
        pageKey,
        page.sourceName,
        page.channelIndex,
      );
      return true;
    }

    // Fallback：per-task widget 路径（旧逻辑，行为等价于 Round 2 之前）。
    final page = pending.first;
    final pageKey = _buildSourceChannelKey(page.sourceName, page.channelIndex);
    _activeWebViews[pageKey] = true;
    _webViewStatus[pageKey] = '正在提取...';
    _webviewStats.onVideoJobStarted(
      pageKey,
      page.sourceName,
      page.channelIndex,
    );
    return true;
  }

  /// 根据 `_scheduler.activeVideoJobs` 统计当前每个 sourceName 上正在跑的
  /// worker 数。
  /// 用于 source-affinity 调度的 soft limit 判定。被选取的 idle worker 自身
  /// 不计入（其 pageKey 为 null）。
  Map<String, int> _activeSourceWorkerCounts() {
    final counts = <String, int>{};
    for (final pageKey in _scheduler.activeVideoJobs.keys) {
      final src = SourceChannelKey.fromPageKey(pageKey).sourceName;
      counts[src] = (counts[src] ?? 0) + 1;
    }
    return counts;
  }

  /// Source-affinity 软上限：当存在其它源 pending 时，单个 source 最多占用
  /// `max(1, _maxConcurrentWebViews - 1)` 个 worker，保留至少 1 个 slot 给
  /// 其它源。`_maxConcurrentWebViews <= 1` 时退化为 1（不零留）。
  int get _sourceAffinitySoftLimit =>
      _maxConcurrentWebViews > 1 ? _maxConcurrentWebViews - 1 : 1;

  /// Round 4 Stage 3：为指定 idle worker 选取下一个 job。
  ///
  /// 调度规则（见 plan 阶段 3）：
  /// 1. **同源优先**：worker 的 `lastSourceName` 有 pending 同源 job 时，优
  ///    先取同源（复用 warm WebView 的站点 session/cookie）。
  /// 2. **soft limit**：若除该源外仍有其它源 pending，则该源 active worker
  ///    数已达 [`_sourceAffinitySoftLimit`] 时跳过本源，把 slot 让给其它源，
  ///    防止慢多 channel 源霸占全部并发。
  /// 3. **全局优先级回退**：同源无 pending 或被 soft limit 时，按 tier 升序
  ///    + 入队序号（[`_pageEnqueueSeq`]）升序选取；候选源同样套用 soft
  ///    limit，仅当所有候选源都被饱和时回退允许任一源（避免死锁）。
  /// 4. **慢源分担**：若没有其它源 pending，单源可吃满全部空闲 slot。
  ///
  /// 所有判定都基于调用发生时的 `_scheduler.activeVideoJobs` 快照；调度器在
  /// pump 循环里串行调用本方法并逐个 commit 到
  /// `_scheduler.activeVideoJobs`，因此 soft limit
  /// 能正确反映本轮已派出的 job。
  SearchPlayResult? _selectNextVideoJobForWorker(
    WebViewWorkerSlotSnapshot slot,
    List<SearchPlayResult> pending,
  ) {
    final picked = selectVideoJobForAffinitySlot(
      affinitySource: slot.lastSourceName,
      pending: pending,
      activeSourceWorkers: _activeSourceWorkerCounts(),
      softLimit: _sourceAffinitySoftLimit,
      sourceTiers: _sourceTiers,
      enqueueSeqByPageKey: _pageEnqueueSeq,
      pageKeyOf: (p) => _buildSourceChannelKey(p.sourceName, p.channelIndex),
    );
    if (picked == null) return null;
    final sameSourcePick =
        slot.lastSourceName != null && picked.sourceName == slot.lastSourceName;
    _logAffinityPick(
      workerId: slot.workerId,
      lastSource: slot.lastSourceName,
      pickedSource: picked.sourceName,
      pageKey: _buildSourceChannelKey(picked.sourceName, picked.channelIndex),
      sameSource: sameSourcePick,
    );
    return picked;
  }

  /// 结构化日志：记录一次 affinity 选取的结果。
  ///
  /// - `sameSource=true`：复用同源，命中 "selected same-source job" 文案。
  /// - `sameSource=false` 且 `lastSource` 非空：worker 从旧源切到新源，记
  ///   "stealing source"，便于排查慢源分流 / 源切换路径。
  /// - `sameSource=false` 且 `lastSource` 为空：worker 首次接活，记
  ///   "taking job"，无源切换语义。
  void _logAffinityPick({
    required int workerId,
    required String? lastSource,
    required String pickedSource,
    required String pageKey,
    required bool sameSource,
  }) {
    if (sameSource) {
      debugPrint(
        '[WebViewScheduler] worker=$workerId selected same-source job '
        '$pickedSource ($pageKey)',
      );
      return;
    }
    final from = (lastSource == null || lastSource.isEmpty)
        ? '<new>'
        : lastSource;
    if (lastSource == null || lastSource.isEmpty) {
      debugPrint(
        '[WebViewScheduler] worker=$workerId taking job '
        '$pickedSource ($pageKey)',
      );
    } else {
      debugPrint(
        '[WebViewScheduler] worker=$workerId stealing source '
        '$pickedSource ($pageKey, from=$from)',
      );
    }
  }

  /// 返回一个 idle [VideoWorkerSlot] 供本次 pump 派活，优先命中 affinity：
  ///
  /// 1. 现有 idle worker 且 `lastSourceName` 命中 [pending] 中某条同源 job
  ///    的，取最低 workerId 者（保证它能复用 warm 同源 WebView，不会被
  ///    非 affinity 的 idle worker 抢先把同源 channel 提走）。
  /// 2. 否则取任意现有 idle worker（最低 workerId）——复用 WebView 实例本身
  ///    就能省掉重建成本。
  /// 3. 否则在 `_maxConcurrentWebViews` 容量内新建一个 worker（workerId 单调
  ///    递增），新 worker 的 `lastSourceName` 为 null。
  /// 4. 全满则返回 null（理论由 `_activeWebViewTaskCount` guard 避免）。
  ///
  /// Pool 模式专用。
  /// 5B step 3：取一个 idle slot（[canAcceptJob]）用来跑 video job。
  ///
  /// 选取规则保持 Round 4 Stage 3 不变（先看 affinity 同源，再看任意 idle，
  /// 再看 captcha 升 video，最后新创建）；底层数据源改为统一
  /// [`_scheduler.slots`]。新创建的 slot 初始 `kind == null`（idle），
  /// 派活时由 [`_startOneWebViewExtractionTask`] 切到
  /// [WebViewWorkerKind.video]。
  WebViewWorkerSlotSnapshot? _acquireIdleVideoWorkerSlotForAffinity(
    List<SearchPlayResult> pending,
  ) {
    final pendingSourceNames = <String>{};
    for (final p in pending) {
      pendingSourceNames.add(p.sourceName);
    }
    final result = _scheduler.acquireIdleVideoWorkerSlot(
      pendingSourceNames,
      useWorkerPool: _useWorkerPool,
      maxConcurrent: _maxConcurrentWebViews,
    );
    _logDisposedIdleSlots(result.disposedIdleSlots);
    if (result.slot != null && result.createdNew) {
      debugPrint(
        '[WebViewScheduler] created worker=${result.slot!.workerId} for video '
        '(${_webViewWorkerPoolLabel()})',
      );
    }
    return result.slot;
  }

  bool _pumpWebViewPoolNow() {
    var startedAny = false;
    while (_activeWebViewTaskCount < _maxConcurrentWebViews) {
      final slotsRemaining = _maxConcurrentWebViews - _activeWebViewTaskCount;
      final hasPendingExtraction = _hasPendingWebViewExtractionTasks();
      final hasActiveExtraction = _useWorkerPool
          ? _scheduler.activeVideoJobs.isNotEmpty
          : _activeWebViews.isNotEmpty;

      final canStartCaptcha = canStartCaptchaDecision(
        hasPendingExtraction: hasPendingExtraction,
        hasActiveExtraction: hasActiveExtraction,
        slotsRemaining: slotsRemaining,
      );

      if (canStartCaptcha && _startOneCaptchaTask()) {
        startedAny = true;
        continue;
      }
      if (_startOneWebViewExtractionTask()) {
        startedAny = true;
        continue;
      }
      break;
    }
    return startedAny;
  }

  int _completedSearchSourceCount() {
    return _sourceProgressMap.values
        .where((p) => _isSearchStepFinished(p.step))
        .length;
  }

  String _searchProgressLabel() {
    return '搜索进度: ${_completedSearchSourceCount()}/${_enabledSourceNames.length}';
  }

  String _captchaActiveLabel() {
    return '验证码进行中 ${_activeCaptchaTasks.length}';
  }

  String _extractionActiveLabel() {
    final active = _useWorkerPool
        ? _scheduler.activeVideoJobs.length
        : _activeWebViews.length;
    return '提取并发 $active/$_maxConcurrentWebViews';
  }

  /// Phase 0 单行调试计数汇总（widget 创建/释放 + 视频/验证码 job 生命周期）。
  String _webviewStatsLabel() {
    return _webviewStats.shortSummary();
  }

  /// Phase 0: 按 sourceName 汇总 pending/active/completed 三个维度。
  /// 输出形如 `源A [2|1|0], 源B [0|0|1]`，方括号内依次为
  /// `pending|active|completed`。pending 复用 `_pageIsPendingForExtraction`，
  /// active 计 `_activeWebViews` + `_activeCaptchaTasks`，completed 计
  /// `_sampleSuccessfulSources`。仅用于调试，不参与调度。
  String _perSourceStatusLabel() {
    final pending = <String, int>{};
    for (final page in _samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pending[page.sourceName] = (pending[page.sourceName] ?? 0) + 1;
      }
    }
    final active = <String, int>{};
    final activeExtractionKeys = _useWorkerPool
        ? _scheduler.activeVideoJobs.keys
        : _activeWebViews.keys;
    for (final key in activeExtractionKeys) {
      final src = SourceChannelKey.fromPageKey(key).sourceName;
      active[src] = (active[src] ?? 0) + 1;
    }
    for (final task in _activeCaptchaTasks.values) {
      active[task.source.name] = (active[task.source.name] ?? 0) + 1;
    }
    final completed = <String, int>{};
    for (final s in _sampleSuccessfulSources) {
      completed[s.sourceName] = (completed[s.sourceName] ?? 0) + 1;
    }
    final names = <String>{
      ...pending.keys,
      ...active.keys,
      ...completed.keys,
    }.toList()..sort();
    if (names.isEmpty) return 'no sources yet';
    final parts = <String>[];
    for (final name in names) {
      final p = pending[name] ?? 0;
      final a = active[name] ?? 0;
      final c = completed[name] ?? 0;
      if (p == 0 && a == 0 && c == 0) continue;
      parts.add('$name [$p|$a|$c]');
    }
    return parts.isEmpty ? 'no active sources' : parts.join(', ');
  }

  /// Round 4 Stage 3：pool 模式调试面板的 worker slot 行。
  ///
  /// 按 workerId 升序渲染每个 slot：
  /// - **busy**：spinner + `sourceName (w$workerId)` + channelName + 当前
  ///   playPageUrl。
  /// - **idle**：muted dot + `w$workerId · idle`。
  ///
  /// 末尾追加 affinity 子文本 `warm: $lastSourceName · same-src pending: $n`：
  /// `lastSourceName` 是 worker 上一任 job 的源名（warm 度），`n` 是该源当前
  /// 仍 pending 的待提取数。仅在有内容（`lastSourceName != null` 或 `n>0`）
  /// 时显示，`n>0` 时用 primary 色高亮，提示该 worker 已有可接的同源 job，
  /// 直观观察 source-affinity 复用与慢源分流效果。
  /// Round 4 Stage 3 / 5B step 3：pool 模式调试面板的 worker slot 行。
  ///
  /// 5B step 3 之后视频/验证码共享 [`_scheduler.slots`]，渲染统一为
  /// 单一列表（按 workerId 升序），不再分两段。空闲 slot（`kind == null`）
  /// 显示 `w$id · idle`；video busy slot 显示当前 source + channel + URL，
  /// captcha busy slot 显示 `正在跳过验证码`。
  ///
  /// 末尾追加 affinity 子文本 `warm: $lastSourceName · same-src pending: $n`：
  /// `lastSourceName` 是 worker 上一任 job 的源名（warm 度），`n` 是该源当前
  /// 仍 pending 的待提取数。仅在有内容（`lastSourceName != null` 或 `n>0`）
  /// 时显示，`n>0` 时用 primary 色高亮，提示该 worker 已有可接的同源 job，
  /// 直观观察 source-affinity 复用与慢源分流效果。
  List<Widget> _buildWebViewWorkerStatusRows() {
    final pendingBySource = <String, int>{};
    for (final page in _samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pendingBySource[page.sourceName] =
            (pendingBySource[page.sourceName] ?? 0) + 1;
      }
    }

    final slots = _scheduler.slots.values.toList()
      ..sort((a, b) => a.workerId.compareTo(b.workerId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white54
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final mutedColor = isDark
        ? Colors.white24
        : Theme.of(context).colorScheme.outline;

    return slots.map((slot) {
      final lastSource = slot.lastSourceName;
      final sameSrcPending = lastSource == null
          ? 0
          : (pendingBySource[lastSource] ?? 0);
      final showAffinity = lastSource != null || sameSrcPending > 0;

      final healthLabel = _workerHealthLabel(slot.health);
      final kind = slot.kind;
      final isVideoBusy = kind == WebViewWorkerKind.video;
      final isCaptchaBusy = kind == WebViewWorkerKind.captcha;
      final isBusy = isVideoBusy || isCaptchaBusy;

      var sourceName = '';
      String? channelName;
      var urlLine = '等待匹配播放页...';
      if (isVideoBusy) {
        final pageKey = slot.pageKey!;
        final key = SourceChannelKey.fromPageKey(pageKey);
        sourceName = key.sourceName;
        final channelIndex = key.channelIndex?.toInt();
        for (final item in _samplePlayPages) {
          final pIdx = item.channelIndex?.toInt();
          if (item.sourceName == sourceName && pIdx == channelIndex) {
            channelName = item.channelName;
            urlLine = item.playPageUrl;
            break;
          }
        }
      } else if (isCaptchaBusy) {
        final task = _activeCaptchaTasks[slot.taskKey];
        sourceName = task?.source.name ?? '';
        urlLine = '正在跳过验证码';
      }

      final busyLabel = isVideoBusy
          ? '$sourceName (w${slot.workerId} · $healthLabel)'
          : isCaptchaBusy
          ? '$sourceName (c${slot.workerId} · $healthLabel)'
          : 'w${slot.workerId} · $healthLabel';

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: isBusy
                  ? CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF888888),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          busyLabel,
                          style: TextStyle(
                            color: isBusy ? labelColor : mutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isVideoBusy && (channelName ?? '').isNotEmpty)
                        Text(
                          ' - $channelName',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    urlLine,
                    style: const TextStyle(color: Colors.grey, fontSize: 8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showAffinity)
                    Text(
                      'warm: ${lastSource ?? '-'} · same-src pending: $sameSrcPending',
                      style: TextStyle(
                        color: sameSrcPending > 0
                            ? Theme.of(context).colorScheme.primary
                            : mutedColor,
                        fontSize: 8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Phase 0: 输出一行结构化的调度快照日志，便于后续 worker pool 重构对比基线。
  void _logSchedulerState(String reason) {
    debugPrint(
      '[WebViewScheduler] state ($reason): '
      '${_extractionActiveLabel()} · ${_captchaActiveLabel()} · '
      '${_webViewWorkerPoolLabel()} · '
      'per-source: ${_perSourceStatusLabel()} · '
      'workers: ${_workerAffinitySummary()} · '
      'stats: ${_webviewStatsLabel()}',
    );
  }

  /// Round 4 Stage 3：worker pool affinity 调度快照字符串，形如
  /// `w0[S#a,jobs#0,warmS,ss#3] w1[idle,warmS,ss#3] w2[idle,warm-,ss#0]`。
  /// 每项含义：`w$workerId` 后方括号内依次为 busy 时 `源#channel`（idle 时
  /// 空）、该源 active 数、`warm$lastSourceName`、`ss#$sameSrcPending`。
  /// 仅用于日志，不参与调度。
  /// Round 4 Stage 3 / 5B step 3：worker pool affinity 调度快照字符串。
  ///
  /// 5B step 3 之后渲染统一遍历 [`_scheduler.slots`]，按 workerId 升序输
  /// 出形如 `w0[V#S#a,warmS,ss#3] w1[C#taskKey,warmS,ss#0] w2[idle,warm-,ss#0]`。
  /// 每项含义：`w$workerId` 后方括号内依次为：
  /// - 视频 busy：`V#源#channel`；空闲或非视频：`idle`
  /// - 验证码 busy：`C#taskKey`
  /// - `warm$lastSourceName`
  /// - `ss#$sameSrcPending`
  /// - `h$health`
  /// 仅用于日志，不参与调度。
  String _workerAffinitySummary() {
    if (_scheduler.slots.isEmpty) {
      return 'none';
    }
    final pendingBySource = <String, int>{};
    for (final page in _samplePlayPages) {
      if (_pageIsPendingForExtraction(page)) {
        pendingBySource[page.sourceName] =
            (pendingBySource[page.sourceName] ?? 0) + 1;
      }
    }
    final activeBySource = _activeSourceWorkerCounts();
    final slots = _scheduler.slots.values.toList()
      ..sort((a, b) => a.workerId.compareTo(b.workerId));
    final parts = <String>[];
    for (final slot in slots) {
      final last = slot.lastSourceName ?? '-';
      final ss = slot.lastSourceName == null ? 0 : (pendingBySource[last] ?? 0);
      final health = _workerHealthLabel(slot.health);
      String cur;
      switch (slot.kind) {
        case WebViewWorkerKind.video:
          final pageKey = slot.pageKey;
          if (pageKey == null) {
            cur = 'idle,jobs${activeBySource[last] ?? 0}';
          } else {
            final k = SourceChannelKey.fromPageKey(pageKey);
            cur = 'V#${k.sourceName}#${k.channelIndex ?? '-'}';
          }
        case WebViewWorkerKind.captcha:
          cur = 'C#${slot.taskKey ?? '-'}';
        case null:
          cur = 'idle,jobs${activeBySource[last] ?? 0}';
      }
      parts.add('w${slot.workerId}[$cur,warm$last,ss#$ss,h$health]');
    }
    return parts.join(' ');
  }

  void _updatePoolStatusMessage() {
    _sampleStatusMessageNotifier.value =
        '${_searchProgressLabel()}，'
        '${_captchaActiveLabel()}，'
        '${_extractionActiveLabel()}';
    _logSchedulerState('poolStatus');
  }

  void _scheduleWebViewPoolPump({bool immediate = false}) {
    if (!mounted) return;

    if (immediate) {
      final startedAny = _scheduler.pumpCoordinator.scheduleImmediate(
        _pumpWebViewPoolNow,
      );
      if (startedAny && mounted) {
        setState(() {});
        _updatePoolStatusMessage();
      }
      _maybeFinishSampleSearch();
      return;
    }

    unawaited(
      _scheduler.pumpCoordinator.scheduleStaggered(_pumpWebViewPoolStaggered),
    );
  }

  Future<void> _pumpWebViewPoolStaggered(int token) async {
    var startedAny = false;
    var isFirst = true;

    while (_activeWebViewTaskCount < _maxConcurrentWebViews) {
      if (!mounted || !_scheduler.pumpCoordinator.isCurrentToken(token)) break;

      if (!isFirst && _webViewLaunchInterval > 0) {
        await Future.delayed(Duration(milliseconds: _webViewLaunchInterval));
        if (!mounted || !_scheduler.pumpCoordinator.isCurrentToken(token)) {
          break;
        }
      }
      isFirst = false;

      final slotsRemaining = _maxConcurrentWebViews - _activeWebViewTaskCount;
      final hasPendingExtraction = _hasPendingWebViewExtractionTasks();
      final hasActiveExtraction = _useWorkerPool
          ? _scheduler.activeVideoJobs.isNotEmpty
          : _activeWebViews.isNotEmpty;

      final canStartCaptcha = canStartCaptchaDecision(
        hasPendingExtraction: hasPendingExtraction,
        hasActiveExtraction: hasActiveExtraction,
        slotsRemaining: slotsRemaining,
      );

      var didStart = false;
      if (canStartCaptcha && _startOneCaptchaTask()) {
        didStart = true;
      } else if (_startOneWebViewExtractionTask()) {
        didStart = true;
      }

      if (didStart) {
        startedAny = true;
        if (mounted) {
          setState(() {});
        }
      } else {
        break;
      }
    }

    if (startedAny && mounted) {
      _updatePoolStatusMessage();
    }
    if (mounted) {
      _maybeFinishSampleSearch();
    }
  }

  void _onCaptchaPreflightResult(String taskKey, CaptchaBypassResult result) {
    final task = _activeCaptchaTasks.remove(taskKey);
    _webViewStatus.remove(taskKey);

    if (task == null) {
      _releaseCaptchaSlotForTask(taskKey);
      _webviewStats.onCaptchaJobLateAfterCancel(taskKey);
      if (mounted) setState(() {});
      _scheduleWebViewPoolPump(immediate: true);
      return;
    }

    if (!mounted || task.loadToken != _sampleLoadToken) {
      _releaseCaptchaSlotForTask(taskKey);
      _webviewStats.onCaptchaJobStaleResult(taskKey);
      if (mounted) setState(() {});
      _scheduleWebViewPoolPump(immediate: true);
      return;
    }

    _recordCaptchaWorkerResult(taskKey, result);
    _releaseCaptchaSlotForTask(taskKey);
    _webviewStats.onCaptchaJobCompleted(
      success: result.success,
      timedOut: result.timedOut,
      jobKey: taskKey,
      sourceName: task.source.name,
    );
    task.onResult(task, result);
    if (mounted) setState(() {});
    _scheduleWebViewPoolPump(immediate: true);
    _maybeFinishSampleSearch();
    _logSchedulerState('captchaResult');
  }

  void _releaseCaptchaSlotForTask(String taskKey) {
    _scheduler.releaseCaptchaSlot(taskKey);
  }

  void _onCaptchaWorkerIdle(int workerId) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final slot = _scheduler.slotOf(workerId);
      if (slot == null) return;
      final taskKey = slot.taskKey;
      if (shouldClearCaptchaSlotOnIdle(
        slotTaskKey: taskKey,
        activeCaptchaTasksContainsKey: _activeCaptchaTasks.containsKey(taskKey),
      )) {
        _scheduler.clearStaleCaptchaSlotOnIdle(workerId);
      }
      final health = _scheduler.healthOf(workerId);
      if (health == WebViewWorkerHealth.unhealthy) {
        _scheduler.removeSlot(workerId);
        debugPrint(
          '[WebViewScheduler] rebuilt captcha worker=$workerId by removing '
          'unhealthy idle slot',
        );
      } else {
        _scheduler.markSlotIdle(workerId);
      }
      _trimIdleWebViewWorkerSlotsToBudget();
      setState(() {});
      _updatePoolStatusMessage();
      _scheduleWebViewPoolPump(immediate: true);
      _maybeFinishSampleSearch();
    });
  }

  void _handleSearchCaptchaPreflightResult({
    required _CaptchaPreflightTask task,
    required SourceRuntimeOverride runtimeOverride,
    required void Function(SourceRuntimeOverride runtimeOverride) onCompleted,
  }) {
    final sourceName = task.source.name;

    if (runtimeOverride.skipSearchError != null) {
      setState(() {
        _sourceProgressMap[sourceName] = SourceSearchProgress(
          sourceName: sourceName,
          step: SearchStep.failed,
          error: runtimeOverride.skipSearchError,
          playPageUrl: null,
          videoRegex: null,
          directVideoUrl: null,
          cookies: runtimeOverride.cookies,
          headers: null,
          captchaConfigJson: task.source.captchaConfigJson,
          enableNestedUrl: false,
        );
      });
    } else {
      _captchaRuntimeOverrides[sourceName] = runtimeOverride;
      setState(() {
        _sourceProgressMap[sourceName] = SourceSearchProgress(
          sourceName: sourceName,
          step: SearchStep.pending,
          error: null,
          playPageUrl: null,
          videoRegex: null,
          directVideoUrl: null,
          cookies: runtimeOverride.cookies,
          headers: null,
          captchaConfigJson: task.source.captchaConfigJson,
          enableNestedUrl: false,
        );
      });
    }

    onCompleted(runtimeOverride);
  }

  void _handleSearchProgressUpdate({
    required SourceSearchProgress progress,
    required String searchName,
    required int currentEpNumber,
  }) {
    // Debug: Print channel information
    if (progress.allChannels != null && progress.allChannels!.isNotEmpty) {
      debugPrint(
        '[Channel Info] ${progress.sourceName}: Found ${progress.allChannels!.length} channels: '
        '${progress.allChannels!.map((c) => '${c.name}(${c.index})').join(', ')}',
      );
    }

    // 更新该源的进度
    _sourceProgressMap[progress.sourceName] = progress;

    // 如果搜索成功，添加到成功列表
    if (progress.step == SearchStep.success && progress.playPageUrl != null) {
      // 调试输出channel信息
      debugPrint(
        '[Search Success] ${progress.sourceName}: '
        'channelName=${progress.channelName}, '
        'channelIndex=${progress.channelIndex}, '
        'allChannels=${progress.allChannels?.length ?? 0}',
      );

      // 标记是否需要为该源启动WebView提取
      bool needsWebViewExtraction = false;

      // 如果有多个channels，为每个channel创建一个结果
      if (progress.allChannels != null && progress.allChannels!.isNotEmpty) {
        debugPrint(
          '[Multi-Channel] ${progress.sourceName}: Creating results for ${progress.allChannels!.length} channels',
        );

        final selectedChannelIndex = progress.channelIndex;

        for (int i = 0; i < progress.allChannels!.length; i++) {
          final channel = progress.allChannels![i];
          final channelKey = _buildSourceChannelKey(
            progress.sourceName,
            channel.index,
          );
          final isSelectedChannel =
              i == 0 || selectedChannelIndex == channel.index;

          if (!isSelectedChannel) {
            final savedOverride = _captchaRuntimeOverrides[progress.sourceName];
            unawaited(
              _resolveChannelPlayPageUrl(
                sourceName: progress.sourceName,
                animeName: searchName,
                channelIndex: channel.index,
                episodeNumber: currentEpNumber,
                channelName: channel.name,
                videoRegex: progress.videoRegex ?? '',
                cookies: progress.cookies ?? savedOverride?.cookies,
                headers: progress.headers,
                searchPageHtml: savedOverride?.searchPageHtml,
                searchPageUrl: savedOverride?.searchPageUrl,
                detailPageHtml: savedOverride?.detailPageHtml,
                detailPageUrl: savedOverride?.detailPageUrl,
              ),
            );
            continue;
          }

          final result = SearchPlayResult(
            sourceName: progress.sourceName,
            playPageUrl: progress.playPageUrl!,
            videoRegex: progress.videoRegex ?? '',
            directVideoUrl: progress.directVideoUrl,
            cookies: progress.cookies,
            headers: progress.headers,
            channelName: channel.name,
            channelIndex: channel.index,
            captchaConfigJson: progress.captchaConfigJson,
            enableNestedUrl: progress.enableNestedUrl,
            matchNestedUrl: progress.matchNestedUrl,
          );

          // 避免重复添加（使用sourceName + channelIndex作为唯一标识）
          if (!_samplePlayPages.any(
            (p) =>
                _buildSourceChannelKey(p.sourceName, p.channelIndex) ==
                channelKey,
          )) {
            debugPrint(
              '[Add Channel Result] ${progress.sourceName} - Channel: ${channel.name}(${channel.index})',
            );
            _addSamplePlayPage(result);

            // 如果没有直接视频URL，标记需要WebView提取
            if (progress.directVideoUrl == null ||
                progress.directVideoUrl!.isEmpty) {
              needsWebViewExtraction = true;
            }
          }

          // 如果有直接视频URL，也添加到成功列表
          if (progress.directVideoUrl != null &&
              progress.directVideoUrl!.isNotEmpty) {
            unawaited(
              _probeAndRegisterPlayableSource(result, autoPlayAfterProbe: true),
            );
          }
        }
      } else {
        // 兼容模式：如果没有allChannels信息，使用旧逻辑
        debugPrint(
          '[Single Result] ${progress.sourceName}: No channel info, using legacy mode',
        );

        final result = SearchPlayResult(
          sourceName: progress.sourceName,
          playPageUrl: progress.playPageUrl!,
          videoRegex: progress.videoRegex ?? '',
          directVideoUrl: progress.directVideoUrl,
          cookies: progress.cookies,
          headers: progress.headers,
          channelName: progress.channelName,
          channelIndex: progress.channelIndex,
          captchaConfigJson: progress.captchaConfigJson,
          enableNestedUrl: progress.enableNestedUrl,
          matchNestedUrl: progress.matchNestedUrl,
        );

        // 避免重复添加
        if (!_samplePlayPages.any((p) => p.sourceName == progress.sourceName)) {
          _addSamplePlayPage(result);

          // 如果没有直接视频URL，标记需要WebView提取
          if (progress.directVideoUrl == null ||
              progress.directVideoUrl!.isEmpty) {
            needsWebViewExtraction = true;
          }
        }

        // 如果有直接视频URL，添加到成功列表
        if (progress.directVideoUrl != null &&
            progress.directVideoUrl!.isNotEmpty) {
          unawaited(
            _probeAndRegisterPlayableSource(result, autoPlayAfterProbe: true),
          );
        }
      }

      // 如果该源需要WebView提取，立即尝试启动（不等待所有源完成）
      if (needsWebViewExtraction) {
        debugPrint(
          '[Immediate WebView] Starting WebView extraction for ${progress.sourceName}',
        );
        _samplePlayPages.sort((a, b) {
          final tierA = _sourceTiers[a.sourceName] ?? 999;
          final tierB = _sourceTiers[b.sourceName] ?? 999;
          return tierA.compareTo(tierB);
        });
        _scheduleWebViewPoolPump();
      }
    }

    // 更新状态消息
    final completedCount = _sourceProgressMap.values
        .where((p) => _isSearchStepFinished(p.step))
        .length;
    final activeCaptcha = _activeCaptchaTasks.length;
    final pendingCaptcha = _pendingCaptchaTasks.length;
    _sampleStatusMessageNotifier.value =
        '搜索进度: $completedCount/${_enabledSourceNames.length}，'
        '验证码 $activeCaptcha 运行/$pendingCaptcha 排队';

    // 手动触发搜索后不自动播放，等待用户主动点击“播放”
    if (_autoPlaySearchedSource) {
      _attemptAutoPlay();
    }
  }

  void _launchSearchStream({
    required String searchName,
    required int currentEpNumber,
    required int relativeEpNumber,
    required List<SourceRuntimeOverride> runtimeOverrides,
    required Set<String> targetSources,
    required int loadToken,
    required String streamTag,
  }) {
    if (targetSources.isEmpty) {
      return;
    }

    late final StreamSubscription<SourceSearchProgress> subscription;
    subscription =
        genericSearchWithProgressRuntime(
          animeName: searchName,
          absoluteEpisode: currentEpNumber,
          relativeEpisode: relativeEpNumber,
          targetSourceNames: targetSources.toList(),
          runtimeOverrides: runtimeOverrides,
        ).listen(
          (progress) {
            if (!mounted || loadToken != _sampleLoadToken) {
              return;
            }
            if (!targetSources.contains(progress.sourceName)) {
              return;
            }

            setState(() {
              _handleSearchProgressUpdate(
                progress: progress,
                searchName: searchName,
                currentEpNumber: currentEpNumber,
              );
            });

            _scheduleWebViewPoolPump(immediate: true);
            _maybeFinishSampleSearch();
          },
          onError: (error, _) {
            debugPrint('[SampleSearch][$streamTag] stream error: $error');
            _searchSubscriptions.remove(subscription);
            if (!mounted || loadToken != _sampleLoadToken) {
              return;
            }

            setState(() {
              for (final sourceName in targetSources) {
                final current = _sourceProgressMap[sourceName];
                final isFinished =
                    current != null && _isSearchStepFinished(current.step);
                if (isFinished) {
                  continue;
                }
                _sourceProgressMap[sourceName] = SourceSearchProgress(
                  sourceName: sourceName,
                  step: SearchStep.failed,
                  error: error.toString(),
                  playPageUrl: null,
                  videoRegex: null,
                  directVideoUrl: null,
                  cookies: null,
                  headers: null,
                  enableNestedUrl: false,
                );
              }
            });
            _scheduleWebViewPoolPump();
            _maybeFinishSampleSearch();
          },
          onDone: () {
            _searchSubscriptions.remove(subscription);
            if (!mounted || loadToken != _sampleLoadToken) {
              return;
            }
            _maybeFinishSampleSearch();
          },
          cancelOnError: true,
        );

    _searchSubscriptions.add(subscription);
  }

  void _startCaptchaSourceSearch({
    required SourceState source,
    required SourceRuntimeOverride runtimeOverride,
    required String searchName,
    required int currentEpNumber,
    required int relativeEpNumber,
    required int loadToken,
  }) {
    _launchSearchStream(
      searchName: searchName,
      currentEpNumber: currentEpNumber,
      relativeEpNumber: relativeEpNumber,
      runtimeOverrides: [runtimeOverride],
      targetSources: {source.name},
      loadToken: loadToken,
      streamTag: 'captcha-${source.name}',
    );
  }

  void _maybeFinishSampleSearch() {
    if (!mounted || !_isLoadingSample) {
      return;
    }
    if (_searchSubscriptions.isNotEmpty) {
      return;
    }
    if (_pendingCaptchaTasks.isNotEmpty || _activeCaptchaTasks.isNotEmpty) {
      return;
    }
    final activeExtraction = _useWorkerPool
        ? _scheduler.activeVideoJobs.isNotEmpty
        : _activeWebViews.isNotEmpty;
    if (activeExtraction || _resolvingChannelPlayPageKeys.isNotEmpty) {
      return;
    }
    // Probes run asynchronously after a WebView extraction completes. The
    // search is not truly finished until every in-flight probe has resolved
    // (accepted -> registered as playable, or rejected -> marked failed),
    // otherwise the UI could briefly report "所有源都无法提取" right before a
    // late probe accepts a source.
    if (_probingSourceKeys.isNotEmpty) {
      return;
    }
    if (_hasPendingWebViewExtractionTasks()) {
      return;
    }
    if (!_isSourceSearchFinished()) {
      return;
    }

    setState(() {
      _isLoadingSample = false;
      if (_samplePlayPages.isEmpty) {
        _sampleError = '未在任何源中找到该动画';
      } else if (_sampleSuccessfulSources.isEmpty) {
        _sampleError = '所有源都无法提取视频链接';
      } else {
        _sampleStatusMessageNotifier.value =
            '搜索完成，共找到 ${_sampleSuccessfulSources.length} 个可用源';
      }
    });
  }

  Future<void> _loadSampleSource({bool manual = false}) async {
    if (!manual && _disableAutoSourceSearchForCurrentEpisode) {
      if (mounted) {
        setState(() {
          _isLoadingSample = false;
          _sampleError = null;
          _sampleStatusMessageNotifier.value = '已播放本地资源，点击刷新可手动搜索在线源';
        });
      }
      return;
    }

    final loadToken = ++_sampleLoadToken;
    await _cancelSearchSubscriptions();

    if (!mounted || loadToken != _sampleLoadToken) {
      return;
    }

    // Ensure we have the latest setting
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSearchOnline = prefs.getBool('auto_search_online') ?? true;
    } catch (e) {
      debugPrint('Error refreshing settings in loadSampleSource: $e');
    }

    // First check if there's already a BT download for this episode
    final btTask = _downloadManager.getAvailableBtTaskForEpisode(
      widget.anime.title,
      _episodeController.currentEpisode.sort.toInt(),
    );

    if (btTask != null && _currentStreamUrl == null) {
      final streamUrl = await _downloadManager.getOrCreateStreamUrl(btTask.id);
      if (!mounted || loadToken != _sampleLoadToken) return;
      if (streamUrl != null) {
        debugPrint(
          '[Sample] Found existing BT download, using it as primary source',
        );
        _playBtStreamUrl(streamUrl);
        // Continue loading other sources in background for alternatives
      }
    }

    setState(() {
      _isLoadingSample = true;
      _sampleError = null;
      _autoPlaySearchedSource = !manual;
      _sampleVideoUrl = _sampleVideoUrl; // Keep existing if BT is playing
      _samplePlayPages = [];
      _sampleSuccessfulSources = [];
      _pageEnqueueSeq.clear();
      _nextPageEnqueueSeq = 0;
      _playableSourceKeys.clear();
      _probingSourceKeys.clear();
      _failedPlaybackSourceKeys.clear();
      _selectedSourceIndex = 0;
      _activeWebViews.clear();
      // Phase 2 B6：pool 状态清理交给 scheduler。把每个 slot 的
      // pageKey/taskKind 置 null 让 build 把它们的 job 转为 null
      // （didUpdateWidget 触发 _cancelCurrentJob(silent) -> onIdle ->
      // _onWorkerIdlePostFrame 走 no-op），并清空 active 反查。
      // slot 表本身保留以便跨搜索复用 InAppWebView；下一个搜索开始后
      // `_acquireIdleVideoWorkerSlotForAffinity` 直接命中这些 idle
      // slot。`lastSourceName` 也保留，便于跨搜索复用同源 warm
      // WebView。
      _activeCaptchaTasks.clear();
      _scheduler.resetForNewSearch();
      _pendingCaptchaTasks.clear();
      _searchSubscriptions.clear();
      _webViewStatus.clear();
      _failedWebViewPageKeys.clear();
      _resolvingChannelPlayPageKeys.clear();
      _sampleStatusMessageNotifier.value = '正在获取播放源列表...';
      _sourceProgressMap = {};
      _captchaRuntimeOverrides = {};
      _enabledSourceNames = [];
      _sourceTiers = {};
      _hasAutoPlayed = false;
      _acceptedSourcePageKey = null;
      _clearPlaybackStartupWatchdog();
      _webviewStats.reset();
    });
    _publishPlayerControlSourceState();

    if (!_autoSearchOnline) {
      if (mounted) {
        setState(() {
          _isLoadingSample = false;
          _sampleStatusMessageNotifier.value = '在线搜索已关闭';
        });
      }
      return;
    }

    try {
      // 获取所有源（包括详细信息如Tier）
      final sources = await getPlaybackSources();
      final enabledSources = sources.where((s) => s.enabled).toList();
      if (enabledSources.isEmpty) {
        if (mounted && loadToken == _sampleLoadToken) {
          setState(() {
            _isLoadingSample = false;
            _sampleError = '未启用任何播放源';
          });
        }
        return;
      }

      final enabledNames = enabledSources.map((s) => s.name).toList();
      final captchaSources =
          enabledSources
              .where(
                (source) =>
                    CaptchaConfig.tryParse(source.captchaConfigJson) != null,
              )
              .toList()
            ..sort((a, b) => a.tier.compareTo(b.tier));
      final captchaSourceNameSet = captchaSources
          .map((source) => source.name)
          .toSet();
      final nonCaptchaSources = enabledSources
          .where((source) => !captchaSourceNameSet.contains(source.name))
          .toList();

      // 使用带进度的流式API，传入当前集号
      final n = _episodeController.currentEpisodeNumbersAgainst(
        widget.allEpisodes,
      );
      final currentEpNumber = n.absolute;
      final relativeEpNumber = n.relative;

      final searchName = _buildSearchNameForSources();
      final captchaPreflightKeyword = _buildCaptchaPreflightKeyword();

      if (!mounted || loadToken != _sampleLoadToken) return;

      setState(() {
        _enabledSourceNames = enabledNames;
        _sourceTiers = {for (var s in enabledSources) s.name: s.tier};

        // 初始化所有源的状态为 Pending
        for (final name in enabledNames) {
          _sourceProgressMap[name] = SourceSearchProgress(
            sourceName: name,
            step: SearchStep.pending,
            error: null,
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: null,
            headers: null,
            enableNestedUrl: false,
          );
        }
        _sampleStatusMessageNotifier.value = captchaSources.isEmpty
            ? '正在搜索 ${enabledSources.length} 个源...'
            : '非验证码源先行搜索，验证码源并发预处理中...';
      });

      if (captchaSources.isNotEmpty) {
        setState(() {
          for (final source in captchaSources) {
            _sourceProgressMap[source.name] = SourceSearchProgress(
              sourceName: source.name,
              step: SearchStep.searching,
              error: null,
              playPageUrl: null,
              videoRegex: null,
              directVideoUrl: null,
              cookies: null,
              headers: null,
              captchaConfigJson: source.captchaConfigJson,
              enableNestedUrl: false,
            );
          }
        });
      }

      if (nonCaptchaSources.isNotEmpty) {
        _launchSearchStream(
          searchName: searchName,
          currentEpNumber: currentEpNumber,
          relativeEpNumber: relativeEpNumber,
          runtimeOverrides: [],
          targetSources: nonCaptchaSources.map((source) => source.name).toSet(),
          loadToken: loadToken,
          streamTag: 'non-captcha',
        );
      }

      for (final source in captchaSources) {
        _queueSearchCaptchaPreflightTask(
          source: source,
          searchKeyword: captchaPreflightKeyword,
          loadToken: loadToken,
          onCompleted: (runtimeOverride) {
            if (!mounted || loadToken != _sampleLoadToken) {
              return;
            }
            if (runtimeOverride.skipSearchError != null) {
              _maybeFinishSampleSearch();
              return;
            }
            _startCaptchaSourceSearch(
              source: source,
              runtimeOverride: runtimeOverride,
              searchName: searchName,
              currentEpNumber: currentEpNumber,
              relativeEpNumber: relativeEpNumber,
              loadToken: loadToken,
            );
          },
        );
      }

      _scheduleWebViewPoolPump();
      _maybeFinishSampleSearch();
    } catch (e) {
      debugPrint("Error loading Sample source: $e");
      if (mounted && loadToken == _sampleLoadToken) {
        setState(() {
          _sampleError = e.toString();
          _isLoadingSample = false;
        });
      }
    }
  }

  String _buildSourceChannelKey(String sourceName, BigInt? channelIndex) {
    return SourceChannelKey(
      sourceName: sourceName,
      channelIndex: channelIndex,
    ).toPageKey();
  }

  Map<String, String> _buildPlaybackHeaders(SearchPlayResult source) {
    final headers = <String, String>{
      if (source.headers != null) ...source.headers!,
    };
    headers.putIfAbsent(
      'User-Agent',
      () =>
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );
    if (!headers.containsKey('Referer') && !headers.containsKey('referer')) {
      headers['Referer'] = source.playPageUrl;
    }
    return headers;
  }

  Map<String, String> _buildProbeHeaders(SearchPlayResult source) {
    final headers = <String, String>{
      if (source.headers != null) ...source.headers!,
    };
    headers.remove('Referer');
    headers.remove('referer');
    headers.putIfAbsent(
      'User-Agent',
      () =>
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );
    return headers;
  }

  bool _containsPlayableSource(SearchPlayResult source) {
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    return _sampleSuccessfulSources.any(
      (item) =>
          _buildSourceChannelKey(item.sourceName, item.channelIndex) ==
          sourceKey,
    );
  }

  void _addPlayableSource(SearchPlayResult source) {
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    if (_playableSourceKeys.add(sourceKey) &&
        !_containsPlayableSource(source)) {
      _sampleSuccessfulSources.add(source);
      _publishPlayerControlSourceState();
    }
  }

  Future<void> _probeAndRegisterPlayableSource(
    SearchPlayResult source, {
    bool autoPlayAfterProbe = false,
  }) async {
    final directVideoUrl = source.directVideoUrl;
    if (directVideoUrl == null || directVideoUrl.isEmpty) {
      return;
    }
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    if (_playableSourceKeys.contains(sourceKey) ||
        _probingSourceKeys.contains(sourceKey)) {
      return;
    }

    _probingSourceKeys.add(sourceKey);
    final probeResult = await _videoUrlProbeService.probe(
      directVideoUrl,
      headers: _buildProbeHeaders(source),
      cookies: source.cookies,
    );
    _probingSourceKeys.remove(sourceKey);

    if (!mounted) {
      return;
    }

    if (!probeResult.playable) {
      debugPrint(
        '[VideoProbe] Rejected ${source.sourceName} channel=${source.channelIndex}: '
        '${probeResult.error} status=${probeResult.statusCode} type=${probeResult.contentType}',
      );
      _failedWebViewPageKeys.add(sourceKey);
      _maybeFinishSampleSearch();
      return;
    }

    debugPrint(
      '[VideoProbe] Accepted ${source.sourceName} channel=${source.channelIndex} '
      'status=${probeResult.statusCode} latency=${probeResult.latency.inMilliseconds}ms',
    );

    setState(() {
      _addPlayableSource(source);
      _sampleStatusMessageNotifier.value =
          '搜索完成，共找到 ${_sampleSuccessfulSources.length} 个可用源';
    });

    if (autoPlayAfterProbe && _autoPlaySearchedSource) {
      _attemptAutoPlay();
    }

    _maybeFinishSampleSearch();
  }

  String _buildPlaybackUrl(SearchPlayResult source) {
    final urlToPlay = source.directVideoUrl!;
    final needsReferer = _needsRefererHeader(urlToPlay);
    if (!needsReferer) {
      debugPrint('[_buildPlaybackUrl] Using direct URL for: $urlToPlay');
      return urlToPlay;
    }

    final finalUrl = _headerProxy.registerUrl(
      urlToPlay,
      _buildPlaybackHeaders(source),
    );
    debugPrint('[_buildPlaybackUrl] Using proxy for: $urlToPlay');
    return finalUrl;
  }

  void _clearPlaybackStartupWatchdog() {
    _playStartupTimer?.cancel();
    _playStartupTimer = null;
    _pendingPlaySourceKey = null;
  }

  void _schedulePlaybackStartupWatchdog(
    SearchPlayResult source, {
    required bool autoFallback,
  }) {
    _clearPlaybackStartupWatchdog();
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );
    _pendingPlaySourceKey = sourceKey;
    _playStartupTimer = Timer(_autoPlayStartupTimeout, () {
      if (!mounted || _pendingPlaySourceKey != sourceKey) {
        return;
      }
      final hasStarted =
          _player.state.playing || _player.state.position > Duration.zero;
      if (hasStarted) {
        _clearPlaybackStartupWatchdog();
        return;
      }
      debugPrint('[PlaybackWatchdog] Startup timed out for $sourceKey');
      _clearPlaybackStartupWatchdog();
      _failedPlaybackSourceKeys.add(sourceKey);
      if (autoFallback) {
        _attemptAutoPlay(excludedSourceKey: sourceKey, forceRetry: true);
      } else if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _videoError = '当前线路启动超时，请切换其他源';
        });
      }
    });
  }

  Future<void> _openOnlineSource(
    SearchPlayResult source, {
    required bool autoFallback,
  }) async {
    final finalUrl = _buildPlaybackUrl(source);
    final sourceKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );

    setState(() {
      _currentOnlineSource = source;
      _currentStreamUrl = finalUrl;
      _sampleVideoUrl = source.directVideoUrl;
      _playingSourceLabel = source.channelName != null
          ? '${source.sourceName}(${source.channelName})'
          : source.sourceName;
      _isLoadingVideo = true;
      _videoError = null;
    });
    _publishPlayerControlSourceState();

    _temporarilyAllowPositionReset();
    await _player.stop();
    _schedulePlaybackStartupWatchdog(source, autoFallback: autoFallback);

    try {
      await _player.open(Media(finalUrl), play: true);
      await _applyPlaybackSpeed();
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
      await _applyPendingStartPosition();
      debugPrint('[_openOnlineSource] Media loading started for $sourceKey');
    } catch (e, st) {
      debugPrint('[_openOnlineSource] ERROR loading media: $e');
      debugPrint('Stack trace: $st');
      _clearPlaybackStartupWatchdog();
      _failedPlaybackSourceKeys.add(sourceKey);
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _videoError = '播放失败: $e';
        });
      }
      if (autoFallback) {
        _attemptAutoPlay(excludedSourceKey: sourceKey, forceRetry: true);
      }
    }
  }

  Future<void> _resolveChannelPlayPageUrl({
    required String sourceName,
    required String animeName,
    required BigInt channelIndex,
    required int episodeNumber,
    required String channelName,
    required String videoRegex,
    String? cookies,
    Map<String, String>? headers,
    String? searchPageHtml,
    String? searchPageUrl,
    String? detailPageHtml,
    String? detailPageUrl,
  }) async {
    final pageKey = _buildSourceChannelKey(sourceName, channelIndex);
    if (_resolvingChannelPlayPageKeys.contains(pageKey)) {
      return;
    }

    final hasAnyCaptchaContext =
        cookies != null ||
        searchPageHtml != null ||
        searchPageUrl != null ||
        detailPageHtml != null ||
        detailPageUrl != null;
    final runtimeOverride = hasAnyCaptchaContext
        ? SourceRuntimeOverride(
            sourceName: sourceName,
            cookies: cookies,
            searchPageHtml: searchPageHtml,
            searchPageUrl: searchPageUrl,
            detailPageHtml: detailPageHtml,
            detailPageUrl: detailPageUrl,
          )
        : null;

    _resolvingChannelPlayPageKeys.add(pageKey);
    try {
      final resolved = await getEpisodePlayUrl(
        sourceName: sourceName,
        animeName: animeName,
        channelIndex: channelIndex,
        episodeNumber: episodeNumber,
        runtimeOverride: runtimeOverride,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final mergedHeaders = <String, String>{};
        if (headers != null) {
          mergedHeaders.addAll(headers);
        }
        if (resolved.headers != null) {
          mergedHeaders.addAll(resolved.headers!);
        }

        final channelResult = SearchPlayResult(
          sourceName: sourceName,
          playPageUrl: resolved.playPageUrl,
          videoRegex: resolved.videoRegex.isNotEmpty
              ? resolved.videoRegex
              : videoRegex,
          directVideoUrl: resolved.directVideoUrl,
          cookies: resolved.cookies ?? cookies,
          headers: mergedHeaders.isEmpty ? null : mergedHeaders,
          channelName: channelName,
          channelIndex: channelIndex,
          captchaConfigJson: resolved.captchaConfigJson,
          enableNestedUrl: resolved.enableNestedUrl,
          matchNestedUrl: resolved.matchNestedUrl,
        );

        final existingIndex = _samplePlayPages.indexWhere(
          (page) =>
              _buildSourceChannelKey(page.sourceName, page.channelIndex) ==
              pageKey,
        );

        if (existingIndex >= 0) {
          _samplePlayPages[existingIndex] = channelResult;
        } else {
          _addSamplePlayPage(channelResult);
        }

        if (channelResult.directVideoUrl != null &&
            channelResult.directVideoUrl!.isNotEmpty) {
          unawaited(
            _probeAndRegisterPlayableSource(
              channelResult,
              autoPlayAfterProbe: true,
            ),
          );
        }

        _samplePlayPages.sort((a, b) {
          final tierA = _sourceTiers[a.sourceName] ?? 999;
          final tierB = _sourceTiers[b.sourceName] ?? 999;
          return tierA.compareTo(tierB);
        });
      });
    } catch (e, st) {
      debugPrint(
        '[Channel Resolve] Failed to resolve play page for $sourceName channel=$channelName($channelIndex): $e\n$st',
      );
    } finally {
      _resolvingChannelPlayPageKeys.remove(pageKey);
      if (mounted) {
        _startNextWebViewExtraction();
      }
    }
  }

  void _attemptAutoPlay({String? excludedSourceKey, bool forceRetry = false}) {
    // Don't auto-play if already playing something (including BT)
    if (!forceRetry &&
        (_hasAutoPlayed ||
            _sampleVideoUrl != null ||
            _currentStreamUrl != null)) {
      return;
    }

    if (_isAutoPlayFallbackInProgress) {
      return;
    }

    // 仅允许Tier 0自动播放
    final candidates = _sampleSuccessfulSources.where((s) {
      final sourceKey = _buildSourceChannelKey(s.sourceName, s.channelIndex);
      return (_sourceTiers[s.sourceName] ?? 999) == 0 &&
          sourceKey != excludedSourceKey &&
          !_failedPlaybackSourceKeys.contains(sourceKey);
    }).toList();

    debugPrint(
      "[_attemptAutoPlay] Found ${candidates.length} Tier 0 candidates. Total sources: ${_sampleSuccessfulSources.length}",
    );

    if (candidates.isNotEmpty) {
      _playSource(candidates.first);
    }
  }

  /// 一旦某 Tier-0 源被接受并开始播放，取消其他低优先级（仍在运行或在队列中）
  /// 提取任务以释放并发槽位，并阻止它们的迟到 onResult 触发 probe/autoplay。
  /// 已完成的发现结果（`_samplePlayPages`/`_sampleSuccessfulSources`）保持不变。
  ///
  /// 取消策略（tiers-aware）：只取消非 Tier-0 源的任务。Tier-0 源是用户配置的
  /// 高优先级源，其提取应跑完以便在源选择器里保留为后备候选。`except` 指向的
  /// 已接受 pageKey 永远不会被取消。与已接受源同名的 channel（即便 Tier 检查
  /// 不变）也会因 Tier 仍为 0 而继续，从而保证同源其他 channel 的迟到结果能
  /// 正常流过 `_onWebViewResult` 注册到源列表。
  ///
  /// 拆解机制说明：`WebViewVideoExtractorWidget` 由 `_buildWebViewExtractors`
  /// 构建并以子节点形式存活在 widget 树里。从这里只能拿到 pageKey 而无法直接
  /// 拿到它们的 State 句柄，因此真正的拆解靠三件事：(a) 下面从 `_activeWebViews`
  /// 等记账中移除，(b) `_onWebViewResult` 里的 late-callback 守卫跳过 probe，以及
  /// (c) 下次 build 因为子节点不在列表里触发的 dispose-on-unmount（会进入
  /// `State.dispose` 取消 `_timeoutTimer` 并清理 cookie）。worker 上新增的
  /// `cancel()` 方法为未来可拿到句柄时预留，本步骤不调用。
  void _cancelLowerPriorityExtraction({required String except}) {
    // 按 sourceName 查 tier 决定是否取消。Tier-0 源（包括 accepted 同源其他 channel
    // 和其他 Tier-0 源）永不取消，仅取消 tier >= 1 的非 Tier-0 源。
    bool isCancellableBySourceName(String sourceName) {
      if (sourceName == SourceChannelKey.fromPageKey(except).sourceName) {
        return false;
      }
      return (_sourceTiers[sourceName] ?? 999) != 0;
    }

    // (a) 清理待处理 captcha 任务。captcha taskKey 是 'search:源名' 格式，与
    //     WebView pageKey 命名空间不同，不能用 fromPageKey 反解；直接用
    //     task.source.name 查 tier。
    final cancellablePendingCaptcha = _pendingCaptchaTasks
        .where((task) => isCancellableBySourceName(task.source.name))
        .toList();
    for (final task in cancellablePendingCaptcha) {
      _webviewStats.onCaptchaJobCancelledWhilePending(
        task.taskKey,
        task.source.name,
      );
    }
    _pendingCaptchaTasks.removeWhere(
      (task) => isCancellableBySourceName(task.source.name),
    );

    // (b) 取消活动 captcha 任务：从记账中移除，后续 onResult 因 task == null
    //     提前返回。仅取消非 Tier-0 源的任务。
    final captchaKeys = _activeCaptchaTasks.entries
        .where((e) => isCancellableBySourceName(e.value.source.name))
        .map((e) => e.key)
        .toList();
    for (final key in captchaKeys) {
      final task = _activeCaptchaTasks.remove(key);
      if (task != null) {
        _webviewStats.onCaptchaJobCancelled(key, task.source.name);
      }
      _scheduler.cancelCaptchaSlot(key);
      _webViewStatus.remove(key);
    }

    // (c) 取消活动 WebView 提取任务：从记账中移除并标记为失败键，防止
    //     `_collectPendingWebViewExtractionTasks` 通过 `alreadyFailed` 检查
    //     重新排队。WebView key 是 pageKey 格式，用 fromPageKey 反解 sourceName。
    bool isCancellableWebViewKey(String pageKey) {
      if (pageKey == except) return false;
      return isCancellableBySourceName(
        SourceChannelKey.fromPageKey(pageKey).sourceName,
      );
    }

    if (_useWorkerPool) {
      // Pool 模式：把对应 slot 的 pageKey 清 null。下一次 build 时
      // `_buildWebViewExtractors` 会让该 worker 拿到 `job: null`，触发
      // `didUpdateWidget` -> `_cancelCurrentJob(silent: true)` -> onIdle，
      // 后者通过 post-frame 调 [`_onWorkerIdlePostFrame`] 完成空 pump。
      // 调度器侧此处同步移除 `_scheduler.activeVideoJobs[pageKey]` 让后续
      // pump/统计立刻看到槽位空闲，避免一帧延迟期间重复派活。
      final videoPageKeys = _scheduler.activeVideoJobs.keys
          .where(isCancellableWebViewKey)
          .toList();
      for (final pageKey in videoPageKeys) {
        _scheduler.cancelVideoJob(pageKey);
        _webViewStatus.remove(pageKey);
        _failedWebViewPageKeys.add(pageKey);
        final srcName = SourceChannelKey.fromPageKey(pageKey).sourceName;
        _webviewStats.onVideoJobCancelled(pageKey, srcName);
      }
    } else {
      // Legacy 路径：靠 widget unmount 触发 dispose 取消 `_timeoutTimer`，并
      // 由 `_onWebViewResult` 的 tier guard 跳过迟到 probe/autoplay。
      final webViewKeys = _activeWebViews.keys
          .where(isCancellableWebViewKey)
          .toList();
      for (final key in webViewKeys) {
        final srcName = SourceChannelKey.fromPageKey(key).sourceName;
        _webviewStats.onVideoJobCancelled(key, srcName);
        _activeWebViews.remove(key);
        _webViewStatus.remove(key);
        _failedWebViewPageKeys.add(key);
      }
    }
    _logSchedulerState('cancelLowerPriority');
  }

  void _playSource(SearchPlayResult source) {
    debugPrint(
      "Auto-playing source: ${source.sourceName} (Tier ${_sourceTiers[source.sourceName]})",
    );

    final acceptedKey = _buildSourceChannelKey(
      source.sourceName,
      source.channelIndex,
    );

    setState(() {
      if (_cancelLowPrioritySourcesOnPlay) {
        _acceptedSourcePageKey = acceptedKey;
        _cancelLowerPriorityExtraction(except: acceptedKey);
      }
      _hasAutoPlayed = true;
      // Ensure index is correct in the display list
      _selectedSourceIndex = _sampleSuccessfulSources.indexOf(source);
      if (_selectedSourceIndex == -1) {
        // Should not happen if source is from _sampleSuccessfulSources
        _selectedSourceIndex = 0;
      }
      _selectedSourceIndexNotifier.value = _selectedSourceIndex;
    });

    // freed slots can be reused (or stay empty — either way the pump must run
    // to avoid stale entries).
    _scheduleWebViewPoolPump(immediate: true);

    _isAutoPlayFallbackInProgress = true;
    unawaited(
      _openOnlineSource(source, autoFallback: true).whenComplete(() {
        _isAutoPlayFallbackInProgress = false;
      }),
    );
  }

  /// WebView 提取结果回调（并发版本）
  void _onWebViewResult(String pageKey, VideoExtractResult result) {
    debugPrint(
      '[_onWebViewResult] pageKey=$pageKey, success=${result.success}, '
      'timedOut=${result.timedOut}, videoUrl=${result.videoUrl}, '
      'error=${result.error}',
    );
    if (!mounted) return;

    final sourceNameForKey = SourceChannelKey.fromPageKey(pageKey).sourceName;

    setState(() {
      _recordVideoWorkerResult(pageKey, result);
      // 旧 [per-task] 路径在收到 result 时立即从 `_activeWebViews` 释放槽位；
      // pool 模式下由 [`_onWorkerIdle`] 在 worker 完成（或被取消）后统一释放
      // `_scheduler.activeVideoJobs` + slot 记账，避免在此处提前释放导致
      // build 阶段
      // 反查失配。
      if (!_useWorkerPool) {
        _activeWebViews.remove(pageKey);
      }
      _webViewStatus.remove(pageKey);

      // Late-callback no-op guard: 一旦某 Tier-0 源被接受并开始播放，任何其他
      // （刚被 `_cancelLowerPriorityExtraction` 取消的）非 Tier-0 提取任务的迟到
      // 结果都不得触发 probe/register/auto-play，否则会劫持当前播放。Tier-0 源
      // （含已接受源的其他 channel 与其他 Tier-0 源的 channel）的迟到结果仍按正常
      // 流程走 probe/register 以填充源列表作为后备。这里仍然清理上面的记账以释放
      // 并发槽位，然后只需更新状态、泵送任务池并提前返回。
      final tier = _sourceTiers[sourceNameForKey] ?? 999;
      if (isVideoResultLateAfterCancel(
        acceptedSourcePageKey: _acceptedSourcePageKey,
        tier: tier,
      )) {
        _webviewStats.onVideoJobLateAfterCancel(pageKey, sourceNameForKey);
        _failedWebViewPageKeys.add(pageKey);
        final total = _samplePlayPages.length;
        final completed = _sampleSuccessfulSources.length;
        final active = _useWorkerPool
            ? _scheduler.activeVideoJobs.length
            : _activeWebViews.length;
        _sampleStatusMessageNotifier.value =
            '提取中: $completed/$total 完成，$active 并发运行';
        if (!_useWorkerPool) {
          _startNextWebViewExtraction();
        }
        // pool 模式下不在此处 pump: worker 同步在 `_complete` 之后还会调用
        // `widget.onIdle`，[_onWorkerIdle] 会 post-frame 调用
        // `_scheduleWebViewPoolPump(immediate: true)`。
        return;
      }

      _webviewStats.onVideoJobCompleted(
        success: result.success,
        timedOut: result.timedOut,
        pageKey: pageKey,
        sourceName: sourceNameForKey,
      );

      if (!result.success) {
        _failedWebViewPageKeys.add(pageKey);
      }

      if (result.success) {
        final key = SourceChannelKey.fromPageKey(pageKey);
        final sourceName = key.sourceName;
        final channelIndex = key.channelIndex?.toInt();

        // 找到对应的播放页并更新
        final pageIndex = _samplePlayPages.indexWhere((p) {
          final pIdx = p.channelIndex?.toInt();
          return p.sourceName == sourceName && (pIdx == channelIndex);
        });

        debugPrint(
          '[_onWebViewResult] resolved pageIndex=$pageIndex for sourceName=$sourceName channelIndex=$channelIndex',
        );

        if (pageIndex >= 0) {
          final page = _samplePlayPages[pageIndex];
          debugPrint(
            '[_onWebViewResult] matched page: playPageUrl=${page.playPageUrl} channelName=${page.channelName}',
          );

          final updatedPage = buildUpdatedPlayPageFromResult(
            page: page,
            result: result,
          );
          debugPrint(
            '[_onWebViewResult] Captured headers: ${updatedPage.headers?.keys.join(", ")}',
          );

          unawaited(
            _probeAndRegisterPlayableSource(
              updatedPage,
              autoPlayAfterProbe: true,
            ),
          );

          // 如果这是第一个成功提取且没有其他源在播放
          debugPrint(
            '[_onWebViewResult] _sampleVideoUrl currently=$_sampleVideoUrl',
          );
        } else {
          debugPrint(
            '[_onWebViewResult] No matching page found for pageKey=$pageKey',
          );
          // 打印当前的 sample play pages 简要信息，帮助调试匹配失败原因
          try {
            final summary = _samplePlayPages
                .map(
                  (p) =>
                      '${p.sourceName}#${p.channelIndex ?? -1}:${p.playPageUrl}',
                )
                .take(20)
                .join(' | ');
            debugPrint('[_onWebViewResult] _samplePlayPages summary: $summary');
          } catch (e) {
            debugPrint(
              '[_onWebViewResult] Failed to summarize _samplePlayPages: $e',
            );
          }
        }
      }

      // 更新状态消息
      final total = _samplePlayPages.length;
      final completed = _sampleSuccessfulSources.length;
      final active = _useWorkerPool
          ? _scheduler.activeVideoJobs.length
          : _activeWebViews.length;
      _sampleStatusMessageNotifier.value =
          '提取中: $completed/$total 完成，$active 并发运行';

      // 旧路径：立即 pump 下一个 task；pool 模式下 worker 接下来会触发
      // `widget.onIdle`，[`_onWorkerIdle`] 会 post-frame 释放 slot + pump。
      if (!_useWorkerPool) {
        _startNextWebViewExtraction();
      }
    });
    _logSchedulerState('videoResult');
  }

  /// Pool 模式下 video runner 自报 idle 的入口（与 captcha 的
  /// [`_onCaptchaWorkerIdle`] 分开）。可能源自两种路径：
  ///
  /// 1. **Worker 完成/超时/失败**：在
  ///    [`VideoExtractionJobRunner._complete`] 里同步先调用
  ///    `sink.onResult` -> [`_onWebViewResult`]（处理 result 业务逻辑），
  ///    再调用本函数 onIdle（5B step 3 之后由 [`ReusableBrowserWorker`]
  ///    的 `onVideoIdle` 转发）。这里只需要释放 slot 记账并 pump 下一
  ///    个 job。
  /// 2. **Worker 被取消**：当前 job 通过 `didUpdateWidget`（job 从 non-null 变
  ///    null，例如搜索重置、`_cancelLowerPriorityExtraction`、`_useWorkerPool`
  ///    实时切换）触发 `_cancelCurrentJob(silent: true)`，进而同步调用
  ///    [`VideoExtractionJobRunner.cancelCurrentJob`]。本函数仅做 pump。
  ///
  /// 因为路径 2 可能发生在 **build 阶段**（`didUpdateWidget` 内同步），直接
  /// `setState` 会触发 "setState() called during build" 异常。所以统一用
  /// `addPostFrameCallback` 把状态修改 + pump 推迟到本帧结束之后。
  void _onWorkerIdle(int workerId) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onWorkerIdlePostFrame(workerId);
    });
  }

  void _onWorkerIdlePostFrame(int workerId) {
    if (!mounted) return;
    final slot = _scheduler.slotOf(workerId);
    if (slot == null) return;

    // 释放 slot 记账（pageKey/taskKey 通常还没被移除：因为 _onWebViewResult
    // 在 pool 模式下不动它；_cancelLowerPriorityExtraction 已在 setState 内
    // 同步删除但走第 (b) 路径时 onIdle 也是 post-frame 到来，绝不冲突）。已
    // 经清空的字段也安全（null = no-op）。
    final prevPageKey = _scheduler.releaseVideoSlotOnIdle(workerId);
    var needsSetState = false;
    if (prevPageKey != null) {
      _webViewStatus.remove(prevPageKey);
      needsSetState = true;
    }
    final slotAfterHealth = _scheduler.healthOf(workerId);

    if (slotAfterHealth == WebViewWorkerHealth.unhealthy) {
      _scheduler.removeSlot(workerId);
      debugPrint(
        '[WebViewScheduler] rebuilt video worker=$workerId by removing '
        'unhealthy idle slot',
      );
      needsSetState = true;
    } else {
      _scheduler.markSlotIdle(workerId);
    }

    if (_trimIdleWebViewWorkerSlotsToBudget()) {
      needsSetState = true;
    }

    // 让 build 把 worker 切到 idle 状态（emit null job，触发 didUpdateWidget
    // 进入`_cancelCurrentJob` 早返回路径——worker 内部 `_isCompleted=true` 守
    // 卫会直接 short-circuit）。
    if (needsSetState) {
      setState(() {});
    }

    // 继续泵送；下一个 job 可能直接落到本 slot。
    _scheduleWebViewPoolPump(immediate: true);
    _maybeFinishSampleSearch();
    _logSchedulerState('workerIdle#$workerId');
  }

  /// 调试面板 live toggle：实时切换 worker pool / legacy 调度路径。
  ///
  /// 切换时清空两条路径的活跃记账 + 丢掉 pool slot 实例，避免旧路径下的
  /// `_activeWebViews` 残留或 pool 模式下 slot 与 widget 树不对齐。下一帧
  /// 起重按新路径调度；captcha active task 保留，但 slot 反查按目标路径重建。
  void _setUseWorkerPool(bool next) {
    setState(() {
      _useWorkerPool = next;
      _activeWebViews.clear();
      // 把 pool slot 整体丢弃：worker widget 在下次 build 不被 emit → 框架
      // 负责 dispose；scheduler 侧不再引用已 dispose 的 state。
      _scheduler.clearForPoolToggle();
      if (next) {
        for (final task in _activeCaptchaTasks.values) {
          final slot = _acquireIdleCaptchaWorkerSlot();
          if (slot == null) continue;
          _scheduler.startCaptchaJob(slot, task.taskKey, task.source.name);
        }
      }
      _webViewStatus.clear();
    });
    _scheduleWebViewPoolPump(immediate: true);
  }

  /// 启动下一个WebView提取任务
  /// 启动下一个WebView提取任务
  void _startNextWebViewExtraction() {
    _scheduleWebViewPoolPump(immediate: true);
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisode.id != _episodeController.currentEpisode.id) {
      _loadComments();
    }
    if (oldWidget.anime.bangumiId != widget.anime.bangumiId) {
      setState(() {
        _onairSites = [];
      });
      _loadRecommendations();
      _loadOnairSites();
      if (!_disableAutoSourceSearchForCurrentEpisode) {
        _loadMikanSource(); // Anime changed, reload search
        _loadDmhySource();
      }
    } else if (oldWidget.currentEpisode.sort !=
        _episodeController.currentEpisode.sort) {
      // Episode changed, reload resources using existing mikan anime info if available
      unawaited(_handleWidgetEpisodeChanged());
    }
  }

  Future<void> _handleWidgetEpisodeChanged() async {
    final hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    if (!mounted) {
      return;
    }

    setState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    if (hasDownloadedPlayback) {
      return;
    }

    if (_mikanAnime != null) {
      _reloadMikanResourcesForEpisode();
    } else {
      _loadMikanSource();
    }
    _loadDmhySource();
    _loadSampleSource();
  }

  Future<void> _reloadMikanResourcesForEpisode() async {
    debugPrint(
      "[Mikan] Reloading resources for new episode: ${_episodeController.currentEpisode.sort.toInt()}",
    );
    debugPrint("[Mikan] Using existing anime ID: ${_mikanAnime!.id}");

    setState(() {
      _isLoadingMikan = true;
      _mikanResources = []; // Clear previous episode resources
    });
    try {
      final resources = await getMikanResources(
        mikanId: _mikanAnime!.id,
        currentEpisodeSort: _episodeController.currentEpisode.sort.toInt(),
      );
      if (mounted) {
        setState(() {
          _mikanResources = resources;
          _isLoadingMikan = false;
        });
      }
    } catch (e) {
      debugPrint("[Mikan] Error reloading resources: $e");
      if (mounted) {
        setState(() {
          _mikanError = e.toString();
          _isLoadingMikan = false;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      final posMs = (_currentVideoTimeNotifier.value * 1000).toInt();
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: posMs,
      );
    } catch (e) {
      debugPrint('Error saving final playback position: $e');
    }
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _sampleLoadToken++;
    for (final subscription in _searchSubscriptions) {
      unawaited(subscription.cancel());
    }
    _searchSubscriptions.clear();
    _activeCaptchaTasks.clear();
    _pendingCaptchaTasks.clear();
    // Phase 2 B6：清理统一 pool 调度记账。worker widget 在 widget 树卸载时
    // 由框架负责 dispose（含 InAppWebView），scheduler 侧只需清空内部表
    // 以避免后续 post-frame 回调进来时引用已 dispose 的 slot。
    _scheduler.clearForDispose();
    _clearPlaybackStartupWatchdog();

    // 通知下载管理器BT流不再活跃
    if (_currentStreamUrl != null) {
      final btHash = _extractBtHashFromStreamUrl(_currentStreamUrl!);
      if (btHash != null) {
        DownloadManager().setActiveStream(btHash, active: false);
        debugPrint(
          '[Player] Notified DownloadManager: stream inactive for $btHash',
        );
      }
    }

    _mobileTabController.dispose();
    _pcEpisodeScrollController.dispose();
    _mobileEpisodeScrollController.dispose();
    _mobileInfoScrollController.dispose();
    _pcMainScrollController.dispose();
    _pcSidebarScrollController.dispose();
    _commentsScrollController.dispose();
    _subtitleService.dispose();
    _player.stop(); // 确保播放器完全停止后再释放
    _player.dispose();
    _mobilePlayerLockNotifier.dispose();
    _availableSourcesNotifier.dispose();
    _currentVideoTimeNotifier.dispose();
    _isVideoPausedNotifier.dispose();
    _showDanmakuSettingsNotifier.dispose();
    _playingSourceLabelNotifier.dispose();
    _sampleStatusMessageNotifier.dispose();
    _selectedSourceIndexNotifier.dispose();
    _episodeController.clearForDispose();
    _videoTitleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF0F0F13)
        : theme.scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 主界面
          isWide ? _buildPCLayout(context) : _buildMobileLayout(context),

          // 后台WebView容器（始终存在，用于验证码预处理+视频提取）
          Positioned(
            left: 0,
            top: 0,
            width: _showWebView ? 400 : 1,
            height: _showWebView ? 300 : 1,
            child: Visibility(
              visible: _showWebView, // 调试时可以显示
              maintainState: true, // 保持状态，确保WebView在隐藏时仍然运行
              child: Container(
                color: Colors.black,
                child: _buildWebViewExtractors(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Mobile Layout ---
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        // Top: Video Player Area
        SafeArea(
          bottom: false,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildVideoPlayerPlaceholder(context, isMobile: true),
          ),
        ),

        // Metadata / Tabs
        Expanded(
          child: Column(
            children: [
              Container(
                color: isDark
                    ? const Color(0xFF16161E)
                    : theme.colorScheme.surfaceContainerLow,
                child: TabBar(
                  controller: _mobileTabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: isDark
                      ? Colors.grey
                      : theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    const Tab(text: "简介 & 推荐"),
                    Tab(text: "评论 (${_comments.length})"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _mobileTabController,
                  children: [
                    _buildMobileInfoTab(context),
                    _buildCommentsTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileInfoTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final descBgColor = isDark
        ? const Color.fromARGB(255, 20, 20, 25)
        : theme.colorScheme.surfaceContainerHigh;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);
    return SingleChildScrollView(
      controller: _mobileInfoScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anime Title
          Text(
            widget.anime.title,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Episode Info
          Text(
            _episodeController.currentEpisode.nameCn.isNotEmpty
                ? _episodeController.currentEpisode.nameCn
                : _episodeController.currentEpisode.name,
            style: TextStyle(
              color: subTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "EP ${_episodeController.currentEpisode.sort % 1 == 0 ? _episodeController.currentEpisode.sort.toInt() : _episodeController.currentEpisode.sort}",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${_episodeController.playableEpisodes.length} Episodes",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              _buildCurrentSourceActionButtons(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          // Description (Mobile)
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: descBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _episodeController.currentEpisode.description.isNotEmpty
                        ? _episodeController.currentEpisode.description
                        : "暂无简介",
                    maxLines: _isDescriptionExpanded ? null : 2,
                    overflow: _isDescriptionExpanded
                        ? null
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (_episodeController.currentEpisode.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _isDescriptionExpanded ? "收起" : "展开",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            _isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Episodes Grid (Horizontal or collapsed)
          InkWell(
            onTap: () {
              setState(() {
                _isEpisodesExpanded = !_isEpisodesExpanded;
                if (_isEpisodesExpanded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_mobileEpisodeScrollController.hasClients) {
                      final index = _episodeController.playableEpisodes.indexOf(
                        _episodeController.currentEpisode,
                      );
                      if (index != -1) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        // Item width 140 + separator 12 = 152
                        final targetOffset =
                            (index * 152.0) -
                            (screenWidth / 2) +
                            (140 / 2) +
                            16; // 16 is padding

                        _mobileEpisodeScrollController.animateTo(
                          targetOffset.clamp(
                            0.0,
                            _mobileEpisodeScrollController
                                .position
                                .maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                  });
                }
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                // Custom implementation of section header style
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "选集",
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isEpisodesExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDark ? Colors.white70 : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isEpisodesExpanded)
            SizedBox(
              height: 138,
              child: Scrollbar(
                controller: _mobileEpisodeScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _mobileEpisodeScrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _episodeController.playableEpisodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ep = _episodeController.playableEpisodes[index];
                    final isSelected = ep == _episodeController.currentEpisode;
                    final borderColor = isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.outlineVariant);
                    final epTextColor = isDark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface;
                    final epCardColor = isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12)
                        : (isDark
                              ? const Color(0xFF1B1D28)
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow);
                    final epIndexColor = isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isDark
                              ? Colors.white70
                              : Theme.of(context).colorScheme.onSurfaceVariant);
                    final epMetaColor = isDark
                        ? Colors.white54
                        : Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.85);

                    return Material(
                      color: epCardColor,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: !isSelected
                            ? () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => PlayerPage(
                                      anime: widget.anime,
                                      currentEpisode: ep,
                                      allEpisodes:
                                          _episodeController.playableEpisodes,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}",
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : epIndexColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (ep.name.isNotEmpty)
                                Text(
                                  ep.name,
                                  style: TextStyle(
                                    color: epTextColor.withValues(alpha: 0.7),
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (ep.nameCn.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  ep.nameCn,
                                  style: TextStyle(
                                    color: epTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const Spacer(),
                              if (ep.airdate.isNotEmpty)
                                Text(
                                  ep.airdate,
                                  style: TextStyle(
                                    color: epMetaColor,
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Play Source Control
          _buildSectionHeader("播放源"),
          const SizedBox(height: 12),
          _buildPlaySourceSelector(isMobile: true),
          const SizedBox(height: 12),
          _buildResourceList(),
          const SizedBox(height: 24),

          if (_onairSites.isNotEmpty) ...[
            _buildSectionHeader("官方播放源"),
            const SizedBox(height: 12),
            _buildOnairSitesList(),
            const SizedBox(height: 24),
          ],

          // Recommendations
          _buildSectionHeader("相关推荐"),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlayerRecommendations(
              recommendations: _recommendations,
              isLoading: _isLoadingRecommendations,
              isVertical: false,
              onItemTap: _navigateToAnime,
            ),
          ),
        ],
      ),
    );
  }

  // --- PC Layout ---
  Widget _buildPCLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF0F0F13)
        : theme.scaffoldBackgroundColor;
    final sidebarColor = isDark
        ? const Color(0xFF13131A)
        : theme.colorScheme.surfaceContainerLow;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);

    return Row(
      children: [
        // Main Content (Left)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Title moved above player (Fixed Header)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                color: bgColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: textColor,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.anime.title,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "EP ${_episodeController.currentEpisode.sort % 1 == 0 ? _episodeController.currentEpisode.sort.toInt() : _episodeController.currentEpisode.sort} - ${_episodeController.currentEpisode.nameCn.isNotEmpty ? _episodeController.currentEpisode.nameCn : _episodeController.currentEpisode.name}",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildCurrentSourceActionButtons(),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: CustomScrollView(
                  controller: _pcMainScrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Video Player (Large)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: Colors.black,
                                  child: _buildVideoPlayerPlaceholder(
                                    context,
                                    isMobile: false,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Video Info Bar & Actions (Description & Stats)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            color: bgColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Action Buttons Removed
                                /*
                                Row(
                                  children: [
                                    _buildPCActionButton(
                                      Icons.thumb_up_alt_outlined,
                                      "23k",
                                    ),
                                    const SizedBox(width: 16),
                                    _buildPCActionButton(
                                      Icons.favorite_border,
                                      "Collect",
                                    ),
                                    const SizedBox(width: 16),
                                    _buildPCActionButton(Icons.share, "Share"),
                                    const Spacer(),
                                    // Date or other metadata can go here
                                  ],
                                ),
                                const SizedBox(height: 16),
                                */

                                // Collapsible Description
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isDescriptionExpanded =
                                          !_isDescriptionExpanded;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color.fromARGB(
                                              255,
                                              20,
                                              20,
                                              25,
                                            )
                                          : theme
                                                .colorScheme
                                                .surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _episodeController
                                                  .currentEpisode
                                                  .description
                                                  .isNotEmpty
                                              ? _episodeController
                                                    .currentEpisode
                                                    .description
                                              : "暂无简介",
                                          maxLines: _isDescriptionExpanded
                                              ? null
                                              : 2,
                                          overflow: _isDescriptionExpanded
                                              ? null
                                              : TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                        if (_episodeController
                                            .currentEpisode
                                            .description
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _isDescriptionExpanded
                                                      ? "收起"
                                                      : "展开",
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Icon(
                                                  _isDescriptionExpanded
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons
                                                            .keyboard_arrow_down,
                                                  size: 16,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Play Source
                                _buildSectionHeader("播放源"),
                                const SizedBox(height: 12),
                                _buildPlaySourceSelector(isMobile: false),
                                const SizedBox(height: 12),
                                _buildResourceList(),
                                if (_onairSites.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildSectionHeader("官方播放源"),
                                  const SizedBox(height: 12),
                                  _buildOnairSitesList(),
                                ],
                              ],
                            ),
                          ),
                          Divider(height: 1, color: borderColor),
                        ],
                      ),
                    ),

                    // Comments Section (Sliver)
                    // Comments Section Header
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              "评论区",
                              trailing: _buildSortButton(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Loading / Empty / List States
                    if (_isLoadingComments)
                      const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (_commentsError != null)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              "加载失败: $_commentsError",
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      )
                    else if (_comments.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              "暂无评论",
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return PlayerComments.buildItem(
                              context,
                              _comments[index],
                            );
                          }, childCount: _comments.length),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sidebar (Right)
        Container(
          width: 380,
          color: sidebarColor,
          child: CustomScrollView(
            controller: _pcSidebarScrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader("播放列表"),
                    const SizedBox(height: 12),
                    Text(
                      "选集",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              // Episode List (Fixed height or scrollable)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 500),
                    child: _buildPCEpisodeList(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _buildSectionHeader("相关推荐"),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PlayerRecommendations(
                        recommendations: _recommendations,
                        isLoading: _isLoadingRecommendations,
                        isVertical: true,
                        onItemTap: _navigateToAnime,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Shared Components ---

  Widget _buildPCEpisodeList() {
    // Vertical list for PC
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E1E2C)
        : theme.colorScheme.surfaceContainer;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final mutedTextColor = isDark
        ? Colors.white54
        : theme.colorScheme.onSurfaceVariant;
    final faintTextColor = isDark
        ? Colors.white24
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    return Scrollbar(
      controller: _pcEpisodeScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        shrinkWrap: true,
        controller: _pcEpisodeScrollController,
        padding: const EdgeInsets.only(right: 12), // space for scrollbar
        itemCount: _episodeController.playableEpisodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ep = _episodeController.playableEpisodes[index];
          final isSelected = ep == _episodeController.currentEpisode;
          final epCardColor = isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : cardColor;

          return Container(
            decoration: BoxDecoration(
              color: epCardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => _onEpisodeSelected(ep),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        "${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}",
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : subTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ep.nameCn.isNotEmpty)
                            Text(
                              ep.nameCn,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : textColor,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (ep.name.isNotEmpty)
                            Text(
                              ep.name,
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (ep.airdate.isNotEmpty)
                      Text(
                        ep.airdate,
                        style: TextStyle(color: faintTextColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSkipNext() {
    final next = _episodeController.resolveByOffset(1);
    if (next != null) _onEpisodeSelected(next);
  }

  Future<void> _onEpisodeSelected(BangumiEpisode ep) async {
    final result = _episodeController.selectEpisode(ep);
    if (!result.changed) return;

    // Stop current player
    _player.stop();
    _sampleLoadToken++;
    final subscriptions = List<StreamSubscription<SourceSearchProgress>>.from(
      _searchSubscriptions,
    );
    _searchSubscriptions.clear();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }

    // Update current episode and reset all states
    setState(() {
      // Reset video playback state
      _currentStreamUrl = null;
      _sampleVideoUrl = null;
      _currentOnlineSource = null;
      _videoError = null;
      _isLoadingVideo = false;
      _loadingMagnet = null;
      _playingSourceLabel = 'Switching...';

      // Reset all source states
      _isLoadingMikan = false;
      _mikanError = null;
      _mikanResources = [];

      _isLoadingDmhy = false;
      _dmhyError = null;
      _dmhyResources = [];

      _isLoadingSample = false;
      _sampleError = null;
      _samplePlayPages = [];
      _sampleSuccessfulSources = [];
      _pageEnqueueSeq.clear();
      _nextPageEnqueueSeq = 0;
      _selectedSourceIndex = 0;
      _activeWebViews.clear();
      // Phase 2 B6：与 `_loadSampleSource` 对齐，清除统一 pool 记账并保留
      // slot 实例以便 InAppWebView 跨搜索复用（scheduler 内部完成）。
      _activeCaptchaTasks.clear();
      _scheduler.resetForNewSearch();
      _pendingCaptchaTasks.clear();
      _webViewStatus.clear();
      _failedWebViewPageKeys.clear();
      _resolvingChannelPlayPageKeys.clear();
      _sampleStatusMessageNotifier.value = '';
      _sourceProgressMap = {};
      _captchaRuntimeOverrides = {};
      _enabledSourceNames = [];
      _sourceTiers = {};
      _hasAutoPlayed = false;
      _acceptedSourcePageKey = null;
      _webviewStats.reset();

      // Reset comments
      _comments = [];
      _isLoadingComments = false;
      _commentsError = null;
    });
    _videoTitleNotifier.value = '${widget.anime.title} - 第${ep.sort.toInt()}集';
    _publishPlayerControlSourceState();

    _savePlaybackHistory();

    // Clear and reload danmaku
    _danmakuService.clearDanmaku();
    _loadDanmaku();

    // Reload comments
    _loadComments();

    // If this episode already has a BT download ready, play it immediately.
    // This mirrors initState's behavior — without it, switching to an already
    // downloaded episode would silently fall through to Mikan/DMHY/sample
    // search even though a local stream is available.
    final hasDownloadedPlayback = await _checkAndPlayExistingBtDownload();
    if (!mounted) {
      return;
    }

    setState(() {
      _disableAutoSourceSearchForCurrentEpisode = hasDownloadedPlayback;
      if (hasDownloadedPlayback) {
        _sampleStatusMessageNotifier.value = '已播放本地资源，可手动搜索在线源';
      }
    });

    if (hasDownloadedPlayback) {
      return;
    }

    // Reload video sources
    if (_mikanAnime != null) {
      _reloadMikanResourcesForEpisode();
    } else {
      _loadMikanSource();
    }
    _loadDmhySource();
    _loadSampleSource();
  }

  void _savePlaybackHistory() {
    try {
      final posMs = (_currentVideoTimeNotifier.value * 1000).toInt();
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: posMs,
      );
      _lastSavedPositionMs = posMs;
    } catch (e) {
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _episodeController.currentEpisode,
        allEpisodes: widget.allEpisodes,
      );
    }
  }

  /// Check if a URL needs Referer header based on domain
  bool _needsRefererHeader(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();

    // List of domains that require Referer header
    final refererRequiredDomains = [
      'vbing.me',
      'libvio',
      'v.cdnlz',
      // Add more domains here as needed
    ];

    return refererRequiredDomains.any((domain) => host.contains(domain));
  }

  // Notifier for source index to bypass Video widget rebuild issues
  late final ValueNotifier<int> _selectedSourceIndexNotifier = ValueNotifier(0);

  void _publishPlayerControlSourceState() {
    final nextSourceIndex = _sampleSuccessfulSources.isEmpty
        ? 0
        : _selectedSourceIndex.clamp(0, _sampleSuccessfulSources.length - 1);
    _selectedSourceIndex = nextSourceIndex;
    _selectedSourceIndexNotifier.value = nextSourceIndex;
    _availableSourcesNotifier.value = List<SearchPlayResult>.unmodifiable(
      _sampleSuccessfulSources,
    );
    _playingSourceLabelNotifier.value = _playingSourceLabel;
  }

  void _onSourceSelected(int index) {
    if (index < 0 || index >= _sampleSuccessfulSources.length) return;

    final source = _sampleSuccessfulSources[index];
    if (source.directVideoUrl == null) return;

    setState(() {
      _selectedSourceIndex = index;
      _selectedSourceIndexNotifier.value = index;
      _sampleVideoUrl = source.directVideoUrl;
      _playingSourceLabel = source.sourceName;
      // We no longer set _currentStreamUrl or call _player.open here.
      // This allows the user to click and see selection without loading the data.
    });
    _publishPlayerControlSourceState();
    debugPrint(
      '[_onSourceSelected] Source $index selected: ${source.sourceName}',
    );
  }

  void _startPlaybackFromSelectedSource() {
    if (_selectedSourceIndex < 0 ||
        _selectedSourceIndex >= _sampleSuccessfulSources.length) {
      return;
    }

    final source = _sampleSuccessfulSources[_selectedSourceIndex];
    if (source.directVideoUrl == null) return;

    // Save current position for resuming playback after source switch
    // Check if we are actually playing something (duration > 0)
    if (_player.state.duration > Duration.zero) {
      final currentPos = _player.state.position.inMilliseconds;
      // Only resume if played more than 1 second to avoid resume-loop at start
      if (currentPos > 1000) {
        _pendingStartPositionMs = currentPos;
        debugPrint(
          '[_startPlayback] Will resume from: ${_pendingStartPositionMs}ms',
        );
      }
    }

    unawaited(_openOnlineSource(source, autoFallback: false));
  }

  Widget _buildVideoPlayerPlaceholder(
    BuildContext context, {
    required bool isMobile,
  }) {
    // If player is initialized and we have a stream, show actual player
    if (_isPlayerInitialized && _currentStreamUrl != null) {
      // Use ListenableBuilder to rebuild when subtitle settings change
      return ListenableBuilder(
        listenable: _subtitleService,
        builder: (context, _) {
          final subtitleSettings = _subtitleService.settings;
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _markUserInteraction(),
            onPointerMove: (_) => _markUserInteraction(),
            onPointerUp: (_) => _markUserInteraction(),
            child: Video(
              controller: _videoController,
              subtitleViewConfiguration: SubtitleViewConfiguration(
                visible: subtitleSettings.enabled,
                style: subtitleSettings.toTextStyle(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  subtitleSettings.bottomPadding,
                ),
              ),
              controls: (state) => CustomVideoControls(
                state: state,
                isMobile: isMobile,
                danmakuService: _danmakuService,
                subtitleService: _subtitleService,
                currentVideoTimeListenable: _currentVideoTimeNotifier,
                isVideoPausedListenable: _isVideoPausedNotifier,
                showDanmakuSettingsListenable: _showDanmakuSettingsNotifier,
                onToggleDanmakuSettings: () =>
                    _showDanmakuSettingsNotifier.value =
                        !_showDanmakuSettingsNotifier.value,
                allEpisodes: _episodeController.playableEpisodes,
                currentEpisode: _episodeController.currentEpisode,
                currentEpisodeListenable:
                    _episodeController.currentEpisodeListenable,
                onEpisodeSelected: _onEpisodeSelected,
                isAutoPlayNextEnabled: _isAutoPlayNextEnabled,
                onToggleAutoPlayNext: () {
                  final newValue = !_isAutoPlayNextEnabled;
                  setState(() {
                    _isAutoPlayNextEnabled = newValue;
                  });
                  _saveAutoPlaySetting(newValue);
                },
                playbackSpeed: _playbackSpeed,
                onPlaybackSpeedChanged: _onPlaybackSpeedChanged,
                availableSources: _sampleSuccessfulSources,
                availableSourcesListenable: _availableSourcesNotifier,
                sourceIndexNotifier: _selectedSourceIndexNotifier,
                currentSourceLabel: _playingSourceLabel,
                currentSourceLabelListenable: _playingSourceLabelNotifier,
                onSourceSelected: (index) {
                  _onSourceSelected(index);
                  _startPlaybackFromSelectedSource();
                },
                isLoading: _isLoadingVideo || _loadingMagnet != null,
                onUserInteraction: _markUserInteraction,
                mobilePlayerLockNotifier: _mobilePlayerLockNotifier,
                videoTitle: _videoTitleNotifier.value,
                videoTitleListenable: _videoTitleNotifier,
              ),
            ),
          );
        },
      );
    }

    // Placeholder when no video is playing
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF1A1A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Loading state
        if (_isLoadingVideo || _loadingMagnet != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 16),
                Text("正在初始化播放...", style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text(
                  "正在连接种子网络...",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          )
        // Error state
        else if (_videoError != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  "播放失败",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _videoError!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          )
        // Default placeholder
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  "选择播放源开始观看",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "在下方「播放源」中选择资源",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Header Overlay (Top) - Fixed for mobile
        if (isMobile)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSortButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (_commentSortMode != value) {
          setState(() {
            _commentSortMode = value;
            _sortComments();
          });
        }
      },
      position: PopupMenuPosition.under,
      color: isDark
          ? const Color(0xFF1E1E2C)
          : theme.colorScheme.surfaceContainer,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'default',
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                "默认排序",
                style: TextStyle(
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'time',
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                "按时间排序",
                style: TextStyle(
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            color: isDark ? Colors.white54 : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            _commentSortMode == 'default' ? "默认排序" : "按时间排序",
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ] else ...[
          const Spacer(),
        ],
      ],
    );
  }

  Widget _buildPlaySourceSelector({required bool isMobile}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);
    final btCount = dedupBtResources([
      ..._mikanResources,
      ..._dmhyResources,
    ]).length;
    final onlineCount = _sampleSuccessfulSources.length;
    final currentLabel = _playingSourceLabel;

    if (!_isSourceControlExpanded) {
      return InkWell(
        onTap: () => setState(() => _isSourceControlExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color.fromARGB(255, 20, 20, 25)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: isMobile
                    ? Row(
                        children: [
                          Text(
                            "已找到 ",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "$btCount",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.download_for_offline,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$onlineCount",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.subscriptions,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "当前：$currentLabel",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "已找到 $btCount 个BT源， $onlineCount 个订阅源，当前源：$currentLabel",
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2C)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSourceTab("BT", "bt")),
          Container(
            width: 1,
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.3),
          ),
          Expanded(child: _buildSourceTab("订阅源", "sample")),
          InkWell(
            onTap: () => setState(() => _isSourceControlExpanded = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              alignment: Alignment.center,
              child: Icon(
                Icons.keyboard_arrow_up,
                color: isDark ? Colors.white70 : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTab(String label, String id) {
    final isSelected = _activeSource == id;

    // Determine status
    bool isLoading = false;
    bool hasError = false;
    int count = 0;

    if (id == 'bt') {
      isLoading = _isLoadingMikan || _isLoadingDmhy;
      hasError = _mikanError != null || _dmhyError != null;
      count = dedupBtResources([..._mikanResources, ..._dmhyResources]).length;
    } else if (id == 'sample') {
      isLoading = _isLoadingSample;
      hasError = _sampleError != null;
      count = _sampleSuccessfulSources.length;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _activeSource = id;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              )
            else if (hasError && count == 0) // Only show error if no data
              Icon(
                Icons.error_outline,
                size: 14,
                color: Colors.redAccent.withValues(alpha: 0.8),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建全网搜源的内容
  Widget _buildSampleSourceContent() {
    // 1. 显示所有源的搜索状态（始终显示）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态标题
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (_isLoadingSample) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _sampleStatusMessageNotifier,
                  builder: (context, statusMessage, _) {
                    final summaryText = _enabledSourceNames.isEmpty
                        ? (_disableAutoSourceSearchForCurrentEpisode
                              ? '已播放本地资源，在线源搜索待手动触发'
                              : '尚未开始搜索在线源')
                        : '搜索完成 (${_sampleSuccessfulSources.length}/${_enabledSourceNames.length} 个可用)';

                    final displayText = _isLoadingSample
                        ? statusMessage
                        : (_sampleError != null ? '搜索失败' : summaryText);

                    return Text(
                      displayText,
                      style: TextStyle(
                        color: _sampleError != null
                            ? Colors.redAccent
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 如果有错误信息，显示在顶部
        if (_sampleError != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sampleError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 所有源的搜索状态列表
        if (_enabledSourceNames.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _enabledSourceNames.length,
              itemBuilder: (context, index) {
                final sourceName = _enabledSourceNames[index];
                final progress = _sourceProgressMap[sourceName];
                return _buildSourceProgressItem(sourceName, progress);
              },
            ),
          ),
        ],

        // 如果正在使用 WebView 任务池，显示所有活动任务
        if ((_useWorkerPool
                ? _scheduler.activeVideoJobs.isNotEmpty
                : _activeWebViews.isNotEmpty) ||
            _activeCaptchaTasks.isNotEmpty) ...[
          Divider(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black26
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _useWorkerPool
                      ? '并发WebView任务 ($_activeWebViewTaskCount/$_maxConcurrentWebViews) · ${_webViewWorkerPoolLabel()}'
                      : '并发WebView任务 ($_activeWebViewTaskCount/$_maxConcurrentWebViews)',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Phase 0 调试计数：webview widget 创建/释放 + 视频/验证码 job 生命周期
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    _webviewStatsLabel(),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white38
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Phase 0 调试：每个 sourceName 的 [pending|active|completed] 分布
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'per-source [p|a|c]: ${_perSourceStatusLabel()}',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white38
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 8,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                if (!_useWorkerPool)
                  ..._activeCaptchaTasks.values.map((task) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${task.label} - 正在跳过验证码',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white54
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                // 显示所有活动视频提取任务的状态
                // Round 4 Stage 3：pool 模式下按 worker slot 渲染（含 idle），展示
                // workerId / 当前 source/channel / lastSourceName / 同源 pending 数，
                // 方便观察 source-affinity 调度；legacy 模式仍按 pageKey 渲染。
                if (_useWorkerPool)
                  ..._buildWebViewWorkerStatusRows()
                else
                  ..._activeWebViews.keys.map((pageKey) {
                    final key = SourceChannelKey.fromPageKey(pageKey);
                    final sourceName = key.sourceName;
                    final channelIndex = key.channelIndex?.toInt();

                    SearchPlayResult? page;
                    for (final item in _samplePlayPages) {
                      final pIdx = item.channelIndex?.toInt();
                      if (item.sourceName == sourceName &&
                          pIdx == channelIndex) {
                        page = item;
                        break;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sourceName,
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white54
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    if ((page?.channelName ?? '').isNotEmpty)
                                      Text(
                                        " - ${page!.channelName}",
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontSize: 9,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  page?.playPageUrl ?? '等待匹配播放页...',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          // 调试开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _showWebView,
                    onChanged: (v) => setState(() => _showWebView = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                const Text("显示 WebView (调试)", style: TextStyle(fontSize: 10)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _useWorkerPool,
                    onChanged: (v) => _setUseWorkerPool(v ?? true),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  "统一 Worker 调度 (Round 7)",
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],

        // 如果有成功的源，显示播放按钮
        if (_sampleSuccessfulSources.isNotEmpty) ...[
          Divider(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "可用源 (${_sampleSuccessfulSources.length})",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 成功源列表
                ...List.generate(_sampleSuccessfulSources.length, (index) {
                  final source = _sampleSuccessfulSources[index];
                  final isSelected = index == _selectedSourceIndex;
                  return GestureDetector(
                    onTap: () {
                      _onSourceSelected(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.15)
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black26
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white38
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        source.sourceName,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87)
                                              : (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : Colors.grey),
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    // 显示channel信息
                                    if (source.channelName != null &&
                                        source.channelName!.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFBB86FC,
                                          ).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          source.channelName!,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  source.directVideoUrl ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _sampleVideoUrl != null
                      ? _startPlaybackFromSelectedSource
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    "播放 - ${_sampleSuccessfulSources.isNotEmpty ? (_sampleSuccessfulSources[_selectedSourceIndex].channelName != null ? '${_sampleSuccessfulSources[_selectedSourceIndex].sourceName}(${_sampleSuccessfulSources[_selectedSourceIndex].channelName})' : _sampleSuccessfulSources[_selectedSourceIndex].sourceName) : ''}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 如果没有任何源且不在加载中，显示空状态
        if (_enabledSourceNames.isEmpty && !_isLoadingSample)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.grey.withValues(alpha: 0.5),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _disableAutoSourceSearchForCurrentEpisode
                      ? '已使用本地资源播放'
                      : '尚未开始搜索在线源',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white38
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _disableAutoSourceSearchForCurrentEpisode
                      ? '如需在线源，请点击下方按钮手动搜索'
                      : '点击下方按钮开始搜索',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.grey.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _loadSampleSource(manual: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("搜索在线源", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : Colors.grey.withValues(alpha: 0.2),
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 构建单个源的搜索进度项
  Widget _buildSourceProgressItem(
    String sourceName,
    SourceSearchProgress? progress,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pendingColor = isDark
        ? Colors.white24
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final idleTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final activeTextColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    // 根据状态决定图标和颜色
    IconData icon;
    Color iconColor;
    String statusText;
    String? errorText;

    if (progress == null) {
      icon = Icons.hourglass_empty;
      iconColor = pendingColor;
      statusText = '等待中';
    } else {
      switch (progress.step) {
        case SearchStep.pending:
          icon = Icons.hourglass_empty;
          iconColor = pendingColor;
          statusText = '等待中';
          break;
        case SearchStep.searching:
          icon = Icons.search;
          iconColor = theme.colorScheme.primary;
          statusText = '搜索中...';
          break;
        case SearchStep.fetchingDetail:
          icon = Icons.article_outlined;
          iconColor = theme.colorScheme.primary;
          statusText = '获取详情页...';
          break;
        case SearchStep.fetchingEpisodes:
          icon = Icons.list_alt;
          iconColor = theme.colorScheme.primary;
          statusText = '获取剧集列表...';
          break;
        case SearchStep.extractingVideo:
          icon = Icons.video_library;
          iconColor = theme.colorScheme.primary;
          statusText = '提取视频链接...';
          break;
        case SearchStep.success:
          icon = Icons.check_circle;
          iconColor = Colors.green;
          statusText = progress.directVideoUrl != null ? '成功' : '找到播放页';
          break;
        case SearchStep.failed:
          icon = Icons.error_outline;
          iconColor = Colors.redAccent;
          statusText = '失败';
          errorText = progress.error;
          break;
      }
    }

    final isActive =
        progress != null &&
        progress.step != SearchStep.pending &&
        progress.step != SearchStep.success &&
        progress.step != SearchStep.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // 状态图标
          if (isActive)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: iconColor,
              ),
            )
          else
            Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          // 源名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sourceName,
                        style: TextStyle(
                          color: isActive ? activeTextColor : idleTextColor,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(color: iconColor, fontSize: 10),
                    ),
                  ],
                ),
                // 显示错误信息
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建所有活动的 WebView 提取器（并发）。
  ///
  /// - **Pool 模式**（`_useWorkerPool=true`，默认）：5B step 3 之后，调度
  ///   器只有一份 `_scheduler.slots`，每个 slot 对应一个长期
  ///   [`ReusableBrowserWorker`]（key 固定为
  ///   `ValueKey('worker_$workerId')`）。slot 的 [kind] 决定 build 时把
  ///   pageKey 反查的播放页打包成 [`VideoJob`] 还是把 taskKey 反查的
  ///   [_CaptchaPreflightTask] 打包成 [`CaptchaJob`] 派给 worker；为空时
  ///   emit `null` job，worker 内部保持当前页/`about:blank` 等下一 job，
  ///   避免重建 InAppWebView 实例。
  /// - **Legacy 模式**：把每个 `_activeWebViews` 的 pageKey 作为独立的一次性
  ///   [`WebViewVideoExtractorWidget`] 实例，行为等价于 Round 2 之前。
  Widget _buildWebViewExtractors() {
    return _useWorkerPool
        ? _buildWebViewExtractorsPool()
        : _buildWebViewExtractorsLegacy();
  }

  /// 把 [SearchPlayResult] 打包成派给 worker 的 [VideoExtractionJob]，与
  /// 旧 [`WebViewVideoExtractorWidget`] 构造参数语义一致。
  VideoExtractionJob _buildVideoExtractionJob(
    SearchPlayResult page, {
    required String pageKey,
  }) {
    return VideoExtractionJob(
      jobKey: pageKey,
      sourceName: page.sourceName,
      url: page.playPageUrl,
      customVideoRegex: page.videoRegex != r'$^' ? page.videoRegex : null,
      enableNestedUrl: page.enableNestedUrl,
      matchNestedUrl: page.matchNestedUrl != r'$^' ? page.matchNestedUrl : null,
      headers: page.headers,
      cookies: page.cookies,
      timeout: const Duration(seconds: 20),
    );
  }

  CaptchaPreflightJob _buildCaptchaPreflightJob(_CaptchaPreflightTask task) {
    return CaptchaPreflightJob(
      jobKey: task.taskKey,
      source: task.source,
      searchKeyword: task.searchKeyword,
      initialUrl: task.initialUrl,
      referer: task.referer,
      initialCookies: task.initialCookies,
      captchaConfig: task.captchaConfig,
      timeout: const Duration(seconds: 45),
    );
  }

  Widget _buildWebViewExtractorsPool() {
    final children = <Widget>[];

    // 5B step 3：调度器统一为单表 `_scheduler.slots`，按 workerId
    // 升序遍历。同一 workerId 在 build 内只 emit 一次
    // [`ReusableBrowserWorker`]（widget key 固定为
    // `ValueKey('worker_$workerId')`），job 切换仅通过 didUpdateWidget
    // 路由到对应 runner（captcha runner 或 video runner），不会因
    // widget key 不同被 Flutter 销毁 → InAppWebView 实例与站点
    // session/cookie 真正跨 kind 复用。
    final workerIds = _scheduler.slots.keys.toList()..sort();
    for (final workerId in workerIds) {
      final slot = _scheduler.slots[workerId]!;
      WebViewJob? job;
      void Function(String, CaptchaBypassResult)? onCaptchaResult;
      void Function(int)? onCaptchaIdle;
      void Function(String, VideoExtractResult)? onVideoResult;
      void Function(int)? onVideoIdle;

      switch (slot.kind) {
        case WebViewWorkerKind.captcha:
          final taskKey = slot.taskKey;
          final task = taskKey == null ? null : _activeCaptchaTasks[taskKey];
          if (task != null) {
            job = CaptchaJob(_buildCaptchaPreflightJob(task));
          }
          onCaptchaResult = (key, result) =>
              _onCaptchaPreflightResult(key, result);
          onCaptchaIdle = (id) => _onCaptchaWorkerIdle(id);
        case WebViewWorkerKind.video:
          final pageKey = slot.pageKey;
          SearchPlayResult? matchedPage;
          if (pageKey != null) {
            final parsedKey = SourceChannelKey.fromPageKey(pageKey);
            final sourceName = parsedKey.sourceName;
            final channelIndex = parsedKey.channelIndex?.toInt();
            for (final page in _samplePlayPages) {
              final pIdx = page.channelIndex?.toInt();
              if (page.sourceName == sourceName && pIdx == channelIndex) {
                matchedPage = page;
                break;
              }
            }
          }
          if (matchedPage != null && pageKey != null) {
            job = VideoJob(
              _buildVideoExtractionJob(matchedPage, pageKey: pageKey),
            );
          }
          onVideoResult = (key, result) => _onWebViewResult(key, result);
          onVideoIdle = (id) => _onWorkerIdle(id);
        case null:
          // slot idle：emit null job，worker 内部保持当前页等下一 job。
          break;
      }

      children.add(
        ReusableBrowserWorker(
          key: ValueKey('worker_$workerId'),
          workerId: workerId,
          job: job,
          onCaptchaResult: onCaptchaResult,
          onCaptchaIdle: onCaptchaIdle,
          onVideoResult: onVideoResult,
          onVideoIdle: onVideoIdle,
          onLog: (message) {
            debugPrint('[WebView][worker_$workerId] $message');
          },
          showWebView: _showWebView,
          stats: _webviewStats,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(children: children);
  }

  /// Legacy per-task widget 实现（[WebViewVideoExtractorWidget] 一次性模型）。
  /// pool 模式下不调用，行为等价于 Round 2 之前。
  Widget _buildWebViewExtractorsLegacy() {
    if (_activeWebViews.isEmpty && _activeCaptchaTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    final orphanPageKeys = <String>[];

    // 构建活动的视频提取 WebView
    for (final pageKey in _activeWebViews.keys) {
      final key = SourceChannelKey.fromPageKey(pageKey);
      final sourceName = key.sourceName;
      final channelIndex = key.channelIndex?.toInt();

      SearchPlayResult? matchedPage;
      for (final page in _samplePlayPages) {
        final pIdx = page.channelIndex?.toInt();
        if (page.sourceName == sourceName && pIdx == channelIndex) {
          matchedPage = page;
          break;
        }
      }

      if (matchedPage == null) {
        // 活动任务找不到对应的播放页（例如列表被重建/重排后不匹配），
        // 这会导致没有 WebView 被创建、onResult 永远不会触发，
        // 于是该任务在“并发提取”面板里卡住不消失。收集这些孤儿任务，
        // 在本帧结束后清理并重新调度任务池。
        orphanPageKeys.add(pageKey);
        continue;
      }

      children.add(
        WebViewVideoExtractorWidget(
          key: ValueKey('webview_$pageKey'),
          url: matchedPage.playPageUrl,
          customVideoRegex: matchedPage.videoRegex != r'$^'
              ? matchedPage.videoRegex
              : null,
          enableNestedUrl: matchedPage.enableNestedUrl,
          matchNestedUrl: matchedPage.matchNestedUrl != r'$^'
              ? matchedPage.matchNestedUrl
              : null,
          headers: matchedPage.headers,
          cookies: matchedPage.cookies,
          timeout: const Duration(seconds: 20),
          showWebView: _showWebView,
          onResult: (result) => _onWebViewResult(pageKey, result),
          onLog: (msg) => debugPrint('[WebView][$pageKey] $msg'),
          stats: _webviewStats,
          jobKey: pageKey,
        ),
      );
    }

    // 清理孤儿提取任务：这些任务被标记为活动，但在 _samplePlayPages 中已经
    // 找不到对应的播放页，因此不会有 WebView 被创建来驱动 onResult。如果放任
    // 不管，它们会一直占用并发槽位并停留在“正在提取”状态。build 阶段不能直接
    // setState，所以推迟到本帧渲染完成后清理并重新泵送任务池。
    if (orphanPageKeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        var changed = false;
        for (final pageKey in orphanPageKeys) {
          if (_activeWebViews.remove(pageKey) != null) {
            _webViewStatus.remove(pageKey);
            _failedWebViewPageKeys.add(pageKey);
            _webviewStats.onVideoJobCancelled(
              pageKey,
              SourceChannelKey.fromPageKey(pageKey).sourceName,
            );
            changed = true;
            debugPrint(
              '[_buildWebViewExtractors] Cleared orphan extraction task: $pageKey',
            );
          }
        }
        if (changed) {
          setState(() {});
          _updatePoolStatusMessage();
          _scheduleWebViewPoolPump(immediate: true);
          _maybeFinishSampleSearch();
        }
      });
    }

    // 构建活动的验证码预处理 WebView（与提取任务共用池子）
    for (final task in _activeCaptchaTasks.values) {
      children.add(
        CaptchaWebViewBypassWidget(
          key: ValueKey('captcha_pool_${task.taskKey}_${task.loadToken}'),
          source: task.source,
          searchKeyword: task.searchKeyword,
          initialUrl: task.initialUrl,
          referer: task.referer,
          initialCookies: task.initialCookies,
          captchaConfig: task.captchaConfig,
          timeout: const Duration(seconds: 45),
          onResult: (result) => _onCaptchaPreflightResult(task.taskKey, result),
          onLog: (message) {
            debugPrint('[CaptchaBypass][${task.taskKey}] $message');
          },
          showWebView: _showWebView,
          stats: _webviewStats,
          jobKey: task.taskKey,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(children: children);
  }

  Widget _buildResourceList() {
    final content = resolvePlayerResourceContent(
      isExpanded: _isSourceControlExpanded,
      activeSource: _activeSource,
    );
    if (content == PlayerResourceContent.hidden) {
      return const SizedBox.shrink();
    }
    if (content == PlayerResourceContent.sample) {
      return _buildSampleSourceContent();
    }
    final deduped = sortBtResourcesByTitle(
      dedupBtResources([..._mikanResources, ..._dmhyResources]),
    );
    return BtResourceList(
      isExpanded: _isSourceControlExpanded,
      resources: toBtResourceViewModels(deduped),
      isLoading: _isLoadingMikan || _isLoadingDmhy,
      hasError: _mikanError != null || _dmhyError != null,
      loadingMagnet: _loadingMagnet,
      isPlayBlocked: _isLoadingVideo || _loadingMagnet != null,
      onRetrySearch: () {
        setState(() {
          _disableAutoSourceSearchForCurrentEpisode = false;
        });
        _loadMikanSource();
        _loadDmhySource();
      },
      onCopyMagnet: (res) {
        Clipboard.setData(ClipboardData(text: res.magnet));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('磁力链接已复制')));
      },
      onDownload: (res) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('开始下载，可在「我的」页面查看进度')));
        await _downloadManager.startDownload(
          magnet: res.magnet,
          name: res.title,
          animeName: widget.anime.title,
          episodeNumber: res.episode,
        );
      },
      onPlay: (res) async {
        setState(() {
          _loadingMagnet = res.magnet;
          _videoError = null;
        });
        try {
          final streamUrl = await _downloadManager.startDownload(
            magnet: res.magnet,
            name: res.title,
            animeName: widget.anime.title,
            episodeNumber: res.episode,
            forPlayback: true,
          );
          if (streamUrl == null) {
            setState(() {
              _videoError = '无法获取播放地址';
              _loadingMagnet = null;
            });
            return;
          }
          debugPrint('[Player] Got stream URL: $streamUrl');
          _currentStreamUrl = streamUrl;
          final btHash = _extractBtHashFromStreamUrl(streamUrl);
          if (btHash != null) {
            _downloadManager.setActiveStream(btHash);
            debugPrint(
              '[Player] Notified DownloadManager: stream active for $btHash',
            );
          }
          await _player.stop();
          await _player.open(Media(streamUrl));
          await _applyPlaybackSpeed();
          await _applyPendingStartPosition();
          setState(() {
            _loadingMagnet = null;
            _playingSourceLabel = 'BT';
          });
          _publishPlayerControlSourceState();
        } catch (e) {
          debugPrint('[Player] Error playing magnet: $e');
          setState(() {
            _videoError = e.toString();
            _loadingMagnet = null;
          });
        }
      },
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    return PlayerComments(
      comments: _comments,
      isLoading: _isLoadingComments,
      error: _commentsError,
      scrollController: _commentsScrollController,
      sortButton: _buildSortButton(),
    );
  }

  Widget _buildOnairSitesList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackColor = isDark ? Colors.white24 : Colors.grey[400]!;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDark ? Colors.white10 : Colors.grey[300]!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _onairSites.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            GestureDetector(
              onTap: () => launchBangumiSiteUrl(_onairSites[i].url),
              child: SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: _buildOnairSiteIcon(
                        _onairSites[i].site,
                        fallbackColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _onairSites[i].title,
                      style: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black87)
                            .withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnairSiteIcon(String siteKey, Color fallbackColor) {
    final assetPath = siteIconAssetPath(siteKey);
    if (assetPath == null) {
      return Icon(Icons.public, color: fallbackColor, size: 36);
    }
    return Image.asset(
      assetPath,
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.public, color: fallbackColor, size: 36),
    );
  }

  void _markUserInteraction() {
    _lastUserInteractionAt = DateTime.now();
  }

  void _temporarilyAllowPositionReset() {
    final now = DateTime.now();
    _allowPositionResetUntil = now.add(_positionResetGracePeriod);
    _furthestObservedPosition = Duration.zero;
    _isRecoveringUnexpectedJump = false;
  }

  void _handleUnexpectedPositionJump(Duration position) {
    final furthestPosition = _furthestObservedPosition;
    final now = DateTime.now();
    final isWithinManualInteractionWindow =
        _lastUserInteractionAt != null &&
        now.difference(_lastUserInteractionAt!) <= _manualSeekGracePeriod;

    if (isWithinManualInteractionWindow) {
      final movedForward = position > furthestPosition;
      final movedBackward =
          furthestPosition > position &&
          furthestPosition - position >= _manualBackwardSeekMinimum;

      if (movedForward || movedBackward) {
        // 用户手动 seek 后，必须把异常跳转检测的基线切到用户选中的位置。
        // 只跳过短暂窗口不够：窗口结束后旧 furthest 仍会把进度拉回去。
        _furthestObservedPosition = position;
      }
      return;
    }

    if (position > _furthestObservedPosition) {
      _furthestObservedPosition = position;
    }

    if (_isRecoveringUnexpectedJump) {
      _isRecoveringUnexpectedJump = false;
      return;
    }

    if (_allowPositionResetUntil?.isAfter(now) ?? false) {
      return;
    }

    if (furthestPosition < _unexpectedJumpSourceMinimum) {
      return;
    }

    final droppedDuration = furthestPosition - position;
    if (droppedDuration < _unexpectedJumpMinimum) {
      return;
    }

    final recoverPosition = furthestPosition + _unexpectedJumpRecoveryOffset;
    final duration = _player.state.duration;
    final boundedRecoverPosition = duration > Duration.zero
        ? recoverPosition > duration
              ? duration
              : recoverPosition
        : recoverPosition;

    if (boundedRecoverPosition <= position) {
      return;
    }

    _temporarilyAllowPositionReset();
    _isRecoveringUnexpectedJump = true;
    unawaited(_player.seek(boundedRecoverPosition));
    debugPrint(
      '[AntiAd] Unexpected position jump detected: '
      '${furthestPosition.inSeconds}s -> ${position.inSeconds}s, '
      'recovering to ${boundedRecoverPosition.inSeconds}s',
    );
  }

  void _navigateToAnime(RankingAnime item) {
    // Create AnimeInfo from RankingAnime
    final animeInfo = AnimeInfo(
      title: item.title,
      bangumiId: item.bangumiId,
      coverUrl: item.coverUrl,
      score: item.score,
      rank: item.rank,
      tags: [], // We don't have full tags yet
      fullJson: null,
    );

    // Navigate to details page or player page?
    // Usually clicking a recommendation goes to details page.
    // But user might want to play directly?
    // Standard flow: Detail Page.
    // But we are in PlayerPage.
    // If we go to details page:
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BangumiDetailsPage(
          anime: animeInfo,
          heroTag: 'player_rec_${item.bangumiId}',
        ),
      ),
    );
  }
}
