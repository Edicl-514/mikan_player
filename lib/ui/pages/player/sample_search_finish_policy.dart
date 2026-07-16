/// Pure finish-policy helpers for sample online search.
///
/// Phase 2 preparatory seam (`docs/player_search_session_design.md` step 2):
/// pins "may the page mark sample search idle?" without moving WebView, gate,
/// or probe side effects. Callers supply snapshot facts; this module only
/// answers boolean policy questions.
library;

import 'package:mikan_player/src/rust/api/generic_scraper.dart';

/// Whether a single source's search step is terminal (success or failed).
bool isSearchStepTerminal(SearchStep step) {
  return step == SearchStep.success || step == SearchStep.failed;
}

/// Whether every enabled source has a terminal progress entry.
///
/// Empty [enabledSourceNames] means the search roster is not ready → not
/// finished (matches historical `_isSourceSearchFinished`).
bool allEnabledSourcesTerminal({
  required Iterable<String> enabledSourceNames,
  required Map<String, SourceSearchProgress> sourceProgressMap,
}) {
  if (enabledSourceNames.isEmpty) return false;
  for (final sourceName in enabledSourceNames) {
    final progress = sourceProgressMap[sourceName];
    if (progress == null || !isSearchStepTerminal(progress.step)) {
      return false;
    }
  }
  return true;
}

/// Whether the page may mark sample search idle and compute final status.
///
/// Mirrors the early-return chain in `_maybeFinishSampleSearch` before the
/// setState/error-string side effects. Probe keys are included so a late
/// probe cannot race a false "所有源都无法提取" finish.
bool mayMarkSampleSearchIdle({
  required bool isMounted,
  required bool isLoadingSample,
  required bool searchSubscriptionsNonEmpty,
  required bool pendingOrActiveCaptcha,
  required bool activeExtraction,
  required bool resolvingChannelKeysNonEmpty,
  required bool probingSourceKeysNonEmpty,
  required bool hasPendingExtraction,
  required bool allSourcesTerminal,
}) {
  if (!isMounted || !isLoadingSample) return false;
  if (searchSubscriptionsNonEmpty) return false;
  if (pendingOrActiveCaptcha) return false;
  if (activeExtraction || resolvingChannelKeysNonEmpty) return false;
  if (probingSourceKeysNonEmpty) return false;
  if (hasPendingExtraction) return false;
  if (!allSourcesTerminal) return false;
  return true;
}
