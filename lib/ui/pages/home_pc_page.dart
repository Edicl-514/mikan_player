import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/favorites_page.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/widgets/blurred_cover_background.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

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

  late PageController _todayPageController;
  Timer? _todayTimer;

  @override
  void initState() {
    super.initState();
    _todayPageController = PageController(viewportFraction: 0.85);
    _userManager.addListener(_onUserUpdate);
    _loadAllData();
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    _todayPageController.dispose();
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
    _loadTodayAnimes();
    _loadRanking();
    _loadHistory();
    _loadFavorites();
  }

  Future<void> _loadTodayAnimes() async {
    try {
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
        fetchFromNetwork: () =>
            crawler.fetchScheduleBasic(yearQuarter: currentQuarter),
      );

      final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final todayStr = weekDays[now.weekday - 1];

      var todayList = animes.where((a) => a.broadcastDay == todayStr).toList();

      if (mounted) {
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
          final enriched = await crawler.fillAnimeDetails(
            animes: missingCovers,
          );
          await CacheManager.instance.cacheAnimeInfos(enriched);

          for (final item in enriched) {
            final index = todayList.indexWhere(
              (a) => a.bangumiId == item.bangumiId,
            );
            if (index != -1) {
              todayList[index] = item;
            }
          }
          if (mounted) {
            setState(() {
              _todayAnimes = List.from(todayList);
            });
          }
        } catch (e) {
          debugPrint('Failed to enrich today animes: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading today animes: $e');
      if (mounted) setState(() => _isLoadingToday = false);
    }
  }

  Future<void> _loadRanking() async {
    try {
      final results = await CacheManager.instance.getRanking(
        sortType: 'trends',
        page: 1,
        fetchFromNetwork: () =>
            fetchBangumiRanking(sortType: 'trends', page: 1),
      );
      if (mounted) {
        setState(() {
          _rankingAnimes = results;
          _isLoadingRanking = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading ranking: $e');
      if (mounted) setState(() => _isLoadingRanking = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _historyManager.getHistory();
      if (mounted) {
        setState(() {
          _historyItems = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      await _favoritesManager.init();
      final localFavs = await _favoritesManager.getAllFavorites();

      List<dynamic> merged = List.from(localFavs);

      if (_userManager.isLoggedIn) {
        try {
          final username = _userManager.user!.username;
          final client = HttpClient();
          final request = await client.getUrl(
            Uri.parse(
              'https://api.bgm.tv/v0/users/$username/collections?subject_type=2&limit=20&offset=0',
            ),
          );
          request.headers.add('accept', 'application/json');
          request.headers.add('User-Agent', 'MikanPlayer/1.0.0 (flutter)');

          final response = await request.close();
          if (response.statusCode == 200) {
            final responseBody = await response.transform(utf8.decoder).join();
            final json = jsonDecode(responseBody);
            final data = json['data'] as List;
            final collections = data
                .map((e) => BangumiUserCollection.fromJson(e))
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
          }
        } catch (e) {
          debugPrint('Error fetching bangumi collections for home: $e');
        }
      }

      if (mounted) {
        setState(() {
          _favoriteItems = merged;
          _isLoadingFavorites = false;
        });
      }
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

    if (episodes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法加载剧集列表')));
      }
      return;
    }

    BangumiEpisode currentEpisode = episodes.first;
    final byId = episodes.where((e) => e.id == item.episodeId).toList();
    if (byId.isNotEmpty) {
      currentEpisode = byId.first;
    } else {
      final bySort = episodes.where((e) => e.sort == item.episodeSort).toList();
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
          allEpisodes: episodes,
          startPositionMs: item.lastPositionMs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTodaySection(),
                const SizedBox(height: 32),
                _buildSectionHeader(AppLocalizations.of(context).recentHot, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RankingPage(),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _buildRankingList(),
                const SizedBox(height: 32),
                _buildSectionHeader(
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
                const SizedBox(height: 16),
                _buildHistoryList(),
                const SizedBox(height: 32),
                _buildSectionHeader(
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
                const SizedBox(height: 16),
                _buildFavoritesList(),
              ],
            ),
          ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimeTablePage(),
                    ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TimeTablePage(),
                  ),
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
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BangumiDetailsPage(
                          anime: anime,
                          heroTagPrefix: 'home_pc_today',
                        ),
                      ),
                    );
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).updateTime(anime.broadcastTime!),
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
                        heroTagPrefix: 'home_pc_rank',
                      ),
                    ),
                  );
                },
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
              return Card(
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
                              maxLines: 2,
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
                        heroTagPrefix: 'home_pc_fav',
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
