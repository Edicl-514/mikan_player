import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@immutable
class PlatformCacheStats {
  const PlatformCacheStats({
    required this.htmlImageSize,
    required this.webViewCacheSize,
    required this.webViewStorageSize,
  });

  final int htmlImageSize;
  final int webViewCacheSize;
  final int webViewStorageSize;

  int get totalSize => htmlImageSize + webViewCacheSize + webViewStorageSize;
}

class PlatformCacheService {
  PlatformCacheService._();

  static final PlatformCacheService instance = PlatformCacheService._();

  Future<PlatformCacheStats> getStats() async {
    var htmlImageSize = 0;
    Directory? temporaryDirectory;
    try {
      temporaryDirectory = await getTemporaryDirectory();
      htmlImageSize = await directorySize(
        Directory(p.join(temporaryDirectory.path, DefaultCacheManager.key)),
      );
    } catch (e) {
      debugPrint('Failed to read HTML image cache size (non-fatal): $e');
    }

    var webViewCacheSize = 0;
    var webViewStorageSize = 0;
    if (Platform.isAndroid) {
      try {
        temporaryDirectory ??= await getTemporaryDirectory();
        webViewCacheSize = await directorySize(
          Directory(p.join(temporaryDirectory.path, 'WebView')),
        );
        webViewStorageSize = await directorySize(
          Directory(p.join(temporaryDirectory.parent.path, 'app_webview')),
        );
      } catch (e) {
        debugPrint('Failed to read WebView cache sizes (non-fatal): $e');
      }
    }

    return PlatformCacheStats(
      htmlImageSize: htmlImageSize,
      webViewCacheSize: webViewCacheSize,
      webViewStorageSize: webViewStorageSize,
    );
  }

  Future<void> clearAll() async {
    final failures = <String>[];
    await _clearStep('HTML image cache', _clearHtmlImageCache, failures);

    if (_supportsWebViewDataClear) {
      await _clearStep(
        'WebView HTTP cache',
        () => InAppWebViewController.clearAllCache(includeDiskFiles: true),
        failures,
      );
      await _clearStep(
        'WebView storage',
        WebStorageManager.instance().deleteAllData,
        failures,
      );
    }

    if (failures.isNotEmpty) {
      throw StateError('Failed to clear: ${failures.join(', ')}');
    }
  }

  bool get _supportsWebViewDataClear =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<void> _clearHtmlImageCache() async {
    await DefaultCacheManager().emptyCache();
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = Directory(
      p.join(temporaryDirectory.path, DefaultCacheManager.key),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _clearStep(
    String label,
    Future<void> Function() action,
    List<String> failures,
  ) async {
    try {
      await action();
    } catch (e, stackTrace) {
      failures.add(label);
      debugPrint('Failed to clear $label: $e');
      debugPrint('$stackTrace');
    }
  }

  @visibleForTesting
  static Future<int> directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;

    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Files may disappear while WebView performs its own cleanup.
        }
      }
    }
    return total;
  }
}
