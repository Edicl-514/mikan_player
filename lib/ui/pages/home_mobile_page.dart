import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust_bangumi;
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/favorites_page.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/widgets/blurred_cover_background.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/network_avatar.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

class HomeMobilePage extends StatefulWidget {
  const HomeMobilePage({super.key});

  @override
  State<HomeMobilePage> createState() => _HomeMobilePageState();
}

class _HomeMobilePageState extends State<HomeMobilePage> {
  final UserManager _userManager = UserManager();
  final FavoritesManager _favoritesManager = FavoritesManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();

  // Data
  List<crawler.AnimeInfo> _todayAnimes = [];
  List<RankingAnime> _rankingAnimes = [];
  List<PlaybackHistoryItem> _historyItems = [];
  List<dynamic> _favoriteItems =
      []; // Can be LocalFavorite or BangumiUserCollection

  bool _isLoadingToday = true;
  bool _isLoadingRanking = true;
  bool _isLoadingHistory = true;
  bool _isLoadingFavorites = true;

  late PageController _todayPageController;
  Timer? _todayTimer;
  final ScrollController _scrollController = createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _todayPageController = PageController(viewportFraction: 0.9);
    _userManager.addListener(_onUserUpdate);
    _loadAllData();
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    _todayPageController.dispose();
    _scrollController.dispose();
    _userManager.removeListener(_onUserUpdate);
    super.dispose();
  }

  void _startTodayTimer() {
    _todayTimer?.cancel();
    if (_todayAnimes.isEmpty) return;
    _todayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_todayAnimes.isEmpty || !mounted) return;
      if (_todayPageController.hasClients) {
        int nextPage = (_todayPageController.page?.round() ?? 0) + 1;
        if (nextPage >= _todayAnimes.length) {
          _todayPageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
          );
        } else {
          _todayPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
          );
        }
      }
    });
  }

  void _onUserUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllData() async {
    debugPrint('[HomeMobile] loadAllData start');
    _loadTodayAnimes();
    _loadRanking();
    _loadHistory();
    _loadFavorites();
  }

  Future<void> _loadTodayAnimes() async {
    try {
      debugPrint('[HomeMobile] loadTodayAnimes start');
      // 1. 直接计算当前季度，无需等待网络请求
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      final quarterNum = currentMonth <= 3
          ? 1
          : currentMonth <= 6
          ? 2
          : currentMonth <= 9
          ? 3
          : 4;
      final currentQuarter = '${currentYear}q$quarterNum';

      // 2. Get timetable（三级优先策略：SQLite缓存 → 本地JSON → 并发API+下载）
      final animes = await CacheManager.instance.getTimetable(
        quarter: currentQuarter,
      );
      debugPrint(
        '[HomeMobile] timetable loaded quarter=$currentQuarter '
        'count=${animes.length}',
      );

      // 3. Filter for today
      final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final todayStr = weekDays[now.weekday - 1];

      var todayList = animes.where((a) => a.broadcastDay == todayStr).toList();
      debugPrint(
        '[HomeMobile] today filter day=$todayStr count=${todayList.length}',
      );

      if (mounted) {
        setState(() {
          _todayAnimes = todayList;
          _isLoadingToday = false;
        });
        _startTodayTimer();
      }

      // 4. Fill details if covers are missing
      final missingCovers = todayList
          .where(
            (a) =>
                a.coverUrl == null ||
                a.coverUrl!.isEmpty ||
                a.fullJson == null ||
                a.fullJson!.isEmpty,
          )
          .toList();
      if (missingCovers.isNotEmpty) {
        try {
          debugPrint(
            '[HomeMobile] fillAnimeDetails start count=${missingCovers.length}',
          );
          final enriched = await crawler.fillAnimeDetails(
            animes: missingCovers,
          );
          debugPrint(
            '[HomeMobile] fillAnimeDetails done count=${enriched.length}',
          );
          // ✅ 保存到缓存，加速后续加载
          await CacheManager.instance.cacheAnimeInfos(enriched);

          // Update the list with enriched data
          for (final item in enriched) {
            final index = todayList.indexWhere(
              (a) => a.bangumiId == item.bangumiId,
            );
            if (index != -1) {
              todayList[index] = item;
            }
            // Also update the full timetable list
            final fullIndex = animes.indexWhere(
              (a) => a.bangumiId == item.bangumiId,
            );
            if (fullIndex != -1) {
              animes[fullIndex] = item;
            }
          }
          // Update timetable cache so next load has coverUrl
          await CacheManager.instance.updateTimetable(currentQuarter, animes);
          debugPrint('[HomeMobile] enriched timetable saved');
          if (mounted) {
            setState(() {
              _todayAnimes = List.from(todayList);
            });
          }
        } catch (e) {
          debugPrint('Failed to enrich today animes: $e');
        }
      }
      debugPrint('[HomeMobile] loadTodayAnimes done');
    } catch (e) {
      debugPrint('Error loading today animes: $e');
      if (mounted) setState(() => _isLoadingToday = false);
    }
  }

  Future<void> _loadRanking() async {
    try {
      debugPrint('[HomeMobile] loadRanking start');
      final results = await CacheManager.instance.getRanking(
        sortType: 'trends',
        page: 1,
        fetchFromNetwork: () =>
            fetchBangumiRanking(sortType: 'trends', page: 1),
      );
      if (mounted) {
        setState(() {
          _rankingAnimes = results.take(10).toList();
          _isLoadingRanking = false;
        });
      }
      debugPrint('[HomeMobile] loadRanking done count=${results.length}');
    } catch (e) {
      debugPrint('Error loading ranking: $e');
      if (mounted) setState(() => _isLoadingRanking = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      debugPrint('[HomeMobile] loadHistory start');
      final history = await _historyManager.getHistory();
      if (mounted) {
        setState(() {
          _historyItems = history.take(10).toList();
          _isLoadingHistory = false;
        });
      }
      debugPrint('[HomeMobile] loadHistory done count=${history.length}');
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      debugPrint('[HomeMobile] loadFavorites start');
      await _favoritesManager.init();
      final localFavs = await _favoritesManager.getAllFavorites();

      List<dynamic> merged = List.from(localFavs);

      if (_userManager.isLoggedIn) {
        try {
          final username = _userManager.user!.username;
          final raw = await rust_bangumi.fetchBangumiUserCollections(
            username: username,
            subjectType: 2,
            limit: 20,
            offset: 0,
          );
          final apiHost = await BangumiUrlRewriter.hostFor('api');
          String rewrite(String url) {
            if (url.isEmpty) return url;
            return BangumiUrlRewriter.rewrite(
              url,
            ).replaceFirst('api.bgm.tv', apiHost);
          }

          final collections = raw
              .map(
                (e) => BangumiUserCollection(
                  date: e.updatedAt,
                  comment: e.comment,
                  tags: e.tags,
                  subjectId: e.subjectId,
                  type: e.collectionType,
                  rate: e.rate,
                  private: e.private,
                  subject: BangumiUserCollectionSubject(
                    id: e.subjectId,
                    name: e.subjectName,
                    nameCn: e.subjectNameCn,
                    shortSummary: e.subjectShortSummary,
                    score: e.subjectScore,
                    eps: e.subjectEps,
                    collectionTotal: e.subjectCollectionTotal,
                    images: BangumiImages(
                      small: rewrite(e.imageSmall),
                      grid: rewrite(e.imageGrid),
                      large: rewrite(e.imageLarge),
                      medium: rewrite(e.imageMedium),
                      common: rewrite(e.imageCommon),
                    ),
                  ),
                ),
              )
              .toList();

          // Merge and de-duplicate
          final Set<int> existingIds = localFavs
              .map((f) => f.bangumiId)
              .toSet();
          for (final col in collections) {
            if (!existingIds.contains(col.subjectId)) {
              merged.add(col);
              existingIds.add(col.subjectId);
            }
          }
        } catch (e) {
          debugPrint('Error fetching bangumi collections for home: $e');
        }
      }

      if (mounted) {
        setState(() {
          _favoriteItems = merged.take(12).toList();
          _isLoadingFavorites = false;
        });
      }
      debugPrint('[HomeMobile] loadFavorites done count=${merged.length}');
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted) setState(() => _isLoadingFavorites = false);
    }
  }

  Future<void> _openHistoryItem(PlaybackHistoryItem item) async {
    var episodes = item.toEpisodes();

    if (episodes.isEmpty && item.bangumiId != null) {
      final subjectId = int.tryParse(item.bangumiId!);
      if (subjectId != null) {
        try {
          episodes = await fetchBangumiEpisodes(subjectId: subjectId);
        } catch (_) {
          episodes = <BangumiEpisode>[];
        }
      }
    }

    final playableEpisodes = episodes.releasedEpisodes();
    if (playableEpisodes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).cannotLoadEpisodes),
          ),
        );
      }
      return;
    }

    BangumiEpisode currentEpisode = playableEpisodes.latestReleasedEpisode()!;
    final byId = playableEpisodes.where((e) => e.id == item.episodeId).toList();
    if (byId.isNotEmpty) {
      currentEpisode = byId.first;
    } else {
      final bySort = playableEpisodes
          .where((e) => e.sort == item.episodeSort)
          .toList();
      if (bySort.isNotEmpty) {
        currentEpisode = bySort.first;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          anime: item.toAnimeInfo(),
          currentEpisode: currentEpisode,
          allEpisodes: playableEpisodes,
          startPositionMs: item.lastPositionMs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).navHome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppLocalizations.of(context).searchHint,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to MyPage or Profile
                // Note: In the new nav structure, MyPage is a tab.
                // Maybe open specific settings or just do nothing/show tooltip
              },
              child: NetworkAvatar(
                imageUrl: _userManager.user?.avatar.medium,
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                fallback: Icon(
                  Icons.person,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildTodaySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                AppLocalizations.of(context).recentHot,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RankingPage(),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _buildRankingList()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                AppLocalizations.of(context).historyTitle,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryPage(),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _buildHistoryList()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                AppLocalizations.of(context).favoritesTitle,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesPage(),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _buildFavoritesList()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _getExtraInfo(crawler.AnimeInfo anime) {
    if (anime.fullJson == null || anime.fullJson!.isEmpty) return '';
    try {
      final data = jsonDecode(anime.fullJson!);
      String summary = data['summary'] ?? '';
      String? director;
      String? original;
      if (data['infobox'] != null) {
        final infobox = data['infobox'] as List;
        for (final item in infobox) {
          if (item['key'] == '导演') {
            final val = item['value'];
            director = (val is List)
                ? val.map((v) => v['v'] ?? '').join(' / ')
                : val.toString();
          } else if (item['key'] == '原作') {
            final val = item['value'];
            original = (val is List)
                ? val.map((v) => v['v'] ?? '').join(' / ')
                : val.toString();
          }
        }
      }

      List<String> infos = [];
      if (original != null && original.isNotEmpty) infos.add('原作: $original');
      if (director != null && director.isNotEmpty) infos.add('导演: $director');

      String infoStr = infos.join('  |  ');
      if (summary.isNotEmpty) {
        if (infoStr.isNotEmpty) infoStr += '\n\n';
        infoStr += summary.replaceAll('\r\n', '\n').replaceAll('\n\n', '\n');
      }

      return infoStr.trim();
    } catch (e) {
      return '';
    }
  }

  Widget _buildSectionHeader(String title, VoidCallback onMore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: onMore,
            tooltip: AppLocalizations.of(context).viewMore,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection() {
    if (_isLoadingToday) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_todayAnimes.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).noTodayUpdate),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimeTablePage(),
                    ),
                  );
                },
                child: Text(AppLocalizations.of(context).viewFullTimetable),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).todayBroadcast,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimeTablePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: _todayAnimes.length,
            controller: _todayPageController,
            itemBuilder: (context, index) {
              final anime = _todayAnimes[index];
              return GestureDetector(
                onTap: () {
                  _todayTimer?.cancel();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BangumiDetailsPage(
                        anime: anime,
                        heroTag:
                            'home_today_${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}',
                      ),
                    ),
                  ).then((_) => _startTodayTimer());
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BlurredCoverBackground(
                        imageUrl: anime.coverUrl ?? '',
                        borderRadius: BorderRadius.circular(16),
                        blurSigma: 22,
                        scale: 1.14,
                        overlayOpacity: 0.12,
                        highlightOpacity: 0.13,
                        borderOpacity: 0.12,
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Hero(
                                    tag:
                                        'home_today_${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}',
                                    child: CachedNetworkImage(
                                      imageUrl: anime.coverUrl ?? '',
                                      fit: BoxFit.cover,
                                      errorWidget: Container(
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 16.0,
                                  top: 16,
                                  bottom: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      anime.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (anime.broadcastTime != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).updateTime(anime.broadcastTime!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final extra = _getExtraInfo(anime);
                                          if (extra.isEmpty) {
                                            return const SizedBox();
                                          }
                                          return Text(
                                            extra,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontSize: 11,
                                              height: 1.5,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRankingList() {
    if (_isLoadingRanking) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rankingAnimes.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(child: Text(AppLocalizations.of(context).noData)),
      );
    }

    return SizedBox(
      height: 220, // Adjusted height for AnimeCard
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _rankingAnimes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final anime = _rankingAnimes[index];
          final rankTag = anime.rank != null
              ? '#${anime.rank}'
              : '#${index + 1}';
          return SizedBox(
            width: 120,
            child: AnimeCard(
              title: anime.title,
              coverUrl: anime.coverUrl,
              score: anime.score,
              tag: rankTag,
              heroTag: 'home_rank_${anime.bangumiId}',
              onTap: () {
                final info = crawler.AnimeInfo(
                  title: anime.title,
                  bangumiId: anime.bangumiId,
                  coverUrl: anime.coverUrl,
                  score: anime.score,
                  rank: anime.rank,
                  tags: [],
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BangumiDetailsPage(
                      anime: info,
                      heroTag:
                          'home_rank_${info.bangumiId ?? info.mikanId ?? info.title.hashCode}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_historyItems.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(child: Text(AppLocalizations.of(context).noHistory)),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _historyItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return SizedBox(
            width: 160,
            child: Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openHistoryItem(item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: item.coverUrl ?? '',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "EP ${item.episodeSort % 1 == 0 ? item.episodeSort.toInt() : item.episodeSort} | ${item.episodeName}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildFavoritesList() {
    if (_isLoadingFavorites) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_favoriteItems.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(child: Text(AppLocalizations.of(context).noFavorites)),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _favoriteItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _favoriteItems[index];

          String title;
          String cover;
          double score;
          String id;

          if (item is LocalFavorite) {
            title = item.title;
            cover = item.coverUrl;
            score = item.score;
            id = item.bangumiId.toString();
          } else if (item is BangumiUserCollection) {
            title = item.subject.nameCn.isNotEmpty
                ? item.subject.nameCn
                : item.subject.name;
            cover = item.subject.images.large;
            score = item.subject.score;
            id = item.subject.id.toString();
          } else {
            return const SizedBox();
          }

          return SizedBox(
            width: 120,
            child: AnimeCard(
              title: title,
              coverUrl: cover,
              score: score,
              heroTag: 'home_fav_$id',
              onTap: () {
                final info = crawler.AnimeInfo(
                  title: title,
                  bangumiId: id,
                  coverUrl: cover,
                  score: score,
                  tags: [],
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BangumiDetailsPage(
                      anime: info,
                      heroTag:
                          'home_fav_${info.bangumiId ?? info.mikanId ?? info.title.hashCode}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
