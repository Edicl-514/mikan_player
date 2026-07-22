import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mikan_player/services/bangumi_image_bridge.dart';
import 'package:mikan_player/utils/app_directories.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

/// 图片缓存服务
/// 负责将网络图片下载并缓存到本地文件系统
/// 兼容 Windows 和 Android
class ImageCacheService {
  static const int androidMaxDiskCacheSizeBytes = 128 << 20;

  static ImageCacheService? _instance;
  static ImageCacheService get instance {
    _instance ??= ImageCacheService._();
    return _instance!;
  }

  ImageCacheService._({HttpClient? httpClient, Directory? cacheDirectory})
    : _cacheDir = cacheDirectory,
      _httpClient =
          httpClient ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  Directory? _cacheDir;
  bool _isInitialized = false;
  final HttpClient _httpClient;
  final Map<String, Future<String?>> _inFlightDownloads = {};
  int _generation = 0;
  final LinkedHashMap<String, String> _memoryPathCache =
      LinkedHashMap<String, String>();
  static const int _maxMemoryCacheSize = 500;
  final Queue<Completer<void>> _downloadQueue = Queue<Completer<void>>();
  int _activeDownloads = 0;
  static const int _maxConcurrentDownloads = 4;

  @visibleForTesting
  factory ImageCacheService.forTesting({
    required Directory cacheDirectory,
    HttpClient? httpClient,
  }) {
    return ImageCacheService._(
      httpClient: httpClient,
      cacheDirectory: cacheDirectory,
    );
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化图片缓存服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_cacheDir == null) {
      final cacheDir = await _getImageCacheDirectory();
      await _migrateLegacyAndroidCache(cacheDir);
      _cacheDir = cacheDir;
    }

    // 确保目录存在
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    _isInitialized = true;
    debugPrint('ImageCacheService initialized at: ${_cacheDir!.path}');
  }

  /// 获取图片缓存目录（兼容 Windows 和 Android）
  Future<Directory> _getImageCacheDirectory() async {
    Directory baseDir;

    if (Platform.isAndroid) {
      // Android: 使用可由系统回收的应用专属外部缓存目录。
      final dirs = await getExternalCacheDirectories();
      if (dirs != null && dirs.isNotEmpty) {
        baseDir = dirs.first;
      } else {
        baseDir = await getTemporaryDirectory();
      }
    } else {
      // 桌面平台: 使用统一的应用数据目录
      baseDir = await AppDirectories.getUnifiedAppDataDirectory();
    }

    return Directory(p.join(baseDir.path, 'image_cache'));
  }

  Future<void> _migrateLegacyAndroidCache(Directory target) async {
    if (!Platform.isAndroid) return;

    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs == null || dirs.isEmpty) return;
      final legacy = Directory(p.join(dirs.first.path, 'image_cache'));
      if (p.equals(legacy.path, target.path) || !await legacy.exists()) return;
      await migrateCacheDirectory(legacy: legacy, target: target);
      debugPrint('Image cache migrated to: ${target.path}');
    } catch (e) {
      debugPrint('Failed to migrate legacy image cache (non-fatal): $e');
    }
  }

  @visibleForTesting
  static Future<void> migrateCacheDirectory({
    required Directory legacy,
    required Directory target,
  }) async {
    if (!await legacy.exists() || p.equals(legacy.path, target.path)) return;

    await target.parent.create(recursive: true);
    if (!await target.exists()) {
      try {
        await legacy.rename(target.path);
        return;
      } on FileSystemException {
        // Some Android storage providers do not support directory rename.
      }
    }

    await target.create(recursive: true);
    await for (final entity in legacy.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = p.relative(entity.path, from: legacy.path);
      final destinationPath = p.join(target.path, relativePath);
      if (entity is Directory) {
        await Directory(destinationPath).create(recursive: true);
        continue;
      }
      if (entity is! File) continue;

      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      if (await destination.exists()) {
        await entity.delete();
        continue;
      }

      try {
        await entity.rename(destination.path);
      } on FileSystemException {
        final modified = (await entity.stat()).modified;
        await entity.copy(destination.path);
        await destination.setLastModified(modified);
        await entity.delete();
      }
    }
    if (await legacy.exists()) {
      await legacy.delete(recursive: true);
    }
  }

  static String _normalizeCacheKey(String url) {
    return BangumiUrlRewriter.canonicalize(url);
  }

  /// 根据 URL 生成唯一的文件名
  String _generateFileName(String url) {
    final key = _normalizeCacheKey(url);
    final hash = md5.convert(key.codeUnits).toString();
    // 尝试从 URL 获取扩展名
    String ext = '.jpg';
    try {
      final uri = Uri.parse(key);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.png')) {
        ext = '.png';
      } else if (path.endsWith('.webp')) {
        ext = '.webp';
      } else if (path.endsWith('.gif')) {
        ext = '.gif';
      }
    } catch (_) {}
    return '$hash$ext';
  }

  /// 获取图片的本地缓存路径
  String getLocalPath(String url) {
    if (_cacheDir == null) {
      throw StateError('ImageCacheService not initialized');
    }
    final fileName = _generateFileName(url);
    return p.join(_cacheDir!.path, fileName);
  }

  /// 检查图片是否已缓存
  Future<bool> isCached(String url) async {
    final localPath = getLocalPath(url);
    return await File(localPath).exists();
  }

  void _putMemoryCache(String url, String path) {
    final key = _normalizeCacheKey(url);
    _memoryPathCache.remove(key);
    _memoryPathCache[key] = path;
    if (_memoryPathCache.length > _maxMemoryCacheSize) {
      _memoryPathCache.remove(_memoryPathCache.keys.first);
    }
  }

  void _evictMemoryPath(String path) {
    _memoryPathCache.removeWhere((_, cachedPath) => p.equals(cachedPath, path));
  }

  String? getCachedPathSync(String url) {
    final key = _normalizeCacheKey(url);
    final path = _memoryPathCache[key];
    if (path != null) {
      _putMemoryCache(key, path);
    }
    return path;
  }

  /// 获取已缓存图片的本地路径，如果未缓存则返回 null
  Future<String?> getCachedPath(String url) async {
    final localPath = getLocalPath(url);
    final file = File(localPath);
    if (await file.exists()) {
      _putMemoryCache(url, localPath);
      return localPath;
    }
    _memoryPathCache.remove(_normalizeCacheKey(url));
    return null;
  }

  /// 下载并缓存图片，返回本地路径
  Future<String?> cacheImage(String url) async {
    if (!_isInitialized) {
      await initialize();
    }

    final key = _normalizeCacheKey(url);

    // 检查是否已缓存
    final existingPath = await getCachedPath(key);
    if (existingPath != null) {
      return existingPath;
    }

    final inFlight = _inFlightDownloads[key];
    if (inFlight != null) {
      return inFlight;
    }

    final generation = _generation;
    final future = _cacheImageWithLimit(key, generation);
    _inFlightDownloads[key] = future;
    future.whenComplete(() {
      if (identical(_inFlightDownloads[key], future)) {
        _inFlightDownloads.remove(key);
      }
    });
    final result = await future;
    if (result != null) {
      _putMemoryCache(key, result);
    }
    return result;
  }

  Future<String?> _cacheImageWithLimit(String url, int generation) async {
    await _acquireDownloadSlot();
    try {
      final existingPath = await getCachedPath(url);
      if (existingPath != null) {
        debugPrint('[ImageCache] Loaded from cache: $url');
        return existingPath;
      }

      final localPath = getLocalPath(url);
      final downloadUrl = BangumiUrlRewriter.rewrite(url);
      final bytes = await _downloadImage(downloadUrl);

      if (bytes != null && bytes.isNotEmpty && generation == _generation) {
        final file = File(localPath);
        await file.writeAsBytes(bytes);
        _putMemoryCache(url, localPath);
        debugPrint('[ImageCache] Loaded from network: $url');
        return localPath;
      }
    } catch (e) {
      debugPrint('Error caching image: $e');
    } finally {
      _releaseDownloadSlot();
    }

    return null;
  }

  Future<void> _acquireDownloadSlot() {
    if (_activeDownloads < _maxConcurrentDownloads) {
      _activeDownloads++;
      return Future.value();
    }

    final completer = Completer<void>();
    _downloadQueue.add(completer);
    return completer.future;
  }

  void _releaseDownloadSlot() {
    if (_downloadQueue.isNotEmpty) {
      _downloadQueue.removeFirst().complete();
      return;
    }

    _activeDownloads--;
  }

  /// 下载图片
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final bangumiBytes = await BangumiImageBridge.fetchFromUrl(url);
      if (bangumiBytes != null && bangumiBytes.isNotEmpty) {
        return bangumiBytes;
      }

      final uri = Uri.parse(url);
      final request = await _httpClient.getUrl(uri);

      // 设置必要的请求头
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );
      request.headers.set('Referer', '${uri.origin}/');

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        return bytes;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
    return null;
  }

  /// 批量缓存图片
  Future<Map<String, String?>> cacheImages(List<String> urls) async {
    final results = <String, String?>{};

    // 并行下载，但限制并发数
    const maxConcurrent = 5;
    for (var i = 0; i < urls.length; i += maxConcurrent) {
      final batch = urls.skip(i).take(maxConcurrent);
      final futures = batch.map((url) async {
        final path = await cacheImage(url);
        return MapEntry(url, path);
      });

      final entries = await Future.wait(futures);
      results.addEntries(entries);
    }

    return results;
  }

  /// 删除单个缓存图片
  Future<bool> deleteImage(String url) async {
    try {
      final localPath = getLocalPath(url);
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        _evictMemoryPath(localPath);
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting cached image: $e');
    }
    return false;
  }

  /// 清空所有缓存图片
  Future<void> clearAll() async {
    try {
      _generation++;
      _inFlightDownloads.clear();
      _memoryPathCache.clear();
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return 0;
    }

    int totalSize = 0;
    try {
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
    return totalSize;
  }

  /// 获取缓存文件数量
  Future<int> getCacheCount() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return 0;
    }

    int count = 0;
    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          count++;
        }
      }
    } catch (e) {
      debugPrint('Error counting cache files: $e');
    }
    return count;
  }

  /// 清理旧的缓存（保留最近使用的）
  /// [maxAge] 最大保留天数
  /// [maxSize] 最大缓存大小（字节）
  Future<void> cleanupOldCache({int maxAgeDays = 30, int? maxSizeBytes}) async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return;
    }

    final now = DateTime.now();
    final maxAge = Duration(days: maxAgeDays);
    final filesToDelete = <File>[];

    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            filesToDelete.add(entity);
          }
        }
      }

      // 删除过期文件
      for (final file in filesToDelete) {
        try {
          final path = file.path;
          await file.delete();
          _evictMemoryPath(path);
        } catch (_) {}
      }

      // 如果指定了最大大小，继续删除直到满足条件
      if (maxSizeBytes != null) {
        var currentSize = await getCacheSize();
        if (currentSize > maxSizeBytes) {
          // 获取所有文件并按修改时间排序
          final files = <File>[];
          await for (final entity in _cacheDir!.list()) {
            if (entity is File) {
              files.add(entity);
            }
          }

          // 按修改时间排序（最旧的在前）
          files.sort((a, b) {
            final statA = a.statSync();
            final statB = b.statSync();
            return statA.modified.compareTo(statB.modified);
          });

          // 删除最旧的文件直到大小满足要求
          for (final file in files) {
            if (currentSize <= maxSizeBytes) break;

            try {
              final path = file.path;
              final fileSize = await file.length();
              await file.delete();
              _evictMemoryPath(path);
              currentSize -= fileSize;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }

  @visibleForTesting
  void debugCloseForTest() {
    _httpClient.close(force: true);
  }
}
