import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

abstract interface class WorkspaceLifecycleParticipant {
  PlayerSessionId get sessionId;
  bool get isPlaying;
  bool get isBusy;

  Future<void> onTabActivated();
  Future<void> onTabBackgrounded();
  Future<void> onRouteCovered();
  Future<void> onRouteRevealed();
  Future<void> prepareToClose();
}

/// Route-scoped participant used by Player pages and the future Tab host.
///
/// Route reveal resumes only when route coverage itself paused playback.
class PlayerSessionHandle implements WorkspaceLifecycleParticipant {
  PlayerSessionHandle({
    required this.sessionId,
    required bool Function() isPlaying,
    required bool Function() isBusy,
    required FutureOr<void> Function() pause,
    required FutureOr<void> Function() resume,
    required FutureOr<void> Function() prepareToClose,
    FutureOr<void> Function()? onTabActivated,
    FutureOr<void> Function()? onTabBackgrounded,
  }) : _isPlaying = isPlaying,
       _isBusy = isBusy,
       _pause = pause,
       _resume = resume,
       _prepareToClose = prepareToClose,
       _onTabActivated = onTabActivated,
       _onTabBackgrounded = onTabBackgrounded;

  @override
  final PlayerSessionId sessionId;
  final bool Function() _isPlaying;
  final bool Function() _isBusy;
  final FutureOr<void> Function() _pause;
  final FutureOr<void> Function() _resume;
  final FutureOr<void> Function() _prepareToClose;
  final FutureOr<void> Function()? _onTabActivated;
  final FutureOr<void> Function()? _onTabBackgrounded;

  bool _pausedByRouteCoverage = false;
  Future<void>? _closeFuture;
  Future<void> _routeTransitionQueue = Future<void>.value();

  @override
  bool get isPlaying => _isPlaying();

  @override
  bool get isBusy => _isBusy();

  bool get pausedByRouteCoverage => _pausedByRouteCoverage;

  /// A different Player taking audio focus supersedes route-driven resume.
  Future<void> onPlaybackFocusLost() => _enqueueRouteTransition(() {
    _pausedByRouteCoverage = false;
  });

  @override
  Future<void> onTabActivated() => Future<void>.value(_onTabActivated?.call());

  @override
  Future<void> onTabBackgrounded() =>
      Future<void>.value(_onTabBackgrounded?.call());

  @override
  Future<void> onRouteCovered() => _enqueueRouteTransition(() async {
    if (_pausedByRouteCoverage || !isPlaying) return;
    _pausedByRouteCoverage = true;
    await _pause();
  });

  @override
  Future<void> onRouteRevealed() => _enqueueRouteTransition(() async {
    if (!_pausedByRouteCoverage) return;
    _pausedByRouteCoverage = false;
    await _resume();
  });

  @override
  Future<void> prepareToClose() {
    return _closeFuture ??= Future<void>.value(_prepareToClose());
  }

  Future<void> _enqueueRouteTransition(FutureOr<void> Function() transition) {
    final next = _routeTransitionQueue.then((_) => transition());
    final guarded = next.catchError((Object error, StackTrace stack) {
      debugPrint(
        '[$sessionId] [WorkspaceLifecycle] route transition failed: '
        '$error\n$stack',
      );
    });
    _routeTransitionQueue = guarded;
    return guarded;
  }
}

class WorkspaceLifecycleRegistry {
  WorkspaceLifecycleRegistry._();

  static final WorkspaceLifecycleRegistry instance =
      WorkspaceLifecycleRegistry._();

  final Map<PlayerSessionId, WorkspaceLifecycleParticipant> _participants =
      <PlayerSessionId, WorkspaceLifecycleParticipant>{};

  Iterable<WorkspaceLifecycleParticipant> get participants =>
      List<WorkspaceLifecycleParticipant>.unmodifiable(_participants.values);

  void register(WorkspaceLifecycleParticipant participant) {
    _participants[participant.sessionId] = participant;
  }

  void unregister(PlayerSessionId sessionId) {
    _participants.remove(sessionId);
  }

  WorkspaceLifecycleParticipant? participantOf(PlayerSessionId sessionId) =>
      _participants[sessionId];

  Future<void> prepareAllToClose() async {
    final snapshot = _participants.values.toList(growable: false);
    await Future.wait(
      snapshot.map((participant) => participant.prepareToClose()),
    );
  }

  @visibleForTesting
  void debugReset() => _participants.clear();
}

class AppShutdownCoordinator {
  AppShutdownCoordinator({WorkspaceLifecycleRegistry? registry})
    : _registry = registry ?? WorkspaceLifecycleRegistry.instance;

  static final AppShutdownCoordinator instance = AppShutdownCoordinator();

  final WorkspaceLifecycleRegistry _registry;
  Future<void>? _prepareFuture;

  Future<void> prepareToClose() =>
      _prepareFuture ??= _registry.prepareAllToClose();

  @visibleForTesting
  void debugReset() => _prepareFuture = null;
}
