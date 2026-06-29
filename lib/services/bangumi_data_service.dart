import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/services/bangumi_request_mode_service.dart';

/// Manages the offline `bangumi-data` raw-data cache used as a fallback when
/// the bgmlist.com schedule API is unreachable.
///
/// The npm `bangumi-data` package is a flat ~7 MB JSON (hosted on unpkg/jsdelivr,
/// reachable from mainland China) that contains every show bgmlist knows about.
/// `fetch_schedule_basic` consults it only when the live API fails, so the cache
/// must be warm *before* it is needed — hence the startup warmup below, which
/// re-downloads at most once every [warmupMaxAgeSecs].
class BangumiDataService {
  BangumiDataService._();

  /// Re-download at most once per week. The data changes slowly and the cache
  /// is only a fallback, so a stale copy is still useful.
  static const int warmupMaxAgeSecs = 7 * 24 * 60 * 60;

  /// Ensure the cache exists and is fresh. Safe to call from app startup;
  /// failures are swallowed (the live API is the primary path anyway).
  /// No-op in legacy mode, which fetches the schedule via HTML and never
  /// reads this file.
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

  /// Force-refresh the cache regardless of age (e.g. from a settings button).
  /// Returns true on success.
  static Future<bool> refresh() async {
    try {
      return await crawler.refreshBangumiDataCache();
    } catch (e) {
      debugPrint('bangumi-data refresh failed: $e');
      return false;
    }
  }
}
