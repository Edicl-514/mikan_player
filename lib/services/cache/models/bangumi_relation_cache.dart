import 'package:isar/isar.dart';

part 'bangumi_relation_cache.g.dart';

/// Bangumi 关联条目缓存模型
@collection
class BangumiRelationCache {
  Id id = Isar.autoIncrement;

  /// 源条目 ID
  @Index()
  late int sourceSubjectId;

  /// 关联条目 ID
  late int relatedSubjectId;

  /// 关联条目名称
  late String name;

  /// 关联条目中文名
  String? nameCn;

  /// 关系类型（续集、前传等）
  late String relation;

  /// 图片 URL
  String? imageUrl;

  /// 本地图片路径
  String? localImagePath;

  /// 缓存时间戳
  late int cachedAt;

  /// 缓存过期时间
  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  static BangumiRelationCache create({
    required int sourceSubjectId,
    required int relatedSubjectId,
    required String name,
    String? nameCn,
    required String relation,
    String? imageUrl,
    String? localImagePath,
    int cacheDurationDays = 7,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BangumiRelationCache()
      ..sourceSubjectId = sourceSubjectId
      ..relatedSubjectId = relatedSubjectId
      ..name = name
      ..nameCn = nameCn
      ..relation = relation
      ..imageUrl = imageUrl
      ..localImagePath = localImagePath
      ..cachedAt = now
      ..expiresAt = now + (cacheDurationDays * 24 * 60 * 60 * 1000);
  }
}
