import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/player_session/player_session_lifecycle.dart';

void main() {
  test(
    'prepareToClose is idempotent and rejects callbacks immediately',
    () async {
      final states = <PlayerSessionLifecycleState>[];
      final controller = PlayerSessionLifecycleController(
        sessionId: const PlayerSessionId('lifecycle'),
        onStateChanged: states.add,
      )..activate();
      controller.setGeneration(4);

      var quiesceCalls = 0;
      final release = Completer<void>();
      final first = controller.prepareToClose(() async {
        quiesceCalls++;
        await release.future;
      });
      final second = controller.prepareToClose(() => quiesceCalls++);

      expect(identical(first, second), isTrue);
      expect(controller.state, PlayerSessionLifecycleState.closing);
      expect(controller.acceptsNewWork, isFalse);
      expect(controller.acceptsCallback(4), isFalse);
      expect(quiesceCalls, 1);

      release.complete();
      await first;
      controller.markDisposed();
      controller.markDisposed();
      expect(states, [
        PlayerSessionLifecycleState.active,
        PlayerSessionLifecycleState.closing,
        PlayerSessionLifecycleState.disposed,
      ]);
    },
  );

  test('prepareToClose wait is bounded', () async {
    final controller = PlayerSessionLifecycleController(
      sessionId: const PlayerSessionId('timeout'),
    )..activate();

    final stopwatch = Stopwatch()..start();
    await controller.prepareToClose(
      () => Completer<void>().future,
      timeout: const Duration(milliseconds: 30),
    );
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
    expect(controller.state, PlayerSessionLifecycleState.closing);
  });
}
