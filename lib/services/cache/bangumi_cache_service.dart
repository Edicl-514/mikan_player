import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:mikan_player/utils/app_directories.dart';

import 'models/bangumi_subject_cache.dart';
import 'models/bangumi_character_cache.dart';
import 'models/bangumi_relation_cache.dart';
import 'models/timetable_cache.dart';
import 'models/ranking_cache.dart';
import 'models/download_record.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';

/// Bangumi 缓存数据库服务
/// 单例模式，管理所有缓存数据的读写
class BangumiCacheService {
  static BangumiCacheService? _instance;
  static BangumiCacheService get instance {
    _instance ??= BangumiCacheService._();
    return _instance!;
  }

  BangumiCacheService._();

  Isar? _isar;
  bool _isInitialized = false;

  /// 获取 Isar 实例
  Isar get isar {
    if (_isar == null) {
      throw StateError(
        'BangumiCacheService not initialized. Call initialize() first.',
      );
    }
    return _isar!;
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化缓存数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    final dir = await _getCacheDirectory();

    _isar = await Isar.open(
      [
        BangumiSubjectCacheSchema,
        BangumiCharacterCacheSchema,
        BangumiRelationCacheSchema,
        TimetableCacheSchema,
        RankingCacheSchema,
        DownloadRecordSchema,
      ],
      directory: dir.path,
      name: 'bangumi_cache',
    );

    _isInitialized = true;
    debugPrint('BangumiCacheService initialized at: ${dir.path}');
  }

  /// 获取缓存目录（兼容 Windows 和 Android）
  Future<Directory> _getCacheDirectory() async {
    final appDir = await AppDirectories.getUnifiedAppDataDirectory();
    final cacheDir = Directory('${appDir.path}/cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 关闭数据库
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
    _isInitialized = false;
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.bangumiSubjectCaches.clear();
      await isar.bangumiCharacterCaches.clear();
      await isar.bangumiRelationCaches.clear();
      await isar.timetableCaches.clear();
      await isar.rankingCaches.clear();
      // NOTE: Do not clear downloadRecords here as they are user data
    });
  }

  /// 清除过期缓存
  Future<void> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await isar.writeTxn(() async {
      // 清除过期的条目缓存
      final expiredSubjects = await isar.bangumiSubjectCaches
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      await isar.bangumiSubjectCaches.deleteAll(
        expiredSubjects.map((e) => e.id).toList(),
      );

      // 清除过期的角色缓存
      final expiredCharacters = await isar.bangumiCharacterCaches
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      await isar.bangumiCharacterCaches.deleteAll(
        expiredCharacters.map((e) => e.id).toList(),
      );

      // 清除过期的关联缓存
      final expiredRelations = await isar.bangumiRelationCaches
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      await isar.bangumiRelationCaches.deleteAll(
        expiredRelations.map((e) => e.id).toList(),
      );

      // 清除过期的时间表缓存
      final expiredTimetables = await isar.timetableCaches
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      await isar.timetableCaches.deleteAll(
        expiredTimetables.map((e) => e.id).toList(),
      );

      // 清除过期的排行榜缓存
      final expiredRankings = await isar.rankingCaches
          .filter()
          .expiresAtLessThan(now)
          .findAll();
      await isar.rankingCaches.deleteAll(
        expiredRankings.map((e) => e.id).toList(),
      );
    });
  }

  // ==================== 条目缓存操作 ====================

  /// 获取条目缓存
  Future<BangumiSubjectCache?> getSubject(int bangumiId) async {
    final cache = await isar.bangumiSubjectCaches
        .filter()
        .bangumiIdEqualTo(bangumiId)
        .findFirst();

    if (cache != null && !cache.isExpired) {
      debugPrint('Isar Cache: Hit Subject $bangumiId');
      return cache;
    }
    debugPrint('Isar Cache: Miss Subject $bangumiId');
    return null;
  }

  /// 保存条目缓存
  Future<void> saveSubject(BangumiSubjectCache cache) async {
    await isar.writeTxn(() async {
      await isar.bangumiSubjectCaches.put(cache);
    });
    debugPrint('Isar Cache: Save Subject ${cache.bangumiId}');
  }

  /// 批量保存条目缓存
  Future<void> saveSubjects(List<BangumiSubjectCache> caches) async {
    await isar.writeTxn(() async {
      await isar.bangumiSubjectCaches.putAll(caches);
    });
    debugPrint('Isar Cache: Save Subjects count=${caches.length}');
  }

  /// 从 AnimeInfo 创建并保存条目缓存
  Future<BangumiSubjectCache?> cacheFromAnimeInfo(AnimeInfo anime) async {
    if (anime.bangumiId == null) return null;

    final bangumiId = int.tryParse(anime.bangumiId!);
    if (bangumiId == null) return null;

    // 检查缓存是否已存在且未过期
    final existing = await getSubject(bangumiId);
    if (existing != null) {
      // 如果已有 fullJson，不需要更新
      if (existing.fullJson != null) {
        return existing;
      }
      // 如果新数据没有 fullJson，也不需要更新
      if (anime.fullJson == null) {
        return existing;
      }
      // 继续保存以更新 fullJson
    }

    Map<String, dynamic>? fullData;
    if (anime.fullJson != null) {
      try {
        fullData = jsonDecode(anime.fullJson!);
      } catch (_) {}
    }

    final cache = BangumiSubjectCache.create(
      bangumiId: bangumiId,
      title: anime.title,
      titleCn: anime.subTitle,
      originalTitle: fullData?['name'],
      description: fullData?['summary'],
      score: anime.score,
      rank: anime.rank,
      imageSmall: fullData?['images']?['small'],
      imageGrid: fullData?['images']?['grid'],
      imageLarge: fullData?['images']?['large'] ?? anime.coverUrl,
      imageMedium: fullData?['images']?['medium'],
      imageCommon: fullData?['images']?['common'],
      airDate: fullData?['date'],
      airWeekday: anime.broadcastDay,
      tagsJson: anime.tags.isNotEmpty ? jsonEncode(anime.tags) : null,
      fullJson: anime.fullJson,
      type: fullData?['type'],
      totalEpisodes: fullData?['eps'],
    );

    await saveSubject(cache);
    return cache;
  }

  /// 从 RankingAnime 创建并保存条目缓存
  Future<BangumiSubjectCache?> cacheFromRankingAnime(RankingAnime anime) async {
    final bangumiId = int.tryParse(anime.bangumiId);
    if (bangumiId == null) return null;

    // 检查缓存是否已存在且未过期
    final existing = await getSubject(bangumiId);
    if (existing != null) {
      return existing; // 已缓存，无需重复保存
    }

    final cache = BangumiSubjectCache.create(
      bangumiId: bangumiId,
      title: anime.title,
      originalTitle: anime.originalTitle,
      score: anime.score,
      rank: anime.rank,
      imageLarge: anime.coverUrl,
    );

    await saveSubject(cache);
    return cache;
  }

  // ==================== 角色缓存操作 ====================

  /// 获取条目的角色缓存列表
  Future<List<BangumiCharacterCache>> getCharacters(int subjectId) async {
    final caches = await isar.bangumiCharacterCaches
        .filter()
        .subjectIdEqualTo(subjectId)
        .findAll();

    if (caches.isNotEmpty && !caches.first.isExpired) {
      debugPrint('Isar Cache: Hit Characters $subjectId');
      return caches;
    }
    debugPrint('Isar Cache: Miss Characters $subjectId');
    return [];
  }

  /// 保存角色缓存
  Future<void> saveCharacters(
    int subjectId,
    List<BangumiCharacter> characters,
  ) async {
    final caches = characters.map((char) {
      return BangumiCharacterCache.create(
        subjectId: subjectId,
        characterId: char.id,
        name: char.name,
        roleName: char.roleName,
        imageSmall: char.images?.small,
        imageGrid: char.images?.grid,
        imageLarge: char.images?.large,
        imageMedium: char.images?.medium,
        imageCommon: char.images?.common,
        actorsJson: jsonEncode(
          char.actors.map((a) => {'id': a.id, 'name': a.name}).toList(),
        ),
      );
    }).toList();

    await isar.writeTxn(() async {
      // 先删除旧的角色缓存
      final oldCaches = await isar.bangumiCharacterCaches
          .filter()
          .subjectIdEqualTo(subjectId)
          .findAll();
      await isar.bangumiCharacterCaches.deleteAll(
        oldCaches.map((e) => e.id).toList(),
      );
      // 保存新的
      await isar.bangumiCharacterCaches.putAll(caches);
    });
    debugPrint('Isar Cache: Save Characters $subjectId count=${caches.length}');
  }

  /// 将缓存转换为 BangumiCharacter
  List<BangumiCharacter> charactersFromCache(
    List<BangumiCharacterCache> caches,
  ) {
    return caches.map((cache) {
      List<BangumiActor> actors = [];
      if (cache.actorsJson != null) {
        try {
          final actorsList = jsonDecode(cache.actorsJson!) as List;
          actors = actorsList
              .map((a) => BangumiActor(id: a['id'], name: a['name']))
              .toList();
        } catch (_) {}
      }

      return BangumiCharacter(
        id: cache.characterId,
        name: cache.name,
        roleName: cache.roleName,
        images: (cache.imageSmall != null || cache.imageLarge != null)
            ? BangumiImages(
                small: cache.imageSmall ?? '',
                grid: cache.imageGrid ?? '',
                large: cache.imageLarge ?? '',
                medium: cache.imageMedium ?? '',
                common: cache.imageCommon ?? '',
              )
            : null,
        actors: actors,
      );
    }).toList();
  }

  // ==================== 关联条目缓存操作 ====================

  /// 获取条目的关联条目缓存列表
  Future<List<BangumiRelationCache>> getRelations(int subjectId) async {
    final caches = await isar.bangumiRelationCaches
        .filter()
        .sourceSubjectIdEqualTo(subjectId)
        .findAll();

    if (caches.isNotEmpty && !caches.first.isExpired) {
      debugPrint('Isar Cache: Hit Relations $subjectId');
      // 过滤掉占位记录（relatedSubjectId == -1）
      return caches.where((c) => c.relatedSubjectId != -1).toList();
    }
    debugPrint('Isar Cache: Miss Relations $subjectId');
    return [];
  }

  /// 保存关联条目缓存
  Future<void> saveRelations(
    int subjectId,
    List<BangumiRelatedSubject> relations,
  ) async {
    final caches = relations.map((rel) {
      return BangumiRelationCache.create(
        sourceSubjectId: subjectId,
        relatedSubjectId: rel.id,
        name: rel.name,
        nameCn: rel.nameCn,
        relation: rel.relation,
        imageUrl: rel.image,
      );
    }).toList();

    // 如果关联列表为空，保存一个占位记录
    if (caches.isEmpty) {
      caches.add(BangumiRelationCache.create(
        sourceSubjectId: subjectId,
        relatedSubjectId: -1, // 占位标记
        name: '',
        relation: 'placeholder',
      ));
    }

    await isar.writeTxn(() async {
      // 先删除旧的关联缓存
      final oldCaches = await isar.bangumiRelationCaches
          .filter()
          .sourceSubjectIdEqualTo(subjectId)
          .findAll();
      await isar.bangumiRelationCaches.deleteAll(
        oldCaches.map((e) => e.id).toList(),
      );
      // 保存新的
      await isar.bangumiRelationCaches.putAll(caches);
    });
    debugPrint('Isar Cache: Save Relations $subjectId count=${relations.length}');
  }

  /// 将缓存转换为 BangumiRelatedSubject
  List<BangumiRelatedSubject> relationsFromCache(
    List<BangumiRelationCache> caches,
  ) {
    return caches
        .where((cache) => cache.relatedSubjectId != -1) // 过滤占位记录
        .map((cache) {
      return BangumiRelatedSubject(
        id: cache.relatedSubjectId,
        name: cache.name,
        nameCn: cache.nameCn ?? '',
        relation: cache.relation,
        image: cache.imageUrl ?? '',
      );
    }).toList();
  }

  // ==================== 时间表缓存操作 ====================

  /// 获取时间表缓存
  Future<TimetableCache?> getTimetable(String quarter) async {
    final cache = await isar.timetableCaches
        .filter()
        .quarterEqualTo(quarter)
        .findFirst();

    if (cache != null && !cache.isExpired) {
      debugPrint('Isar Cache: Hit Timetable $quarter');
      return cache;
    }
    debugPrint('Isar Cache: Miss Timetable $quarter');
    return null;
  }

  /// 获取时间表缓存（包括已过期的）
  /// 用于离线模式或网络失败时的降级方案
  Future<TimetableCache?> getTimetableIncludingExpired(String quarter) async {
    final cache = await isar.timetableCaches
        .filter()
        .quarterEqualTo(quarter)
        .findFirst();

    if (cache != null) {
      if (cache.isExpired) {
        debugPrint('Isar Cache: Hit Timetable (expired) $quarter');
      } else {
        debugPrint('Isar Cache: Hit Timetable $quarter');
      }
      return cache;
    }
    debugPrint('Isar Cache: Miss Timetable $quarter');
    return null;
  }

  /// 保存时间表缓存
  Future<void> saveTimetable(String quarter, List<AnimeInfo> animes) async {
    final animesJson = jsonEncode(
      animes
          .map(
            (a) => {
              'title': a.title,
              'subTitle': a.subTitle,
              'bangumiId': a.bangumiId,
              'mikanId': a.mikanId,
              'coverUrl': a.coverUrl,
              'siteUrl': a.siteUrl,
              'broadcastDay': a.broadcastDay,
              'broadcastTime': a.broadcastTime,
              'score': a.score,
              'rank': a.rank,
              'tags': a.tags,
              'fullJson': a.fullJson,
            },
          )
          .toList(),
    );

    final cache = TimetableCache.create(
      quarter: quarter,
      animesJson: animesJson,
    );

    await isar.writeTxn(() async {
      await isar.timetableCaches.put(cache);
    });
    debugPrint('Isar Cache: Save Timetable $quarter');
  }

  /// 将缓存转换为 AnimeInfo 列表
  List<AnimeInfo> animesFromTimetableCache(TimetableCache cache) {
    try {
      final list = jsonDecode(cache.animesJson) as List;
      return list
          .map(
            (item) => AnimeInfo(
              title: item['title'] ?? '',
              subTitle: item['subTitle'],
              bangumiId: item['bangumiId'],
              mikanId: item['mikanId'],
              coverUrl: item['coverUrl'],
              siteUrl: item['siteUrl'],
              broadcastDay: item['broadcastDay'],
              broadcastTime: item['broadcastTime'],
              score: item['score']?.toDouble(),
              rank: item['rank'],
              tags: (item['tags'] as List?)?.cast<String>() ?? [],
              fullJson: item['fullJson'],
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error parsing timetable cache: $e');
      return [];
    }
  }

  // ==================== 排行榜/索引缓存操作 ====================

  /// 获取排行榜缓存
  Future<RankingCache?> getRanking({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
  }) async {
    final key = RankingCache.generateKey(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
    );

    final cache = await isar.rankingCaches
        .filter()
        .cacheKeyEqualTo(key)
        .findFirst();

    if (cache != null && !cache.isExpired) {
      debugPrint('Isar Cache: Hit Ranking $key');
      return cache;
    }
    debugPrint('Isar Cache: Miss Ranking $key');
    return null;
  }

  /// 保存排行榜缓存
  Future<void> saveRanking({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
    required List<RankingAnime> results,
  }) async {
    final resultsJson = jsonEncode(
      results
          .map(
            (a) => {
              'title': a.title,
              'bangumiId': a.bangumiId,
              'coverUrl': a.coverUrl,
              'score': a.score,
              'rank': a.rank,
              'info': a.info,
              'originalTitle': a.originalTitle,
            },
          )
          .toList(),
    );

    final cache = RankingCache.create(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
      resultsJson: resultsJson,
    );

    await isar.writeTxn(() async {
      await isar.rankingCaches.put(cache);
    });
    debugPrint('Isar Cache: Save Ranking ${cache.cacheKey}');
  }

  /// 将缓存转换为 RankingAnime 列表
  List<RankingAnime> rankingFromCache(RankingCache cache) {
    try {
      final list = jsonDecode(cache.resultsJson) as List;
      return list
          .map(
            (item) => RankingAnime(
              title: item['title'] ?? '',
              bangumiId: item['bangumiId'] ?? '',
              coverUrl: item['coverUrl'] ?? '',
              score: item['score']?.toDouble(),
              rank: item['rank'],
              info: item['info'] ?? '',
              originalTitle: item['originalTitle'],
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error parsing ranking cache: $e');
      return [];
    }
  }

  // ==================== 统计信息 ====================

  /// 获取缓存统计信息
  Future<Map<String, int>> getCacheStats() async {
    return {
      'subjects': await isar.bangumiSubjectCaches.count(),
      'characters': await isar.bangumiCharacterCaches.count(),
      'relations': await isar.bangumiRelationCaches.count(),
      'timetables': await isar.timetableCaches.count(),
      'rankings': await isar.rankingCaches.count(),
      'downloadRecords': await isar.downloadRecords.count(),
    };
  }

  // ==================== 下载记录操作 ====================

  /// 获取下载记录
  Future<DownloadRecord?> getDownloadRecord(String infoHash) async {
    final record = await isar.downloadRecords
        .filter()
        .infoHashEqualTo(infoHash)
        .findFirst();
    if (record != null) {
      debugPrint('Isar Cache: Hit DownloadRecord $infoHash');
    } else {
      debugPrint('Isar Cache: Miss DownloadRecord $infoHash');
    }
    return record;
  }

  /// 保存下载记录
  Future<void> saveDownloadRecord(DownloadRecord record) async {
    await isar.writeTxn(() async {
      await isar.downloadRecords.put(record);
    });
    debugPrint('Isar Cache: Save DownloadRecord ${record.infoHash}');
  }

  /// 查找已完成的下载
  Future<DownloadRecord?> findCompletedDownload(
    String animeName,
    int episodeNumber,
  ) async {
    // 模糊匹配番剧名称可能会有问题，最好如果有 BangumiID 能存 BangumiID
    // 目前先尝试精确匹配
    final record = await isar.downloadRecords
        .filter()
        .animeNameEqualTo(animeName)
        .episodeNumberEqualTo(episodeNumber)
        .statusEqualTo(1) // Completed
        .findFirst();

    if (record != null) {
      debugPrint('Isar Cache: Hit CompletedDownload $animeName $episodeNumber');
    } else {
      debugPrint(
        'Isar Cache: Miss CompletedDownload $animeName $episodeNumber',
      );
    }
    return record;
  }

  /// 获取所有下载记录
  Future<List<DownloadRecord>> getAllDownloadRecords() async {
    final records = await isar.downloadRecords.where().findAll();
    debugPrint('Isar Cache: Get AllDownloadRecords count=${records.length}');
    return records;
  }

  /// 删除下载记录
  Future<void> deleteDownloadRecord(String infoHash) async {
    await isar.writeTxn(() async {
      await isar.downloadRecords.filter().infoHashEqualTo(infoHash).deleteAll();
    });
    debugPrint('Isar Cache: Delete DownloadRecord $infoHash');
  }
}
