import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/source_request_gate.dart';

void main() {
  late SourceRequestGate gate;

  setUp(() {
    gate = SourceRequestGate.instance;
    gate.debugReset();
  });

  tearDown(() {
    gate.debugReset();
  });

  test('first start is free and markStarted opens a cooldown window', () {
    const interval = Duration(seconds: 2);
    expect(gate.canStartNow('srcA', interval), isTrue);
    expect(gate.remainingCooldown('srcA', interval), isNull);

    gate.markStarted('srcA');
    expect(gate.canStartNow('srcA', interval), isFalse);
    final remaining = gate.remainingCooldown('srcA', interval);
    expect(remaining, isNotNull);
    expect(remaining!.inMilliseconds, greaterThan(0));
    expect(
      remaining.inMilliseconds,
      lessThanOrEqualTo(interval.inMilliseconds),
    );
  });

  test('sources are independent', () {
    const interval = Duration(seconds: 3);
    gate.markStarted('srcA');
    expect(gate.canStartNow('srcA', interval), isFalse);
    expect(gate.canStartNow('srcB', interval), isTrue);
  });

  test(
    'scheduleWhenReady is latest-wins and fires only once interval elapses',
    () async {
      const interval = Duration(milliseconds: 80);
      gate.markStarted('srcA');

      final fired = <Object>[];
      gate.scheduleWhenReady(
        sourceName: 'srcA',
        minInterval: interval,
        token: 1,
        onReady: () => fired.add(1),
      );
      gate.scheduleWhenReady(
        sourceName: 'srcA',
        minInterval: interval,
        token: 2,
        onReady: () => fired.add(2),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(fired, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fired, [2]);
    },
  );

  test('markStarted cancels a pending waiter for that source', () async {
    const interval = Duration(milliseconds: 100);
    gate.markStarted('srcA');

    var fired = false;
    gate.scheduleWhenReady(
      sourceName: 'srcA',
      minInterval: interval,
      token: 't',
      onReady: () => fired = true,
    );
    // A real start of the same source cancels the delayed waiter.
    gate.markStarted('srcA');

    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(fired, isFalse);
  });

  test('captchaIntervalMs floors very small delays', () {
    expect(
      SourceRequestGate.captchaIntervalMs(0).inMilliseconds,
      SourceRequestGate.captchaIntervalFloorMs,
    );
    expect(
      SourceRequestGate.captchaIntervalMs(500).inMilliseconds,
      SourceRequestGate.captchaIntervalFloorMs,
    );
    expect(SourceRequestGate.captchaIntervalMs(3000).inMilliseconds, 3000);
  });

  test('debugPendingWaiterCount tracks schedule and cancel', () {
    const interval = Duration(seconds: 2);
    gate.markStarted('srcA');
    expect(gate.debugPendingWaiterCount, 0);
    gate.scheduleWhenReady(
      sourceName: 'srcA',
      minInterval: interval,
      token: 't1',
      onReady: () {},
    );
    expect(gate.debugPendingWaiterCount, 1);
    expect(gate.debugPendingToken('srcA'), 't1');
    gate.cancelPending('srcA', token: 't1');
    expect(gate.debugPendingWaiterCount, 0);
  });

  test('same source keeps one latest waiter per session', () async {
    const a = PlayerSessionId('a');
    const b = PlayerSessionId('b');
    const interval = Duration(milliseconds: 40);
    gate.markStarted('shared', sessionId: a);
    final fired = <String>[];

    gate.scheduleWhenReady(
      sessionId: a,
      sourceName: 'shared',
      minInterval: interval,
      token: 'a-old',
      onReady: () => fired.add('a-old'),
    );
    gate.scheduleWhenReady(
      sessionId: a,
      sourceName: 'shared',
      minInterval: interval,
      token: 'a-new',
      onReady: () {
        fired.add('a-new');
        gate.markStarted('shared', sessionId: a);
      },
    );
    gate.scheduleWhenReady(
      sessionId: b,
      sourceName: 'shared',
      minInterval: interval,
      token: 'b',
      onReady: () {
        fired.add('b');
        gate.markStarted('shared', sessionId: b);
      },
    );

    expect(gate.debugPendingWaiterCount, 2);
    expect(gate.debugPendingToken('shared', sessionId: a), 'a-new');
    expect(gate.debugPendingToken('shared', sessionId: b), 'b');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fired, ['a-new', 'b']);
  });

  test('cancelSession leaves another session waiter intact', () async {
    const a = PlayerSessionId('a');
    const b = PlayerSessionId('b');
    const interval = Duration(milliseconds: 40);
    gate.markStarted('shared', sessionId: a);
    final fired = <String>[];
    gate.scheduleWhenReady(
      sessionId: a,
      sourceName: 'shared',
      minInterval: interval,
      token: 'a',
      onReady: () => fired.add('a'),
    );
    gate.scheduleWhenReady(
      sessionId: b,
      sourceName: 'shared',
      minInterval: interval,
      token: 'b',
      onReady: () => fired.add('b'),
    );

    gate.cancelSession(a);
    expect(gate.debugPendingWaiterCount, 1);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(fired, ['b']);
  });
}
