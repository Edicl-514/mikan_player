import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_selection.dart';

/// Phase 2 B1 tests for the pure idle-slot selection rules.
///
/// WebViewWorkerSlot is a plain data class with a public constructor and
/// mutable fields — no platform bindings, so we can construct real instances
/// in pure Dart tests.
///
/// The three functions under test replicate sort/pick logic that was
/// previously inline in `_PlayerPageState` methods. The goal of each test is
/// to pin down which slot is chosen (or rejected) given a concrete slot set,
/// so future refactors of the scheduler can diff against these expectations.

WebViewWorkerSlot _slot({
  required int workerId,
  WebViewWorkerKind? kind,
  WebViewWorkerHealth health = WebViewWorkerHealth.idle,
  String? lastSourceName,
}) {
  final s = WebViewWorkerSlot(workerId: workerId);
  s.kind = kind;
  s.health = health;
  s.lastSourceName = lastSourceName;
  return s;
}

void main() {
  group('selectDisposableIdleSlotId', () {
    test('empty slots -> null', () {
      expect(selectDisposableIdleSlotId([]), isNull);
    });

    test('all busy (running) -> null', () {
      final slots = [
        _slot(workerId: 1, health: WebViewWorkerHealth.running),
        _slot(workerId: 2, health: WebViewWorkerHealth.cancelling),
      ];
      expect(selectDisposableIdleSlotId(slots), isNull);
    });

    test('one disposable idle slot -> its workerId', () {
      final slots = [_slot(workerId: 5)];
      expect(selectDisposableIdleSlotId(slots), 5);
    });

    test('unhealthy preferred over healthy for removal', () {
      final slots = [
        _slot(workerId: 3, health: WebViewWorkerHealth.unhealthy),
        _slot(workerId: 7, health: WebViewWorkerHealth.idle),
      ];
      expect(selectDisposableIdleSlotId(slots), 3);
    });

    test('cold preferred for removal (keep warm slots)', () {
      final slots = [
        _slot(workerId: 2, lastSourceName: 'srcA'), // warm
        _slot(workerId: 8, lastSourceName: null), // cold
      ];
      expect(selectDisposableIdleSlotId(slots), 8);
    });

    test('same health/warm -> highest workerId preferred for removal', () {
      final slots = [_slot(workerId: 4), _slot(workerId: 9)];
      expect(selectDisposableIdleSlotId(slots), 9);
    });

    test('kindFilter=video never matches (kind!=null => not disposable)', () {
      // In the unified pool an idle slot has kind==null. A slot with
      // kind==video is running an active job so canDisposeWhenIdle is false.
      // Therefore a kindFilter of video can never select a slot in the unified
      // pool — the caller falls back to the null-kind path.
      final slots = [
        _slot(workerId: 1, kind: WebViewWorkerKind.video),
        _slot(workerId: 2, kind: WebViewWorkerKind.captcha),
      ];
      expect(
        selectDisposableIdleSlotId(slots, kindFilter: WebViewWorkerKind.video),
        isNull,
      );
    });

    test('kindFilter=video with no disposable video slot -> null', () {
      final slots = [
        _slot(workerId: 2, kind: WebViewWorkerKind.captcha),
      ];
      expect(
        selectDisposableIdleSlotId(slots, kindFilter: WebViewWorkerKind.video),
        isNull,
      );
    });

    test('kindFilter=null considers all disposable idle slots', () {
      final slots = [
        _slot(workerId: 1, kind: WebViewWorkerKind.video),
        _slot(workerId: 2, kind: WebViewWorkerKind.captcha),
        _slot(workerId: 3, health: WebViewWorkerHealth.unhealthy),
      ];
      expect(selectDisposableIdleSlotId(slots), 3);
    });

    test('non-disposable video slot excluded even if kindFilter matches', () {
      final slots = [
        _slot(
          workerId: 1,
          kind: WebViewWorkerKind.video,
          health: WebViewWorkerHealth.running,
        ),
      ];
      expect(
        selectDisposableIdleSlotId(slots, kindFilter: WebViewWorkerKind.video),
        isNull,
      );
    });

    test('unhealthy takes priority over cold/warm tiebreak', () {
      final slots = [
        _slot(workerId: 1, lastSourceName: 'srcA'), // warm, healthy
        _slot(workerId: 5, health: WebViewWorkerHealth.unhealthy), // unhealthy
        _slot(workerId: 9, lastSourceName: null), // cold, healthy
      ];
      // unhealthy beats both cold and warm
      expect(selectDisposableIdleSlotId(slots), 5);
    });
  });

  group('selectSameSourceIdleSlot', () {
    test('empty -> null', () {
      expect(selectSameSourceIdleSlot([], {}), isNull);
    });

    test('no slot with matching lastSourceName -> null', () {
      final slots = [_slot(workerId: 1, lastSourceName: 'srcA')];
      expect(selectSameSourceIdleSlot(slots, {'srcB'}), isNull);
    });

    test('one matching -> returns it', () {
      final slots = [_slot(workerId: 5, lastSourceName: 'srcA')];
      final result = selectSameSourceIdleSlot(slots, {'srcA'});
      expect(result, isNotNull);
      expect(result!.workerId, 5);
    });

    test('multiple matching -> lowest workerId', () {
      final slots = [
        _slot(workerId: 3, lastSourceName: 'srcB'),
        _slot(workerId: 7, lastSourceName: 'srcB'),
      ];
      final result = selectSameSourceIdleSlot(slots, {'srcB'});
      expect(result, isNotNull);
      expect(result!.workerId, 3);
    });

    test('slot with matching lastSourceName but running -> excluded', () {
      final slots = [
        _slot(
          workerId: 1,
          lastSourceName: 'srcA',
          health: WebViewWorkerHealth.running,
        ),
      ];
      expect(selectSameSourceIdleSlot(slots, {'srcA'}), isNull);
    });

    test('slot with matching lastSourceName but unhealthy -> excluded', () {
      final slots = [
        _slot(
          workerId: 1,
          lastSourceName: 'srcA',
          health: WebViewWorkerHealth.unhealthy,
        ),
      ];
      expect(selectSameSourceIdleSlot(slots, {'srcA'}), isNull);
    });

    test('pendingSourceNames empty -> null', () {
      final slots = [_slot(workerId: 1, lastSourceName: 'srcA')];
      expect(selectSameSourceIdleSlot(slots, {}), isNull);
    });

    test('matching slot preferred over lower-workerId non-matching', () {
      final slots = [
        _slot(workerId: 1, lastSourceName: 'srcA'), // doesn't match srcB
        _slot(workerId: 10, lastSourceName: 'srcB'), // matches
      ];
      final result = selectSameSourceIdleSlot(slots, {'srcB'});
      expect(result, isNotNull);
      expect(result!.workerId, 10);
    });

    test('multiple sources in pending set, one slot matches the other', () {
      final slots = [_slot(workerId: 5, lastSourceName: 'srcX')];
      final result = selectSameSourceIdleSlot(slots, {'srcX', 'srcY'});
      expect(result, isNotNull);
      expect(result!.workerId, 5);
    });
  });

  group('selectAnyIdleAcceptableSlot', () {
    test('empty -> null', () {
      expect(selectAnyIdleAcceptableSlot([]), isNull);
    });

    test('no canAcceptJob slot -> null', () {
      final slots = [
        _slot(workerId: 1, health: WebViewWorkerHealth.running),
        _slot(workerId: 2, health: WebViewWorkerHealth.cancelling),
        _slot(workerId: 3, health: WebViewWorkerHealth.unhealthy),
      ];
      expect(selectAnyIdleAcceptableSlot(slots), isNull);
    });

    test('one canAcceptJob slot -> returns it', () {
      final slots = [_slot(workerId: 7)];
      final result = selectAnyIdleAcceptableSlot(slots);
      expect(result, isNotNull);
      expect(result!.workerId, 7);
    });

    test('multiple canAcceptJob -> lowest workerId', () {
      final slots = [
        _slot(workerId: 5),
        _slot(workerId: 2),
        _slot(workerId: 8),
      ];
      final result = selectAnyIdleAcceptableSlot(slots);
      expect(result, isNotNull);
      expect(result!.workerId, 2);
    });

    test('unhealthy (canAcceptJob=false) excluded', () {
      final slots = [
        _slot(workerId: 1, health: WebViewWorkerHealth.unhealthy),
        _slot(workerId: 4, health: WebViewWorkerHealth.idle),
      ];
      final result = selectAnyIdleAcceptableSlot(slots);
      expect(result, isNotNull);
      expect(result!.workerId, 4);
    });
  });

  group('capacity / composition scenarios', () {
    test('at capacity: all busy (no canAcceptJob) -> acquire returns null', () {
      final slots = [
        _slot(workerId: 1, health: WebViewWorkerHealth.running),
        _slot(workerId: 2, health: WebViewWorkerHealth.running),
        _slot(workerId: 3, health: WebViewWorkerHealth.running),
      ];
      expect(selectAnyIdleAcceptableSlot(slots), isNull);
      expect(selectSameSourceIdleSlot(slots, {'srcA'}), isNull);
    });

    test('over budget: trim selects the best disposable idle slot', () {
      // Simulate a pool with 5 slots where maxConcurrent is 3. Two must be
      // trimmed. selectDisposableIdleSlotId should return the unhealthy one
      // first (priority removal), then the cold one.
      final slots = [
        _slot(workerId: 1, health: WebViewWorkerHealth.running), // busy, kept
        _slot(workerId: 2, kind: WebViewWorkerKind.video), // idle, warm
        _slot(
          workerId: 3,
          health: WebViewWorkerHealth.unhealthy,
        ), // idle, unhealthy
        _slot(workerId: 4), // idle, cold
        _slot(
          workerId: 5,
          health: WebViewWorkerHealth.cancelling,
        ), // busy, kept
      ];
      // First trim pass — unhealthy wins.
      expect(selectDisposableIdleSlotId(slots), 3);
      // After removing workerId 3, the remaining idle candidates are 2 (warm)
      // and 4 (cold). Cold is preferred for removal to keep warm affinity.
      final afterFirst = slots.where((s) => s.workerId != 3).toList();
      expect(selectDisposableIdleSlotId(afterFirst), 4);
    });
  });
}
