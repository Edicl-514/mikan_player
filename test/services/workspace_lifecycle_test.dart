import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_lifecycle.dart';

void main() {
  test('route cover resumes only playback paused by route coverage', () async {
    var playing = true;
    var pauses = 0;
    var resumes = 0;
    final handle = PlayerSessionHandle(
      sessionId: const PlayerSessionId('a'),
      isPlaying: () => playing,
      isBusy: () => false,
      pause: () {
        pauses++;
        playing = false;
      },
      resume: () {
        resumes++;
        playing = true;
      },
      prepareToClose: () {},
    );

    await handle.onRouteCovered();
    expect(pauses, 1);
    expect(handle.pausedByRouteCoverage, isTrue);

    await handle.onRouteRevealed();
    expect(resumes, 1);
    expect(playing, isTrue);

    playing = false;
    await handle.onRouteCovered();
    await handle.onRouteRevealed();
    expect(pauses, 1);
    expect(resumes, 1);
  });

  test('tab visibility callbacks do not pause playback', () async {
    var playing = true;
    var pauses = 0;
    var activated = 0;
    var backgrounded = 0;
    final handle = PlayerSessionHandle(
      sessionId: const PlayerSessionId('a'),
      isPlaying: () => playing,
      isBusy: () => false,
      pause: () {
        pauses++;
        playing = false;
      },
      resume: () {},
      prepareToClose: () {},
      onTabActivated: () => activated++,
      onTabBackgrounded: () => backgrounded++,
    );

    await handle.onTabBackgrounded();
    await handle.onTabActivated();

    expect(pauses, 0);
    expect(playing, isTrue);
    expect(backgrounded, 1);
    expect(activated, 1);
  });

  test('rapid cover and reveal serialize pause before resume', () async {
    var playing = true;
    final pauseCompleter = Completer<void>();
    final events = <String>[];
    final handle = PlayerSessionHandle(
      sessionId: const PlayerSessionId('a'),
      isPlaying: () => playing,
      isBusy: () => false,
      pause: () async {
        events.add('pause-start');
        await pauseCompleter.future;
        playing = false;
        events.add('pause-end');
      },
      resume: () {
        playing = true;
        events.add('resume');
      },
      prepareToClose: () {},
    );

    final covered = handle.onRouteCovered();
    final revealed = handle.onRouteRevealed();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['pause-start']);

    pauseCompleter.complete();
    await Future.wait([covered, revealed]);

    expect(events, ['pause-start', 'pause-end', 'resume']);
    expect(playing, isTrue);
  });

  test('losing playback focus cancels route-driven resume', () async {
    var playing = true;
    var resumes = 0;
    final handle = PlayerSessionHandle(
      sessionId: const PlayerSessionId('a'),
      isPlaying: () => playing,
      isBusy: () => false,
      pause: () => playing = false,
      resume: () {
        resumes++;
        playing = true;
      },
      prepareToClose: () {},
    );

    await handle.onRouteCovered();
    await handle.onPlaybackFocusLost();
    await handle.onRouteRevealed();

    expect(resumes, 0);
    expect(playing, isFalse);
  });

  test('prepare close is idempotent', () async {
    final completer = Completer<void>();
    var closes = 0;
    final handle = PlayerSessionHandle(
      sessionId: const PlayerSessionId('a'),
      isPlaying: () => false,
      isBusy: () => true,
      pause: () {},
      resume: () {},
      prepareToClose: () {
        closes++;
        return completer.future;
      },
    );

    final first = handle.prepareToClose();
    final second = handle.prepareToClose();
    expect(identical(first, second), isTrue);
    expect(closes, 1);
    completer.complete();
    await Future.wait([first, second]);
  });

  test('registry prepares every live participant', () async {
    final registry = WorkspaceLifecycleRegistry.instance;
    registry.debugReset();
    final closed = <String>[];

    for (final id in ['a', 'b']) {
      registry.register(
        PlayerSessionHandle(
          sessionId: PlayerSessionId(id),
          isPlaying: () => false,
          isBusy: () => false,
          pause: () {},
          resume: () {},
          prepareToClose: () => closed.add(id),
        ),
      );
    }

    await registry.prepareAllToClose();
    expect(closed, unorderedEquals(['a', 'b']));
    registry.debugReset();
  });

  test('tab close prepares only participants owned by that tab', () async {
    final registry = WorkspaceLifecycleRegistry.instance;
    registry.debugReset();
    final closed = <String>[];

    for (final id in ['a', 'b']) {
      registry.register(
        PlayerSessionHandle(
          sessionId: PlayerSessionId(id),
          isPlaying: () => false,
          isBusy: () => false,
          pause: () {},
          resume: () {},
          prepareToClose: () => closed.add(id),
        ),
        tabId: WorkspaceTabId('tab-$id'),
      );
    }

    await registry.prepareTabToClose(const WorkspaceTabId('tab-a'));
    expect(closed, ['a']);
    expect(
      registry.participantsForTab(const WorkspaceTabId('tab-b')),
      hasLength(1),
    );
    registry.debugReset();
  });
}
