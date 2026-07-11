import 'package:mikan_player/ui/pages/player/webview_worker_slot.dart';

/// Phase 2 B1: pure selection rules for idle WebView worker slots.
///
/// These functions replicate the sort/pick logic that was previously inline in
/// `_PlayerPageState` methods (`_removeIdleWorkerSlot`,
/// `_acquireIdleVideoWorkerSlotForAffinity`, `_acquireIdleCaptchaWorkerSlot`).
/// They only READ slot fields — the map
/// mutation (`_webViewWorkerSlots.remove/add`, `_nextWebViewWorkerId++`) stays
/// in the page.

/// Selects the [workerId] of the disposable idle slot to remove, or `null` if
/// no disposable idle slot exists.
///
/// Sort priority (ascending = first to remove):
/// 1. Unhealthy first: `health == unhealthy` → 0, else → 1.
/// 2. Cold first (`lastSourceName == null` → 0, warm → 1): cold sorts first
///    so affinity scheduling can still hit warm workers after trim.
/// 3. Highest [WebViewWorkerSlot.workerId] first.
int? selectDisposableIdleSlotId(Iterable<WebViewWorkerSlot> slots) {
  final idleSlots = slots.where((slot) => slot.canDisposeWhenIdle).toList()
    ..sort((a, b) {
      final aBad = a.health == WebViewWorkerHealth.unhealthy ? 0 : 1;
      final bBad = b.health == WebViewWorkerHealth.unhealthy ? 0 : 1;
      if (aBad != bBad) return aBad.compareTo(bBad);
      final aWarm = a.lastSourceName == null ? 0 : 1;
      final bWarm = b.lastSourceName == null ? 0 : 1;
      if (aWarm != bWarm) return aWarm.compareTo(bWarm);
      return b.workerId.compareTo(a.workerId);
    });
  if (idleSlots.isEmpty) return null;
  return idleSlots.first.workerId;
}

/// Selects an idle [WebViewWorkerSlot] whose [WebViewWorkerSlot.lastSourceName]
/// matches [pendingSourceNames], preferring the lowest [workerId].
///
/// Returns `null` if no acceptable idle slot has a matching source.
WebViewWorkerSlot? selectSameSourceIdleSlot(
  Iterable<WebViewWorkerSlot> slots,
  Set<String> pendingSourceNames,
) {
  final candidates =
      slots
          .where(
            (slot) =>
                slot.canAcceptJob &&
                slot.lastSourceName != null &&
                pendingSourceNames.contains(slot.lastSourceName!),
          )
          .toList()
        ..sort((a, b) => a.workerId.compareTo(b.workerId));
  if (candidates.isEmpty) return null;
  return candidates.first;
}

/// Selects any idle [WebViewWorkerSlot] that [WebViewWorkerSlot.canAcceptJob],
/// preferring the lowest [workerId].
///
/// Returns `null` if no acceptable idle slot exists.
WebViewWorkerSlot? selectAnyIdleAcceptableSlot(
  Iterable<WebViewWorkerSlot> slots,
) {
  final idleSlots = slots.where((slot) => slot.canAcceptJob).toList()
    ..sort((a, b) => a.workerId.compareTo(b.workerId));
  if (idleSlots.isEmpty) return null;
  return idleSlots.first;
}
