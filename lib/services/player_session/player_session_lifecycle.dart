import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

/// Route-scoped lifecycle guard for one live Player page.
///
/// Closing is deliberately two-stage: [prepareToClose] quiesces asynchronous
/// work and can be awaited by a future route/Tab close protocol, while
/// [markDisposed] remains the final synchronous widget teardown signal.
class PlayerSessionLifecycleController {
  PlayerSessionLifecycleController({
    required this.sessionId,
    this.onStateChanged,
  });

  final PlayerSessionId sessionId;
  final ValueChanged<PlayerSessionLifecycleState>? onStateChanged;

  PlayerSessionLifecycleState _state = PlayerSessionLifecycleState.created;
  int _generation = 0;
  Future<void>? _prepareFuture;

  PlayerSessionLifecycleState get state => _state;
  int get generation => _generation;
  bool get acceptsNewWork =>
      _state != PlayerSessionLifecycleState.closing &&
      _state != PlayerSessionLifecycleState.disposed;

  void activate() => _transitionTo(PlayerSessionLifecycleState.active);

  void background() => _transitionTo(PlayerSessionLifecycleState.background);

  int advanceGeneration() => ++_generation;

  void setGeneration(int generation) {
    if (generation < _generation) {
      throw StateError(
        'Session $sessionId generation cannot move backwards '
        '($_generation -> $generation)',
      );
    }
    _generation = generation;
  }

  /// Returns true only while the session can still accept callbacks and the
  /// callback belongs to the current generation.
  bool acceptsCallback(int generation) =>
      acceptsNewWork && generation == _generation;

  /// Starts close preparation once and returns the same future to all callers.
  ///
  /// [quiesce] is invoked synchronously up to its first await, so callers from
  /// State.dispose still invalidate generations and reject new work before
  /// synchronous widget teardown proceeds. The wait is bounded: a slow native
  /// resource release must not indefinitely prevent a route from unmounting.
  Future<void> prepareToClose(
    FutureOr<void> Function() quiesce, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    final existing = _prepareFuture;
    if (existing != null) return existing;
    if (_state == PlayerSessionLifecycleState.disposed) {
      return Future<void>.value();
    }

    _transitionTo(PlayerSessionLifecycleState.closing);
    late final Future<void> result;
    try {
      final pending = quiesce();
      result = Future<void>.value(pending)
          .timeout(
            timeout,
            onTimeout: () {
              debugPrint(
                '[$sessionId] [PlayerSessionLifecycle] prepareToClose timed out '
                'after ${timeout.inMilliseconds}ms',
              );
            },
          )
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              '[$sessionId] [PlayerSessionLifecycle] prepareToClose failed: '
              '$error\n$stackTrace',
            );
          });
    } catch (error, stackTrace) {
      debugPrint(
        '[$sessionId] [PlayerSessionLifecycle] prepareToClose failed: '
        '$error\n$stackTrace',
      );
      result = Future<void>.value();
    }
    _prepareFuture = result;
    return result;
  }

  void markDisposed() {
    if (_state == PlayerSessionLifecycleState.disposed) return;
    _transitionTo(PlayerSessionLifecycleState.disposed);
  }

  void _transitionTo(PlayerSessionLifecycleState next) {
    if (_state == next) return;
    if (_state == PlayerSessionLifecycleState.disposed) {
      throw StateError(
        'Disposed session $sessionId cannot transition to $next',
      );
    }
    if (_state == PlayerSessionLifecycleState.closing &&
        next != PlayerSessionLifecycleState.disposed) {
      throw StateError('Closing session $sessionId cannot transition to $next');
    }
    _state = next;
    onStateChanged?.call(next);
  }
}
