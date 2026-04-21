/// 时间表/季度番剧列表缓存模型
class TimetableCache {
  int id = 0;

  /// 季度标识（如 "2024q1"）
  late String quarter;

  /// 完整的动画列表 JSON
  late String animesJson;

  /// 缓存时间戳
  late int cachedAt;

  /// 缓存过期时间（时间表数据更新较频繁，默认 1 天）
  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  static TimetableCache create({
    required String quarter,
    required String animesJson,
    int cacheDurationHours = 24,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TimetableCache()
      ..quarter = quarter
      ..animesJson = animesJson
      ..cachedAt = now
      ..expiresAt = now + (cacheDurationHours * 60 * 60 * 1000);
  }
}
