import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/services/webview_scheduler_stats.dart';
import 'package:mikan_player/services/reusable_browser_worker.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

SourceState _sourceState({String name = 'src', int tier = 0}) {
  return SourceState(
    name: name,
    description: 'd',
    iconUrl: '',
    tier: tier,
    defaultSubtitleLanguage: 'zh',
    defaultResolution: '1080p',
    searchUrl: 'https://example.com/search?q={keyword}',
    searchConfigJson: '{}',
    captchaConfigJson: null,
    enabled: true,
  );
}

void main() {
  group('WebViewSchedulerStats', () {
    test('reset() clears every counter', () {
      final stats = WebViewSchedulerStats();
      stats.onVideoWidgetCreated('job-1');
      stats.onVideoWidgetDisposed('job-1');
      stats.onBrowserWorkerCreated('worker_0');
      stats.onBrowserWorkerDisposed('worker_0');
      stats.onBrowserWorkerKindSwitched(0, WebViewJobKind.captcha);
      stats.onBrowserWorkerSameWorkerCrossKindReuse(0);
      stats.onVideoJobStarted('page-1', 'src-a', BigInt.zero);
      stats.onVideoJobCompleted(
        success: true,
        timedOut: false,
        pageKey: 'page-1',
        sourceName: 'src-a',
      );
      stats.onVideoJobCancelled('page-2', 'src-b');
      stats.onVideoJobLateAfterCancel('page-3', 'src-c');
      stats.onCaptchaWidgetCreated('captcha-1');
      stats.onCaptchaWidgetDisposed('captcha-1');
      stats.onCaptchaJobStarted('captcha-1', 'src-a');
      stats.onCaptchaJobCompleted(
        success: false,
        timedOut: true,
        jobKey: 'captcha-1',
        sourceName: 'src-a',
      );
      stats.onCaptchaJobCancelled('captcha-2', 'src-b');
      stats.onCaptchaJobCancelledWhilePending('captcha-3', 'src-c');
      stats.onCaptchaJobLateAfterCancel('captcha-4');
      stats.onCaptchaJobStaleResult('captcha-5');

      expect(stats.videoWidgetCreations, 1);
      expect(stats.browserWorkerCreations, 1);
      expect(stats.videoJobStarted, 1);
      expect(stats.captchaJobStaleResult, 1);

      stats.reset();

      expect(stats.videoWidgetCreations, 0);
      expect(stats.videoWidgetDisposals, 0);
      expect(stats.captchaWidgetCreations, 0);
      expect(stats.captchaWidgetDisposals, 0);
      expect(stats.browserWorkerCreations, 0);
      expect(stats.browserWorkerDisposals, 0);
      expect(stats.browserWorkerKindSwitches, 0);
      expect(stats.browserWorkerSameWorkerCrossKindReuse, 0);
      expect(stats.videoJobStarted, 0);
      expect(stats.videoJobCompletedTotal, 0);
      expect(stats.videoJobSucceeded, 0);
      expect(stats.videoJobFailed, 0);
      expect(stats.videoJobTimedOut, 0);
      expect(stats.videoJobCancelled, 0);
      expect(stats.videoJobLateAfterCancel, 0);
      expect(stats.captchaJobStarted, 0);
      expect(stats.captchaJobCompletedTotal, 0);
      expect(stats.captchaJobSucceeded, 0);
      expect(stats.captchaJobFailed, 0);
      expect(stats.captchaJobTimedOut, 0);
      expect(stats.captchaJobCancelled, 0);
      expect(stats.captchaJobCancelledWhilePending, 0);
      expect(stats.captchaJobLateAfterCancel, 0);
      expect(stats.captchaJobStaleResult, 0);
    });

    test('onVideoJobCompleted branches success/failed/timedOut', () {
      final stats = WebViewSchedulerStats();
      stats.onVideoJobCompleted(
        success: true,
        timedOut: false,
        pageKey: 'p1',
        sourceName: 'src-a',
      );
      stats.onVideoJobCompleted(
        success: false,
        timedOut: false,
        pageKey: 'p2',
        sourceName: 'src-a',
      );
      stats.onVideoJobCompleted(
        success: false,
        timedOut: true,
        pageKey: 'p3',
        sourceName: 'src-a',
      );

      expect(stats.videoJobCompletedTotal, 3);
      expect(stats.videoJobSucceeded, 1);
      expect(stats.videoJobFailed, 1);
      expect(stats.videoJobTimedOut, 1);
    });

    test('onCaptchaJobCompleted branches success/failed/timedOut', () {
      final stats = WebViewSchedulerStats();
      stats.onCaptchaJobCompleted(
        success: true,
        timedOut: false,
        jobKey: 'k1',
        sourceName: 'src',
      );
      stats.onCaptchaJobCompleted(
        success: false,
        timedOut: false,
        jobKey: 'k2',
        sourceName: 'src',
      );
      stats.onCaptchaJobCompleted(
        success: false,
        timedOut: true,
        jobKey: 'k3',
        sourceName: 'src',
      );

      expect(stats.captchaJobCompletedTotal, 3);
      expect(stats.captchaJobSucceeded, 1);
      expect(stats.captchaJobFailed, 1);
      expect(stats.captchaJobTimedOut, 1);
    });

    test('onBrowserWorkerKindSwitched increments only kind switch counter',
        () {
      final stats = WebViewSchedulerStats();
      stats.onBrowserWorkerCreated('w0');
      stats.onBrowserWorkerKindSwitched(0, WebViewJobKind.captcha);
      stats.onBrowserWorkerKindSwitched(0, WebViewJobKind.video);
      expect(stats.browserWorkerKindSwitches, 2);
      expect(stats.browserWorkerSameWorkerCrossKindReuse, 0);
    });

    test('onBrowserWorkerSameWorkerCrossKindReuse increments cross-kind '
        'counter', () {
      final stats = WebViewSchedulerStats();
      stats.onBrowserWorkerCreated('w0');
      stats.onBrowserWorkerSameWorkerCrossKindReuse(0);
      stats.onBrowserWorkerSameWorkerCrossKindReuse(0);
      expect(stats.browserWorkerSameWorkerCrossKindReuse, 2);
    });

    test('shortSummary() returns a non-empty one-line string', () {
      final stats = WebViewSchedulerStats();
      stats.onVideoJobCompleted(
        success: true,
        timedOut: false,
        pageKey: 'p',
        sourceName: 'src',
      );
      final summary = stats.shortSummary();
      expect(summary, isNotEmpty);
      expect(summary, contains('WV created='));
      expect(summary, contains('BR created='));
      expect(summary, contains('video started='));
      expect(summary, contains('captcha started='));
    });
  });

  group('WebViewJob (sealed union)', () {
    test('CaptchaJob returns captcha kind and forwards jobKey', () {
      const jobKey = 'captcha-key';
      final inner = CaptchaPreflightJob(
        jobKey: jobKey,
        source: _sourceState(),
        captchaConfig: CaptchaConfig(enable: true),
      );
      final job = CaptchaJob(inner);
      expect(job.kind, WebViewJobKind.captcha);
      expect(job.jobKey, jobKey);
    });

    test('VideoJob returns video kind and forwards jobKey', () {
      const jobKey = 'video-key';
      const inner = VideoExtractionJob(
        jobKey: jobKey,
        url: 'https://example.com/play/1',
      );
      final job = VideoJob(inner);
      expect(job.kind, WebViewJobKind.video);
      expect(job.jobKey, jobKey);
    });
  });

  group('WebViewVideoExtractor.url helpers', () {
    final extractor = WebViewVideoExtractor();

    test('isVideoUrl returns true for m3u8 / mp4 / image / akamaized', () {
      expect(extractor.isVideoUrl('https://cdn.example.com/playlist.m3u8'), isTrue);
      expect(
        extractor.isVideoUrl('https://cdn.example.com/stream.mp4?token=abc'),
        isTrue,
      );
      expect(
        extractor.isVideoUrl(
          'https://cdn.example.com/play.image?key=xyz',
        ),
        isTrue,
      );
      expect(
        extractor.isVideoUrl('https://foo.akamaized.net/asset.ts'),
        isTrue,
      );
      expect(
        extractor.isVideoUrl('https://vfile.bilivideo.com/play.m3u8'),
        isTrue,
      );
    });

    test('isVideoUrl returns false for non-video URLs', () {
      expect(extractor.isVideoUrl('https://example.com/index.html'), isFalse);
      expect(extractor.isVideoUrl('https://example.com/style.css'), isFalse);
      expect(
        extractor.isVideoUrl('https://example.com/img.png'),
        isFalse,
      );
      expect(extractor.isVideoUrl('https://example.com/main.js'), isFalse);
    });

    test('matchesCustomRegex honors empty/sentinel regex', () {
      expect(extractor.matchesCustomRegex('https://example.com', null), isFalse);
      expect(
        extractor.matchesCustomRegex('https://example.com', ''),
        isFalse,
      );
      expect(
        extractor.matchesCustomRegex('https://example.com', r'$^'),
        isFalse,
      );
    });

    test('matchesCustomRegex returns true for valid regex', () {
      expect(
        extractor.matchesCustomRegex(
          'https://cdn.example.com/stream.m3u8',
          r'm3u8$',
        ),
        isTrue,
      );
    });

    test('extractUrlWithCustomRegex prefers named group "v"', () {
      final extracted = extractor.extractUrlWithCustomRegex(
        'captcha:next=https://cdn.example.com/stream.m3u8?token=abc',
        r'next=(?<v>https?://[^\s&]+)',
      );
      expect(extracted, 'https://cdn.example.com/stream.m3u8?token=abc');
    });

    test('extractUrlWithCustomRegex falls back to first capture group', () {
      final extracted = extractor.extractUrlWithCustomRegex(
        'prefix https://cdn.example.com/stream.m3u8 suffix',
        r'(https?://\S+\.m3u8)',
      );
      expect(extracted, 'https://cdn.example.com/stream.m3u8');
    });

    test('extractUrlWithCustomRegex returns null on non-match', () {
      final extracted = extractor.extractUrlWithCustomRegex(
        'https://example.com',
        r'nonexistent-pattern',
      );
      expect(extracted, isNull);
    });

    test('extractUrlWithCustomRegex returns full URL when capture is not '
        'absolute (segment-only regex)', () {
      final extracted = extractor.extractUrlWithCustomRegex(
        'https://example.com/video/tos/alisg/stream',
        r'/video/tos/alisg/',
      );
      expect(extracted, 'https://example.com/video/tos/alisg/stream');
    });
  });

  group('VideoExtractResult', () {
    test('success is true when videoUrl is non-empty', () {
      final r = VideoExtractResult(videoUrl: 'https://x/y.m3u8');
      expect(r.success, isTrue);
    });

    test('success is false when videoUrl is null/empty', () {
      expect(VideoExtractResult().success, isFalse);
      expect(VideoExtractResult(videoUrl: '').success, isFalse);
      expect(VideoExtractResult(error: 'oops').success, isFalse);
    });

    test('default fields', () {
      final r = VideoExtractResult();
      expect(r.timedOut, isFalse);
      expect(r.headers, isEmpty);
      expect(r.videoUrl, isNull);
      expect(r.error, isNull);
    });
  });

  group('CaptchaBypassResult', () {
    test('timedOut defaults to false', () {
      const r = CaptchaBypassResult(sourceName: 's', success: true);
      expect(r.timedOut, isFalse);
    });

    test('carries cookies / html / url when set', () {
      const r = CaptchaBypassResult(
        sourceName: 's',
        success: true,
        cookies: 'a=1; b=2',
        finalHtml: '<html/>',
        finalUrl: 'https://x',
        searchPageHtml: '<search/>',
        searchPageUrl: 'https://x/search',
        detailPageHtml: '<detail/>',
        detailPageUrl: 'https://x/detail',
        timedOut: true,
      );
      expect(r.cookies, 'a=1; b=2');
      expect(r.finalHtml, '<html/>');
      expect(r.finalUrl, 'https://x');
      expect(r.searchPageHtml, '<search/>');
      expect(r.searchPageUrl, 'https://x/search');
      expect(r.detailPageHtml, '<detail/>');
      expect(r.detailPageUrl, 'https://x/detail');
      expect(r.timedOut, isTrue);
    });
  });

  group('CaptchaConfig.tryParse', () {
    test('returns null for empty/invalid json', () {
      expect(CaptchaConfig.tryParse(null), isNull);
      expect(CaptchaConfig.tryParse(''), isNull);
      expect(CaptchaConfig.tryParse('not-json'), isNull);
    });

    test('returns null when enable=false', () {
      final json =
          '{"enable":false,"type":"image_ocr","detectSelector":"#cap"}';
      expect(CaptchaConfig.tryParse(json), isNull);
    });

    test('parses a valid image_ocr config', () {
      final json = '''
{
  "enable": true,
  "type": "image_ocr",
  "detectSelector": "#captcha",
  "imageSelector": "#captcha-img",
  "inputSelector": "#captcha-input",
  "submitSelector": "#submit",
  "initialDelayMs": 1500
}
''';
      final cfg = CaptchaConfig.tryParse(json);
      expect(cfg, isNotNull);
      expect(cfg!.isImageOcr, isTrue);
      expect(cfg.isSimpleClick, isFalse);
      expect(cfg.detectSelector, '#captcha');
      expect(cfg.imageSelector, '#captcha-img');
      expect(cfg.inputSelector, '#captcha-input');
      expect(cfg.submitSelector, '#submit');
      expect(cfg.initialDelayMs, 1500);
    });

    test('parses a simple_click config', () {
      final json = '''
{
  "enable": true,
  "type": "simple_click",
  "detectSelector": ".robot-check",
  "submitSelector": "button.continue",
  "initialDelayMs": 800
}
''';
      final cfg = CaptchaConfig.tryParse(json);
      expect(cfg, isNotNull);
      expect(cfg!.isSimpleClick, isTrue);
      expect(cfg.isImageOcr, isFalse);
    });
  });
}
