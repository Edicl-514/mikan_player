import 'dart:async';

import 'package:flutter/foundation.dart';

/// Process-wide per-source start gate for online extraction / captcha preflight.
///
/// Rapid episode switches and player re-entry used to cancel an in-flight
/// captcha load and immediately fire the same source again. Sites respond by
/// serving broken/empty captcha images, after which OCR fails even though the
/// local runner is healthy.
///
/// This gate keeps the **latest** waiter's callback for each [sourceName] and
/// only fires it once [minInterval] has elapsed since the previous
/// [markStarted]. Older waiters are dropped (stack / latest-wins), so a user
/// who lands on EP3 only pays for EP3's request, not every intermediate stop.
///
/// Multi-session note (Phase 0): the pending map is keyed by [sourceName]
/// alone. Two Player sessions waiting on the same source currently overwrite
/// each other. Phase 1 will rekey pending entries to `(sessionId, sourceName)`
/// while keeping [_lastStartedAt] shared per source for cooldown.
class SourceRequestGate {
  SourceRequestGate._();

  static final SourceRequestGate instance = SourceRequestGate._();

  /// Default spacing for non-captcha video extraction starts.
  static const Duration defaultVideoInterval = Duration(milliseconds: 350);

  /// Floor applied to captcha [initialDelayMs] so a misconfigured 0 still
  /// provides a real cooldown under rapid re-entry.
  static const int captchaIntervalFloorMs = 800;

  final Map<String, DateTime> _lastStartedAt = <String, DateTime>{};
  final Map<String, _PendingStart> _pending = <String, _PendingStart>{};

  /// Number of sources currently holding a delayed waiter (debug / invariant).
  int get debugPendingWaiterCount => _pending.length;

  /// Token currently waiting for [sourceName], or null.
  @visibleForTesting
  Object? debugPendingToken(String sourceName) => _pending[sourceName]?.token;

  /// Remaining wait before [sourceName] may start again under [minInterval],
  /// or `null` when it may start immediately.
  Duration? remainingCooldown(String sourceName, Duration minInterval) {
    if (minInterval <= Duration.zero) return null;
    final last = _lastStartedAt[sourceName];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= minInterval) return null;
    return minInterval - elapsed;
  }

  /// Whether [sourceName] may start a new job right now.
  bool canStartNow(String sourceName, Duration minInterval) =>
      remainingCooldown(sourceName, minInterval) == null;

  /// Record that a real start (worker accept / load) just happened for
  /// [sourceName]. Cancels any pending delayed waiter for that source — the
  /// active start is the new generation baseline.
  void markStarted(String sourceName, {String? ownerTag}) {
    _lastStartedAt[sourceName] = DateTime.now();
    final pending = _pending.remove(sourceName);
    pending?.timer.cancel();
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [SourceRequestGate] $sourceName markStarted '
        '(cancelledPending=${pending != null})',
      );
    }
  }

  /// Coalesce a delayed start for [sourceName].
  ///
  /// Only the most recent [token] is kept. When the interval elapses and the
  /// token is still current, [onReady] is invoked once (typically to re-pump
  /// the WebView pool). If another start happened in the meantime the timer
  /// reschedules against the fresh baseline.
  ///
  /// Optional [ownerTag] is only prepended to debug logs (Phase 0 identity).
  void scheduleWhenReady({
    required String sourceName,
    required Duration minInterval,
    required Object token,
    required void Function() onReady,
    String? ownerTag,
  }) {
    final remaining = remainingCooldown(sourceName, minInterval);
    if (remaining == null || remaining <= Duration.zero) {
      // Already free — still hop a microtask so callers can finish their
      // current pump loop without re-entering synchronously.
      final existing = _pending.remove(sourceName);
      existing?.timer.cancel();
      scheduleMicrotask(() {
        if (!canStartNow(sourceName, minInterval)) {
          scheduleWhenReady(
            sourceName: sourceName,
            minInterval: minInterval,
            token: token,
            onReady: onReady,
            ownerTag: ownerTag,
          );
          return;
        }
        onReady();
      });
      return;
    }

    final previous = _pending.remove(sourceName);
    previous?.timer.cancel();

    late final _PendingStart pending;
    pending = _PendingStart(
      token: token,
      minInterval: minInterval,
      onReady: onReady,
      ownerTag: ownerTag,
      timer: Timer(remaining, () => _firePending(sourceName, pending)),
    );
    _pending[sourceName] = pending;
    final prefix = ownerTag == null ? '' : '$ownerTag ';
    debugPrint(
      '$prefix[SourceRequestGate] $sourceName cooling '
      '${remaining.inMilliseconds}ms (token=$token'
      '${previous == null ? '' : ', overwrotePriorToken=${previous.token}'})',
    );
  }

  void cancelPending(String sourceName, {Object? token, String? ownerTag}) {
    final pending = _pending[sourceName];
    if (pending == null) return;
    if (token != null && pending.token != token) return;
    pending.timer.cancel();
    _pending.remove(sourceName);
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [SourceRequestGate] $sourceName cancelPending token=$token',
      );
    }
  }

  /// Cancels **every** pending waiter in the process.
  ///
  /// Multi-session risk: this is not session-scoped. Prefer per-source
  /// [cancelPending] (and Phase 1 `cancelSession`) over this from PlayerPage.
  void cancelAllPending({String? ownerTag}) {
    final count = _pending.length;
    for (final pending in _pending.values) {
      pending.timer.cancel();
    }
    _pending.clear();
    if (ownerTag != null && count > 0) {
      debugPrint(
        '$ownerTag [SourceRequestGate] cancelAllPending cleared=$count',
      );
    }
  }

  /// Test-only: drop both start history and pending timers.
  @visibleForTesting
  void debugReset() {
    cancelAllPending();
    _lastStartedAt.clear();
  }

  /// Captcha start spacing derived from the source's [initialDelayMs].
  static Duration captchaIntervalMs(int initialDelayMs) {
    final ms = initialDelayMs < captchaIntervalFloorMs
        ? captchaIntervalFloorMs
        : initialDelayMs;
    return Duration(milliseconds: ms);
  }

  void _firePending(String sourceName, _PendingStart pending) {
    final current = _pending[sourceName];
    if (!identical(current, pending)) return;
    _pending.remove(sourceName);

    final remaining = remainingCooldown(sourceName, pending.minInterval);
    if (remaining != null && remaining > Duration.zero) {
      scheduleWhenReady(
        sourceName: sourceName,
        minInterval: pending.minInterval,
        token: pending.token,
        onReady: pending.onReady,
        ownerTag: pending.ownerTag,
      );
      return;
    }

    final prefix = pending.ownerTag == null ? '' : '${pending.ownerTag} ';
    debugPrint(
      '$prefix[SourceRequestGate] $sourceName ready (token=${pending.token})',
    );
    pending.onReady();
  }
}

class _PendingStart {
  _PendingStart({
    required this.token,
    required this.minInterval,
    required this.onReady,
    required this.timer,
    this.ownerTag,
  });

  final Object token;
  final Duration minInterval;
  final void Function() onReady;
  final Timer timer;
  final String? ownerTag;
}
