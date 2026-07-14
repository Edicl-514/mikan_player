import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/reusable_browser_worker.dart';
import 'package:mikan_player/services/webview_captcha_job_runner.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/services/webview_video_job_runner.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

void main() {
  group('CaptchaJobRunner (no InAppWebView attached)', () {
    test('initialUrl is null before any job is accepted', () {
      final runner = CaptchaJobRunner(
        workerId: 0,
        sink: CaptchaJobRunnerSink(),
        stats: null,
      );
      expect(runner.initialUrl, isNull);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('acceptJob emits failure result for source with no initial URL or '
        'searchKeyword', () {
      CaptchaBypassResult? captured;
      bool idle = false;
      final runner = CaptchaJobRunner(
        workerId: 7,
        sink: CaptchaJobRunnerSink(
          onResult: (taskKey, result) => captured = result,
          onIdle: (id) => idle = true,
        ),
        stats: null,
      );
      // Source with empty searchUrl — acceptJob should immediately fail.
      final source = SourceState(
        name: 'empty-source',
        description: 'd',
        iconUrl: '',
        tier: 0,
        defaultSubtitleLanguage: 'zh',
        defaultResolution: '1080p',
        searchUrl: '',
        searchConfigJson: '{}',
        captchaConfigJson: null,
        enabled: true,
      );
      runner.acceptJob(
        CaptchaPreflightJob(
          jobKey: 'k1',
          source: source,
          searchKeyword: null,
          initialUrl: null,
          captchaConfig: CaptchaConfig(enable: true),
        ),
      );
      expect(captured, isNotNull);
      expect(captured!.success, isFalse);
      expect(captured!.sourceName, 'empty-source');
      expect(captured!.error, contains('Captcha bypass requires'));
      expect(idle, isTrue);
      runner.dispose();
    });

    test('dispose() is idempotent and clears state', () {
      final runner = CaptchaJobRunner(
        workerId: 0,
        sink: CaptchaJobRunnerSink(),
        stats: null,
      );
      runner.dispose();
      // Calling dispose a second time should not throw.
      expect(() => runner.dispose(), returnsNormally);
    });
  });

  group('VideoExtractionJobRunner (no InAppWebView attached)', () {
    test('initial state has no current job', () {
      final runner = VideoExtractionJobRunner(
        workerId: 0,
        sink: VideoExtractionJobSink(),
        stats: null,
      );
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('transitionToIdle before any job is a no-op', () {
      final runner = VideoExtractionJobRunner(
        workerId: 0,
        sink: VideoExtractionJobSink(),
        stats: null,
      );
      expect(() => runner.transitionToIdle(), returnsNormally);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test('cancelCurrentJob before any job is a no-op', () {
      final runner = VideoExtractionJobRunner(
        workerId: 0,
        sink: VideoExtractionJobSink(),
        stats: null,
      );
      expect(() => runner.cancelCurrentJob(), returnsNormally);
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test(
      'acceptJob sets currentJob but does not navigate without a '
      'controller (host widget handles initialUrlRequest on first build)',
      () {
        final runner = VideoExtractionJobRunner(
          workerId: 0,
          sink: VideoExtractionJobSink(),
          stats: null,
        );
        runner.acceptJob(
          const VideoExtractionJob(
            jobKey: 'p1',
            url: 'https://example.com/never-loaded',
          ),
        );
        expect(runner.currentJob, isNotNull);
        expect(runner.currentJob!.jobKey, 'p1');
        runner.dispose();
      },
    );
  });

  group('WebViewJob union dispatch', () {
    test('CaptchaJob.preflight is the underlying CaptchaPreflightJob', () {
      const inner = CaptchaPreflightJob(
        jobKey: 'k',
        source: _SourceStub(),
        captchaConfig: CaptchaConfig(enable: true),
      );
      final job = CaptchaJob(inner);
      expect(identical(job.preflight, inner), isTrue);
    });

    test('VideoJob.extraction is the underlying VideoExtractionJob', () {
      const inner = VideoExtractionJob(
        jobKey: 'k',
        sourceName: 'video-source',
        url: 'https://example.com/1',
      );
      final job = VideoJob(inner);
      expect(identical(job.extraction, inner), isTrue);
      expect(job.extraction.sourceName, 'video-source');
    });

    test('same stable task key in a new search generation is a new job', () {
      const inner = CaptchaPreflightJob(
        jobKey: 'search:source',
        source: _SourceStub(),
        captchaConfig: CaptchaConfig(enable: true),
      );

      expect(
        sameWebViewJob(
          const CaptchaJob(inner, generation: 41),
          const CaptchaJob(inner, generation: 42),
        ),
        isFalse,
      );
      expect(
        sameWebViewJob(
          const CaptchaJob(inner, generation: 42),
          const CaptchaJob(inner, generation: 42),
        ),
        isTrue,
      );
    });
  });
}

/// Minimal SourceState for tests that don't read source fields.
class _SourceStub implements SourceState {
  const _SourceStub();

  @override
  String get name => 'stub';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
