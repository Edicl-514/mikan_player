import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/ranking.dart' as ranking;
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('排行榜'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '近期热门'),
              Tab(text: '排行榜'),
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

  const RankingList({super.key, required this.sortType});

  @override
  State<RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<RankingList>
    with AutomaticKeepAliveClientMixin {
  final List<ranking.RankingAnime> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用缓存管理器获取数据
      final items = await CacheManager.instance.getRanking(
        sortType: widget.sortType,
        page: 1,
        fetchFromNetwork: () =>
            ranking.fetchBangumiRanking(sortType: widget.sortType, page: 1),
      );
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items);
          _page = 1;
          _isLoading = false;
          // Bangumi usually has many pages, but if we get empty list, no more.
          _hasMore = items.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 使用缓存管理器获取数据
      final items = await CacheManager.instance.getRanking(
        sortType: widget.sortType,
        page: _page + 1,
        fetchFromNetwork: () => ranking.fetchBangumiRanking(
          sortType: widget.sortType,
          page: _page + 1,
        ),
      );
      if (mounted) {
        setState(() {
          if (items.isEmpty) {
            _hasMore = false;
          } else {
            _items.addAll(items);
            _page++;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        // Optionally show snackbar error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('没有数据'));
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

    return Container(
      height: 140, // Slightly taller for more info
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navigate to details
          final animeInfo = crawler.AnimeInfo(
            title: item.title,
            bangumiId: item.bangumiId,
            coverUrl: item.coverUrl,
            score: item.score,
            rank: item.rank,
            tags: item.info
                .split(' / ')
                .toList(), // Bangumi info usually separated by / or space
            // Other fields optional/default
            subTitle: item.originalTitle,
            mikanId: null,
            siteUrl: null,
            broadcastDay: null,
            broadcastTime: null,
            fullJson: null,
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BangumiDetailsPage(
                anime: animeInfo,
                heroTagPrefix: 'ranking_cover',
              ),
            ),
          );
        },
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
    );
  }
}
