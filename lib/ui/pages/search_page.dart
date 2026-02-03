import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialKeyword;

  const SearchPage({super.key, this.initialKeyword});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<RankingAnime> _results = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  String _currentKeyword = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) {
      _searchController.text = widget.initialKeyword!;
      _currentKeyword = widget.initialKeyword!;
      _performSearch();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _performSearch() async {
    if (_currentKeyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _page = 1;
      _hasMore = true;
    });

    try {
      final results = await searchBangumiSubject(
        keyword: _currentKeyword,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _hasMore = results.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _page + 1;
      final results = await searchBangumiSubject(
        keyword: _currentKeyword,
        page: nextPage,
      );
      if (mounted) {
        setState(() {
          _results.addAll(results);
          _page = nextPage;
          _hasMore = results.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Don't show snackbar for load more error to avoid spamming, just stop loading
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSearchSubmit(String value) {
    if (value.trim().isEmpty) return;
    _currentKeyword = value.trim();
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search anime...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
          onSubmitted: _handleSearchSubmit,
          autofocus: true,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _handleSearchSubmit(_searchController.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _results.isEmpty && _currentKeyword.isNotEmpty) {
      return const Center(child: Text('No results found'));
    }

    if (_currentKeyword.isEmpty) {
      return const Center(child: Text('Enter a keyword to search'));
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= _results.length) return null;
              final anime = _results[index];

              String tag =
                  'TV'; // Default fallback, but RankingAnime doesn't have type info easily parsed yet
              if (anime.rank != null) {
                tag = '#${anime.rank}';
              }

              final heroTag = 'search_${anime.bangumiId}_${index}';

              return AnimeCard(
                title: anime.title,
                subtitle: anime.info,
                tag: tag,
                coverUrl: anime.coverUrl,
                score: anime.score,
                heroTag: heroTag,
                onTap: () {
                  final animeInfo = crawler.AnimeInfo(
                    title: anime.title,
                    bangumiId: anime.bangumiId,
                    coverUrl: anime.coverUrl,
                    score: anime.score,
                    rank: anime.rank,
                    tags: anime.info.split(' / ').toList(),
                    subTitle: anime.originalTitle,
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
                        heroTagPrefix: 'search',
                      ),
                    ),
                  );
                },
              );
            }, childCount: _results.length),
          ),
        ),
        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
