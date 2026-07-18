import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

typedef PlaybackHistoryEpisodeLoader =
    Future<List<BangumiEpisode>> Function(int subjectId);

/// Resolves the episode list used when opening an item from playback history.
///
/// History stores an episode snapshot so it remains usable offline, but that
/// snapshot can become stale while a currently airing show receives new
/// episodes. Prefer the normal daily episode cache/network path when a Bangumi
/// subject id is available, and fall back to the snapshot on any failure.
Future<List<BangumiEpisode>> resolvePlaybackHistoryEpisodes(
  PlaybackHistoryItem item, {
  PlaybackHistoryEpisodeLoader? loadEpisodes,
}) async {
  final snapshot = item.toEpisodes();
  final subjectId = int.tryParse(item.bangumiId ?? '');
  if (subjectId == null) return snapshot;

  try {
    final loader = loadEpisodes ?? _loadEpisodes;
    final refreshed = await loader(subjectId);
    if (refreshed.isNotEmpty) return refreshed;
  } catch (error) {
    debugPrint(
      '[History] Failed to refresh episodes for $subjectId; '
      'using saved snapshot: $error',
    );
  }

  return snapshot;
}

Future<List<BangumiEpisode>> _loadEpisodes(int subjectId) {
  return CacheManager.instance.getEpisodes(
    subjectId: subjectId,
    fetchFromNetwork: () => fetchBangumiEpisodes(subjectId: subjectId),
  );
}
