import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';

class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});

  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage>
    with SingleTickerProviderStateMixin {
  late TabController _dayTabController;
  final List<String> _days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日', '其他'];
  List<crawler.ArchiveQuarter> _archives = [];
  crawler.ArchiveQuarter? _selectedArchive;
  List<crawler.AnimeInfo> _animes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dayTabController = TabController(length: _days.length, vsync: this);
    final now = DateTime.now();
    // weekday: 1 (Mon) to 7 (Sun)
    int todayIndex = now.weekday - 1;
    if (todayIndex >= 0 && todayIndex < 7) {
      _dayTabController.index = todayIndex;
    }
    _loadArchives();
  }

  @override
  void dispose() {
    _dayTabController.dispose();
    super.dispose();
  }

  Future<void> _loadArchives() async {
    try {
      final archives = await crawler.fetchArchiveList();
      if (mounted) {
        setState(() {
          _archives = archives;
          if (_archives.isNotEmpty) {
            _selectedArchive = _archives.first;
          }
        });
        if (_selectedArchive != null) {
          _loadAnimes(_selectedArchive!.quarter);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _parseError(e);
        });
      }
    }
  }

  String _parseError(dynamic e) {
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('connect') ||
        errorStr.contains('request') ||
        errorStr.contains('handshake') ||
        errorStr.contains('timeout')) {
      return "网络连接失败，请检查网络设置或稍后再试";
    }
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return "资源未找到 (404)";
    }
    return "加载失败: $e";
  }

  Future<void> _loadAnimes(String yearQuarter) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // 1. Fetch Basic Schedule (Fast)
      final basicList = await crawler.fetchScheduleBasic(
        yearQuarter: yearQuarter,
      );
      if (!mounted) return;

      setState(() {
        _animes = basicList;
        _isLoading = false;
      });

      // 2. Fetch Details for Current Tab (Priority)
      await _loadDetailsForCurrentTab();

      // 3. Fetch Details for Other Days (Background)
      if (mounted) {
        _loadDetailsForOthers();
      }

      // 4. Fetch Extra Subjects (Search)
      if (mounted) {
        _loadExtras(yearQuarter);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _parseError(e);
        });
      }
    }
  }

  Future<void> _loadDetailsForCurrentTab() async {
    final currentDayIndex = _dayTabController.index;
    if (currentDayIndex >= _days.length) return;

    final currentDay = _days[currentDayIndex];

    final targetAnimes = _animes.where((a) {
      final day = a.broadcastDay ?? '其他';
      return day == currentDay && a.bangumiId != null && a.coverUrl == null;
    }).toList();

    if (targetAnimes.isEmpty) return;

    try {
      final enriched = await crawler.fillAnimeDetails(animes: targetAnimes);
      if (mounted) {
        _updateAnimes(enriched);
      }
    } catch (e) {
      debugPrint("Error loading details for $currentDay: $e");
    }
  }

  Future<void> _loadDetailsForOthers() async {
    final currentDayIndex = _dayTabController.index;
    final currentDay = _days[currentDayIndex];

    final targetAnimes = _animes.where((a) {
      final day = a.broadcastDay ?? '其他';
      return day != currentDay && a.bangumiId != null && a.coverUrl == null;
    }).toList();

    if (targetAnimes.isEmpty) return;

    // chunk requests if too many? Rust handles concurrency, but we can pass all.
    try {
      final enriched = await crawler.fillAnimeDetails(animes: targetAnimes);
      if (mounted) {
        _updateAnimes(enriched);
      }
    } catch (e) {
      debugPrint("Error loading details for others: $e");
    }
  }

  Future<void> _loadExtras(String yearQuarter) async {
    try {
      // IDs already in the list to avoid dupes
      final existingIds = _animes
          .map((a) => a.bangumiId)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final extras = await crawler.fetchExtraSubjects(
        yearQuarter: yearQuarter,
        existingIds: existingIds,
      );

      if (mounted && extras.isNotEmpty) {
        setState(() {
          _animes.addAll(extras);
        });
        // Extras usually have covers, but if not we could enrich them too.
        // The scraping logic for extras usually includes covers.
      }
    } catch (e) {
      debugPrint("Error loading extras: $e");
    }
  }

  void _updateAnimes(List<crawler.AnimeInfo> updates) {
    setState(() {
      for (final update in updates) {
        final index = _animes.indexWhere(
          (a) => a.bangumiId == update.bangumiId,
        );
        if (index != -1) {
          _animes[index] = update;
        }
      }
    });
  }

  void _showQuarterPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Quarter',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _archives.length,
                  itemBuilder: (context, index) {
                    final arch = _archives[index];
                    final isSelected =
                        _selectedArchive?.quarter == arch.quarter;
                    return ListTile(
                      title: Text(arch.title),
                      subtitle: Text(arch.year),
                      selected: isSelected,
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () {
                        setState(() => _selectedArchive = arch);
                        _loadAnimes(arch.quarter);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<crawler.AnimeInfo>> get _groupedAnimes {
    final Map<String, List<crawler.AnimeInfo>> groups = {};
    for (final day in _days) {
      groups[day] = [];
    }
    for (final anime in _animes) {
      final day = anime.broadcastDay ?? '其他';
      if (groups.containsKey(day)) {
        groups[day]!.add(anime);
      } else {
        groups['其他']!.add(anime);
      }
    }
    for (final group in groups.values) {
      group.sort((a, b) {
        final timeA = a.broadcastTime ?? '99:99';
        final timeB = b.broadcastTime ?? '99:99';
        return timeA.compareTo(timeB);
      });
    }
    return groups;
  }

  Widget _buildAnimeItem(crawler.AnimeInfo anime) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BangumiDetailsPage(
                anime: anime,
                heroTagPrefix: 'timetable_cover',
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag:
                      'timetable_cover_${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: anime.coverUrl != null
                        ? Image.network(
                            anime.coverUrl!,
                            width: 70,
                            height: 100,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 70,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                  ),
                ),
                if (anime.score != null && anime.score! > 0)
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
                        ),
                      ),
                      child: Text(
                        anime.score!.toStringAsFixed(1),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    anime.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (anime.subTitle != null && anime.subTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        anime.subTitle!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (anime.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        anime.tags.take(4).join(' / '),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (anime.rank != null && anime.rank! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Rank #${anime.rank}',
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedAnimes;
    final now = DateTime.now();
    final todayStr = _days[now.weekday - 1];
    final currentTimeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedArchive?.title ?? 'Timetable'),
        actions: [
          IconButton(
            onPressed: _archives.isEmpty ? null : _showQuarterPicker,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
        bottom: TabBar(
          controller: _dayTabController,
          isScrollable: true,
          tabs: List.generate(_days.length, (index) {
            final day = _days[index];
            if (index < 7 && _selectedArchive == _archives.firstOrNull) {
              final now = DateTime.now();
              final monday = now.subtract(Duration(days: now.weekday - 1));
              final targetDate = monday.add(Duration(days: index));
              return Tab(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${targetDate.month}/${targetDate.day}",
                      style: const TextStyle(fontSize: 10),
                    ),
                    Text(day),
                  ],
                ),
              );
            }
            return Tab(text: day);
          }),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _archives.isEmpty
          ? _buildErrorView()
          : TabBarView(
              controller: _dayTabController,
              children: _days.map((day) {
                final animes = grouped[day] ?? [];
                if (animes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_filter,
                          size: 64,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text('No anime found for this day.'),
                      ],
                    ),
                  );
                }

                // Mix time headers and anime items
                final listItems = <Widget>[];
                String? lastTime;
                bool markerAdded = false;

                for (final anime in animes) {
                  final time = anime.broadcastTime ?? "TBA";

                  // Add current time marker if it's today and we passing that time
                  if (day == todayStr &&
                      !markerAdded &&
                      time != "TBA" &&
                      time.compareTo(currentTimeStr) > 0) {
                    listItems.add(_buildTimeMarker(currentTimeStr));
                    markerAdded = true;
                  }

                  if (time != lastTime) {
                    listItems.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                    lastTime = time;
                  }
                  listItems.add(_buildAnimeItem(anime));
                }

                // Add marker at end if not added and it's today
                if (day == todayStr && !markerAdded) {
                  listItems.add(_buildTimeMarker(currentTimeStr));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: listItems,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTimeMarker(String timeStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 20, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: Colors.deepPurple, thickness: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              "出错了",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "未知错误",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadArchives();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("重试"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
