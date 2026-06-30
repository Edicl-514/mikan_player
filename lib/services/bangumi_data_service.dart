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

  /// Look up all sites listed under `bangumiId` in the cached bangumi-data.
  /// Returns an empty list when the bangumi id is missing, unparseable, or
  /// not present in the cached payload — the UI should hide the section
  /// rather than show an error in that case.
  static Future<List<crawler.BangumiDataSiteEntry>> getSites(
    String? bangumiId,
  ) async {
    if (bangumiId == null || bangumiId.isEmpty) return const [];
    final id = int.tryParse(bangumiId);
    if (id == null) return const [];
    try {
      return await crawler.fetchBangumiDataSites(bangumiId: id);
    } catch (e) {
      debugPrint('bangumi-data sites lookup failed (non-fatal): $e');
      return const [];
    }
  }

  /// Mikan-origin lookup. Returns empty when mikan has no bangumi mapping.
  static Future<List<crawler.BangumiDataSiteEntry>> getSitesByMikan(
    String? mikanId,
  ) async {
    if (mikanId == null || mikanId.isEmpty) return const [];
    final id = int.tryParse(mikanId);
    if (id == null) return const [];
    try {
      return await crawler.fetchBangumiDataSitesByMikan(mikanId: id);
    } catch (e) {
      debugPrint('bangumi-data sites lookup by mikan failed: $e');
      return const [];
    }
  }

  /// Look up the mikan id for a given bangumi.tv subject id from the cached
  /// bangumi-data index. Returns `null` when the index has not been built,
  /// the bangumi id is missing/unparseable, or there is no mikan mapping.
  static Future<String?> getMikanId(String? bangumiId) async {
    if (bangumiId == null || bangumiId.isEmpty) return null;
    final id = int.tryParse(bangumiId);
    if (id == null) return null;
    try {
      final result = await crawler.lookupMikanId(bangumiId: id);
      return result?.toString();
    } catch (e) {
      debugPrint('bangumi-data mikan id lookup failed (non-fatal): $e');
      return null;
    }
  }
}
