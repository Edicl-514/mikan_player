import 'package:isar/isar.dart';

part 'bangumi_character_cache.g.dart';

/// Bangumi 角色缓存模型
@collection
class BangumiCharacterCache {
  Id id = Isar.autoIncrement;

  /// 关联的条目 ID
  @Index()
  late int subjectId;

  /// 角色 ID
  late int characterId;

  /// 角色名称
  late String name;

  /// 角色类型（主角、配角等）
  late String roleName;

  /// 角色图片 URL (small)
  String? imageSmall;

  /// 角色图片 URL (grid)
  String? imageGrid;

  /// 角色图片 URL (large)
  String? imageLarge;

  /// 角色图片 URL (medium)
  String? imageMedium;

  /// 角色图片 URL (common)
  String? imageCommon;

  /// 本地图片路径
  String? localImagePath;

  /// 声优列表（JSON 字符串）
  String? actorsJson;

  /// 缓存时间戳
  late int cachedAt;

  /// 缓存过期时间
  late int expiresAt;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  static BangumiCharacterCache create({
    required int subjectId,
    required int characterId,
    required String name,
    required String roleName,
    String? imageSmall,
    String? imageGrid,
    String? imageLarge,
    String? imageMedium,
    String? imageCommon,
    String? localImagePath,
    String? actorsJson,
    int cacheDurationDays = 7,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BangumiCharacterCache()
      ..subjectId = subjectId
      ..characterId = characterId
      ..name = name
      ..roleName = roleName
      ..imageSmall = imageSmall
      ..imageGrid = imageGrid
      ..imageLarge = imageLarge
      ..imageMedium = imageMedium
      ..imageCommon = imageCommon
      ..localImagePath = localImagePath
      ..actorsJson = actorsJson
      ..cachedAt = now
      ..expiresAt = now + (cacheDurationDays * 24 * 60 * 60 * 1000);
  }
}
