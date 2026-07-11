import 'package:mikan_player/src/rust/api/generic_scraper.dart';

/// Phase 2 B3: pure pump decision helpers for the WebView worker pool.
///
/// These functions replicate the captcha/video competition gate, the
/// per-source soft-limit and the source-affinity job selection logic that
/// were previously inline in `_PlayerPageState` methods. They read only the
/// snapshot they receive as parameters (no page State) so they can be
/// unit-tested in isolation.
///
/// Verbatim from:
/// - `_pumpWebViewPoolNow` / `_pumpWebViewPoolStaggered` (captcha gate)
/// - `_selectNextVideoJobForWorker` (affinity + soft limit + global fallback)
/// - `_pickBestPending` (tier + enqueue-seq stable sort)

/// Captcha-vs-video competition gate.
///
/// Verbatim from the `canStartCaptcha` expression at the top of
/// `_pumpWebViewPoolNow` and `_pumpWebViewPoolStaggered`:
/// ```
/// final canStartCaptcha =
///     !hasPendingExtraction || hasActiveExtraction || slotsRemaining > 1;
/// ```
/// Rationale: a captcha task should only run when either (a) there is no
/// pending video extraction to give the slot to, (b) an extraction is
/// already running so the remaining slots are not exclusively needed by
/// video, or (c) more than one slot is vacant so video can still get one.
bool canStartCaptchaDecision({
  required bool hasPendingExtraction,
  required bool hasActiveExtraction,
  required int slotsRemaining,
}) {
  return !hasPendingExtraction || hasActiveExtraction || slotsRemaining > 1;
}

/// Picks the highest-priority candidate from [candidates] by (tier asc,
/// enqueue-sequence asc) — a stable sort preserving the caller's order for
/// equal-key items.
///
/// Verbatim from `_pickBestPending`. Caller supplies [pageKeyOf] so the pure
/// function does not depend on page State. Throws if [candidates] is empty.
SearchPlayResult pickBestPending(
  List<SearchPlayResult> candidates, {
  required Map<String, int> sourceTiers,
  required Map<String, int> enqueueSeqByPageKey,
  required String Function(SearchPlayResult) pageKeyOf,
}) {
  candidates.sort((a, b) {
    final tierA = sourceTiers[a.sourceName] ?? 999;
    final tierB = sourceTiers[b.sourceName] ?? 999;
    if (tierA != tierB) return tierA.compareTo(tierB);
    final seqA = enqueueSeqByPageKey[pageKeyOf(a)] ?? 0;
    final seqB = enqueueSeqByPageKey[pageKeyOf(b)] ?? 0;
    return seqA.compareTo(seqB);
  });
  return candidates.first;
}

/// Selects the next video job for an idle worker, respecting source affinity
/// and a per-source soft limit so no single source monopolises the pool when
/// others are waiting.
///
/// Verbatim from `_selectNextVideoJobForWorker` (the 3-step pipeline):
/// 1. **Same-source priority** — if the worker's [affinitySource] has pending
///    same-source jobs and isn't saturated (other sources pending AND active
///    count < [softLimit]), pick the best same-source job.
/// 2. **Global fallback** — collect all candidates whose source isn't
///    saturated, then pick the best; if every source is saturated (deadlock
///    guard) fall back to all pending.
/// 3. Returns `null` only when [pending] is empty.
SearchPlayResult? selectVideoJobForAffinitySlot({
  required String? affinitySource,
  required List<SearchPlayResult> pending,
  required Map<String, int> activeSourceWorkers,
  required int softLimit,
  required Map<String, int> sourceTiers,
  required Map<String, int> enqueueSeqByPageKey,
  required String Function(SearchPlayResult) pageKeyOf,
}) {
  if (pending.isEmpty) return null;

  // Step 1: same-source priority (gated by soft limit).
  if (affinitySource != null && affinitySource.isNotEmpty) {
    final sameSource = pending
        .where((p) => p.sourceName == affinitySource)
        .toList();
    if (sameSource.isNotEmpty) {
      final otherSourcesPending = pending.any(
        (p) => p.sourceName != affinitySource,
      );
      final currentActive = activeSourceWorkers[affinitySource] ?? 0;
      final limited = otherSourcesPending && currentActive >= softLimit;
      if (!limited) {
        return pickBestPending(
          sameSource,
          sourceTiers: sourceTiers,
          enqueueSeqByPageKey: enqueueSeqByPageKey,
          pageKeyOf: pageKeyOf,
        );
      }
    }
  }

  // Step 2: global fallback, filter saturated sources.
  final candidates = <SearchPlayResult>[];
  for (final p in pending) {
    final src = p.sourceName;
    final currentActive = activeSourceWorkers[src] ?? 0;
    final otherSourcesPending = pending.any((pp) => pp.sourceName != src);
    final limited = otherSourcesPending && currentActive >= softLimit;
    if (!limited) {
      candidates.add(p);
    }
  }
  if (candidates.isEmpty) {
    // Deadlock guard: every source saturated — allow any to avoid pump stall.
    candidates.addAll(pending);
  }

  return pickBestPending(
    candidates,
    sourceTiers: sourceTiers,
    enqueueSeqByPageKey: enqueueSeqByPageKey,
    pageKeyOf: pageKeyOf,
  );
}
