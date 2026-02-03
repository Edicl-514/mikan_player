import 'package:flutter/material.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  late Future<List<PlaybackHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _historyManager.getHistory();
  }

  Future<void> _reload() async {
    setState(() {
      _historyFuture = _historyManager.getHistory();
    });
  }

  String _formatEpisodeSort(double sort) {
    if (sort % 1 == 0) {
      return sort.toInt().toString();
    }
    return sort.toString();
  }

  Future<void> _openHistoryItem(PlaybackHistoryItem item) async {
    var episodes = item.toEpisodes();

    if (episodes.isEmpty && item.bangumiId != null) {
      final subjectId = int.tryParse(item.bangumiId!);
      if (subjectId != null) {
        try {
          episodes = await fetchBangumiEpisodes(subjectId: subjectId);
        } catch (_) {
          episodes = <BangumiEpisode>[];
        }
      }
    }

    if (episodes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法加载剧集列表')),
        );
      }
      return;
    }

    BangumiEpisode currentEpisode = episodes.first;
    final byId = episodes.where((e) => e.id == item.episodeId).toList();
    if (byId.isNotEmpty) {
      currentEpisode = byId.first;
    } else {
      final bySort = episodes
          .where((e) => e.sort == item.episodeSort)
          .toList();
      if (bySort.isNotEmpty) {
        currentEpisode = bySort.first;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          anime: item.toAnimeInfo(),
          currentEpisode: currentEpisode,
          allEpisodes: episodes,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('暂无播放记录',
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          Text('在播放页开始观看后会自动记录',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放历史')),
      body: FutureBuilder<List<PlaybackHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? <PlaybackHistoryItem>[];
          if (items.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final coverUrl = item.coverUrl ?? '';
                final episodeLabel =
                    'EP ${_formatEpisodeSort(item.episodeSort)}';

                return Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: coverUrl.isEmpty
                        ? Container(
                            width: 56,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: coverUrl,
                            width: 56,
                            height: 80,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
                          ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${episodeLabel}  ${item.episodeNameCn.isNotEmpty ? item.episodeNameCn : item.episodeName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _historyManager.remove(item.key);
                        if (mounted) {
                          _reload();
                        }
                      },
                    ),
                    onTap: () => _openHistoryItem(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
