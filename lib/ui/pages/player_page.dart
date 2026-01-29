import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mikan_player/services/download_manager.dart';

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

    _loadComments();
    _loadRecommendations();
    _loadRecommendations();
    _loadMikanSource();
    _loadDmhySource();
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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Deep dark background
      body: isWide ? _buildPCLayout(context) : _buildMobileLayout(context),
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
          _buildSectionHeader("选集"),
          const SizedBox(height: 12),
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
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFBB86FC) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _buildResourceList() {
    List<dynamic> resources = [];
    if (_activeSource == 'mikan') {
      resources = _mikanResources;
    } else {
      resources = _dmhyResources;
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
