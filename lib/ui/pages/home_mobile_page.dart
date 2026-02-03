import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

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
    _loadTodayAnimes();
    _loadRanking();
    _loadHistory();
    _loadFavorites();
  }

  Future<void> _loadTodayAnimes() async {
    try {
      // 1. Get archives to find current quarter
      // We can try to guess the quarter or fetch the list. Fetching list is safer.
      final archives = await crawler.fetchArchiveList();
      if (archives.isNotEmpty) {
        final currentQuarter = archives.first.quarter;

        // 2. Get timetable
        final animes = await CacheManager.instance.getTimetable(
          quarter: currentQuarter,
          fetchFromNetwork: () =>
              crawler.fetchScheduleBasic(yearQuarter: currentQuarter),
        );

        // 3. Filter for today
        final now = DateTime.now();
        final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final todayStr = weekDays[now.weekday - 1];

        var todayList = animes
            .where((a) => a.broadcastDay == todayStr)
            .toList();

        if (mounted) {
          setState(() {
            _todayAnimes = todayList;
            _isLoadingToday = false;
          });
          _startTodayTimer();
        }

        // 4. Fill details if covers are missing
        final missingCovers = todayList
            .where((a) => a.coverUrl == null || a.coverUrl!.isEmpty)
            .toList();
        if (missingCovers.isNotEmpty) {
          try {
            final enriched = await crawler.fillAnimeDetails(
              animes: missingCovers,
            );
            // Update the list with enriched data
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
          _rankingAnimes = results.take(10).toList();
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
          _historyItems = history.take(10).toList();
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
      appBar: AppBar(
        title: const Text('首页', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索番剧',
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
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                backgroundImage: _userManager.user?.avatar.medium != null
                    ? NetworkImage(_userManager.user!.avatar.medium)
                    : null,
                child: _userManager.user == null
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodaySection(),
              const SizedBox(height: 24),
              _buildSectionHeader('近期热门', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RankingPage()),
                );
              }),
              _buildRankingList(),
              const SizedBox(height: 24),
              _buildSectionHeader('历史记录', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              }),
              _buildHistoryList(),
              const SizedBox(height: 24),
              _buildSectionHeader('我的收藏', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoritesPage(),
                  ),
                );
              }),
              _buildFavoritesList(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
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
            tooltip: '查看更多',
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
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('今天没有更新的番剧哦'),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimeTablePage(),
                    ),
                  );
                },
                child: const Text('查看完整时间表'),
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
              const Text(
                '今日放送',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BangumiDetailsPage(
                        anime: anime,
                        heroTagPrefix: 'home_today',
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: anime.coverUrl ?? '',
                          fit: BoxFit.cover,
                          errorWidget: Container(color: Colors.grey[800]),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (anime.broadcastTime != null)
                              Text(
                                "更新时间: ${anime.broadcastTime}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
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
      return const SizedBox(height: 180, child: Center(child: Text('暂无数据')));
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
                      heroTagPrefix: 'home_rank',
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
      return const SizedBox(height: 100, child: Center(child: Text('暂无播放记录')));
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
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                            "EP ${item.episodeSort} · ${item.episodeName}",
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
      return const SizedBox(height: 100, child: Center(child: Text('暂无收藏')));
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
                      heroTagPrefix: 'home_fav',
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
