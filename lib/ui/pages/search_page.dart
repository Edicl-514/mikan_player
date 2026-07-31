import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as bangumi;
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
  late final PagedRequestController<SearchRequest, _SearchResult>
  _resultsController;
  String _currentKeyword = '';
  String _sortType = 'rank';
  SearchMode _searchMode = SearchMode.keyword;
  bool _initialQueryLoaded = false;
  BangumiRequestMode _requestMode = BangumiRequestMode.hybrid;
  final ScrollController _scrollController = createPlatformScrollController();

  List<_SearchResult> get _results => _resultsController.items;
  bool get _isLoading =>
      _resultsController.isLoading || _resultsController.isLoadingMore;

  @override
  void initState() {
    super.initState();
    _resultsController = PagedRequestController<SearchRequest, _SearchResult>(
      fetchPage: (request, page) {
        final fetchPage = widget.fetchPage;
        if (fetchPage != null && !request.mode.isCharacterOrPerson) {
          return fetchPage(
            request,
            page,
          ).then((items) => items.map(_SearchResult.subject).toList());
        }
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
    final nextSearchMode =
        mode == BangumiRequestMode.legacy && !_searchMode.isAvailableInLegacy
        ? SearchMode.keyword
        : _searchMode;
    final nextSortType = _defaultSortType(mode: mode);
    final shouldRefresh =
        _currentKeyword.isNotEmpty &&
        (_requestMode != mode ||
            _searchMode != nextSearchMode ||
            _sortType != nextSortType);

    setState(() {
      _requestMode = mode;
      _searchMode = nextSearchMode;
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
    if (_searchMode == mode || (_isLegacyMode && !mode.isAvailableInLegacy)) {
      return;
    }
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
    if (_searchMode.isCharacterOrPerson) return const [];

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
    final hintText = _searchHintText(l10n);

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
                        Theme.of(context).appBarTheme.titleTextStyle?.color
                            ?.withValues(alpha: 0.7) ??
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
                  icon: Icon(_searchMode.icon),
                  tooltip: AppLocalizations.of(context).searchModeTooltip,
                  onSelected: _setSearchMode,
                  itemBuilder: _buildSearchModeItems,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
              icon: Icon(_searchMode.icon),
              tooltip: AppLocalizations.of(context).searchModeTooltip,
              onSelected: _setSearchMode,
              itemBuilder: _buildSearchModeItems,
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

  List<PopupMenuEntry<SearchMode>> _buildSearchModeItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SearchMode.values
        .map(
          (mode) => PopupMenuItem<SearchMode>(
            value: mode,
            enabled: !_isLegacyMode || mode.isAvailableInLegacy,
            child: Row(
              children: [
                if (_searchMode == mode)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Text(_searchModeLabel(l10n, mode)),
              ],
            ),
          ),
        )
        .toList();
  }

  String _searchModeLabel(AppLocalizations l10n, SearchMode mode) {
    switch (mode) {
      case SearchMode.keyword:
        return l10n.searchKeywordModeLabel;
      case SearchMode.tag:
        return l10n.searchTagModeLabel;
      case SearchMode.character:
        return l10n.searchCharacterModeLabel;
      case SearchMode.person:
        return l10n.searchPersonModeLabel;
    }
  }

  String _searchHintText(AppLocalizations l10n) {
    switch (_searchMode) {
      case SearchMode.keyword:
        return l10n.searchHintText;
      case SearchMode.tag:
        return _isLegacyMode ? l10n.searchEnterTag : l10n.searchEnterTagsMulti;
      case SearchMode.character:
        return l10n.searchEnterCharacter;
      case SearchMode.person:
        return l10n.searchEnterPerson;
    }
  }

  String _searchEmptyMessage(AppLocalizations l10n) {
    switch (_searchMode) {
      case SearchMode.keyword:
        return l10n.searchEnterKeyword;
      case SearchMode.tag:
        return _isLegacyMode ? l10n.searchEnterTag : l10n.searchEnterTagsMulti;
      case SearchMode.character:
        return l10n.searchEnterCharacter;
      case SearchMode.person:
        return l10n.searchEnterPerson;
    }
  }

  Widget _buildResultCard(
    BuildContext context,
    _SearchResult result,
    int index,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (result.kind) {
      case _SearchResultKind.subject:
        final anime = result.anime!;
        final heroTag = 'search_${anime.bangumiId}_$index';
        final tag = anime.rank == null ? 'TV' : '#${anime.rank}';
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
      case _SearchResultKind.character:
        final character = result.character!;
        return AnimeCard(
          title: _displayName(character.nameCn, character.name),
          subtitle: _searchResultSubtitle(
            primaryName: character.nameCn,
            secondaryName: character.name,
            info: character.info,
          ),
          tag: l10n.searchCharacterModeLabel,
          coverUrl: _searchImageUrl(character.images),
          destination: WorkspaceDestinations.character(
            characterId: character.id,
            characterName: _displayName(character.nameCn, character.name),
            heroImageUrl: _searchImageUrl(character.images),
            enableHeroAnimation: false,
          ),
        );
      case _SearchResultKind.person:
        final person = result.person!;
        final info = person.career.isEmpty
            ? person.info
            : person.career.join(' / ');
        return AnimeCard(
          title: _displayName(person.nameCn, person.name),
          subtitle: _searchResultSubtitle(
            primaryName: person.nameCn,
            secondaryName: person.name,
            info: info,
          ),
          tag: l10n.searchPersonModeLabel,
          coverUrl: _searchImageUrl(person.images),
          destination: WorkspaceDestinations.person(
            personId: person.id,
            personName: _displayName(person.nameCn, person.name),
            heroImageUrl: _searchImageUrl(person.images),
            enableHeroAnimation: false,
          ),
        );
    }
  }

  String _displayName(String preferred, String fallback) =>
      preferred.trim().isNotEmpty ? preferred : fallback;

  String _searchResultSubtitle({
    required String primaryName,
    required String secondaryName,
    required String info,
  }) {
    final parts = <String>[];
    if (secondaryName.trim().isNotEmpty && secondaryName != primaryName) {
      parts.add(secondaryName);
    }
    if (info.trim().isNotEmpty) parts.add(info);
    return parts.join(' / ');
  }

  String? _searchImageUrl(bangumi.BangumiImages? images) {
    if (images == null) return null;
    for (final url in [
      images.medium,
      images.large,
      images.small,
      images.grid,
    ]) {
      if (url.isNotEmpty) return url;
    }
    return null;
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
        child: Text(_searchEmptyMessage(AppLocalizations.of(context))),
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
              return _buildResultCard(context, _results[index], index);
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

enum SearchMode { keyword, tag, character, person }

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
  bool get isAvailableInLegacy =>
      this == SearchMode.keyword || this == SearchMode.tag;

  bool get isCharacterOrPerson =>
      this == SearchMode.character || this == SearchMode.person;

  IconData get icon {
    switch (this) {
      case SearchMode.keyword:
        return Icons.text_fields;
      case SearchMode.tag:
        return Icons.label;
      case SearchMode.character:
        return Icons.face;
      case SearchMode.person:
        return Icons.person;
    }
  }

  Future<List<_SearchResult>> fetch({
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
        ).then((items) => items.map(_SearchResult.subject).toList());
      case SearchMode.tag:
        return searchBangumiTag(
          tag: keyword,
          sortType: sortType,
          page: page,
        ).then((items) => items.map(_SearchResult.subject).toList());
      case SearchMode.character:
        return bangumi
            .searchBangumiCharacters(keyword: keyword, page: page)
            .then((items) => items.map(_SearchResult.character).toList());
      case SearchMode.person:
        return bangumi
            .searchBangumiPersons(keyword: keyword, page: page)
            .then((items) => items.map(_SearchResult.person).toList());
    }
  }
}

enum _SearchResultKind { subject, character, person }

class _SearchResult {
  const _SearchResult._({
    required this.kind,
    this.anime,
    this.character,
    this.person,
  });

  factory _SearchResult.subject(RankingAnime anime) =>
      _SearchResult._(kind: _SearchResultKind.subject, anime: anime);

  factory _SearchResult.character(bangumi.BangumiCharacterSearchResult item) =>
      _SearchResult._(kind: _SearchResultKind.character, character: item);

  factory _SearchResult.person(bangumi.BangumiPersonSearchResult item) =>
      _SearchResult._(kind: _SearchResultKind.person, person: item);

  final _SearchResultKind kind;
  final RankingAnime? anime;
  final bangumi.BangumiCharacterSearchResult? character;
  final bangumi.BangumiPersonSearchResult? person;
}

class _SearchSortOption {
  final String value;
  final String label;

  const _SearchSortOption(this.value, this.label);
}
