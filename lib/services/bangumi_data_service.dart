import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/services/bangumi_request_mode_service.dart';

class BangumiDataService {
  BangumiDataService._();

  static const int warmupMaxAgeSecs = 7 * 24 * 60 * 60;

  static Future<void> warmup() async {
    try {
      final mode = await BangumiRequestModeService.load();
      if (mode == BangumiRequestMode.legacy) {
        return;
      }
      final downloaded = await crawler.ensureBangumiDataCache(
        maxAgeSecs: BigInt.from(warmupMaxAgeSecs),
      );
      if (downloaded) {
        debugPrint('bangumi-data cache refreshed in background');
      }
    } catch (e) {
      debugPrint('bangumi-data warmup failed (non-fatal): $e');
    }
  }

  static Future<bool> refresh() async {
    try {
      return await crawler.refreshBangumiDataCache();
    } catch (e) {
      debugPrint('bangumi-data refresh failed: $e');
      return false;
    }
  }

  static Future<crawler.BangumiDataCacheStatus> getStatus() async {
    return crawler.getBangumiDataCacheStatus();
  }
}
