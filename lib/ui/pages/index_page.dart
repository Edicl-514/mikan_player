import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/pages/index_filter_labels.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/desktop_page_scaffold.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  BangumiRequestMode _requestMode = BangumiRequestMode.hybrid;
  // Protocol tokens for filter state / Bangumi tags — display via
  // [indexFilterLabel].
  // i18n-ignore: protocol filter state tokens used for matching/API
  final Map<String, String> _selections = {
    indexFilterKeyCategory: indexFilterAll,
    indexFilterKeySource: indexFilterAll,
    indexFilterKeyType: indexFilterAll,
    indexFilterKeyRegion: indexFilterAll,
    // i18n-ignore: protocol filter/API token used for matching/state
    indexFilterKeySort: '排名',
  };
  final Set<String> _selectedTypeTags = <String>{};
  // i18n-ignore: protocol filter option token used for matching/state
  String _selectedYear = indexFilterUnlimited;
  // i18n-ignore: protocol filter option token used for matching/state
  String _selectedMonth = indexFilterAll;
  _YearMonthFilterValue? _rangeStart;
  _YearMonthFilterValue? _rangeEnd;
  bool _timePanelOpen = false;
  _TimePanelMode _timePanelMode = _TimePanelMode.point;

  // i18n-ignore: protocol filter option tokens used for matching/API
  final Map<String, List<String>> _filterData = {
    // i18n-ignore: protocol filter/API token used for matching/state
    indexFilterKeyCategory: [indexFilterAll, 'TV', 'WEB', 'OVA', '剧场版', '其他'],
    // i18n-ignore: protocol filter/API token used for matching/state
    indexFilterKeySource: [indexFilterAll, '原创', '漫画改', '游戏改', '小说改', '影视改'],
    indexFilterKeyType: [
      indexFilterAll,
      // i18n-ignore: protocol filter/API token used for matching/state
      '科幻',
      // i18n-ignore: protocol filter/API token used for matching/state
      '喜剧',
      // i18n-ignore: protocol filter/API token used for matching/state
      '同人',
      // i18n-ignore: protocol filter/API token used for matching/state
      '百合',
      // i18n-ignore: protocol filter/API token used for matching/state
      '校园',
      // i18n-ignore: protocol filter/API token used for matching/state
      '惊悚',
      // i18n-ignore: protocol filter/API token used for matching/state
      '后宫',
      // i18n-ignore: protocol filter/API token used for matching/state
      '机战',
      // i18n-ignore: protocol filter/API token used for matching/state
      '悬疑',
      // i18n-ignore: protocol filter/API token used for matching/state
      '恋爱',
      // i18n-ignore: protocol filter/API token used for matching/state
      '奇幻',
      // i18n-ignore: protocol filter/API token used for matching/state
      '推理',
      // i18n-ignore: protocol filter/API token used for matching/state
      '运动',
      // i18n-ignore: protocol filter/API token used for matching/state
      '耽美',
      // i18n-ignore: protocol filter/API token used for matching/state
      '音乐',
      // i18n-ignore: protocol filter/API token used for matching/state
      '战斗',
      // i18n-ignore: protocol filter/API token used for matching/state
      '冒险',
      // i18n-ignore: protocol filter/API token used for matching/state
      '萌系',
      // i18n-ignore: protocol filter/API token used for matching/state
      '穿越',
      // i18n-ignore: protocol filter/API token used for matching/state
      '玄幻',
      // i18n-ignore: protocol filter/API token used for matching/state
      '乙女',
      // i18n-ignore: protocol filter/API token used for matching/state
      '恐怖',
      // i18n-ignore: protocol filter/API token used for matching/state
      '历史',
      // i18n-ignore: protocol filter/API token used for matching/state
      '日常',
      // i18n-ignore: protocol filter/API token used for matching/state
      '剧情',
      // i18n-ignore: protocol filter/API token used for matching/state
      '武侠',
      // i18n-ignore: protocol filter/API token used for matching/state
      '美食',
      // i18n-ignore: protocol filter/API token used for matching/state
      '职场',
    ],
    indexFilterKeyRegion: [
      indexFilterAll,
      // i18n-ignore: protocol filter/API token used for matching/state
      '日本',
      // i18n-ignore: protocol filter/API token used for matching/state
      '欧美',
      // i18n-ignore: protocol filter/API token used for matching/state
      '中国',
      // i18n-ignore: protocol filter/API token used for matching/state
      '美国',
      // i18n-ignore: protocol filter/API token used for matching/state
      '韩国',
      // i18n-ignore: protocol filter/API token used for matching/state
      '法国',
      // i18n-ignore: protocol filter/API token used for matching/state
      '中国香港',
      // i18n-ignore: protocol filter/API token used for matching/state
      '英国',
      // i18n-ignore: protocol filter/API token used for matching/state
      '俄罗斯',
      // i18n-ignore: protocol filter/API token used for matching/state
      '苏联',
      // i18n-ignore: protocol filter/API token used for matching/state
      '捷克',
      // i18n-ignore: protocol filter/API token used for matching/state
      '中国台湾',
      // i18n-ignore: protocol filter/API token used for matching/state
      '马来西亚',
    ],
    // i18n-ignore: protocol sort tokens used for matching/state
    indexFilterKeySort: ['排名', '相关度', '收藏数'],
  };

  // i18n-ignore: protocol year filter option tokens used for matching/state
  static const List<String> _yearOptions = [
    indexFilterUnlimited,
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
  ];

  // i18n-ignore: protocol month filter option tokens used for matching/state
  static const List<String> _monthOptions = [
    indexFilterAll,
    // i18n-ignore: protocol filter/API token used for matching/state
    '1月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '2月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '3月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '4月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '5月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '6月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '7月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '8月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '9月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '10月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '11月',
    // i18n-ignore: protocol filter/API token used for matching/state
    '12月',
  ];

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
    BangumiRequestModeService.load().then((mode) {
      if (!mounted) return;
      final shouldRefresh = _requestMode != mode;
      setState(() {
        _syncFilterStateForModeChange(_requestMode, mode);
        _requestMode = mode;
        _ensureValidSortSelection();
      });
      if (shouldRefresh) {
        _fetchAnimes();
      }
    });
    BangumiRequestModeService.notifier.addListener(_handleRequestModeChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    BangumiRequestModeService.notifier.removeListener(
      _handleRequestModeChanged,
    );
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRequestModeChanged() {
    final mode = BangumiRequestModeService.notifier.value;
    if (!mounted || _requestMode == mode) return;

    setState(() {
      _syncFilterStateForModeChange(_requestMode, mode);
      _requestMode = mode;
      _ensureValidSortSelection();
      _animes = [];
      _page = 1;
      _hasMore = true;
    });
    _fetchAnimes();
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
      // i18n-ignore: protocol filter/API token used for matching/state
      final String sortLabel = _selections[indexFilterKeySort] ?? '排名';
      String sortType;
      switch (sortLabel) {
        // i18n-ignore: protocol filter/API token used for matching/state
        case '排名':
          sortType = 'rank';
          break;
        // i18n-ignore: protocol filter/API token used for matching/state
        case '热度':
          sortType = 'trends';
          break;
        // i18n-ignore: protocol filter/API token used for matching/state
        case '收藏':
        // i18n-ignore: protocol filter/API token used for matching/state
        case '收藏数':
          sortType = _isLegacyMode ? 'collects' : 'heat';
          break;
        // i18n-ignore: protocol filter/API token used for matching/state
        case '日期':
          sortType = 'date';
          break;
        // i18n-ignore: protocol filter/API token used for matching/state
        case '名称':
          sortType = 'title';
          break;
        // i18n-ignore: protocol filter/API token used for matching/state
        case '相关度':
          sortType = 'match';
          break;
        default:
          sortType = 'rank';
      }

      final String year = _supportsAdvancedBrowserFilters
          ? _encodeSelectedRange()
          : _encodeLegacyYearFilter();

      final List<String> tags = <String>[];
      _selections.forEach((key, value) {
        if (key != indexFilterKeyType &&
            key != indexFilterKeySort &&
            value != indexFilterAll &&
            value != indexFilterUnlimited) {
          if (key == indexFilterKeyCategory) {
            if (value == 'TV') {
              _addUniqueTag(tags, 'tv');
            } else if (value == 'WEB') {
              _addUniqueTag(tags, 'web');
            } else if (value == 'OVA') {
              _addUniqueTag(tags, 'ova');
              // i18n-ignore: protocol filter/API token used for matching/state
            } else if (value == '剧场版') {
              _addUniqueTag(tags, 'movie');
            } else {
              _addUniqueTag(tags, value);
            }
          } else {
            _addUniqueTag(tags, value);
          }
        }
      });
      for (final typeTag in _resolvedTypeTags()) {
        _addUniqueTag(tags, typeTag);
      }

      final int targetPage = loadMore ? _page + 1 : 1;

      // i18n-ignore: protocol filter/API token used for matching/state
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
      if (mounted && fetchId == _currentFetchId) {
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
    if (monthLabel == indexFilterAll || monthLabel == indexFilterUnlimited) {
      return null;
    }

    // i18n-ignore: protocol filter/API token used for matching/state
    final monthMatch = RegExp(r'^(\d{1,2})月$').firstMatch(monthLabel);
    if (monthMatch == null) return null;

    final month = int.tryParse(monthMatch.group(1)!);
    if (month == null || month < 1 || month > 12) return null;

    return month.toString().padLeft(2, '0');
  }

  bool get _isLegacyMode => _requestMode == BangumiRequestMode.legacy;
  bool get _supportsAdvancedBrowserFilters => !_isLegacyMode;

  // i18n-ignore: protocol sort option tokens used for matching/state
  List<String> _sortOptions() {
    if (_isLegacyMode) {
      // i18n-ignore: protocol filter/API token used for matching/state
      return ['排名', '热度', '收藏', '日期', '名称'];
    }
    // i18n-ignore: protocol filter/API token used for matching/state
    return ['排名', '相关度', '收藏数'];
  }

  void _ensureValidSortSelection() {
    final options = _sortOptions();
    final current = _selections[indexFilterKeySort];
    if (current == null || !options.contains(current)) {
      _selections[indexFilterKeySort] = options.first;
    }
  }

  void _syncFilterStateForModeChange(
    BangumiRequestMode previous,
    BangumiRequestMode next,
  ) {
    if (previous == next) return;

    if (previous == BangumiRequestMode.legacy &&
        next != BangumiRequestMode.legacy) {
      final selectedType = _selections[indexFilterKeyType];
      _selectedTypeTags
        ..clear()
        ..addAll(
          selectedType != null && selectedType != indexFilterAll
              ? [selectedType]
              : const [],
        );

      final legacyYear = _selectedYear;
      final legacyMonth = _normalizeMonthValue(_selectedMonth);
      if (legacyYear != indexFilterUnlimited) {
        final yearValue = int.tryParse(legacyYear);
        if (yearValue != null) {
          if (legacyMonth != null) {
            final monthValue = int.tryParse(legacyMonth);
            if (monthValue != null) {
              _rangeStart = _YearMonthFilterValue(yearValue, monthValue);
              _rangeEnd = _YearMonthFilterValue(yearValue, monthValue);
            }
          } else {
            _rangeStart = _YearMonthFilterValue(yearValue, 1);
            _rangeEnd = _YearMonthFilterValue(yearValue, 12);
          }
        }
      } else {
        _rangeStart = null;
        _rangeEnd = null;
      }
      return;
    }

    if (previous != BangumiRequestMode.legacy &&
        next == BangumiRequestMode.legacy) {
      final orderedTags = _orderedSelectedTypeTags();
      _selections[indexFilterKeyType] = orderedTags.isEmpty
          ? indexFilterAll
          : orderedTags.first;

      _timePanelOpen = false;
      _timePanelMode = _TimePanelMode.point;
      if (_rangeStart != null &&
          _rangeEnd != null &&
          _rangeStart!.year == _rangeEnd!.year) {
        _selectedYear = _rangeStart!.year.toString();
        _selectedMonth = _rangeStart == _rangeEnd
            // i18n-ignore: protocol filter/API token used for matching/state
            ? '${_rangeStart!.month}月'
            : indexFilterAll;
      } else {
        _selectedYear = indexFilterUnlimited;
        _selectedMonth = indexFilterAll;
      }
    }
  }

  String _encodeLegacyYearFilter() {
    final String? normalizedMonth = _normalizeMonthValue(_selectedMonth);
    return _selectedYear == indexFilterUnlimited
        ? ''
        : normalizedMonth == null
        ? _selectedYear
        : '$_selectedYear-$normalizedMonth';
  }

  String _encodeSelectedRange() {
    if (_rangeStart == null || _rangeEnd == null) {
      return '';
    }
    return '${_rangeStart!.apiValue}..${_rangeEnd!.apiValue}';
  }

  List<String> _resolvedTypeTags() {
    if (_supportsAdvancedBrowserFilters) {
      return _orderedSelectedTypeTags();
    }

    final selectedType = _selections[indexFilterKeyType];
    if (selectedType == null || selectedType == indexFilterAll) {
      return const [];
    }
    return [selectedType];
  }

  List<String> _orderedSelectedTypeTags() {
    final options = _filterData[indexFilterKeyType] ?? const <String>[];
    return options
        .where(
          (option) =>
              option != indexFilterAll && _selectedTypeTags.contains(option),
        )
        .toList();
  }

  void _addUniqueTag(List<String> tags, String value) {
    if (value.isEmpty || tags.contains(value)) return;
    tags.add(value);
  }

  void _prepareForRefresh() {
    _animes = [];
    _page = 1;
    _hasMore = true;
    _isLoading = true;
  }

  void _onSelectionChanged(String label, String value) {
    if (_selections[label] == value) return;
    setState(() {
      _selections[label] = value;
      _prepareForRefresh();
    });
    _fetchAnimes();
  }

  void _onTimePanelYearSelected(String value) {
    if (_selectedYear == value) {
      return;
    }

    if (value == indexFilterUnlimited) {
      setState(() {
        _selectedYear = indexFilterUnlimited;
        _selectedMonth = indexFilterAll;
        _rangeStart = null;
        _rangeEnd = null;
        _prepareForRefresh();
      });
      _fetchAnimes();
      return;
    }

    if (_timePanelMode == _TimePanelMode.range &&
        _supportsAdvancedBrowserFilters) {
      setState(() {
        _selectedYear = value;
        _selectedMonth = indexFilterAll;
        final year = int.tryParse(value);
        if (year != null) {
          _applyAdvancedTimePoint(_YearMonthFilterValue(year, 1));
          _prepareForRefresh();
        }
      });
      _fetchAnimes();
      return;
    }

    setState(() {
      _selectedYear = value;
      _selectedMonth = indexFilterAll;
      _syncRangeFromPointSelection();
      _prepareForRefresh();
    });
    _fetchAnimes();
  }

  void _onTimePanelMonthSelected(String value) {
    if (_selectedYear == indexFilterUnlimited && value != indexFilterAll) {
      return;
    }

    if (_timePanelMode == _TimePanelMode.range &&
        _supportsAdvancedBrowserFilters) {
      if (value == indexFilterAll) {
        if (_selectedYear != indexFilterUnlimited) {
          _onTimePanelYearSelected(_selectedYear);
        }
        return;
      }

      final year = int.tryParse(_selectedYear);
      final month = int.tryParse(_normalizeMonthValue(value) ?? '');
      if (year == null || month == null) return;

      setState(() {
        _selectedMonth = value;
        _applyAdvancedTimePoint(_YearMonthFilterValue(year, month));
        _prepareForRefresh();
      });
      _fetchAnimes();
      return;
    }

    if (value == indexFilterAll) {
      if (_selectedMonth == indexFilterAll) return;
      setState(() {
        _selectedMonth = indexFilterAll;
        _syncRangeFromPointSelection();
        _prepareForRefresh();
      });
      _fetchAnimes();
      return;
    }

    final year = int.tryParse(_selectedYear);
    final month = int.tryParse(_normalizeMonthValue(value) ?? '');
    if (year == null || month == null) return;

    setState(() {
      _selectedMonth = value;
      _syncRangeFromPointSelection();
      _prepareForRefresh();
    });
    _fetchAnimes();
  }

  void _syncRangeFromPointSelection() {
    if (!_supportsAdvancedBrowserFilters) return;

    if (_selectedYear == indexFilterUnlimited) {
      _rangeStart = null;
      _rangeEnd = null;
      return;
    }

    final year = int.tryParse(_selectedYear);
    if (year == null) {
      _rangeStart = null;
      _rangeEnd = null;
      return;
    }

    final normalizedMonth = _normalizeMonthValue(_selectedMonth);
    if (normalizedMonth != null) {
      final month = int.tryParse(normalizedMonth);
      if (month != null) {
        _rangeStart = _YearMonthFilterValue(year, month);
        _rangeEnd = _YearMonthFilterValue(year, month);
        return;
      }
    }

    _rangeStart = _YearMonthFilterValue(year, 1);
    _rangeEnd = _YearMonthFilterValue(year, 12);
  }

  void _applyAdvancedTimePoint(_YearMonthFilterValue point) {
    if (_rangeStart == null || _rangeEnd == null) {
      _rangeStart = point;
      _rangeEnd = point;
      return;
    }

    final start = _rangeStart!;
    final end = _rangeEnd!;

    if (point.compareTo(start) < 0) {
      _rangeStart = point;
      return;
    }

    if (point.compareTo(end) > 0) {
      _rangeEnd = point;
      return;
    }

    final startDistance = (point.serializedIndex - start.serializedIndex).abs();
    final endDistance = (end.serializedIndex - point.serializedIndex).abs();

    if (startDistance <= endDistance) {
      _rangeStart = point;
    } else {
      _rangeEnd = point;
    }
  }

  void _onTypeTagToggled(String value) {
    final nextSelected = Set<String>.from(_selectedTypeTags);
    if (value == indexFilterAll) {
      if (nextSelected.isEmpty) return;
      nextSelected.clear();
    } else {
      if (nextSelected.contains(value)) {
        nextSelected.remove(value);
      } else {
        nextSelected.add(value);
      }
    }

    setState(() {
      _selectedTypeTags
        ..clear()
        ..addAll(nextSelected);
      _prepareForRefresh();
    });
    _fetchAnimes();
  }

  String _rangeSummaryText(AppLocalizations l10n) {
    if (_rangeStart == null || _rangeEnd == null) {
      return l10n.indexDateRangeUnset;
    }
    return '${_rangeStart!.displayLabel} - ${_rangeEnd!.displayLabel}';
  }

  ({bool isSelected, bool isInRange, bool isBoundary}) _chipHighlightState(
    String label,
    String option,
  ) {
    final isSelected = label == '__time__'
        ? _selectedYear == option
        : label == '__month__'
        ? _selectedMonth == option
        : _selections[label] == option;

    if (!_supportsAdvancedBrowserFilters ||
        (_rangeStart == null && _rangeEnd == null)) {
      return (isSelected: isSelected, isInRange: false, isBoundary: false);
    }

    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) {
      return (isSelected: isSelected, isInRange: false, isBoundary: false);
    }

    if (label == '__time__') {
      final year = int.tryParse(option);
      if (year == null) {
        return (isSelected: isSelected, isInRange: false, isBoundary: false);
      }

      final isInRange = year >= start.year && year <= end.year;
      final isBoundary = year == start.year || year == end.year;
      return (
        isSelected: isSelected,
        isInRange: isInRange,
        isBoundary: isBoundary,
      );
    }

    if (label == '__month__') {
      final selectedYear = int.tryParse(_selectedYear);
      final month = int.tryParse(_normalizeMonthValue(option) ?? '');
      if (selectedYear == null || month == null) {
        return (isSelected: isSelected, isInRange: false, isBoundary: false);
      }

      if (selectedYear < start.year || selectedYear > end.year) {
        return (isSelected: isSelected, isInRange: false, isBoundary: false);
      }

      if (start.year == end.year) {
        final isInRange = month >= start.month && month <= end.month;
        final isBoundary = month == start.month || month == end.month;
        return (
          isSelected: isSelected,
          isInRange: isInRange,
          isBoundary: isBoundary,
        );
      }

      if (selectedYear == start.year) {
        return (
          isSelected: isSelected,
          isInRange: month >= start.month,
          isBoundary: month == start.month,
        );
      }

      if (selectedYear == end.year) {
        return (
          isSelected: isSelected,
          isInRange: month <= end.month,
          isBoundary: month == end.month,
        );
      }

      return (isSelected: isSelected, isInRange: true, isBoundary: false);
    }

    return (isSelected: isSelected, isInRange: false, isBoundary: false);
  }

  String _timeDisplayText(AppLocalizations l10n) {
    if (_selectedYear == indexFilterUnlimited) {
      return l10n.indexDateRangeUnset;
    }

    if (_supportsAdvancedBrowserFilters &&
        _rangeStart != null &&
        _rangeEnd != null &&
        _rangeStart != _rangeEnd) {
      return '${_rangeStart!.displayLabel} - ${_rangeEnd!.displayLabel}';
    }

    final normalizedMonth = _normalizeMonthValue(_selectedMonth);
    if (normalizedMonth != null) {
      return '$_selectedYear.$normalizedMonth';
    }
    return _selectedYear;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hosted = DesktopPageChromeScope.hostsPageHeader(context);
    final bool showMonthFilter = _selectedYear != indexFilterUnlimited;

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
                  if (_supportsAdvancedBrowserFilters &&
                      entry.key == indexFilterKeyType)
                    _buildMultiSelectTypeRow(context)
                  else
                    _buildFilterRow(
                      context,
                      entry.key,
                      entry.key == indexFilterKeySort
                          ? _sortOptions()
                          : entry.value,
                    ),
                ],
                _buildTimeButtonRow(context),
                if (_timePanelOpen) ...[
                  _buildTimePanelYearRow(context),
                  if (showMonthFilter) _buildTimePanelMonthRow(context),
                  if (_supportsAdvancedBrowserFilters &&
                      _rangeStart != null &&
                      _rangeEnd != null)
                    _buildTimeRangeSummaryRow(context),
                  if (_supportsAdvancedBrowserFilters)
                    _buildTimePanelModeToggle(context),
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

    if (hosted) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          DesktopPageActionRow(
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.searchHint,
                onPressed: () => WorkspaceNavigation.open<void>(
                  context,
                  WorkspaceDestinations.search(context),
                ),
              ),
            ],
          ),
          Expanded(child: body),
        ],
      );
    }

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
              onPressed: () => WorkspaceNavigation.open<void>(
                context,
                WorkspaceDestinations.search(context),
              ),
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
      final colorScheme = Theme.of(context).colorScheme;
      final chip = FilterChip(
        showCheckmark: false,
        label: Text(indexFilterLabel(AppLocalizations.of(context), option)),
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
          color: isSelected ? colorScheme.onSecondaryContainer : null,
        ),
        selectedColor: colorScheme.secondaryContainer,
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
              indexFilterLabel(AppLocalizations.of(context), label),
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

  Widget _buildTimeButtonRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = _timeDisplayText(l10n);
    final hasTimeFilter = _selectedYear != indexFilterUnlimited;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 32,
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).indexFilterTime,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              setState(() {
                _timePanelOpen = !_timePanelOpen;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasTimeFilter
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: _timePanelOpen
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasTimeFilter
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: hasTimeFilter
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _timePanelOpen ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (hasTimeFilter) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                setState(() {
                  _selectedYear = indexFilterUnlimited;
                  _selectedMonth = indexFilterAll;
                  _rangeStart = null;
                  _rangeEnd = null;
                  _prepareForRefresh();
                });
                _fetchAnimes();
              },
              borderRadius: BorderRadius.circular(10),
              child: Icon(
                Icons.close,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePanelYearRow(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final chips = _yearOptions.map((option) {
      final isSelected = _selectedYear == option;
      final highlightState =
          _timePanelMode == _TimePanelMode.range &&
              _supportsAdvancedBrowserFilters
          ? _chipHighlightState('__time__', option)
          : (isSelected: isSelected, isInRange: false, isBoundary: false);
      final isInRange = highlightState.isInRange;
      final isBoundary = highlightState.isBoundary;
      final colorScheme = Theme.of(context).colorScheme;
      final chip = FilterChip(
        showCheckmark: false,
        label: Text(indexFilterLabel(AppLocalizations.of(context), option)),
        selected: isSelected,
        onSelected: (bool value) {
          if (value) {
            _onTimePanelYearSelected(option);
          }
        },
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.zero,
        backgroundColor: !isSelected && isInRange
            ? colorScheme.secondaryContainer.withValues(
                alpha: isBoundary ? 0.6 : 0.32,
              )
            : null,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected || isBoundary
              ? FontWeight.bold
              : FontWeight.normal,
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : isInRange
              ? colorScheme.onSurface
              : null,
        ),
        selectedColor: colorScheme.secondaryContainer,
        side: isBoundary
            ? BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.85),
                width: 1,
              )
            : BorderSide.none,
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
          const SizedBox(width: 50),
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

  Widget _buildTimePanelMonthRow(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final chips = _monthOptions.map((option) {
      final isSelected = _selectedMonth == option;
      final highlightState =
          _timePanelMode == _TimePanelMode.range &&
              _supportsAdvancedBrowserFilters
          ? _chipHighlightState('__month__', option)
          : (isSelected: isSelected, isInRange: false, isBoundary: false);
      final isInRange = highlightState.isInRange;
      final isBoundary = highlightState.isBoundary;
      final colorScheme = Theme.of(context).colorScheme;
      final chip = FilterChip(
        showCheckmark: false,
        label: Text(indexFilterLabel(AppLocalizations.of(context), option)),
        selected: isSelected,
        onSelected: (bool value) {
          if (value) {
            _onTimePanelMonthSelected(option);
          }
        },
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.zero,
        backgroundColor: !isSelected && isInRange
            ? colorScheme.secondaryContainer.withValues(
                alpha: isBoundary ? 0.6 : 0.32,
              )
            : null,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected || isBoundary
              ? FontWeight.bold
              : FontWeight.normal,
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : isInRange
              ? colorScheme.onSurface
              : null,
        ),
        selectedColor: colorScheme.secondaryContainer,
        side: isBoundary
            ? BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.85),
                width: 1,
              )
            : BorderSide.none,
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
          const SizedBox(width: 50),
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

  Widget _buildTimePanelModeToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPoint = _timePanelMode == _TimePanelMode.point;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, top: 2.0),
      child: Row(
        children: [
          const SizedBox(width: 50),
          ToggleButtons(
            isSelected: [isPoint, !isPoint],
            onPressed: (index) {
              setState(() {
                _timePanelMode = index == 0
                    ? _TimePanelMode.point
                    : _TimePanelMode.range;
              });
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 28, minWidth: 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  l10n.indexTimeModePoint,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPoint ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  l10n.indexTimeModeRange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: !isPoint ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectTypeRow(BuildContext context) {
    final options = _filterData[indexFilterKeyType] ?? const <String>[];
    final chips = options.map((option) {
      final isAllOption = option == indexFilterAll;
      final isSelected = isAllOption
          ? _selectedTypeTags.isEmpty
          : _selectedTypeTags.contains(option);

      return FilterChip(
        showCheckmark: false,
        label: Text(indexFilterLabel(AppLocalizations.of(context), option)),
        selected: isSelected,
        onSelected: (_) => _onTypeTagToggled(option),
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
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 32,
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).indexFilterType,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Wrap(
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

  Widget _buildTimeRangeSummaryRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 24,
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.indexDateRangeSelected,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              _rangeSummaryText(l10n),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearMonthFilterValue implements Comparable<_YearMonthFilterValue> {
  final int year;
  final int month;

  const _YearMonthFilterValue(this.year, this.month);

  String get apiValue => '$year-${month.toString().padLeft(2, '0')}';
  String get displayLabel => '$year.${month.toString().padLeft(2, '0')}';
  int get serializedIndex => year * 12 + month;

  @override
  int compareTo(_YearMonthFilterValue other) {
    final yearCompare = year.compareTo(other.year);
    if (yearCompare != 0) return yearCompare;
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _YearMonthFilterValue &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

enum _TimePanelMode { point, range }
