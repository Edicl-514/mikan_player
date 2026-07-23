import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_resource_debug.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/source_request_gate.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';

import '../../support/fake_player_session.dart';

/// Multi-Player-session regression coverage carried forward from Phase 0.
///
/// Local schedulers remain independently testable, while production creation
/// is now wrapped by WebViewResourceCoordinator. Gate and close expectations
/// below assert the Phase 1 owner-isolated behavior.
void main() {
  late SourceRequestGate gate;
  late PlayerResourceDebugRegistry registry;

  setUp(() {
    PlayerSessionId.debugResetAllocator();
    registry = PlayerResourceDebugRegistry.instance;
    registry.debugReset();
    gate = SourceRequestGate.instance;
    gate.debugReset();
  });

  tearDown(() {
    registry.debugReset();
    gate.debugReset();
  });

  group('local max_concurrent stacks across sessions (Phase 0 risk)', () {
    test(
      'two schedulers each fill their local max and total live workers sum',
      () {
        final dual = DualFakePlayerSessions(maxConcurrentPerSession: 3);
        dual.registerAll();
        addTearDown(dual.closeAll);

        dual.a.fillLocalBudget(sourcePrefix: 'a');
        dual.b.fillLocalBudget(sourcePrefix: 'b');

        expect(dual.a.scheduler.workerCount, 3);
        expect(dual.b.scheduler.workerCount, 3);

        final snap = dual.snapshot();
        // Phase 0: no app-wide hard limit — totals stack.
        expect(snap.liveWorkerCount, 6);
        expect(snap.activeJobCount, 6);
        expect(snap.sessionCount, 2);
      },
    );
  });

  group('SourceRequestGate same-source session isolation', () {
    test(
      'both sessions retain a waiter and start under the shared cooldown',
      () async {
        final dual = DualFakePlayerSessions();
        dual.registerAll();
        addTearDown(dual.closeAll);

        const interval = Duration(milliseconds: 80);
        gate.markStarted('shared-src');

        dual.a.scheduleGateWaiter(
          sourceName: 'shared-src',
          minInterval: interval,
          token: 'token-a',
        );
        expect(gate.debugPendingWaiterCount, 1);
        expect(gate.debugPendingToken('shared-src'), 'token-a');

        dual.b.scheduleGateWaiter(
          sourceName: 'shared-src',
          minInterval: interval,
          token: 'token-b',
        );
        expect(gate.debugPendingWaiterCount, 2);
        expect(
          gate.debugPendingToken('shared-src', sessionId: dual.a.sessionId),
          'token-a',
        );
        expect(
          gate.debugPendingToken('shared-src', sessionId: dual.b.sessionId),
          'token-b',
        );

        await Future<void>.delayed(const Duration(milliseconds: 220));
        expect(dual.a.acceptedCallbacks, ['token-a']);
        expect(dual.b.acceptedCallbacks, ['token-b']);
      },
    );
  });

  group('session A cleanup must not affect session B', () {
    test(
      'closing A leaves B workers/jobs intact and does not cancel B gate waiter',
      () async {
        final dual = DualFakePlayerSessions(maxConcurrentPerSession: 2);
        dual.registerAll();
        addTearDown(() {
          if (!dual.b.isDisposed) dual.b.closeSession();
        });

        dual.a.fillLocalBudget(sourcePrefix: 'a');
        dual.b.fillLocalBudget(sourcePrefix: 'b');

        const interval = Duration(milliseconds: 100);
        gate.markStarted('src-b-only');
        dual.b.scheduleGateWaiter(
          sourceName: 'src-b-only',
          minInterval: interval,
          token: 'b-waiter',
        );
        expect(gate.debugPendingWaiterCount, 1);

        dual.a.closeSession();

        expect(dual.a.scheduler.workerCount, 0);
        expect(dual.b.scheduler.workerCount, 2);
        expect(dual.b.scheduler.activeVideoJobCount, 2);
        // closeSession deliberately avoids cancelAllPending.
        expect(gate.debugPendingWaiterCount, 1);
        expect(gate.debugPendingToken('src-b-only'), 'b-waiter');

        final snap = dual.snapshot();
        expect(snap.sessionCount, 1);
        expect(snap.liveWorkerCount, 2);

        await Future<void>.delayed(const Duration(milliseconds: 140));
        expect(dual.b.acceptedCallbacks, ['b-waiter']);
      },
    );

    test(
      'cancelAllPending from A would wipe B waiters (documents the hazard)',
      () {
        final dual = DualFakePlayerSessions();
        dual.registerAll();
        addTearDown(dual.closeAll);

        const interval = Duration(seconds: 2);
        gate.markStarted('src');
        dual.b.scheduleGateWaiter(
          sourceName: 'src',
          minInterval: interval,
          token: 'b',
        );
        expect(gate.debugPendingWaiterCount, 1);

        // What a naive session-close path would do today if it used cancelAll.
        gate.cancelAllPending(ownerTag: dual.a.ownerTag);
        expect(gate.debugPendingWaiterCount, 0);
        expect(gate.debugPendingToken('src'), isNull);
      },
    );
  });

  group('late callback generation / owner guard', () {
    test(
      'after closeSession, the session waiter is cancelled before it can fire',
      () async {
        final session = FakePlayerSession(
          sessionId: const PlayerSessionId('ps-late'),
        );
        session.register();
        addTearDown(() {
          if (!session.isDisposed) session.closeSession();
        });

        final genAtStart = session.bumpGeneration();
        expect(session.isCallbackCurrent(genAtStart), isTrue);
        gate.markStarted('late-source');
        session.scheduleGateWaiter(
          sourceName: 'late-source',
          minInterval: const Duration(milliseconds: 40),
          token: 'late-token',
        );

        session.closeSession();
        expect(session.isDisposed, isTrue);
        // closeSession bumps generation again.
        expect(session.isCallbackCurrent(genAtStart), isFalse);
        expect(
          isSearchGenerationCurrent(
            resultLoadToken: genAtStart,
            currentLoadToken: session.generation,
            isDisposed: session.isDisposed,
          ),
          isFalse,
        );
        expect(
          mayStartSearchScopedJob(
            jobLoadToken: genAtStart,
            currentLoadToken: session.generation,
            isDisposed: session.isDisposed,
          ),
          isFalse,
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(session.acceptedCallbacks, isEmpty);
        expect(session.lateCallbacks, isEmpty);
      },
    );

    test(
      'stale generation before dispose is also rejected (search replacement)',
      () {
        final session = FakePlayerSession();
        session.register();
        addTearDown(session.closeSession);

        final stale = session.bumpGeneration();
        final current = session.bumpGeneration();
        expect(session.isCallbackCurrent(stale), isFalse);
        expect(session.isCallbackCurrent(current), isTrue);
      },
    );
  });

  group('two-session search / close sequence', () {
    test('A late callback is rejected after close while B continues', () async {
      final dual = DualFakePlayerSessions(maxConcurrentPerSession: 3);
      dual.registerAll();
      addTearDown(() {
        if (!dual.b.isDisposed) dual.b.closeSession();
      });

      dual.a.bumpGeneration();
      dual.b.bumpGeneration();
      dual.a.fillLocalBudget(sourcePrefix: 'a');
      dual.b.fillLocalBudget(sourcePrefix: 'b');

      const interval = Duration(milliseconds: 60);
      gate.markStarted('source-a');
      gate.markStarted('source-b');
      dual.a.scheduleGateWaiter(
        sourceName: 'source-a',
        minInterval: interval,
        token: 'a',
      );
      dual.b.scheduleGateWaiter(
        sourceName: 'source-b',
        minInterval: interval,
        token: 'b',
      );
      expect(gate.debugPendingWaiterCount, 2);

      dual.a.closeSession();
      expect(gate.debugPendingWaiterCount, 1);
      expect(dual.snapshot().sessionCount, 1);
      expect(dual.b.scheduler.workerCount, 3);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(dual.a.acceptedCallbacks, isEmpty);
      expect(dual.a.lateCallbacks, isEmpty);
      expect(dual.b.acceptedCallbacks, ['b']);
    });
  });
}
