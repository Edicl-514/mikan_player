import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart' as ranking;
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';

typedef RankingPageFetcher =
    Future<List<ranking.RankingAnime>> Function(String sortType, int page);

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.rankingTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.rankingTrending),
              Tab(text: l10n.rankingRanking),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RankingList(sortType: 'trends'),
            RankingList(sortType: 'rank'),
          ],
        ),
      ),
    );
  }
}

class RankingList extends StatefulWidget {
  final String sortType; // 'trends' or 'rank'
  final RankingPageFetcher? fetchPage;

  const RankingList({super.key, required this.sortType, this.fetchPage});

  @override
  State<RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<RankingList>
    with AutomaticKeepAliveClientMixin {
  late final PagedRequestController<String, ranking.RankingAnime> _controller;
  final ScrollController _scrollController = createPlatformScrollController();

  List<ranking.RankingAnime> get _items => _controller.items;
  bool get _isLoading => _controller.isLoading;
  bool get _isLoadingMore => _controller.isLoadingMore;
  String? get _errorMessage => _controller.error?.toString();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = PagedRequestController<String, ranking.RankingAnime>(
      fetchPage: (sortType, page) {
        final fetchPage = widget.fetchPage;
        if (fetchPage != null) return fetchPage(sortType, page);
        return CacheManager.instance.getRanking(
          sortType: sortType,
          page: page,
          fetchFromNetwork: () =>
              ranking.fetchBangumiRanking(sortType: sortType, page: page),
        );
      },
    )..addListener(_onControllerChanged);
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RankingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortType != widget.sortType) _loadData();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    await _controller.refresh(widget.sortType);
  }

  Future<void> _loadMore() async {
    await _controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.loadFailed(_errorMessage ?? l10n.unknownError)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.pageRetry)),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(child: Text(l10n.noData));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = _items[index];
        return _buildItem(context, item, index);
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    ranking.RankingAnime item,
    int index,
  ) {
    // Determine rank display
    // If 'top', sometimes items have rank. If not, maybe use index + 1?
    // For 'trends', rank might not be explicitly in the item from scraper if it's not provided by Bangumi.
    // However, if we scroll, index + 1 is a good proxy for "Current List Position".
    // But if `item.rank` exists (parsed from "Rank X"), use it.
    final rankDisplay = item.rank != null ? '#${item.rank}' : '#${index + 1}';
    final animeInfo = crawler.AnimeInfo(
      title: item.title,
      bangumiId: item.bangumiId,
      coverUrl: item.coverUrl,
      score: item.score,
      rank: item.rank,
      tags: item.info.split(' / ').toList(),
      subTitle: item.originalTitle,
    );
    final destination = WorkspaceDestinations.bangumiDetails(
      anime: animeInfo,
      heroTag:
          'ranking_cover_${animeInfo.bangumiId ?? animeInfo.mikanId ?? animeInfo.title.hashCode}',
    );

    return WorkspaceLink(
      destination: destination,
      builder: (context, activate) => Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: activate,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Cover with Score and Rank
              AspectRatio(
                aspectRatio: 0.7,
                child: Stack(
                  children: [
                    Hero(
                      tag:
                          'ranking_cover_${item.bangumiId.isNotEmpty ? item.bangumiId : item.title.hashCode}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.coverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorWidget: Container(color: Colors.grey[300]),
                              )
                            : Container(color: Colors.grey[300]),
                      ),
                    ),
                    // Rank Tag
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          rankDisplay,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (item.score != null && item.score! > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            item.score!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.originalTitle != null &&
                        item.originalTitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.originalTitle!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      item.info,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
