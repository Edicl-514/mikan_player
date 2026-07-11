import 'dart:collection';

import 'package:mikan_player/ui/pages/player/webview_pool_pump_coordinator.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_bookkeeping.dart'
    as bk;
import 'package:mikan_player/ui/pages/player/webview_worker_selection.dart'
    as sel;
import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';

/// Phase 2 B6: the long-lived WebView worker scheduler state object.
///
/// B1–B5 extracted the *pure* slot/selection/bookkeeping/coordinator logic
/// into free functions; B6 now folds the *mutable* state that previously lived
/// inline as private fields of `_PlayerPageState` into one testable object:
///
///   - the worker-slot table (was `_webViewWorkerSlots`)
///   - the active video reverse map (was `_activeVideoJobs`)
///   - the active captcha reverse map (was `_activeCaptchaJobs`)
///   - the monotonic worker-id counter (was `_nextWebViewWorkerId`)
///   - the pump-token/dedup coordinator (was `_pumpCoordinator`)
///
/// The scheduler deliberately owns **state mutations only**. It does not
/// perform the source-affinity *job* selection (that depends on the page's
/// `SearchPlayResult` pending list / tiers / enqueue-seq), nor the pump loop,
/// nor any side-effects (`debugPrint`, `_webviewStats`, `_webViewStatus`,
/// `setState`). Those stay on the page, which drives the scheduler through the
/// methods below and reads the read-only views.
///
/// This keeps the scheduler free of Flutter, `BuildContext`, `Widget`,
/// `InAppWebViewController`, `Player`, and the network / search services — it
/// is unit-testable in pure Dart. All mutation paths reuse the B1–B5 pure
/// functions verbatim (no algorithm redesign), so worker selection, affinity,
/// concurrency, cancellation, late-callback handling, and auto-play behaviour
/// are unchanged.

/// Outcome of [PlayerWebViewScheduler.acquireIdleCaptchaWorkerSlot] /
/// [PlayerWebViewScheduler.acquireIdleVideoWorkerSlot].
///
/// Carry three pieces of information the page needs to reproduce its historic
/// `debugPrint` lines without the scheduler owning logging:
///   - [slot]: the idle slot the caller should now dispatch a job onto, or
///     `null` when no slot could be acquired (budget full, no disposable idle).
///   - [disposedIdleSlots]: idle slots that had to be evicted (budget trim +
///     free-one-for-new) as part of this acquire, so the page can log each
///     `disposed idle worker` line.
///   - [createdNew]: whether [slot] was freshly minted (so the page logs
///     `created worker=$id for ...`), versus reused from the existing table.
class PlayerWebViewSchedulerAcquire {
  const PlayerWebViewSchedulerAcquire({
    required this.slot,
    required this.disposedIdleSlots,
    required this.createdNew,
  });

  final WebViewWorkerSlot? slot;
  final List<WebViewWorkerSlot> disposedIdleSlots;
  final bool createdNew;
}

class PlayerWebViewScheduler {
  PlayerWebViewScheduler();

  final Map<int, WebViewWorkerSlot> _slots = {};
  final Map<String, int> _activeVideoJobs = {};
  final Map<String, int> _activeCaptchaJobs = {};
  final WebViewPoolPumpCoordinator _pumpCoordinator =
      WebViewPoolPumpCoordinator();
  int _nextWorkerId = 0;

  late final Map<int, WebViewWorkerSlot> _slotsView =
      UnmodifiableMapView<int, WebViewWorkerSlot>(_slots);
  late final Map<String, int> _activeVideoJobsView =
      UnmodifiableMapView<String, int>(_activeVideoJobs);
  late final Map<String, int> _activeCaptchaJobsView =
      UnmodifiableMapView<String, int>(_activeCaptchaJobs);

  // ── Read-only views for the page ──────────────────────────────────────────

  /// Unmodifiable live view of the worker-slot table. The page iterates this
  /// during build (`_buildWebViewExtractorsPool`, status rows, affinity
  /// summary) but must never add/remove entries — use the methods below.
  Map<int, WebViewWorkerSlot> get slots => _slotsView;

  /// Unmodifiable live view of the active video reverse map
  /// (`pageKey -> workerId`). The page reads `.length` / `.containsKey` /
  /// `.keys` for counters and `_pageIsPendingForExtraction`; mutations go
  /// through the scheduler methods.
  Map<String, int> get activeVideoJobs => _activeVideoJobsView;

  /// Unmodifiable live view of the active captcha reverse map
  /// (`taskKey -> workerId`).
  Map<String, int> get activeCaptchaJobs => _activeCaptchaJobsView;

  /// Direct slot lookup (`null` if the worker was disposed, or if
  /// [workerId] itself is `null`).
  WebViewWorkerSlot? slotOf(int? workerId) =>
      workerId == null ? null : _slots[workerId];

  /// Current health of a worker slot (`null` if disposed, or if
  /// [workerId] itself is `null`).
  WebViewWorkerHealth? healthOf(int? workerId) =>
      workerId == null ? null : _slots[workerId]?.health;

  /// The pump-dedup/cancel-token coordinator. The page drives
  /// `scheduleImmediate` / `scheduleStaggered` / `isCurrentToken` / `reset`
  /// on it from `_scheduleWebViewPoolPump` and the reset paths; the scheduler
  /// owns the instance so the token survives across pump re-issues.
  WebViewPoolPumpCoordinator get pumpCoordinator => _pumpCoordinator;

  int get workerCount => _slots.length;
  int get activeVideoJobCount => _activeVideoJobs.length;
  int get activeCaptchaJobCount => _activeCaptchaJobs.length;

  // ── Start job ─────────────────────────────────────────────────────────────

  /// Marks [slot] as running a video job for [pageKey] from [sourceName] and
  /// records the reverse mapping. Reuses [bk.startVideoJobOnSlot], so the
  /// idle/reverse-map invariants are validated atomically (throws
  /// [StateError] on any violation without partially mutating state).
  void startVideoJob(
    WebViewWorkerSlot slot,
    String pageKey,
    String sourceName,
  ) {
    bk.startVideoJobOnSlot(slot, pageKey, sourceName, _activeVideoJobs);
  }

  /// Marks [slot] as running a captcha job for [taskKey] from [sourceName] and
  /// records the reverse mapping. Reuses [bk.startCaptchaJobOnSlot].
  void startCaptchaJob(
    WebViewWorkerSlot slot,
    String taskKey,
    String sourceName,
  ) {
    bk.startCaptchaJobOnSlot(slot, taskKey, sourceName, _activeCaptchaJobs);
  }

  // ── Cancel / release ──────────────────────────────────────────────────────

  /// Cancels the video job for [pageKey]: removes the reverse mapping, sets
  /// the slot health to cancelling, and clears its pageKey + kind. Returns the
  /// workerId that owned the job (or `null` if no active job). Reuses
  /// [bk.cancelVideoJob]. The page uses the workerId for side-effects on that
  /// worker (none currently), and `_onWebViewResult`'s late-callback guard
  /// handles a stale result arriving after this.
  int? cancelVideoJob(String pageKey) {
    return bk.cancelVideoJob(pageKey, _activeVideoJobs, _slots);
  }

  /// Cancels the captcha job for [taskKey]: removes the reverse mapping,
  /// marks the slot cancelling, and clears its taskKey + kind (so the next
  /// build emits a null job and the runner cancels). Returns the workerId that
  /// owned the job (or `null`).
  ///
  /// Mirrors the inline sequence in `_cancelLowerPriorityExtraction`'s captcha
  /// branch (set health=cancelling + clear fields, then drop the reverse map
  /// entry). Unlike [releaseCaptchaSlot], the slot is left in the table in a
  /// cancelling state so the build can route didUpdateWidget into the runner's
  /// `_cancelCurrentJob(silent)` path.
  int? cancelCaptchaSlot(String taskKey) {
    final workerId = _activeCaptchaJobs.remove(taskKey);
    final slot = workerId == null ? null : _slots[workerId];
    if (slot != null) {
      slot.health = WebViewWorkerHealth.cancelling;
      slot.taskKey = null;
      slot.kind = null;
    }
    return workerId;
  }

  /// Releases the captcha slot for [taskKey]: removes the reverse mapping and
  /// clears the slot's taskKey + kind (slot stays in the table, reusable).
  /// No-op if there is no active job or the slot's taskKey doesn't match
  /// (stale-callback guard). Reuses [bk.releaseCaptchaSlot].
  void releaseCaptchaSlot(String taskKey) {
    bk.releaseCaptchaSlot(taskKey, _activeCaptchaJobs, _slots);
  }

  /// Releases a video slot on worker idle: clears the slot's pageKey + kind
  /// and removes the reverse mapping. Returns the previous pageKey (or `null`)
  /// so the page can drop the matching `_webViewStatus` entry. Reuses
  /// [bk.releaseVideoSlotOnIdle].
  String? releaseVideoSlotOnIdle(int workerId) {
    return bk.releaseVideoSlotOnIdle(workerId, _activeVideoJobs, _slots);
  }

  /// Clears a stale captcha slot on worker idle: the page has already decided
  /// via [shouldClearCaptchaSlotOnIdle] that the slot's taskKey is no longer in
  /// the active-task set. Clears the slot's taskKey + kind (guarded by a
  /// taskKey match) and removes the reverse-mapping entry.
  void clearStaleCaptchaSlotOnIdle(int workerId, String? taskKey) {
    final slot = _slots[workerId];
    if (slot == null) return;
    if (taskKey != null && slot.taskKey == taskKey) {
      slot.taskKey = null;
      slot.kind = null;
    }
    if (taskKey != null) {
      _activeCaptchaJobs.remove(taskKey);
    }
  }

  // ── Record worker results ─────────────────────────────────────────────────

  /// Updates the slot's `consecutiveFailures` / health for a video result.
  /// Returns `true` iff the slot was marked unhealthy this call (so the page
  /// can `debugPrint`). No mutation if there is no active job for [pageKey].
  /// Reuses [bk.recordVideoWorkerResult].
  bool recordVideoWorkerResult(
    String pageKey,
    bool failed,
    int failureThreshold,
  ) {
    return bk.recordVideoWorkerResult(
      pageKey,
      failed,
      _activeVideoJobs,
      _slots,
      failureThreshold,
    );
  }

  bool recordCaptchaWorkerResult(
    String taskKey,
    bool failed,
    int failureThreshold,
  ) {
    return bk.recordCaptchaWorkerResult(
      taskKey,
      failed,
      _activeCaptchaJobs,
      _slots,
      failureThreshold,
    );
  }

  // ── Single-slot health transitions ────────────────────────────────────────

  /// Marks the worker's slot healthy-idle (called from `_onWorkerIdlePostFrame`
  /// / `_onCaptchaWorkerIdle` when the slot is not being removed for
  /// unhealthyness).
  void markSlotIdle(int workerId) {
    final slot = _slots[workerId];
    if (slot != null) {
      slot.health = WebViewWorkerHealth.idle;
    }
  }

  /// Removes a worker's slot entirely (used after an unhealthy worker reports
  /// idle, so the build stops emitting its `ReusableBrowserWorker` and Flutter
  /// disposes the underlying InAppWebView). Idempotent.
  void removeSlot(int workerId) {
    _slots.remove(workerId);
  }

  // ── Budget trim ───────────────────────────────────────────────────────────

  /// Trims idle disposable slots down to [maxConcurrent]. Returns the removed
  /// slots (in eviction order) so the page can log each
  /// `disposed idle worker` line. No-op (returns `const []`) when
  /// [useWorkerPool] is false — matching the legacy short-circuit. Reuses
  /// [sel.selectDisposableIdleSlotId] verbatim.
  List<WebViewWorkerSlot> trimIdleWorkerSlotsToBudget({
    required bool useWorkerPool,
    required int maxConcurrent,
  }) {
    if (!useWorkerPool) return const [];
    final removed = <WebViewWorkerSlot>[];
    while (_slots.length > maxConcurrent) {
      final workerId = sel.selectDisposableIdleSlotId(_slots.values);
      if (workerId == null) break;
      final slot = _slots.remove(workerId);
      if (slot != null) removed.add(slot);
    }
    return removed;
  }

  // ── Slot allocation (acquire) ────────────────────────────────────────────

  PlayerWebViewSchedulerAcquire acquireIdleCaptchaWorkerSlot({
    required bool useWorkerPool,
    required int maxConcurrent,
  }) {
    final disposed = <WebViewWorkerSlot>[];
    disposed.addAll(
      trimIdleWorkerSlotsToBudget(
        useWorkerPool: useWorkerPool,
        maxConcurrent: maxConcurrent,
      ),
    );

    final idle = sel.selectAnyIdleAcceptableSlot(_slots.values);
    if (idle != null) {
      return PlayerWebViewSchedulerAcquire(
        slot: idle,
        disposedIdleSlots: disposed,
        createdNew: false,
      );
    }
    if (useWorkerPool && _slots.length >= maxConcurrent) {
      final freed = _freeOneDisposableIdle();
      if (freed != null) disposed.add(freed);
    }
    if (!useWorkerPool || _slots.length < maxConcurrent) {
      final workerId = _nextWorkerId++;
      final slot = WebViewWorkerSlot(workerId: workerId);
      _slots[workerId] = slot;
      return PlayerWebViewSchedulerAcquire(
        slot: slot,
        disposedIdleSlots: disposed,
        createdNew: true,
      );
    }
    return PlayerWebViewSchedulerAcquire(
      slot: null,
      disposedIdleSlots: disposed,
      createdNew: false,
    );
  }

  /// Acquires an idle slot for a video job, preferring a same-source warm
  /// worker (so its InAppWebView's session/cookie carries over to the next
  /// same-source channel). [pendingSourceNames] is the set of source names
  /// that still have pending extraction jobs — used only for the affinity
  /// preference, not for job selection (the page keeps the `pickBestPending` /
  /// `selectVideoJobForAffinitySlot` step because it depends on the page's
  /// `SearchPlayResult` list + tiers + enqueue-seq).
  ///
  /// Eviction of disposable idle slots is surfaced via
  /// [PlayerWebViewSchedulerAcquire.disposedIdleSlots] for logging; creation
  /// via [.createdNew].
  PlayerWebViewSchedulerAcquire acquireIdleVideoWorkerSlot(
    Set<String> pendingSourceNames, {
    required bool useWorkerPool,
    required int maxConcurrent,
  }) {
    final disposed = <WebViewWorkerSlot>[];
    disposed.addAll(
      trimIdleWorkerSlotsToBudget(
        useWorkerPool: useWorkerPool,
        maxConcurrent: maxConcurrent,
      ),
    );

    final sameSource = sel.selectSameSourceIdleSlot(
      _slots.values,
      pendingSourceNames,
    );
    if (sameSource != null) {
      return PlayerWebViewSchedulerAcquire(
        slot: sameSource,
        disposedIdleSlots: disposed,
        createdNew: false,
      );
    }
    final any = sel.selectAnyIdleAcceptableSlot(_slots.values);
    if (any != null) {
      return PlayerWebViewSchedulerAcquire(
        slot: any,
        disposedIdleSlots: disposed,
        createdNew: false,
      );
    }
    if (useWorkerPool && _slots.length >= maxConcurrent) {
      final freed = _freeOneDisposableIdle();
      if (freed != null) disposed.add(freed);
    }
    if (!useWorkerPool || _slots.length < maxConcurrent) {
      final workerId = _nextWorkerId++;
      final slot = WebViewWorkerSlot(workerId: workerId);
      _slots[workerId] = slot;
      return PlayerWebViewSchedulerAcquire(
        slot: slot,
        disposedIdleSlots: disposed,
        createdNew: true,
      );
    }
    return PlayerWebViewSchedulerAcquire(
      slot: null,
      disposedIdleSlots: disposed,
      createdNew: false,
    );
  }

  WebViewWorkerSlot? _freeOneDisposableIdle() {
    final workerId = sel.selectDisposableIdleSlotId(_slots.values);
    if (workerId == null) return null;
    return _slots.remove(workerId);
  }

  // ── Reset paths ───────────────────────────────────────────────────────────

  /// Resets scheduler state for a new search / new episode. Clears both active
  /// maps, clears every slot's job fields, sets idle slots healthy-idle and
  /// busy slots cancelling (so the build routes didUpdateWidget into the
  /// runner's `_cancelCurrentJob(silent)` path), and cancels any in-flight
  /// staggered pump via [WebViewPoolPumpCoordinator.reset]. The slot table is
  /// **kept** so InAppWebView instances are reused across searches; only the
  /// per-job state is dropped. Mirrors the inline sequences in
  /// `_loadSampleSource` / `_loadEpisodeSource`.
  void resetForNewSearch() {
    _activeVideoJobs.clear();
    _activeCaptchaJobs.clear();
    for (final slot in _slots.values) {
      final wasIdle = slot.kind == null;
      slot.health = wasIdle
          ? WebViewWorkerHealth.idle
          : WebViewWorkerHealth.cancelling;
      slot.clearCurrentJob();
    }
    _pumpCoordinator.reset();
  }

  /// Drops all scheduler state for the live worker-pool toggle: clears both
  /// active maps and the slot table (the framework disposes the worker
  /// widgets on the next build since they stop being emitted). The
  /// worker-id counter keeps increasing so fresh slots never collide with
  /// disposed ids. The caller re-acquires captcha slots for any still-active
  /// captcha tasks after this. Mirrors `_setUseWorkerPool`.
  void clearForPoolToggle() {
    _activeVideoJobs.clear();
    _activeCaptchaJobs.clear();
    _slots.clear();
  }

  /// Clears all scheduler state on `dispose` so any post-frame idle callback
  /// arriving after the page is gone sees empty maps rather than disposed
  /// slots. The pump coordinator has no resources to release.
  void clearForDispose() {
    _activeVideoJobs.clear();
    _activeCaptchaJobs.clear();
    _slots.clear();
  }

  // ── Invariants ────────────────────────────────────────────────────────────

  /// Validates the map/slot consistency invariants. Returns a list of
  /// human-readable violation messages; an empty list means the scheduler is
  /// in a consistent state. The page (and tests) call this after each mutation
  /// to catch any drift between the slot table and the reverse maps early.
  ///
  /// Checks:
  ///   1. Each active video entry maps to a unique slot whose kind is video
  ///      and whose `pageKey` matches the map key.
  ///   2. Each active captcha entry maps to a unique slot whose kind is
  ///      captcha and whose `taskKey` matches the map key.
  ///   3. No worker appears in both the video and the captcha active map.
  ///   4. An idle slot (kind == null) retains neither a pageKey nor a taskKey.
  ///   5. A busy slot has exactly one reverse mapping (in exactly one map).
  List<String> validateInvariants() {
    final errors = <String>[];

    final videoWorkerIds = _activeVideoJobs.values.toList();
    if (videoWorkerIds.toSet().length != videoWorkerIds.length) {
      errors.add('duplicate workerIds in activeVideoJobs: $videoWorkerIds');
    }
    final captchaWorkerIds = _activeCaptchaJobs.values.toList();
    if (captchaWorkerIds.toSet().length != captchaWorkerIds.length) {
      errors.add('duplicate workerIds in activeCaptchaJobs: $captchaWorkerIds');
    }

    _activeVideoJobs.forEach((pageKey, workerId) {
      final slot = _slots[workerId];
      if (slot == null) {
        errors.add('activeVideoJobs[$pageKey]=$workerId has no slot');
        return;
      }
      if (slot.kind != WebViewWorkerKind.video) {
        errors.add(
          'activeVideoJobs[$pageKey] -> worker $workerId kind=${slot.kind} '
          '(expected video)',
        );
      }
      if (slot.pageKey != pageKey) {
        errors.add(
          'activeVideoJobs[$pageKey] -> worker $workerId slot.pageKey='
          '${slot.pageKey}',
        );
      }
    });

    _activeCaptchaJobs.forEach((taskKey, workerId) {
      final slot = _slots[workerId];
      if (slot == null) {
        errors.add('activeCaptchaJobs[$taskKey]=$workerId has no slot');
        return;
      }
      if (slot.kind != WebViewWorkerKind.captcha) {
        errors.add(
          'activeCaptchaJobs[$taskKey] -> worker $workerId kind=${slot.kind} '
          '(expected captcha)',
        );
      }
      if (slot.taskKey != taskKey) {
        errors.add(
          'activeCaptchaJobs[$taskKey] -> worker $workerId slot.taskKey='
          '${slot.taskKey}',
        );
      }
    });

    final shared = _activeVideoJobs.values.toSet().intersection(
      _activeCaptchaJobs.values.toSet(),
    );
    if (shared.isNotEmpty) {
      errors.add('workers in both video and captcha maps: $shared');
    }

    for (final slot in _slots.values) {
      if (slot.isIdle) {
        if (slot.pageKey != null) {
          errors.add(
            'idle worker ${slot.workerId} retains pageKey=${slot.pageKey}',
          );
        }
        if (slot.taskKey != null) {
          errors.add(
            'idle worker ${slot.workerId} retains taskKey=${slot.taskKey}',
          );
        }
      } else {
        final inVideo = _activeVideoJobs.containsValue(slot.workerId);
        final inCaptcha = _activeCaptchaJobs.containsValue(slot.workerId);
        final count = (inVideo ? 1 : 0) + (inCaptcha ? 1 : 0);
        if (count != 1) {
          errors.add(
            'busy worker ${slot.workerId} (kind=${slot.kind}) has $count '
            'reverse mappings',
          );
        }
      }
    }

    return errors;
  }
}
