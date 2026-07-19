import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/services/playback_history_episode_resolver.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';

typedef HistoryLoader = Future<List<PlaybackHistoryItem>> Function();
typedef HistoryRemover = Future<void> Function(String key);

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.loadHistory, this.removeHistory});

  final HistoryLoader? loadHistory;
  final HistoryRemover? removeHistory;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  late final PagedRequestController<int, PlaybackHistoryItem> _controller;
  final ScrollController _scrollController = createPlatformScrollController();

  @override
  void initState() {
    super.initState();
    _controller = PagedRequestController<int, PlaybackHistoryItem>(
      fetchPage: (_, _) =>
          widget.loadHistory?.call() ?? _historyManager.getHistory(),
    )..addListener(_onControllerChanged);
    _reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    await _controller.refresh(0);
  }

  String _formatEpisodeSort(double sort) {
    if (sort % 1 == 0) {
      return sort.toInt().toString();
    }
    return sort.toString();
  }

  String _formatMs(int ms) {
    if (ms <= 0) return '';
    final seconds = (ms / 1000).floor();
    final s = seconds % 60;
    final m = (seconds / 60).floor() % 60;
    final h = (seconds / 3600).floor();
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openHistoryItem(PlaybackHistoryItem item) async {
    final episodes = await resolvePlaybackHistoryEpisodes(item);
    final playableEpisodes = episodes.releasedEpisodes();
    if (playableEpisodes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).cannotLoadEpisodes),
          ),
        );
      }
      return;
    }

    BangumiEpisode currentEpisode = playableEpisodes.latestReleasedEpisode()!;
    final byId = playableEpisodes.where((e) => e.id == item.episodeId).toList();
    if (byId.isNotEmpty) {
      currentEpisode = byId.first;
    } else {
      final bySort = playableEpisodes
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
          allEpisodes: playableEpisodes,
          startPositionMs: item.lastPositionMs,
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            l10n.noHistory,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.historyEmptyHint,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget body;
    if (_controller.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_controller.error != null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.loadFailed(_controller.error.toString())),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _reload, child: Text(l10n.pageRetry)),
          ],
        ),
      );
    } else if (_controller.items.isEmpty) {
      body = _buildEmpty(l10n);
    } else {
      final items = _controller.items;
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final coverUrl = item.coverUrl ?? '';
            // i18n-ignore: product lexicon episode index prefix
            final episodeLabel = 'EP ${_formatEpisodeSort(item.episodeSort)}';

            return Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                        child: const Icon(Icons.image, color: Colors.grey),
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
                  // i18n-ignore: composed history subtitle with upstream episode title
                  '$episodeLabel  ${item.episodeNameCn.isNotEmpty ? item.episodeNameCn : item.episodeName}${item.lastPositionMs > 0 ? ' · ${_formatMs(item.lastPositionMs)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final remove = widget.removeHistory;
                    if (remove != null) {
                      await remove(item.key);
                    } else {
                      await _historyManager.remove(item.key);
                    }
                    if (mounted) await _reload();
                  },
                ),
                onTap: () => _openHistoryItem(item),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: body,
    );
  }
}
