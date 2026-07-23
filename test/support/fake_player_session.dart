import 'package:mikan_player/services/player_session/player_resource_debug.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/source_request_gate.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';

/// Dual-session test fixture for multi-tab Phase 0 risk characterization.
///
/// Models a Player page's local [PlayerWebViewScheduler] plus a session handle
/// registered with [PlayerResourceDebugRegistry], without starting WebView2 /
/// media_kit / Flutter widgets.
class FakePlayerSession {
  FakePlayerSession({
    PlayerSessionId? sessionId,
    this.tabId,
    this.maxConcurrent = 3,
  }) : sessionId = sessionId ?? PlayerSessionId.allocate() {
    handle = PlayerSessionDebugHandle(
      sessionId: this.sessionId,
      tabId: tabId,
      lifecycleState: PlayerSessionLifecycleState.active,
      reportCounts: () => PlayerSessionResourceCounts(
        liveWorkerCount: scheduler.workerCount,
        activeJobCount:
            scheduler.activeVideoJobCount + scheduler.activeCaptchaJobCount,
        lifecycleState: handle.lifecycleState,
      ),
    );
  }

  final PlayerSessionId sessionId;
  final WorkspaceTabId? tabId;
  final int maxConcurrent;
  final PlayerWebViewScheduler scheduler = PlayerWebViewScheduler();
  late final PlayerSessionDebugHandle handle;

  /// Sample load / generation token (mirrors [PlayerSampleSourceController]).
  int generation = 0;

  bool isDisposed = false;
  final List<Object> lateCallbacks = <Object>[];
  final List<Object> acceptedCallbacks = <Object>[];

  PlayerSessionLogContext get logContext => PlayerSessionLogContext(
    tabId: tabId,
    sessionId: sessionId,
    generation: generation,
  );

  String get ownerTag => logContext.tag;

  void register() {
    PlayerResourceDebugRegistry.instance.register(handle);
  }

  int bumpGeneration() {
    generation += 1;
    handle.generation = generation;
    return generation;
  }

  /// Fill local pool to [maxConcurrent] with running video jobs.
  List<WebViewWorkerSlotSnapshot> fillLocalBudget({
    String sourcePrefix = 'src',
  }) {
    final slots = <WebViewWorkerSlotSnapshot>[];
    for (var i = 0; i < maxConcurrent; i++) {
      final acquire = scheduler.acquireIdleVideoWorkerSlot(
        {'$sourcePrefix-$i'},
        useWorkerPool: true,
        maxConcurrent: maxConcurrent,
      );
      final slot = acquire.slot;
      if (slot == null) {
        throw StateError(
          'Could not fill budget at i=$i workerCount=${scheduler.workerCount}',
        );
      }
      final pageKey = 'page-$i';
      scheduler.startVideoJob(
        slot,
        pageKey,
        '$sourcePrefix-$i',
        generation: generation,
      );
      slots.add(slot);
    }
    return slots;
  }

  /// Gate waiter whose [onReady] is generation-guarded like PlayerPage.
  void scheduleGateWaiter({
    required String sourceName,
    required Duration minInterval,
    required Object token,
  }) {
    final gateToken = token;
    final capturedGeneration = generation;
    SourceRequestGate.instance.scheduleWhenReady(
      sessionId: sessionId,
      sourceName: sourceName,
      minInterval: minInterval,
      token: gateToken,
      ownerTag: ownerTag,
      onReady: () {
        if (!isCallbackCurrent(capturedGeneration)) {
          lateCallbacks.add(gateToken);
          return;
        }
        SourceRequestGate.instance.markStarted(
          sourceName,
          sessionId: sessionId,
          ownerTag: ownerTag,
        );
        acceptedCallbacks.add(gateToken);
      },
    );
  }

  bool isCallbackCurrent(int resultGeneration) {
    if (isDisposed) return false;
    return resultGeneration == generation;
  }

  /// Mirrors PlayerPage dispose: bump generation, clear scheduler, unregister.
  ///
  /// Deliberately does **not** call [SourceRequestGate.cancelAllPending] —
  /// that is process-wide and would cancel other sessions (Phase 0 risk).
  void closeSession() {
    handle.lifecycleState = PlayerSessionLifecycleState.closing;
    SourceRequestGate.instance.cancelSession(sessionId, ownerTag: ownerTag);
    bumpGeneration();
    isDisposed = true;
    scheduler.resetForNewSearch();
    scheduler.clearForDispose();
    handle.lifecycleState = PlayerSessionLifecycleState.disposed;
    PlayerResourceDebugRegistry.instance.unregister(sessionId);
  }
}

/// Pair of independent fake sessions for composition tests.
class DualFakePlayerSessions {
  DualFakePlayerSessions({this.maxConcurrentPerSession = 3})
    : a = FakePlayerSession(
        sessionId: const PlayerSessionId('ps-a'),
        tabId: const WorkspaceTabId('tab-a'),
        maxConcurrent: maxConcurrentPerSession,
      ),
      b = FakePlayerSession(
        sessionId: const PlayerSessionId('ps-b'),
        tabId: const WorkspaceTabId('tab-b'),
        maxConcurrent: maxConcurrentPerSession,
      );

  final int maxConcurrentPerSession;
  final FakePlayerSession a;
  final FakePlayerSession b;

  void registerAll() {
    a.register();
    b.register();
  }

  void closeAll() {
    if (!a.isDisposed) a.closeSession();
    if (!b.isDisposed) b.closeSession();
  }

  PlayerResourceDebugSnapshot snapshot() {
    return PlayerResourceDebugRegistry.instance.snapshot();
  }
}
