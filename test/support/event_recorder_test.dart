// Self-tests for the F-0 event recorder and pending-result helpers.

import 'package:flutter_test/flutter_test.dart';

import 'event_recorder.dart';

void main() {
  group('EventRecorder', () {
    test('records events in arrival order and exposes records', () {
      final recorder = EventRecorder()
        ..record('a')
        ..record('b')
        ..record('c');
      expect(recorder.records.map((e) => e.name).toList(), ['a', 'b', 'c']);
    });

    test('expectInOrder accepts interleaved events', () {
      final recorder = EventRecorder()
        ..record('start')
        ..record('noise')
        ..record('middle')
        ..record('noise')
        ..record('end');
      recorder.expectInOrder(<String>['start', 'middle', 'end']);
    });

    test('expectInOrder accepts an empty expected sequence', () {
      final recorder = EventRecorder()..record('unrelated');
      recorder.expectInOrder(const <String>[]);
    });

    test('expectInOrder fails when the order is broken', () {
      final recorder = EventRecorder()
        ..record('start')
        ..record('end')
        ..record('middle');
      expect(
        () => recorder.expectInOrder(<String>['start', 'middle', 'end']),
        throwsA(isA<TestFailure>()),
      );
    });

    test('expectStrictOrder requires the exact sequence', () {
      final recorder = EventRecorder()
        ..record('start')
        ..record('middle')
        ..record('end');
      recorder.expectStrictOrder(<String>['start', 'middle', 'end']);

      final bad = EventRecorder()
        ..record('start')
        ..record('end');
      expect(
        () => bad.expectStrictOrder(<String>['start', 'middle', 'end']),
        throwsA(isA<TestFailure>()),
      );
    });

    test('expectContainsPredicate matches an event by predicate', () {
      final recorder = EventRecorder()..record('load', result: 42);
      recorder.expectContainsPredicate(
        (e) => e.name == 'load' && e.result == 42,
      );
    });

    test('expectNoMoreCalls throws when events remain', () {
      final recorder = EventRecorder()..record('leak');
      expect(() => recorder.expectNoMoreCalls(), throwsA(isA<TestFailure>()));
    });

    test('clear wipes the ledger', () {
      final recorder = EventRecorder()
        ..record('a')
        ..clear();
      recorder.expectNoMoreCalls();
    });
  });

  group('PendingResult', () {
    test('awaiters resolve when complete is called exactly once', () async {
      final pending = PendingResult<int>();
      var fired = 0;
      pending.future.then((v) => fired = v);
      pending.complete(7);
      await Future<void>.delayed(Duration.zero);
      expect(fired, 7);
      pending.complete(8);
      pending.completeError(StateError('too late'));
      expect(
        fired,
        7,
        reason: 'PendingResult must not fire on subsequent completions',
      );
    });

    test('awaiters reject when completeError is called exactly once', () async {
      final pending = PendingResult<int>();
      var caught = false;
      pending.future.catchError((Object e) {
        caught = true;
        return 0;
      });
      pending.completeError(StateError('broken'));
      await Future<void>.delayed(Duration.zero);
      expect(caught, isTrue);
    });

    test('reports isCompleted once the single completion happens', () {
      final pending = PendingResult<String>();
      expect(pending.isCompleted, isFalse);
      pending.complete('done');
      expect(pending.isCompleted, isTrue);
    });
  });
}
