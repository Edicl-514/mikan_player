import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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

  /// Per-quarter chain of in-flight `saveTimetable` operations. Serializes
  /// the winner-save and the late-save from the API/download racer so the
  /// late result deterministically lands after the winner result. Without
  /// this, two concurrent `InsertMode.insertOrReplace` calls on the same
  /// quarter key race in SQLite and the final state depends on which
  /// commit lands last.
  final Map<String, Future<void>> _timetableSaveQueue =
      <String, Future<void>>{};

  void _runDetached(
    String label,
    Future<void> Function() task, {
    Duration delay = Duration.zero,
  }) {
    Future<void> runner() async {
      if (delay != Duration.zero) {
        debugPrint('$label scheduled after ${delay.inMilliseconds}ms');
        await Future<void>.delayed(delay);
      }
      debugPrint('$label started');
      await task();
      debugPrint('$label finished');
    }

    unawaited(
      runner().catchError((Object e, StackTrace stackTrace) {
        debugPrint('$label failed (non-fatal): $e');
        debugPrint('$stackTrace');
      }),
    );
  }

  /// Chain a save onto the per-quarter queue. Returns the chained future
  /// so callers can await or fire-and-forget it.
  Future<void> _enqueueTimetableSave(String quarter, List<AnimeInfo> animes) {
    final previous = _timetableSaveQueue[quarter] ?? Future<void>.value();
    debugPrint(
      '[Timetable] Queue save $quarter count=${animes.length} '
      'previousPending=${_timetableSaveQueue.containsKey(quarter)}',
    );
    final next = previous
        .then((_) => _dbCache.saveTimetable(quarter, animes))
        .catchError((e) {
          debugPrint('Timetable save failed for $quarter: $e');
        });
    _timetableSaveQueue[quarter] = next;
    // Self-cleaning: when the chain drains, drop the slot so the map
    // doesn't grow unbounded for long-lived processes browsing many
    // quarters.
    next.whenComplete(() {
      if (identical(_timetableSaveQueue[quarter], next)) {
        _timetableSaveQueue.remove(quarter);
        debugPrint('[Timetable] Save queue drained for $quarter');
      }
    });
    return next;
  }

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
  Future<List<AnimeInfo>> getTimetable({required String quarter}) async {
    // ---- Level 1: SQLite 缓存 ----
    final cache = await _dbCache.getTimetable(quarter);
    if (cache != null) {
      final cachedAnimes = _dbCache.animesFromTimetableCache(cache);
      if (cachedAnimes.isNotEmpty) {
        final withTitle = cachedAnimes.where((a) => a.title.isNotEmpty);
        final withBroadcast = cachedAnimes.where(
          (a) =>
              (a.broadcastDay != null && a.broadcastDay!.isNotEmpty) ||
              (a.broadcastTime != null && a.broadcastTime!.isNotEmpty),
        );
        // Require both a non-trivial sample size and a quality bar. Without
        // the `>= 3` floor, a single-row cache (write corruption / unit
        // test residue) would pass `length ~/ 2 == 0` and be shown as the
        // entire quarter.
        const minSample = 3;
        if (withTitle.length >= minSample &&
            withTitle.length >= cachedAnimes.length ~/ 2 &&
            withBroadcast.isNotEmpty) {
          debugPrint('Timetable loaded from SQLite cache: $quarter');
          return cachedAnimes;
        }
        debugPrint('Timetable SQLite cache incomplete; trying Level 2');
      }
    }

    // ---- Level 2: 本地 bangumi-data.json (不下载, 只 mmap 读) ----
    try {
      final localAnimes = await crawler.fetchScheduleBasicFromLocalJsonNodl(
        yearQuarter: quarter,
      );
      if (localAnimes.isNotEmpty) {
        debugPrint(
          'Timetable loaded from local bangumi-data.json: $quarter '
          'count=${localAnimes.length}',
        );
        unawaited(_enqueueTimetableSave(quarter, localAnimes));
        _cacheAnimeCovers(localAnimes);
        // Do not call crawler.spawnSitesIndexBackground() from Dart here.
        // That Rust API is synchronous and uses tokio::spawn internally;
        // when invoked through the sync FRB path on Android it can run
        // outside a Tokio runtime, panic, and abort the process in release.
        // Site lookups still self-heal lazily, and startup warmup uses the
        // async ensureBangumiDataCache path instead.
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
        // Winner-save goes through the per-quarter queue so the late-save
        // (API result) deterministically lands after this one. The
        // future is fire-and-forget; Level 1 on the next cold start
        // reads whatever the queue's last writer left.
        unawaited(_enqueueTimetableSave(quarter, animes));
        _cacheAnimeCovers(animes);
      }
      return animes;
    } catch (e) {
      debugPrint('Timetable Level 3 failed, trying expired cache: $e');
      final expiredCache = await _dbCache.getTimetableIncludingExpired(quarter);
      if (expiredCache != null) {
        debugPrint('Using expired cache for $quarter');
        return _dbCache.animesFromTimetableCache(expiredCache);
      }
      rethrow;
    }
  }

  /// 并发执行 API 请求和下载 bangumi-data.json 构建，哪个先完成用哪个。
  /// 两路完成后，非空的慢结果也会保存进缓存（供下次 Level 1 命中）。
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
      if (completer.isCompleted) return;
      if (apiResult != null && apiResult!.isNotEmpty) {
        completer.complete(apiResult!);
        return;
      }
      if (downloadResult != null && downloadResult!.isNotEmpty) {
        completer.complete(downloadResult!);
        return;
      }
      if (completed == 2) {
        completer.completeError(
          apiError ?? downloadError ?? Exception('No data source available'),
        );
      }
    }

    apiFuture
        .then((animes) {
          apiResult = animes;
          completed++;
          tryComplete();
        })
        .catchError((e) {
          apiError = e;
          completed++;
          tryComplete();
        });

    downloadFuture
        .then((animes) {
          downloadResult = animes;
          completed++;
          tryComplete();
        })
        .catchError((e) {
          downloadError = e;
          completed++;
          tryComplete();
        });

    final animes = await completer.future;

    // Fire-and-forget: wait for both futures to settle, then save the
    // non-empty late result into SQLite so the next cold start hits
    // Level 1. API result is saved preferentially (usually more complete).
    _saveLateResultAfterBothSettle(quarter, apiFuture, downloadFuture);

    return animes;
  }

  /// API-only 请求 (带较短超时, 因为有本地数据兜底)。
  /// 不带 Rust 侧的 local-JSON fallback，失败就直接抛异常。
  Future<List<AnimeInfo>> _fetchFromApiWithTimeout(String quarter) async {
    try {
      return await crawler
          .fetchScheduleBasicApiOnly(yearQuarter: quarter)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Timetable API request failed/timed out: $e');
      rethrow;
    }
  }

  /// 下载 bangumi-data.json + 构建 + 过滤
  ///
  /// `downloadMaxWait` 兜底：Rust 内部下载有 120s `reqwest` timeout 加上
  /// `retry_request` 的重试，单次下载极端情况可能跑几分钟；这里给个
  /// 总竞速上限，超时后让 `tryComplete` 走 "两路都失败" 分支，最终
  /// fallback 到 expired cache。
  static const Duration _downloadOverallTimeout = Duration(seconds: 60);

  Future<List<AnimeInfo>> _fetchFromDownloadedJson(String quarter) async {
    try {
      return await crawler
          .fetchScheduleBasicFromLocalJson(yearQuarter: quarter)
          .timeout(_downloadOverallTimeout);
    } on TimeoutException {
      debugPrint('Timetable download+build overall timeout');
      rethrow;
    } catch (e) {
      debugPrint('Timetable download+build failed: $e');
      rethrow;
    }
  }

  /// Wait for both API and download futures to settle, then save the
  /// non-empty late result. API result is preferred (usually more
  /// up-to-date). Called fire-and-forget after the first result wins.
  ///
  /// The save is enqueued on the per-quarter chain so it lands **after**
  /// the winner-save enqueued in `getTimetable`. This deterministically
  /// upgrades the cache from the winner to the API result when download
  /// won the race but API finished later — without the queue, two
  /// concurrent `insertOrReplace` calls on the same key race in SQLite
  /// and the final state is whichever commit lands last.
  void _saveLateResultAfterBothSettle(
    String quarter,
    Future<List<AnimeInfo>> apiFuture,
    Future<List<AnimeInfo>> downloadFuture,
  ) {
    Future.wait([
          apiFuture.catchError((_) => <AnimeInfo>[]),
          downloadFuture.catchError((_) => <AnimeInfo>[]),
        ])
        .then((results) {
          final api = results[0];
          final dl = results[1];
          if (api.isNotEmpty) {
            unawaited(_enqueueTimetableSave(quarter, api));
          } else if (dl.isNotEmpty) {
            unawaited(_enqueueTimetableSave(quarter, dl));
          }
        })
        .catchError((Object e, StackTrace stackTrace) {
          debugPrint('Late timetable save coordination failed: $e');
          debugPrint('$stackTrace');
        });
  }

  /// Level 2 命中本地 JSON 后, 后台用 API-only 数据刷新缓存,
  /// 确保下次启动 SQLite 缓存是最新的。API 失败就结束，不隐式下载。
  ///
  /// Routed through `_enqueueTimetableSave` so this background save
  /// serializes with the in-flight Level 2 winner-save chain (the user
  /// may have triggered another `getTimetable` for the same quarter by
  /// the time this API request finishes).
  void _refreshTimetableInBackground(String quarter) {
    crawler
        .fetchScheduleBasicApiOnly(yearQuarter: quarter)
        .then((animes) {
          debugPrint(
            'Background timetable refresh finished for $quarter '
            'count=${animes.length}',
          );
          if (animes.isNotEmpty) {
            unawaited(_enqueueTimetableSave(quarter, animes));
          }
        })
        .catchError((Object e) {
          debugPrint('Background timetable refresh failed (non-fatal): $e');
        });
  }

  /// 更新时间表缓存
  Future<void> updateTimetable(String quarter, List<AnimeInfo> animes) async {
    debugPrint(
      '[Timetable] updateTimetable requested $quarter count=${animes.length}',
    );
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
    debugPrint('[Timetable] cacheAnimeInfos start count=${animes.length}');
    for (final anime in animes) {
      await _dbCache.cacheFromAnimeInfo(anime);
    }

    // 后台缓存封面图片
    _cacheAnimeCovers(animes);
    debugPrint('[Timetable] cacheAnimeInfos done count=${animes.length}');
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
      _runDetached(
        'Anime cover cache count=${urls.length}',
        () => _imageCache.cacheImages(urls),
      );
    }
  }

  /// 后台缓存 RankingAnime 封面图片
  void _cacheRankingCovers(List<RankingAnime> animes) {
    final urls = animes
        .where((a) => a.coverUrl.isNotEmpty)
        .map((a) => a.coverUrl)
        .toList();

    if (urls.isNotEmpty) {
      _runDetached(
        'Ranking cover cache count=${urls.length}',
        () => _imageCache.cacheImages(urls),
      );
    }
  }

  /// 后台缓存角色图片
  void _cacheCharacterImages(List<BangumiCharacter> characters) {
    final urls = characters
        .where((c) => c.images?.medium != null && c.images!.medium.isNotEmpty)
        .map((c) => c.images!.medium)
        .toList();

    if (urls.isNotEmpty) {
      _runDetached(
        'Character image cache',
        () => _imageCache.cacheImages(urls),
      );
    }
  }

  /// 后台缓存关联条目图片
  void _cacheRelationImages(List<BangumiRelatedSubject> relations) {
    final urls = relations
        .where((r) => r.image.isNotEmpty)
        .map((r) => r.image)
        .toList();

    if (urls.isNotEmpty) {
      _runDetached('Relation image cache', () => _imageCache.cacheImages(urls));
    }
  }

  // ==================== 缓存管理 ====================

  /// 清空所有缓存
  Future<void> clearAll() async {
    await _dbCache.clearAll();
    await _imageCache.clearAll();
    await clearWebViewCookies();
  }

  /// 清除 WebView 的 Cookie 存储
  ///
  /// 调用 `flutter_inappwebview` 的 [CookieManager.deleteAllCookies],
  /// 把内置 WebView 的 cookie jar 整个清空。这样下次重新打开
  /// 验证/Captcha bypass 页面时，不会再携带上次的登录态或令牌。
  ///
  /// 平台支持度（来自 plugin 文档）：
  /// - Android: 支持
  /// - iOS: 支持
  /// - macOS: 支持
  /// - Windows: 支持
  /// - Linux / Web: plugin 在该平台不支持 CookieManager，会抛异常，
  ///   这里捕获后忽略即可。
  Future<void> clearWebViewCookies() async {
    try {
      final ok = await CookieManager().deleteAllCookies();
      debugPrint('WebView cookies cleared: $ok');
    } catch (e, stackTrace) {
      debugPrint('Failed to clear webview cookies (non-fatal): $e');
      debugPrint('$stackTrace');
    }
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
