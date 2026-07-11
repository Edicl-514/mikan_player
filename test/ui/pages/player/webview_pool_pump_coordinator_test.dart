import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/webview_pool_pump_coordinator.dart';

/// Phase 2 B5 tests for WebViewPoolPumpCoordinator.
///
/// This is a *stateful* coordinator (not pure functions like B1–B4), so
/// tests drive its internal state machine by passing fake callbacks. The
/// behavior under test is the verbatim contract of `_PlayerPageState`'s
/// `_webViewPoolPumpScheduled` / `_webViewPumpToken` fields:
///   - immediate schedules cancel pending staggered via token bump
///   - staggered schedules no-op when already scheduled
///   - staggered loop completion clears flag iff token still current
///   - reset clears flag + bumps token
void main() {
  WebViewPoolPumpCoordinator make() => WebViewPoolPumpCoordinator();

  group('initial state', () {
    test('starts idle, token 0', () {
      final c = make();
      expect(c.isScheduled, isFalse);
      expect(c.token, 0);
    });
  });

  group('scheduleImmediate', () {
    test('sets nothing, just invokes the pump; returns pump value', () {
      final c = make();
      var pumpInvoked = 0;
      final started = c.scheduleImmediate(() {
        pumpInvoked++;
        return true;
      });
      expect(started, isTrue);
      expect(pumpInvoked, 1);
      expect(c.isScheduled, isFalse);
    });

    test(
      'previously-scheduled staggered is cancelled (token bumps, flag clears)',
      () {
        final c = make();
        var staggeredInvoked = 0;
        c.scheduleStaggered((_) async => staggeredInvoked++);
        expect(c.isScheduled, isTrue);
        final tokenBefore = c.token;

        // immediate bumps token and clears flag
        c.scheduleImmediate(() => false);
        expect(c.isScheduled, isFalse);
        expect(c.token, tokenBefore + 1);
        expect(
          staggeredInvoked,
          1,
        ); // the staggered callback was invoked synchronously (same as page),
        // but the loop's async continuation (after its first `await`) would
        // see !isCurrentToken(token) and break.
      },
    );

    test('consecutive immediate schedules each invoke pump', () {
      final c = make();
      var count = 0;
      c.scheduleImmediate(() {
        count++;
        return false;
      });
      c.scheduleImmediate(() {
        count++;
        return true;
      });
      c.scheduleImmediate(() {
        count++;
        return false;
      });
      expect(count, 3);
      // No staggered flag set since only immediate schedules were made.
      expect(c.isScheduled, isFalse);
    });
  });

  group('scheduleStaggered', () {
    test(
      'first call sets flag + bumps token + starts pump with new token',
      () async {
        final c = make();
        var receivedTokens = <int>[];
        c.scheduleStaggered((token) async {
          receivedTokens.add(token);
        });
        expect(c.isScheduled, isTrue);
        expect(receivedTokens, [1]);
        expect(c.token, 1);
      },
    );

    test('clears the scheduled flag when the pump completes', () async {
      final c = make();
      final pumpDone = Completer<void>();
      final scheduled = c.scheduleStaggered((_) => pumpDone.future);

      expect(c.isScheduled, isTrue);
      pumpDone.complete();
      await scheduled;

      expect(c.isScheduled, isFalse);
    });

    test('clears the scheduled flag when the pump fails', () async {
      final c = make();
      final scheduled = c.scheduleStaggered(
        (_) async => throw StateError('pump failed'),
      );

      expect(c.isScheduled, isTrue);
      await expectLater(scheduled, throwsStateError);
      expect(c.isScheduled, isFalse);
    });

    test(
      'second call while scheduled is no-op (does not invoke pump)',
      () async {
        final c = make();
        var invokeCount = 0;
        c.scheduleStaggered((_) async => invokeCount++);
        c.scheduleStaggered((_) async => invokeCount++);
        c.scheduleStaggered((_) async => invokeCount++);
        expect(invokeCount, 1);
        expect(c.isScheduled, isTrue);
        expect(c.token, 1); // only one bump
      },
    );

    test('after clearScheduledIfCurrent, can schedule again', () async {
      final c = make();
      var invokeCount = 0;
      c.scheduleStaggered((_) async => invokeCount++);
      final firstToken = c.token;

      c.clearScheduledIfCurrent(firstToken);
      expect(c.isScheduled, isFalse);

      c.scheduleStaggered((_) async => invokeCount++);
      expect(c.isScheduled, isTrue);
      expect(c.token, firstToken + 1);
      expect(invokeCount, 2);
    });

    test('clearScheduledIfCurrent with stale token does NOT clear flag', () {
      final c = make();
      c.scheduleStaggered((_) async {});
      final firstToken = c.token;
      // Immediate bumps token: flag should clear, staggered never runs sync
      c.scheduleImmediate(() => false);
      expect(c.token, firstToken + 1);
      // Either way, clearScheduledIfCurrent with stale token is a no-op
      c.clearScheduledIfCurrent(firstToken); // stale
      // isScheduled already false; gating stays false
      expect(c.isScheduled, isFalse);
      c.scheduleStaggered((_) async {});
      c.scheduleImmediate(() => false);
      c.clearScheduledIfCurrent(firstToken + 999); // stale
      expect(c.isScheduled, isFalse);
    });

    test('isCurrentToken cancels a loop when reset bumps the token', () {
      final c = make();
      c.scheduleStaggered((token) async {
        // simulate async task
      });
      final issuedToken = c.token;
      // Before cancel: token still current
      expect(c.isCurrentToken(issuedToken), isTrue);

      c.reset(); // cancels
      expect(c.isCurrentToken(issuedToken), isFalse);
      expect(c.token, issuedToken + 1);
      expect(c.isScheduled, isFalse);
    });
  });

  group('reset', () {
    test('clears flag + bumps token when idle', () {
      final c = make();
      expect(c.isScheduled, isFalse);
      expect(c.token, 0);
      c.reset();
      expect(c.isScheduled, isFalse);
      expect(c.token, 1);
    });

    test('clears flag + bumps token when scheduled (cancels pending)', () {
      final c = make();
      c.scheduleStaggered((_) async {});
      c.reset();
      expect(c.isScheduled, isFalse);
    });

    test('monotonic token across resets', () {
      final c = make();
      expect(c.token, 0);
      c.reset();
      expect(c.token, 1);
      c.reset();
      c.reset();
      expect(c.token, 3);
    });
  });

  group('isCurrentToken', () {
    test('matches coordinator token', () {
      final c = make();
      expect(c.isCurrentToken(0), isTrue);
      c.scheduleStaggered((_) async {});
      expect(c.isCurrentToken(1), isTrue);
      expect(c.isCurrentToken(0), isFalse);
      c.reset();
      expect(c.isCurrentToken(2), isTrue);
      expect(c.isCurrentToken(1), isFalse);
    });
  });

  group('coordinator + simulated pump loop (B5 end-to-end shape)', () {
    test('immediate then immediate cancels staggered in flight correctly', () {
      // Following a typical pump: scheduleImmediate bumps token; previously
      // issued staggered tokens become non-current; the staggered loop
      // would break at its next `isCurrentToken` check.
      final c = make();
      int? staggeredLoopToken;
      c.scheduleStaggered((token) async {
        staggeredLoopToken = token; // capture the issued token
      });
      final issued = c.token;

      // mid-loop page calls immediate
      c.scheduleImmediate(() => true);
      expect(c.isCurrentToken(issued), isFalse);
      expect(staggeredLoopToken, issued); // staggered ran captured the token
    });

    test('reset during staggered cancels pending staggered', () {
      final c = make();
      var staggeredInvoked = 0;
      c.scheduleStaggered((token) async => staggeredInvoked++);
      final issued = c.token;
      c.reset();
      // page's staggered loop sees !isCurrentToken(token) and breaks; flag
      // was cleared by reset.
      expect(c.isCurrentToken(issued), isFalse);
      expect(c.isScheduled, isFalse);
      // Subsequent schedules work normally (flag was cleared by reset).
      c.scheduleStaggered((_) async => staggeredInvoked++);
      expect(c.isScheduled, isTrue);
      expect(staggeredInvoked, 2); // both staggered callbacks ran synchronously
    });
  });
}
