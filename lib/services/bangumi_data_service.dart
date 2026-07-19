import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:mikan_player/src/rust/api/crawler.dart' as crawler;
import 'package:mikan_player/services/bangumi_request_mode_service.dart';

abstract interface class BangumiDataBackend {
  Future<int> buildSitesIndex();
  Future<bool> ensureCache({required BigInt maxAgeSecs});
  Future<bool> refreshCache();
  Future<crawler.BangumiDataCacheStatus> getStatus();
  Future<List<crawler.BangumiDataSiteEntry>> fetchSites(int bangumiId);
  Future<List<crawler.BangumiDataSiteEntry>> fetchSitesByMikan(int mikanId);
  Future<PlatformInt64?> lookupMikanId(int bangumiId);
}

class RustBangumiDataBackend implements BangumiDataBackend {
  const RustBangumiDataBackend();

  @override
  Future<int> buildSitesIndex() async =>
      (await crawler.buildSitesIndex()).toInt();

  @override
  Future<bool> ensureCache({required BigInt maxAgeSecs}) =>
      crawler.ensureBangumiDataCache(maxAgeSecs: maxAgeSecs);

  @override
  Future<bool> refreshCache() => crawler.refreshBangumiDataCache();

  @override
  Future<crawler.BangumiDataCacheStatus> getStatus() =>
      crawler.getBangumiDataCacheStatus();

  @override
  Future<List<crawler.BangumiDataSiteEntry>> fetchSites(int bangumiId) =>
      crawler.fetchBangumiDataSites(bangumiId: bangumiId);

  @override
  Future<List<crawler.BangumiDataSiteEntry>> fetchSitesByMikan(int mikanId) =>
      crawler.fetchBangumiDataSitesByMikan(mikanId: mikanId);

  @override
  Future<PlatformInt64?> lookupMikanId(int bangumiId) =>
      crawler.lookupMikanId(bangumiId: bangumiId);
}

class BangumiDataService {
  BangumiDataService._();

  static const int warmupMaxAgeSecs = 7 * 24 * 60 * 60;
  static Future<bool>? _sitesIndexReady;
  static BangumiDataBackend _backend = const RustBangumiDataBackend();

  static Future<bool> _ensureSitesIndexReady() {
    final existing = _sitesIndexReady;
    if (existing != null) return existing;

    late final Future<bool> future;
    future = (() async {
      try {
        final count = await _backend.buildSitesIndex();
        debugPrint('bangumi-data sites index ready: $count entries');
        return true;
      } catch (e) {
        debugPrint('bangumi-data sites index build failed (non-fatal): $e');
        if (identical(_sitesIndexReady, future)) {
          _sitesIndexReady = null;
        }
        return false;
      }
    })();
    _sitesIndexReady = future;
    return future;
  }

  static Future<void> warmup() async {
    try {
      final mode = await BangumiRequestModeService.load();
      if (mode == BangumiRequestMode.legacy) {
        return;
      }
      final downloaded = await _backend.ensureCache(
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
      final refreshed = await _backend.refreshCache();
      if (refreshed) {
        _sitesIndexReady = null;
        _ensureSitesIndexReady(); // fire-and-forget rebuild
      }
      return refreshed;
    } catch (e) {
      debugPrint('bangumi-data refresh failed: $e');
      return false;
    }
  }

  static Future<crawler.BangumiDataCacheStatus> getStatus() async {
    return _backend.getStatus();
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
      final ready = await _ensureSitesIndexReady();
      if (!ready) return const [];
      return await _backend.fetchSites(id);
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
      final ready = await _ensureSitesIndexReady();
      if (!ready) return const [];
      return await _backend.fetchSitesByMikan(id);
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
      final ready = await _ensureSitesIndexReady();
      if (!ready) return null;
      final result = await _backend.lookupMikanId(id);
      return result?.toString();
    } catch (e) {
      debugPrint('bangumi-data mikan id lookup failed (non-fatal): $e');
      return null;
    }
  }

  @visibleForTesting
  static void debugBindBackendForTest(BangumiDataBackend backend) {
    _backend = backend;
    _sitesIndexReady = null;
  }

  @visibleForTesting
  static void debugResetForTest() {
    _backend = const RustBangumiDataBackend();
    _sitesIndexReady = null;
  }
}
