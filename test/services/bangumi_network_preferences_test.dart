import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_request_mode_service.dart';
import 'package:mikan_player/services/bangumi_reverse_proxy_service.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BangumiRequestModeService.debugResetForTest();
    BangumiReverseProxyService.debugResetForTest();
  });

  group('BangumiRequestModeService', () {
    test('parses all supported values and falls back to hybrid', () {
      expect(BangumiRequestMode.fromValue('legacy'), BangumiRequestMode.legacy);
      expect(BangumiRequestMode.fromValue('hybrid'), BangumiRequestMode.hybrid);
      expect(BangumiRequestMode.fromValue('modern'), BangumiRequestMode.modern);
      expect(BangumiRequestMode.fromValue(null), BangumiRequestMode.hybrid);
      expect(BangumiRequestMode.fromValue('future'), BangumiRequestMode.hybrid);
    });

    test('load uses hybrid for missing and unknown persisted values', () async {
      expect(await BangumiRequestModeService.load(), BangumiRequestMode.hybrid);

      SharedPreferences.setMockInitialValues({
        BangumiRequestModeService.preferenceKey: 'unknown',
      });
      BangumiRequestModeService.notifier.value = BangumiRequestMode.legacy;

      expect(await BangumiRequestModeService.load(), BangumiRequestMode.hybrid);
      expect(
        BangumiRequestModeService.notifier.value,
        BangumiRequestMode.hybrid,
      );
    });

    test('save persists, syncs once, and updates notifier', () async {
      final backend = FakeRequestModeBackend();
      BangumiRequestModeService.debugBindBackendForTest(backend);
      var notifications = 0;
      BangumiRequestModeService.notifier.addListener(() => notifications++);

      await BangumiRequestModeService.save(BangumiRequestMode.modern);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(BangumiRequestModeService.preferenceKey),
        'modern',
      );
      expect(backend.modes, ['modern']);
      expect(
        BangumiRequestModeService.notifier.value,
        BangumiRequestMode.modern,
      );
      expect(notifications, 1);
    });

    test(
      'syncToRust loads persisted mode without rewriting preferences',
      () async {
        SharedPreferences.setMockInitialValues({
          BangumiRequestModeService.preferenceKey: 'legacy',
        });
        final backend = FakeRequestModeBackend();
        BangumiRequestModeService.debugBindBackendForTest(backend);

        await BangumiRequestModeService.syncToRust();

        expect(backend.modes, ['legacy']);
        expect(
          BangumiRequestModeService.notifier.value,
          BangumiRequestMode.legacy,
        );
      },
    );
  });

  group('BangumiReverseProxyService', () {
    test('load defaults off and keeps URL rewriting disabled', () async {
      BangumiUrlRewriter.setEnabled(true);

      final value = await BangumiReverseProxyService.load();

      expect(value, isFalse);
      expect(BangumiReverseProxyService.notifier.value, isFalse);
      expect(
        BangumiUrlRewriter.rewrite('https://api.bgm.tv/v0/subjects/1'),
        'https://api.bgm.tv/v0/subjects/1',
      );
    });

    test('save persists, syncs, and toggles Dart URL rewriting', () async {
      final backend = FakeReverseProxyBackend();
      BangumiReverseProxyService.debugBindBackendForTest(backend);

      await BangumiReverseProxyService.save(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BangumiReverseProxyService.preferenceKey), isTrue);
      expect(backend.values, [true]);
      expect(BangumiReverseProxyService.notifier.value, isTrue);
      expect(
        BangumiUrlRewriter.rewrite('https://api.bgm.tv/v0/subjects/1'),
        'https://api.bangumi.lol/v0/subjects/1',
      );
    });

    test('syncToRust mirrors a persisted value to all runtimes', () async {
      SharedPreferences.setMockInitialValues({
        BangumiReverseProxyService.preferenceKey: true,
      });
      final backend = FakeReverseProxyBackend();
      BangumiReverseProxyService.debugBindBackendForTest(backend);

      await BangumiReverseProxyService.syncToRust();

      expect(backend.values, [true]);
      expect(BangumiReverseProxyService.notifier.value, isTrue);
      expect(BangumiUrlRewriter.enabled, isTrue);
    });
  });
}

class FakeRequestModeBackend implements BangumiRequestModeBackend {
  final modes = <String>[];

  @override
  Future<void> setMode(String mode) async {
    modes.add(mode);
  }
}

class FakeReverseProxyBackend implements BangumiReverseProxyBackend {
  final values = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    values.add(enabled);
  }
}
