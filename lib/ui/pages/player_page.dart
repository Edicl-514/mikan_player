import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/services/download_manager.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/danmaku_service.dart';
import 'package:mikan_player/services/subtitle_service.dart';
import 'package:mikan_player/services/header_injection_proxy.dart';
import 'package:mikan_player/ui/widgets/video_player_controls.dart';
import 'package:mikan_player/ui/widgets/bangumi_mask_text.dart';
import 'package:mikan_player/services/playback_history_manager.dart';

import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

class PlayerPage extends StatefulWidget {
  final AnimeInfo anime;
  final BangumiEpisode currentEpisode;
  final List<BangumiEpisode> allEpisodes;
  final int? startPositionMs; // optional start position in milliseconds

  const PlayerPage({
    super.key,
    required this.anime,
    required this.currentEpisode,
    required this.allEpisodes,
    this.startPositionMs,
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

  // Current episode (can be switched internally)
  late BangumiEpisode _currentEpisode;

  List<BangumiEpisodeComment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;
  String _commentSortMode = 'default'; // 'default' or 'time'

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
  final Map<String, bool> _activeWebViews =
      {}; // 正在运行的WebView (sourceName -> isActive)
  final Map<String, String> _webViewStatus =
      {}; // WebView状态消息 (sourceName -> message)
  final Set<String> _failedWebViewPageKeys = {}; // 提取失败的WebView Key
  int _maxConcurrentWebViews =
      3; // 最大并发WebView数量 (Reduced from 3 to prevent lag)
  int _webViewLaunchInterval = 200; // WebView启动间隔 (毫秒)
  String _sampleStatusMessage = ''; // WebView 提取状态消息
  bool _showWebView = false; // 是否显示 WebView（调试用）

  // Auto Play Logic
  bool _hasAutoPlayed = false;
  bool _isAutoPlayNextEnabled = true;

  // 每个源的搜索进度状态
  Map<String, SourceSearchProgress> _sourceProgressMap = {};
  List<String> _enabledSourceNames = []; // 所有已启用的源名称

  // Active Source
  String _activeSource = 'bt'; // 'bt' or 'sample'
  bool _isSourceControlExpanded = false;

  // Video Player
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerInitialized = false;
  bool _isLoadingVideo =
      false; // Keep for general UI loading (like initial search or player overlay)
  String? _loadingMagnet; // Track which specific magnet is being loaded
  String? _currentStreamUrl;
  String? _videoError;
  String _playingSourceLabel = '未播放';
  final DownloadManager _downloadManager = DownloadManager();

  // Danmaku
  final DanmakuService _danmakuService = DanmakuService();
  double _currentVideoTime = 0;
  bool _isVideoPaused = false;
  bool _showDanmakuSettings = false;
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

  // Header Injection Proxy
  final HeaderInjectionProxy _headerProxy = HeaderInjectionProxy();

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _pcEpisodeScrollController = ScrollController();
    _mobileEpisodeScrollController = ScrollController();

    // Initialize current episode from widget
    _currentEpisode = widget.currentEpisode;

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
        setState(() {
          _currentVideoTime = position.inMilliseconds / 1000.0;
        });

        try {
          final posMs = position.inMilliseconds;
          if ((posMs - _lastSavedPositionMs).abs() >= _saveIntervalMs) {
            _lastSavedPositionMs = posMs;
            _historyManager.addOrUpdate(
              anime: widget.anime,
              currentEpisode: _currentEpisode,
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
        setState(() {
          _isVideoPaused = !playing;
        });
        // Save position when paused
        if (!playing) {
          try {
            final posMs = (_currentVideoTime * 1000).toInt();
            _historyManager.addOrUpdate(
              anime: widget.anime,
              currentEpisode: _currentEpisode,
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
        debugPrint('[Player] Video completed, auto-playing next episode...');
        _onSkipNext();
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
    _loadSettings();
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isAutoPlayNextEnabled = prefs.getBool('auto_play_next') ?? true;
          _maxConcurrentWebViews = prefs.getInt('max_concurrent_webviews') ?? 1;
          _webViewLaunchInterval =
              prefs.getInt('webview_launch_interval') ?? 200;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
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

  // Load danmaku based on anime title and episode
  Future<void> _loadDanmaku() async {
    final animeTitle = widget.anime.title;
    final episodeNumber = _currentEpisode.sort.toInt();

    // Calculate relative episode number (1-based index in the episode list)
    final epIndex = widget.allEpisodes.indexWhere(
      (e) => e.id == _currentEpisode.id,
    );
    final relativeEpNumber = epIndex != -1 ? epIndex + 1 : episodeNumber;

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
    if (_currentEpisode.id == 0) return;

    setState(() {
      _isLoadingComments = true;
      _commentsError = null;
    });

    try {
      final comments = await fetchBangumiEpisodeComments(
        episodeId: _currentEpisode.id,
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
        targetEpisode: _currentEpisode.sort.toInt(),
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
    debugPrint("[Mikan] Current episode sort: ${_currentEpisode.sort}");

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

      if (_currentEpisode.id != 0) {
        final resources = await getMikanResources(
          mikanId: result.id,
          currentEpisodeSort: _currentEpisode.sort.toInt(),
        );

        debugPrint(
          "[Mikan] Initial load: Found ${resources.length} resources for EP ${_currentEpisode.sort.toInt()}",
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
      _failedWebViewPageKeys.clear();
      _sampleStatusMessage = '正在获取播放源列表...';
      _sourceProgressMap = {};
      _enabledSourceNames = [];
      _sourceTiers = {};
      _hasAutoPlayed = false;
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
      final currentEpNumber = _currentEpisode.sort.toInt();

      // Calculate relative episode number (1-based index in the episode list)
      final epIndex = widget.allEpisodes.indexWhere(
        (e) => e.id == _currentEpisode.id,
      );
      final relativeEpNumber = epIndex != -1 ? epIndex + 1 : currentEpNumber;

      final searchName = _buildSearchNameForSources();

      await for (final progress in genericSearchWithProgress(
        animeName: searchName,
        absoluteEpisode: currentEpNumber,
        relativeEpisode: relativeEpNumber,
      )) {
        if (!mounted) return;

        // Debug: Print channel information
        if (progress.allChannels != null && progress.allChannels!.isNotEmpty) {
          debugPrint(
            '[Channel Info] ${progress.sourceName}: Found ${progress.allChannels!.length} channels: '
            '${progress.allChannels!.map((c) => '${c.name}(${c.index})').join(', ')}',
          );
        }

        setState(() {
          // 更新该源的进度
          _sourceProgressMap[progress.sourceName] = progress;

          // 如果搜索成功，添加到成功列表
          if (progress.step == SearchStep.success &&
              progress.playPageUrl != null) {
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
            if (progress.allChannels != null &&
                progress.allChannels!.isNotEmpty) {
              debugPrint(
                '[Multi-Channel] ${progress.sourceName}: Creating results for ${progress.allChannels!.length} channels',
              );

              for (int i = 0; i < progress.allChannels!.length; i++) {
                final channel = progress.allChannels![i];
                final result = SearchPlayResult(
                  sourceName: progress.sourceName,
                  playPageUrl: progress.playPageUrl!,
                  videoRegex: progress.videoRegex ?? '',
                  directVideoUrl: progress.directVideoUrl,
                  cookies: progress.cookies,
                  headers: progress.headers,
                  channelName: channel.name,
                  channelIndex: channel.index,
                );

                // 避免重复添加（使用sourceName + channelIndex作为唯一标识）
                final key = '${progress.sourceName}_${channel.index}';
                if (!_samplePlayPages.any(
                  (p) => '${p.sourceName}_${p.channelIndex}' == key,
                )) {
                  debugPrint(
                    '[Add Channel Result] ${progress.sourceName} - Channel: ${channel.name}(${channel.index})',
                  );
                  _samplePlayPages.add(result);

                  // 如果没有直接视频URL，标记需要WebView提取
                  if (progress.directVideoUrl == null ||
                      progress.directVideoUrl!.isEmpty) {
                    needsWebViewExtraction = true;
                  }
                }

                // 如果有直接视频URL，也添加到成功列表
                if (progress.directVideoUrl != null &&
                    progress.directVideoUrl!.isNotEmpty) {
                  if (!_sampleSuccessfulSources.any(
                    (s) => '${s.sourceName}_${s.channelIndex}' == key,
                  )) {
                    _sampleSuccessfulSources.add(result);
                  }
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
              );

              // 避免重复添加
              if (!_samplePlayPages.any(
                (p) => p.sourceName == progress.sourceName,
              )) {
                _samplePlayPages.add(result);

                // 如果没有直接视频URL，标记需要WebView提取
                if (progress.directVideoUrl == null ||
                    progress.directVideoUrl!.isEmpty) {
                  needsWebViewExtraction = true;
                }
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

            // 如果该源需要WebView提取，立即尝试启动（不等待所有源完成）
            if (needsWebViewExtraction) {
              debugPrint(
                '[Immediate WebView] Starting WebView extraction for ${progress.sourceName}',
              );
              // 按Tier排序_samplePlayPages，确保低Tier的源优先提取
              _samplePlayPages.sort((a, b) {
                final tierA = _sourceTiers[a.sourceName] ?? 999;
                final tierB = _sourceTiers[b.sourceName] ?? 999;
                return tierA.compareTo(tierB);
              });
              _startNextWebViewExtraction();
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

      setState(() {
        // 检查是否有任何成功的源
        if (_samplePlayPages.isEmpty) {
          _sampleError = '未在任何源中找到该动画';
          _isLoadingSample = false;
        } else if (_sampleSuccessfulSources.isEmpty) {
          // 所有源都需要WebView提取，等待WebView完成
          _sampleStatusMessage = '常规搜索完成，WebView提取进行中...';
        } else {
          // 部分源已成功，部分可能还在WebView提取中
          _sampleStatusMessage =
              '常规搜索完成，已找到 ${_sampleSuccessfulSources.length} 个可用源';
        }
      });
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

    // 仅允许Tier 0自动播放
    final candidates = _sampleSuccessfulSources
        .where((s) => (_sourceTiers[s.sourceName] ?? 999) == 0)
        .toList();

    debugPrint(
      "[_attemptAutoPlay] Found ${candidates.length} Tier 0 candidates. Total sources: ${_sampleSuccessfulSources.length}",
    );

    if (candidates.isNotEmpty) {
      _playSource(candidates.first);
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

      // Check if this source needs Referer header (proxy)
      final needsReferer = _needsRefererHeader(_sampleVideoUrl!);

      String urlToPlay;
      if (needsReferer) {
        // Use proxy for sources that need Referer
        final headers = <String, String>{
          'Referer': source.playPageUrl,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
        urlToPlay = _headerProxy.registerUrl(_sampleVideoUrl!, headers);
        debugPrint('[_playSource] Auto-play (Tier 0) - using proxy:');
        debugPrint('  Original URL: $_sampleVideoUrl');
        debugPrint('  Proxied URL: $urlToPlay');
      } else {
        // Use direct URL for sources that don't need Referer
        urlToPlay = _sampleVideoUrl!;
        debugPrint('[_playSource] Auto-play (Tier 0) - using direct URL:');
        debugPrint('  URL: $urlToPlay');
      }

      // Store the URL to play
      _currentStreamUrl = urlToPlay;
      _playingSourceLabel = source.sourceName;

      // 停止之前的播放，防止后台继续播放
      _player.stop();

      try {
        // Auto-play for Tier 0 sources
        _player
            .open(Media(urlToPlay), play: true)
            .then((_) => _applyPendingStartPosition());
        debugPrint('[_playSource] Media loaded and auto-playing (Tier 0).');
      } catch (e, st) {
        debugPrint('[_playSource] ERROR loading media: $e\n$st');
        _videoError = '播放器打开失败: $e';
      }

      _isLoadingVideo = false;
      _videoError = null;
    });
  }

  /// WebView 提取结果回调（并发版本）
  void _onWebViewResult(String pageKey, VideoExtractResult result) {
    debugPrint(
      '[_onWebViewResult] pageKey=$pageKey, success=${result.success}, videoUrl=${result.videoUrl}, error=${result.error}',
    );
    if (!mounted) return;

    setState(() {
      // 移除活动WebView
      _activeWebViews.remove(pageKey);
      _webViewStatus.remove(pageKey);

      if (!result.success) {
        _failedWebViewPageKeys.add(pageKey);
      }

      if (result.success) {
        // 从pageKey解析出sourceName和channelIndex
        final parts = pageKey.split('_');
        if (parts.length >= 2) {
          final sourceName = parts.sublist(0, parts.length - 1).join('_');
          final channelIndexStr = parts.last;
          final channelIndex = channelIndexStr == '-1'
              ? null
              : int.tryParse(channelIndexStr);

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

            final resultHeaders = <String, String>{};
            if (page.headers != null) resultHeaders.addAll(page.headers!);
            resultHeaders.addAll(result.headers);

            debugPrint(
              '[_onWebViewResult] Captured headers: ${resultHeaders.keys.join(", ")}',
            );

            final updatedPage = SearchPlayResult(
              sourceName: page.sourceName,
              playPageUrl: page.playPageUrl,
              videoRegex: page.videoRegex,
              directVideoUrl: result.videoUrl,
              cookies: page.cookies,
              headers: resultHeaders,
              channelName: page.channelName,
              channelIndex: page.channelIndex,
            );

            _sampleSuccessfulSources.add(updatedPage);

            // 如果这是第一个成功提取且没有其他源在播放
            debugPrint(
              '[_onWebViewResult] _sampleVideoUrl currently=$_sampleVideoUrl',
            );
            // 尝试自动播放（遵循Tier规则）
            _attemptAutoPlay();
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
              debugPrint(
                '[_onWebViewResult] _samplePlayPages summary: $summary',
              );
            } catch (e) {
              debugPrint(
                '[_onWebViewResult] Failed to summarize _samplePlayPages: $e',
              );
            }
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
  /// 启动下一个WebView提取任务
  void _startNextWebViewExtraction() {
    if (!mounted) return;

    // 延迟启动，避免连续启动造成的UI卡顿，同时确保上一个WebView有足够时间释放资源
    Future.delayed(Duration(milliseconds: _webViewLaunchInterval), () {
      if (!mounted) return;

      // 如果已经达到并发上限，不启动新的
      if (_activeWebViews.length >= _maxConcurrentWebViews) return;

      // 创建唯一标识：sourceName + channelIndex
      String getPageKey(SearchPlayResult page) {
        return '${page.sourceName}_${page.channelIndex ?? -1}';
      }

      // 找到下一个需要提取的源
      final needsExtraction = _samplePlayPages.where((page) {
        final pageKey = getPageKey(page);
        final alreadySuccessful = _sampleSuccessfulSources.any(
          (s) => getPageKey(s) == pageKey,
        );
        final alreadyActive = _activeWebViews.containsKey(pageKey);
        final alreadyFailed = _failedWebViewPageKeys.contains(pageKey);
        return !alreadySuccessful && !alreadyActive && !alreadyFailed;
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
      final pageKey = getPageKey(page);
      setState(() {
        _activeWebViews[pageKey] = true;
        _webViewStatus[pageKey] = '正在提取...';
      });
    });
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisode.id != _currentEpisode.id) {
      _loadComments();
    }
    if (oldWidget.anime.bangumiId != widget.anime.bangumiId) {
      _loadRecommendations();
      _loadMikanSource(); // Anime changed, reload search
      _loadDmhySource();
    } else if (oldWidget.currentEpisode.sort != _currentEpisode.sort) {
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
      "[Mikan] Reloading resources for new episode: ${_currentEpisode.sort.toInt()}",
    );
    debugPrint("[Mikan] Using existing anime ID: ${_mikanAnime!.id}");

    setState(() {
      _isLoadingMikan = true;
      _mikanResources = []; // Clear previous episode resources
    });
    try {
      final resources = await getMikanResources(
        mikanId: _mikanAnime!.id,
        currentEpisodeSort: _currentEpisode.sort.toInt(),
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
      final posMs = (_currentVideoTime * 1000).toInt();
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: posMs,
      );
    } catch (e) {
      debugPrint('Error saving final playback position: $e');
    }
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _mobileTabController.dispose();
    _pcEpisodeScrollController.dispose();
    _mobileEpisodeScrollController.dispose();
    _subtitleService.dispose();
    _player.stop(); // 确保播放器完全停止后再释放
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
            _currentEpisode.nameCn.isNotEmpty
                ? _currentEpisode.nameCn
                : _currentEpisode.name,
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
                  "EP ${_currentEpisode.sort % 1 == 0 ? _currentEpisode.sort.toInt() : _currentEpisode.sort}",
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
              // View count removed
              /*
              const Spacer(),
              const Icon(Icons.remove_red_eye, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              const Text(
                "1.2M",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              */
              const Spacer(),
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
                color: const Color.fromARGB(255, 20, 20, 25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentEpisode.description.isNotEmpty
                        ? _currentEpisode.description
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
                  if (_currentEpisode.description.isNotEmpty)
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
                      final index = widget.allEpisodes.indexOf(_currentEpisode);
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
                    final isSelected = ep == _currentEpisode;
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
          _buildPlaySourceSelector(isMobile: true),
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
                                "EP ${_currentEpisode.sort % 1 == 0 ? _currentEpisode.sort.toInt() : _currentEpisode.sort} - ${_currentEpisode.nameCn.isNotEmpty ? _currentEpisode.nameCn : _currentEpisode.name}",
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
                            color: const Color(0xFF0F0F13),
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
                                      color: const Color.fromARGB(
                                        255,
                                        20,
                                        20,
                                        25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget
                                                  .currentEpisode
                                                  .description
                                                  .isNotEmpty
                                              ? widget
                                                    .currentEpisode
                                                    .description
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
                                                      : Icons
                                                            .keyboard_arrow_down,
                                                  size: 16,
                                                  color: const Color(
                                                    0xFFBB86FC,
                                                  ),
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
                                const Text(
                                  "播放源",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildPlaySourceSelector(isMobile: false),
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
                    const Text(
                      "选集",
                      style: TextStyle(
                        color: Colors.white,
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
          final isSelected = ep == _currentEpisode;

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

  void _onSkipNext() {
    final currentIndex = widget.allEpisodes.indexOf(_currentEpisode);
    if (currentIndex < widget.allEpisodes.length - 1) {
      _onEpisodeSelected(widget.allEpisodes[currentIndex + 1]);
    }
  }

  void _onEpisodeSelected(BangumiEpisode ep) {
    if (ep.id == _currentEpisode.id) return;

    // Stop current player
    _player.stop();

    // Update current episode and reset all states
    setState(() {
      _currentEpisode = ep;

      // Reset video playback state
      _currentStreamUrl = null;
      _sampleVideoUrl = null;
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
      _selectedSourceIndex = 0;
      _activeWebViews.clear();
      _webViewStatus.clear();
      _sampleStatusMessage = '';
      _sourceProgressMap = {};
      _hasAutoPlayed = false;

      // Reset comments
      _comments = [];
      _isLoadingComments = false;
      _commentsError = null;
    });

    _savePlaybackHistory();

    // Clear and reload danmaku
    _danmakuService.clearDanmaku();
    _loadDanmaku();

    // Reload comments
    _loadComments();

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
      final posMs = (_currentVideoTime * 1000).toInt();
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _currentEpisode,
        allEpisodes: widget.allEpisodes,
        lastPositionMs: posMs,
      );
      _lastSavedPositionMs = posMs;
    } catch (e) {
      _historyManager.addOrUpdate(
        anime: widget.anime,
        currentEpisode: _currentEpisode,
        allEpisodes: widget.allEpisodes,
      );
    }
  }

  // Helper to sanitize headers (remove duplicates, empty values, unify case)
  Map<String, String> _sanitizeHeaders(Map<String, String>? input) {
    if (input == null) return {};
    final Map<String, String> cleaned = {};

    // Prioritize standard keys
    final keyMap = {
      'referer': 'Referer',
      'user-agent': 'User-Agent',
      'cookie': 'Cookie',
      'accept': 'Accept',
    };

    input.forEach((k, v) {
      if (v.isEmpty) return; // Skip empty values

      final lowerK = k.toLowerCase();
      final standardK = keyMap[lowerK] ?? k;

      cleaned[standardK] = v;
    });

    return cleaned;
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

    setState(() {
      _isLoadingVideo = true;
      _videoError = null;
    });

    final urlToPlay = source.directVideoUrl!;
    final needsReferer = _needsRefererHeader(urlToPlay);

    String finalUrl;
    if (needsReferer) {
      // Use proxy for sources that need Referer
      final headers = <String, String>{
        'Referer': source.playPageUrl,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
      finalUrl = _headerProxy.registerUrl(urlToPlay, headers);
      debugPrint('[_startPlayback] Using proxy for: $urlToPlay');
    } else {
      finalUrl = urlToPlay;
      debugPrint('[_startPlayback] Using direct URL for: $urlToPlay');
    }

    setState(() {
      _currentStreamUrl = finalUrl;
    });

    // Open media and start playing
    _player.stop();
    try {
      _player.open(Media(finalUrl), play: true).then((_) {
        setState(() => _isLoadingVideo = false);
        _applyPendingStartPosition();
      });
      debugPrint('[_startPlayback] Media loading started.');
    } catch (e, st) {
      debugPrint('[_startPlayback] ERROR loading media: $e');
      debugPrint('Stack trace: $st');
      setState(() {
        _isLoadingVideo = false;
        _videoError = "播放失败: $e";
      });
    }
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
          return Video(
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
              currentVideoTime: _currentVideoTime,
              isVideoPaused: _isVideoPaused,
              showDanmakuSettings: _showDanmakuSettings,
              onToggleDanmakuSettings: () =>
                  setState(() => _showDanmakuSettings = !_showDanmakuSettings),
              allEpisodes: widget.allEpisodes,
              currentEpisode: _currentEpisode,
              onEpisodeSelected: _onEpisodeSelected,
              isAutoPlayNextEnabled: _isAutoPlayNextEnabled,
              onToggleAutoPlayNext: () {
                final newValue = !_isAutoPlayNextEnabled;
                setState(() {
                  _isAutoPlayNextEnabled = newValue;
                });
                _saveAutoPlaySetting(newValue);
              },
              availableSources: _sampleSuccessfulSources,
              sourceIndexNotifier: _selectedSourceIndexNotifier,
              currentSourceLabel: _playingSourceLabel,
              onSourceSelected: (index) {
                _onSourceSelected(index);
                _startPlaybackFromSelectedSource();
              },
              isLoading: _isLoadingVideo || _loadingMagnet != null,
              videoTitle:
                  '${widget.anime.title} - 第${_currentEpisode.sort.toInt()}集',
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

  Widget _buildSortButton() {
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
      color: const Color(0xFF1E1E2C),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'default',
          child: Row(
            children: [
              Icon(Icons.sort, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text("默认排序", style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'time',
          child: Row(
            children: [
              Icon(Icons.access_time, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                "按时间排序",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, color: Colors.white54, size: 16),
          const SizedBox(width: 4),
          Text(
            _commentSortMode == 'default' ? "默认排序" : "按时间排序",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
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
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ] else ...[
          const Spacer(),
          // const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
        ],
      ],
    );
  }

  Widget _buildPlaySourceSelector({required bool isMobile}) {
    final btCount = _mikanResources.length + _dmhyResources.length;
    final onlineCount = _sampleSuccessfulSources.length;
    final currentLabel = _playingSourceLabel;

    if (!_isSourceControlExpanded) {
      return InkWell(
        onTap: () => setState(() => _isSourceControlExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 20, 20, 25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: isMobile
                    ? Row(
                        children: [
                          const Text(
                            "已找到 ",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "$btCount",
                            style: const TextStyle(
                              color: Color(0xFFBB86FC),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: const Icon(
                              Icons.download_for_offline,
                              size: 14,
                              color: Color(0xFFBB86FC),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$onlineCount",
                            style: const TextStyle(
                              color: Color(0xFF03DAC6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: const Icon(
                              Icons.subscriptions,
                              size: 14,
                              color: Color(0xFF03DAC6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "当前：$currentLabel",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "已找到 $btCount 个BT源， $onlineCount 个订阅源，当前源：$currentLabel",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSourceTab("BT", "bt")),
          Container(width: 1, color: Colors.white10),
          Expanded(child: _buildSourceTab("订阅源", "sample")),
          InkWell(
            onTap: () => setState(() => _isSourceControlExpanded = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              alignment: Alignment.center,
              child: const Icon(
                Icons.keyboard_arrow_up,
                color: Colors.white70,
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
      count = _mikanResources.length + _dmhyResources.length;
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
                ..._activeWebViews.keys.map((pageKey) {
                  // 从pageKey解析出sourceName和channelIndex
                  final parts = pageKey.split('_');
                  final sourceName = parts.length > 1
                      ? parts.sublist(0, parts.length - 1).join('_')
                      : pageKey;
                  final channelIndexStr = parts.isNotEmpty ? parts.last : '-1';
                  final channelIndex = channelIndexStr == '-1'
                      ? null
                      : int.tryParse(channelIndexStr);

                  // 找到对应页面
                  final page = _samplePlayPages.firstWhere((p) {
                    final pIdx = p.channelIndex == null
                        ? null
                        : p.channelIndex!.toInt();
                    return p.sourceName == sourceName && (pIdx == channelIndex);
                  }, orElse: () => _samplePlayPages.first);

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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sourceName,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  if (page.channelName != null &&
                                      page.channelName!.isNotEmpty)
                                    Text(
                                      " - ${page.channelName}",
                                      style: const TextStyle(
                                        color: Color(0xFFBB86FC),
                                        fontSize: 9,
                                      ),
                                    ),
                                ],
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
                      _onSourceSelected(index);
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
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
                                          style: const TextStyle(
                                            color: Color(0xFFBB86FC),
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
      children: _activeWebViews.keys.map((pageKey) {
        // 从pageKey解析出sourceName和channelIndex
        final parts = pageKey.split('_');
        final sourceName = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('_')
            : pageKey;
        final channelIndexStr = parts.isNotEmpty ? parts.last : '-1';
        final channelIndex = channelIndexStr == '-1'
            ? null
            : int.tryParse(channelIndexStr);

        // 找到对应的页面信息
        final page = _samplePlayPages.firstWhere((p) {
          final pIdx = p.channelIndex == null ? null : p.channelIndex!.toInt();
          return p.sourceName == sourceName && (pIdx == channelIndex);
        }, orElse: () => _samplePlayPages.first);

        return WebViewVideoExtractorWidget(
          key: ValueKey('webview_$pageKey'),
          url: page.playPageUrl,
          customVideoRegex: page.videoRegex != r'$^' ? page.videoRegex : null,
          timeout: const Duration(seconds: 20),
          showWebView: _showWebView,
          onResult: (result) => _onWebViewResult(pageKey, result),
          onLog: (msg) => debugPrint('[WebView][$pageKey] $msg'),
        );
      }).toList(),
    );
  }

  Widget _buildResourceList() {
    if (!_isSourceControlExpanded) {
      return const SizedBox.shrink();
    }
    List<dynamic> resources = [];
    if (_activeSource == 'bt') {
      resources = [..._mikanResources, ..._dmhyResources];
    } else if (_activeSource == 'sample') {
      return _buildSampleSourceContent();
    }

    if (resources.isEmpty) {
      if ((_activeSource == 'bt' && (_isLoadingMikan || _isLoadingDmhy))) {
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

                              // 停止之前的播放，防止后台继续播放
                              await _player.stop();
                              await _player.open(Media(streamUrl));
                              await _applyPendingStartPosition();

                              setState(() {
                                _loadingMagnet = null;
                                _playingSourceLabel = "BT";
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text(
                "全部评论",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildSortButton(),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              return _buildCommentItem(_comments[index]);
            },
          ),
        ),
      ],
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
                  customWidgetBuilder: (element) {
                    if (element.classes.contains('text_mask')) {
                      return BangumiMaskText(
                        html: element.innerHtml,
                        textStyle: const TextStyle(fontSize: 14, height: 1.5),
                      );
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
                                      customWidgetBuilder: (element) {
                                        if (element.classes.contains(
                                          'text_mask',
                                        )) {
                                          return BangumiMaskText(
                                            html: element.innerHtml,
                                            textStyle: const TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          );
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
}
