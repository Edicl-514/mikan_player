import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';

class TagBrowsePage extends StatefulWidget {
  final String tagName;

  const TagBrowsePage({super.key, required this.tagName});

  @override
  State<TagBrowsePage> createState() => _TagBrowsePageState();
}

class _TagBrowsePageState extends State<TagBrowsePage> {
  List<RankingAnime> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = createPlatformScrollController();

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
      _results = [];
      _page = 1;
      _hasMore = true;
    });

    try {
      final results = await CacheManager.instance.getBrowser(
        sortType: 'rank',
        year: '',
        tags: [widget.tagName],
        page: 1,
        fetchFromNetwork: () => fetchBangumiBrowser(
          sortType: 'rank',
          year: '',
          tags: [widget.tagName],
          page: 1,
        ),
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
        setState(() {
          _isLoading = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.loadFailed(e.toString()))));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final results = await CacheManager.instance.getBrowser(
        sortType: 'rank',
        year: '',
        tags: [widget.tagName],
        page: nextPage,
        fetchFromNetwork: () => fetchBangumiBrowser(
          sortType: 'rank',
          year: '',
          tags: [widget.tagName],
          page: nextPage,
        ),
      );
      if (mounted) {
        setState(() {
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            _results.addAll(results);
            _page = nextPage;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tagName),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _results.isEmpty) {
      return Center(child: Text(l10n.noRelatedAnime(widget.tagName)));
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
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _results.length) return null;
                final anime = _results[index];

                String cardTag = anime.rank != null ? '#${anime.rank}' : 'TV';
                final heroTag = 'tag_${widget.tagName}_${anime.bangumiId}_$index';

                return AnimeCard(
                  title: anime.title,
                  subtitle: anime.info,
                  tag: cardTag,
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
              },
              childCount: _results.length,
            ),
          ),
        ),
        if (_isLoadingMore)
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
