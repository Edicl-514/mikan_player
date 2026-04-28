import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_mask_text.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'player_page.dart';
import 'tag_browse_page.dart';
import 'character_detail_page.dart';
import 'person_detail_page.dart';

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
  Map<String, dynamic>? _data;
  late ScrollController _scrollController;

  // Bangumi API data
  List<BangumiEpisode>? _episodes;
  List<BangumiCharacter>? _characters;
  List<BangumiRelatedSubject>? _relations;
  List<BangumiComment>? _comments;

  // Person name → id mapping (built from persons API + character actors)
  final Map<String, int> _personIdMap = {};

  bool _isLoadingEpisodes = false;
  bool _isLoadingCharacters = false;
  bool _isLoadingRelations = false;
  bool _isLoadingComments = false;
  bool _isLocalFavorite = false;
  bool _isCopied = false;
  Timer? _copyTimer;
  bool _showOriginalSummary = false;

  // Pagination State
  int _commentPage = 1;
  bool _hasMoreComments = true;
  bool _isLoadingMoreComments = false;
  final ScrollController _commentScrollController = ScrollController();
  late ScrollController _episodesScrollController;
  late ScrollController _charactersScrollController;
  late ScrollController _relationsScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _episodesScrollController = ScrollController();
    _charactersScrollController = ScrollController();
    _relationsScrollController = ScrollController();
    _parseData();
    _checkFavoriteStatus();
    _fetchBangumiData();

    _commentScrollController.addListener(_handleCommentScroll);
  }

  void _handleCommentScroll() {
    if (!_commentScrollController.hasClients) return;
    if (_commentScrollController.position.pixels >=
        _commentScrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments || !_hasMoreComments) return;

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

      final newComments = await fetchBangumiComments(
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

    final subjectId = int.parse(subjectIdStr);
    final cache = CacheManager.instance;

    if (_data == null) {
      try {
        final cachedAnime = await cache.getSubject(subjectId);
        if (cachedAnime != null && cachedAnime.fullJson != null) {
          debugPrint('Subject loaded from cache: $subjectId');
          _data = jsonDecode(cachedAnime.fullJson!);
        } else {
          final details = await fillAnimeDetails(animes: [widget.anime]);
          if (details.isNotEmpty) {
            final detail = details.first;
            if (detail.fullJson != null) {
              _data = jsonDecode(detail.fullJson!);
              unawaited(cache.cacheAnimeInfo(detail));
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading anime details: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoadingEpisodes = true;
      _isLoadingCharacters = true;
      _isLoadingRelations = true;
      _isLoadingComments = true;
      _commentPage = 1;
      _hasMoreComments = true;
      _isLoadingMoreComments = false;
      _episodes = null;
      _characters = null;
      _relations = null;
      _comments = null;
      _personIdMap.clear();
    });

    List<BangumiEpisode> episodes = [];
    List<BangumiCharacter> characters = [];
    List<BangumiRelatedSubject> relations = [];
    List<BangumiComment> comments = [];
    final personMap = <String, int>{};

    Future<void> loadEpisodes() async {
      try {
        final allEpisodes = await fetchBangumiEpisodes(subjectId: subjectId);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        episodes = allEpisodes.where((ep) {
          if (ep.airdate.isEmpty) return true;
          try {
            final date = DateTime.parse(ep.airdate);
            final epDate = DateTime(date.year, date.month, date.day);
            return !epDate.isAfter(today);
          } catch (e) {
            return true;
          }
        }).toList();
      } catch (e) {
        debugPrint('Error fetching episodes: $e');
        episodes = [];
      }
    }

    Future<void> loadCharacters() async {
      try {
        characters = await cache.getCharacters(
          subjectId: subjectId,
          fetchFromNetwork: () => fetchBangumiCharacters(subjectId: subjectId),
        );
        for (final ch in characters) {
          for (final actor in ch.actors) {
            if (actor.name.isNotEmpty && actor.id != 0) {
              personMap.putIfAbsent(actor.name, () => actor.id);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching characters: $e');
        characters = [];
      }
    }

    Future<void> loadRelations() async {
      try {
        relations = await cache.getRelations(
          subjectId: subjectId,
          fetchFromNetwork: () => fetchBangumiRelations(subjectId: subjectId),
        );
      } catch (e) {
        debugPrint('Error fetching relations: $e');
        relations = [];
      }
    }

    Future<void> loadPersons() async {
      try {
        final persons = await fetchBangumiPersons(subjectId: subjectId);
        for (final p in persons) {
          if (p.name.isNotEmpty && p.id != 0) {
            personMap.putIfAbsent(p.name, () => p.id);
          }
        }
      } catch (e) {
        debugPrint('Error fetching persons: $e');
      }
    }

    Future<void> loadComments() async {
      try {
        comments = await fetchBangumiComments(subjectId: subjectId, page: 1);
      } catch (e) {
        debugPrint('Error fetching comments: $e');
        comments = [];
      }
    }

    await Future.wait([
      loadEpisodes(),
      loadCharacters(),
      loadRelations(),
      loadPersons(),
      loadComments(),
    ]);

    if (!mounted) return;

    setState(() {
      _episodes = episodes;
      _characters = characters;
      _relations = relations;
      _comments = comments;
      _mergePersonIdMap(personMap);
      _isLoadingEpisodes = false;
      _isLoadingCharacters = false;
      _isLoadingRelations = false;
      _isLoadingComments = false;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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
    _scrollController.dispose();
    _episodesScrollController.dispose();
    _charactersScrollController.dispose();
    _relationsScrollController.dispose();
    _commentScrollController.removeListener(_handleCommentScroll);
    _commentScrollController.dispose();
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
    const bgColor = Color(0xFF16161E);
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
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurpleAccent,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
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
              if (_comments == null || _comments!.isEmpty)
                ListView(
                  controller: _commentScrollController,
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSectionTitle(context, "评论", isDarkBg: true),
                    ),
                    const SizedBox(height: 96),
                    Center(
                      child: Text(
                        '暂无评论',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                )
              else
                ListView.builder(
                  controller: _commentScrollController,
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      (_comments == null ? 0 : _comments!.length) + 1 +
                      (_isLoadingMoreComments ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSectionTitle(
                          context,
                          "评论",
                          isDarkBg: true,
                        ),
                      );
                    }

                    final commentIndex = index - 1;
                    if (_comments == null || commentIndex >= _comments!.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                        isDarkBg: true,
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
    const bgColor = Color(0xFF16161E);

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

        // Blur Effect + Dark Gradient
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episodes Section (Moved from Header)
          // Using Dark Bg style as the page background is dark
          _buildEpisodesSection(context, isDarkBg: true),
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
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    if (_hasBothTranslationAndOriginal()) ...[
                      const SizedBox(height: 8),
                      Text(
                        _showOriginalSummary ? "点击显示翻译" : "点击显示原文",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
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
          _buildMobileTags(isDarkBg: true),
          const SizedBox(height: 24),

          // Information Box (Infobox)
          _buildInfoBoxList(context),
          const SizedBox(height: 24),

          // Characters
          _buildCharactersSection(context, isDarkBg: true),
          const SizedBox(height: 40),

          // Related Items (Associated entries)
          _buildRelationsSection(context, isDarkBg: true),
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
            onPressed: () {
              final subjectId = widget.anime.bangumiId;
              if (subjectId != null) {
                final url = "https://bgm.tv/subject/$subjectId";
                Clipboard.setData(ClipboardData(text: url)).then((_) {
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
                          _buildInfoBoxList(context),
                        ],
                      ),
                    ),
                  ),
                  // Right Panel
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _commentScrollController,
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
                          const SizedBox(height: 32),

                          // RELATED ITEMS
                          _buildRelationsSection(context, isDarkBg: true),
                          const SizedBox(height: 32),

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

  Widget _buildRelatedItemsSection(
    BuildContext context, {
    bool isDarkBg = false,
  }) {
    // Placeholder Data
    final items = [
      {"title": "葬送的芙莉莲 第一季", "type": "前传", "cover": null},
      {"title": "葬送的芙莉莲 外传", "type": "外传", "cover": null},
    ];

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final borderColor = isDarkBg ? Colors.white10 : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "Related Items", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length + 1, // +1 for a "More" placeholder
            separatorBuilder: (c, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index == items.length) {
                // Placeholder for future fetch
                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: isDarkBg ? Colors.white24 : Colors.grey,
                      size: 28,
                    ),
                  ),
                );
              }

              final item = items[index];
              return SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.movie_outlined,
                            color: isDarkBg ? Colors.white24 : Colors.grey[400],
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['type'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkBg ? Colors.amber : Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['title'] as String,
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
              );
            },
          ),
        ),
      ],
    );
  }

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
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
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

  Widget _buildCharacterRoleBadge(
    String label, {
    required bool isDarkBg,
  }) {
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
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.9),
        ),
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
        _buildSectionTitle(context, "Story", isDarkBg: isDarkBg),
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
        _buildSectionTitle(context, "Tags", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map<Widget>((tag) {
            final name = (tag['name'] ?? '') as String;
            return ActionChip(
              label: Text(name),
              backgroundColor: isDarkBg ? Colors.white10 : Colors.grey[200],
              labelStyle: TextStyle(
                color: isDarkBg ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: name.isNotEmpty
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TagBrowsePage(tagName: name),
                      ),
                    )
                  : null,
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
        builder: (context) => PersonDetailPage(
          personId: personId,
          enableHeroAnimation: false,
        ),
      ),
    );
  }

  void _openCharacterPage(int characterId, {String? characterName, String? heroImageUrl}) {
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

  Widget _buildInfoBoxList(BuildContext context) {
    if (_data == null || _data!['infobox'] == null) {
      return const SizedBox.shrink();
    }
    final infobox = _data!['infobox'] as List;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Information",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...infobox.map((item) {
            final val = item['value'];
            const valueStyle = TextStyle(color: Colors.white, fontSize: 12);
            const linkStyle = TextStyle(
              color: Colors.cyanAccent,
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: Colors.cyanAccent,
            );

            // When value is a list of persons, render each as a clickable span
            if (val is List) {
              final names = val
                  .map((v) => (v['v'] ?? '').toString())
                  .where((s) => s.isNotEmpty)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        item['key'],
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 0,
                        runSpacing: 4,
                        children: [
                          for (int i = 0; i < names.length; i++) ...[
                            _buildPersonAwareText(
                              names[i],
                              textStyle: valueStyle,
                              linkStyle: linkStyle,
                            ),
                            if (i < names.length - 1)
                              const Text(', ', style: valueStyle),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Plain string value
            final valueStr = val.toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      item['key'],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPersonAwareText(
                      valueStr,
                      textStyle: valueStyle,
                      linkStyle: linkStyle,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
        "Episodes",
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
        _buildSectionTitle(context, "Episodes", isDarkBg: isDarkBg),
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
                return Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlayerPage(
                            anime: widget.anime,
                            currentEpisode: ep,
                            allEpisodes: _episodes!,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // Color moved to Material
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkBg ? Colors.white10 : Colors.grey[300]!,
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
                              color: isDarkBg
                                  ? Colors.amber
                                  : Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Japanese name
                          if (ep.name.isNotEmpty)
                            Text(
                              ep.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.7),
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
                                color: textColor,
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
                                color: textColor.withValues(alpha: 0.5),
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

    final characters = [..._characters!]
      ..sort((a, b) {
        final priorityCompare =
            _characterRolePriority(a).compareTo(_characterRolePriority(b));
        if (priorityCompare != 0) return priorityCompare;
        return a.name.compareTo(b.name);
      });

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "角色", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        SizedBox(
          height:
              240, // Increased from 228 to avoid overflow when names are long
          child: Scrollbar(
            controller: _charactersScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _charactersScrollController,
              padding: const EdgeInsets.only(
                bottom: 10,
              ), // Reduced space for scrollbar
              scrollDirection: Axis.horizontal,
              itemCount: characters.take(10).length,
              separatorBuilder: (c, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
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
                                              tag: 'character_${char.id.toInt()}',
                                              child: CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                alignment: Alignment.topCenter,
                                                deferOffscreenLoad: false,
                                              ),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              deferOffscreenLoad: false,
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
                                      : Colors.blue,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: isDarkBg
                                      ? Colors.cyanAccent
                                      : Colors.blue,
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
                                color: textColor.withValues(alpha: 0.5),
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
                                              : Colors.blue,
                                          decoration: TextDecoration.underline,
                                          decorationColor: isDarkBg
                                              ? Colors.cyanAccent
                                              : Colors.blue,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : Text(
                                      cvName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textColor.withValues(alpha: 0.7),
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
          ),
        ),
      ],
    );
  }

  Widget _buildRelationsSection(BuildContext context, {bool isDarkBg = false}) {
    if (_isLoadingRelations) {
      return _buildRelatedItemsSection(context, isDarkBg: isDarkBg);
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
        _buildSectionTitle(context, "Related Items", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        SizedBox(
          height: 204, // Height adjusted for scrollbar
          child: Scrollbar(
            controller: _relationsScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _relationsScrollController,
              padding: const EdgeInsets.only(bottom: 10), // Space for scrollbar
              scrollDirection: Axis.horizontal,
              itemCount: _relations!.length,
              separatorBuilder: (c, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
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
                                  borderRadius: BorderRadius.circular(12),
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
                            color: isDarkBg ? Colors.amber : Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rel.nameCn.isNotEmpty ? rel.nameCn : rel.name,
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
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(BuildContext context, {bool isDarkBg = false}) {
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
    final eps = _data?['eps'] ?? widget.anime.fullJson?.length ?? 0; // fallback
    final total = _data?['total_episodes'] ?? 0;

    // If total is 0, maybe it's unknown.
    // Let's just say "Total X eps" if we know it.
    if (total > 0) {
      return "全 $total 话";
    }
    return "$eps 话";
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
