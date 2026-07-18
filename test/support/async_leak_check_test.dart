// Self-tests for the F-0 async leak checker.
// Confirms the happy path (every handle disposed) and the leaked-handle path
// surface the documented behavior so future tests can rely on the helper.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'async_leak_check.dart';

void main() {
  group('AsyncLeakCheck', () {
    test('registerStreamSubscription + disposeAll satisfies verify()', () async {
      final leaker = AsyncLeakCheck();
      addTearDown(leaker.disposeAll);
      final controller = StreamController<void>.broadcast();
      addTearDown(controller.close);
      final sub = controller.stream.listen((_) {});
      leaker.registerStreamSubscription(sub, label: 'stream');

      // Registered handle is alive until dispose() runs on the handle.
      expect(leaker.pendingCount, 1);
      await leaker.disposeAll();
      expect(leaker.pendingCount, 0);
      leaker.verify();
    });

    test('pending leaks surface as TestFailure naming the leaked resource',
        () async {
      final leaker = AsyncLeakCheck();
      addTearDown(leaker.disposeAll);
      final controller = StreamController<void>.broadcast();
      addTearDown(controller.close);
      final sub = controller.stream.listen((_) {});
      leaker.registerStreamSubscription(sub, label: 'leakySubscription');

      try {
        leaker.verify(message: 'leaked sub expected');
        fail('verify should have thrown');
      } on TestFailure catch (e) {
        expect(e.message, contains('leakySubscription'));
        expect(e.message, contains('leaked sub expected'));
      }

      // Dispose via the handle path so verify can pass afterward.
      await leaker.disposeAll();
      leaker.verify();
    });

    test('registerTimer is reported as a leak until disposeAll', () async {
      final leaker = AsyncLeakCheck();
      addTearDown(leaker.disposeAll);
      final t = Timer(const Duration(seconds: 60), () {});
      leaker.registerTimer(t, label: 'oneMinute');

      expect(leaker.pendingCount, 1);
      await leaker.disposeAll();
      expect(leaker.pendingCount, 0);
    });

    test('disposeAll does not mask secondary failures', () async {
      final leaker = AsyncLeakCheck();
      var first = false;
      var second = false;
      leaker.registerDisposer(() => first = true, label: 'first');
      leaker.registerDisposer(
        () => throw StateError('boom'),
        label: 'throwing',
      );
      leaker.registerDisposer(() => second = true, label: 'second');

      await leaker.disposeAll();
      expect(first, isTrue);
      expect(second, isTrue);
      expect(leaker.disposeErrors, hasLength(1));
      expect(leaker.disposeErrors.single, isA<StateError>());
    });
  });
}
