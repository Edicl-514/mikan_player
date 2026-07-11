import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';

/// Phase 2 B4: pure worker complete/cancel/late-result sub-operations.
///
/// Worker complete/cancel/late-result callbacks (`_onWebViewResult`,
/// `_onCaptchaPreflightResult`, `_onWorkerIdle`, `_onCaptchaWorkerIdle`)
/// are page-side event handlers that mutate extensive State, run setState
/// and trigger downstream effects (probe/register, stats, pump, log). The
/// methods themselves are NOT pure due to those effects — but inside each
/// are small, self-contained decisions/transforms whose correctness is
/// worth pinning down with unit tests.
///
/// This module captures three such helpers — they replicate the verbatim
/// predicates the page applies inline. The page caller keeps the effects.

/// Late-after-cancel tier guard for [_onWebViewResult].
///
/// Verbatim from the `if (_acceptedSourcePageKey != null) { final tier = …;
/// if (tier != 0) { …late… return; } }` block inside `_onWebViewResult`.
///
/// When a Tier-0 source has been accepted (i.e. another source is now
/// playing), a non-Tier-0 result that arrives late must NOT trigger
/// probe/register/auto-play — otherwise it would hijack the current
/// playback. Tier-0 results (including other channels of the accepted
/// source and other Tier-0 sources) still flow through the normal probe
/// path to populate the source list as a fallback.
///
/// [tier] is the tier of the completed source, with `999` (the same
/// default `_sourceTiers[… ] ?? 999` applies) meaning "unknown tier" and
/// is therefore NOT a Tier-0 source (i.e. late guard would suppress it).
bool isVideoResultLateAfterCancel({
  required String? acceptedSourcePageKey,
  required int tier,
}) {
  // No accepted source => every result goes through the normal path.
  // Accepted source + tier == 0 => Tier-0, allow normal probe/register.
  // Accepted source + tier != 0 => suppress probe/register (late path).
  return acceptedSourcePageKey != null && tier != 0;
}

/// Builds the resolved video [SearchPlayResult] from a pending page and a
/// successful extraction result, merging page-supplied headers with the
/// freshly captured headers from the extraction (extraction headers win
/// for duplicates).
///
/// Verbatim from the `if (result.success) { … new SearchPlayResult(…) … }`
/// branch inside `_onWebViewResult`. This is a pure transform that the
/// page then feeds to `_probeAndRegisterPlayableSource`.
SearchPlayResult buildUpdatedPlayPageFromResult({
  required SearchPlayResult page,
  required VideoExtractResult result,
}) {
  final resultHeaders = <String, String>{};
  if (page.headers != null) resultHeaders.addAll(page.headers!);
  resultHeaders.addAll(result.headers);
  return SearchPlayResult(
    sourceName: page.sourceName,
    playPageUrl: page.playPageUrl,
    videoRegex: page.videoRegex,
    directVideoUrl: result.videoUrl,
    cookies: page.cookies,
    headers: resultHeaders,
    channelName: page.channelName,
    channelIndex: page.channelIndex,
    enableNestedUrl: page.enableNestedUrl,
    matchNestedUrl: page.matchNestedUrl,
  );
}

/// Captcha worker idle stale-task cleanup predicate.
///
/// Verbatim from the inline check in `_onCaptchaWorkerIdle`:
/// ```
/// final taskKey = slot.taskKey;
/// if (taskKey != null && !_activeCaptchaTasks.containsKey(taskKey)) {
///   slot.taskKey = null;
///   slot.kind = null;
///   _activeCaptchaJobs.remove(taskKey);
/// }
/// ```
/// This pure function answers only "should the page clear the slot
/// bookkeeping here?" — the page performs the mutation itself so the
/// function is trivially universally testable without State.
bool shouldClearCaptchaSlotOnIdle({
  required String? slotTaskKey,
  required bool activeCaptchaTasksContainsKey,
}) {
  // Only clear when a taskKey is set AND the task is no longer active —
  // indicating the slot's reverse-mapping entry is stale (either the
  // source has been re-rooted via a new load token or the task was
  // cancelled before completion).
  return slotTaskKey != null && !activeCaptchaTasksContainsKey;
}
