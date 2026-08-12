import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/ui/pages/favorites/bangumi_collection_conflict_panel.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';

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
  final BangumiCollectionsRepository _collectionsRepository =
      BangumiCollectionsRepository();
  late final BangumiCollectionSyncService _syncService =
      BangumiCollectionSyncService(
        favoritesManager: _favoritesManager,
        repository: _collectionsRepository,
      );
  final ScrollController _localScrollController =
      createPlatformScrollController();
  final ScrollController _bangumiScrollController =
      createPlatformScrollController();

  // Bangumi Data
  List<BangumiUserCollection> _bangumiCollections = [];
  bool _isLoadingBangumi = false;
  String? _bangumiError;

  // Local Data
  List<LocalFavorite> _localFavorites = [];
  bool _isLoadingLocal = false;
  final RequestGenerationGuard _localGuard = RequestGenerationGuard();
  final RequestGenerationGuard _bangumiGuard = RequestGenerationGuard();
  final Map<int, BangumiCollectionResolution> _conflictChoices = {};
  List<BangumiCollectionConflict> _conflicts = [];
  bool _isSyncing = false;
  bool _isResolvingConflicts = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userManager.addListener(_onAccountChanged);
    _favoritesManager.init().then((_) => _loadForCurrentMode());
  }

  @override
  void dispose() {
    _localGuard.dispose();
    _bangumiGuard.dispose();
    _userManager.removeListener(_onAccountChanged);
    _tabController.dispose();
    _localScrollController.dispose();
    _bangumiScrollController.dispose();
    super.dispose();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _loadForCurrentMode();
  }

  Future<void> _loadForCurrentMode() async {
    if (_userManager.isSyncMode) {
      await _synchronizeCollections();
      return;
    }
    await _fetchLocalFavorites();
    if (_userManager.isLoggedIn) {
      await _fetchBangumiCollections();
    }
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
      final collections = await _collectionsRepository.fetchPublic(username);

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

  Future<void> _synchronizeCollections() async {
    final user = _userManager.user;
    if (user == null || !_userManager.isSyncMode || _isSyncing) return;
    final generation = _bangumiGuard.begin();
    if (mounted) {
      setState(() {
        _isSyncing = true;
        _syncError = null;
      });
    }
    try {
      final result = await _syncService.synchronize(user.username);
      if (!mounted || !_bangumiGuard.isCurrent(generation)) return;
      setState(() {
        _localFavorites = result.favorites;
        _conflicts = result.conflicts;
        // Do not silently choose a side. The comparison panel requires an
        // explicit choice for every conflicting subject.
        _conflictChoices.clear();
        _isLoadingLocal = false;
        _isSyncing = false;
      });
    } catch (e) {
      debugPrint('Error synchronizing collections: $e');
      if (!mounted || !_bangumiGuard.isCurrent(generation)) return;
      setState(() {
        _syncError = AppLocalizations.of(
          context,
        ).fetchCollectionsFailed(e.toString());
        _isSyncing = false;
      });
      await _fetchLocalFavorites();
    }
  }

  Future<void> _resolveConflicts(
    Map<int, BangumiCollectionResolution> resolutions,
  ) async {
    if (_isResolvingConflicts) return;
    setState(() => _isResolvingConflicts = true);
    try {
      final favorites = await _syncService.resolveFieldConflicts(
        _conflicts,
        resolutions,
      );
      if (!mounted) return;
      setState(() {
        _localFavorites = favorites;
        _conflicts = [];
        _conflictChoices.clear();
        _isResolvingConflicts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolvingConflicts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).bangumiSyncFailedWithError(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _refreshAll() => _loadForCurrentMode();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);
    if (_userManager.isSyncMode) {
      return Scaffold(
        appBar: isHosted ? null : AppBar(title: Text(l10n.favoritesTitle)),
        floatingActionButton: isHosted
            ? FloatingActionButton(
                onPressed: _isSyncing ? null : _refreshAll,
                tooltip: l10n.refreshAllFavorites,
                child: const Icon(Icons.sync),
              )
            : null,
        body: _buildSynchronizedFavorites(),
      );
    }
    final tabBar = TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: l10n.favoritesTabLocal),
        Tab(text: l10n.favoritesTabBangumi),
      ],
    );
    final tabBarView = TabBarView(
      controller: _tabController,
      children: [_buildLocalFavorites(), _buildBangumiFavorites()],
    );
    return Scaffold(
      appBar: isHosted
          ? null
          : AppBar(title: Text(l10n.favoritesTitle), bottom: tabBar),
      // Desktop refreshes through this floating button (mirroring the data
      // source page's "add source" action); mobile refreshes by pulling the
      // list down.
      floatingActionButton: isHosted
          ? FloatingActionButton(
              onPressed: _refreshAll,
              tooltip: l10n.refreshAllFavorites,
              child: const Icon(Icons.refresh),
            )
          : null,
      body: isHosted
          ? Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: tabBar,
                ),
                Expanded(child: tabBarView),
              ],
            )
          : tabBarView,
    );
  }

  Widget _buildSynchronizedFavorites() {
    if (_isSyncing && _localFavorites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_syncError != null && _localFavorites.isEmpty) {
      return _buildErrorState(_syncError!, _synchronizeCollections);
    }

    final favorites = _buildLocalFavorites(
      onRefresh: _synchronizeCollections,
      synchronized: true,
    );
    if (_conflicts.isEmpty) {
      return Column(
        children: [
          if (_isSyncing) const LinearProgressIndicator(),
          if (_syncError != null) _buildSyncErrorBanner(_syncError!),
          Expanded(child: favorites),
        ],
      );
    }

    final panel = BangumiCollectionConflictPanel(
      conflicts: _conflicts,
      statusLabel: (type) => _getTypeLabel(context, type),
      onResolve: _resolveConflicts,
      isResolving: _isResolvingConflicts,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return panel;
        return Row(
          children: [
            Expanded(child: favorites),
            const VerticalDivider(width: 1),
            SizedBox(width: 520, child: panel),
          ],
        );
      },
    );
  }

  Widget _buildSyncErrorBanner(String message) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.sync_problem, color: colors.onErrorContainer),
        title: Text(message),
        trailing: IconButton(
          onPressed: _synchronizeCollections,
          tooltip: AppLocalizations.of(context).pageRetry,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() retry) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: Text(l10n.pageRetry)),
        ],
      ),
    );
  }

  Widget _buildLocalFavorites({
    Future<void> Function()? onRefresh,
    bool synchronized = false,
  }) {
    final l10n = AppLocalizations.of(context);
    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localFavorites.isEmpty) {
      return _buildRefreshableEmpty(
        message: l10n.noLocalFavorites,
        onRefresh: onRefresh ?? _fetchLocalFavorites,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? _fetchLocalFavorites,
      child: ListView.separated(
        controller: _localScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
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
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (synchronized) {
                    await _syncService.deleteFavorite(item.bangumiId);
                  } else {
                    await _favoritesManager.removeFavorite(item.bangumiId);
                  }
                  await _fetchLocalFavorites();
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l10n.favoriteUpdateFailed(e.toString())),
                    ),
                  );
                }
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
      return _buildRefreshableEmpty(
        message: l10n.noBangumiFavorites,
        onRefresh: _fetchBangumiCollections,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBangumiCollections,
      child: ListView.separated(
        controller: _bangumiScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
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

  Widget _buildRefreshableEmpty({
    required String message,
    required RefreshCallback onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(message)),
          ),
        ],
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
