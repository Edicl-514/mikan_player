/// Pure identity / ownership value types for multi-Player-session coordination.
///
/// Phase 0 of `docs/windows_desktop_multitab_plan.md`: these types do not depend
/// on Flutter widgets, media_kit, or a real WebView engine. Later phases attach
/// them to [PlayerPage], worker leases, and global coordinators.
library;

/// Stable in-memory identity of one top-level workspace tab.
///
/// Phase 0 has no Tab shell yet; callers may leave this null or use a sentinel
/// when logging from a single-page app shell.
class WorkspaceTabId {
  const WorkspaceTabId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceTabId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'tab:$value';
}

/// Route-level identity of one live [PlayerPage] State / route instance.
///
/// Distinct from [WorkspaceTabId]: a single tab's navigator stack may host
/// multiple player sessions over time (or nested player → details → player).
class PlayerSessionId {
  const PlayerSessionId(this.value);

  /// Allocates a new unique session id. Prefer this over hand-rolled strings
  /// outside tests so logs stay monotonic and collision-free.
  factory PlayerSessionId.allocate([String? prefix]) {
    final n = ++_next;
    final p = (prefix == null || prefix.isEmpty) ? 'ps' : prefix;
    return PlayerSessionId('$p-$n');
  }

  final String value;

  static int _next = 0;

  /// Test-only: reset the allocator counter so fixture ids stay stable.
  static void debugResetAllocator() {
    _next = 0;
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerSessionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'session:$value';
}

/// Lifecycle stages a player session moves through.
///
/// Phase 0 only defines the enum. Phase 1 wires registration + prepare-close.
enum PlayerSessionLifecycleState {
  created,
  active,
  background,
  closing,
  disposed,
}

/// Global identity of one live WebView worker lease.
///
/// Local [workerId] alone is **not** unique across Player sessions; always pair
/// it with the owning [PlayerSessionId].
class WebViewWorkerLeaseId {
  const WebViewWorkerLeaseId({
    required this.playerSessionId,
    required this.localWorkerId,
  });

  final PlayerSessionId playerSessionId;
  final int localWorkerId;

  @override
  bool operator ==(Object other) =>
      other is WebViewWorkerLeaseId &&
      other.playerSessionId == playerSessionId &&
      other.localWorkerId == localWorkerId;

  @override
  int get hashCode => Object.hash(playerSessionId, localWorkerId);

  @override
  String toString() => 'lease:${playerSessionId.value}/worker:$localWorkerId';
}

/// Compact log tag shared by PlayerPage / scheduler / gate / cookie paths.
///
/// [tabId] is optional until the Tab shell exists; [generation] is the sample
/// search load token (or 0 when none).
class PlayerSessionLogContext {
  const PlayerSessionLogContext({
    this.tabId,
    required this.sessionId,
    this.workerId,
    this.generation,
  });

  final WorkspaceTabId? tabId;
  final PlayerSessionId sessionId;
  final int? workerId;
  final int? generation;

  PlayerSessionLogContext copyWith({
    WorkspaceTabId? tabId,
    PlayerSessionId? sessionId,
    int? workerId,
    int? generation,
    bool clearWorkerId = false,
    bool clearGeneration = false,
  }) {
    return PlayerSessionLogContext(
      tabId: tabId ?? this.tabId,
      sessionId: sessionId ?? this.sessionId,
      workerId: clearWorkerId ? null : (workerId ?? this.workerId),
      generation: clearGeneration ? null : (generation ?? this.generation),
    );
  }

  /// Stable prefix for `debugPrint`, e.g.
  /// `[tab:t1 session:ps-1 worker:2 gen:7]`.
  String get tag {
    final parts = <String>[
      if (tabId != null) 'tab:${tabId!.value}',
      'session:${sessionId.value}',
      if (workerId != null) 'worker:$workerId',
      if (generation != null) 'gen:$generation',
    ];
    return '[${parts.join(' ')}]';
  }

  @override
  String toString() => tag;
}
