import '../src/rust/api/bangumi.dart';

extension BangumiEpisodeFilter on BangumiEpisode {
  bool isReleased() {
    if (airdate.isEmpty) return true;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime.parse(airdate);
      final episodeDate = DateTime(date.year, date.month, date.day);
      return !episodeDate.isAfter(today);
    } catch (_) {
      return true;
    }
  }
}

extension BangumiEpisodeFilterList on Iterable<BangumiEpisode> {
  List<BangumiEpisode> releasedEpisodes() {
    return withoutPhantomEpisodes().where((episode) => episode.isReleased()).toList();
  }

  /// Removes phantom episodes returned by the Bangumi API: entries that share
  /// an episode number (`sort`) with a real episode but carry no title or other
  /// metadata (different id, empty name/nameCn/airdate). Mirrors the dedup logic
  /// used by the details page episode panel so both panels stay consistent.
  List<BangumiEpisode> withoutPhantomEpisodes() {
    final list = toList();

    // First pass: collect sort values that have at least one named episode.
    final namedSorts = <double>{};
    for (final episode in list) {
      final hasName = episode.name.isNotEmpty || episode.nameCn.isNotEmpty;
      if (hasName) namedSorts.add(episode.sort);
    }

    // Second pass: keep every named episode, and drop nameless episodes whose
    // sort is already covered by a named one (the phantom duplicates). Also
    // de-duplicate by id to guard against repeated entries.
    final result = <BangumiEpisode>[];
    final seenIds = <String>{};
    for (final episode in list) {
      final hasName = episode.name.isNotEmpty || episode.nameCn.isNotEmpty;
      if (!hasName && namedSorts.contains(episode.sort)) {
        continue;
      }
      if (!seenIds.add(episode.id.toString())) {
        continue;
      }
      result.add(episode);
    }
    return result;
  }

  BangumiEpisode? latestReleasedEpisode() {
    BangumiEpisode? latest;
    for (final episode in this) {
      if (!episode.isReleased()) continue;
      if (latest == null || episode.sort > latest.sort) {
        latest = episode;
      }
    }
    return latest;
  }
}
