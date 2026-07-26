import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';

typedef SearchPageFetcher =
    Future<List<RankingAnime>> Function(SearchRequest request, int page);

class SearchPage extends StatefulWidget {
  final String? initialKeyword;
  final String? initialTag;
  final bool autofocus;
  final SearchPageFetcher? fetchPage;

  const SearchPage({
    super.key,
    this.initialKeyword,
    this.initialTag,
    bool? autofocus,
    this.fetchPage,
  }) : autofocus = autofocus ?? (initialKeyword == null && initialTag == null);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  late final PagedRequestController<SearchRequest, RankingAnime>
  _resultsController;
  String _currentKeyword = '';
  String _sortType = 'rank';
  SearchMode _searchMode = SearchMode.keyword;
  bool _initialQueryLoaded = false;
  BangumiRequestMode _requestMode = BangumiRequestMode.hybrid;
  final ScrollController _scrollController = createPlatformScrollController();

  List<RankingAnime> get _results => _resultsController.items;
  bool get _isLoading =>
      _resultsController.isLoading || _resultsController.isLoadingMore;

  @override
  void initState() {
    super.initState();
    _resultsController = PagedRequestController<SearchRequest, RankingAnime>(
      fetchPage: (request, page) {
        final fetchPage = widget.fetchPage;
        if (fetchPage != null) return fetchPage(request, page);
        return request.mode.fetch(
          keyword: request.keyword,
          sortType: request.sortType,
          page: page,
        );
      },
    )..addListener(_onResultsChanged);
    if (widget.initialTag != null) {
      _searchMode = SearchMode.tag;
      _searchController.text = widget.initialTag!;
      _currentKeyword = widget.initialTag!;
    } else if (widget.initialKeyword != null) {
      _searchMode = SearchMode.keyword;
      _searchController.text = widget.initialKeyword!;
      _currentKeyword = widget.initialKeyword!;
    }
    BangumiRequestModeService.load().then((mode) {
      if (!mounted) return;
      _applyRequestMode(mode);
    });
    BangumiRequestModeService.notifier.addListener(_handleRequestModeChanged);
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
    BangumiRequestModeService.notifier.removeListener(
      _handleRequestModeChanged,
    );
    _searchController.dispose();
    _scrollController.dispose();
    _resultsController.dispose();
    super.dispose();
  }

  void _onResultsChanged() {
    if (mounted) setState(() {});
  }

  void _handleRequestModeChanged() {
    if (!mounted) return;
    _applyRequestMode(BangumiRequestModeService.notifier.value);
  }

  void _applyRequestMode(BangumiRequestMode mode) {
    final nextSortType = _defaultSortType(mode: mode);
    final shouldRefresh =
        _currentKeyword.isNotEmpty &&
        (_requestMode != mode || _sortType != nextSortType);

    setState(() {
      _requestMode = mode;
      _sortType = nextSortType;
    });

    if (shouldRefresh) {
      _performSearch();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _performSearch() async {
    if (_currentKeyword.isEmpty) return;

    final result = await _resultsController.refresh(
      SearchRequest(
        keyword: _currentKeyword,
        sortType: _sortType,
        mode: _searchMode,
      ),
    );
    if (mounted && result.committed && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).searchFailed(result.error.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _loadMore() async {
    await _resultsController.loadMore();
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
      _sortType = _defaultSortType();
    });
    await _performSearch();
  }

  Future<void> _setSortType(String sortType) async {
    if (_sortType == sortType) return;
    setState(() {
      _sortType = sortType;
    });
    await _performSearch();
  }

  bool get _isLegacyMode => _requestMode == BangumiRequestMode.legacy;

  String _defaultSortType({BangumiRequestMode? mode}) {
    final requestMode = mode ?? _requestMode;
    if (_searchMode == SearchMode.tag) {
      return requestMode == BangumiRequestMode.legacy ? 'rank' : 'rank';
    }
    return requestMode == BangumiRequestMode.legacy ? 'rank' : 'rank';
  }

  List<_SearchSortOption> _buildSortOptions(AppLocalizations l10n) {
    if (_searchMode == SearchMode.keyword && _isLegacyMode) {
      return const [];
    }

    if (_searchMode == SearchMode.tag && _isLegacyMode) {
      return [
        _SearchSortOption('rank', l10n.searchSortRank),
        _SearchSortOption('collects', l10n.searchSortHeat),
        _SearchSortOption('date', l10n.searchSortDate),
        _SearchSortOption('title', l10n.searchSortTitle),
      ];
    }

    return [
      _SearchSortOption('rank', l10n.searchSortRank),
      _SearchSortOption('match', l10n.searchSortMatch),
      _SearchSortOption('heat', l10n.searchSortHeat),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sortOptions = _buildSortOptions(l10n);
    final effectiveSortType =
        sortOptions.any((option) => option.value == _sortType)
        ? _sortType
        : (sortOptions.isEmpty ? _sortType : sortOptions.first.value);

    final isHosted = DesktopPageChromeScope.hostsPageHeader(context);
    final hintText = _searchMode == SearchMode.keyword
        ? AppLocalizations.of(context).searchHintText
        : (_isLegacyMode
              ? AppLocalizations.of(context).searchEnterTag
              : AppLocalizations.of(context).searchEnterTagsMulti);

    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: _handleSearchSubmit,
      autofocus: widget.autofocus && !isHosted,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: isHosted
          ? null
          : AppBar(
              title: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color:
                        Theme.of(
                          context,
                        ).appBarTheme.titleTextStyle?.color?.withValues(
                          alpha: 0.7,
                        ) ??
                        Theme.of(
                          context,
                        ).textTheme.titleLarge?.color?.withValues(alpha: 0.7),
                  ),
                ),
                style: TextStyle(
                  color:
                      Theme.of(context).appBarTheme.titleTextStyle?.color ??
                      Theme.of(context).textTheme.titleLarge?.color,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSearchSubmit,
                autofocus: widget.autofocus,
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
                      child: Row(
                        children: [
                          if (_searchMode == SearchMode.keyword)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).searchKeywordModeLabel,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: SearchMode.tag,
                      child: Row(
                        children: [
                          if (_searchMode == SearchMode.tag)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 12),
                          Text(AppLocalizations.of(context).searchTagModeLabel),
                        ],
                      ),
                    ),
                  ],
                ),
                if (sortOptions.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    tooltip: l10n.searchSortTooltip,
                    onSelected: (value) async {
                      if (value == effectiveSortType) return;
                      await _setSortType(value);
                    },
                    itemBuilder: (context) => sortOptions
                        .map(
                          (option) => PopupMenuItem(
                            value: option.value,
                            child: Row(
                              children: [
                                if (option.value == effectiveSortType)
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 12),
                                Text(option.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: AppLocalizations.of(context).searchHint,
                  onPressed: () => _handleSearchSubmit(_searchController.text),
                ),
              ],
            ),
      body: isHosted
          ? Column(
              children: [
                _buildHostedCommandRow(
                  context: context,
                  searchField: searchField,
                  sortOptions: sortOptions,
                  effectiveSortType: effectiveSortType,
                ),
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
    );
  }

  Widget _buildHostedCommandRow({
    required BuildContext context,
    required Widget searchField,
    required List<_SearchSortOption> sortOptions,
    required String effectiveSortType,
  }) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
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
                  child: Row(
                    children: [
                      if (_searchMode == SearchMode.keyword)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).searchKeywordModeLabel),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SearchMode.tag,
                  child: Row(
                    children: [
                      if (_searchMode == SearchMode.tag)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).searchTagModeLabel),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(child: searchField),
            const SizedBox(width: 8),
            if (sortOptions.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: l10n.searchSortTooltip,
                onSelected: (value) async {
                  if (value == effectiveSortType) return;
                  await _setSortType(value);
                },
                itemBuilder: (context) => sortOptions
                    .map(
                      (option) => PopupMenuItem(
                        value: option.value,
                        child: Row(
                          children: [
                            if (option.value == effectiveSortType)
                              Icon(
                                Icons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 12),
                            Text(option.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: AppLocalizations.of(context).searchHint,
              onPressed: () => _handleSearchSubmit(_searchController.text),
            ),
          ],
        ),
      ),
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
              : (_isLegacyMode
                    ? AppLocalizations.of(context).searchEnterTag
                    : AppLocalizations.of(context).searchEnterTagsMulti),
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
                destination: WorkspaceDestinations.bangumiDetails(
                  anime: crawler.AnimeInfo(
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
                  ),
                  heroTag: heroTag,
                ),
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

class SearchRequest {
  const SearchRequest({
    required this.keyword,
    required this.sortType,
    required this.mode,
  });

  final String keyword;
  final String sortType;
  final SearchMode mode;
}

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
        return searchBangumiTag(tag: keyword, sortType: sortType, page: page);
    }
  }
}

class _SearchSortOption {
  final String value;
  final String label;

  const _SearchSortOption(this.value, this.label);
}
