import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/ui/widgets/danmaku_overlay.dart';
import 'package:mikan_player/ui/widgets/danmaku_settings.dart';

import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

class PlayerPage extends StatefulWidget {
  final AnimeInfo anime;
  final BangumiEpisode currentEpisode;
  final List<BangumiEpisode> allEpisodes;

  const PlayerPage({
    super.key,
    required this.anime,
    required this.currentEpisode,
    required this.allEpisodes,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  late TabController _mobileTabController;
  late ScrollController _pcEpisodeScrollController;
  late ScrollController _mobileEpisodeScrollController;
  bool _isDescriptionExpanded = false;
  bool _isEpisodesExpanded = false;

  List<BangumiEpisodeComment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;

  List<RankingAnime> _recommendations = [];
  bool _isLoadingRecommendations = false;

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
  final Map<String, bool> _activeWebViews = {}; // 正在运行的WebView (sourceName -> isActive)
  final Map<String, String> _webViewStatus = {}; // WebView状态消息 (sourceName -> message)
  final int _maxConcurrentWebViews = 3; // 最大并发WebView数量
  String _sampleStatusMessage = ''; // WebView 提取状态消息
  bool _showWebView = false; // 是否显示 WebView（调试用）

  // Auto Play Logic
  bool _hasAutoPlayed = false;
  int _currentAutoPlayTier = 0;

  // 每个源的搜索进度状态
  Map<String, SourceSearchProgress> _sourceProgressMap = {};
  List<String> _enabledSourceNames = []; // 所有已启用的源名称

  // Active Source
  String _activeSource = 'mikan'; // 'mikan' or 'dmhy'

  // Video Player
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerInitialized = false;
  bool _isLoadingVideo =
      false; // Keep for general UI loading (like initial search or player overlay)
  String? _loadingMagnet; // Track which specific magnet is being loaded
  String? _currentStreamUrl;
  String? _videoError;
  final DownloadManager _downloadManager = DownloadManager();

  // Danmaku
  final DanmakuService _danmakuService = DanmakuService();
  double _currentVideoTime = 0;
  bool _isVideoPaused = false;
  bool _showDanmakuSettings = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playingSubscription;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _pcEpisodeScrollController = ScrollController();
    _mobileEpisodeScrollController = ScrollController();

    // Initialize video player
    _player = Player();
    _videoController = VideoController(_player);
    _isPlayerInitialized = true;

    // Subscribe to player position for danmaku sync
    _positionSubscription = _player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentVideoTime = position.inMilliseconds / 1000.0;
        });
      }
    });

    // Subscribe to playing state for danmaku pause
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isVideoPaused = !playing;
        });
      }
    });

    _loadComments();
    _loadRecommendations();
    _loadRecommendations();
    _loadMikanSource();
    _loadMikanSource();
    _loadDmhySource();
    _loadSampleSource();
    _loadDanmaku();
  }

  // Load danmaku based on anime title and episode
  Future<void> _loadDanmaku() async {
    final animeTitle = widget.anime.title;
    final episodeNumber = widget.currentEpisode.sort.toInt();

    // Calculate relative episode number (1-based index in the episode list)
    final epIndex = widget.allEpisodes.indexWhere(
      (e) => e.id == widget.currentEpisode.id,
    );
    final relativeEpNumber = epIndex != -1 ? epIndex + 1 : episodeNumber;

    debugPrint(
        '[Danmaku] Loading danmaku for: $animeTitle EP$episodeNumber (rel: $relativeEpNumber)');

    // Prefer Bangumi TV subject_id if available for more accurate matching
    if (widget.anime.bangumiId != null && widget.anime.bangumiId!.isNotEmpty) {
      final subjectId = int.tryParse(widget.anime.bangumiId!);
      if (subjectId != null) {
        debugPrint('[Danmaku] Using Bangumi TV subject_id: $subjectId');
        await _danmakuService.loadDanmakuByBangumiId(
          subjectId,
          episodeNumber.toString(),
          relativeEpisode: relativeEpNumber,
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
    if (widget.currentEpisode.id == 0) return;

    setState(() {
      _isLoadingComments = true;
      _commentsError = null;
    });

    try {
      final comments = await fetchBangumiEpisodeComments(
        episodeId: widget.currentEpisode.id,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
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

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final List<RankingAnime> results = [];
      final Set<String> addedIds = {};

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
            debugPrint("Error fetching relations: $e");
          }
        }
      }

      // 2. Tag-based Search
      final tags = widget.anime.tags;
      const invalidTags = ['TV', '日本', '中国'];
      final validTags = tags.where((t) => !invalidTags.contains(t)).toList();

      if (validTags.isNotEmpty) {
        // Limit results: more tags => fewer per tag
        int limitPerTag = (12 / validTags.length).ceil();
        if (limitPerTag < 2) limitPerTag = 2;
        if (limitPerTag > 5) limitPerTag = 5;

        // Take max 5 tags to search
        final searchTags = validTags.take(5).toList();

        // Fetch in parallel
        final futures = searchTags.map((tag) async {
          try {
            return await fetchBangumiBrowser(
              sortType: 'trends', // Use trends for "You might like"
              year: '',
              tags: [tag],
              page: 1,
            );
          } catch (e) {
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
      }

      if (mounted) {
        setState(() {
          _recommendations = results;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading recommendations: $e");
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
        targetEpisode: widget.currentEpisode.sort.toInt(),
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
    debugPrint("[Mikan] Current episode sort: ${widget.currentEpisode.sort}");

    setState(() {
      _isLoadingMikan = true;
      _mikanError = null;
      _mikanResources = [];
    });

    try {
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

      if (widget.currentEpisode.id != 0) {
        final resources = await getMikanResources(
          mikanId: result.id,
          currentEpisodeSort: widget.currentEpisode.sort.toInt(),
        );

        debugPrint(
          "[Mikan] Initial load: Found ${resources.length} resources for EP ${widget.currentEpisode.sort.toInt()}",
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

  Future<void> _loadSampleSource() async {
    setState(() {
      _isLoadingSample = true;
      _sampleError = null;
      _sampleVideoUrl = null;
      _samplePlayPages = [];
      _sampleSuccessfulSources = [];
      _selectedSourceIndex = 0;
      _activeWebViews.clear();
      _webViewStatus.clear();
      _sampleStatusMessage = '正在获取播放源列表...';
      _sourceProgressMap = {};
      _enabledSourceNames = [];
      _sourceTiers = {};
      _hasAutoPlayed = false;
      _currentAutoPlayTier = 0;
    });

    try {
      // 获取所有源（包括详细信息如Tier）
      final sources = await getPlaybackSources();
      final enabledSources = sources.where((s) => s.enabled).toList();
      final enabledNames = enabledSources.map((s) => s.name).toList();

      if (!mounted) return;

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
          );
        }
        _sampleStatusMessage = '正在搜索 ${enabledNames.length} 个源...';
      });

      // 使用带进度的流式API，传入当前集号
      final currentEpNumber = widget.currentEpisode.sort.toInt();

      // Calculate relative episode number (1-based index in the episode list)
      final epIndex = widget.allEpisodes.indexWhere(
        (e) => e.id == widget.currentEpisode.id,
      );
      final relativeEpNumber = epIndex != -1 ? epIndex + 1 : currentEpNumber;

      await for (final progress in genericSearchWithProgress(
        animeName: widget.anime.title,
        absoluteEpisode: currentEpNumber,
        relativeEpisode: relativeEpNumber,
      )) {
        if (!mounted) return;

        setState(() {
          // 更新该源的进度
          _sourceProgressMap[progress.sourceName] = progress;

          // 如果搜索成功，添加到成功列表
          if (progress.step == SearchStep.success &&
              progress.playPageUrl != null) {
            final result = SearchPlayResult(
              sourceName: progress.sourceName,
              playPageUrl: progress.playPageUrl!,
              videoRegex: progress.videoRegex ?? '',
              directVideoUrl: progress.directVideoUrl,
              cookies: progress.cookies,
              headers: progress.headers,
            );

            // 避免重复添加
            if (!_samplePlayPages.any(
              (p) => p.sourceName == progress.sourceName,
            )) {
              _samplePlayPages.add(result);
            }

            // 如果有直接视频URL，添加到成功列表
            if (progress.directVideoUrl != null &&
                progress.directVideoUrl!.isNotEmpty) {
              if (!_sampleSuccessfulSources.any(
                (s) => s.sourceName == progress.sourceName,
              )) {
                _sampleSuccessfulSources.add(result);
              }
            }
          }

          // 更新状态消息
          final completedCount = _sourceProgressMap.values
              .where(
                (p) =>
                    p.step == SearchStep.success || p.step == SearchStep.failed,
              )
              .length;
          _sampleStatusMessage =
              '搜索进度: $completedCount/${_enabledSourceNames.length}';

          // 尝试自动播放（基于Tier逻辑）
          _attemptAutoPlay();
        });
      }

      // 所有源搜索完毕
      if (!mounted) return;

      // 检查是否有任何成功的源
      final hasAnyPlayPage = _samplePlayPages.isNotEmpty;

      if (!hasAnyPlayPage) {
        setState(() {
          _sampleError = '未在任何源中找到该动画';
          _isLoadingSample = false;
        });
        return;
      }

      // 如果有找到播放页但没有直接链接的源，启动并发WebView提取
      if (_sampleSuccessfulSources.isEmpty ||
          _samplePlayPages.length > _sampleSuccessfulSources.length) {
        // Sort play pages by Tier before WebView extraction
        _samplePlayPages.sort((a, b) {
          final tierA = _sourceTiers[a.sourceName] ?? 999;
          final tierB = _sourceTiers[b.sourceName] ?? 999;
          return tierA.compareTo(tierB);
        });

        setState(() {
          _sampleStatusMessage = '搜索完成，正在提取剩余源...';
          _startConcurrentWebViewExtraction();
        });
      } else {
        setState(() {
          _isLoadingSample = false;
          _sampleStatusMessage =
              '搜索完成，共找到 ${_sampleSuccessfulSources.length} 个可用源';
        });
      }
    } catch (e) {
      debugPrint("Error loading Sample source: $e");
      if (mounted) {
        setState(() {
          _sampleError = e.toString();
          _isLoadingSample = false;
        });
      }
    }
  }

  void _attemptAutoPlay() {
    if (_hasAutoPlayed || _sampleVideoUrl != null) return;

    // Determine max tier
    int maxTier = 0;
    if (_sourceTiers.isNotEmpty) {
      maxTier = _sourceTiers.values.reduce((a, b) => a > b ? a : b);
    }
    // Safety cap
    if (maxTier > 100) maxTier = 100;

    // Iterate through tiers starting from current target
    while (_currentAutoPlayTier <= maxTier) {
      final tier = _currentAutoPlayTier;

      // Check for available candidates in this tier
      final candidates = _sampleSuccessfulSources
          .where((s) => (_sourceTiers[s.sourceName] ?? 999) == tier)
          .toList();

      if (candidates.isNotEmpty) {
        // Found a candidate in the current tier! Play the first one.
        // Since we are inside the stream, "first one" is "earliest parsed".
        _playSource(candidates.first);
        return;
      }

      // Check if there are any pending sources for this tier
      final hasPending = _sourceProgressMap.values.any(
        (p) =>
            (_sourceTiers[p.sourceName] ?? 999) == tier &&
            p.step != SearchStep.success &&
            p.step != SearchStep.failed,
      );

      if (hasPending) {
        // We are still waiting for sources in this tier.
        // Do not proceed to higher tiers.
        return;
      }

      // If no candidates AND no pending sources for this tier,
      // it means all sources in this tier failed (or no direct link).
      // Move to next tier.
      _currentAutoPlayTier++;
    }
  }

  void _playSource(SearchPlayResult source) {
    if (_sampleVideoUrl != null) return;

    debugPrint(
      "Auto-playing source: ${source.sourceName} (Tier ${_sourceTiers[source.sourceName]})",
    );

    setState(() {
      _hasAutoPlayed = true;
      _sampleVideoUrl = source.directVideoUrl;
      // Ensure index is correct in the display list
      _selectedSourceIndex = _sampleSuccessfulSources.indexOf(source);
      if (_selectedSourceIndex == -1) {
        // Should not happen if source is from _sampleSuccessfulSources
        _selectedSourceIndex = 0;
      }

      final headers = <String, String>{};
      if (source.headers != null) headers.addAll(source.headers!);
      if (source.cookies != null) headers['Cookie'] = source.cookies!;

      _player.open(Media(_sampleVideoUrl!, httpHeaders: headers));
      _currentStreamUrl = _sampleVideoUrl;
      _isLoadingVideo = false;
      _videoError = null;
    });
  }

  /// 启动并发WebView提取
  void _startConcurrentWebViewExtraction() {
    if (!mounted) return;

    // 找到所有需要WebView提取的源（还没有直接视频链接的）
    final needsExtraction = _samplePlayPages.where((page) {
      return !_sampleSuccessfulSources.any(
        (s) => s.playPageUrl == page.playPageUrl,
      );
    }).toList();

    if (needsExtraction.isEmpty) {
      setState(() {
        _isLoadingSample = false;
        _sampleStatusMessage =
            '搜索完成，共找到 ${_sampleSuccessfulSources.length} 个可用源';
      });
      return;
    }

    // 启动前N个源的WebView提取（根据_maxConcurrentWebViews限制）
    for (var i = 0; i < needsExtraction.length && i < _maxConcurrentWebViews; i++) {
      final page = needsExtraction[i];
      setState(() {
        _activeWebViews[page.sourceName] = true;
        _webViewStatus[page.sourceName] = '正在提取...';
      });
    }

    setState(() {
      final total = _samplePlayPages.length;
      final completed = _sampleSuccessfulSources.length;
      final active = _activeWebViews.length;
      _sampleStatusMessage = '提取中: $completed/$total 完成，$active 并发运行';
    });
  }

  /// WebView 提取结果回调（并发版本）
  void _onWebViewResult(String sourceName, VideoExtractResult result) {
    if (!mounted) return;

    setState(() {
      // 移除活动WebView
      _activeWebViews.remove(sourceName);
      _webViewStatus.remove(sourceName);

      if (result.success) {
        // 找到对应的播放页并更新
        final pageIndex = _samplePlayPages.indexWhere(
          (p) => p.sourceName == sourceName,
        );
        
        if (pageIndex >= 0) {
          final page = _samplePlayPages[pageIndex];
          final updatedPage = SearchPlayResult(
            sourceName: page.sourceName,
            playPageUrl: page.playPageUrl,
            videoRegex: page.videoRegex,
            directVideoUrl: result.videoUrl,
            cookies: page.cookies,
            headers: page.headers,
          );

          _sampleSuccessfulSources.add(updatedPage);

          // 如果这是第一个成功提取且没有其他源在播放
          if (_sampleVideoUrl == null) {
            _playSource(updatedPage);
          }
        }
      }

      // 更新状态消息
      final total = _samplePlayPages.length;
      final completed = _sampleSuccessfulSources.length;
      final active = _activeWebViews.length;
      _sampleStatusMessage = '提取中: $completed/$total 完成，$active 并发运行';

      // 启动下一个待提取的源（如果有）
      _startNextWebViewExtraction();
    });
  }

  /// 启动下一个WebView提取任务
  void _startNextWebViewExtraction() {
    if (!mounted) return;

    // 如果已经达到并发上限，不启动新的
    if (_activeWebViews.length >= _maxConcurrentWebViews) return;

    // 找到下一个需要提取的源
    final needsExtraction = _samplePlayPages.where((page) {
      final alreadySuccessful = _sampleSuccessfulSources.any(
        (s) => s.playPageUrl == page.playPageUrl,
      );
      final alreadyActive = _activeWebViews.containsKey(page.sourceName);
      return !alreadySuccessful && !alreadyActive;
    }).toList();

    if (needsExtraction.isEmpty) {
      // 检查是否所有提取都完成了
      if (_activeWebViews.isEmpty) {
        setState(() {
          _isLoadingSample = false;
          if (_sampleSuccessfulSources.isEmpty) {
            _sampleError = '所有源都无法提取视频链接';
          } else {
            _sampleStatusMessage =
                '搜索完成，共找到 ${_sampleSuccessfulSources.length} 个可用源';
          }
        });
      }
      return;
    }

    // 启动下一个
    final page = needsExtraction.first;
    setState(() {
      _activeWebViews[page.sourceName] = true;
      _webViewStatus[page.sourceName] = '正在提取...';
    });
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisode.id != widget.currentEpisode.id) {
      _loadComments();
    }
    if (oldWidget.anime.bangumiId != widget.anime.bangumiId) {
      _loadRecommendations();
      _loadMikanSource(); // Anime changed, reload search
      _loadDmhySource();
    } else if (oldWidget.currentEpisode.sort != widget.currentEpisode.sort) {
      // Episode changed, reload resources using existing mikan anime info if available
      if (_mikanAnime != null) {
        _reloadMikanResourcesForEpisode();
      } else {
        _loadMikanSource();
      }
      _loadDmhySource();
      _loadSampleSource();
    }
  }

  Future<void> _reloadMikanResourcesForEpisode() async {
    debugPrint(
      "[Mikan] Reloading resources for new episode: ${widget.currentEpisode.sort.toInt()}",
    );
    debugPrint("[Mikan] Using existing anime ID: ${_mikanAnime!.id}");

    setState(() {
      _isLoadingMikan = true;
      _mikanResources = []; // Clear previous episode resources
    });
    try {
      final resources = await getMikanResources(
        mikanId: _mikanAnime!.id,
        currentEpisodeSort: widget.currentEpisode.sort.toInt(),
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
    _mobileTabController.dispose();
    _pcEpisodeScrollController.dispose();
    _mobileEpisodeScrollController.dispose();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Deep dark background
      body: Stack(
        children: [
          // 主界面
          isWide ? _buildPCLayout(context) : _buildMobileLayout(context),
          
          // 后台WebView容器（始终存在，用于后台视频提取）
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
                color: const Color(0xFF16161E),
                child: TabBar(
                  controller: _mobileTabController,
                  labelColor: const Color(0xFFBB86FC),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFBB86FC),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anime Title
          Text(
            widget.anime.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Episode Info
          Text(
            widget.currentEpisode.nameCn.isNotEmpty
                ? widget.currentEpisode.nameCn
                : widget.currentEpisode.name,
            style: const TextStyle(
              color: Colors.white70,
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
                  color: const Color(0xFFBB86FC).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "EP ${widget.currentEpisode.sort % 1 == 0 ? widget.currentEpisode.sort.toInt() : widget.currentEpisode.sort}",
                  style: const TextStyle(
                    color: Color(0xFFBB86FC),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${widget.allEpisodes.length} Episodes",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.remove_red_eye, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              const Text(
                "1.2M",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentEpisode.description.isNotEmpty
                      ? widget.currentEpisode.description
                      : "暂无简介",
                  maxLines: _isDescriptionExpanded ? null : 2,
                  overflow: _isDescriptionExpanded
                      ? null
                      : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (widget.currentEpisode.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _isDescriptionExpanded ? "收起" : "展开",
                          style: const TextStyle(
                            color: Color(0xFFBB86FC),
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          _isDescriptionExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: const Color(0xFFBB86FC),
                        ),
                      ],
                    ),
                  ),
              ],
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
                      final index = widget.allEpisodes.indexOf(
                        widget.currentEpisode,
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
                    color: const Color(0xFFBB86FC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "选集",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isEpisodesExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white70,
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
                  itemCount: widget.allEpisodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ep = widget.allEpisodes[index];
                    final isSelected = ep == widget.currentEpisode;
                    final borderColor = isSelected
                        ? const Color(0xFFBB86FC)
                        : Colors.white10;
                    final textColor = Colors.white;

                    return Material(
                      color: isSelected
                          ? const Color(0xFFBB86FC).withValues(alpha: 0.1)
                          : const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => PlayerPage(
                                  anime: widget.anime,
                                  currentEpisode: ep,
                                  allEpisodes: widget.allEpisodes,
                                ),
                              ),
                            );
                          }
                        },
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
                                      ? const Color(0xFFBB86FC)
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (ep.name.isNotEmpty)
                                Text(
                                  ep.name,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.7),
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
                                    color: textColor,
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
                                  style: const TextStyle(
                                    color: Colors.white24,
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
          _buildPlaySourceSelector(),
          const SizedBox(height: 12),
          _buildResourceList(),
          const SizedBox(height: 24),

          // Recommendations
          _buildSectionHeader("相关推荐"),
          const SizedBox(height: 12),
          _buildRecommendationsList(isVertical: false),
        ],
      ),
    );
  }

  // --- PC Layout ---
  Widget _buildPCLayout(BuildContext context) {
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
                color: const Color(0xFF0F0F13),
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
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "EP ${widget.currentEpisode.sort % 1 == 0 ? widget.currentEpisode.sort.toInt() : widget.currentEpisode.sort} - ${widget.currentEpisode.nameCn.isNotEmpty ? widget.currentEpisode.nameCn : widget.currentEpisode.name}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Video Player (Large)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              color: Colors.black,
                              child: _buildVideoPlayerPlaceholder(
                                context,
                                isMobile: false,
                              ),
                            ),
                          ),

                          // Video Info Bar & Actions (Description & Stats)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            color: const Color(0xFF16161E),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Action Buttons
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

                                // Collapsible Description
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isDescriptionExpanded =
                                          !_isDescriptionExpanded;
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget
                                                .currentEpisode
                                                .description
                                                .isNotEmpty
                                            ? widget.currentEpisode.description
                                            : "暂无简介",
                                        maxLines: _isDescriptionExpanded
                                            ? null
                                            : 2,
                                        overflow: _isDescriptionExpanded
                                            ? null
                                            : TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      if (widget
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
                                                style: const TextStyle(
                                                  color: Color(0xFFBB86FC),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Icon(
                                                _isDescriptionExpanded
                                                    ? Icons.keyboard_arrow_up
                                                    : Icons.keyboard_arrow_down,
                                                size: 16,
                                                color: const Color(0xFFBB86FC),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Play Source
                                const Text(
                                  "播放源",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildPlaySourceSelector(),
                                const SizedBox(height: 12),
                                _buildResourceList(),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
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
                            _buildSectionHeader("评论区"),
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
                      const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              "暂无评论",
                              style: TextStyle(color: Colors.white54),
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
                            return _buildCommentItem(_comments[index]);
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
          color: const Color(0xFF13131A),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader("播放列表"),
                    const SizedBox(height: 12),
                    _buildInfoBox("选集", "自动连播"),
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
                    _buildRecommendationsList(isVertical: true),
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
    return Scrollbar(
      controller: _pcEpisodeScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        shrinkWrap: true,
        controller: _pcEpisodeScrollController,
        padding: const EdgeInsets.only(right: 12), // space for scrollbar
        itemCount: widget.allEpisodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ep = widget.allEpisodes[index];
          final isSelected = ep == widget.currentEpisode;

          return Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFBB86FC).withValues(alpha: 0.15)
                  : const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFBB86FC).withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => PlayerPage(
                        anime: widget.anime,
                        currentEpisode: ep,
                        allEpisodes: widget.allEpisodes,
                      ),
                    ),
                  );
                }
              },
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
                            ? const Color(0xFFBB86FC)
                            : Colors.white10,
                      ),
                      child: Text(
                        "${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}",
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
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
                                    ? const Color(0xFFBB86FC)
                                    : Colors.white,
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
                                color: Colors.white54,
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
                        style: TextStyle(color: Colors.white24, fontSize: 10),
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

  Widget _buildVideoPlayerPlaceholder(
    BuildContext context, {
    required bool isMobile,
  }) {
    // If player is initialized and we have a stream, show actual player
    if (_isPlayerInitialized && _currentStreamUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Actual video player
          Video(controller: _videoController, controls: AdaptiveVideoControls),

          // Danmaku overlay
          IgnorePointer(
            child: DanmakuOverlay(
              currentTime: _currentVideoTime,
              danmakuList: _danmakuService.danmakuList,
              settings: _danmakuService.settings,
              isPaused: _isVideoPaused,
              isPlaying: _currentStreamUrl != null,
            ),
          ),

          // Loading overlay
          if (_isLoadingVideo || _loadingMagnet != null)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFBB86FC)),
                    SizedBox(height: 16),
                    Text("正在加载视频流...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

          // Danmaku controls overlay (top right)
          Positioned(
            top: isMobile ? 8 : 16,
            right: isMobile ? 8 : 16,
            child: _buildDanmakuControls(),
          ),

          // Danmaku settings panel
          if (_showDanmakuSettings)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showDanmakuSettings = false),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {}, // Prevent close when tapping panel
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 420,
                        maxHeight: 550,
                      ),
                      child: DanmakuSettingsPanel(
                        danmakuService: _danmakuService,
                        onClose: () =>
                            setState(() => _showDanmakuSettings = false),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Header Overlay (Top) - for mobile back button
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
                  ],
                ),
              ),
            ),
        ],
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
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFBB86FC)),
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

  Widget _buildDanmakuControls() {
    return ListenableBuilder(
      listenable: _danmakuService,
      builder: (context, _) {
        final settings = _danmakuService.settings;
        final hasData = _danmakuService.danmakuList.isNotEmpty;
        final isLoading = _danmakuService.isLoading;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Danmaku count badge
              if (hasData)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBB86FC).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_danmakuService.danmakuCount}',
                    style: const TextStyle(
                      color: Color(0xFFBB86FC),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFBB86FC),
                  ),
                ),

              if (hasData) const SizedBox(width: 4),

              // Toggle button
              IconButton(
                icon: Icon(
                  settings.enabled ? Icons.subtitles : Icons.subtitles_off,
                  color: hasData
                      ? (settings.enabled
                            ? const Color(0xFFBB86FC)
                            : Colors.white54)
                      : Colors.white30,
                  size: 20,
                ),
                tooltip: settings.enabled ? '关闭弹幕' : '开启弹幕',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: hasData ? _danmakuService.toggleEnabled : null,
              ),

              // Settings button
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white54, size: 20),
                tooltip: '弹幕设置',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showDanmakuSettings = true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDanmakuText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withValues(alpha: 0.8),
          ),
          Shadow(
            offset: const Offset(-1, -1),
            blurRadius: 2,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFBB86FC),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      ],
    );
  }

  Widget _buildPlaySourceSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSourceTab("Mikan Project", "mikan")),
          Container(width: 1, color: Colors.white10),
          Expanded(child: _buildSourceTab("动漫花园", "dmhy")),
          Container(width: 1, color: Colors.white10),
          Expanded(child: _buildSourceTab("全网搜", "sample")),
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

    if (id == 'mikan') {
      isLoading = _isLoadingMikan;
      hasError = _mikanError != null;
      count = _mikanResources.length;
    } else if (id == 'dmhy') {
      isLoading = _isLoadingDmhy;
      hasError = _dmhyError != null;
      count = _dmhyResources.length;
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
              ? const Color(0xFFBB86FC).withValues(alpha: 0.1)
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
                  color: isSelected ? const Color(0xFFBB86FC) : Colors.white70,
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
                  color: isSelected ? const Color(0xFFBB86FC) : Colors.grey,
                ),
              )
            else if (hasError)
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
                      ? const Color(0xFFBB86FC).withValues(alpha: 0.2)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFBB86FC) : Colors.grey,
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
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFBB86FC),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  _isLoadingSample
                      ? _sampleStatusMessage
                      : (_sampleError != null
                            ? '搜索失败'
                            : '搜索完成 (${_sampleSuccessfulSources.length}/${_enabledSourceNames.length} 个可用)'),
                  style: TextStyle(
                    color: _sampleError != null
                        ? Colors.redAccent
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 重试按钮
              if (!_isLoadingSample)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loadSampleSource,
                  color: Colors.white54,
                  tooltip: '重新搜索',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
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

        // 如果正在使用 WebView 提取，显示所有活动的WebView
        if (_activeWebViews.isNotEmpty) ...[
          const Divider(color: Colors.white10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '并发WebView提取 (${_activeWebViews.length}/$_maxConcurrentWebViews)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 显示所有活动WebView的状态
                ..._activeWebViews.keys.map((sourceName) {
                  final page = _samplePlayPages.firstWhere(
                    (p) => p.sourceName == sourceName,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFFBB86FC),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sourceName,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                page.playPageUrl,
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
                }).toList(),
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
                const Text(
                  "显示 WebView (调试)",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ],

        // 如果有成功的源，显示播放按钮
        if (_sampleSuccessfulSources.isNotEmpty) ...[
          const Divider(color: Colors.white10),
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
                      style: const TextStyle(
                        color: Colors.white70,
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
                      setState(() {
                        _selectedSourceIndex = index;
                        _sampleVideoUrl = source.directVideoUrl;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFBB86FC).withValues(alpha: 0.15)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFBB86FC).withValues(alpha: 0.5)
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
                                ? const Color(0xFFBB86FC)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.sourceName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
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
                      ? () {
                          final source =
                              _sampleSuccessfulSources[_selectedSourceIndex];
                          final headers = <String, String>{};
                          if (source.headers != null)
                            headers.addAll(source.headers!);
                          if (source.cookies != null)
                            headers['Cookie'] = source.cookies!;

                          _player.open(
                            Media(_sampleVideoUrl!, httpHeaders: headers),
                          );
                          setState(() {
                            _currentStreamUrl = _sampleVideoUrl;
                            _isLoadingVideo = false;
                            _videoError = null;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    "播放 - ${_sampleSuccessfulSources.isNotEmpty ? _sampleSuccessfulSources[_selectedSourceIndex].sourceName : ''}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB86FC),
                    foregroundColor: Colors.black,
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
                const Icon(Icons.search_off, color: Colors.white24, size: 32),
                const SizedBox(height: 8),
                const Text(
                  "未找到资源",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadSampleSource,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("重试", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white70,
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
    // 根据状态决定图标和颜色
    IconData icon;
    Color iconColor;
    String statusText;
    String? errorText;

    if (progress == null) {
      icon = Icons.hourglass_empty;
      iconColor = Colors.white24;
      statusText = '等待中';
    } else {
      switch (progress.step) {
        case SearchStep.pending:
          icon = Icons.hourglass_empty;
          iconColor = Colors.white24;
          statusText = '等待中';
          break;
        case SearchStep.searching:
          icon = Icons.search;
          iconColor = const Color(0xFFBB86FC);
          statusText = '搜索中...';
          break;
        case SearchStep.fetchingDetail:
          icon = Icons.article_outlined;
          iconColor = const Color(0xFFBB86FC);
          statusText = '获取详情页...';
          break;
        case SearchStep.fetchingEpisodes:
          icon = Icons.list_alt;
          iconColor = const Color(0xFFBB86FC);
          statusText = '获取剧集列表...';
          break;
        case SearchStep.extractingVideo:
          icon = Icons.video_library;
          iconColor = const Color(0xFFBB86FC);
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
            ? const Color(0xFFBB86FC).withValues(alpha: 0.08)
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
                          color: isActive ? Colors.white : Colors.white70,
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

  /// 构建所有活动的 WebView 提取器（并发）
  Widget _buildWebViewExtractors() {
    if (_activeWebViews.isEmpty) {
      return const SizedBox.shrink();
    }

    // 构建所有活动WebView的列表
    return Column(
      children: _activeWebViews.keys.map((sourceName) {
        // 找到对应的页面信息
        final page = _samplePlayPages.firstWhere(
          (p) => p.sourceName == sourceName,
        );

        return WebViewVideoExtractorWidget(
          key: ValueKey('webview_$sourceName'),
          url: page.playPageUrl,
          customVideoRegex: page.videoRegex != r'$^' ? page.videoRegex : null,
          timeout: const Duration(seconds: 20),
          showWebView: _showWebView,
          onResult: (result) => _onWebViewResult(sourceName, result),
          onLog: (msg) => debugPrint('[WebView][$sourceName] $msg'),
        );
      }).toList(),
    );
  }

  Widget _buildResourceList() {
    List<dynamic> resources = [];
    if (_activeSource == 'mikan') {
      resources = _mikanResources;
    } else if (_activeSource == 'dmhy') {
      resources = _dmhyResources;
    } else if (_activeSource == 'sample') {
      return _buildSampleSourceContent();
    }

    if (resources.isEmpty) {
      if ((_activeSource == 'mikan' && _isLoadingMikan) ||
          (_activeSource == 'dmhy' && _isLoadingDmhy)) {
        return const SizedBox.shrink(); // Loader is in tab
      }
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text("暂无资源", style: TextStyle(color: Colors.white24)),
      );
    }

    return Column(
      children: resources.map((res) {
        String title = "";
        String magnet = "";
        String size = "";
        String time = "";
        int? episode;

        if (res is MikanEpisodeResource) {
          title = res.title;
          magnet = res.magnet;
          size = res.size;
          time = res.updateTime;
          episode = res.episode;
        } else if (res is DmhyResource) {
          title = res.title;
          magnet = res.magnet;
          size = res.size;
          time = res.publishDate;
          episode = res.episode;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      size,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: magnet));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text("磁力链接已复制")));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.copy, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "复制",
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      // Trigger download/play based on type
                      // Check if _downloadMagnet needs specific type
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("开始下载，可在「我的」页面查看进度")),
                      );
                      await _downloadManager.startDownload(
                        magnet: magnet,
                        name: title,
                        animeName: widget.anime.title,
                        episodeNumber: episode,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.download, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "下载",
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: (_isLoadingVideo || _loadingMagnet != null)
                        ? null
                        : () async {
                            // Adapt _playMagnet to handle generic data
                            setState(() {
                              _loadingMagnet = magnet;
                              _videoError = null;
                            });

                            try {
                              final streamUrl = await _downloadManager
                                  .startDownload(
                                    magnet: magnet,
                                    name: title,
                                    animeName: widget.anime.title,
                                    episodeNumber: episode,
                                  );

                              if (streamUrl == null) {
                                setState(() {
                                  _videoError = "无法获取播放地址";
                                  _loadingMagnet = null;
                                });
                                return;
                              }

                              debugPrint("[Player] Got stream URL: $streamUrl");
                              _currentStreamUrl = streamUrl;

                              await _player.open(Media(streamUrl));

                              setState(() {
                                _loadingMagnet = null;
                              });
                            } catch (e) {
                              debugPrint("[Player] Error playing magnet: $e");
                              setState(() {
                                _videoError = e.toString();
                                _loadingMagnet = null;
                              });
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (_isLoadingVideo || _loadingMagnet != null)
                            ? const Color(0xFFBB86FC).withValues(alpha: 0.5)
                            : const Color(0xFFBB86FC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          if (_loadingMagnet == magnet)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          else
                            const Icon(
                              Icons.play_arrow,
                              size: 12,
                              color: Colors.black,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _loadingMagnet == magnet ? "加载中" : "播放",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    if (_isLoadingComments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_commentsError != null) {
      return Center(
        child: Text(
          "加载失败: $_commentsError",
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text("暂无评论", style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentItem(BangumiEpisodeComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: comment.avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(comment.avatar),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: comment.avatar.isEmpty ? Colors.grey[800] : null,
            ),
            child: comment.avatar.isEmpty
                ? Center(
                    child: Text(
                      comment.userName.isNotEmpty ? comment.userName[0] : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + Time
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Content
                HtmlWidget(
                  comment.contentHtml,
                  textStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  customStylesBuilder: (element) {
                    if (element.localName == 'img') {
                      return {'max-width': '100%', 'max-height': '350px'};
                    }
                    return null;
                  },
                ),

                // Replies (樓中樓)
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: comment.replies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reply = entry.value;
                        final isLast = index == comment.replies.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: reply.avatar.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(reply.avatar),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: reply.avatar.isEmpty
                                      ? Colors.grey[800]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          reply.userName,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          reply.time,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    HtmlWidget(
                                      reply.contentHtml,
                                      textStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      customStylesBuilder: (element) {
                                        if (element.localName == 'img') {
                                          return {
                                            'max-width': '100%',
                                            'max-height': '350px',
                                          };
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                // Like / Reply Buttons (Mock)
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Like",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.reply, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      "Reply",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsList({required bool isVertical}) {
    if (_isLoadingRecommendations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          "暂无相关推荐",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
      );
    }

    if (isVertical) {
      return Column(
        children: _recommendations
            .map((item) => _buildRecommendationItemVertical(item))
            .toList(),
      );
    } else {
      return SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _recommendations.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return _buildRecommendationItemHorizontal(_recommendations[index]);
          },
        ),
      );
    }
  }

  Widget _buildRecommendationItemHorizontal(RankingAnime item) {
    return InkWell(
      onTap: () {
        _navigateToAnime(item);
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF252535),
                  image: item.coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item.coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.info.isNotEmpty)
              Text(
                item.info.split(' / ').first,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItemVertical(RankingAnime item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _navigateToAnime(item);
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF252535),
                image: item.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.info.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.info.split(' / ').first,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (item.score != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 10, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          "${item.score}",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          heroTagPrefix: 'player_rec_${item.bangumiId}',
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(width: 4),
            Icon(Icons.toggle_on, color: const Color(0xFFBB86FC), size: 32),
          ],
        ),
      ],
    );
  }

  Widget _buildPCActionButton(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
