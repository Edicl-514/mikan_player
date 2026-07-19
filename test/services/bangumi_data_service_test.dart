import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBangumiDataBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBangumiDataBackend();
    BangumiDataService.debugBindBackendForTest(backend);
    BangumiRequestModeService.notifier.value = BangumiRequestMode.hybrid;
  });

  tearDown(BangumiDataService.debugResetForTest);

  test(
    'warmup skips legacy mode and uses the documented max age otherwise',
    () async {
      SharedPreferences.setMockInitialValues({
        BangumiRequestModeService.preferenceKey: 'legacy',
      });
      await BangumiDataService.warmup();
      expect(backend.ensureAges, isEmpty);

      SharedPreferences.setMockInitialValues({
        BangumiRequestModeService.preferenceKey: 'hybrid',
      });
      backend.ensureResult = true;
      await BangumiDataService.warmup();

      expect(backend.ensureAges, [
        BigInt.from(BangumiDataService.warmupMaxAgeSecs),
      ]);
    },
  );

  test(
    'warmup and refresh convert backend failures to non-fatal results',
    () async {
      backend.ensureError = StateError('offline');
      await expectLater(BangumiDataService.warmup(), completes);

      backend.refreshError = StateError('offline');
      expect(await BangumiDataService.refresh(), isFalse);
    },
  );

  test('refresh true invalidates and rebuilds the site index', () async {
    backend.refreshResult = true;

    expect(await BangumiDataService.refresh(), isTrue);
    await pumpEventQueue();

    expect(backend.buildCalls, 1);
  });

  test('refresh false does not start an index rebuild', () async {
    backend.refreshResult = false;

    expect(await BangumiDataService.refresh(), isFalse);
    await pumpEventQueue();

    expect(backend.buildCalls, 0);
  });

  test('invalid ids return empty/null without building the index', () async {
    expect(await BangumiDataService.getSites(null), isEmpty);
    expect(await BangumiDataService.getSites(''), isEmpty);
    expect(await BangumiDataService.getSites('abc'), isEmpty);
    expect(await BangumiDataService.getSitesByMikan('x'), isEmpty);
    expect(await BangumiDataService.getMikanId('1.5'), isNull);
    expect(backend.buildCalls, 0);
  });

  test('concurrent lookups share one index build', () async {
    final build = Completer<int>();
    backend.onBuild = () => build.future;
    backend.sites[12] = const [
      BangumiDataSiteEntry(
        site: 'mikan',
        title: 'Title',
        url: 'https://mikan.example/12',
        kind: 'onair',
      ),
    ];
    backend.mikanIds[12] = 34;

    final sitesFuture = BangumiDataService.getSites('12');
    final mikanFuture = BangumiDataService.getMikanId('12');
    await pumpEventQueue();
    expect(backend.buildCalls, 1);
    build.complete(10);

    expect(await sitesFuture, backend.sites[12]);
    expect(await mikanFuture, '34');
    expect(backend.buildCalls, 1);
  });

  test('failed index build returns fallback and can retry later', () async {
    var attempts = 0;
    backend.onBuild = () async {
      attempts++;
      if (attempts == 1) throw StateError('corrupt index');
      return 2;
    };
    backend.sites[7] = const [
      BangumiDataSiteEntry(
        site: 'site',
        title: 'Recovered',
        url: 'https://example.test',
        kind: 'info',
      ),
    ];

    expect(await BangumiDataService.getSites('7'), isEmpty);
    expect(await BangumiDataService.getSites('7'), backend.sites[7]);
    expect(backend.buildCalls, 2);
  });

  test('site and mikan backend errors degrade to empty/null', () async {
    backend.sitesError = StateError('bad sites');
    backend.mikanError = StateError('bad mapping');

    expect(await BangumiDataService.getSites('1'), isEmpty);
    expect(await BangumiDataService.getSitesByMikan('2'), isEmpty);
    expect(await BangumiDataService.getMikanId('1'), isNull);
  });

  test('getStatus delegates without altering status fields', () async {
    backend.status = BangumiDataCacheStatus(
      cached: true,
      fileSize: BigInt.from(123),
      lastModifiedSecs: BigInt.from(456),
      version: 'v1',
      lastFailedSecs: null,
    );

    final status = await BangumiDataService.getStatus();

    expect(status, backend.status);
  });
}

class FakeBangumiDataBackend implements BangumiDataBackend {
  Future<int> Function()? onBuild;
  int buildCalls = 0;
  bool ensureResult = false;
  Object? ensureError;
  final ensureAges = <BigInt>[];
  bool refreshResult = false;
  Object? refreshError;
  BangumiDataCacheStatus status = BangumiDataCacheStatus(
    cached: false,
    fileSize: BigInt.zero,
    version: '',
  );
  final sites = <int, List<BangumiDataSiteEntry>>{};
  final mikanSites = <int, List<BangumiDataSiteEntry>>{};
  final mikanIds = <int, PlatformInt64>{};
  Object? sitesError;
  Object? mikanError;

  @override
  Future<int> buildSitesIndex() {
    buildCalls++;
    return onBuild?.call() ?? Future.value(0);
  }

  @override
  Future<bool> ensureCache({required BigInt maxAgeSecs}) async {
    ensureAges.add(maxAgeSecs);
    if (ensureError case final error?) throw error;
    return ensureResult;
  }

  @override
  Future<bool> refreshCache() async {
    if (refreshError case final error?) throw error;
    return refreshResult;
  }

  @override
  Future<BangumiDataCacheStatus> getStatus() async => status;

  @override
  Future<List<BangumiDataSiteEntry>> fetchSites(int bangumiId) async {
    if (sitesError case final error?) throw error;
    return sites[bangumiId] ?? const [];
  }

  @override
  Future<List<BangumiDataSiteEntry>> fetchSitesByMikan(int mikanId) async {
    if (sitesError case final error?) throw error;
    return mikanSites[mikanId] ?? const [];
  }

  @override
  Future<PlatformInt64?> lookupMikanId(int bangumiId) async {
    if (mikanError case final error?) throw error;
    return mikanIds[bangumiId];
  }
}
