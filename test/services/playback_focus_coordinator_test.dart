import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/playback_focus_coordinator.dart';
import 'package:mikan_player/services/player_session/player_resource_debug.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

void main() {
  late PlaybackFocusCoordinator coordinator;

  setUp(() {
    PlayerResourceDebugRegistry.instance.debugReset();
    coordinator = PlaybackFocusCoordinator();
  });

  test('requesting focus pauses the previous session', () async {
    const a = PlayerSessionId('a');
    const b = PlayerSessionId('b');
    var pausesA = 0;
    var pausesB = 0;
    coordinator.registerSession(sessionId: a, onPause: () => pausesA++);
    coordinator.registerSession(sessionId: b, onPause: () => pausesB++);

    expect(await coordinator.requestFocus(a), isTrue);
    expect(await coordinator.requestFocus(b), isTrue);

    expect(pausesA, 1);
    expect(pausesB, 0);
    expect(coordinator.focusedSessionId, b);
    expect(PlayerResourceDebugRegistry.instance.playbackFocusSessionId, b);
  });

  test(
    'pausing the current owner does not restore the previous owner',
    () async {
      const a = PlayerSessionId('a');
      const b = PlayerSessionId('b');
      var pausesA = 0;
      coordinator.registerSession(sessionId: a, onPause: () => pausesA++);
      coordinator.registerSession(sessionId: b, onPause: () {});

      await coordinator.requestFocus(a);
      await coordinator.requestFocus(b);
      coordinator.notifyPlaying(b, playing: false);

      expect(pausesA, 1);
      expect(coordinator.focusedSessionId, b);
    },
  );

  test(
    'unregistering the owner clears focus without affecting others',
    () async {
      const a = PlayerSessionId('a');
      const b = PlayerSessionId('b');
      coordinator.registerSession(sessionId: a, onPause: () {});
      coordinator.registerSession(sessionId: b, onPause: () {});

      await coordinator.requestFocus(a);
      coordinator.unregisterSession(a);

      expect(coordinator.focusedSessionId, isNull);
      expect(await coordinator.requestFocus(b), isTrue);
      expect(coordinator.focusedSessionId, b);
    },
  );

  test('an unregistered session cannot acquire focus', () async {
    expect(
      await coordinator.requestFocus(const PlayerSessionId('missing')),
      isFalse,
    );
    expect(coordinator.focusedSessionId, isNull);
  });
}
