import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_resource_debug.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

typedef PlaybackPauseCallback = FutureOr<void> Function();

/// Process-wide arbitration for the single session allowed to output audio.
///
/// A paused session keeps focus until another session explicitly requests it
/// or the owner closes. This prevents pausing the current player from
/// implicitly resuming a previously focused player.
class PlaybackFocusCoordinator {
  PlaybackFocusCoordinator();

  static final PlaybackFocusCoordinator instance = PlaybackFocusCoordinator();

  final Map<PlayerSessionId, PlaybackPauseCallback> _pauseCallbacks =
      <PlayerSessionId, PlaybackPauseCallback>{};
  PlayerSessionId? _focusedSessionId;
  Future<void> _handoffQueue = Future<void>.value();

  PlayerSessionId? get focusedSessionId => _focusedSessionId;

  void registerSession({
    required PlayerSessionId sessionId,
    required PlaybackPauseCallback onPause,
  }) {
    _pauseCallbacks[sessionId] = onPause;
  }

  /// Serializes focus handoffs and pauses the previous owner before granting.
  Future<bool> requestFocus(PlayerSessionId sessionId) {
    final completer = Completer<bool>();
    _handoffQueue = _handoffQueue
        .then((_) async {
          if (!_pauseCallbacks.containsKey(sessionId)) {
            completer.complete(false);
            return;
          }
          if (_focusedSessionId == sessionId) {
            completer.complete(true);
            return;
          }

          final previousId = _focusedSessionId;
          final previousPause = previousId == null
              ? null
              : _pauseCallbacks[previousId];
          if (previousPause != null) {
            try {
              await previousPause();
            } catch (error, stackTrace) {
              debugPrint(
                '[PlaybackFocus] Failed to pause $previousId: '
                '$error\n$stackTrace',
              );
            }
          }

          if (!_pauseCallbacks.containsKey(sessionId)) {
            completer.complete(false);
            return;
          }
          _focusedSessionId = sessionId;
          PlayerResourceDebugRegistry.instance.playbackFocusSessionId =
              sessionId;
          completer.complete(true);
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) completer.complete(false);
          debugPrint('[PlaybackFocus] Handoff failed: $error\n$stackTrace');
        });
    return completer.future;
  }

  /// Covers direct player controls which begin playback outside page helpers.
  void notifyPlaying(PlayerSessionId sessionId, {required bool playing}) {
    if (playing) {
      unawaited(requestFocus(sessionId));
    }
  }

  void unregisterSession(PlayerSessionId sessionId) {
    _pauseCallbacks.remove(sessionId);
    if (_focusedSessionId != sessionId) return;
    _focusedSessionId = null;
    PlayerResourceDebugRegistry.instance.playbackFocusSessionId = null;
  }

  @visibleForTesting
  void debugReset() {
    _pauseCallbacks.clear();
    _focusedSessionId = null;
    _handoffQueue = Future<void>.value();
    PlayerResourceDebugRegistry.instance.playbackFocusSessionId = null;
  }
}
