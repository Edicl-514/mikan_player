import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

typedef PlaybackHistoryEpisodeLoader =
    Future<List<BangumiEpisode>> Function(int subjectId);

/// Picks the [BangumiEpisode] to resume at from a playable (released-only)
/// episode list for a history item.
///
/// Resolution order: exact [BangumiEpisode.id] match → [BangumiEpisode.sort]
/// match → the latest released episode. Returns `null` when
/// [playableEpisodes] is empty; the caller is expected to surface that empty
/// case (e.g. a "cannot load episodes" snackbar) rather than navigate.
BangumiEpisode? resolveResumeEpisode(
  PlaybackHistoryItem item,
  List<BangumiEpisode> playableEpisodes,
) {
  if (playableEpisodes.isEmpty) return null;
  final byId = playableEpisodes.where((e) => e.id == item.episodeId);
  if (byId.isNotEmpty) return byId.first;
  final bySort = playableEpisodes.where((e) => e.sort == item.episodeSort);
  if (bySort.isNotEmpty) return bySort.first;
  return playableEpisodes.latestReleasedEpisode();
}

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
