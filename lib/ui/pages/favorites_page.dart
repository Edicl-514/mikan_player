import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

import 'package:mikan_player/src/rust/api/crawler.dart' as rust_crawler;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserManager _userManager = UserManager();
  final FavoritesManager _favoritesManager = FavoritesManager();

  // Bangumi Data
  List<BangumiUserCollection> _bangumiCollections = [];
  bool _isLoadingBangumi = false;
  String? _bangumiError;

  // Local Data
  List<LocalFavorite> _localFavorites = [];
  bool _isLoadingLocal = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _favoritesManager.init().then((_) => _fetchLocalFavorites());
    if (_userManager.isLoggedIn) {
      _fetchBangumiCollections();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocalFavorites() async {
    setState(() => _isLoadingLocal = true);
    final favs = await _favoritesManager.getAllFavorites();
    if (mounted) {
      setState(() {
        _localFavorites = favs;
        _isLoadingLocal = false;
      });
    }
  }

  Future<void> _fetchBangumiCollections() async {
    if (!_userManager.isLoggedIn) return;

    setState(() {
      _isLoadingBangumi = true;
      _bangumiError = null;
    });

    try {
      final username = _userManager.user!.username;
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://api.bgm.tv/v0/users/$username/collections?subject_type=2&limit=30&offset=0',
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

        if (mounted) {
          setState(() {
            _bangumiCollections = collections;
            _isLoadingBangumi = false;
          });
        }
      } else {
        throw Exception('Failed to fetch collections: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
      if (mounted) {
        setState(() {
          _bangumiError = '获取收藏失败: $e';
          _isLoadingBangumi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          IconButton(
            onPressed: () {
              _fetchLocalFavorites();
              if (_userManager.isLoggedIn) {
                _fetchBangumiCollections();
              }
            },
            icon: const Icon(Icons.refresh),
            tooltip: '刷新所有收藏',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本地收藏'),
            Tab(text: 'Bangumi 同步'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLocalFavorites(), _buildBangumiFavorites()],
      ),
    );
  }

  Widget _buildLocalFavorites() {
    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localFavorites.isEmpty) {
      return const Center(child: Text('暂无本地收藏'));
    }

    return RefreshIndicator(
      onRefresh: _fetchLocalFavorites,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _localFavorites.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _localFavorites[index];
          return _buildFavoriteItem(
            context: context,
            title: item.title,
            coverUrl: item.coverUrl,
            score: item.score,
            subtitle: _getTypeLabel(item.type),
            onTap: () {
              _navigateToDetails(
                item.bangumiId.toString(),
                item.title,
                item.coverUrl,
                item.score,
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _favoritesManager.removeFavorite(item.bangumiId);
                _fetchLocalFavorites();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBangumiFavorites() {
    if (!_userManager.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('请先登录 Bangumi 账号'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Go back to profile to login
              },
              child: const Text('去登录'),
            ),
          ],
        ),
      );
    }

    if (_isLoadingBangumi) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bangumiError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_bangumiError!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _fetchBangumiCollections,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_bangumiCollections.isEmpty) {
      return const Center(child: Text('暂无 Bangumi 收藏数据'));
    }

    return RefreshIndicator(
      onRefresh: _fetchBangumiCollections,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _bangumiCollections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _bangumiCollections[index];
          return _buildFavoriteItem(
            context: context,
            title: item.subject.nameCn.isNotEmpty
                ? item.subject.nameCn
                : item.subject.name,
            coverUrl: item.subject.images.large,
            score: item.subject.score,
            subtitle: _getTypeLabel(item.type),
            onTap: () {
              _navigateToDetails(
                item.subject.id.toString(),
                item.subject.name,
                item.subject.images.large,
                item.subject.score,
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToDetails(
    String bangumiId,
    String title,
    String cover,
    double score,
  ) {
    final animeInfo = rust_crawler.AnimeInfo(
      title: title,
      bangumiId: bangumiId,
      coverUrl: cover,
      score: score,
      tags: [],
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BangumiDetailsPage(anime: animeInfo),
      ),
    );
  }

  String _getTypeLabel(int type) {
    switch (type) {
      case 1:
        return '想看';
      case 2:
        return '看过';
      case 3:
        return '在看';
      case 4:
        return '搁置';
      case 5:
        return '抛弃';
      default:
        return '未知';
    }
  }

  Widget _buildFavoriteItem({
    required BuildContext context,
    required String title,
    required String coverUrl,
    required double score,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            SizedBox(
              width: 80,
              height: 110,
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (score > 0) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            "$score",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Padding(padding: const EdgeInsets.all(12.0), child: trailing),
          ],
        ),
      ),
    );
  }
}
