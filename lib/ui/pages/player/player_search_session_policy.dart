/// Pure search-session acceptance / captcha-refresh policy for the player.
///
/// Phase 4 preparatory seam for the PlayerSearchSession design note
/// (`docs/player_search_session_design.md`). These helpers pin cross-cutting
/// stale-completion contracts without moving WebView, Rust, or page
/// orchestration. Callers keep side effects; this file only answers
/// accept/reject and captcha-refresh interpretation questions.
library;

/// Whether an asynchronous search-scoped result may mutate visible sample /
/// captcha / extraction state owned by the current search generation.
///
/// Mirrors the page's `loadToken == sampleLoadToken` (+ dispose) guards used by
/// `_loadSampleSource` continuations, `_onCaptchaPreflightResult`, and
/// extraction/probe paths.
bool isSearchGenerationCurrent({
  required int resultLoadToken,
  required int currentLoadToken,
  required bool isDisposed,
}) {
  if (isDisposed) return false;
  return resultLoadToken == currentLoadToken;
}

/// Whether a captcha completion may run its success/failure callback for the
/// active task bookkeeping.
///
/// Requires a live search generation, a non-null active task entry, and a
/// matching task key. Late results after cancel still release slots on the
/// page; they must not apply runtime overrides or source progress.
bool mayApplyCaptchaResult({
  required int resultLoadToken,
  required int currentLoadToken,
  required bool isDisposed,
  required bool activeTaskPresent,
  required String? activeTaskKey,
  required String resultTaskKey,
}) {
  if (!isSearchGenerationCurrent(
    resultLoadToken: resultLoadToken,
    currentLoadToken: currentLoadToken,
    isDisposed: isDisposed,
  )) {
    return false;
  }
  if (!activeTaskPresent) return false;
  return activeTaskKey == resultTaskKey;
}

/// Whether a video extraction completion may proceed into probe/register for
/// the current search.
///
/// Combines generation currency with the existing late-after-accept tier guard
/// input: when [isLateNonTier0AfterAccept] is true the page must suppress
/// probe/register (see [isVideoResultLateAfterCancel]).
bool mayProbeVideoExtractionResult({
  required int resultLoadToken,
  required int currentLoadToken,
  required bool isDisposed,
  required bool isLateNonTier0AfterAccept,
}) {
  if (!isSearchGenerationCurrent(
    resultLoadToken: resultLoadToken,
    currentLoadToken: currentLoadToken,
    isDisposed: isDisposed,
  )) {
    return false;
  }
  if (isLateNonTier0AfterAccept) return false;
  return true;
}

/// Captcha-refresh interpretation after the runner can no longer detect the
/// captcha DOM.
///
/// The captcha image is often briefly detached while a refresh loads. That is
/// **not** the same as a solved challenge. Only a present success selector
/// (with empty-selector disallowed) counts as success; otherwise the runner
/// must wait for the image to reappear / continue OCR.
///
/// Mirrors `WebViewCaptchaJobRunner` retry path after `_refreshCaptchaImage`.
bool shouldTreatMissingCaptchaAfterRefreshAsSuccess({
  required bool captchaStillDetectable,
  required bool successSelectorPresent,
}) {
  if (captchaStillDetectable) return false;
  return successSelectorPresent;
}

/// Whether a post-frame worker-idle notification may clear bookkeeping for a
/// captcha slot that was reset / reassigned.
///
/// If the slot already carries a new kind (reassigned job), the idle event is
/// stale and must not mark idle or clear reverse maps.
bool mayProcessCaptchaWorkerIdle({required bool slotHasActiveKind}) {
  return !slotHasActiveKind;
}

/// Whether a brand-new captcha/video job may be started for the current
/// generation. Dispose and generation mismatch both block starts.
bool mayStartSearchScopedJob({
  required int jobLoadToken,
  required int currentLoadToken,
  required bool isDisposed,
}) {
  return isSearchGenerationCurrent(
    resultLoadToken: jobLoadToken,
    currentLoadToken: currentLoadToken,
    isDisposed: isDisposed,
  );
}
