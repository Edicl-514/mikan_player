import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 图片缓存服务
/// 负责将网络图片下载并缓存到本地文件系统
/// 兼容 Windows 和 Android
class ImageCacheService {
  static ImageCacheService? _instance;
  static ImageCacheService get instance {
    _instance ??= ImageCacheService._();
    return _instance!;
  }

  ImageCacheService._();

  Directory? _cacheDir;
  bool _isInitialized = false;
  final HttpClient _httpClient = HttpClient();

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化图片缓存服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _cacheDir = await _getImageCacheDirectory();
    
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
      // Android: 使用外部存储的应用专属目录
      final dirs = await getExternalStorageDirectories();
      if (dirs != null && dirs.isNotEmpty) {
        baseDir = dirs.first;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 桌面平台: 使用应用支持目录
      baseDir = await getApplicationSupportDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    return Directory('${baseDir.path}/image_cache');
  }

  /// 根据 URL 生成唯一的文件名
  String _generateFileName(String url) {
    final hash = md5.convert(url.codeUnits).toString();
    // 尝试从 URL 获取扩展名
    String ext = '.jpg';
    try {
      final uri = Uri.parse(url);
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
    return '${_cacheDir!.path}/$fileName';
  }

  /// 检查图片是否已缓存
  Future<bool> isCached(String url) async {
    final localPath = getLocalPath(url);
    return await File(localPath).exists();
  }

  /// 获取已缓存图片的本地路径，如果未缓存则返回 null
  Future<String?> getCachedPath(String url) async {
    final localPath = getLocalPath(url);
    final file = File(localPath);
    if (await file.exists()) {
      return localPath;
    }
    return null;
  }

  /// 下载并缓存图片，返回本地路径
  Future<String?> cacheImage(String url) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 检查是否已缓存
    final existingPath = await getCachedPath(url);
    if (existingPath != null) {
      return existingPath;
    }

    try {
      final localPath = getLocalPath(url);
      final bytes = await _downloadImage(url);
      
      if (bytes != null && bytes.isNotEmpty) {
        final file = File(localPath);
        await file.writeAsBytes(bytes);
        return localPath;
      }
    } catch (e) {
      debugPrint('Error caching image: $e');
    }
    
    return null;
  }

  /// 下载图片
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final request = await _httpClient.getUrl(uri);
      
      // 设置必要的请求头
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Referer', '${uri.scheme}://${uri.host}/');
      
      final response = await request.close();
      
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
          await file.delete();
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
              final fileSize = await file.length();
              await file.delete();
              currentSize -= fileSize;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }
}
