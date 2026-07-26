import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart' as rust_bangumi;
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
  final ScrollController _scrollController = createPlatformScrollController();

  // Bangumi Data
  List<BangumiUserCollection> _bangumiCollections = [];
  bool _isLoadingBangumi = false;
  String? _bangumiError;

  // Local Data
  List<LocalFavorite> _localFavorites = [];
  bool _isLoadingLocal = false;
  final RequestGenerationGuard _localGuard = RequestGenerationGuard();
  final RequestGenerationGuard _bangumiGuard = RequestGenerationGuard();

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
    _localGuard.dispose();
    _bangumiGuard.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocalFavorites() async {
    final generation = _localGuard.begin();
    if (mounted) setState(() => _isLoadingLocal = true);
    try {
      final favs = await _favoritesManager.getAllFavorites();
      if (mounted && _localGuard.isCurrent(generation)) {
        setState(() {
          _localFavorites = favs;
          _isLoadingLocal = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching local favorites: $e');
      if (mounted && _localGuard.isCurrent(generation)) {
        setState(() => _isLoadingLocal = false);
      }
    }
  }

  Future<void> _fetchBangumiCollections() async {
    if (!_userManager.isLoggedIn) return;

    final generation = _bangumiGuard.begin();

    if (mounted) {
      setState(() {
        _isLoadingBangumi = true;
        _bangumiError = null;
      });
    }

    try {
      final username = _userManager.user!.username;
      // Hit Rust so the request goes through the ECH-capable client.
      final raw = await rust_bangumi.fetchBangumiUserCollections(
        username: username,
        subjectType: 2,
        limit: 30,
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
                images: rust_bangumi.BangumiImages(
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

      if (mounted && _bangumiGuard.isCurrent(generation)) {
        setState(() {
          _bangumiCollections = collections;
          _isLoadingBangumi = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
      if (mounted && _bangumiGuard.isCurrent(generation)) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _bangumiError = l10n.fetchCollectionsFailed(e.toString());
          _isLoadingBangumi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);
    final tabBar = TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: l10n.favoritesTabLocal),
        Tab(text: l10n.favoritesTabBangumi),
      ],
    );
    return Scaffold(
      appBar: isHosted
          ? null
          : AppBar(
              title: Text(l10n.favoritesTitle),
              actions: [
                IconButton(
                  onPressed: () {
                    _fetchLocalFavorites();
                    if (_userManager.isLoggedIn) {
                      _fetchBangumiCollections();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshAllFavorites,
                ),
              ],
              bottom: tabBar,
            ),
      body: isHosted
          ? Column(
              children: [
                DesktopPageActionRow(
                  children: [
                    IconButton(
                      onPressed: () {
                        _fetchLocalFavorites();
                        if (_userManager.isLoggedIn) {
                          _fetchBangumiCollections();
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: l10n.refreshAllFavorites,
                    ),
                  ],
                ),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: tabBar,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLocalFavorites(), _buildBangumiFavorites()],
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildLocalFavorites(), _buildBangumiFavorites()],
            ),
    );
  }

  Widget _buildLocalFavorites() {
    final l10n = AppLocalizations.of(context);
    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localFavorites.isEmpty) {
      return Center(child: Text(l10n.noLocalFavorites));
    }

    return RefreshIndicator(
      onRefresh: _fetchLocalFavorites,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _localFavorites.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _localFavorites[index];
          final heroTag = 'favorites_local_${item.bangumiId}';
          return _buildFavoriteItem(
            context: context,
            title: item.title,
            coverUrl: item.coverUrl,
            score: item.score,
            subtitle: _getTypeLabel(context, item.type),
            heroTag: heroTag,
            destination: _detailsDestination(
              item.bangumiId.toString(),
              item.title,
              item.coverUrl,
              item.score,
              heroTag: heroTag,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.favoritesRemoveTooltip,
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
    final l10n = AppLocalizations.of(context);
    if (!_userManager.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.loginBangumiFirst),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Go back to profile to login
              },
              child: Text(l10n.goToLogin),
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
              child: Text(l10n.pageRetry),
            ),
          ],
        ),
      );
    }

    if (_bangumiCollections.isEmpty) {
      return Center(child: Text(l10n.noBangumiFavorites));
    }

    return RefreshIndicator(
      onRefresh: _fetchBangumiCollections,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _bangumiCollections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _bangumiCollections[index];
          final heroTag = 'favorites_bangumi_${item.subject.id}';
          return _buildFavoriteItem(
            context: context,
            title: item.subject.nameCn.isNotEmpty
                ? item.subject.nameCn
                : item.subject.name,
            coverUrl: item.subject.images.large,
            score: item.subject.score,
            subtitle: _getTypeLabel(context, item.type),
            heroTag: heroTag,
            destination: _detailsDestination(
              item.subject.id.toString(),
              item.subject.name,
              item.subject.images.large,
              item.subject.score,
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }

  WorkspaceDestination _detailsDestination(
    String bangumiId,
    String title,
    String cover,
    double score, {
    required String heroTag,
  }) {
    final animeInfo = rust_crawler.AnimeInfo(
      title: title,
      bangumiId: bangumiId,
      coverUrl: cover,
      score: score,
      tags: [],
    );
    return WorkspaceDestinations.bangumiDetails(
      anime: animeInfo,
      heroTag: heroTag,
    );
  }

  String _getTypeLabel(BuildContext context, int type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case 1:
        return l10n.favoritesStatusWish;
      case 2:
        return l10n.favoritesStatusWatched;
      case 3:
        return l10n.favoritesStatusWatching;
      case 4:
        return l10n.favoritesStatusOnHold;
      case 5:
        return l10n.favoritesStatusDropped;
      default:
        return l10n.favoritesStatusUnknown;
    }
  }

  Widget _buildFavoriteItem({
    required BuildContext context,
    required String title,
    required String coverUrl,
    required double score,
    required String subtitle,
    required String heroTag,
    required WorkspaceDestination destination,
    Widget? trailing,
  }) {
    return WorkspaceLink(
      destination: destination,
      builder: (context, activate) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: activate,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              SizedBox(
                width: 80,
                height: 110,
                child: Hero(
                  tag: heroTag,
                  child: CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: Colors.grey),
                  ),
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
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
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
      ),
    );
  }
}
