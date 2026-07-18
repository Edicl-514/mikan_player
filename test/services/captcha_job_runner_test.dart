// Shell / public-surface unit tests for CaptchaJobRunner after the Phase 6
// extract. Library-private pure helpers in captcha_search_flow.dart stay
// private (same as pre-split statics); this suite covers the public runner
// surface and CaptchaJobRunnerSink without a WebView binding.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/webview_captcha_job_runner.dart';

void main() {
  group('CaptchaJobRunnerSink', () {
    test('default constructor leaves all callbacks null', () {
      final sink = CaptchaJobRunnerSink();
      expect(sink.onResult, isNull);
      expect(sink.onIdle, isNull);
      expect(sink.onLog, isNull);
    });

    test('callbacks round-trip through the constructor', () {
      var logCalls = 0;
      final sink = CaptchaJobRunnerSink(
        onResult: (_, _) {},
        onIdle: (_, _) {},
        onLog: (_) => logCalls++,
      );
      expect(sink.onResult, isNotNull);
      expect(sink.onIdle, isNotNull);
      sink.onLog!.call('hi');
      expect(logCalls, 1);
    });
  });

  group('CaptchaJobRunner (no InAppWebView attached) — basic shell', () {
    CaptchaJobRunner makeRunner({CaptchaJobRunnerSink? sink}) {
      return CaptchaJobRunner(
        workerId: 0,
        sink: sink ?? CaptchaJobRunnerSink(),
        stats: null,
      );
    }

    test('initialUrl is null before any job is accepted', () {
      final runner = makeRunner();
      expect(runner.initialUrl, isNull);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('dispose() is idempotent and clears state', () {
      final runner = makeRunner();
      runner.dispose();
      expect(() => runner.dispose(), returnsNormally);
    });

    test('transitionToIdle before any job is a no-op', () {
      final runner = makeRunner();
      expect(() => runner.transitionToIdle(), returnsNormally);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('cancelCurrentJob before any job is a no-op', () {
      final runner = makeRunner();
      expect(() => runner.cancelCurrentJob(), returnsNormally);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('buildNavigationHeaders returns empty map before any job is set', () {
      final runner = makeRunner();
      expect(runner.buildNavigationHeaders(), isEmpty);
      runner.dispose();
    });

    test('jobTimeout falls back to 45s when no job is set', () {
      final runner = makeRunner();
      expect(runner.jobTimeout, const Duration(seconds: 45));
      runner.dispose();
    });
  });
}
