import 'package:flutter/foundation.dart';

import 'bangumi_cache_service.dart';
import 'image_cache_service.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
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

  /// 获取时间表数据（优先从缓存）
  /// [quarter] 季度标识，如 "2024q1"
  /// [fetchFromNetwork] 网络获取函数
  Future<List<AnimeInfo>> getTimetable({
    required String quarter,
    required Future<List<AnimeInfo>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getTimetable(quarter);
    if (cache != null) {
      debugPrint('Timetable loaded from cache: $quarter');
      return _dbCache.animesFromTimetableCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching timetable from network: $quarter');
    final animes = await fetchFromNetwork();
    
    // 保存到缓存
    await _dbCache.saveTimetable(quarter, animes);
    
    // 后台缓存封面图片
    _cacheAnimeCovers(animes);
    
    return animes;
  }

  // ==================== 排行榜/索引相关 ====================

  /// 获取排行榜数据（优先从缓存）
  Future<List<RankingAnime>> getRanking({
    required String sortType,
    required int page,
    required Future<List<RankingAnime>> Function() fetchFromNetwork,
  }) async {
    // 尝试从缓存获取
    final cache = await _dbCache.getRanking(
      sortType: sortType,
      page: page,
    );
    if (cache != null) {
      debugPrint('Ranking loaded from cache: $sortType page $page');
      return _dbCache.rankingFromCache(cache);
    }

    // 从网络获取
    debugPrint('Fetching ranking from network: $sortType page $page');
    final results = await fetchFromNetwork();
    
    // 保存到缓存
    await _dbCache.saveRanking(
      sortType: sortType,
      page: page,
      results: results,
    );
    
    // 后台缓存封面图片
    _cacheRankingCovers(results);
    
    return results;
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
    final results = await fetchFromNetwork();
    
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
    final characters = await fetchFromNetwork();
    
    // 保存到缓存
    await _dbCache.saveCharacters(subjectId, characters);
    
    // 后台缓存角色图片
    _cacheCharacterImages(characters);
    
    return characters;
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
    final relations = await fetchFromNetwork();
    
    // 保存到缓存
    await _dbCache.saveRelations(subjectId, relations);
    
    // 后台缓存关联条目图片
    _cacheRelationImages(relations);
    
    return relations;
  }

  // ==================== 条目详情相关 ====================

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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
