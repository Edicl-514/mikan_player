import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

typedef _PendingKey = ({PlayerSessionId sessionId, String sourceName});

/// Process-wide per-source cooldown with session-isolated waiters.
///
/// Cooldown timestamps remain shared by source, but each Player session keeps
/// its own latest-wins waiter. Only one session is handed a ready claim for a
/// source at a time; [markStarted] releases that claim and begins the next
/// global cooldown before another session can proceed.
class SourceRequestGate {
  SourceRequestGate._();

  static final SourceRequestGate instance = SourceRequestGate._();
  static const PlayerSessionId _legacySessionId = PlayerSessionId('legacy');

  static const Duration defaultVideoInterval = Duration(milliseconds: 350);
  static const int captchaIntervalFloorMs = 800;

  final Map<String, DateTime> _lastStartedAt = <String, DateTime>{};
  final Map<_PendingKey, _PendingStart> _pending = {};
  final Map<String, Timer> _sourceTimers = {};
  final Map<String, PlayerSessionId> _readyClaims = {};
  final Map<String, int> _lastServedSequence = {};
  int _sequence = 0;

  int get debugPendingWaiterCount => _pending.length;

  @visibleForTesting
  Object? debugPendingToken(String sourceName, {PlayerSessionId? sessionId}) {
    if (sessionId != null) {
      return _pending[(sessionId: sessionId, sourceName: sourceName)]?.token;
    }
    final matches =
        _pending.entries
            .where((entry) => entry.key.sourceName == sourceName)
            .toList()
          ..sort((a, b) => a.value.sequence.compareTo(b.value.sequence));
    return matches.isEmpty ? null : matches.last.value.token;
  }

  @visibleForTesting
  PlayerSessionId? debugReadyClaim(String sourceName) =>
      _readyClaims[sourceName];

  Duration? remainingCooldown(String sourceName, Duration minInterval) {
    if (minInterval <= Duration.zero) return null;
    final last = _lastStartedAt[sourceName];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= minInterval) return null;
    return minInterval - elapsed;
  }

  bool canStartNow(String sourceName, Duration minInterval) =>
      remainingCooldown(sourceName, minInterval) == null;

  bool canSessionStartNow(
    PlayerSessionId sessionId,
    String sourceName,
    Duration minInterval,
  ) {
    final claim = _readyClaims[sourceName];
    return (claim == null || claim == sessionId) &&
        canStartNow(sourceName, minInterval);
  }

  void markStarted(
    String sourceName, {
    PlayerSessionId? sessionId,
    String? ownerTag,
  }) {
    final owner = sessionId ?? _legacySessionId;
    _lastStartedAt[sourceName] = DateTime.now();
    final key = (sessionId: owner, sourceName: sourceName);
    final pending = _pending.remove(key);
    _readyClaims.remove(sourceName);
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [SourceRequestGate] $sourceName markStarted '
        '(cancelledOwnPending=${pending != null})',
      );
    }
    _scheduleSource(sourceName);
  }

  void scheduleWhenReady({
    PlayerSessionId? sessionId,
    required String sourceName,
    required Duration minInterval,
    required Object token,
    required void Function() onReady,
    String? ownerTag,
  }) {
    final owner = sessionId ?? _legacySessionId;
    final key = (sessionId: owner, sourceName: sourceName);
    final previous = _pending[key];
    _pending[key] = _PendingStart(
      token: token,
      minInterval: minInterval,
      onReady: onReady,
      ownerTag: ownerTag,
      sequence: previous?.sequence ?? ++_sequence,
    );
    if (ownerTag != null) {
      final remaining = remainingCooldown(sourceName, minInterval);
      debugPrint(
        '$ownerTag [SourceRequestGate] $sourceName queued '
        '${remaining?.inMilliseconds ?? 0}ms (token=$token'
        '${previous == null ? '' : ', overwroteOwnToken=${previous.token}'})',
      );
    }
    _scheduleSource(sourceName);
  }

  void cancelPending(
    String sourceName, {
    PlayerSessionId? sessionId,
    Object? token,
    String? ownerTag,
  }) {
    final owner = sessionId ?? _legacySessionId;
    final key = (sessionId: owner, sourceName: sourceName);
    final pending = _pending[key];
    if (pending == null || (token != null && pending.token != token)) return;
    _pending.remove(key);
    if (_readyClaims[sourceName] == owner) {
      _readyClaims.remove(sourceName);
    }
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [SourceRequestGate] $sourceName cancelPending token=$token',
      );
    }
    _scheduleSource(sourceName);
  }

  void cancelSession(PlayerSessionId sessionId, {String? ownerTag}) {
    final sources = <String>{};
    final keys = _pending.keys
        .where((key) => key.sessionId == sessionId)
        .toList(growable: false);
    for (final key in keys) {
      sources.add(key.sourceName);
      _pending.remove(key);
    }
    final claimedSources = _readyClaims.entries
        .where((entry) => entry.value == sessionId)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final source in claimedSources) {
      sources.add(source);
      _readyClaims.remove(source);
    }
    if (ownerTag != null && (keys.isNotEmpty || claimedSources.isNotEmpty)) {
      debugPrint(
        '$ownerTag [SourceRequestGate] cancelSession '
        'waiters=${keys.length} claims=${claimedSources.length}',
      );
    }
    for (final source in sources) {
      _scheduleSource(source);
    }
  }

  /// Process-wide reset/shutdown API. Player sessions must use [cancelSession].
  void cancelAllPending({String? ownerTag}) {
    final count = _pending.length;
    _pending.clear();
    _readyClaims.clear();
    for (final timer in _sourceTimers.values) {
      timer.cancel();
    }
    _sourceTimers.clear();
    if (ownerTag != null && count > 0) {
      debugPrint(
        '$ownerTag [SourceRequestGate] cancelAllPending cleared=$count',
      );
    }
  }

  @visibleForTesting
  void debugReset() {
    cancelAllPending();
    _lastStartedAt.clear();
    _lastServedSequence.clear();
    _sequence = 0;
  }

  static Duration captchaIntervalMs(int initialDelayMs) {
    final ms = initialDelayMs < captchaIntervalFloorMs
        ? captchaIntervalFloorMs
        : initialDelayMs;
    return Duration(milliseconds: ms);
  }

  void _scheduleSource(String sourceName) {
    _sourceTimers.remove(sourceName)?.cancel();
    if (_readyClaims.containsKey(sourceName)) return;

    final candidates = _pending.entries
        .where((entry) => entry.key.sourceName == sourceName)
        .toList(growable: false);
    if (candidates.isEmpty) return;

    final ready = candidates
        .where(
          (entry) =>
              remainingCooldown(sourceName, entry.value.minInterval) == null,
        )
        .toList();
    if (ready.isNotEmpty) {
      final selected = _selectFair(sourceName, ready);
      final pending = _pending.remove(selected.key);
      if (pending == null) return;
      _readyClaims[sourceName] = selected.key.sessionId;
      _lastServedSequence[sourceName] = pending.sequence;
      scheduleMicrotask(() {
        if (_readyClaims[sourceName] != selected.key.sessionId) return;
        final prefix = pending.ownerTag == null ? '' : '${pending.ownerTag} ';
        debugPrint(
          '$prefix[SourceRequestGate] $sourceName ready '
          '(token=${pending.token})',
        );
        try {
          pending.onReady();
        } catch (error, stackTrace) {
          if (_readyClaims[sourceName] == selected.key.sessionId) {
            _readyClaims.remove(sourceName);
            _scheduleSource(sourceName);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });
      return;
    }

    Duration? earliest;
    for (final candidate in candidates) {
      final remaining = remainingCooldown(
        sourceName,
        candidate.value.minInterval,
      );
      if (remaining != null && (earliest == null || remaining < earliest)) {
        earliest = remaining;
      }
    }
    if (earliest != null) {
      _sourceTimers[sourceName] = Timer(earliest, () {
        _sourceTimers.remove(sourceName);
        _scheduleSource(sourceName);
      });
    }
  }

  MapEntry<_PendingKey, _PendingStart> _selectFair(
    String sourceName,
    List<MapEntry<_PendingKey, _PendingStart>> ready,
  ) {
    ready.sort((a, b) => a.value.sequence.compareTo(b.value.sequence));
    final after = _lastServedSequence[sourceName] ?? -1;
    return ready.firstWhere(
      (entry) => entry.value.sequence > after,
      orElse: () => ready.first,
    );
  }
}

class _PendingStart {
  const _PendingStart({
    required this.token,
    required this.minInterval,
    required this.onReady,
    required this.sequence,
    this.ownerTag,
  });

  final Object token;
  final Duration minInterval;
  final void Function() onReady;
  final int sequence;
  final String? ownerTag;
}
