import 'package:isar/isar.dart';

part 'bangumi_subject_cache.g.dart';

/// Bangumi 条目缓存模型
/// 用于缓存从 Bangumi API 获取的番剧基本信息
@collection
class BangumiSubjectCache {
  Id id = Isar.autoIncrement;

  /// Bangumi 条目 ID
  @Index(unique: true, replace: true)
  late int bangumiId;

  /// 标题
  late String title;

  /// 中文标题
  String? titleCn;

  /// 原标题
  String? originalTitle;

  /// 简介/描述
  String? description;

  /// 评分
  double? score;

  /// 排名
  int? rank;

  /// 图片 URL (small)
  String? imageSmall;

  /// 图片 URL (grid)
  String? imageGrid;

  /// 图片 URL (large)
  String? imageLarge;

  /// 图片 URL (medium)
  String? imageMedium;

  /// 图片 URL (common)
  String? imageCommon;

  /// 本地图片路径（缓存后的本地路径）
  String? localImagePath;

  /// 放送日期
  String? airDate;

  /// 放送星期
  String? airWeekday;

  /// 标签列表（JSON 字符串存储）
  String? tagsJson;

  /// 完整的 JSON 数据（用于存储额外信息）
  String? fullJson;

  /// 条目类型 (2 = anime)
  int? type;

  /// 总集数
  int? totalEpisodes;

  /// 缓存时间戳（毫秒）
  late int cachedAt;

  /// 缓存过期时间（毫秒），默认 7 天
  late int expiresAt;

  /// 检查缓存是否过期
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  /// 创建缓存条目
  static BangumiSubjectCache create({
    required int bangumiId,
    required String title,
    String? titleCn,
    String? originalTitle,
    String? description,
    double? score,
    int? rank,
    String? imageSmall,
    String? imageGrid,
    String? imageLarge,
    String? imageMedium,
    String? imageCommon,
    String? localImagePath,
    String? airDate,
    String? airWeekday,
    String? tagsJson,
    String? fullJson,
    int? type,
    int? totalEpisodes,
    int cacheDurationDays = 7,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BangumiSubjectCache()
      ..bangumiId = bangumiId
      ..title = title
      ..titleCn = titleCn
      ..originalTitle = originalTitle
      ..description = description
      ..score = score
      ..rank = rank
      ..imageSmall = imageSmall
      ..imageGrid = imageGrid
      ..imageLarge = imageLarge
      ..imageMedium = imageMedium
      ..imageCommon = imageCommon
      ..localImagePath = localImagePath
      ..airDate = airDate
      ..airWeekday = airWeekday
      ..tagsJson = tagsJson
      ..fullJson = fullJson
      ..type = type
      ..totalEpisodes = totalEpisodes
      ..cachedAt = now
      ..expiresAt = now + (cacheDurationDays * 24 * 60 * 60 * 1000);
  }
}
