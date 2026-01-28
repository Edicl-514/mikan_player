import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'player_page.dart';

class BangumiDetailsPage extends StatefulWidget {
  final AnimeInfo anime;
  final String heroTagPrefix;

  const BangumiDetailsPage({
    super.key,
    required this.anime,
    this.heroTagPrefix = 'cover',
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

  bool _isLoadingEpisodes = false;
  bool _isLoadingCharacters = false;
  bool _isLoadingRelations = false;
  bool _isLoadingComments = false;

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
    _fetchBangumiData();

    _commentScrollController.addListener(() {
      if (_commentScrollController.position.pixels >=
          _commentScrollController.position.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    });
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
    if (subjectIdStr != null) {
      final subjectId = int.parse(subjectIdStr);

      // If we don't have detailed data (e.g. navigated from relations), fetch it
      if (_data == null) {
        fillAnimeDetails(animes: [widget.anime])
            .then((details) {
              if (mounted && details.isNotEmpty) {
                final detail = details.first;
                if (detail.fullJson != null) {
                  setState(() {
                    try {
                      _data = jsonDecode(detail.fullJson!);
                    } catch (e) {
                      debugPrint("Error parsing fetched fullJson: $e");
                    }
                  });
                }
              }
            })
            .catchError((e) {
              debugPrint("Error fetching anime details: $e");
            });
      }

      setState(() {
        _isLoadingEpisodes = true;
        _isLoadingCharacters = true;
        _isLoadingRelations = true;
        _isLoadingComments = true;
        // Reset pagination
        _commentPage = 1;
        _hasMoreComments = true;
      });

      // Fetch Episodes
      fetchBangumiEpisodes(subjectId: subjectId)
          .then((allEpisodes) {
            if (!mounted) return;
            setState(() {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              _episodes = allEpisodes.where((ep) {
                if (ep.airdate.isEmpty) return true;
                try {
                  // Bangumi airdate is typically YYYY-MM-DD
                  final date = DateTime.parse(ep.airdate);
                  final epDate = DateTime(date.year, date.month, date.day);
                  // Show if epDate <= today
                  return !epDate.isAfter(today);
                } catch (e) {
                  return true; // Keep if format is unknown
                }
              }).toList();
              _isLoadingEpisodes = false;
            });
          })
          .catchError((e) {
            debugPrint('Error fetching episodes: $e');
            if (mounted) {
              setState(() {
                _episodes = [];
                _isLoadingEpisodes = false;
              });
            }
          });

      // Fetch Characters
      fetchBangumiCharacters(subjectId: subjectId)
          .then((characters) {
            if (!mounted) return;
            setState(() {
              _characters = characters;
              _isLoadingCharacters = false;
            });
          })
          .catchError((e) {
            debugPrint('Error fetching characters: $e');
            if (mounted) {
              setState(() {
                _characters = [];
                _isLoadingCharacters = false;
              });
            }
          });

      // Fetch Relations
      fetchBangumiRelations(subjectId: subjectId)
          .then((relations) {
            if (!mounted) return;
            setState(() {
              _relations = relations;
              _isLoadingRelations = false;
            });
          })
          .catchError((e) {
            debugPrint('Error fetching relations: $e');
            if (mounted) {
              setState(() {
                _relations = [];
                _isLoadingRelations = false;
              });
            }
          });

      // Fetch Comments
      fetchBangumiComments(subjectId: subjectId, page: 1)
          .then((comments) {
            if (!mounted) return;
            setState(() {
              _comments = comments;
              _isLoadingComments = false;
            });
          })
          .catchError((e) {
            debugPrint('Error fetching comments: $e');
            if (mounted) {
              setState(() {
                _comments = [];
                _isLoadingComments = false;
              });
            }
          });
    } else {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
          _isLoadingCharacters = false;
          _isLoadingRelations = false;
          _isLoadingComments = false;
        });
      }
    }
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

  @override
  void dispose() {
    _scrollController.dispose();
    _episodesScrollController.dispose();
    _charactersScrollController.dispose();
    _relationsScrollController.dispose();
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
                    340, // Reduced height to remove empty space and fit content better
                pinned: true,
                elevation: 0,
                backgroundColor: bgColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildMobileHeaderContent(context),
                ),
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurpleAccent,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: "详情"), // Details
                    Tab(text: "评论"), // Comments (Merged Reviews & Discussion)
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildMobileDetailsTab(context),
              NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200) {
                    _loadMoreComments();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildCommentsSection(context, isDarkBg: true),
                ),
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
          Image.network(
            imgUrl,
            fit: BoxFit.cover,
            height: 500, // extend a bit
            errorBuilder: (_, _, _) => Container(color: Colors.grey[900]),
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
                          '${widget.heroTagPrefix}_${widget.anime.bangumiId ?? widget.anime.mikanId ?? widget.anime.title.hashCode}',
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
                          image: imgUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(imgUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imgUrl == null
                            ? const Icon(Icons.movie, color: Colors.grey)
                            : null,
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
          Text(
            _data?['summary'] ?? "暂无简介",
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white70,
            ),
            textAlign: TextAlign.justify,
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
    // Placeholder actions
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
            label: const Text("收藏"),
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
            onPressed: () {},
            icon: const Icon(Icons.share),
            label: const Text("Share"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

    return Row(
      children: [
        Text(
          "$wish 收藏 / $doing 在看 / $dropped 抛弃",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // Simple Collection Button for Mobile Header
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.favorite_border, size: 16),
          label: const Text("收藏"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            minimumSize: Size.zero, // Compact
          ),
        ),
      ],
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
        return Container(
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
        );
      }).toList(),
    );
  }

  // --- Wide Layout (PC) ---
  Widget _buildWideLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildBlurredBackground(context)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel
                  SizedBox(
                    width: 350,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 32,
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
        Image.network(
          imgUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: Colors.black87),
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
          '${widget.heroTagPrefix}_${widget.anime.bangumiId ?? widget.anime.mikanId ?? widget.anime.title.hashCode}',
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
          child: Image.network(imgUrl, fit: BoxFit.cover),
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

  Widget _buildRatingCard(BuildContext context) {
    if (_data == null || _data!['rating'] == null) {
      return const SizedBox.shrink();
    }
    final rating = _data!['rating'];
    final score = rating['score'];
    final rank = rating['rank'];
    final count = rating['total'];

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
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, {bool isDarkBg = false}) {
    final summary = _data?['summary'] ?? "No summary available.";
    final textColor = isDarkBg
        ? Colors.white70
        : Theme.of(context).textTheme.bodyMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "Story", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        Text(
          summary,
          style: TextStyle(fontSize: 15, height: 1.6, color: textColor),
          textAlign: TextAlign.justify,
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
            final name = tag['name'] ?? '';
            return Chip(
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
            );
          }).toList(),
        ),
      ],
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
            String valueStr = "";
            if (val is List) {
              valueStr = val.map((v) => v['v'] ?? '').join(', ');
            } else {
              valueStr = val.toString();
            }

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
                    child: Text(
                      valueStr,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
          height: 228, // Reduced to bring scrollbar closer
          child: Scrollbar(
            controller: _charactersScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _charactersScrollController,
              padding: const EdgeInsets.only(
                bottom: 10,
              ), // Reduced space for scrollbar
              scrollDirection: Axis.horizontal,
              itemCount: _characters!.take(10).length,
              separatorBuilder: (c, i) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final char = _characters![index];
                final imageUrl =
                    char.images?.large ?? char.images?.medium ?? '';
                final cvName = char.actors.isNotEmpty
                    ? char.actors.first.name
                    : '';

                return SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Character Image
                      Container(
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
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                )
                              : null,
                        ),
                        child: imageUrl.isEmpty
                            ? Icon(
                                Icons.person,
                                color: isDarkBg
                                    ? Colors.white24
                                    : Colors.grey[400],
                                size: 40,
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // Character Name
                      Text(
                        char.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Role Type (主角/配角)
                      if (char.roleName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: char.roleName.contains('主角')
                                ? (isDarkBg
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : Colors.amber[100])
                                : (isDarkBg
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.blue[100]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            char.roleName,
                            style: TextStyle(
                              fontSize: 9,
                              color: char.roleName.contains('主角')
                                  ? (isDarkBg
                                        ? Colors.amber[300]
                                        : Colors.amber[900])
                                  : (isDarkBg
                                        ? Colors.blue[300]
                                        : Colors.blue[900]),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
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
                              child: Text(
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
                            image: rel.image.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(rel.image),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  )
                                : null,
                          ),
                          child: rel.image.isEmpty
                              ? Center(
                                  child: Icon(
                                    Icons.movie_outlined,
                                    color: isDarkBg
                                        ? Colors.white24
                                        : Colors.grey[400],
                                    size: 32,
                                  ),
                                )
                              : null,
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

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "评论", isDarkBg: isDarkBg),
        const SizedBox(height: 12),
        ..._comments!.map((comment) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDarkBg ? Colors.white10 : Colors.grey[200],
                  backgroundImage: comment.avatar.isNotEmpty
                      ? NetworkImage(comment.avatar)
                      : null,
                  child: comment.avatar.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: isDarkBg ? Colors.white30 : Colors.grey[400],
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Content
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
                      Text(
                        comment.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
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
