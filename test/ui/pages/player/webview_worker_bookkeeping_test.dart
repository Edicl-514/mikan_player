import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_bookkeeping.dart';

/// Phase 2 B2 tests for the pure video/captcha bookkeeping operations.
///
/// These tests pin down the slot + reverse-map consistency invariants:
///   - start: slot fields + map entry set together
///   - release/cancel: slot fields cleared + map entry removed together
///   - record: consecutiveFailures + health transitions
///
/// WebViewWorkerSlot is a plain mutable data class — no platform bindings —
/// so we construct real instances and real Maps in pure Dart.

const _threshold = 3;

WebViewWorkerSlot _slot({required int workerId}) {
  return WebViewWorkerSlot(workerId: workerId);
}

void main() {
  group('startVideoJobOnSlot', () {
    test('sets slot fields and reverse-maps pageKey -> workerId', () {
      final slot = _slot(workerId: 5);
      final jobs = <String, int>{};
      startVideoJobOnSlot(slot, 'pageA', 'srcA', jobs);
      expect(slot.pageKey, 'pageA');
      expect(slot.kind, WebViewWorkerKind.video);
      expect(slot.lastSourceName, 'srcA');
      expect(slot.health, WebViewWorkerHealth.running);
      expect(jobs, {'pageA': 5});
    });

    test('overwrites previous job on same slot', () {
      final slot = _slot(workerId: 3);
      final jobs = <String, int>{};
      startVideoJobOnSlot(slot, 'page1', 'srcA', jobs);
      startVideoJobOnSlot(slot, 'page2', 'srcB', jobs);
      expect(slot.pageKey, 'page2');
      expect(jobs, {'page1': 3, 'page2': 3});
    });
  });

  group('startCaptchaJobOnSlot', () {
    test('sets slot fields and reverse-maps taskKey -> workerId', () {
      final slot = _slot(workerId: 7);
      final jobs = <String, int>{};
      startCaptchaJobOnSlot(slot, 'taskA', 'srcC', jobs);
      expect(slot.taskKey, 'taskA');
      expect(slot.kind, WebViewWorkerKind.captcha);
      expect(slot.lastSourceName, 'srcC');
      expect(slot.health, WebViewWorkerHealth.running);
      expect(jobs, {'taskA': 7});
    });
  });

  group('releaseCaptchaSlot', () {
    test('removes reverse-map entry and clears slot job fields', () {
      final slots = {5: _slot(workerId: 5)};
      final captchaJobs = {'taskA': 5};
      startCaptchaJobOnSlot(slots[5]!, 'taskA', 'srcA', captchaJobs);
      releaseCaptchaSlot('taskA', captchaJobs, slots);
      expect(captchaJobs, isEmpty);
      expect(slots[5]!.taskKey, isNull);
      expect(slots[5]!.kind, isNull);
      // slot stays in the map (reusable)
      expect(slots, contains(5));
    });

    test('no-op if taskKey not in activeCaptchaJobs', () {
      final slots = {5: _slot(workerId: 5)};
      final captchaJobs = <String, int>{};
      releaseCaptchaSlot('unknown', captchaJobs, slots);
      expect(captchaJobs, isEmpty);
      expect(slots[5]!.taskKey, isNull);
      expect(slots[5]!.kind, isNull);
    });

    test(
      'stale callback: slot.taskKey mismatch -> map removed but slot untouched',
      () {
        final slots = {5: _slot(workerId: 5)};
        final captchaJobs = {'taskA': 5};
        // slot.taskKey is null (not set), doesn't match 'taskA'
        releaseCaptchaSlot('taskA', captchaJobs, slots);
        expect(captchaJobs, isEmpty);
        // slot.taskKey was already null, stays null
        expect(slots[5]!.taskKey, isNull);
      },
    );
  });

  group('cancelVideoJob', () {
    test('removes reverse-map entry, sets cancelling, clears pageKey+kind', () {
      final slots = {3: _slot(workerId: 3)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[3]!, 'pageA', 'srcA', videoJobs);
      final removed = cancelVideoJob('pageA', videoJobs, slots);
      expect(removed, 3);
      expect(videoJobs, isEmpty);
      expect(slots[3]!.health, WebViewWorkerHealth.cancelling);
      expect(slots[3]!.pageKey, isNull);
      expect(slots[3]!.kind, isNull);
    });

    test('returns null if no active job for pageKey', () {
      final slots = {3: _slot(workerId: 3)};
      final videoJobs = <String, int>{};
      expect(cancelVideoJob('unknown', videoJobs, slots), isNull);
    });

    test('returns workerId even if slot missing (map still cleared)', () {
      final videoJobs = {'pageA': 9};
      // no slot with workerId 9 in slots map
      final slots = <int, WebViewWorkerSlot>{};
      final removed = cancelVideoJob('pageA', videoJobs, slots);
      expect(removed, 9);
      expect(videoJobs, isEmpty);
    });
  });

  group('releaseVideoSlotOnIdle', () {
    test(
      'clears pageKey+kind and removes reverse-map entry, returns prevPageKey',
      () {
        final slots = {4: _slot(workerId: 4)};
        final videoJobs = <String, int>{};
        startVideoJobOnSlot(slots[4]!, 'pageX', 'srcX', videoJobs);
        final prev = releaseVideoSlotOnIdle(4, videoJobs, slots);
        expect(prev, 'pageX');
        expect(videoJobs, isEmpty);
        expect(slots[4]!.pageKey, isNull);
        expect(slots[4]!.kind, isNull);
      },
    );

    test('returns null if worker not in slots', () {
      final videoJobs = <String, int>{};
      expect(releaseVideoSlotOnIdle(99, videoJobs, {}), isNull);
    });

    test('returns null if slot has no pageKey (already idle)', () {
      final slots = {4: _slot(workerId: 4)};
      final videoJobs = <String, int>{};
      final prev = releaseVideoSlotOnIdle(4, videoJobs, slots);
      expect(prev, isNull);
      expect(slots[4]!.kind, isNull);
    });
  });

  group('recordVideoWorkerResult', () {
    test('success resets consecutiveFailures to 0, returns false', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
      slots[1]!.consecutiveFailures = 2;
      final marked = recordVideoWorkerResult(
        'p',
        false,
        videoJobs,
        slots,
        _threshold,
      );
      expect(marked, false);
      expect(slots[1]!.consecutiveFailures, 0);
      expect(slots[1]!.health, WebViewWorkerHealth.running);
    });

    test('failure increments but below threshold -> not marked', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
      final marked = recordVideoWorkerResult(
        'p',
        true,
        videoJobs,
        slots,
        _threshold,
      );
      expect(marked, false);
      expect(slots[1]!.consecutiveFailures, 1);
      expect(slots[1]!.health, WebViewWorkerHealth.running);
    });

    test('failure reaching threshold -> marked unhealthy, returns true', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
      slots[1]!.consecutiveFailures = 2;
      final marked = recordVideoWorkerResult(
        'p',
        true,
        videoJobs,
        slots,
        _threshold,
      );
      expect(marked, true);
      expect(slots[1]!.consecutiveFailures, 3);
      expect(slots[1]!.health, WebViewWorkerHealth.unhealthy);
    });

    test('no active job for pageKey -> returns false, no mutation', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      final marked = recordVideoWorkerResult(
        'unknown',
        true,
        videoJobs,
        slots,
        _threshold,
      );
      expect(marked, false);
      expect(slots[1]!.consecutiveFailures, 0);
    });

    test('slot missing -> returns false', () {
      final videoJobs = {'p': 99};
      final slots = <int, WebViewWorkerSlot>{};
      expect(
        recordVideoWorkerResult('p', true, videoJobs, slots, _threshold),
        false,
      );
    });
  });

  group('recordCaptchaWorkerResult', () {
    test('success resets consecutiveFailures, returns false', () {
      final slots = {2: _slot(workerId: 2)};
      final captchaJobs = <String, int>{};
      startCaptchaJobOnSlot(slots[2]!, 't', 's', captchaJobs);
      slots[2]!.consecutiveFailures = 2;
      expect(
        recordCaptchaWorkerResult('t', false, captchaJobs, slots, _threshold),
        false,
      );
      expect(slots[2]!.consecutiveFailures, 0);
    });

    test('failure reaching threshold -> unhealthy', () {
      final slots = {2: _slot(workerId: 2)};
      final captchaJobs = <String, int>{};
      startCaptchaJobOnSlot(slots[2]!, 't', 's', captchaJobs);
      slots[2]!.consecutiveFailures = 2;
      expect(
        recordCaptchaWorkerResult('t', true, captchaJobs, slots, _threshold),
        true,
      );
      expect(slots[2]!.health, WebViewWorkerHealth.unhealthy);
    });

    test('no active job -> false, no mutation', () {
      final slots = {2: _slot(workerId: 2)};
      final captchaJobs = <String, int>{};
      expect(
        recordCaptchaWorkerResult(
          'unknown',
          true,
          captchaJobs,
          slots,
          _threshold,
        ),
        false,
      );
    });
  });

  group('map-slot consistency (B2 invariants)', () {
    test('start then complete: both maps empty, slot idle', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
      expect(videoJobs, {'p': 1});
      releaseVideoSlotOnIdle(1, videoJobs, slots);
      expect(videoJobs, isEmpty);
      expect(slots[1]!.pageKey, isNull);
      expect(slots[1]!.kind, isNull);
    });

    test('start then cancel: map empty, slot cancelling', () {
      final slots = {1: _slot(workerId: 1)};
      final videoJobs = <String, int>{};
      startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
      cancelVideoJob('p', videoJobs, slots);
      expect(videoJobs, isEmpty);
      expect(slots[1]!.health, WebViewWorkerHealth.cancelling);
      expect(slots[1]!.pageKey, isNull);
    });

    test('captcha start then release: map empty, slot reusable', () {
      final slots = {1: _slot(workerId: 1)};
      final captchaJobs = <String, int>{};
      startCaptchaJobOnSlot(slots[1]!, 't', 's', captchaJobs);
      expect(captchaJobs, {'t': 1});
      releaseCaptchaSlot('t', captchaJobs, slots);
      expect(captchaJobs, isEmpty);
      expect(slots[1]!.taskKey, isNull);
      expect(slots[1]!.kind, isNull);
      // can reuse slot for a new job
      startVideoJobOnSlot(slots[1]!, 'p2', 's2', {});
      expect(slots[1]!.kind, WebViewWorkerKind.video);
    });

    test(
      'video start + failure to threshold + idle release removes unhealthy slot',
      () {
        final slots = {1: _slot(workerId: 1)};
        final videoJobs = <String, int>{};
        startVideoJobOnSlot(slots[1]!, 'p', 's', videoJobs);
        // simulate 3 consecutive failures
        recordVideoWorkerResult('p', true, videoJobs, slots, _threshold);
        recordVideoWorkerResult('p', true, videoJobs, slots, _threshold);
        final marked = recordVideoWorkerResult(
          'p',
          true,
          videoJobs,
          slots,
          _threshold,
        );
        expect(marked, true);
        expect(slots[1]!.health, WebViewWorkerHealth.unhealthy);
        // page releases the slot on idle
        releaseVideoSlotOnIdle(1, videoJobs, slots);
        // page would then remove the unhealthy slot — simulate that
        slots.remove(1);
        expect(slots, isEmpty);
        expect(videoJobs, isEmpty);
      },
    );
  });
}
