// Shell / public-surface unit tests for CaptchaJobRunner after the Phase 6
// extract. Library-private pure helpers in captcha_search_flow.dart stay
// private (same as pre-split statics); this suite covers the public runner
// surface and CaptchaJobRunnerSink without a WebView binding.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/webview_captcha_job_runner.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';

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

    test('explicit initial URL wins and its whitespace is trimmed', () {
      final runner = makeRunner();
      runner.acceptJob(
        job(
          initialUrl: '  https://detail.example/item/1  ',
          searchKeyword: 'ignored',
        ),
      );

      expect(runner.initialUrl, 'https://detail.example/item/1');
      runner.dispose();
    });

    test('search URL strips season suffix before replacing keyword', () {
      final runner = makeRunner();
      runner.acceptJob(
        job(
          searchKeyword: '  Example Anime Season 2  ',
          searchUrl: 'https://search.example/?q={keyword}',
        ),
      );

      expect(runner.initialUrl, 'https://search.example/?q=Example Anime');
      runner.dispose();
    });

    test('search URL without placeholder works with an empty keyword', () {
      final runner = makeRunner();
      runner.acceptJob(job(searchUrl: 'https://search.example/latest'));

      expect(runner.initialUrl, 'https://search.example/latest');
      runner.dispose();
    });

    test('missing keyword for a placeholder completes once with failure', () {
      final results = <CaptchaBypassResult>[];
      var idleCalls = 0;
      final runner = makeRunner(
        sink: CaptchaJobRunnerSink(
          onResult: (_, result) => results.add(result),
          onIdle: (_, _) => idleCalls++,
        ),
      );

      runner.acceptJob(job(searchUrl: 'https://search.example/?q={keyword}'));

      expect(runner.initialUrl, isNull);
      expect(results, hasLength(1));
      expect(results.single.success, isFalse);
      expect(results.single.error, contains('requires initialUrl'));
      expect(idleCalls, 1);
      runner.dispose();
    });

    test(
      'navigation headers preserve a non-default port and explicit referer',
      () {
        final runner = makeRunner();
        runner.acceptJob(
          job(initialUrl: 'http://127.0.0.1:18080/page', referer: null),
        );

        expect(
          runner.buildNavigationHeaders()['Referer'],
          'http://127.0.0.1:18080/',
        );

        runner.acceptJob(
          job(
            initialUrl: 'https://detail.example/page',
            referer: ' https://ref.example/from ',
          ),
        );
        expect(
          runner.buildNavigationHeaders()['Referer'],
          'https://ref.example/from',
        );
        runner.dispose();
      },
    );

    test('complete followed by cancel settles the job only once', () {
      final results = <CaptchaBypassResult>[];
      final idleJobs = <CaptchaPreflightJob>[];
      final runner = makeRunner(
        sink: CaptchaJobRunnerSink(
          onResult: (_, result) => results.add(result),
          onIdle: (_, completedJob) => idleJobs.add(completedJob),
        ),
      );

      // Missing entry data completes synchronously inside acceptJob.
      runner.acceptJob(job(searchUrl: 'https://example.com/?q={keyword}'));
      runner.cancelCurrentJob();

      expect(results, hasLength(1));
      expect(idleJobs, hasLength(1));
      expect(idleJobs.single.jobKey, 'job');
      expect(runner.currentJob, isNull);
      runner.dispose();
    });

    test(
      'cancel wins a timeout race without a late result or second idle',
      () async {
        final results = <CaptchaBypassResult>[];
        final idleJobs = <CaptchaPreflightJob>[];
        final runner = makeRunner(
          sink: CaptchaJobRunnerSink(
            onResult: (_, result) => results.add(result),
            onIdle: (_, completedJob) => idleJobs.add(completedJob),
          ),
        );

        runner.acceptJob(
          job(
            initialUrl: 'https://example.com/challenge',
            timeout: const Duration(milliseconds: 40),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        runner.cancelCurrentJob();
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(results, isEmpty);
        expect(idleJobs, hasLength(1));
        expect(runner.currentJob, isNull);
        runner.dispose();
      },
    );

    test(
      'dispose suppresses a pending timeout result and idle callback',
      () async {
        var resultCalls = 0;
        var idleCalls = 0;
        final runner = makeRunner(
          sink: CaptchaJobRunnerSink(
            onResult: (_, _) => resultCalls++,
            onIdle: (_, _) => idleCalls++,
          ),
        );

        runner.acceptJob(
          job(
            initialUrl: 'https://example.com/challenge',
            timeout: const Duration(milliseconds: 20),
          ),
        );
        runner.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(resultCalls, 0);
        expect(idleCalls, 0);
      },
    );

    test('old generation timeout cannot settle same-key replacement', () async {
      final results = <CaptchaPreflightJob>[];
      final idleJobs = <CaptchaPreflightJob>[];
      final runner = makeRunner(
        sink: CaptchaJobRunnerSink(
          onResult: (completedJob, _) => results.add(completedJob),
          onIdle: (_, completedJob) => idleJobs.add(completedJob),
        ),
      );

      runner.acceptJob(
        job(
          generation: 1,
          initialUrl: 'https://example.com/old',
          timeout: const Duration(milliseconds: 25),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      runner.acceptJob(
        job(
          generation: 2,
          initialUrl: 'https://example.com/new',
          timeout: const Duration(milliseconds: 100),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(results, isEmpty);
      expect(idleJobs, isEmpty);
      expect(runner.currentJob?.generation, 2);

      runner.cancelCurrentJob();
      expect(idleJobs.map((completedJob) => completedJob.generation), [2]);
      runner.dispose();
    });

    test(
      'timeout releases the scheduler slot for the next worker job',
      () async {
        final scheduler = PlayerWebViewScheduler();
        final slot = scheduler
            .acquireIdleCaptchaWorkerSlot(useWorkerPool: true, maxConcurrent: 1)
            .slot!;
        scheduler.startCaptchaJob(slot, 'job', 'source', generation: 9);
        final runner = makeRunner(
          sink: CaptchaJobRunnerSink(
            onResult: (completedJob, _) => scheduler.releaseCaptchaSlot(
              completedJob.jobKey,
              generation: completedJob.generation,
            ),
            onIdle: (workerId, _) => scheduler.markSlotIdle(workerId),
          ),
        );

        runner.acceptJob(
          job(
            generation: 9,
            initialUrl: 'https://example.com/challenge',
            timeout: const Duration(milliseconds: 20),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(scheduler.activeCaptchaJobs, isEmpty);
        expect(scheduler.healthOf(slot.workerId), WebViewWorkerHealth.idle);
        final next = scheduler.acquireIdleVideoWorkerSlot(
          {'source'},
          useWorkerPool: true,
          maxConcurrent: 1,
        );
        expect(next.slot?.workerId, slot.workerId);
        runner.dispose();
      },
    );
  });
}

CaptchaPreflightJob job({
  String searchUrl = '',
  String? searchKeyword,
  String? initialUrl,
  String? referer,
  int generation = 0,
  Duration timeout = const Duration(seconds: 45),
}) {
  return CaptchaPreflightJob(
    jobKey: 'job',
    generation: generation,
    source: SourceState(
      name: 'source',
      description: '',
      iconUrl: '',
      tier: 1,
      defaultSubtitleLanguage: '',
      defaultResolution: '',
      searchUrl: searchUrl,
      searchConfigJson: '{}',
      enabled: true,
    ),
    searchKeyword: searchKeyword,
    initialUrl: initialUrl,
    referer: referer,
    captchaConfig: const CaptchaConfig(enable: true),
    timeout: timeout,
  );
}
