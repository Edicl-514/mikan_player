import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bangumi_cache_service.dart';
import 'image_cache_service.dart';
import 'models/bangumi_subject_cache.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/src/rust/api/ranking.dart';

/// 统一缓存管理器
/// 提供简化的缓存操作接口，整合数据库缓存和图片缓存
class CacheManager {
  static CacheManager? _instance;
  static CacheManager get instance {
    _instance ??= CacheManager._();
    return _instance!;
  }

  CacheManager._();

  final BangumiCacheService _dbCache = BangumiCacheService.instance;
  final ImageCacheService _imageCache = ImageCacheService.instance;

  bool _isInitialized = false;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化缓存系统
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _dbCache.initialize();
    await _imageCache.initialize();

    // 启动时清理过期缓存
    await _dbCache.clearExpired();

    _isInitialized = true;
    debugPrint('CacheManager initialized');
  }

  /// 关闭缓存系统
  Future<void> close() async {
    await _dbCache.close();
    _isInitialized = false;
  }

  // ==================== 时间表相关 ====================

  /// 获取时间表数据（三级优先策略）
  ///
  /// 1. SQLite 缓存 → 命中直接返回 (~ms)
  /// 2. 本地 bangumi-data.json → mmap 读取 (~22ms)
  /// 3. 并发: [下载+构建] vs [API请求] → 哪个先完成用哪个
  ///
  /// [quarter] 季度标识，如 "2024q1"
  Future<List<AnimeInfo>> getTimetable({
    required String quarter,
  }) async {
    // ---- Level 1: SQLite 缓存 ----
    final cache = await _dbCache.getTimetable(quarter);
    if (cache != null) {
      final cachedAnimes = _dbCache.animesFromTimetableCache(cache);
      if (cachedAnimes.isNotEmpty &&
          cachedAnimes.any(
            (anime) =>
                anime.broadcastDay != null && anime.broadcastDay!.isNotEmpty,
          )) {
        debugPrint('Timetable loaded from SQLite cache: $quarter');
        return cachedAnimes;
      }
      debugPrint('Timetable SQLite cache incomplete; trying Level 2');
    }

    // ---- Level 2: 本地 bangumi-data.json (不下载, 只 mmap 读) ----
    try {
      final localAnimes =
          await crawler.fetchScheduleBasicFromLocalJsonNodl(
        yearQuarter: quarter,
      );
      if (localAnimes.isNotEmpty) {
        debugPrint('Timetable loaded from local bangumi-data.json: $quarter');
        await _dbCache.saveTimetable(quarter, localAnimes);
        _cacheAnimeCovers(localAnimes);
        _refreshTimetableInBackground(quarter);
        return localAnimes;
      }
    } catch (e) {
      debugPrint('Local JSON read failed (non-fatal): $e');
    }

    // ---- Level 3: 并发 — API 请求 vs 下载+构建 ----
    debugPrint('Timetable: Level 3 — racing API vs download for $quarter');
    try {
      final animes = await _raceApiAndDownload(quarter);
      if (animes.isNotEmpty) {
        await _dbCache.saveTimetable(quarter, animes);
        _cacheAnimeCovers(animes);
      }
      return animes;
    } catch (e) {
      debugPrint('Timetable Level 3 failed, trying expired cache: $e');
      final expiredCache = await _dbCache.getTimetableIncludingExpired(
        quarter,
      );
      if (expiredCache != null) {
        debugPrint('Using expired cache for $quarter');
        return _dbCache.animesFromTimetableCache(expiredCache);
      }
      rethrow;
    }
  }

  /// 并发执行 API 请求和下载 bangumi-data.json 构建，哪个先完成用哪个。
  /// 后完成的那个仍然会保存缓存（供下次使用）。
  Future<List<AnimeInfo>> _raceApiAndDownload(String quarter) async {
    final apiFuture = _fetchFromApiWithTimeout(quarter);
    final downloadFuture = _fetchFromDownloadedJson(quarter);

    List<AnimeInfo>? apiResult;
    Object? apiError;
    List<AnimeInfo>? downloadResult;
    Object? downloadError;
    int completed = 0;

    final completer = Completer<List<AnimeInfo>>();

    void tryComplete() {
      // 第一个成功的直接返回
      if (!completer.isCompleted && apiResult != null) {
        completer.complete(apiResult!);
        return;
      }
      if (!completer.isCompleted && downloadResult != null && downloadResult!.isNotEmpty) {
        completer.complete(downloadResult!);
        return;
      }
      // 两个都完成了，都没有有效结果
      if (completed == 2 && !completer.isCompleted) {
        completer.completeError(
          apiError ?? downloadError ?? Exception('No data source available'),
        );
      }
    }

    apiFuture.then((animes) {
      apiResult = animes;
      completed++;
      tryComplete();
    }).catchError((e) {
      apiError = e;
      completed++;
      tryComplete();
    });

    downloadFuture.then((animes) {
      downloadResult = animes;
      completed++;
      tryComplete();
    }).catchError((e) {
      downloadError = e;
      completed++;
      tryComplete();
    });

    final animes = await completer.future;

    _saveLateResult(quarter, apiResult, downloadResult);

    return animes;
  }

  /// API 请求 (带较短超时, 因为有本地数据兜底)
  Future<List<AnimeInfo>> _fetchFromApiWithTimeout(String quarter) async {
    try {
      return await crawler.fetchScheduleBasic(
        yearQuarter: quarter,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Timetable API request failed/timed out: $e');
      rethrow;
    }
  }

  /// 下载 bangumi-data.json + 构建 + 过滤
  Future<List<AnimeInfo>> _fetchFromDownloadedJson(String quarter) async {
    try {
      return await crawler.fetchScheduleBasicFromLocalJson(
        yearQuarter: quarter,
      );
    } catch (e) {
      debugPrint('Timetable download+build failed: $e');
      rethrow;
    }
  }

  /// 后完成的路径把结果也存入缓存, 供下次 Level 1 直接命中
  void _saveLateResult(
    String quarter,
    List<AnimeInfo>? apiResult,
    List<AnimeInfo>? downloadResult,
  ) {
    // API 结果通常更新更全, 优先保存
    if (apiResult != null && apiResult.isNotEmpty) {
      _dbCache.saveTimetable(quarter, apiResult).catchError((e) {
        debugPrint('Late-saving API result failed: $e');
      });
    } else if (downloadResult != null && downloadResult.isNotEmpty) {
      _dbCache.saveTimetable(quarter, downloadResult).catchError((e) {
        debugPrint('Late-saving download result failed: $e');
      });
    }
  }

  /// Level 2 命中本地 JSON 后, 后台用 API 数据刷新缓存,
  /// 确保下次启动 SQLite 缓存是最新的。
  void _refreshTimetableInBackground(String quarter) {
    crawler.fetchScheduleBasic(yearQuarter: quarter).then((animes) {
      if (animes.isNotEmpty) {
        _dbCache.saveTimetable(quarter, animes).catchError((e) {
          debugPrint('Background timetable refresh save failed: $e');
        });
      }
    }).catchError((e) {
      debugPrint('Background timetable refresh failed (non-fatal): $e');
    });
  }

  /// 更新时间表缓存
  Future<void> updateTimetable(String quarter, List<AnimeInfo> animes) async {
    await _dbCache.saveTimetable(quarter, animes);
  }

  // ==================== 排行榜/索引相关 ====================

  /// 获取排行榜数据（优先从缓存）
  Future<List<RankingAnime>> getRanking({
    required String sortType,
    required int page,
    required Future<List<RankingAnime>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getRanking(sortType: sortType, page: page);
    if (cache != null) {
      debugPrint('Ranking loaded from cache: $sortType page $page');
      return _dbCache.rankingFromCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching ranking from network: $sortType page $page');
    try {
      final results = await _fetchWithEmptyRetry(
        fetchFromNetwork: fetchFromNetwork,
        retryOnEmpty: page == 1,
        label: 'Ranking $sortType page $page',
      );

      if (results.isEmpty) {
        debugPrint(
          'Ranking network returned empty; keeping cache untouched: $sortType page $page',
        );
        final expiredCache = await _dbCache.getRankingIncludingExpired(
          sortType: sortType,
          page: page,
        );
        if (expiredCache != null) {
          debugPrint('Using expired ranking cache: $sortType page $page');
          return _dbCache.rankingFromCache(expiredCache);
        }
        return results;
      }

      // 保存到缓存
      await _dbCache.saveRanking(
        sortType: sortType,
        page: page,
        results: results,
      );

      // 后台缓存封面图片
      _cacheRankingCovers(results);

      return results;
    } catch (e) {
      debugPrint('Network failed for ranking: $e');
      final expiredCache = await _dbCache.getRankingIncludingExpired(
        sortType: sortType,
        page: page,
      );
      if (expiredCache != null) {
        debugPrint('Using expired ranking cache: $sortType page $page');
        return _dbCache.rankingFromCache(expiredCache);
      }
      rethrow;
    }
  }

  /// 获取索引页数据（优先从缓存）
  Future<List<RankingAnime>> getBrowser({
    required String sortType,
    required String year,
    required List<String> tags,
    required int page,
    required Future<List<RankingAnime>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getRanking(
      sortType: sortType,
      year: year,
      tags: tags,
      page: page,
    );
    if (cache != null) {
      debugPrint('Browser loaded from cache: $sortType $year page $page');
      return _dbCache.rankingFromCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching browser from network: $sortType $year page $page');
    try {
      final results = await _fetchWithEmptyRetry(
        fetchFromNetwork: fetchFromNetwork,
        retryOnEmpty: page == 1,
        label: 'Browser $sortType $year page $page',
      );

      if (results.isEmpty) {
        debugPrint(
          'Browser network returned empty; keeping cache untouched: $sortType $year page $page',
        );
        final expiredCache = await _dbCache.getRankingIncludingExpired(
          sortType: sortType,
          year: year,
          tags: tags,
          page: page,
        );
        if (expiredCache != null) {
          debugPrint('Using expired browser cache: $sortType $year page $page');
          return _dbCache.rankingFromCache(expiredCache);
        }
        return results;
      }

      // 保存到缓存
      await _dbCache.saveRanking(
        sortType: sortType,
        year: year,
        tags: tags,
        page: page,
        results: results,
      );

      // 后台缓存封面图片
      _cacheRankingCovers(results);

      return results;
    } catch (e) {
      debugPrint('Network failed for browser: $e');
      final expiredCache = await _dbCache.getRankingIncludingExpired(
        sortType: sortType,
        year: year,
        tags: tags,
        page: page,
      );
      if (expiredCache != null) {
        debugPrint('Using expired browser cache: $sortType $year page $page');
        return _dbCache.rankingFromCache(expiredCache);
      }
      rethrow;
    }
  }

  Future<List<RankingAnime>> _fetchWithEmptyRetry({
    required Future<List<RankingAnime>> Function() fetchFromNetwork,
    required bool retryOnEmpty,
    required String label,
  }) async {
    final results = await fetchFromNetwork();
    if (!retryOnEmpty || results.isNotEmpty) return results;

    debugPrint('$label returned empty; retrying once');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return fetchFromNetwork();
  }

  // ==================== 角色相关 ====================

  /// 获取角色数据（优先从缓存）
  Future<List<BangumiCharacter>> getCharacters({
    required int subjectId,
    required Future<List<BangumiCharacter>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getCharacters(subjectId);
    if (cache.isNotEmpty) {
      debugPrint('Characters loaded from cache: $subjectId');
      return _dbCache.charactersFromCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching characters from network: $subjectId');
    try {
      final characters = await fetchFromNetwork();

      // 保存到缓存
      await _dbCache.saveCharacters(subjectId, characters);

      // 后台缓存角色图片
      _cacheCharacterImages(characters);

      return characters;
    } catch (e) {
      debugPrint('Network failed for characters: $e');
      rethrow;
    }
  }

  Future<List<BangumiCharacter>> getCachedCharacters(int subjectId) async {
    final cache = await _dbCache.getCharactersIncludingExpired(subjectId);
    if (cache.isEmpty) return const [];
    return _dbCache.charactersFromCache(cache);
  }

  // ==================== 关联条目相关 ====================

  /// 获取关联条目数据（优先从缓存）
  Future<List<BangumiRelatedSubject>> getRelations({
    required int subjectId,
    required Future<List<BangumiRelatedSubject>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getRelations(subjectId);
    if (cache.isNotEmpty) {
      debugPrint('Relations loaded from cache: $subjectId');
      return _dbCache.relationsFromCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching relations from network: $subjectId');
    try {
      final relations = await fetchFromNetwork();

      // 保存到缓存
      await _dbCache.saveRelations(subjectId, relations);

      // 后台缓存关联条目图片
      _cacheRelationImages(relations);

      return relations;
    } catch (e) {
      debugPrint('Network failed for relations: $e');
      rethrow;
    }
  }

  Future<List<BangumiRelatedSubject>> getCachedRelations(int subjectId) async {
    final cache = await _dbCache.getRelationsIncludingExpired(subjectId);
    if (cache.isEmpty) return const [];
    return _dbCache.relationsFromCache(cache);
  }

  // ==================== 剧集相关 ====================

  /// 获取剧集数据（优先从缓存，缓存每日零点过期）
  Future<List<BangumiEpisode>> getEpisodes({
    required int subjectId,
    required Future<List<BangumiEpisode>> Function() fetchFromNetwork,
  }) async {
    final cache = await _dbCache.getEpisodes(subjectId);
    if (cache.isNotEmpty) {
      debugPrint('Episodes loaded from cache: $subjectId');
      return cache;
    }

    debugPrint('Fetching episodes from network: $subjectId');
    try {
      final episodes = await fetchFromNetwork();
      if (episodes.isEmpty) {
        debugPrint(
          'Episodes network returned empty; keeping cache untouched: $subjectId',
        );
        final expiredCache = await _dbCache.getEpisodesIncludingExpired(
          subjectId,
        );
        if (expiredCache.isNotEmpty) {
          debugPrint('Using expired episodes cache: $subjectId');
          return expiredCache;
        }
        return episodes;
      }

      await _dbCache.saveEpisodes(subjectId, episodes);
      return episodes;
    } catch (e) {
      debugPrint('Network failed for episodes: $e');
      final expiredCache = await _dbCache.getEpisodesIncludingExpired(
        subjectId,
      );
      if (expiredCache.isNotEmpty) {
        debugPrint('Using expired episodes cache: $subjectId');
        return expiredCache;
      }
      rethrow;
    }
  }

  Future<List<BangumiEpisode>> getCachedEpisodes(int subjectId) {
    return _dbCache.getEpisodesIncludingExpired(subjectId);
  }

  // ==================== 人物相关 ====================

  /// 获取人物数据（优先从缓存）
  Future<List<BangumiPerson>> getPersons({
    required int subjectId,
    required Future<List<BangumiPerson>> Function() fetchFromNetwork,
  }) async {
    final cache = await _dbCache.getPersons(subjectId);
    if (cache.isNotEmpty) {
      debugPrint('Persons loaded from cache: $subjectId');
      return cache;
    }

    debugPrint('Fetching persons from network: $subjectId');
    try {
      final persons = await fetchFromNetwork();
      if (persons.isEmpty) {
        debugPrint(
          'Persons network returned empty; keeping cache untouched: $subjectId',
        );
        final expiredCache = await _dbCache.getPersonsIncludingExpired(
          subjectId,
        );
        if (expiredCache.isNotEmpty) {
          debugPrint('Using expired persons cache: $subjectId');
          return expiredCache;
        }
        return persons;
      }

      await _dbCache.savePersons(subjectId, persons);
      return persons;
    } catch (e) {
      debugPrint('Network failed for persons: $e');
      final expiredCache = await _dbCache.getPersonsIncludingExpired(subjectId);
      if (expiredCache.isNotEmpty) {
        debugPrint('Using expired persons cache: $subjectId');
        return expiredCache;
      }
      rethrow;
    }
  }

  Future<List<BangumiPerson>> getCachedPersons(int subjectId) {
    return _dbCache.getPersonsIncludingExpired(subjectId);
  }

  // ==================== 条目详情相关 ====================

  /// 获取条目详情（优先从缓存）
  /// 如果缓存存在且未过期，返回缓存的 AnimeInfo
  /// 否则返回 null，需要从网络获取
  Future<AnimeInfo?> getSubject(int bangumiId) async {
    final cache = await _dbCache.getSubject(bangumiId);
    if (cache == null) return null;

    return _subjectCacheToAnimeInfo(cache);
  }

  Future<AnimeInfo?> getCachedSubject(int bangumiId) async {
    final cache = await _dbCache.getSubjectIncludingExpired(bangumiId);
    if (cache == null) return null;

    return _subjectCacheToAnimeInfo(cache);
  }

  AnimeInfo _subjectCacheToAnimeInfo(BangumiSubjectCache cache) {
    // 将缓存转换为 AnimeInfo
    return AnimeInfo(
      title: cache.title,
      subTitle: cache.originalTitle,
      bangumiId: cache.bangumiId.toString(),
      mikanId: null,
      coverUrl: cache.imageLarge,
      siteUrl: null,
      broadcastDay: cache.airWeekday,
      broadcastTime: null,
      score: cache.score,
      rank: cache.rank,
      tags: cache.tagsJson != null
          ? List<String>.from(jsonDecode(cache.tagsJson!))
          : [],
      fullJson: cache.fullJson,
    );
  }

  /// 缓存 AnimeInfo 条目
  Future<void> cacheAnimeInfo(AnimeInfo anime) async {
    await _dbCache.cacheFromAnimeInfo(anime);

    // 缓存封面图片
    if (anime.coverUrl != null) {
      _imageCache.cacheImage(anime.coverUrl!);
    }
  }

  /// 批量缓存 AnimeInfo 条目
  Future<void> cacheAnimeInfos(List<AnimeInfo> animes) async {
    for (final anime in animes) {
      await _dbCache.cacheFromAnimeInfo(anime);
    }

    // 后台缓存封面图片
    _cacheAnimeCovers(animes);
  }

  // ==================== 图片相关 ====================

  /// 获取本地图片路径（如果已缓存）
  Future<String?> getLocalImagePath(String url) async {
    return await _imageCache.getCachedPath(url);
  }

  /// 缓存图片并返回本地路径
  Future<String?> cacheImage(String url) async {
    return await _imageCache.cacheImage(url);
  }

  /// 后台缓存 AnimeInfo 封面图片
  void _cacheAnimeCovers(List<AnimeInfo> animes) {
    final urls = animes
        .where((a) => a.coverUrl != null)
        .map((a) => a.coverUrl!)
        .toList();

    if (urls.isNotEmpty) {
      // 异步执行，不阻塞主流程
      Future.microtask(() async {
        await _imageCache.cacheImages(urls);
      });
    }
  }

  /// 后台缓存 RankingAnime 封面图片
  void _cacheRankingCovers(List<RankingAnime> animes) {
    final urls = animes
        .where((a) => a.coverUrl.isNotEmpty)
        .map((a) => a.coverUrl)
        .toList();

    if (urls.isNotEmpty) {
      Future.microtask(() async {
        await _imageCache.cacheImages(urls);
      });
    }
  }

  /// 后台缓存角色图片
  void _cacheCharacterImages(List<BangumiCharacter> characters) {
    final urls = characters
        .where((c) => c.images?.medium != null && c.images!.medium.isNotEmpty)
        .map((c) => c.images!.medium)
        .toList();

    if (urls.isNotEmpty) {
      Future.microtask(() async {
        await _imageCache.cacheImages(urls);
      });
    }
  }

  /// 后台缓存关联条目图片
  void _cacheRelationImages(List<BangumiRelatedSubject> relations) {
    final urls = relations
        .where((r) => r.image.isNotEmpty)
        .map((r) => r.image)
        .toList();

    if (urls.isNotEmpty) {
      Future.microtask(() async {
        await _imageCache.cacheImages(urls);
      });
    }
  }

  // ==================== 缓存管理 ====================

  /// 清空所有缓存
  Future<void> clearAll() async {
    await _dbCache.clearAll();
    await _imageCache.clearAll();
  }

  /// 清除过期缓存
  Future<void> clearExpired() async {
    await _dbCache.clearExpired();
    await _imageCache.cleanupOldCache();
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final dbStats = await _dbCache.getCacheStats();
    final imageCount = await _imageCache.getCacheCount();
    final imageSize = await _imageCache.getCacheSize();

    return {
      ...dbStats,
      'imageCount': imageCount,
      'imageSize': imageSize,
      'imageSizeFormatted': _formatBytes(imageSize),
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
