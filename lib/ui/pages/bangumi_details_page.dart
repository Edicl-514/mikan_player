import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/services/bangumi_details_service.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_mask_text.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'player_page.dart';
import 'tag_browse_page.dart';
import 'character_detail_page.dart';
import 'person_detail_page.dart';

/// Bangumi-data `site` key → asset filename under `assets/images/sites/`.
/// Adding a new entry here is enough to make the icon show up; missing
/// entries fall back to a generic globe icon.
const Map<String, String> _kSiteIconMap = {
  'bangumi': 'bangumi.png',
  'bangumi_moe': 'bangumi_moe.png',
  'bilibili': 'bilibili.png',
  'bilibili_hk_mo': 'bilibili.png',
  'bilibili_hk_mo_tw': 'bilibili.png',
  'bilibili_tw': 'bilibili.png',
  'acfun': 'acfun.png',
  'youku': 'youku.png',
  'qq': 'qq.png',
  'iqiyi': 'iqiyi.png',
  'letv': 'letv.png',
  'mgtv': 'mgtv.png',
  'nicovideo': 'nicovideo.png',
  'netflix': 'netflix.png',
  'gamer': 'gamer.png',
  'gamer_hk': 'gamer.png',
  'gamer_tw': 'gamer.png',
  'muse_hk': 'muse.png',
  'muse_tw': 'muse.png',
  'ani_one': 'ani_one.png',
  'ani_one_asia': 'ani_one.png',
  'viu': 'viu.png',
  'mytv': 'mytv.png',
  'disneyplus': 'disneyplus.png',
  'abema': 'abema.png',
  'unext': 'unext.png',
  'tropics': 'tropics.png',
  'prime': 'prime.png',
  'danime': 'danime.png',
  'dmhy': 'dmhy.png',
  'mikan': 'mikan.png',
  'tmdb': 'tmdb.png',
  'mal': 'mal.png',
  'anidb': 'anidb.png',
  'aniList': 'anilist.png',
};

class BangumiDetailsPage extends StatefulWidget {
  final AnimeInfo anime;
  final String? heroTag;
  final bool enableCharacterHero;

  const BangumiDetailsPage({
    super.key,
    required this.anime,
    this.heroTag,
    this.enableCharacterHero = true,
  });

  @override
  State<BangumiDetailsPage> createState() => _BangumiDetailsPageState();
}

class _BangumiDetailsPageState extends State<BangumiDetailsPage> {
  final BangumiDetailsService _detailsService = BangumiDetailsService.instance;
  Map<String, dynamic>? _data;
  late ScrollController _mobileDetailsScrollController;
  late ScrollController _wideLeftScrollController;
  late ScrollController _wideRightScrollController;

  // Bangumi API data
  List<BangumiEpisode>? _episodes;
  List<BangumiCharacter>? _characters;
  List<BangumiRelatedSubject>? _relations;
  List<BangumiComment>? _comments;
  List<BangumiDataSiteEntry>? _sites;

  // Person name → id mapping (built from persons API + character actors)
  final Map<String, int> _personIdMap = {};

  bool _isLoadingEpisodes = false;
  bool _isLoadingCharacters = false;
  bool _isLoadingRelations = false;
  bool _isLoadingComments = false;
  bool _hasRequestedComments = false;
  bool _isLocalFavorite = false;
  bool _isCopied = false;
  Timer? _copyTimer;
  bool _showOriginalSummary = false;
  bool _isInfoBoxExpanded = false;

  // Pre-sorted characters to avoid sorting in build
  List<BangumiCharacter>? _sortedCharacters;

  // Pagination State
  int _commentPage = 1;
  bool _hasMoreComments = true;
  bool _isLoadingMoreComments = false;
  late ScrollController _episodesScrollController;
  late ScrollController _charactersScrollController;
  late ScrollController _relationsScrollController;
  late ScrollController _sitesScrollController;

  @override
  void initState() {
    super.initState();
    _mobileDetailsScrollController = createPlatformScrollController();
    _wideLeftScrollController = createPlatformScrollController();
    _wideRightScrollController = createPlatformScrollController();
    _wideRightScrollController.addListener(_handleWideRightScroll);
    _episodesScrollController = createPlatformScrollController();
    _charactersScrollController = createPlatformScrollController();
    _relationsScrollController = createPlatformScrollController();
    _sitesScrollController = createPlatformScrollController();
    _parseData();
    _checkFavoriteStatus();
    _primeInitialDataFromCache();
    _fetchBangumiData();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is OverscrollNotification) {
      _tryLoadMoreComments(notification.metrics);
    }
    return false;
  }

  void _handleWideRightScroll() {
    if (!_wideRightScrollController.hasClients) return;
    _tryLoadMoreComments(_wideRightScrollController.position);
  }

  void _tryLoadMoreComments(ScrollMetrics metrics) {
    if (metrics.pixels >= metrics.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments || !_hasMoreComments || !_hasRequestedComments) {
      return;
    }

    setState(() {
      _isLoadingMoreComments = true;
    });

    try {
      final subjectIdStr = widget.anime.bangumiId;
      if (subjectIdStr == null) {
        setState(() => _isLoadingMoreComments = false);
        return;
      }
      final subjectId = int.parse(subjectIdStr);

      final newComments = await _detailsService.fetchCommentsPage(
        subjectId: subjectId,
        page: _commentPage + 1,
      );

      if (mounted) {
        setState(() {
          if (newComments.isEmpty) {
            _hasMoreComments = false;
          } else {
            _comments?.addAll(newComments);
            _commentPage++;
          }
          _isLoadingMoreComments = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading more comments: $e");
      if (mounted) {
        setState(() {
          _isLoadingMoreComments = false;
        });
      }
    }
  }

  Future<void> _ensureCommentsLoaded() async {
    if (_hasRequestedComments || _isLoadingComments) return;

    final subjectIdStr = widget.anime.bangumiId;
    if (subjectIdStr == null) return;

    final subjectId = int.tryParse(subjectIdStr);
    if (subjectId == null) return;

    setState(() {
      _hasRequestedComments = true;
      _isLoadingComments = true;
      _commentPage = 1;
      _hasMoreComments = true;
      _isLoadingMoreComments = false;
      _comments = null;
    });

    try {
      final comments = await _detailsService.fetchCommentsPage(
        subjectId: subjectId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _hasMoreComments = comments.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _hasMoreComments = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _fetchBangumiData() async {
    final subjectIdStr = widget.anime.bangumiId;
    if (subjectIdStr == null) {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
          _isLoadingCharacters = false;
          _isLoadingRelations = false;
          _isLoadingComments = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingEpisodes = true;
      _isLoadingCharacters = true;
      _isLoadingRelations = true;
      _isLoadingComments = false;
      _hasRequestedComments = false;
      _commentPage = 1;
      _hasMoreComments = true;
      _isLoadingMoreComments = false;
      _episodes = null;
      _characters = null;
      _relations = null;
      _comments = null;
      _personIdMap.clear();
    });

    final result = await _detailsService.loadInitialData(
      anime: widget.anime,
      includeSubjectDetails: _data == null,
    );

    if (!mounted) return;

    final sortedCharacters = [...result.characters]
      ..sort((a, b) {
        final pa = _characterRolePriority(a);
        final pb = _characterRolePriority(b);
        return pa != pb ? pa.compareTo(pb) : a.name.compareTo(b.name);
      });

    setState(() {
      _data ??= result.subjectData;
      if (result.episodes.isNotEmpty ||
          _episodes == null ||
          _episodes!.isEmpty) {
        _episodes = result.episodes;
      }
      if (sortedCharacters.isNotEmpty ||
          _characters == null ||
          _characters!.isEmpty) {
        _characters = sortedCharacters;
        _sortedCharacters = sortedCharacters;
      }
      if (result.relations.isNotEmpty ||
          _relations == null ||
          _relations!.isEmpty) {
        _relations = result.relations;
      }
      if (result.sites.isNotEmpty) {
        _sites = result.sites;
      }
      _mergePersonIdMap(result.personIdMap);
      _isLoadingEpisodes = false;
      _isLoadingCharacters = false;
      _isLoadingRelations = false;
    });

    if (mounted) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () async {
          if (!mounted) return;
          await _ensureCommentsLoaded();
        }),
      );
    }
  }

  Future<void> _primeInitialDataFromCache() async {
    final result = await _detailsService.loadCachedInitialData(
      anime: widget.anime,
      includeSubjectDetails: _data == null,
    );
    if (!mounted || result == null) return;

    final sortedCharacters = [...result.characters]
      ..sort((a, b) {
        final pa = _characterRolePriority(a);
        final pb = _characterRolePriority(b);
        return pa != pb ? pa.compareTo(pb) : a.name.compareTo(b.name);
      });

    setState(() {
      _data ??= result.subjectData;
      if (result.episodes.isNotEmpty) {
        _episodes = result.episodes;
        _isLoadingEpisodes = false;
      }
      if (sortedCharacters.isNotEmpty) {
        _characters = sortedCharacters;
        _sortedCharacters = sortedCharacters;
        _isLoadingCharacters = false;
      }
      if (result.relations.isNotEmpty) {
        _relations = result.relations;
        _isLoadingRelations = false;
      }
      if (result.sites.isNotEmpty) {
        _sites = result.sites;
      }
      _mergePersonIdMap(result.personIdMap);
    });
  }

  void _parseData() {
    if (widget.anime.fullJson != null) {
      try {
        _data = jsonDecode(widget.anime.fullJson!);
      } catch (e) {
        debugPrint('Error parsing fullJson: $e');
      }
    }
  }

  List<String> _extractCurrentTags() {
    final rawTags = _data?['tags'];
    if (rawTags is! List) {
      return widget.anime.tags;
    }

    final tags = <String>[];
    final seen = <String>{};
    for (final item in rawTags) {
      String value = '';
      if (item is Map) {
        value = item['name']?.toString().trim() ?? '';
      } else {
        value = item?.toString().trim() ?? '';
      }
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) {
        tags.add(value);
      }
    }
    return tags.isNotEmpty ? tags : widget.anime.tags;
  }

  AnimeInfo _buildAnimeForPlayer() {
    final currentNameCn = _data?['name_cn']?.toString().trim() ?? '';

    return AnimeInfo(
      title: widget.anime.title,
      subTitle: currentNameCn.isNotEmpty ? currentNameCn : widget.anime.subTitle,
      bangumiId: widget.anime.bangumiId,
      mikanId: widget.anime.mikanId,
      coverUrl: widget.anime.coverUrl,
      siteUrl: widget.anime.siteUrl,
      broadcastDay: widget.anime.broadcastDay,
      broadcastTime: widget.anime.broadcastTime,
      score: widget.anime.score,
      rank: widget.anime.rank,
      tags: _extractCurrentTags(),
      fullJson: _data != null ? jsonEncode(_data) : widget.anime.fullJson,
    );
  }

  // Parse summary to extract translation and original text
  Map<String, String?> _parseSummary(String? summary) {
    if (summary == null || summary.isEmpty) {
      return {'translation': null, 'original': null};
    }

    // Check if summary contains the separator
    final separatorIndex = summary.indexOf('[简介原文]');
    if (separatorIndex == -1) {
      // No separator, treat entire text as translation
      return {'translation': summary, 'original': null};
    }

    // Split into translation and original
    final translation = summary.substring(0, separatorIndex).trim();
    final original = summary.substring(separatorIndex + '[简介原文]'.length).trim();

    return {'translation': translation, 'original': original};
  }

  String? _getDisplaySummary() {
    final summary = _data?['summary'];
    final parsed = _parseSummary(summary);

    if (_showOriginalSummary) {
      return parsed['original'] ?? parsed['translation'];
    } else {
      return parsed['translation'];
    }
  }

  bool _hasBothTranslationAndOriginal() {
    final summary = _data?['summary'];
    final parsed = _parseSummary(summary);
    return parsed['translation'] != null && parsed['original'] != null;
  }

  Future<void> _checkFavoriteStatus() async {
    final idStr = widget.anime.bangumiId;
    if (idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;

    final isFav = await FavoritesManager().isFavorite(id);
    if (mounted) {
      setState(() {
        _isLocalFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final idStr = widget.anime.bangumiId;
    if (idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;

    final manager = FavoritesManager();
    if (_isLocalFavorite) {
      await manager.removeFavorite(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).removeFromFavorites),
          ),
        );
      }
    } else {
      await manager.addFavorite(
        bangumiId: id,
        title: widget.anime.title,
        coverUrl: widget.anime.coverUrl ?? '',
        score: widget.anime.score ?? 0.0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).addToLocalFavorites),
          ),
        );
      }
    }
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _wideRightScrollController.removeListener(_handleWideRightScroll);
    _mobileDetailsScrollController.dispose();
    _wideLeftScrollController.dispose();
    _wideRightScrollController.dispose();
    _episodesScrollController.dispose();
    _charactersScrollController.dispose();
    _relationsScrollController.dispose();
    _sitesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are on a wide screen (PC)
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isWide ? _buildWideLayout(context) : _buildMobileLayout(context),
    );
  }

  // --- Mobile Layout (Refined based on screenshot) ---
  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight:
                    380, // Increased to accommodate the new stats card
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: bgColor,
                surfaceTintColor: bgColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildMobileHeaderContent(context),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      labelColor: isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      unselectedLabelColor: isDark
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: const [
                        Tab(text: "详情"), // Details
                        Tab(
                          text: "评论",
                        ), // Comments (Merged Reviews & Discussion)
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildMobileDetailsTab(context),
              Builder(
                builder: (context) {
                  if (!_hasRequestedComments && !_isLoadingComments) {
                    unawaited(_ensureCommentsLoaded());
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: _isLoadingComments
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildSectionTitle(
                                  context,
                                  "评论",
                                  isDarkBg: isDark,
                                ),
                              ),
                              const SizedBox(height: 96),
                              Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  '加载中...',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _comments == null || _comments!.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildSectionTitle(
                                  context,
                                  "评论",
                                  isDarkBg: isDark,
                                ),
                              ),
                              const SizedBox(height: 96),
                              Center(
                                child: Text(
                                  '暂无评论',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                (_comments == null ? 0 : _comments!.length) +
                                1 +
                                (_isLoadingMoreComments ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildSectionTitle(
                                    context,
                                    "评论",
                                    isDarkBg: isDark,
                                  ),
                                );
                              }

                              final commentIndex = index - 1;
                              if (_comments == null ||
                                  commentIndex >= _comments!.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final comment = _comments![commentIndex];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildCommentCard(
                                  context,
                                  comment,
                                  isDarkBg: isDark,
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeaderContent(BuildContext context) {
    // Determine background image
    final imgUrl = _getImageUrl();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred Background
        if (imgUrl != null)
          CachedNetworkImage(
            imageUrl: imgUrl,
            fit: BoxFit.cover,
            height: 500, // extend a bit
            errorWidget: Container(color: Colors.grey[900]),
          )
        else
          Container(color: Colors.grey[900]),

        // Blur Effect + Dark Gradient (RepaintBoundary isolates expensive blur)
        RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                    bgColor,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 2. Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Cover + Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    Hero(
                      tag:
                          widget.heroTag ??
                          '${widget.anime.bangumiId ?? widget.anime.mikanId ?? widget.anime.title.hashCode}',
                      child: Container(
                        width: 110,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: imgUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  width: 110,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.movie, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right Column Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayTitle(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              _data?['date'] != null
                                  ? _formatDateToMonth(_data!['date'])
                                  : "2026年 1月", // Fallback/Placeholder
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getEpisodeStatusText(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildHeaderRatingRow(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Collection Stats Row
                _buildCollectionStatsRow(),

                const SizedBox(height: 16),

                // Episodes Section moved to Body
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentCard(
    BuildContext context,
    BangumiComment comment, {
    required bool isDarkBg,
  }) {
    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkBg ? Colors.white10 : Colors.grey[300]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkBg ? Colors.white10 : Colors.grey[200],
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: comment.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: comment.avatar,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.person,
                        size: 20,
                        color: isDarkBg ? Colors.white30 : Colors.grey[400],
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 20,
                      color: isDarkBg ? Colors.white30 : Colors.grey[400],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment.rate != null)
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < (comment.rate! / 2).round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 12,
                            color: Colors.amber,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                HtmlWidget(
                  comment.contentHtml.isNotEmpty
                      ? comment.contentHtml
                      : comment.content,
                  textStyle: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                  customWidgetBuilder: (element) {
                    if (element.classes.contains('text_mask')) {
                      return BangumiMaskText(
                        html: element.innerHtml,
                        textStyle: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.8),
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
  }

  Widget _buildMobileDetailsTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      controller: defaultTargetPlatform == TargetPlatform.windows
          ? _mobileDetailsScrollController
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episodes Section (Moved from Header)
          _buildEpisodesSection(context, isDarkBg: isDark),
          const SizedBox(height: 24),

          // Story Summary
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _hasBothTranslationAndOriginal()
                    ? () {
                        setState(() {
                          _showOriginalSummary = !_showOriginalSummary;
                        });
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplaySummary() ?? "暂无简介",
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: isDark
                            ? Colors.white70
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    if (_hasBothTranslationAndOriginal()) ...[
                      const SizedBox(height: 8),
                      Text(
                        _showOriginalSummary ? "点击显示翻译" : "点击显示原文",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tags
          _buildMobileTags(isDarkBg: isDark),
          const SizedBox(height: 24),

          // Information Box (Infobox)
          _buildInfoBoxList(context, isDarkBg: isDark),
          const SizedBox(height: 24),

          // Characters
          _buildCharactersSection(context, isDarkBg: isDark),
          if (_relations != null && _relations!.isNotEmpty) ...[
            const SizedBox(height: 40),
            // Related Items (Associated entries)
            _buildRelationsSection(context, isDarkBg: isDark),
          ],
          if (_sites != null && _sites!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSitesSection(context, isDarkBg: isDark),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderRatingRow() {
    final rating = _data?['rating'];
    if (rating == null) return const SizedBox.shrink();

    final score = rating['score'] ?? 0.0;
    final total = rating['total'] ?? 0;
    final rank = rating['rank'] ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$score",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < (score / 2).round() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                );
              }),
            ),
            const SizedBox(height: 2),
            Text(
              (rank != null && rank > 0) ? "$total 人评 | #$rank" : "$total 人评",
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Placeholder actions
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isLocalFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            label: Text(_isLocalFavorite ? "已收藏" : "收藏"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final subjectId = widget.anime.bangumiId;
              if (subjectId != null) {
                final mainHost = await BangumiUrlRewriter.hostFor('main');
                final url =
                    BangumiUrlRewriter.rewrite("https://bgm.tv/subject/$subjectId")
                        .replaceFirst('bgm.tv', mainHost);
                await Clipboard.setData(ClipboardData(text: url));
                if (!mounted) return;
                setState(() {
                  _isCopied = true;
                });
                _copyTimer?.cancel();
                _copyTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _isCopied = false;
                    });
                  }
                });
              }
            },
            icon: Icon(_isCopied ? Icons.check_rounded : Icons.share),
            label: Text(_isCopied ? l10n.copied : l10n.share),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isCopied
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              foregroundColor: _isCopied ? Colors.greenAccent : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: _isCopied
                    ? const BorderSide(color: Colors.greenAccent, width: 1)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionStatsRow() {
    final collection = _data?['collection'];
    if (collection == null) {
      return const SizedBox.shrink();
    }

    final wish = collection['wish'] ?? 0;
    final doing = collection['doing'] ?? 0;
    final dropped = collection['dropped'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$wish 收藏 / $doing 在看 / $dropped 抛弃",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Simple Collection Button for Mobile Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleFavorite,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4081), Color(0xFFF50057)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLocalFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isLocalFavorite ? "已收藏" : "收藏",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTags({bool isDarkBg = false}) {
    final tags = _data?['tags'];
    if (tags == null || tags is! List) {
      return const SizedBox.shrink();
    }

    final borderColor = isDarkBg ? Colors.white24 : Colors.grey[300]!;
    final textColor = isDarkBg ? Colors.white70 : Colors.black87;
    final countColor = isDarkBg ? Colors.white38 : Colors.grey;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.take(15).map<Widget>((tag) {
        final name = tag['name'];
        final count = tag['count'];
        return GestureDetector(
          onTap: name != null
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TagBrowsePage(tagName: name as String),
                  ),
                )
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$name ",
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                  if (count != null)
                    TextSpan(
                      text: "$count",
                      style: TextStyle(fontSize: 10, color: countColor),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Wide Layout (PC) ---
  Widget _buildWideLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildBlurredBackground(context)),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel
                  SizedBox(
                    width: 350,
                    child: SingleChildScrollView(
                      controller: _wideLeftScrollController,
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        kToolbarHeight + 24,
                        24,
                        24,
                      ),
                      child: Column(
                        children: [
                          _buildPoster(context, radius: 16),
                          const SizedBox(height: 24),
                          _buildRatingCard(context),
                          const SizedBox(height: 24),
                          _buildActionButtons(context),
                          const SizedBox(height: 24),
                          _buildInfoBoxList(context, isDarkBg: true),
                        ],
                      ),
                    ),
                  ),
                  // Right Panel
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _wideRightScrollController,
                      padding: const EdgeInsets.fromLTRB(
                        32,
                        kToolbarHeight + 24,
                        32,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleSection(context, isDarkBg: true),
                          const SizedBox(height: 32),

                          // MOVED EPISODES HERE
                          _buildEpisodesSection(context, isDarkBg: true),
                          const SizedBox(height: 32),

                          _buildSummarySection(context, isDarkBg: true),
                          const SizedBox(height: 32),
                          _buildTagsSection(context, isDarkBg: true),
                          const SizedBox(height: 32),

                          _buildCharactersSection(context, isDarkBg: true),
                          if (_relations != null && _relations!.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            // RELATED ITEMS
                            _buildRelationsSection(context, isDarkBg: true),
                          ],
                          if (_sites != null && _sites!.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSitesSection(context, isDarkBg: true),
                          ] else if (_relations == null || _relations!.isEmpty) ...[
                            const SizedBox(height: 32),
                          ],

                          _buildCommentsSection(context, isDarkBg: true),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Components (Shared/PC) ---

  Widget _buildBlurredBackground(BuildContext context) {
    final imgUrl = _getImageUrl();
    if (imgUrl == null) {
      return Container(color: Colors.black87);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          errorWidget: Container(color: Colors.black87),
        ),
        RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildPoster(BuildContext context, {double radius = 12}) {
    final imgUrl = _getImageUrl();
    if (imgUrl == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Center(
          child: Icon(Icons.movie, size: 64, color: Colors.white54),
        ),
      );
    }
    return Hero(
      tag:
          widget.heroTag ??
          '${widget.anime.bangumiId ?? widget.anime.mikanId ?? widget.anime.title.hashCode}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: imgUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 400,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(
    BuildContext context, {
    bool centered = false,
    bool isDarkBg = false,
  }) {
    final title = _getDisplayTitle();
    final cnName = _data?['name_cn'] ?? widget.anime.subTitle;
    final textColor = isDarkBg
        ? Colors.white
        : Theme.of(context).textTheme.titleLarge?.color;
    final subColor = isDarkBg
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        if (cnName != null && cnName.isNotEmpty && cnName != title) ...[
          const SizedBox(height: 8),
          Text(
            cnName,
            style: TextStyle(
              fontSize: 18,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );
  }

  int _characterRolePriority(BangumiCharacter character) {
    final roleName = character.roleName;
    if (roleName.contains('主角')) return 0;
    if (roleName.contains('配角')) return 1;
    return 2;
  }

  String? _characterRoleLabel(BangumiCharacter character) {
    final roleName = character.roleName;
    if (roleName.contains('主角')) return '主角';
    if (roleName.contains('配角')) return '配角';
    if (roleName.isNotEmpty) return '闲角';
    return null;
  }

  Widget _buildCharacterRoleBadge(String label, {required bool isDarkBg}) {
    final isMain = label == '主角';
    final isSupporting = label == '配角';
    final badgeColor = isMain
        ? Colors.amber
        : isSupporting
        ? Colors.blue
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRatingCard(BuildContext context) {
    if (_data == null || _data!['rating'] == null) {
      return const SizedBox.shrink();
    }
    final rating = _data!['rating'];
    final score = rating['score'];
    final rank = rating['rank'];
    final count = rating['total'];

    final collection = _data?['collection'];
    final wish = collection?['wish'] ?? 0;
    final doing = collection?['doing'] ?? 0;
    final dropped = collection?['dropped'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text(
                "$score",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$count votes",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (rank != null && rank > 0) ...[
            const Divider(color: Colors.white24, height: 24),
            Text(
              "Ranked #$rank",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
          if (collection != null) ...[
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStatItem("收藏", wish),
                _buildCompactStatItem("在看", doing),
                _buildCompactStatItem("抛弃", dropped),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context, {bool isDarkBg = false}) {
    final summary = _getDisplaySummary() ?? "No summary available.";
    final textColor = isDarkBg
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color;
    final hintColor = isDarkBg ? Colors.white38 : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).bangumiDetailsStory,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _hasBothTranslationAndOriginal()
              ? () {
                  setState(() {
                    _showOriginalSummary = !_showOriginalSummary;
                  });
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: TextStyle(fontSize: 15, height: 1.6, color: textColor),
                textAlign: TextAlign.justify,
              ),
              if (_hasBothTranslationAndOriginal()) ...[
                const SizedBox(height: 8),
                Text(
                  _showOriginalSummary ? "点击显示翻译" : "点击显示原文",
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context, {bool isDarkBg = false}) {
    final tags = _data?['tags'];
    if (tags == null || tags is! List || tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).bangumiDetailsTags,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map<Widget>((tag) {
            final name = (tag['name'] ?? '') as String;
            return GestureDetector(
              onTap: name.isNotEmpty
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TagBrowsePage(tagName: name),
                      ),
                    )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDarkBg ? Colors.white10 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: isDarkBg ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _openPersonPage(int personId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PersonDetailPage(personId: personId, enableHeroAnimation: false),
      ),
    );
  }

  void _openCharacterPage(
    int characterId, {
    String? characterName,
    String? heroImageUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(
          characterId: characterId,
          characterName: characterName,
          heroImageUrl: heroImageUrl,
        ),
      ),
    );
  }

  void _mergePersonIdMap(Map<String, int> entries) {
    for (final entry in entries.entries) {
      final id = entry.value;
      final rawName = entry.key.trim();
      if (id == 0 || rawName.isEmpty) continue;

      _personIdMap.putIfAbsent(rawName, () => id);

      final collapsedWhitespace = rawName.replaceAll(
        RegExp(r'\s+', unicode: true),
        ' ',
      );
      if (collapsedWhitespace != rawName) {
        _personIdMap.putIfAbsent(collapsedWhitespace, () => id);
      }
    }
  }

  List<InlineSpan> _buildPersonInlineSpans(
    String text, {
    required TextStyle textStyle,
    required TextStyle linkStyle,
  }) {
    if (text.isEmpty || _personIdMap.isEmpty) {
      return [TextSpan(text: text, style: textStyle)];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    while (cursor < text.length) {
      final match = _findNextPersonMatch(text, cursor);
      if (match == null) {
        spans.add(TextSpan(text: text.substring(cursor), style: textStyle));
        break;
      }

      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: textStyle),
        );
      }

      spans.add(
        TextSpan(
          text: match.name,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openPersonPage(match.personId),
        ),
      );
      cursor = match.end;
    }

    return spans;
  }

  _PersonTextMatch? _findNextPersonMatch(String text, int startIndex) {
    _PersonTextMatch? bestMatch;
    final seenNames = <String>{};

    for (final entry in _personIdMap.entries) {
      final name = entry.key.trim();
      if (name.length < 2 || !seenNames.add(name)) continue;

      final matchIndex = text.indexOf(name, startIndex);
      if (matchIndex == -1) continue;

      final candidate = _PersonTextMatch(
        start: matchIndex,
        end: matchIndex + name.length,
        name: name,
        personId: entry.value,
      );

      if (bestMatch == null ||
          candidate.start < bestMatch.start ||
          (candidate.start == bestMatch.start &&
              candidate.name.length > bestMatch.name.length)) {
        bestMatch = candidate;
      }
    }

    return bestMatch;
  }

  Widget _buildPersonAwareText(
    String text, {
    required TextStyle textStyle,
    required TextStyle linkStyle,
  }) {
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: _buildPersonInlineSpans(
          text,
          textStyle: textStyle,
          linkStyle: linkStyle,
        ),
      ),
    );
  }

  Widget _buildInfoBoxList(BuildContext context, {bool isDarkBg = false}) {
    if (_data == null || _data!['infobox'] == null) {
      return const SizedBox.shrink();
    }
    final infobox = (_data!['infobox'] as List)
        .where((item) => !_isInfoboxItemEmpty(item))
        .toList();
    if (infobox.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final keyColor = isDarkBg ? Colors.white54 : Colors.grey;
    final bgColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.1);
    final canCollapse = _shouldEnableInfoBoxCollapse(infobox);
    final visibleItems = _isInfoBoxExpanded || !canCollapse
        ? infobox
        : infobox.take(6).toList();
    final hiddenCount = infobox.length - visibleItems.length;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Information",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (canCollapse)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isInfoBoxExpanded = !_isInfoBoxExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Text(_isInfoBoxExpanded ? "收起" : "展开"),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in visibleItems)
                    _buildInfoBoxItem(
                      item,
                      isExpanded: _isInfoBoxExpanded || !canCollapse,
                      textColor: textColor,
                      keyColor: keyColor,
                      isDarkBg: isDarkBg,
                    ),
                  if (!_isInfoBoxExpanded && canCollapse && hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "还有 $hiddenCount 项，点击展开查看完整信息",
                        style: TextStyle(color: keyColor, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldEnableInfoBoxCollapse(List infobox) {
    if (infobox.length > 6) {
      return true;
    }

    for (final item in infobox) {
      final value = item is Map ? item['value'] : null;
      if (value is List && value.length > 4) {
        return true;
      }
      if (_summarizeInfoboxValue(value).length > 80) {
        return true;
      }
    }

    return false;
  }

  bool _isInfoboxItemEmpty(dynamic item) {
    if (item is! Map) {
      return true;
    }

    final key = (item['key'] ?? '').toString().trim();
    final value = _summarizeInfoboxValue(item['value']).trim();
    return key.isEmpty || value.isEmpty;
  }

  Widget _buildInfoBoxItem(
    dynamic item, {
    required bool isExpanded,
    required Color textColor,
    required Color keyColor,
    required bool isDarkBg,
  }) {
    final key = (item['key'] ?? '').toString();
    final value = item['value'];
    final valueStyle = TextStyle(color: textColor, fontSize: 12);
    final linkColor = isDarkBg ? Colors.cyanAccent : Colors.blue.shade800;
    final linkStyle = TextStyle(
      color: linkColor,
      fontSize: 12,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              key,
              style: TextStyle(
                color: keyColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isExpanded
                ? _buildExpandedInfoBoxValue(
                    value,
                    valueStyle: valueStyle,
                    linkStyle: linkStyle,
                  )
                : Text(
                    _summarizeInfoboxValue(value),
                    style: valueStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedInfoBoxValue(
    dynamic value, {
    required TextStyle valueStyle,
    required TextStyle linkStyle,
  }) {
    if (value is List) {
      final names = value
          .map((v) => (v['v'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      if (names.isEmpty) {
        return const SizedBox.shrink();
      }

      return Wrap(
        spacing: 0,
        runSpacing: 4,
        children: [
          for (int i = 0; i < names.length; i++) ...[
            _buildPersonAwareText(
              names[i],
              textStyle: valueStyle,
              linkStyle: linkStyle,
            ),
            if (i < names.length - 1) Text(', ', style: valueStyle),
          ],
        ],
      );
    }

    return _buildPersonAwareText(
      value?.toString() ?? '',
      textStyle: valueStyle,
      linkStyle: linkStyle,
    );
  }

  String _summarizeInfoboxValue(dynamic value) {
    if (value is List) {
      return value
          .map((v) => (v['v'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return value?.toString() ?? '';
  }

  Widget _buildPlaceholderSection(
    BuildContext context,
    String title,
    IconData icon, {
    bool isDarkBg = false,
  }) {
    final boxColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final iconColor = isDarkBg ? Colors.white24 : Colors.grey[400];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title, isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(12),
            border: isDarkBg ? Border.all(color: Colors.white10) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 8),
              Text(
                "Loading $title...",
                style: TextStyle(color: iconColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                "(Coming Soon)",
                style: TextStyle(color: iconColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    bool isDarkBg = false,
  }) {
    // For mobile details tab (which is light), we need specific handling if isDarkBg is false but we want similar style.
    // The previous implementation used primary color for the bar.

    return Row(
      children: [
        // Indicator bar
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: isDarkBg ? Colors.amber : Colors.deepPurple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkBg ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  String? _getImageUrl() {
    if (_data != null && _data!['images'] != null) {
      final images = _data!['images'];
      return images['large'] ??
          images['common'] ??
          images['medium'] ??
          widget.anime.coverUrl;
    }
    return widget.anime.coverUrl;
  }

  String _getDisplayTitle() {
    return _data?['name'] ?? widget.anime.title;
  }

  String _formatDateToMonth(String dateStr) {
    // try parse YYYY-MM-DD
    try {
      final date = DateTime.parse(dateStr);
      return "${date.year}年 ${date.month}月";
    } catch (_) {
      return dateStr;
    }
  }

  // New builder methods for Bangumi data
  Widget _buildEpisodesSection(BuildContext context, {bool isDarkBg = false}) {
    if (_isLoadingEpisodes) {
      return _buildPlaceholderSection(
        context,
        AppLocalizations.of(context).bangumiDetailsEpisodes,
        Icons.video_library,
        isDarkBg: isDarkBg,
      );
    }

    if (_episodes == null || _episodes!.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).bangumiDetailsEpisodes,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 138, // Reduced to bring scrollbar closer
          child: Scrollbar(
            controller: _episodesScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _episodesScrollController,
              padding: const EdgeInsets.only(
                bottom: 10,
              ), // Reduced space for scrollbar
              scrollDirection: Axis.horizontal,
              itemCount: _episodes!.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final ep = _episodes![index];
                final released = ep.isReleased();
                final epCardColor = released
                    ? cardColor
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey.shade50);
                final epBorderColor = released
                    ? (isDarkBg ? Colors.white10 : Colors.grey[300]!)
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200);
                final epTextColor = released
                    ? textColor
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.42));
                final epIndexColor = released
                    ? (isDarkBg ? Colors.amber : Colors.deepPurple)
                    : (isDarkBg
                          ? Colors.amber.withValues(alpha: 0.45)
                          : Colors.blueGrey.withValues(alpha: 0.7));
                final epDateColor = released
                    ? epTextColor.withValues(alpha: 0.5)
                    : epTextColor.withValues(alpha: 0.72);
                return Material(
                  color: epCardColor,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: released
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PlayerPage(
                                  anime: _buildAnimeForPlayer(),
                                  currentEpisode: ep,
                                  allEpisodes: _episodes!,
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
                        border: Border.all(
                          color: epBorderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: epIndexColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Japanese name
                          if (ep.name.isNotEmpty)
                            Text(
                              ep.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: epTextColor.withValues(alpha: 0.7),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          // Chinese name
                          if (ep.nameCn.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ep.nameCn,
                              style: TextStyle(
                                fontSize: 11,
                                color: epTextColor,
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
                                fontSize: 9,
                                color: epDateColor,
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
      ],
    );
  }

  Widget _buildCharactersSection(
    BuildContext context, {
    bool isDarkBg = false,
  }) {
    if (_isLoadingCharacters) {
      return _buildPlaceholderSection(
        context,
        "Characters",
        Icons.person,
        isDarkBg: isDarkBg,
      );
    }

    if (_characters == null || _characters!.isEmpty) {
      return const SizedBox.shrink();
    }

    final characters = _sortedCharacters ?? _characters!;

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "角色", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Scrollbar(
            controller: _charactersScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _charactersScrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = 0;
                      index < characters.take(10).length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 16),
                      Builder(
                        builder: (context) {
                          final char = characters[index];
                          final imageUrl =
                              char.images?.large ?? char.images?.medium ?? '';
                          final cvName = char.actors.isNotEmpty
                              ? char.actors.first.name
                              : '';
                          final canOpenCharacterPage = char.id != 0;
                          final roleLabel = _characterRoleLabel(char);

                          return SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Character Image
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: canOpenCharacterPage
                                        ? () => _openCharacterPage(
                                            char.id.toInt(),
                                            characterName: char.name,
                                            heroImageUrl: imageUrl,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 120,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDarkBg
                                              ? Colors.white10
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            imageUrl.isNotEmpty
                                                ? widget.enableCharacterHero
                                                      ? Hero(
                                                          tag:
                                                              'character_${char.id.toInt()}',
                                                          child: CachedNetworkImage(
                                                            imageUrl: imageUrl,
                                                            fit: BoxFit.cover,
                                                            alignment: Alignment
                                                                .topCenter,
                                                            deferOffscreenLoad:
                                                                false,
                                                          ),
                                                        )
                                                      : CachedNetworkImage(
                                                          imageUrl: imageUrl,
                                                          fit: BoxFit.cover,
                                                          alignment: Alignment
                                                              .topCenter,
                                                          deferOffscreenLoad:
                                                              false,
                                                        )
                                                : Center(
                                                    child: Icon(
                                                      Icons.person,
                                                      color: isDarkBg
                                                          ? Colors.white24
                                                          : Colors.grey[400],
                                                      size: 40,
                                                    ),
                                                  ),
                                            if (roleLabel != null)
                                              Positioned(
                                                left: 6,
                                                top: 6,
                                                child: _buildCharacterRoleBadge(
                                                  roleLabel,
                                                  isDarkBg: isDarkBg,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Character Name
                                canOpenCharacterPage
                                    ? GestureDetector(
                                        onTap: () => _openCharacterPage(
                                          char.id.toInt(),
                                          characterName: char.name,
                                          heroImageUrl: imageUrl,
                                        ),
                                        child: Text(
                                          char.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkBg
                                                ? Colors.cyanAccent
                                                : Colors.blue.shade800,
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: isDarkBg
                                                ? Colors.cyanAccent
                                                : Colors.blue.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : Text(
                                        char.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                // CV Name
                                if (cvName.isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        'CV: ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _personIdMap.containsKey(cvName)
                                            ? GestureDetector(
                                                onTap: () => _openPersonPage(
                                                  _personIdMap[cvName]!,
                                                ),
                                                child: Text(
                                                  cvName,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDarkBg
                                                        ? Colors.cyanAccent
                                                        : Colors.blue.shade800,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    decorationColor: isDarkBg
                                                        ? Colors.cyanAccent
                                                        : Colors.blue.shade800,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )
                                            : Text(
                                                cvName,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: textColor.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationsSection(BuildContext context, {bool isDarkBg = false}) {
    if (_isLoadingRelations) {
      return _buildPlaceholderSection(
        context,
        AppLocalizations.of(context).bangumiDetailsRelatedItems,
        Icons.link,
        isDarkBg: isDarkBg,
      );
    }

    if (_relations == null || _relations!.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDarkBg ? Colors.white10 : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).bangumiDetailsRelatedItems,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Scrollbar(
            controller: _relationsScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _relationsScrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = 0;
                      index < _relations!.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 16),
                      Builder(
                        builder: (context) {
                          final rel = _relations![index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BangumiDetailsPage(
                                    anime: AnimeInfo(
                                      title: rel.nameCn.isNotEmpty
                                          ? rel.nameCn
                                          : rel.name,
                                      bangumiId: rel.id.toString(),
                                      coverUrl: rel.image,
                                      tags: const [],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: rel.image.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: rel.image,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.center,
                                              deferOffscreenLoad: false,
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.movie_outlined,
                                              color: isDarkBg
                                                  ? Colors.white24
                                                  : Colors.grey[400],
                                              size: 32,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    rel.relation,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkBg
                                          ? Colors.amber
                                          : Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rel.nameCn.isNotEmpty
                                        ? rel.nameCn
                                        : rel.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textColor.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSitesSection(BuildContext context, {bool isDarkBg = false}) {
    if (_sites == null || _sites!.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDarkBg ? Colors.white10 : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          AppLocalizations.of(context).bangumiDetailsRelatedSites,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Scrollbar(
            controller: _sitesScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _sitesScrollController,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < _sites!.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      _buildSiteCard(
                        context,
                        _sites![index],
                        textColor: textColor,
                        cardColor: cardColor!,
                        borderColor: borderColor,
                        isDarkBg: isDarkBg,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSiteCard(
    BuildContext context,
    BangumiDataSiteEntry site, {
    required Color textColor,
    required Color cardColor,
    required Color borderColor,
    required bool isDarkBg,
  }) {
    final fallbackColor =
        isDarkBg ? Colors.white24 : Colors.grey[400]!;
    return GestureDetector(
      onTap: () => _launchSiteUrl(site.url),
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: _buildSiteIcon(site.site, fallbackColor),
            ),
            const SizedBox(height: 8),
            Text(
              site.title,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.9),
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
    );
  }

  Widget _buildSiteIcon(String siteKey, Color fallbackColor) {
    final assetPath = _siteIconAssetPath(siteKey);
    if (assetPath == null) {
      return Icon(Icons.public, color: fallbackColor, size: 28);
    }
    return Image.asset(
      assetPath,
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.public, color: fallbackColor, size: 28),
    );
  }

  /// Maps a bangumi-data `site` key to an asset path under
  /// `assets/images/sites/`. Returns null when no bundled icon exists,
  /// letting the caller fall back to a generic placeholder icon.
  String? _siteIconAssetPath(String siteKey) {
    final entry = _kSiteIconMap[siteKey];
    if (entry == null) return null;
    return 'assets/images/sites/$entry';
  }

  Future<void> _launchSiteUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme ||
          (!uri.scheme.startsWith('http'))) {
        debugPrint('Refusing to launch non-HTTP URL: $url');
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('launchUrl returned false for $url');
      }
    } catch (e) {
      debugPrint('Failed to launch $url: $e');
    }
  }

  Widget _buildCommentsSection(BuildContext context, {bool isDarkBg = false}) {
    if (!_hasRequestedComments && !_isLoadingComments) {
      unawaited(_ensureCommentsLoaded());
    }

    if (_isLoadingComments) {
      return _buildPlaceholderSection(
        context,
        "Comments",
        Icons.comment,
        isDarkBg: isDarkBg,
      );
    }

    if (_comments == null || _comments!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "评论", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        ..._comments!.map(
          (comment) => _buildCommentCard(context, comment, isDarkBg: isDarkBg),
        ),
        if (_isLoadingMoreComments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  String _getEpisodeStatusText() {
    // Placeholder logic matching screenshot: "连载至 30 · 预定全 10 话"
    // We should use real data if possible
    final total = _getTotalEpisodeCount();
    if (total != null && total > 0) {
      return "全 $total 话";
    }
    return "0话";
  }

  int? _getTotalEpisodeCount() {
    final totalFromData = _readIntValue(_data?['total_episodes']);
    if (totalFromData != null && totalFromData > 0) {
      return totalFromData;
    }

    final epsFromData = _readIntValue(_data?['eps']);
    if (epsFromData != null && epsFromData > 0) {
      return epsFromData;
    }

    final episodeCount = _episodes?.length ?? 0;
    if (episodeCount > 0) {
      return episodeCount;
    }

    final parsedEpisodes = _data?['episodes'];
    if (parsedEpisodes is List) {
      final count = parsedEpisodes.whereType<Map>().length;
      if (count > 0) {
        return count;
      }
    }

    return null;
  }

  int? _readIntValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _PersonTextMatch {
  final int start;
  final int end;
  final String name;
  final int personId;

  const _PersonTextMatch({
    required this.start,
    required this.end,
    required this.name,
    required this.personId,
  });
}
