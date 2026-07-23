import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

enum WebViewSessionPriority { foreground, background }

@immutable
class WebViewResourceSnapshot {
  const WebViewResourceSnapshot({
    required this.limit,
    required this.liveLeaseCount,
    required this.busyLeaseCount,
    required this.pendingRequestCount,
    required this.draining,
    required this.perSessionLeaseCount,
  });

  final int limit;
  final int liveLeaseCount;
  final int busyLeaseCount;
  final int pendingRequestCount;
  final bool draining;
  final Map<PlayerSessionId, int> perSessionLeaseCount;
}

class _SessionRegistration {
  _SessionRegistration({
    required this.priority,
    required this.onCapacityAvailable,
    required this.onReleaseIdleWorkers,
  });

  WebViewSessionPriority priority;
  final VoidCallback onCapacityAvailable;
  final VoidCallback onReleaseIdleWorkers;
}

class _LeaseRecord {
  _LeaseRecord(this.id);

  final WebViewWorkerLeaseId id;
  bool busy = false;
  bool materialized = false;
  bool releaseRequested = false;
}

/// Process-wide hard quota for live WebView widgets.
///
/// A lease is granted before a worker widget can enter the tree and is released
/// only by that widget's dispose boundary. Pending requests are grouped by
/// session; foreground sessions are served first and sessions at the same
/// priority rotate round-robin.
class WebViewResourceCoordinator {
  WebViewResourceCoordinator({required int initialLimit})
    : _limit = _normalizeLimit(initialLimit);

  static final WebViewResourceCoordinator instance = WebViewResourceCoordinator(
    initialLimit: 3,
  );

  int _limit;
  final Map<PlayerSessionId, _SessionRegistration> _sessions = {};
  final Map<WebViewWorkerLeaseId, _LeaseRecord> _leases = {};
  final Map<PlayerSessionId, Queue<WebViewWorkerLeaseId>> _pending = {};
  final Queue<PlayerSessionId> _foregroundOrder = Queue();
  final Queue<PlayerSessionId> _backgroundOrder = Queue();
  final Map<PlayerSessionId, List<Completer<void>>> _releaseWaiters = {};

  int get limit => _limit;
  int get liveLeaseCount => _leases.length;
  int get pendingRequestCount =>
      _pending.values.fold(0, (sum, requests) => sum + requests.length);
  bool get isDraining => liveLeaseCount > _limit;

  void registerSession({
    required PlayerSessionId sessionId,
    WebViewSessionPriority priority = WebViewSessionPriority.foreground,
    required VoidCallback onCapacityAvailable,
    required VoidCallback onReleaseIdleWorkers,
  }) {
    _sessions[sessionId] = _SessionRegistration(
      priority: priority,
      onCapacityAvailable: onCapacityAvailable,
      onReleaseIdleWorkers: onReleaseIdleWorkers,
    );
    _rebuildPendingOrder();
    _pumpPending();
  }

  /// Removes callbacks and pending requests. Live leases remain accounted for
  /// until their widget dispose boundaries call [releaseLease].
  void unregisterSession(PlayerSessionId sessionId) {
    cancelPendingSession(sessionId);
    _sessions.remove(sessionId);
    _removeFromOrders(sessionId);
  }

  void updateSessionPriority(
    PlayerSessionId sessionId,
    WebViewSessionPriority priority,
  ) {
    final session = _sessions[sessionId];
    if (session == null || session.priority == priority) return;
    session.priority = priority;
    _rebuildPendingOrder();
    _pumpPending();
  }

  /// Returns true when [leaseId] is already owned or can be granted now.
  /// Otherwise the request is queued once and idle reclamation is requested.
  bool requestLease(WebViewWorkerLeaseId leaseId) {
    if (_leases.containsKey(leaseId)) return true;
    final session = _sessions[leaseId.playerSessionId];
    if (session == null) return false;

    final hasOlderWaiters = pendingRequestCount > 0;
    if (!isDraining && liveLeaseCount < _limit && !hasOlderWaiters) {
      _grant(leaseId);
      return true;
    }

    final requests = _pending.putIfAbsent(
      leaseId.playerSessionId,
      Queue<WebViewWorkerLeaseId>.new,
    );
    if (!requests.contains(leaseId)) {
      requests.addLast(leaseId);
      _appendSessionToOrder(leaseId.playerSessionId);
    }
    _requestIdleReclamation();
    _pumpPending();
    return _leases.containsKey(leaseId);
  }

  bool ownsLease(WebViewWorkerLeaseId leaseId) => _leases.containsKey(leaseId);

  void markLeaseBusy(WebViewWorkerLeaseId leaseId, {required bool busy}) {
    final lease = _leases[leaseId];
    if (lease == null) return;
    lease.busy = busy;
  }

  /// Marks that the granted permit now corresponds to a scheduler slot whose
  /// widget boundary will eventually release it.
  void markLeaseMaterialized(WebViewWorkerLeaseId leaseId) {
    final lease = _leases[leaseId];
    if (lease == null) {
      throw StateError('Cannot materialize unowned lease $leaseId');
    }
    lease.materialized = true;
  }

  /// Idempotently releases one lease after the matching widget is disposed.
  void releaseLease(WebViewWorkerLeaseId leaseId) {
    final removed = _leases.remove(leaseId);
    if (removed == null) return;
    _completeReleaseWaitersIfDone(leaseId.playerSessionId);
    _pumpPending();
  }

  void cancelPendingSession(PlayerSessionId sessionId) {
    _pending.remove(sessionId);
    _removeFromOrders(sessionId);
  }

  /// Requests that a session remove all worker widgets. Accounting remains
  /// intact until each widget calls [releaseLease] from State.dispose.
  void releaseAllOwnedBy(PlayerSessionId sessionId) {
    cancelPendingSession(sessionId);
    final owned = _leases.values
        .where((lease) => lease.id.playerSessionId == sessionId)
        .toList(growable: false);
    for (final lease in owned) {
      if (lease.materialized) {
        lease.releaseRequested = true;
      } else {
        _leases.remove(lease.id);
      }
    }
    _sessions[sessionId]?.onReleaseIdleWorkers();
    _completeReleaseWaitersIfDone(sessionId);
    _pumpPending();
  }

  /// Drops granted permits that never became scheduler slots/widgets.
  void releaseUnmaterializedOwnedBy(PlayerSessionId sessionId) {
    final ids = _leases.values
        .where(
          (lease) =>
              lease.id.playerSessionId == sessionId && !lease.materialized,
        )
        .map((lease) => lease.id)
        .toList(growable: false);
    for (final id in ids) {
      _leases.remove(id);
    }
    _completeReleaseWaitersIfDone(sessionId);
    _pumpPending();
  }

  Future<void> waitUntilSessionReleased(
    PlayerSessionId sessionId, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    if (!_hasSessionLeases(sessionId)) return Future<void>.value();
    final completer = Completer<void>();
    _releaseWaiters.putIfAbsent(sessionId, () => []).add(completer);
    return completer.future.timeout(timeout, onTimeout: () {});
  }

  void updateLimit(int nextLimit) {
    final normalized = _normalizeLimit(nextLimit);
    if (_limit == normalized) return;
    final grew = normalized > _limit;
    _limit = normalized;
    if (grew) {
      _pumpPending();
    } else {
      _requestIdleReclamation();
    }
  }

  WebViewResourceSnapshot snapshot() {
    final counts = <PlayerSessionId, int>{};
    var busy = 0;
    for (final lease in _leases.values) {
      counts.update(
        lease.id.playerSessionId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (lease.busy) busy++;
    }
    return WebViewResourceSnapshot(
      limit: _limit,
      liveLeaseCount: liveLeaseCount,
      busyLeaseCount: busy,
      pendingRequestCount: pendingRequestCount,
      draining: isDraining,
      perSessionLeaseCount: Map.unmodifiable(counts),
    );
  }

  @visibleForTesting
  void debugReset({int? limit}) {
    _sessions.clear();
    _leases.clear();
    _pending.clear();
    _foregroundOrder.clear();
    _backgroundOrder.clear();
    for (final waiters in _releaseWaiters.values) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
    _releaseWaiters.clear();
    if (limit != null) _limit = _normalizeLimit(limit);
  }

  void _grant(WebViewWorkerLeaseId id) {
    _leases.putIfAbsent(id, () => _LeaseRecord(id));
  }

  void _pumpPending() {
    if (isDraining) return;
    while (liveLeaseCount < _limit && pendingRequestCount > 0) {
      final sessionId = _takeNextSession();
      if (sessionId == null) break;
      final requests = _pending[sessionId];
      final registration = _sessions[sessionId];
      if (requests == null || requests.isEmpty || registration == null) {
        _pending.remove(sessionId);
        continue;
      }
      final request = requests.removeFirst();
      _grant(request);
      if (requests.isEmpty) {
        _pending.remove(sessionId);
      } else {
        _appendSessionToOrder(sessionId);
      }
      scheduleMicrotask(registration.onCapacityAvailable);
    }
  }

  PlayerSessionId? _takeNextSession() {
    if (_foregroundOrder.isNotEmpty) return _foregroundOrder.removeFirst();
    if (_backgroundOrder.isNotEmpty) return _backgroundOrder.removeFirst();
    _rebuildPendingOrder();
    if (_foregroundOrder.isNotEmpty) return _foregroundOrder.removeFirst();
    if (_backgroundOrder.isNotEmpty) return _backgroundOrder.removeFirst();
    return null;
  }

  void _appendSessionToOrder(PlayerSessionId sessionId) {
    final registration = _sessions[sessionId];
    if (registration == null || _pending[sessionId]?.isEmpty != false) return;
    final target = registration.priority == WebViewSessionPriority.foreground
        ? _foregroundOrder
        : _backgroundOrder;
    if (!target.contains(sessionId)) target.addLast(sessionId);
  }

  void _rebuildPendingOrder() {
    _foregroundOrder.clear();
    _backgroundOrder.clear();
    for (final sessionId in _pending.keys) {
      _appendSessionToOrder(sessionId);
    }
  }

  void _removeFromOrders(PlayerSessionId sessionId) {
    _foregroundOrder.removeWhere((id) => id == sessionId);
    _backgroundOrder.removeWhere((id) => id == sessionId);
  }

  void _requestIdleReclamation() {
    for (final registration in _sessions.values) {
      registration.onReleaseIdleWorkers();
    }
  }

  bool _hasSessionLeases(PlayerSessionId sessionId) =>
      _leases.keys.any((leaseId) => leaseId.playerSessionId == sessionId);

  void _completeReleaseWaitersIfDone(PlayerSessionId sessionId) {
    if (_hasSessionLeases(sessionId)) return;
    final waiters = _releaseWaiters.remove(sessionId);
    if (waiters == null) return;
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  static int _normalizeLimit(int value) => value < 1 ? 1 : value;
}
