import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/bt_stream_restore_coordinator.dart';

class _DelayGate {
  final List<Completer<void>> _waiters = [];

  Future<void> call(Duration duration) {
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void releaseNext() => _waiters.removeAt(0).complete();
}

void main() {
  const hash = '0123456789abcdef0123456789abcdef01234567';

  test(
    'zero-delay synchronous completion does not leave a stale job',
    () async {
      final coordinator = BtStreamRestoreCoordinator();
      var calls = 0;

      await coordinator.schedule(
        hash,
        delay: Duration.zero,
        operation: (_) async => calls++,
      );
      await coordinator.schedule(
        hash,
        delay: Duration.zero,
        operation: (_) async => calls++,
      );

      expect(calls, 2);
      await coordinator.waitForIdle();
    },
  );

  test('duplicate schedule shares the current job', () async {
    final gate = _DelayGate();
    final coordinator = BtStreamRestoreCoordinator(sleep: gate.call);
    var calls = 0;

    final first = coordinator.schedule(
      hash,
      delay: const Duration(milliseconds: 300),
      operation: (_) async => calls++,
    );
    final second = coordinator.schedule(
      hash,
      delay: const Duration(milliseconds: 300),
      operation: (_) async => calls++,
    );

    expect(identical(first, second), isTrue);
    gate.releaseNext();
    await first;
    expect(calls, 1);
  });

  test(
    'cancel invalidates old job and allows a replacement immediately',
    () async {
      final gate = _DelayGate();
      final coordinator = BtStreamRestoreCoordinator(sleep: gate.call);
      final calls = <String>[];

      coordinator.schedule(
        hash,
        delay: const Duration(milliseconds: 300),
        operation: (_) async => calls.add('old'),
      );
      coordinator.cancel(hash);
      coordinator.schedule(
        hash,
        delay: const Duration(milliseconds: 300),
        operation: (_) async => calls.add('new'),
      );

      gate.releaseNext();
      gate.releaseNext();
      await coordinator.waitForIdle();
      expect(calls, ['new']);
    },
  );

  test('waitForIdle includes logically cancelled jobs', () async {
    final gate = _DelayGate();
    final coordinator = BtStreamRestoreCoordinator(sleep: gate.call);
    var completed = false;

    coordinator.schedule(
      hash,
      delay: const Duration(milliseconds: 300),
      operation: (_) async {},
    );
    coordinator.cancel(hash);
    final waiting = coordinator.waitForIdle().then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.releaseNext();
    await waiting;
    expect(completed, isTrue);
  });

  test('dispose invalidates pending jobs', () async {
    final gate = _DelayGate();
    final coordinator = BtStreamRestoreCoordinator(sleep: gate.call);
    var calls = 0;

    coordinator.schedule(
      hash,
      delay: const Duration(milliseconds: 300),
      operation: (_) async => calls++,
    );
    coordinator.dispose();
    gate.releaseNext();
    await coordinator.waitForIdle();

    expect(calls, 0);
  });
}
