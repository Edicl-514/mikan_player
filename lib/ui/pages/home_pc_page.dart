import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/playback_history_episode_resolver.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust_bangumi;
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/utils/broadcast_day_tokens.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/widgets/blurred_cover_background.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';

class HomePcPage extends StatefulWidget {
  const HomePcPage({super.key});

  @override
  State<HomePcPage> createState() => _HomePcPageState();
}

class _HomePcPageState extends State<HomePcPage> {
  final UserManager _userManager = UserManager();
  final FavoritesManager _favoritesManager = FavoritesManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();

  List<crawler.AnimeInfo> _todayAnimes = [];
  List<RankingAnime> _rankingAnimes = [];
  List<PlaybackHistoryItem> _historyItems = [];
  List<dynamic> _favoriteItems = [];

  bool _isLoadingToday = true;
  bool _isLoadingRanking = true;
  bool _isLoadingHistory = true;
  bool _isLoadingFavorites = true;

  final RequestGenerationGuard _todayGuard = RequestGenerationGuard();
  final RequestGenerationGuard _rankingGuard = RequestGenerationGuard();
  final RequestGenerationGuard _historyGuard = RequestGenerationGuard();
  final RequestGenerationGuard _favoritesGuard = RequestGenerationGuard();

  late PageController _todayPageController;
  Timer? _todayTimer;
  final ScrollController _scrollController = createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _todayPageController = PageController(viewportFraction: 0.85);
    _userManager.addListener(_onUserUpdate);
    _loadAllData();
  }

  @override
  void dispose() {
    _todayGuard.dispose();
    _rankingGuard.dispose();
    _historyGuard.dispose();
    _favoritesGuard.dispose();
    _todayTimer?.cancel();
    _todayPageController.dispose();
    _scrollController.dispose();
    _userManager.removeListener(_onUserUpdate);
    super.dispose();
  }

  void _startTodayTimer() {
    _todayTimer?.cancel();
    if (_todayAnimes.isEmpty) return;
    _todayTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_todayAnimes.isEmpty || !mounted) return;
      if (_todayPageController.hasClients) {
        int nextPage = (_todayPageController.page?.round() ?? 0) + 1;
        if (nextPage >= _todayAnimes.length) {
          _todayPageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.fastOutSlowIn,
          );
        } else {
          _todayPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.fastOutSlowIn,
          );
        }
      }
    });
  }

  void _onUserUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllData() async {
    debugPrint('[HomePc] loadAllData start');
    await Future.wait([
      _loadTodayAnimes(),
      _loadRanking(),
      _loadHistory(),
      _loadFavorites(),
    ]);
  }

  Future<void> _loadTodayAnimes() async {
    final generation = _todayGuard.begin();
    try {
      debugPrint('[HomePc] loadTodayAnimes start');
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

      final animes = await CacheManager.instance.getTimetable(
        quarter: currentQuarter,
      );
      debugPrint(
        '[HomePc] timetable loaded quarter=$currentQuarter '
        'count=${animes.length}',
      );

      final todayStr = broadcastDayTokenForWeekday(now.weekday);

      var todayList = animes.where((a) => a.broadcastDay == todayStr).toList();
      debugPrint(
        '[HomePc] today filter day=$todayStr count=${todayList.length}',
      );

      if (mounted && _todayGuard.isCurrent(generation)) {
        setState(() {
          _todayAnimes = todayList;
          _isLoadingToday = false;
        });
        _startTodayTimer();
      }

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
            '[HomePc] fillAnimeDetails start count=${missingCovers.length}',
          );
          final enriched = await crawler.fillAnimeDetails(
            animes: missingCovers,
          );
          debugPrint('[HomePc] fillAnimeDetails done count=${enriched.length}');
          await CacheManager.instance.cacheAnimeInfos(enriched);

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
          debugPrint('[HomePc] enriched timetable saved');
          if (mounted && _todayGuard.isCurrent(generation)) {
            setState(() {
              _todayAnimes = List.from(todayList);
            });
          }
        } catch (e) {
          debugPrint('Failed to enrich today animes: $e');
        }
      }
      debugPrint('[HomePc] loadTodayAnimes done');
    } catch (e) {
      debugPrint('Error loading today animes: $e');
      if (mounted && _todayGuard.isCurrent(generation)) {
        setState(() => _isLoadingToday = false);
      }
    }
  }

  Future<void> _loadRanking() async {
    final generation = _rankingGuard.begin();
    try {
      debugPrint('[HomePc] loadRanking start');
      final results = await CacheManager.instance.getRanking(
        sortType: 'trends',
        page: 1,
        fetchFromNetwork: () =>
            fetchBangumiRanking(sortType: 'trends', page: 1),
      );
      if (mounted && _rankingGuard.isCurrent(generation)) {
        setState(() {
          _rankingAnimes = results;
          _isLoadingRanking = false;
        });
      }
      debugPrint('[HomePc] loadRanking done count=${results.length}');
    } catch (e) {
      debugPrint('Error loading ranking: $e');
      if (mounted && _rankingGuard.isCurrent(generation)) {
        setState(() => _isLoadingRanking = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    final generation = _historyGuard.begin();
    try {
      debugPrint('[HomePc] loadHistory start');
      final history = await _historyManager.getHistory();
      if (mounted && _historyGuard.isCurrent(generation)) {
        setState(() {
          _historyItems = history;
          _isLoadingHistory = false;
        });
      }
      debugPrint('[HomePc] loadHistory done count=${history.length}');
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted && _historyGuard.isCurrent(generation)) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _loadFavorites() async {
    final generation = _favoritesGuard.begin();
    try {
      debugPrint('[HomePc] loadFavorites start');
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

      if (mounted && _favoritesGuard.isCurrent(generation)) {
        setState(() {
          _favoriteItems = merged;
          _isLoadingFavorites = false;
        });
      }
      debugPrint('[HomePc] loadFavorites done count=${merged.length}');
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted && _favoritesGuard.isCurrent(generation)) {
        setState(() => _isLoadingFavorites = false);
      }
    }
  }

  Future<void> _openHistoryItem(
    PlaybackHistoryItem item, {
    WorkspaceOpenDisposition disposition = WorkspaceOpenDisposition.currentTab,
  }) async {
    final episodes = await resolvePlaybackHistoryEpisodes(item);
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
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.player(
        anime: item.toAnimeInfo(),
        currentEpisode: currentEpisode,
        allEpisodes: playableEpisodes,
        startPositionMs: item.lastPositionMs,
      ),
      disposition: disposition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTodaySection(),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context).recentHot, () {
                  WorkspaceNavigation.open<void>(
                    context,
                    WorkspaceDestinations.ranking(context),
                  );
                }),
                const SizedBox(height: 16),
                _buildRankingList(),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  AppLocalizations.of(context).historyTitle,
                  () {
                    WorkspaceNavigation.open<void>(
                      context,
                      WorkspaceDestinations.history(context),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildHistoryList(),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  AppLocalizations.of(context).favoritesTitle,
                  () {
                    WorkspaceNavigation.open<void>(
                      context,
                      WorkspaceDestinations.favorites(context),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildFavoritesList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getExtraInfo(crawler.AnimeInfo anime, AppLocalizations l10n) {
    if (anime.fullJson == null || anime.fullJson!.isEmpty) return '';
    try {
      final data = jsonDecode(anime.fullJson!);
      String summary = data['summary'] ?? '';
      String? director;
      String? original;
      if (data['infobox'] != null) {
        final infobox = data['infobox'] as List;
        for (final item in infobox) {
          // i18n-ignore: upstream Bangumi infobox key token used for matching
          if (item['key'] == '导演') {
            final val = item['value'];
            director = (val is List)
                ? val.map((v) => v['v'] ?? '').join(' / ')
                : val.toString();
            // i18n-ignore: upstream Bangumi infobox key token used for matching
          } else if (item['key'] == '原作') {
            final val = item['value'];
            original = (val is List)
                ? val.map((v) => v['v'] ?? '').join(' / ')
                : val.toString();
          }
        }
      }

      List<String> infos = [];
      if (original != null && original.isNotEmpty) {
        infos.add(l10n.homeOriginalWork(original));
      }
      if (director != null && director.isNotEmpty) {
        infos.add(l10n.homeDirector(director));
      }

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onMore,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).viewMore),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySection() {
    if (_isLoadingToday) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_todayAnimes.isEmpty) {
      return Container(
        height: 320,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context).noTodayUpdate),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month),
                onPressed: () {
                  WorkspaceNavigation.open<void>(
                    context,
                    WorkspaceDestinations.timetable(context),
                  );
                },
                label: Text(AppLocalizations.of(context).viewFullTimetable),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).todayBroadcast,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () {
                WorkspaceNavigation.open<void>(
                  context,
                  WorkspaceDestinations.timetable(context),
                );
              },
              icon: const Icon(Icons.calendar_month),
              tooltip: AppLocalizations.of(context).viewFullTimetable,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: _todayAnimes.length,
            controller: _todayPageController,
            itemBuilder: (context, index) {
              final anime = _todayAnimes[index];
              final heroTag =
                  'home_pc_today_${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}';
              return AnimatedBuilder(
                animation: _todayPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_todayPageController.position.haveDimensions) {
                    value = _todayPageController.page! - index;
                    value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 360,
                      width: double.infinity,
                      child: child,
                    ),
                  );
                },
                child: WorkspaceLink(
                  destination: WorkspaceDestinations.bangumiDetails(
                    anime: anime,
                    heroTag: heroTag,
                  ),
                  builder: (context, activate) => GestureDetector(
                    onTap: () {
                      _todayTimer?.cancel();
                      activate();
                      _startTodayTimer();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BlurredCoverBackground(
                            imageUrl: anime.coverUrl ?? '',
                            borderRadius: BorderRadius.circular(24),
                            blurSigma: 26,
                            scale: 1.16,
                            overlayOpacity: 0.1,
                            highlightOpacity: 0.14,
                            borderOpacity: 0.14,
                          ),
                          Positioned.fill(
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Hero(
                                        tag: heroTag,
                                        child: CachedNetworkImage(
                                          imageUrl: anime.coverUrl ?? '',
                                          fit: BoxFit.cover,
                                          cacheWidth: 600,
                                          cacheHeight: 800,
                                          deferOffscreenLoad: false,
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
                                      right: 32.0,
                                      top: 32,
                                      bottom: 32,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          anime.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 16),
                                        if (anime.broadcastTime != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).updateTime(
                                                anime.broadcastTime!,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: Builder(
                                            builder: (context) {
                                              final extra = _getExtraInfo(
                                                anime,
                                                AppLocalizations.of(context),
                                              );
                                              if (extra.isEmpty) {
                                                return const SizedBox();
                                              }
                                              return Text(
                                                extra,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                  fontSize: 14,
                                                  height: 1.5,
                                                ),
                                                maxLines: 5,
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
        height: 496,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_rankingAnimes.isEmpty) {
      return SizedBox(
        height: 496,
        child: Center(child: Text(AppLocalizations.of(context).noData)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double cardWidth = 130;
          const double cardHeight = 240;
          const double spacing = 16;
          final crossAxisCount =
              ((constraints.maxWidth + spacing) / (cardWidth + spacing))
                  .floor()
                  .clamp(1, 100);
          final maxItems = (crossAxisCount * 2).clamp(0, _rankingAnimes.length);
          final items = _rankingAnimes.take(maxItems).toList();

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final anime = entry.value;
              final rankTag = anime.rank != null
                  ? '#${anime.rank}'
                  : '#${index + 1}';
              return AnimeCard(
                title: anime.title,
                coverUrl: anime.coverUrl,
                score: anime.score,
                tag: rankTag,
                heroTag: 'home_pc_rank_${anime.bangumiId}',
                cacheWidth: 320,
                deferOffscreenLoad: false,
                destination: WorkspaceDestinations.bangumiDetails(
                  anime: crawler.AnimeInfo(
                    title: anime.title,
                    bangumiId: anime.bangumiId,
                    coverUrl: anime.coverUrl,
                    score: anime.score,
                    rank: anime.rank,
                    tags: [],
                  ),
                  heroTag: 'home_pc_rank_${anime.bangumiId}',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingHistory) {
      return const SizedBox(
        height: 376,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_historyItems.isEmpty) {
      return SizedBox(
        height: 376,
        child: Center(child: Text(AppLocalizations.of(context).noHistory)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double cardWidth = 180;
          const double cardHeight = 180;
          const double spacing = 16;
          final crossAxisCount =
              ((constraints.maxWidth + spacing) / (cardWidth + spacing))
                  .floor()
                  .clamp(1, 100);
          final maxItems = (crossAxisCount * 2).clamp(0, _historyItems.length);
          final items = _historyItems.take(maxItems).toList();

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
            children: items.map((item) {
              return WorkspaceLinkAction(
                onOpen: (disposition) =>
                    _openHistoryItem(item, disposition: disposition),
                builder: (context, activate) => Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: activate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: item.coverUrl ?? '',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: 360,
                            deferOffscreenLoad: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).homeEpisodeProgress(
                                  '${item.episodeSort % 1 == 0 ? item.episodeSort.toInt() : item.episodeSort}',
                                  item.episodeName,
                                ),
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
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesList() {
    if (_isLoadingFavorites) {
      return const SizedBox(
        height: 496,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_favoriteItems.isEmpty) {
      return SizedBox(
        height: 496,
        child: Center(child: Text(AppLocalizations.of(context).noFavorites)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double cardWidth = 130;
          const double cardHeight = 240;
          const double spacing = 16;
          final crossAxisCount =
              ((constraints.maxWidth + spacing) / (cardWidth + spacing))
                  .floor()
                  .clamp(1, 100);
          final maxItems = (crossAxisCount * 2).clamp(0, _favoriteItems.length);
          final items = _favoriteItems.take(maxItems).toList();

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardWidth / cardHeight,
            children: items.map((item) {
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

              return AnimeCard(
                title: title,
                coverUrl: cover,
                score: score,
                heroTag: 'home_pc_fav_$id',
                cacheWidth: 320,
                deferOffscreenLoad: false,
                destination: WorkspaceDestinations.bangumiDetails(
                  anime: crawler.AnimeInfo(
                    title: title,
                    bangumiId: id,
                    coverUrl: cover,
                    score: score,
                    tags: [],
                  ),
                  heroTag: 'home_pc_fav_$id',
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
