import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
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
import 'package:mikan_player/services/source_request_gate.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/utils/source_channel_key.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/player/player_source_helpers.dart';
import 'package:mikan_player/ui/pages/player/player_episode_controller.dart';
import 'package:mikan_player/ui/pages/player/player_source_controller.dart';
import 'package:mikan_player/ui/pages/player/player_sample_source_controller.dart';
import 'package:mikan_player/ui/pages/player/player_playback_controller.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';
import 'package:mikan_player/ui/pages/player/player_side_panel_loader.dart';
import 'package:mikan_player/ui/pages/player/player_bt_source_loader.dart';
import 'package:mikan_player/ui/pages/player/player_captcha_preflight_coordinator.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_coordinator.dart';
import 'package:mikan_player/ui/pages/player/player_autoplay_coordinator.dart';
import 'package:mikan_player/ui/pages/player/sample_search_finish_policy.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_resource_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comment_sort_button.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_current_source_actions.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_video_area.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_selector.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_sample_source_panel.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_mobile_layout.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_layout.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_state_transitions.dart';

part 'player/player_page_layouts.dart';
part 'player/player_page_mobile_info_layout.dart';
part 'player/player_page_pc_layout.dart';
part 'player/player_page_video_area.dart';
part 'player/player_page_source_panel.dart';
part 'player/player_page_sample_source_panel.dart';
part 'player/player_page_webview_widgets.dart';
part 'player/player_page_side_panel_widgets.dart';
part 'player/player_page_interactions.dart';
part 'player/player_page_playback_host.dart';
part 'player/player_page_side_panel_host.dart';
part 'player/player_page_webview_scheduler_host.dart';
part 'player/player_page_search_host.dart';
part 'player/player_page_autoplay_host.dart';
part 'player/player_page_webview_result_host.dart';
part 'player/player_page_episode_host.dart';

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

  // Side panel (comments / recommendations / onair sites) state.
  // Phase 1.1: pure mutators live in PlayerSidePanelLoader; async fetch bodies
  // and State glue live in player_page_side_panel_host.dart.
  final PlayerSidePanelLoader _sidePanelLoader = PlayerSidePanelLoader();

  // Sample Source
  // 并发WebView管理
  final Map<String, int> _activeWebViews =
      {}; // legacy WebView pageKey -> search generation
  final Map<String, String> _webViewStatus =
      {}; // WebView状态消息 (sourceName -> message)
  final Set<String> _failedWebViewPageKeys = {}; // 提取失败的WebView Key
  final Set<String> _resolvingChannelPlayPageKeys = {}; // 正在解析的频道播放页
  // Phase 1.3: captcha preflight queue / active map / runtime overrides.
  final PlayerCaptchaPreflightCoordinator _captchaCoordinator =
      PlayerCaptchaPreflightCoordinator();
  final PlayerSearchSessionCoordinator _searchSessionCoordinator =
      PlayerSearchSessionCoordinator();
  int _maxConcurrentWebViews = PlayerPage.kDefaultMaxConcurrentWebViews;
  bool _cancelLowPrioritySourcesOnPlay = true;
  int _webViewLaunchInterval = 200;
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

  // Mikan + DMHY 源加载状态对象。Phase 2 责任拆分：本页原先散落的 7 个源加载
  // 状态字段（Mikan 的 loading 标志、error、anime 绑定、resources 列表，以及
  // DMHY 的 loading 标志、error、resources 列表）全归该对象管理。本页只读只读
  // 视图、把所有 mutation 路由到 controller 方法（`markMikanLoading` /
  // `setMikanResources` / `markDmhyLoading` / ...）；异步 fetch 本身
  // （`_loadMikanSource` / `_loadDmhySource` / `_reloadMikanResourcesForEpisode`
  // 的方法体，内含 `widget.anime.*`、`BangumiRequestModeService` /
  // `searchMikanAnime` / `getMikanResources` / `fetchDmhyResources`、`mounted`
  // 检查、`setState` 包裹）仍留在本页。完整 doc comments 详见
  // `lib/ui/pages/player/player_source_controller.dart`。
  late final PlayerSourceController _sourceController;

  // Sample-source 搜索状态对象。Phase 2 Sub-commit B：本页原先散落的 11 个
  // sample 搜索状态字段（loading/error/play pages/successful sources/selected
  // index/load token/enqueue seq/progress map/enabled names/tiers）全归该对象
  // 管理。本页只读只读视图、把 mutation 路由到 controller；WebView pool /
  // scheduler / captcha / stream launch / prefs / BT probe / setState 仍留本页。
  // 完整 doc comments 详见
  // `lib/ui/pages/player/player_sample_source_controller.dart`。
  late final PlayerSampleSourceController _sampleSourceController;

  // Online playback state, source selection, URL/header planning, and the
  // startup watchdog live in this pure-Dart controller. WebView/probe/player
  // widget construction and Flutter lifecycle stay on this page.
  late final PlayerPlaybackController _playbackController;

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
  // 在新搜索/新剧集开始时重置为 null（与 playback auto-play eligibility 同步）。
  String? _acceptedSourcePageKey;

  // Auto Play Logic
  bool _isAutoPlayNextEnabled = true;
  bool _autoSearchOnline = true;
  bool _disableAutoSourceSearchForCurrentEpisode = false;
  bool _autoPlaySearchedSource = true;
  double _playbackSpeed = 1.0;

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
  // Notifier for source index to bypass Video widget rebuild issues.
  late final ValueNotifier<int> _selectedSourceIndexNotifier = ValueNotifier(0);
  String? _loadingMagnet; // Track which specific magnet is being loaded
  final DownloadManager _downloadManager = DownloadManager();

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
    _sourceController = PlayerSourceController();
    _sampleSourceController = PlayerSampleSourceController();
    _playbackController = PlayerPlaybackController();
    _videoTitleNotifier = ValueNotifier(
      '${widget.anime.title} - 第${_episodeController.currentEpisode.sort.toInt()}集',
    );
    _playingSourceLabelNotifier.value = _playbackController.playingSourceLabel;

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
          _playbackController.notifyPlaybackStarted();
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
          _playbackController.notifyPlaybackStarted();
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

  void _updateState(VoidCallback mutation) => setState(mutation);

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animeChanged = oldWidget.anime.bangumiId != widget.anime.bangumiId;
    final episodeChanged =
        oldWidget.currentEpisode.sort != _episodeController.currentEpisode.sort;
    if (animeChanged || episodeChanged) {
      // Source loading for a prop-driven switch can be delayed by the local
      // download probe below. Invalidate immediately so an earlier request
      // cannot commit while that probe is still pending.
      _sourceController.invalidatePendingRequests();
    }
    if (oldWidget.currentEpisode.id != _episodeController.currentEpisode.id) {
      _loadComments();
    }
    if (animeChanged) {
      setState(() {
        _sidePanelLoader.clearOnairSites();
      });
      _loadRecommendations();
      _loadOnairSites();
      if (!_disableAutoSourceSearchForCurrentEpisode) {
        _loadMikanSource(); // Anime changed, reload search
        _loadDmhySource();
      }
    } else if (episodeChanged) {
      // Episode changed, reload resources using existing mikan anime info if available
      unawaited(_handleWidgetEpisodeChanged());
    }
  }

  @override
  void dispose() {
    _sourceController.invalidatePendingRequests();
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
    // Invalidate every in-flight sample/captcha/video generation first so any
    // stream event, probe, or open that races with dispose is dropped.
    _sampleSourceController.bumpLoadToken();
    _playbackController.clearForDispose();
    _acceptedSourcePageKey = null;
    unawaited(_cancelSearchSubscriptions());
    _captchaCoordinator.clearForDispose();
    // Drop active jobs so runners stop loading; framework dispose of
    // ReusableBrowserWorker tears down InAppWebViews afterwards.
    _scheduler.resetForNewSearch();
    // Phase 2 B6：清理统一 pool 调度记账。worker widget 在 widget 树卸载时
    // 由框架负责 dispose（含 InAppWebView），scheduler 侧只需清空内部表
    // 以避免后续 post-frame 回调进来时引用已 dispose 的 slot。
    _scheduler.clearForDispose();
    // 通知下载管理器BT流不再活跃
    if (_playbackController.currentStreamUrl != null) {
      final btHash = _extractBtHashFromStreamUrl(
        _playbackController.currentStreamUrl!,
      );
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
    _sourceController.clearForDispose();
    _sampleSourceController.clearForDispose();
    _sidePanelLoader.clearForDispose();
    _captchaCoordinator.clearForDispose();
    _searchSessionCoordinator.clearForDispose();
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
}
