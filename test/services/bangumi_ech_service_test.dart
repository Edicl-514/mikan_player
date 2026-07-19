import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_ech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEchBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeEchBackend();
    BangumiEchService.debugBindBackendForTest(backend);
    BangumiEchService.notifier.value = true;
    BangumiEchService.dohNotifier.value = const [];
  });

  tearDown(BangumiEchService.debugResetForTest);

  test('load defaults ECH on and pushes an empty custom DoH list', () async {
    final enabled = await BangumiEchService.load();

    expect(enabled, isTrue);
    expect(backend.enabledValues, [true]);
    expect(backend.setLists, [<String>[]]);
    expect(BangumiEchService.dohNotifier.value, isEmpty);
  });

  test('load restores persisted toggle and endpoints', () async {
    SharedPreferences.setMockInitialValues({
      BangumiEchService.preferenceKey: false,
      BangumiEchService.dohListKey: ['https://one/dns-query'],
    });

    final enabled = await BangumiEchService.load();

    expect(enabled, isFalse);
    expect(backend.enabledValues, [false]);
    expect(backend.setLists.single, ['https://one/dns-query']);
    expect(BangumiEchService.dohNotifier.value, ['https://one/dns-query']);
  });

  test('save, refresh, warmup, and sync delegate to the backend', () async {
    backend.refreshResult = 321;

    await BangumiEchService.save(false);
    expect(await BangumiEchService.refresh(), 321);
    await BangumiEchService.warmup();
    await BangumiEchService.syncToRust();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(BangumiEchService.preferenceKey), isFalse);
    expect(backend.enabledValues, [false, false]);
    expect(backend.refreshCalls, 1);
    expect(backend.warmupCalls, 1);
  });

  test(
    'add trims, rejects empty, and deduplicates trailing slash variants',
    () async {
      expect(await BangumiEchService.addDohEndpoint('   '), isEmpty);
      expect(
        await BangumiEchService.addDohEndpoint(' https://one/dns-query/ '),
        ['https://one/dns-query/'],
      );
      expect(await BangumiEchService.addDohEndpoint('https://one/dns-query'), [
        'https://one/dns-query/',
      ]);
      expect(backend.setLists, [
        ['https://one/dns-query/'],
      ]);
    },
  );

  test('remove compares normalized endpoint values', () async {
    SharedPreferences.setMockInitialValues({
      BangumiEchService.dohListKey: [
        'https://one/dns-query/',
        'https://two/dns-query',
      ],
    });

    final result = await BangumiEchService.removeDohEndpoint(
      ' https://one/dns-query ',
    );

    expect(result, ['https://two/dns-query']);
    expect(backend.setLists.single, ['https://two/dns-query']);
  });

  test(
    'move clamps target, ignores invalid source, and persists backend result',
    () async {
      SharedPreferences.setMockInitialValues({
        BangumiEchService.dohListKey: ['a', 'b', 'c'],
      });
      backend.current = ['a', 'b', 'c'];

      expect(await BangumiEchService.moveDohEndpoint(-1, 2), ['a', 'b', 'c']);
      final moved = await BangumiEchService.moveDohEndpoint(0, 99);

      expect(moved, ['b', 'c', 'a']);
      expect(backend.moves, [(0, 2)]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(BangumiEchService.dohListKey), [
        'b',
        'c',
        'a',
      ]);
    },
  );

  test('set cleans blanks while reset removes the custom list', () async {
    expect(await BangumiEchService.setDohEndpoints([' a ', '', '  ', 'b']), [
      'a',
      'b',
    ]);
    expect(await BangumiEchService.resetDohEndpoints(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(BangumiEchService.dohListKey), isFalse);
    expect(backend.resetCalls, 1);
    expect(BangumiEchService.dohNotifier.value, isEmpty);
  });

  test(
    'test endpoint restores persisted and runtime lists after success',
    () async {
      SharedPreferences.setMockInitialValues({
        BangumiEchService.dohListKey: ['previous'],
      });
      backend.refreshResult = 88;

      final size = await BangumiEchService.testDohEndpoint(' candidate ');

      expect(size, 88);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(BangumiEchService.dohListKey), ['previous']);
      expect(backend.setLists, [
        ['candidate'],
        ['previous'],
      ]);
      expect(BangumiEchService.dohNotifier.value, ['previous']);
    },
  );

  test(
    'test endpoint restores persisted and runtime lists when refresh throws',
    () async {
      SharedPreferences.setMockInitialValues({
        BangumiEchService.dohListKey: ['previous'],
      });
      backend.refreshError = StateError('offline');

      final size = await BangumiEchService.testDohEndpoint('candidate');

      expect(size, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(BangumiEchService.dohListKey), ['previous']);
      expect(backend.setLists, [
        ['candidate'],
        ['previous'],
      ]);
      expect(BangumiEchService.dohNotifier.value, ['previous']);
    },
  );

  test(
    'JSON import/export handles unicode, mixed values, and malformed input',
    () {
      const endpoints = ['https://例子.test/dns-query', 'https://two'];
      final encoded = BangumiEchService.exportDohEndpointsJson(endpoints);

      expect(jsonDecode(encoded), endpoints);
      expect(
        BangumiEchService.importDohEndpointsJson(
          '[" a ", 1, null, "", "https://例子.test"]',
        ),
        ['a', 'https://例子.test'],
      );
      expect(BangumiEchService.importDohEndpointsJson('{}'), isNull);
      expect(BangumiEchService.importDohEndpointsJson('not json'), isNull);
    },
  );
}

class FakeEchBackend implements BangumiEchBackend {
  final enabledValues = <bool>[];
  final setLists = <List<String>>[];
  final moves = <(int, int)>[];
  int refreshResult = 0;
  Object? refreshError;
  int refreshCalls = 0;
  int warmupCalls = 0;
  int resetCalls = 0;
  List<String> current = <String>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledValues.add(enabled);
  }

  @override
  Future<int> refresh() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    return refreshResult;
  }

  @override
  Future<void> warmup() async {
    warmupCalls++;
  }

  @override
  Future<List<String>> setDohEndpoints(List<String> endpoints) async {
    current = List<String>.of(endpoints);
    setLists.add(List<String>.of(endpoints));
    return List<String>.of(current);
  }

  @override
  Future<List<String>> moveDohEndpoint(int from, int to) async {
    moves.add((from, to));
    final item = current.removeAt(from);
    current.insert(to, item);
    return List<String>.of(current);
  }

  @override
  Future<List<String>> resetDohEndpoints() async {
    resetCalls++;
    current = <String>[];
    return const [];
  }
}
