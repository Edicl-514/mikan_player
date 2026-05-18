import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialKeyword;
  final String? initialTag;

  const SearchPage({super.key, this.initialKeyword, this.initialTag});

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
  String _sortType = 'rank';
  SearchMode _searchMode = SearchMode.keyword;
  bool _initialQueryLoaded = false;
  final ScrollController _scrollController = createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTag != null) {
      _searchMode = SearchMode.tag;
      _searchController.text = widget.initialTag!;
      _currentKeyword = widget.initialTag!;
    } else if (widget.initialKeyword != null) {
      _searchMode = SearchMode.keyword;
      _searchController.text = widget.initialKeyword!;
      _currentKeyword = widget.initialKeyword!;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialQueryLoaded) return;
    _initialQueryLoaded = true;
    if (_currentKeyword.isNotEmpty) {
      _performSearch();
    }
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
      final results = await _searchMode.fetch(
        keyword: _currentKeyword,
        sortType: _sortType,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).searchFailed(e.toString()),
            ),
          ),
        );
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
      final results = await _searchMode.fetch(
        keyword: _currentKeyword,
        sortType: _sortType,
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

  Future<void> _setSearchMode(SearchMode mode) async {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _results = [];
      _page = 1;
      _hasMore = true;
    });
    await _performSearch();
  }

  Future<void> _setSortType(String sortType) async {
    if (_sortType == sortType) return;
    setState(() {
      _sortType = sortType;
      _results = [];
      _page = 1;
      _hasMore = true;
    });
    await _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchHintText,
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color?.withValues(alpha: 0.7) ??
                  Theme.of(context).textTheme.titleLarge?.color?.withValues(alpha: 0.7),
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                Theme.of(context).textTheme.titleLarge?.color,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _handleSearchSubmit,
          autofocus: true,
        ),
        actions: [
          PopupMenuButton<SearchMode>(
            icon: Icon(
              _searchMode == SearchMode.keyword
                  ? Icons.text_fields
                  : Icons.label,
            ),
            tooltip: AppLocalizations.of(context).searchModeTooltip,
            onSelected: _setSearchMode,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SearchMode.keyword,
                child: Text(
                  AppLocalizations.of(context).searchKeywordModeLabel,
                ),
              ),
              PopupMenuItem(
                value: SearchMode.tag,
                child: Text(AppLocalizations.of(context).searchTagModeLabel),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: AppLocalizations.of(context).searchSortTooltip,
            onSelected: _setSortType,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rank',
                child: Text(AppLocalizations.of(context).searchSortRank),
              ),
              PopupMenuItem(
                value: 'match',
                child: Text(AppLocalizations.of(context).searchSortMatch),
              ),
              PopupMenuItem(
                value: 'heat',
                child: Text(AppLocalizations.of(context).searchSortHeat),
              ),
            ],
          ),
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
      return Center(child: Text(AppLocalizations.of(context).searchNoResults));
    }

    if (_currentKeyword.isEmpty) {
      return Center(
        child: Text(
          _searchMode == SearchMode.keyword
              ? AppLocalizations.of(context).searchEnterKeyword
              : AppLocalizations.of(context).searchEnterTag,
        ),
      );
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

              final heroTag = 'search_${anime.bangumiId}_$index';

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
                        heroTag: heroTag,
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

enum SearchMode { keyword, tag }

extension on SearchMode {
  Future<List<RankingAnime>> fetch({
    required String keyword,
    required String sortType,
    required int page,
  }) {
    switch (this) {
      case SearchMode.keyword:
        return searchBangumiSubject(
          keyword: keyword,
          sortType: sortType,
          page: page,
        );
      case SearchMode.tag:
        return fetchBangumiBrowser(
          sortType: sortType,
          year: '',
          tags: [keyword],
          page: page,
        );
    }
  }
}
