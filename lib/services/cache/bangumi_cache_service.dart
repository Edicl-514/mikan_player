import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';

import 'models/bangumi_character_cache.dart';
import 'models/bangumi_episode_cache.dart';
import 'models/bangumi_person_cache.dart';
import 'models/bangumi_relation_cache.dart';
import 'models/bangumi_subject_cache.dart';
import 'models/download_record.dart';
import 'models/ranking_cache.dart';
import 'models/timetable_cache.dart';

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

  AppDatabase? _db;
  bool _isInitialized = false;

  AppDatabase get db {
    if (_db == null) {
      throw StateError(
        'BangumiCacheService not initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化缓存数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    _db = AppDatabase.instance;
    _isInitialized = true;
    debugPrint('BangumiCacheService initialized with Drift');
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    await db.transaction(() async {
      await db.delete(db.dbBangumiSubjectCaches).go();
      await db.delete(db.dbBangumiCharacterCaches).go();
      await db.delete(db.dbBangumiRelationCaches).go();
      await db.delete(db.dbTimetableCaches).go();
      await db.delete(db.dbRankingCaches).go();
      await db.delete(db.dbBangumiEpisodeCaches).go();
      await db.delete(db.dbBangumiPersonCaches).go();
      // NOTE: Do not clear downloadRecords here as they are user data
    });
  }

  /// 清除过期缓存
  Future<void> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await (db.delete(
        db.dbBangumiSubjectCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbBangumiCharacterCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbBangumiRelationCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbTimetableCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbRankingCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbBangumiEpisodeCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
      await (db.delete(
        db.dbBangumiPersonCaches,
      )..where((tbl) => tbl.expiresAt.isSmallerThanValue(now))).go();
    });
  }

  // ==================== 条目缓存操作 ====================

  /// 获取条目缓存
  Future<BangumiSubjectCache?> getSubject(int bangumiId) async {
    final cache = await _getSubjectRow(bangumiId);

    if (cache != null && !cache.isExpired) {
      debugPrint('Drift Cache: Hit Subject $bangumiId');
      return cache;
    }
    debugPrint('Drift Cache: Miss Subject $bangumiId');
    return null;
  }

  Future<BangumiSubjectCache?> getSubjectIncludingExpired(int bangumiId) async {
    final cache = await _getSubjectRow(bangumiId);

    if (cache != null) {
      if (cache.isExpired) {
        debugPrint('Drift Cache: Hit Subject (expired) $bangumiId');
      } else {
        debugPrint('Drift Cache: Hit Subject $bangumiId');
      }
      return cache;
    }
    debugPrint('Drift Cache: Miss Subject $bangumiId');
    return null;
  }

  Future<BangumiSubjectCache?> _getSubjectRow(int bangumiId) async {
    final row = await (db.select(
      db.dbBangumiSubjectCaches,
    )..where((tbl) => tbl.bangumiId.equals(bangumiId))).getSingleOrNull();
    return row == null ? null : _subjectFromRow(row);
  }

  /// 保存条目缓存
  Future<void> saveSubject(BangumiSubjectCache cache) async {
    await db
        .into(db.dbBangumiSubjectCaches)
        .insert(_subjectToCompanion(cache), mode: InsertMode.insertOrReplace);
    debugPrint('Drift Cache: Save Subject ${cache.bangumiId}');
  }

  /// 批量保存条目缓存
  Future<void> saveSubjects(List<BangumiSubjectCache> caches) async {
    await db.batch((batch) {
      batch.insertAll(
        db.dbBangumiSubjectCaches,
        caches.map(_subjectToCompanion).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
    debugPrint('Drift Cache: Save Subjects count=${caches.length}');
  }

  /// 从 AnimeInfo 创建并保存条目缓存
  Future<BangumiSubjectCache?> cacheFromAnimeInfo(AnimeInfo anime) async {
    if (anime.bangumiId == null) return null;

    final bangumiId = int.tryParse(anime.bangumiId!);
    if (bangumiId == null) return null;

    final existing = await getSubject(bangumiId);
    if (existing != null) {
      if (existing.fullJson != null) return existing;
      if (anime.fullJson == null) return existing;
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

    final existing = await getSubject(bangumiId);
    if (existing != null) return existing;

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
    final caches = await _getCharacterRows(subjectId);

    if (caches.isNotEmpty && !caches.first.isExpired) {
      debugPrint('Drift Cache: Hit Characters $subjectId');
      return caches;
    }
    debugPrint('Drift Cache: Miss Characters $subjectId');
    return [];
  }

  Future<List<BangumiCharacterCache>> getCharactersIncludingExpired(
    int subjectId,
  ) async {
    final caches = await _getCharacterRows(subjectId);

    if (caches.isNotEmpty) {
      if (caches.first.isExpired) {
        debugPrint('Drift Cache: Hit Characters (expired) $subjectId');
      } else {
        debugPrint('Drift Cache: Hit Characters $subjectId');
      }
      return caches;
    }
    debugPrint('Drift Cache: Miss Characters $subjectId');
    return [];
  }

  Future<List<BangumiCharacterCache>> _getCharacterRows(int subjectId) async {
    final rows = await (db.select(
      db.dbBangumiCharacterCaches,
    )..where((tbl) => tbl.subjectId.equals(subjectId))).get();
    return rows.map(_characterFromRow).toList();
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

    await db.transaction(() async {
      await (db.delete(
        db.dbBangumiCharacterCaches,
      )..where((tbl) => tbl.subjectId.equals(subjectId))).go();
      await db.batch((batch) {
        batch.insertAll(
          db.dbBangumiCharacterCaches,
          caches.map(_characterToCompanion).toList(),
        );
      });
    });
    debugPrint(
      'Drift Cache: Save Characters $subjectId count=${caches.length}',
    );
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
    final caches = await _getRelationRows(subjectId);

    if (caches.isNotEmpty && !caches.first.isExpired) {
      debugPrint('Drift Cache: Hit Relations $subjectId');
      return caches.where((c) => c.relatedSubjectId != -1).toList();
    }
    debugPrint('Drift Cache: Miss Relations $subjectId');
    return [];
  }

  Future<List<BangumiRelationCache>> getRelationsIncludingExpired(
    int subjectId,
  ) async {
    final caches = await _getRelationRows(subjectId);

    if (caches.isNotEmpty) {
      if (caches.first.isExpired) {
        debugPrint('Drift Cache: Hit Relations (expired) $subjectId');
      } else {
        debugPrint('Drift Cache: Hit Relations $subjectId');
      }
      return caches.where((c) => c.relatedSubjectId != -1).toList();
    }
    debugPrint('Drift Cache: Miss Relations $subjectId');
    return [];
  }

  Future<List<BangumiRelationCache>> _getRelationRows(int subjectId) async {
    final rows = await (db.select(
      db.dbBangumiRelationCaches,
    )..where((tbl) => tbl.sourceSubjectId.equals(subjectId))).get();
    return rows.map(_relationFromRow).toList();
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

    if (caches.isEmpty) {
      caches.add(
        BangumiRelationCache.create(
          sourceSubjectId: subjectId,
          relatedSubjectId: -1,
          name: '',
          relation: 'placeholder',
        ),
      );
    }

    await db.transaction(() async {
      await (db.delete(
        db.dbBangumiRelationCaches,
      )..where((tbl) => tbl.sourceSubjectId.equals(subjectId))).go();
      await db.batch((batch) {
        batch.insertAll(
          db.dbBangumiRelationCaches,
          caches.map(_relationToCompanion).toList(),
        );
      });
    });
    debugPrint(
      'Drift Cache: Save Relations $subjectId count=${relations.length}',
    );
  }

  /// 将缓存转换为 BangumiRelatedSubject
  List<BangumiRelatedSubject> relationsFromCache(
    List<BangumiRelationCache> caches,
  ) {
    return caches.where((cache) => cache.relatedSubjectId != -1).map((cache) {
      return BangumiRelatedSubject(
        id: cache.relatedSubjectId,
        name: cache.name,
        nameCn: cache.nameCn ?? '',
        relation: cache.relation,
        image: cache.imageUrl ?? '',
      );
    }).toList();
  }

  // ==================== 剧集缓存操作 ====================

  /// 获取条目的剧集缓存列表
  Future<List<BangumiEpisode>> getEpisodes(int subjectId) async {
    final cache = await _getEpisodeRow(subjectId);

    if (cache != null && !cache.isExpired) {
      debugPrint('Drift Cache: Hit Episodes $subjectId');
      return episodesFromCache(cache);
    }
    debugPrint('Drift Cache: Miss Episodes $subjectId');
    return [];
  }

  Future<List<BangumiEpisode>> getEpisodesIncludingExpired(
    int subjectId,
  ) async {
    final cache = await _getEpisodeRow(subjectId);

    if (cache != null) {
      if (cache.isExpired) {
        debugPrint('Drift Cache: Hit Episodes (expired) $subjectId');
      } else {
        debugPrint('Drift Cache: Hit Episodes $subjectId');
      }
      return episodesFromCache(cache);
    }
    debugPrint('Drift Cache: Miss Episodes $subjectId');
    return [];
  }

  Future<BangumiEpisodeCache?> _getEpisodeRow(int subjectId) async {
    final row = await (db.select(
      db.dbBangumiEpisodeCaches,
    )..where((tbl) => tbl.subjectId.equals(subjectId))).getSingleOrNull();
    return row == null ? null : _episodeFromRow(row);
  }

  /// 保存条目的剧集缓存，过期时间为下一个本地零点
  Future<void> saveEpisodes(
    int subjectId,
    List<BangumiEpisode> episodes,
  ) async {
    if (episodes.isEmpty) {
      debugPrint('Drift Cache: Skip empty Episodes $subjectId');
      return;
    }

    final episodesJson = jsonEncode(
      episodes
          .map(
            (ep) => {
              'id': ep.id,
              'name': ep.name,
              'nameCn': ep.nameCn,
              'description': ep.description,
              'airdate': ep.airdate,
              'duration': ep.duration,
              'sort': ep.sort,
            },
          )
          .toList(),
    );
    final cache = BangumiEpisodeCache.create(
      subjectId: subjectId,
      episodesJson: episodesJson,
    );

    await db
        .into(db.dbBangumiEpisodeCaches)
        .insert(_episodeToCompanion(cache), mode: InsertMode.insertOrReplace);
    debugPrint(
      'Drift Cache: Save Episodes $subjectId count=${episodes.length}',
    );
  }

  /// 将缓存转换为 BangumiEpisode 列表
  List<BangumiEpisode> episodesFromCache(BangumiEpisodeCache cache) {
    try {
      final list = jsonDecode(cache.episodesJson) as List;
      return list
          .map(
            (item) => BangumiEpisode(
              id: item['id'] ?? 0,
              name: item['name'] ?? '',
              nameCn: item['nameCn'] ?? '',
              description: item['description'] ?? '',
              airdate: item['airdate'] ?? '',
              duration: item['duration'] ?? '',
              sort: (item['sort'] ?? 0).toDouble(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error parsing episode cache: $e');
      return [];
    }
  }

  // ==================== 人物缓存操作 ====================

  /// 获取条目的人物缓存列表
  Future<List<BangumiPerson>> getPersons(int subjectId) async {
    final cache = await _getPersonRow(subjectId);

    if (cache != null && !cache.isExpired) {
      debugPrint('Drift Cache: Hit Persons $subjectId');
      return personsFromCache(cache);
    }
    debugPrint('Drift Cache: Miss Persons $subjectId');
    return [];
  }

  Future<List<BangumiPerson>> getPersonsIncludingExpired(int subjectId) async {
    final cache = await _getPersonRow(subjectId);

    if (cache != null) {
      if (cache.isExpired) {
        debugPrint('Drift Cache: Hit Persons (expired) $subjectId');
      } else {
        debugPrint('Drift Cache: Hit Persons $subjectId');
      }
      return personsFromCache(cache);
    }
    debugPrint('Drift Cache: Miss Persons $subjectId');
    return [];
  }

  Future<BangumiPersonCache?> _getPersonRow(int subjectId) async {
    final row = await (db.select(
      db.dbBangumiPersonCaches,
    )..where((tbl) => tbl.subjectId.equals(subjectId))).getSingleOrNull();
    return row == null ? null : _personFromRow(row);
  }

  /// 保存条目的人物缓存
  Future<void> savePersons(int subjectId, List<BangumiPerson> persons) async {
    if (persons.isEmpty) {
      debugPrint('Drift Cache: Skip empty Persons $subjectId');
      return;
    }

    final personsJson = jsonEncode(
      persons
          .map(
            (person) => {
              'id': person.id,
              'name': person.name,
              'relation': person.relation,
              'career': person.career,
              'personType': person.personType,
              'images': person.images == null
                  ? null
                  : {
                      'small': person.images!.small,
                      'grid': person.images!.grid,
                      'large': person.images!.large,
                      'medium': person.images!.medium,
                      'common': person.images!.common,
                    },
            },
          )
          .toList(),
    );

    final cache = BangumiPersonCache.create(
      subjectId: subjectId,
      personsJson: personsJson,
    );

    await db
        .into(db.dbBangumiPersonCaches)
        .insert(_personToCompanion(cache), mode: InsertMode.insertOrReplace);
    debugPrint('Drift Cache: Save Persons $subjectId count=${persons.length}');
  }

  /// 将缓存转换为 BangumiPerson 列表
  List<BangumiPerson> personsFromCache(BangumiPersonCache cache) {
    try {
      final list = jsonDecode(cache.personsJson) as List;
      return list
          .map(
            (item) => BangumiPerson(
              id: item['id'] ?? 0,
              name: item['name'] ?? '',
              relation: item['relation'] ?? '',
              career: (item['career'] as List?)?.cast<String>() ?? const [],
              personType: item['personType'] ?? 0,
              images: item['images'] == null
                  ? null
                  : BangumiImages(
                      small: item['images']['small'] ?? '',
                      grid: item['images']['grid'] ?? '',
                      large: item['images']['large'] ?? '',
                      medium: item['images']['medium'] ?? '',
                      common: item['images']['common'] ?? '',
                    ),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error parsing person cache: $e');
      return [];
    }
  }

  // ==================== 时间表缓存操作 ====================

  /// 获取时间表缓存
  Future<TimetableCache?> getTimetable(String quarter) async {
    final cache = await _getTimetableRow(quarter);

    if (cache != null && !cache.isExpired) {
      debugPrint('Drift Cache: Hit Timetable $quarter');
      return cache;
    }
    debugPrint('Drift Cache: Miss Timetable $quarter');
    return null;
  }

  /// 获取时间表缓存（包括已过期的）
  /// 用于离线模式或网络失败时的降级方案
  Future<TimetableCache?> getTimetableIncludingExpired(String quarter) async {
    final cache = await _getTimetableRow(quarter);

    if (cache != null) {
      if (cache.isExpired) {
        debugPrint('Drift Cache: Hit Timetable (expired) $quarter');
      } else {
        debugPrint('Drift Cache: Hit Timetable $quarter');
      }
      return cache;
    }
    debugPrint('Drift Cache: Miss Timetable $quarter');
    return null;
  }

  Future<TimetableCache?> _getTimetableRow(String quarter) async {
    final row = await (db.select(
      db.dbTimetableCaches,
    )..where((tbl) => tbl.quarter.equals(quarter))).getSingleOrNull();
    return row == null ? null : _timetableFromRow(row);
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

    await db
        .into(db.dbTimetableCaches)
        .insert(_timetableToCompanion(cache), mode: InsertMode.insertOrReplace);
    debugPrint('Drift Cache: Save Timetable $quarter');
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
    return _getRankingCache(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
      includeExpired: false,
    );
  }

  /// 获取排行榜缓存（包括已过期的）
  /// 用于网络失败或空响应时的降级方案
  Future<RankingCache?> getRankingIncludingExpired({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
  }) async {
    return _getRankingCache(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
      includeExpired: true,
    );
  }

  Future<RankingCache?> _getRankingCache({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
    required bool includeExpired,
  }) async {
    final key = RankingCache.generateKey(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
    );

    final row = await (db.select(
      db.dbRankingCaches,
    )..where((tbl) => tbl.cacheKey.equals(key))).getSingleOrNull();
    final cache = row == null ? null : _rankingFromRow(row);

    if (cache == null) {
      debugPrint('Drift Cache: Miss Ranking $key');
      return null;
    }

    if (!_rankingCacheHasResults(cache)) {
      debugPrint('Drift Cache: Drop empty Ranking $key');
      await deleteRanking(
        sortType: sortType,
        year: year,
        tags: tags,
        page: page,
      );
      return null;
    }

    if (includeExpired || !cache.isExpired) {
      if (cache.isExpired) {
        debugPrint('Drift Cache: Hit Ranking (expired) $key');
      } else {
        debugPrint('Drift Cache: Hit Ranking $key');
      }
      return cache;
    }

    debugPrint('Drift Cache: Miss Ranking $key');
    return null;
  }

  bool _rankingCacheHasResults(RankingCache cache) {
    try {
      final list = jsonDecode(cache.resultsJson);
      return list is List && list.isNotEmpty;
    } catch (e) {
      debugPrint('Error parsing ranking cache metadata: $e');
      return false;
    }
  }

  /// 保存排行榜缓存
  Future<void> saveRanking({
    required String sortType,
    String? year,
    List<String>? tags,
    required int page,
    required List<RankingAnime> results,
  }) async {
    if (results.isEmpty) {
      debugPrint(
        'Drift Cache: Skip empty Ranking ${RankingCache.generateKey(sortType: sortType, year: year, tags: tags, page: page)}',
      );
      return;
    }

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

    await db
        .into(db.dbRankingCaches)
        .insert(_rankingToCompanion(cache), mode: InsertMode.insertOrReplace);
    debugPrint('Drift Cache: Save Ranking ${cache.cacheKey}');
  }

  /// 删除单个排行榜/索引缓存
  Future<void> deleteRanking({
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
    await (db.delete(
      db.dbRankingCaches,
    )..where((tbl) => tbl.cacheKey.equals(key))).go();
    debugPrint('Drift Cache: Delete Ranking $key');
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
      'subjects': await _count(db.dbBangumiSubjectCaches),
      'characters': await _count(db.dbBangumiCharacterCaches),
      'relations': await _count(db.dbBangumiRelationCaches),
      'timetables': await _count(db.dbTimetableCaches),
      'rankings': await _count(db.dbRankingCaches),
      'episodes': await _count(db.dbBangumiEpisodeCaches),
      'persons': await _count(db.dbBangumiPersonCaches),
      'downloadRecords': await _count(db.dbDownloadRecords),
    };
  }

  Future<int> _count(TableInfo<Table, Object?> table) async {
    final countExp = table.$columns.first.count();
    return (db.selectOnly(table)..addColumns([countExp]))
        .map((row) => row.read(countExp) ?? 0)
        .getSingle();
  }

  // ==================== 下载记录操作 ====================

  /// 获取下载记录
  Future<DownloadRecord?> getDownloadRecord(String infoHash) async {
    final row = await (db.select(
      db.dbDownloadRecords,
    )..where((tbl) => tbl.infoHash.equals(infoHash))).getSingleOrNull();
    final record = row == null ? null : _downloadRecordFromRow(row);
    if (record != null) {
      debugPrint('Drift Cache: Hit DownloadRecord $infoHash');
    } else {
      debugPrint('Drift Cache: Miss DownloadRecord $infoHash');
    }
    return record;
  }

  /// 保存下载记录
  Future<void> saveDownloadRecord(DownloadRecord record) async {
    await db
        .into(db.dbDownloadRecords)
        .insert(
          _downloadRecordToCompanion(record),
          mode: InsertMode.insertOrReplace,
        );
    debugPrint('Drift Cache: Save DownloadRecord ${record.infoHash}');
  }

  /// 查找已完成的下载
  Future<DownloadRecord?> findCompletedDownload(
    String animeName,
    int episodeNumber,
  ) async {
    final row =
        await (db.select(db.dbDownloadRecords)..where(
              (tbl) =>
                  tbl.animeName.equals(animeName) &
                  tbl.episodeNumber.equals(episodeNumber) &
                  tbl.status.equals(1),
            ))
            .getSingleOrNull();
    final record = row == null ? null : _downloadRecordFromRow(row);

    if (record != null) {
      debugPrint(
        'Drift Cache: Hit CompletedDownload $animeName $episodeNumber',
      );
    } else {
      debugPrint(
        'Drift Cache: Miss CompletedDownload $animeName $episodeNumber',
      );
    }
    return record;
  }

  /// 获取所有下载记录
  Future<List<DownloadRecord>> getAllDownloadRecords() async {
    final rows = await db.select(db.dbDownloadRecords).get();
    final records = rows.map(_downloadRecordFromRow).toList();
    debugPrint('Drift Cache: Get AllDownloadRecords count=${records.length}');
    return records;
  }

  /// 删除下载记录
  Future<void> deleteDownloadRecord(String infoHash) async {
    await (db.delete(
      db.dbDownloadRecords,
    )..where((tbl) => tbl.infoHash.equals(infoHash))).go();
    debugPrint('Drift Cache: Delete DownloadRecord $infoHash');
  }

  DbBangumiSubjectCachesCompanion _subjectToCompanion(
    BangumiSubjectCache cache,
  ) {
    return DbBangumiSubjectCachesCompanion.insert(
      bangumiId: cache.bangumiId,
      title: cache.title,
      titleCn: Value(cache.titleCn),
      originalTitle: Value(cache.originalTitle),
      description: Value(cache.description),
      score: Value(cache.score),
      rank: Value(cache.rank),
      imageSmall: Value(cache.imageSmall),
      imageGrid: Value(cache.imageGrid),
      imageLarge: Value(cache.imageLarge),
      imageMedium: Value(cache.imageMedium),
      imageCommon: Value(cache.imageCommon),
      localImagePath: Value(cache.localImagePath),
      airDate: Value(cache.airDate),
      airWeekday: Value(cache.airWeekday),
      tagsJson: Value(cache.tagsJson),
      fullJson: Value(cache.fullJson),
      type: Value(cache.type),
      totalEpisodes: Value(cache.totalEpisodes),
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  BangumiSubjectCache _subjectFromRow(DbBangumiSubjectCache row) {
    return BangumiSubjectCache()
      ..id = row.id
      ..bangumiId = row.bangumiId
      ..title = row.title
      ..titleCn = row.titleCn
      ..originalTitle = row.originalTitle
      ..description = row.description
      ..score = row.score
      ..rank = row.rank
      ..imageSmall = row.imageSmall
      ..imageGrid = row.imageGrid
      ..imageLarge = row.imageLarge
      ..imageMedium = row.imageMedium
      ..imageCommon = row.imageCommon
      ..localImagePath = row.localImagePath
      ..airDate = row.airDate
      ..airWeekday = row.airWeekday
      ..tagsJson = row.tagsJson
      ..fullJson = row.fullJson
      ..type = row.type
      ..totalEpisodes = row.totalEpisodes
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbBangumiCharacterCachesCompanion _characterToCompanion(
    BangumiCharacterCache cache,
  ) {
    return DbBangumiCharacterCachesCompanion.insert(
      subjectId: cache.subjectId,
      characterId: cache.characterId,
      name: cache.name,
      roleName: cache.roleName,
      imageSmall: Value(cache.imageSmall),
      imageGrid: Value(cache.imageGrid),
      imageLarge: Value(cache.imageLarge),
      imageMedium: Value(cache.imageMedium),
      imageCommon: Value(cache.imageCommon),
      localImagePath: Value(cache.localImagePath),
      actorsJson: Value(cache.actorsJson),
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  BangumiCharacterCache _characterFromRow(DbBangumiCharacterCache row) {
    return BangumiCharacterCache()
      ..id = row.id
      ..subjectId = row.subjectId
      ..characterId = row.characterId
      ..name = row.name
      ..roleName = row.roleName
      ..imageSmall = row.imageSmall
      ..imageGrid = row.imageGrid
      ..imageLarge = row.imageLarge
      ..imageMedium = row.imageMedium
      ..imageCommon = row.imageCommon
      ..localImagePath = row.localImagePath
      ..actorsJson = row.actorsJson
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbBangumiRelationCachesCompanion _relationToCompanion(
    BangumiRelationCache cache,
  ) {
    return DbBangumiRelationCachesCompanion.insert(
      sourceSubjectId: cache.sourceSubjectId,
      relatedSubjectId: cache.relatedSubjectId,
      name: cache.name,
      nameCn: Value(cache.nameCn),
      relation: cache.relation,
      imageUrl: Value(cache.imageUrl),
      localImagePath: Value(cache.localImagePath),
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  BangumiRelationCache _relationFromRow(DbBangumiRelationCache row) {
    return BangumiRelationCache()
      ..id = row.id
      ..sourceSubjectId = row.sourceSubjectId
      ..relatedSubjectId = row.relatedSubjectId
      ..name = row.name
      ..nameCn = row.nameCn
      ..relation = row.relation
      ..imageUrl = row.imageUrl
      ..localImagePath = row.localImagePath
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbTimetableCachesCompanion _timetableToCompanion(TimetableCache cache) {
    return DbTimetableCachesCompanion.insert(
      quarter: cache.quarter,
      animesJson: cache.animesJson,
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  TimetableCache _timetableFromRow(DbTimetableCache row) {
    return TimetableCache()
      ..id = row.id
      ..quarter = row.quarter
      ..animesJson = row.animesJson
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbRankingCachesCompanion _rankingToCompanion(RankingCache cache) {
    return DbRankingCachesCompanion.insert(
      cacheKey: cache.cacheKey,
      sortType: cache.sortType,
      year: Value(cache.year),
      tagsJson: Value(cache.tagsJson),
      page: cache.page,
      resultsJson: cache.resultsJson,
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  RankingCache _rankingFromRow(DbRankingCache row) {
    return RankingCache()
      ..id = row.id
      ..cacheKey = row.cacheKey
      ..sortType = row.sortType
      ..year = row.year
      ..tagsJson = row.tagsJson
      ..page = row.page
      ..resultsJson = row.resultsJson
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbBangumiEpisodeCachesCompanion _episodeToCompanion(
    BangumiEpisodeCache cache,
  ) {
    return DbBangumiEpisodeCachesCompanion.insert(
      subjectId: cache.subjectId,
      episodesJson: cache.episodesJson,
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  BangumiEpisodeCache _episodeFromRow(DbBangumiEpisodeCache row) {
    return BangumiEpisodeCache()
      ..id = row.id
      ..subjectId = row.subjectId
      ..episodesJson = row.episodesJson
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbBangumiPersonCachesCompanion _personToCompanion(BangumiPersonCache cache) {
    return DbBangumiPersonCachesCompanion.insert(
      subjectId: cache.subjectId,
      personsJson: cache.personsJson,
      cachedAt: cache.cachedAt,
      expiresAt: cache.expiresAt,
    );
  }

  BangumiPersonCache _personFromRow(DbBangumiPersonCache row) {
    return BangumiPersonCache()
      ..id = row.id
      ..subjectId = row.subjectId
      ..personsJson = row.personsJson
      ..cachedAt = row.cachedAt
      ..expiresAt = row.expiresAt;
  }

  DbDownloadRecordsCompanion _downloadRecordToCompanion(DownloadRecord record) {
    return DbDownloadRecordsCompanion.insert(
      infoHash: record.infoHash,
      magnet: record.magnet,
      name: Value(record.name),
      animeName: Value(record.animeName),
      bangumiId: Value(record.bangumiId),
      episodeNumber: Value(record.episodeNumber),
      status: record.status,
      filePath: Value(record.filePath),
      totalSize: record.totalSize,
      downloaded: record.downloaded,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  DownloadRecord _downloadRecordFromRow(DbDownloadRecord row) {
    return DownloadRecord()
      ..id = row.id
      ..infoHash = row.infoHash
      ..magnet = row.magnet
      ..name = row.name
      ..animeName = row.animeName
      ..bangumiId = row.bangumiId
      ..episodeNumber = row.episodeNumber
      ..status = row.status
      ..filePath = row.filePath
      ..totalSize = row.totalSize
      ..downloaded = row.downloaded
      ..createdAt = row.createdAt
      ..updatedAt = row.updatedAt;
  }
}
