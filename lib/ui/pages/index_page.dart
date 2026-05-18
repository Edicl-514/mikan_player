import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final Map<String, String> _selections = {
    '分类': '全部',
    '来源': '全部',
    '类型': '全部',
    '地区': '全部',
    '时间': '不限',
    '月份': '全部',
    '排序': '排名',
  };

  final Map<String, List<String>> _filterData = {
    '分类': ['全部', 'TV', 'WEB', 'OVA', '剧场版', '动态漫画', '其他'],
    '来源': ['全部', '原创', '漫画改', '游戏改', '小说改', '影视改'],
    '类型': [
      '全部',
      '科幻',
      '喜剧',
      '同人',
      '百合',
      '校园',
      '惊悚',
      '后宫',
      '机战',
      '悬疑',
      '恋爱',
      '奇幻',
      '推理',
      '运动',
      '耽美',
      '音乐',
      '战斗',
      '冒险',
      '萌系',
      '穿越',
      '玄幻',
      '乙女',
      '恐怖',
      '历史',
      '日常',
      '剧情',
      '武侠',
      '美食',
      '职场',
    ],
    '地区': [
      '全部',
      '日本',
      '欧美',
      '中国',
      '美国',
      '韩国',
      '法国',
      '中国香港',
      '英国',
      '俄罗斯',
      '苏联',
      '捷克',
      '中国台湾',
      '马来西亚',
    ],
    '时间': [
      '不限',
      '2026',
      '2025',
      '2024',
      '2023',
      '2022',
      '2021',
      '2020',
      '2019',
      '2018',
      '2017',
      '2016',
      '2015',
      '2014',
      '2013',
      '2012',
      '2011',
      '2010',
      '2009',
      '2008',
      '2007',
      '2006',
      '2005',
      '2004',
      '2003',
      '2002',
      '2001',
      '2000',
    ],
    '月份': [
      '全部',
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ],
    '排序': ['排名', '相关度', '收藏数'],
  };

  List<RankingAnime> _animes = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  int _currentFetchId = 0;
  final ScrollController _scrollController = createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _fetchAnimes();
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
      _fetchAnimes(loadMore: true);
    }
  }

  Future<void> _fetchAnimes({bool loadMore = false}) async {
    if (loadMore && (_isLoading || !_hasMore)) return;

    final fetchId = ++_currentFetchId;

    setState(() {
      _isLoading = true;
    });

    try {
      final String sortLabel = _selections['排序'] ?? '排名';
      String sortType;
      switch (sortLabel) {
        case '排名':
          sortType = 'rank';
          break;
        case '相关度':
          sortType = 'match';
          break;
        case '收藏数':
          sortType = 'heat';
          break;
        default:
          sortType = 'rank';
      }

      final String selectedYear = _selections['时间'] ?? '不限';
      final String selectedMonth = _selections['月份'] ?? '全部';
      final String? normalizedMonth = _normalizeMonthValue(selectedMonth);
      final String year = selectedYear == '不限'
          ? ''
          : normalizedMonth == null
          ? selectedYear
          : '$selectedYear-$normalizedMonth';

      final List<String> tags = [];
      _selections.forEach((key, value) {
        if (key != '时间' &&
            key != '月份' &&
            key != '排序' &&
            value != '全部' &&
            value != '不限') {
          if (key == '分类') {
            if (value == 'TV') {
              tags.add('tv');
            } else if (value == 'WEB') {
              tags.add('web');
            } else if (value == 'OVA') {
              tags.add('ova');
            } else if (value == '剧场版') {
              tags.add('movie');
            } else {
              tags.add(value);
            }
          } else {
            tags.add(value);
          }
        }
      });

      final int targetPage = loadMore ? _page + 1 : 1;

      // 使用缓存管理器获取数据
      final results = await CacheManager.instance.getBrowser(
        sortType: sortType,
        year: year,
        tags: tags,
        page: targetPage,
        fetchFromNetwork: () => fetchBangumiBrowser(
          sortType: sortType,
          year: year,
          tags: tags,
          page: targetPage,
        ),
      );

      if (mounted && fetchId == _currentFetchId) {
        setState(() {
          if (loadMore) {
            _animes.addAll(results);
          } else {
            _animes = results;
          }
          _page = targetPage;
          _hasMore = results.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error fetching animes: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.loadFailed(e.toString()))));
      }
    } finally {
      if (mounted && fetchId == _currentFetchId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _normalizeMonthValue(String monthLabel) {
    if (monthLabel == '全部' || monthLabel == '不限') return null;

    final monthMatch = RegExp(r'^(\d{1,2})月$').firstMatch(monthLabel);
    if (monthMatch == null) return null;

    final month = int.tryParse(monthMatch.group(1)!);
    if (month == null || month < 1 || month > 12) return null;

    return month.toString().padLeft(2, '0');
  }

  void _onSelectionChanged(String label, String value) {
    if (_selections[label] == value) return;
    setState(() {
      _selections[label] = value;
      if (label == '时间') {
        _selections['月份'] = '全部';
      }
      _animes = []; // 清空列表，显示加载动画
      _page = 1;
      _hasMore = true;
      _isLoading = true;
    });
    _fetchAnimes();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool showMonthFilter = (_selections['时间'] ?? '不限') != '不限';

    Widget body = CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in _filterData.entries) ...[
                  if (entry.key != '月份')
                    _buildFilterRow(context, entry.key, entry.value),
                  if (entry.key == '时间' && showMonthFilter)
                    _buildFilterRow(
                      context,
                      '月份',
                      _filterData['月份'] ?? const ['全部'],
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_isLoading && _animes.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else
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
                if (index >= _animes.length) return null;
                final anime = _animes[index];

                String tag = 'TV';
                if (anime.rank != null) {
                  tag = '#${anime.rank}';
                }

                final heroTag =
                    'index_cover_${anime.bangumiId.isNotEmpty ? anime.bangumiId : anime.title.hashCode}';

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
                          heroTag:
                              'index_cover_${animeInfo.bangumiId ?? animeInfo.mikanId ?? animeInfo.title.hashCode}',
                        ),
                      ),
                    );
                  },
                );
              }, childCount: _animes.length),
            ),
          ),
        if (_isLoading && _animes.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );

    if (isMobile) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).navIndex,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.searchHint,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildFilterRow(
    BuildContext context,
    String label,
    List<String> options,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final chips = options.map((option) {
      final isSelected = _selections[label] == option;
      final chip = FilterChip(
        showCheckmark: false,
        label: Text(option),
        selected: isSelected,
        onSelected: (bool value) {
          if (value) {
            _onSelectionChanged(label, option);
          }
        },
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.zero,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : null,
        ),
        selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

      if (isMobile) {
        return Padding(padding: const EdgeInsets.only(right: 4.0), child: chip);
      }
      return chip;
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: isMobile
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 32,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: chips),
                  )
                : Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: chips,
                  ),
          ),
        ],
      ),
    );
  }
}
