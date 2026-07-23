import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

@immutable
class CookieHostLeaseId {
  const CookieHostLeaseId({required this.sessionId, required this.resourceKey});

  final PlayerSessionId sessionId;
  final String resourceKey;

  @override
  bool operator ==(Object other) =>
      other is CookieHostLeaseId &&
      other.sessionId == sessionId &&
      other.resourceKey == resourceKey;

  @override
  int get hashCode => Object.hash(sessionId, resourceKey);
}

/// Tracks which Player resources currently depend on each shared WebView host.
class CookieUsageRegistry {
  CookieUsageRegistry();

  static final CookieUsageRegistry instance = CookieUsageRegistry();

  final Map<CookieHostLeaseId, Set<String>> _hostsByLease = {};
  final Map<String, Set<CookieHostLeaseId>> _leasesByHost = {};
  final Map<PlayerSessionId, int> _sessionGenerations = {};

  int get leaseCount => _hostsByLease.length;

  void registerSession(PlayerSessionId sessionId, {int generation = 0}) {
    _sessionGenerations[sessionId] = generation;
  }

  void updateSessionGeneration(PlayerSessionId sessionId, int generation) {
    final current = _sessionGenerations[sessionId];
    if (current != null && generation < current) return;
    _sessionGenerations[sessionId] = generation;
  }

  bool isGenerationCurrent(PlayerSessionId sessionId, int generation) {
    final current = _sessionGenerations[sessionId];
    return current == null || current == generation;
  }

  void acquireHost(CookieHostLeaseId leaseId, String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final hosts = _hostsByLease.putIfAbsent(leaseId, () => <String>{});
    if (!hosts.add(normalized)) return;
    _leasesByHost
        .putIfAbsent(normalized, () => <CookieHostLeaseId>{})
        .add(leaseId);
  }

  void releaseLease(CookieHostLeaseId leaseId) {
    final hosts = _hostsByLease.remove(leaseId);
    if (hosts == null) return;
    for (final host in hosts) {
      final leases = _leasesByHost[host];
      leases?.remove(leaseId);
      if (leases?.isEmpty ?? false) _leasesByHost.remove(host);
    }
  }

  void releaseSession(PlayerSessionId sessionId) {
    final leases = _hostsByLease.keys
        .where((lease) => lease.sessionId == sessionId)
        .toList(growable: false);
    for (final lease in leases) {
      releaseLease(lease);
    }
    _sessionGenerations.remove(sessionId);
  }

  bool hasActiveUsers(String host) =>
      _leasesByHost[host.trim().toLowerCase()]?.isNotEmpty ?? false;

  int activeUserCount(String host) =>
      _leasesByHost[host.trim().toLowerCase()]?.length ?? 0;

  @visibleForTesting
  void debugReset() {
    _hostsByLease.clear();
    _leasesByHost.clear();
    _sessionGenerations.clear();
  }
}
