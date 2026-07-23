import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/source_request_gate.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';

/// Process-wide debug registry + invariant snapshot for multi-session work.
///
/// Phase 0 of `docs/windows_desktop_multitab_plan.md`. Production PlayerPage
/// registers a lightweight handle on create/dispose so logs and tests can
/// assert cross-session totals **without** changing resource budgets yet.
///
/// Global coordinators (WebView hard limit, cookie leases, playback focus) land
/// in Phase 1/2; this registry only observes what sessions report.
class PlayerResourceDebugRegistry {
  PlayerResourceDebugRegistry._();

  static final PlayerResourceDebugRegistry instance =
      PlayerResourceDebugRegistry._();

  final Map<PlayerSessionId, PlayerSessionDebugHandle> _sessions =
      <PlayerSessionId, PlayerSessionDebugHandle>{};

  PlayerSessionId? playbackFocusSessionId;

  /// Registers [handle]. Replacing an existing id is allowed (re-entry) and
  /// overwrites the previous handle reference.
  void register(PlayerSessionDebugHandle handle) {
    _sessions[handle.sessionId] = handle;
    debugPrint(
      '${handle.logContext.tag} [PlayerSession] registered '
      'state=${handle.lifecycleState.name} '
      'sessions=${_sessions.length}',
    );
  }

  /// Idempotent unregister. Does not touch process-wide gate / cookie state.
  void unregister(PlayerSessionId sessionId) {
    final removed = _sessions.remove(sessionId);
    if (removed == null) return;
    if (playbackFocusSessionId == sessionId) {
      playbackFocusSessionId = null;
    }
    debugPrint(
      '${removed.logContext.tag} [PlayerSession] unregistered '
      'sessions=${_sessions.length}',
    );
  }

  PlayerSessionDebugHandle? handleOf(PlayerSessionId sessionId) =>
      _sessions[sessionId];

  int get sessionCount => _sessions.length;

  Iterable<PlayerSessionDebugHandle> get sessions => _sessions.values;

  /// Builds a point-in-time invariant snapshot from registered handles plus
  /// process-wide gate / cookie cleanup counts.
  PlayerResourceDebugSnapshot snapshot({
    WebViewCookieJanitor? cookieJanitor,
    int cookieLeaseCount = 0,
  }) {
    var liveWorkers = 0;
    var activeJobs = 0;
    final perSession = <PlayerSessionId, PlayerSessionResourceCounts>{};
    for (final handle in _sessions.values) {
      final counts = handle.reportCounts();
      perSession[handle.sessionId] = counts;
      liveWorkers += counts.liveWorkerCount;
      activeJobs += counts.activeJobCount;
    }
    final gate = SourceRequestGate.instance;
    final janitor = cookieJanitor ?? WebViewCookieJanitor();
    return PlayerResourceDebugSnapshot(
      sessionCount: _sessions.length,
      liveWorkerCount: liveWorkers,
      activeJobCount: activeJobs,
      pendingGateWaiterCount: gate.debugPendingWaiterCount,
      pendingCookieCleanupCount: janitor.debugPendingCleanupCount,
      cookieLeaseCount: cookieLeaseCount,
      playbackFocusSessionId: playbackFocusSessionId,
      perSession:
          Map<PlayerSessionId, PlayerSessionResourceCounts>.unmodifiable(
            perSession,
          ),
    );
  }

  /// Test-only: drop all registrations without disposing real pages.
  @visibleForTesting
  void debugReset() {
    _sessions.clear();
    playbackFocusSessionId = null;
  }
}

/// Per-session counters contributed to [PlayerResourceDebugSnapshot].
class PlayerSessionResourceCounts {
  const PlayerSessionResourceCounts({
    required this.liveWorkerCount,
    required this.activeJobCount,
    this.lifecycleState = PlayerSessionLifecycleState.active,
  });

  final int liveWorkerCount;
  final int activeJobCount;
  final PlayerSessionLifecycleState lifecycleState;
}

/// Computes debug counts for both pooled and legacy per-task WebView modes.
///
/// In legacy mode every active job owns a live WebView widget. In pool mode,
/// idle slots remain live and therefore [pooledWorkerCount] is authoritative.
PlayerSessionResourceCounts playerSessionResourceCountsForMode({
  required bool useWorkerPool,
  required int pooledWorkerCount,
  required int pooledActiveVideoJobCount,
  required int legacyActiveVideoJobCount,
  required int activeCaptchaJobCount,
  required PlayerSessionLifecycleState lifecycleState,
}) {
  final activeVideoJobCount = useWorkerPool
      ? pooledActiveVideoJobCount
      : legacyActiveVideoJobCount;
  return PlayerSessionResourceCounts(
    liveWorkerCount: useWorkerPool
        ? pooledWorkerCount
        : activeVideoJobCount + activeCaptchaJobCount,
    activeJobCount: activeVideoJobCount + activeCaptchaJobCount,
    lifecycleState: lifecycleState,
  );
}

/// Lightweight handle owned by a real or fake Player session.
class PlayerSessionDebugHandle {
  PlayerSessionDebugHandle({
    required this.sessionId,
    this.tabId,
    this.lifecycleState = PlayerSessionLifecycleState.created,
    PlayerSessionResourceCounts Function()? reportCounts,
  }) : _reportCounts =
           reportCounts ??
           (() => const PlayerSessionResourceCounts(
             liveWorkerCount: 0,
             activeJobCount: 0,
           ));

  final PlayerSessionId sessionId;
  final WorkspaceTabId? tabId;
  PlayerSessionLifecycleState lifecycleState;
  final PlayerSessionResourceCounts Function() _reportCounts;

  /// Optional generation (sample load token) for log context only.
  int? generation;

  PlayerSessionLogContext get logContext => PlayerSessionLogContext(
    tabId: tabId,
    sessionId: sessionId,
    generation: generation,
  );

  PlayerSessionResourceCounts reportCounts() {
    final base = _reportCounts();
    return PlayerSessionResourceCounts(
      liveWorkerCount: base.liveWorkerCount,
      activeJobCount: base.activeJobCount,
      lifecycleState: lifecycleState,
    );
  }
}

/// Immutable cross-session invariant snapshot for logs and tests.
class PlayerResourceDebugSnapshot {
  const PlayerResourceDebugSnapshot({
    required this.sessionCount,
    required this.liveWorkerCount,
    required this.activeJobCount,
    required this.pendingGateWaiterCount,
    required this.pendingCookieCleanupCount,
    required this.cookieLeaseCount,
    required this.playbackFocusSessionId,
    required this.perSession,
  });

  final int sessionCount;
  final int liveWorkerCount;
  final int activeJobCount;
  final int pendingGateWaiterCount;
  final int pendingCookieCleanupCount;
  final int cookieLeaseCount;
  final PlayerSessionId? playbackFocusSessionId;
  final Map<PlayerSessionId, PlayerSessionResourceCounts> perSession;

  String shortSummary() {
    return 'sessions=$sessionCount liveWorkers=$liveWorkerCount '
        'activeJobs=$activeJobCount gateWaiters=$pendingGateWaiterCount '
        'cookiePending=$pendingCookieCleanupCount '
        'cookieLeases=$cookieLeaseCount '
        'focus=${playbackFocusSessionId?.value ?? 'none'}';
  }

  @override
  String toString() => 'PlayerResourceDebugSnapshot($shortSummary())';
}

/// Formats a structured multi-session log line.
void playerSessionDebugPrint(
  PlayerSessionLogContext context,
  String component,
  String message,
) {
  debugPrint('${context.tag} [$component] $message');
}
