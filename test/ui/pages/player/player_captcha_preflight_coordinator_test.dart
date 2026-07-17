// Phase 1.3: unit tests for captcha preflight coordinator queue + overrides.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_captcha_preflight_coordinator.dart';

SourceState _source({
  String name = 'src',
  String? captchaConfigJson = '{"enable":true,"type":"image_ocr"}',
}) {
  return SourceState(
    name: name,
    description: '',
    iconUrl: '',
    tier: 0,
    defaultSubtitleLanguage: '',
    defaultResolution: '',
    searchUrl: 'https://example.com/s',
    searchConfigJson: '{}',
    captchaConfigJson: captchaConfigJson,
    enabled: true,
  );
}

CaptchaBypassResult _result({
  bool success = true,
  String sourceName = 'src',
  String? error,
  String? cookies,
  String? searchPageHtml,
  String? searchPageUrl,
  String? detailPageHtml,
  String? detailPageUrl,
}) => CaptchaBypassResult(
  sourceName: sourceName,
  success: success,
  error: error,
  cookies: cookies,
  searchPageHtml: searchPageHtml,
  searchPageUrl: searchPageUrl,
  detailPageHtml: detailPageHtml,
  detailPageUrl: detailPageUrl,
);

void main() {
  group('buildSearchCaptchaRuntimeOverride', () {
    test('success carries cookies and html snapshots', () {
      final override = buildSearchCaptchaRuntimeOverride(
        source: _source(name: 'A'),
        result: _result(
          success: true,
          sourceName: 'A',
          cookies: 'a=1',
          searchPageHtml: '<s>',
          searchPageUrl: 'https://s',
          detailPageHtml: '<d>',
          detailPageUrl: 'https://d',
        ),
      );
      expect(override.sourceName, 'A');
      expect(override.cookies, 'a=1');
      expect(override.searchPageHtml, '<s>');
      expect(override.skipSearchError, isNull);
    });

    test('failure sets skipSearchError', () {
      final override = buildSearchCaptchaRuntimeOverride(
        source: _source(name: 'B'),
        result: _result(success: false, sourceName: 'B', error: 'ocr blank'),
      );
      expect(override.skipSearchError, 'ocr blank');
      expect(
        buildSearchCaptchaRuntimeOverride(
          source: _source(),
          result: _result(success: false),
        ).skipSearchError,
        'Captcha preflight failed',
      );
    });
  });

  group('PlayerCaptchaPreflightCoordinator queue', () {
    test('queueTask de-dupes by taskKey and requires captcha config', () {
      final c = PlayerCaptchaPreflightCoordinator();
      void onResult(CaptchaPreflightTask t, CaptchaBypassResult r) {}

      expect(
        c.queueTask(
          taskKey: 'search:src',
          label: 'src',
          source: _source(captchaConfigJson: 'not-json'),
          loadToken: 1,
          onResult: onResult,
        ),
        isFalse,
      );

      expect(
        c.queueTask(
          taskKey: 'search:src',
          label: 'src',
          source: _source(),
          loadToken: 1,
          onResult: onResult,
        ),
        isTrue,
      );
      expect(c.pendingCount, 1);

      expect(
        c.queueTask(
          taskKey: 'search:src',
          label: 'src',
          source: _source(),
          loadToken: 2,
          onResult: onResult,
        ),
        isFalse,
      );
      expect(c.pendingCount, 1);
    });

    test('pollNextReady respects canStartNow and restores pending', () {
      final c = PlayerCaptchaPreflightCoordinator();
      void onResult(CaptchaPreflightTask t, CaptchaBypassResult r) {}

      c.queueTask(
        taskKey: 'a',
        label: 'a',
        source: _source(name: 'cool'),
        loadToken: 1,
        onResult: onResult,
      );
      c.queueTask(
        taskKey: 'b',
        label: 'b',
        source: _source(name: 'hot'),
        loadToken: 1,
        onResult: onResult,
      );

      final poll = c.pollNextReady(
        canStartNow: (name, _) => name == 'hot',
        intervalFor: (_) => const Duration(milliseconds: 800),
      );
      expect(poll.ready?.taskKey, 'b');
      expect(poll.stillPending.map((t) => t.taskKey).toList(), ['a']);
      expect(poll.coolingSources, ['cool']);

      c.restorePending(poll.stillPending);
      expect(c.pendingCount, 1);
      c.markActive(poll.ready!);
      expect(c.activeCount, 1);
      expect(c.isActive('b'), isTrue);

      c.clearTasks();
      expect(c.pendingCount, 0);
      expect(c.activeCount, 0);
    });

    test('runtime overrides + resetForNewSearch', () {
      final c = PlayerCaptchaPreflightCoordinator();
      c.setRuntimeOverride(
        's',
        const SourceRuntimeOverride(sourceName: 's', cookies: 'x'),
      );
      expect(c.runtimeOverrideFor('s')?.cookies, 'x');
      c.resetForNewSearch();
      expect(c.runtimeOverrideFor('s'), isNull);
    });

    test('exposes read-only views and removes pending through coordinator', () {
      final c = PlayerCaptchaPreflightCoordinator();
      void onResult(CaptchaPreflightTask t, CaptchaBypassResult r) {}

      c.queueTask(
        taskKey: 'keep',
        label: 'keep',
        source: _source(name: 'keep'),
        loadToken: 1,
        onResult: onResult,
      );
      c.queueTask(
        taskKey: 'remove',
        label: 'remove',
        source: _source(name: 'remove'),
        loadToken: 1,
        onResult: onResult,
      );

      expect(() => c.pendingTasks.clear(), throwsUnsupportedError);
      final removed = c.removePendingWhere((task) => task.taskKey == 'remove');
      expect(removed.map((task) => task.taskKey), ['remove']);
      expect(c.pendingTasks.map((task) => task.taskKey), ['keep']);

      final poll = c.pollNextReady(
        canStartNow: (_, _) => true,
        intervalFor: (_) => Duration.zero,
      );
      c.markActive(poll.ready!);
      expect(() => c.activeTasks.clear(), throwsUnsupportedError);

      c.setRuntimeOverride(
        'keep',
        const SourceRuntimeOverride(sourceName: 'keep', cookies: 'a=1'),
      );
      expect(() => c.runtimeOverrides.clear(), throwsUnsupportedError);
    });
  });
}
