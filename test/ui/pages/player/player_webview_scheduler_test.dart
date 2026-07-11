import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';

/// Phase 2 B6 tests for [PlayerWebViewScheduler].
///
/// The scheduler folds the previously-page-owned mutable state (worker-slot
/// table, active video/captcha reverse maps, the monotonic workerId counter,
/// and the [WebViewPoolPumpCoordinator]) into one object. These composition
/// tests exercise the *cross-cutting* map/slot consistency invariants that
/// the per-module unit tests (B1–B5) could only check in isolation:
///
///   - cross-kind lifecycle (captcha -> idle -> video) on the same worker
///   - atomic start failures leave state untouched
///   - video complete / cancel / late-idle keep maps + slots aligned
///   - captcha complete / cancel / stale-idle keep maps + slots aligned
///   - consecutive failures reaching the threshold evict an unhealthy worker
///   - reset clears jobs/slots and invalidates the old pump token
///   - two staggered pumps with different tokens: the older one completing
///     must not clear the newer pump's scheduled flag / state
///
/// Every mutation step is followed by [PlayerWebViewScheduler.validateInvariants]
/// (via [expectConsistent]) so any drift between the slot table and the reverse
/// maps surfaces immediately.

const _threshold = 3;
const _maxConcurrent = 4;

void expectConsistent(PlayerWebViewScheduler s, [String? label]) {
  final errors = s.validateInvariants();
  if (errors.isNotEmpty) {
    fail(
      'invariants violated${label == null ? '' : ' ($label)'}:\n'
      '${errors.map((e) => '  - $e').join('\n')}',
    );
  }
}

PlayerWebViewScheduler newScheduler() => PlayerWebViewScheduler();

void main() {
  group('cross-kind lifecycle (captcha -> idle -> video on same worker)', () {
    test(
      'captcha start -> release -> markIdle -> video start reuses the slot',
      () {
        final s = newScheduler();

        final cap = s.acquireIdleCaptchaWorkerSlot(
          useWorkerPool: true,
          maxConcurrent: _maxConcurrent,
        );
        expect(cap.slot, isNotNull);
        expect(cap.createdNew, isTrue);
        expectConsistent(s, 'after captcha acquire');

        s.startCaptchaJob(cap.slot!, 'taskA', 'srcX');
        expectConsistent(s, 'after captcha start');
        expect(s.activeCaptchaJobs, {'taskA': cap.slot!.workerId});
        expect(cap.slot!.kind, WebViewWorkerKind.captcha);

        // captcha completes: release the slot, then the page marks it
        // healthy-idle (mirrors _onCaptchaWorkerIdle).
        s.releaseCaptchaSlot('taskA');
        expectConsistent(s, 'after captcha release');
        expect(s.activeCaptchaJobs, isEmpty);
        expect(cap.slot!.taskKey, isNull);
        expect(cap.slot!.kind, isNull);
        expect(cap.slot!.lastSourceName, 'srcX');

        s.markSlotIdle(cap.slot!.workerId);
        expectConsistent(s, 'after markIdle');
        expect(cap.slot!.health, WebViewWorkerHealth.idle);

        // next pump: same-source affinity should hand this warm slot back.
        final vid = s.acquireIdleVideoWorkerSlot(
          {'srcX'},
          useWorkerPool: true,
          maxConcurrent: _maxConcurrent,
        );
        expectConsistent(s, 'after video acquire');
        expect(vid.slot, same(cap.slot));
        expect(vid.createdNew, isFalse);

        s.startVideoJob(vid.slot!, 'pageA', 'srcX');
        expectConsistent(s, 'after video start');
        expect(s.activeVideoJobs, {'pageA': cap.slot!.workerId});
        expect(cap.slot!.kind, WebViewWorkerKind.video);
        expect(s.activeCaptchaJobs, isEmpty);
      },
    );

    test('video -> idle -> captcha on same worker also stays consistent', () {
      final s = newScheduler();
      final vid = s.acquireIdleVideoWorkerSlot(
        {'srcY'},
        useWorkerPool: true,
        maxConcurrent: _maxConcurrent,
      );
      s.startVideoJob(vid.slot!, 'pageB', 'srcY');
      expectConsistent(s, 'after video start');

      s.releaseVideoSlotOnIdle(vid.slot!.workerId);
      expectConsistent(s, 'after video release');
      s.markSlotIdle(vid.slot!.workerId);
      expectConsistent(s, 'after markIdle');

      final cap = s.acquireIdleCaptchaWorkerSlot(
        useWorkerPool: true,
        maxConcurrent: _maxConcurrent,
      );
      expect(cap.slot, same(vid.slot));
      s.startCaptchaJob(cap.slot!, 'taskB', 'srcY');
      expectConsistent(s, 'after captcha start');
      expect(s.activeVideoJobs, isEmpty);
      expect(s.activeCaptchaJobs, {'taskB': cap.slot!.workerId});
    });
  });

  group('atomic start failures leave state untouched', () {
    test('starting a second job on a busy slot throws and changes nothing', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      final beforeJobs = Map<String, int>.from(s.activeVideoJobs);
      final beforeKind = slot.kind;
      final beforePageKey = slot.pageKey;

      expect(() => s.startVideoJob(slot, 'pageB', 'srcB'), throwsStateError);
      expectConsistent(s, 'after rejected second video start');
      expect(s.activeVideoJobs, beforeJobs);
      expect(slot.kind, beforeKind);
      expect(slot.pageKey, beforePageKey);
    });

    test(
      'starting a job whose pageKey is already active throws and is a no-op',
      () {
        final s = newScheduler();
        final w0 = s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startVideoJob(w0, 'pageA', 'srcA');
        final w1 = s
            .acquireIdleVideoWorkerSlot(
              {'srcB'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        final beforeW1Kind = w1.kind;
        final beforeJobs = Map<String, int>.from(s.activeVideoJobs);

        expect(() => s.startVideoJob(w1, 'pageA', 'srcA'), throwsStateError);
        expectConsistent(s, 'after rejected duplicate pageKey');
        expect(s.activeVideoJobs, beforeJobs);
        expect(w1.kind, beforeW1Kind);
      },
    );

    test(
      'assigning a captcha job to a worker already running video throws',
      () {
        final s = newScheduler();
        final slot = s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startVideoJob(slot, 'pageA', 'srcA');
        expectConsistent(s, 'video running');

        // The bookkeeping start guards reject a non-idle slot, so the worker
        // cannot appear in BOTH active maps at once.
        expect(
          () => s.startCaptchaJob(slot, 'taskA', 'srcA'),
          throwsStateError,
        );
        expectConsistent(s, 'after rejected cross-kind start');
        expect(s.activeCaptchaJobs, isEmpty);
        expect(s.activeVideoJobs, {'pageA': slot.workerId});
      },
    );
  });

  group('video complete / cancel / late idle keep map-slot consistent', () {
    test('complete: releaseVideoSlotOnIdle empties the reverse map', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      expectConsistent(s, 'after start');

      final prev = s.releaseVideoSlotOnIdle(slot.workerId);
      expect(prev, 'pageA');
      expectConsistent(s, 'after idle release');
      expect(s.activeVideoJobs, isEmpty);
      expect(slot.pageKey, isNull);
      expect(slot.kind, isNull);
      expect(slot.lastSourceName, 'srcA');
    });

    test('cancel: cancelVideoJob sets cancelling + clears fields', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      expectConsistent(s, 'after start');

      final removed = s.cancelVideoJob('pageA');
      expect(removed, slot.workerId);
      expectConsistent(s, 'after cancel');
      expect(s.activeVideoJobs, isEmpty);
      expect(slot.health, WebViewWorkerHealth.cancelling);
      expect(slot.pageKey, isNull);
      expect(slot.kind, isNull);
    });

    test('late idle callback on an already-released slot is a no-op', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      s.releaseVideoSlotOnIdle(slot.workerId);
      expectConsistent(s, 'after first release');

      // A duplicate idle callback (e.g. post-frame + dispose race) must not
      // corrupt state: it returns null and leaves maps empty.
      final prev = s.releaseVideoSlotOnIdle(slot.workerId);
      expect(prev, isNull);
      expectConsistent(s, 'after late idle');
      expect(s.activeVideoJobs, isEmpty);
    });

    test('cancel of an unknown pageKey returns null and changes nothing', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      expect(s.cancelVideoJob('unknown'), isNull);
      expectConsistent(s, 'after cancel-unknown');
      expect(s.activeVideoJobs, {'pageA': slot.workerId});
    });
  });

  group('captcha complete / cancel / stale idle keep map-slot consistent', () {
    test('complete: releaseCaptchaSlot empties the reverse map', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleCaptchaWorkerSlot(
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startCaptchaJob(slot, 'taskA', 'srcA');
      expectConsistent(s, 'after start');

      s.releaseCaptchaSlot('taskA');
      expectConsistent(s, 'after release');
      expect(s.activeCaptchaJobs, isEmpty);
      expect(slot.taskKey, isNull);
      expect(slot.kind, isNull);
      expect(slot.lastSourceName, 'srcA');
    });

    test('cancel: cancelCaptchaSlot sets cancelling + clears fields', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleCaptchaWorkerSlot(
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startCaptchaJob(slot, 'taskA', 'srcA');
      expectConsistent(s, 'after start');

      final removed = s.cancelCaptchaSlot('taskA');
      expect(removed, slot.workerId);
      expectConsistent(s, 'after cancel');
      expect(s.activeCaptchaJobs, isEmpty);
      expect(slot.health, WebViewWorkerHealth.cancelling);
      expect(slot.taskKey, isNull);
      expect(slot.kind, isNull);
    });

    test(
      'stale idle: clearStaleCaptchaSlotOnIdle drops a stale reverse map',
      () {
        final s = newScheduler();
        final slot = s
            .acquireIdleCaptchaWorkerSlot(
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startCaptchaJob(slot, 'taskA', 'srcA');
        expectConsistent(s, 'after start');

        // Simulate the _onCaptchaWorkerIdle path: the task has been removed
        // from the page's active-task set, so the slot's lingering taskKey is
        // stale and must be cleared together with its reverse-mapping.
        s.clearStaleCaptchaSlotOnIdle(slot.workerId, 'taskA');
        expectConsistent(s, 'after stale clear');
        expect(s.activeCaptchaJobs, isEmpty);
        expect(slot.taskKey, isNull);
        expect(slot.kind, isNull);
      },
    );

    test('release of an unknown taskKey is a safe no-op', () {
      final s = newScheduler();
      s.releaseCaptchaSlot('unknown');
      expectConsistent(s, 'after release-unknown');
      expect(s.activeCaptchaJobs, isEmpty);
    });
  });

  group('unhealthy worker eviction after failure threshold', () {
    test(
      'video: threshold consecutive failures mark + remove the slot on idle',
      () {
        final s = newScheduler();
        final slot = s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startVideoJob(slot, 'pageA', 'srcA');
        expectConsistent(s, 'after start');

        expect(s.recordVideoWorkerResult('pageA', true, _threshold), isFalse);
        expectConsistent(s, 'after fail 1');
        expect(s.recordVideoWorkerResult('pageA', true, _threshold), isFalse);
        expectConsistent(s, 'after fail 2');
        final marked = s.recordVideoWorkerResult('pageA', true, _threshold);
        expect(marked, isTrue);
        expectConsistent(s, 'after fail 3 (marked)');
        expect(s.healthOf(slot.workerId), WebViewWorkerHealth.unhealthy);

        // Page then releases the slot on idle and removes the unhealthy worker.
        s.releaseVideoSlotOnIdle(slot.workerId);
        s.removeSlot(slot.workerId);
        expectConsistent(s, 'after remove');
        expect(s.workerCount, 0);
        expect(s.activeVideoJobs, isEmpty);
        expect(s.slotOf(slot.workerId), isNull);
      },
    );

    test('captcha: threshold failures mark + remove the slot on idle', () {
      final s = newScheduler();
      final slot = s
          .acquireIdleCaptchaWorkerSlot(
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startCaptchaJob(slot, 'taskA', 'srcA');
      expectConsistent(s, 'after start');

      s.recordCaptchaWorkerResult('taskA', true, _threshold);
      s.recordCaptchaWorkerResult('taskA', true, _threshold);
      expect(s.recordCaptchaWorkerResult('taskA', true, _threshold), isTrue);
      expectConsistent(s, 'marked unhealthy');
      expect(s.healthOf(slot.workerId), WebViewWorkerHealth.unhealthy);

      // Real flow: _onCaptchaPreflightResult releases the slot (clears the
      // reverse map + job fields) BEFORE the post-frame _onCaptchaWorkerIdle
      // removes the unhealthy worker.
      s.releaseCaptchaSlot('taskA');
      expectConsistent(s, 'after release before remove');
      s.removeSlot(slot.workerId);
      expectConsistent(s, 'after remove');
      expect(s.workerCount, 0);
    });

    test(
      'a success resets consecutiveFailures so threshold is not reached',
      () {
        final s = newScheduler();
        final slot = s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startVideoJob(slot, 'pageA', 'srcA');
        s.recordVideoWorkerResult('pageA', true, _threshold);
        s.recordVideoWorkerResult('pageA', true, _threshold);
        // success in between resets the counter
        s.recordVideoWorkerResult('pageA', false, _threshold);
        expectConsistent(s, 'after success reset');
        expect(slot.consecutiveFailures, 0);
        expect(s.recordVideoWorkerResult('pageA', true, _threshold), isFalse);
        expect(s.healthOf(slot.workerId), WebViewWorkerHealth.running);
      },
    );
  });

  group('reset clears jobs/slots and invalidates the old pump token', () {
    test('resetForNewSearch clears active maps, cancels busy slots', () {
      final s = newScheduler();
      final v = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(v, 'pageA', 'srcA');
      final c = s
          .acquireIdleCaptchaWorkerSlot(
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startCaptchaJob(c, 'taskA', 'srcA');
      expectConsistent(s, 'before reset');
      expect(s.workerCount, 2);

      s.resetForNewSearch();
      expectConsistent(s, 'after reset');
      expect(s.activeVideoJobs, isEmpty);
      expect(s.activeCaptchaJobs, isEmpty);
      // slot table is preserved for cross-search WebView reuse ...
      expect(s.workerCount, 2);
      // ... busy slots are cancelling, idle ones healthy-idle.
      expect(v.health, WebViewWorkerHealth.cancelling);
      expect(v.pageKey, isNull);
      expect(v.kind, isNull);
      expect(c.health, WebViewWorkerHealth.cancelling);
      expect(c.taskKey, isNull);
      expect(c.kind, isNull);
    });

    test('resetForNewSearch invalidates the old pump token', () {
      final s = newScheduler();
      s.pumpCoordinator.scheduleStaggered((_) async {});
      final oldToken = s.pumpCoordinator.token;
      expect(s.pumpCoordinator.isScheduled, isTrue);

      s.resetForNewSearch();
      expect(s.pumpCoordinator.isCurrentToken(oldToken), isFalse);
      expect(s.pumpCoordinator.isScheduled, isFalse);
      expect(s.pumpCoordinator.token, oldToken + 1);
    });

    test('clearForPoolToggle drops the whole slot table', () {
      final s = newScheduler();
      final v = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(v, 'pageA', 'srcA');
      expectConsistent(s, 'before toggle');

      s.clearForPoolToggle();
      expectConsistent(s, 'after toggle');
      expect(s.workerCount, 0);
      expect(s.activeVideoJobs, isEmpty);
      expect(s.activeCaptchaJobs, isEmpty);
    });

    test('clearForDispose empties everything', () {
      final s = newScheduler();
      s.startVideoJob(
        s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!,
        'pageA',
        'srcA',
      );
      expectConsistent(s, 'before dispose');
      s.clearForDispose();
      expectConsistent(s, 'after dispose');
      expect(s.workerCount, 0);
      expect(s.activeVideoJobs, isEmpty);
      expect(s.activeCaptchaJobs, isEmpty);
    });
  });

  group(
    'staggered pump with two tokens: old completion cannot clear new state',
    () {
      test(
        'a late-arriving old-token completion leaves the new schedule intact',
        () {
          final s = newScheduler();
          // Issue pump A (token 1).
          s.pumpCoordinator.scheduleStaggered((_) async {});
          final tokenA = s.pumpCoordinator.token;
          expect(s.pumpCoordinator.isScheduled, isTrue);

          // Meanwhile a reset bumps the token and clears the flag.
          s.resetForNewSearch();
          expect(s.pumpCoordinator.isCurrentToken(tokenA), isFalse);

          // A new pump B is scheduled. reset already bumped the token once,
          // so this schedule bumps it again -> tokenB = tokenA + 2.
          s.pumpCoordinator.scheduleStaggered((_) async {});
          final tokenB = s.pumpCoordinator.token;
          expect(tokenB, tokenA + 2);
          expect(s.pumpCoordinator.isScheduled, isTrue);

          // The OLD pump A finally completes and tries to clear the flag.
          s.pumpCoordinator.clearScheduledIfCurrent(tokenA);
          // The new schedule must NOT be cleared by the stale completion.
          expect(s.pumpCoordinator.isScheduled, isTrue);
          expect(s.pumpCoordinator.isCurrentToken(tokenB), isTrue);

          // The scheduler's own job/slot state is unaffected by the stale
          // pump completion (mutations only go through scheduler methods).
          expectConsistent(s, 'after stale completion');
          expect(s.activeVideoJobs, isEmpty);
          expect(s.activeCaptchaJobs, isEmpty);
          expect(s.workerCount, 0);

          // The NEW pump B completing DOES clear the flag.
          s.pumpCoordinator.clearScheduledIfCurrent(tokenB);
          expect(s.pumpCoordinator.isScheduled, isFalse);
        },
      );

      test(
        'old staggered pump does not clear new scheduler job state mid-flight',
        () {
          final s = newScheduler();
          // Start a video job on worker 0, then issue staggered pump A.
          final w0 = s
              .acquireIdleVideoWorkerSlot(
                {'srcA'},
                useWorkerPool: true,
                maxConcurrent: _maxConcurrent,
              )
              .slot!;
          s.startVideoJob(w0, 'pageA', 'srcA');
          expectConsistent(s, 'before pump A');
          s.pumpCoordinator.scheduleStaggered((_) async {});
          final tokenA = s.pumpCoordinator.token;

          // A reset invalidates pump A and clears the jobs, then a brand-new
          // job starts under a fresh slot.
          s.resetForNewSearch();
          expectConsistent(s, 'after reset');
          final w1 = s
              .acquireIdleVideoWorkerSlot(
                {'srcB'},
                useWorkerPool: true,
                maxConcurrent: _maxConcurrent,
              )
              .slot!;
          s.startVideoJob(w1, 'pageB', 'srcB');
          expectConsistent(s, 'after new job');

          // Pump A's stale completion must not touch the new job state.
          s.pumpCoordinator.clearScheduledIfCurrent(tokenA);
          expectConsistent(s, 'after stale pump A completion');
          expect(s.activeVideoJobs, {'pageB': w1.workerId});
          expect(s.activeCaptchaJobs, isEmpty);
        },
      );

      test('reset mid-staggered leaves the coordinator schedulable again', () {
        final s = newScheduler();
        s.pumpCoordinator.scheduleStaggered((_) async {});
        final tokenA = s.pumpCoordinator.token;
        s.resetForNewSearch();
        expect(s.pumpCoordinator.isCurrentToken(tokenA), isFalse);

        // Scheduling again works cleanly (flag was cleared by reset). reset
        // bumped the token once, this schedule bumps it again -> +2.
        s.pumpCoordinator.scheduleStaggered((_) async {});
        expect(s.pumpCoordinator.isScheduled, isTrue);
        expect(s.pumpCoordinator.token, tokenA + 2);
        expectConsistent(s, 'after re-schedule');
      });
    },
  );

  group('validateInvariants surfaces drift (negative sanity)', () {
    test('flags an active video entry whose slot has been removed', () {
      final s = newScheduler();
      // Manually corrupt by starting then disposing the slot out of band
      // (simulates a bug where removeSlot runs before the reverse map clear).
      final slot = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: _maxConcurrent,
          )
          .slot!;
      s.startVideoJob(slot, 'pageA', 'srcA');
      s.removeSlot(slot.workerId); // corruption: reverse map still has it
      final errors = s.validateInvariants();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('has no slot'));
    });
  });

  group('acquire budget / affinity', () {
    test('acquire evicts an unhealthy idle slot to make room at budget', () {
      final s = newScheduler();
      const max = 1;
      // Worker 0 runs a captcha, fails to threshold -> unhealthy, then is
      // released on result. It is now unhealthy-idle: canAcceptJob is false
      // (health != idle) but canDisposeWhenIdle is true, so the only way to
      // acquire a fresh worker under the budget is to evict it.
      final a = s
          .acquireIdleCaptchaWorkerSlot(useWorkerPool: true, maxConcurrent: max)
          .slot!;
      s.startCaptchaJob(a, 'taskA', 'srcA');
      s.recordCaptchaWorkerResult('taskA', true, _threshold);
      s.recordCaptchaWorkerResult('taskA', true, _threshold);
      expect(s.recordCaptchaWorkerResult('taskA', true, _threshold), isTrue);
      expect(s.healthOf(a.workerId), WebViewWorkerHealth.unhealthy);
      s.releaseCaptchaSlot('taskA');
      expectConsistent(s, 'unhealthy idle worker');
      expect(s.workerCount, 1);

      final b = s.acquireIdleCaptchaWorkerSlot(
        useWorkerPool: true,
        maxConcurrent: max,
      );
      expectConsistent(s, 'after eviction acquire');
      // The unhealthy slot was disposed and a brand-new worker created.
      expect(b.slot, isNotNull);
      expect(b.createdNew, isTrue);
      expect(s.workerCount, 1);
      expect(b.slot!.workerId, isNot(a.workerId));
      expect(s.slotOf(a.workerId), isNull);
    });

    test(
      'same-source affinity picks the warm worker over a lower-id non-warm one',
      () {
        final s = newScheduler();
        // w0 (lower id) runs srcB, w1 (higher id) runs srcA. After both idle,
        // an affinity acquire for {srcA} must pick w1 (warm) despite w0 having
        // the lower workerId that selectAnyIdleAcceptableSlot would prefer.
        final w0 = s
            .acquireIdleVideoWorkerSlot(
              {'srcB'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        s.startVideoJob(w0, 'pageB', 'srcB');
        final w1 = s
            .acquireIdleVideoWorkerSlot(
              {'srcA'},
              useWorkerPool: true,
              maxConcurrent: _maxConcurrent,
            )
            .slot!;
        expect(w1.workerId, greaterThan(w0.workerId));
        s.startVideoJob(w1, 'pageA', 'srcA');
        s.releaseVideoSlotOnIdle(w0.workerId);
        s.markSlotIdle(w0.workerId);
        s.releaseVideoSlotOnIdle(w1.workerId);
        s.markSlotIdle(w1.workerId);
        expectConsistent(s, 'two idle workers');

        final picked = s.acquireIdleVideoWorkerSlot(
          {'srcA'},
          useWorkerPool: true,
          maxConcurrent: _maxConcurrent,
        );
        expectConsistent(s, 'after affinity pick');
        expect(picked.slot, same(w1));
        expect(picked.slot!.lastSourceName, 'srcA');
      },
    );

    test('at capacity with no disposable idle returns null', () {
      final s = newScheduler();
      const max = 1;
      final busy = s
          .acquireIdleVideoWorkerSlot(
            {'srcA'},
            useWorkerPool: true,
            maxConcurrent: max,
          )
          .slot!;
      s.startVideoJob(busy, 'pageA', 'srcA');
      expectConsistent(s, 'busy');
      // No disposable idle (the only slot is busy running) -> null.
      final none = s.acquireIdleCaptchaWorkerSlot(
        useWorkerPool: true,
        maxConcurrent: max,
      );
      expect(none.slot, isNull);
      expectConsistent(s, 'after null acquire');
    });
  });
}
