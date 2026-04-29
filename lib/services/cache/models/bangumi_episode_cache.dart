/// Bangumi episode list cache model.
/// Detail-page episode data expires at the next local midnight.
class BangumiEpisodeCache {
  int id = 0;

  late int subjectId;

  late String episodesJson;

  late int cachedAt;

  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  static BangumiEpisodeCache create({
    required int subjectId,
    required String episodesJson,
  }) {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);

    return BangumiEpisodeCache()
      ..subjectId = subjectId
      ..episodesJson = episodesJson
      ..cachedAt = now.millisecondsSinceEpoch
      ..expiresAt = nextMidnight.millisecondsSinceEpoch;
  }
}
