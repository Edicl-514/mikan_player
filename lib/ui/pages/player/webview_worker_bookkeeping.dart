import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';

/// Phase 2 B2: isolated bookkeeping operations for active video/captcha jobs.
///
/// These functions replicate the slot + reverse-map mutation logic that was
/// previously inline in `_PlayerPageState` methods. They parameterize the
/// maps (activeVideoJobs / activeCaptchaJobs / webViewWorkerSlots) so they
/// can be unit-tested without a full page State. The caller (the page) keeps
/// the side-effects (debugPrint, _webviewStats, _webViewStatus, setState).
///
/// Start operations validate the idle-slot and reverse-map invariants before
/// mutating either object. Invalid transitions throw [StateError] without
/// partially updating the slot or map.

void _ensureSlotCanStartJob(
  WebViewWorkerSlot slot,
  String jobKey,
  Map<String, int> activeJobs,
) {
  if (!slot.canAcceptJob || slot.pageKey != null || slot.taskKey != null) {
    throw StateError(
      'Worker ${slot.workerId} cannot accept $jobKey: '
      'kind=${slot.kind}, health=${slot.health}, '
      'pageKey=${slot.pageKey}, taskKey=${slot.taskKey}',
    );
  }
  if (activeJobs.containsKey(jobKey)) {
    throw StateError('Job $jobKey is already active');
  }
  if (activeJobs.values.contains(slot.workerId)) {
    throw StateError(
      'Worker ${slot.workerId} already has an active reverse mapping',
    );
  }
}

/// Marks [slot] as running a video job and records the reverse mapping.
///
/// Verbatim from the inline sequence in `_startOneWebViewExtractionTask`:
/// slot.pageKey = pageKey; slot.kind = video; slot.lastSourceName = source;
/// slot.health = running; activeVideoJobs[pageKey] = slot.workerId.
void startVideoJobOnSlot(
  WebViewWorkerSlot slot,
  String pageKey,
  String sourceName,
  Map<String, int> activeVideoJobs,
) {
  _ensureSlotCanStartJob(slot, pageKey, activeVideoJobs);
  slot.pageKey = pageKey;
  slot.kind = WebViewWorkerKind.video;
  slot.lastSourceName = sourceName;
  slot.health = WebViewWorkerHealth.running;
  activeVideoJobs[pageKey] = slot.workerId;
}

/// Marks [slot] as running a captcha job and records the reverse mapping.
///
/// Verbatim from the inline sequence in `_startOneCaptchaTask` /
/// the rebuild loop in `_resetWebViewPool`:
/// slot.taskKey = taskKey; slot.kind = captcha; slot.lastSourceName = source;
/// slot.health = running; activeCaptchaJobs[taskKey] = slot.workerId.
void startCaptchaJobOnSlot(
  WebViewWorkerSlot slot,
  String taskKey,
  String sourceName,
  Map<String, int> activeCaptchaJobs,
) {
  _ensureSlotCanStartJob(slot, taskKey, activeCaptchaJobs);
  slot.taskKey = taskKey;
  slot.kind = WebViewWorkerKind.captcha;
  slot.lastSourceName = sourceName;
  slot.health = WebViewWorkerHealth.running;
  activeCaptchaJobs[taskKey] = slot.workerId;
}

/// Releases the captcha slot for [taskKey]: removes the reverse-mapping entry
/// and clears the slot's job fields (kind → null, taskKey → null).
///
/// Verbatim from `_releaseCaptchaSlotForTask`. The slot itself stays in
/// [slots] (it is reusable). No-op if the reverse-mapping has no entry for
/// [taskKey], or if the slot's taskKey doesn't match (guard against stale
/// callbacks).
void releaseCaptchaSlot(
  String taskKey,
  Map<String, int> activeCaptchaJobs,
  Map<int, WebViewWorkerSlot> slots,
) {
  final workerId = activeCaptchaJobs.remove(taskKey);
  if (workerId == null) return;
  final slot = slots[workerId];
  if (slot?.taskKey == taskKey) {
    slot?.taskKey = null;
    slot?.kind = null;
  }
}

/// Cancels the video job for [pageKey]: removes the reverse-mapping entry,
/// sets the slot health to cancelling, and clears pageKey + kind so the build
/// phase won't re-dispatch a runner.
///
/// Verbatim from the pool-mode branch of `_cancelLowerPriorityExtraction`.
/// Returns the workerId that was removed (or null if no active job existed),
/// so the caller can perform any side-effects on that worker.
int? cancelVideoJob(
  String pageKey,
  Map<String, int> activeVideoJobs,
  Map<int, WebViewWorkerSlot> slots,
) {
  final workerId = activeVideoJobs.remove(pageKey);
  final slot = workerId == null ? null : slots[workerId];
  if (slot != null) {
    slot.health = WebViewWorkerHealth.cancelling;
    slot.pageKey = null;
    slot.kind = null;
  }
  return workerId;
}

/// Releases a video slot on worker idle: clears the slot's pageKey + kind and
/// removes the reverse-mapping entry. Used by `_onWorkerIdle` when a worker
/// reports it is done.
///
/// Verbatim from the pool-mode branch of `_onWorkerIdle`. Returns the
/// previous pageKey (or null) so the caller can clean up _webViewStatus etc.
String? releaseVideoSlotOnIdle(
  int workerId,
  Map<String, int> activeVideoJobs,
  Map<int, WebViewWorkerSlot> slots,
) {
  final slot = slots[workerId];
  if (slot == null) return null;

  final prevPageKey = slot.pageKey;
  if (prevPageKey != null) {
    slot.pageKey = null;
    activeVideoJobs.remove(prevPageKey);
  }
  if (slot.kind != null) {
    slot.kind = null;
  }
  return prevPageKey;
}

/// Records a video worker result, updating the slot's [consecutiveFailures]
/// and potentially marking it [unhealthy].
///
/// Verbatim from `_recordVideoWorkerResult`. [failed] is `!result.success ||
/// result.timedOut`. Returns `true` if the slot was marked unhealthy this
/// call (so the caller can debugPrint). Returns `false` if there was no
/// active job for [pageKey], no slot found, or the slot wasn't marked unhealthy.
bool recordVideoWorkerResult(
  String pageKey,
  bool failed,
  Map<String, int> activeVideoJobs,
  Map<int, WebViewWorkerSlot> slots,
  int failureThreshold,
) {
  final workerId = activeVideoJobs[pageKey];
  if (workerId == null) return false;
  final slot = slots[workerId];
  if (slot == null) return false;

  if (!failed) {
    slot.consecutiveFailures = 0;
    return false;
  }

  slot.consecutiveFailures++;
  if (slot.consecutiveFailures >= failureThreshold) {
    slot.health = WebViewWorkerHealth.unhealthy;
    return true;
  }
  return false;
}

/// Records a captcha worker result, updating the slot's [consecutiveFailures]
/// and potentially marking it [unhealthy].
///
/// Verbatim from `_recordCaptchaWorkerResult`. [failed] is `!result.success`.
/// Returns `true` if the slot was marked unhealthy this call.
bool recordCaptchaWorkerResult(
  String taskKey,
  bool failed,
  Map<String, int> activeCaptchaJobs,
  Map<int, WebViewWorkerSlot> slots,
  int failureThreshold,
) {
  final workerId = activeCaptchaJobs[taskKey];
  if (workerId == null) return false;
  final slot = slots[workerId];
  if (slot == null) return false;

  if (!failed) {
    slot.consecutiveFailures = 0;
    return false;
  }

  slot.consecutiveFailures++;
  if (slot.consecutiveFailures >= failureThreshold) {
    slot.health = WebViewWorkerHealth.unhealthy;
    return true;
  }
  return false;
}
