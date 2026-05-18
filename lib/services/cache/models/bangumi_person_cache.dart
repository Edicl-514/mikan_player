/// Bangumi person list cache model.
/// Subject staff/person data expires after 7 days.
class BangumiPersonCache {
  int id = 0;

  late int subjectId;

  late String personsJson;

  late int cachedAt;

  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  static BangumiPersonCache create({
    required int subjectId,
    required String personsJson,
  }) {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 7));

    return BangumiPersonCache()
      ..subjectId = subjectId
      ..personsJson = personsJson
      ..cachedAt = now.millisecondsSinceEpoch
      ..expiresAt = expiresAt.millisecondsSinceEpoch;
  }
}
