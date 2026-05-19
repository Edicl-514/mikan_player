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
    return where((episode) => episode.isReleased()).toList();
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
