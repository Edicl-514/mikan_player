import 'package:isar/isar.dart';

part 'ranking_cache.g.dart';

/// 排行榜/索引页缓存模型
@collection
class RankingCache {
  Id id = Isar.autoIncrement;

  /// 缓存键（由排序类型、年份、标签、页码组合）
  @Index(unique: true, replace: true)
  late String cacheKey;

  /// 排序类型
  late String sortType;

  /// 年份（用于索引页）
  String? year;

  /// 标签列表（JSON 字符串）
  String? tagsJson;

  /// 页码
  late int page;

  /// 结果列表 JSON
  late String resultsJson;

  /// 缓存时间戳
  late int cachedAt;

  /// 缓存过期时间（排行榜数据默认 6 小时）
  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  /// 生成缓存键
  static String generateKey({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
  }) {
    final tagsStr = tags?.join(',') ?? '';
    return '$sortType|${year ?? ''}|$tagsStr|$page';
  }

  static RankingCache create({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
    required String resultsJson,
    int cacheDurationHours = 6,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RankingCache()
      ..cacheKey = generateKey(sortType: sortType, year: year, tags: tags, page: page)
      ..sortType = sortType
      ..year = year
      ..tagsJson = tags?.join(',')
      ..page = page
      ..resultsJson = resultsJson
      ..cachedAt = now
      ..expiresAt = now + (cacheDurationHours * 60 * 60 * 1000);
  }
}
