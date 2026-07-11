import 'dart:async';

/// Phase 2 B5: stateful coordinator for the WebView pool pump scheduling.
///
/// B1–B4 extracted *pure* functions; B5 encapsulates the *stateful*
/// scheduling bookkeeping (`_webViewPoolPumpScheduled` dedup flag +
/// `_webViewPumpToken` cancel token) that was previously inline in
/// `_PlayerPageState`.
///
/// The coordinator owns two pieces of state:
///   1. `_scheduled` — dedup flag so multiple `scheduleStaggered` calls
///      collapse into one in-flight pump loop.
///   2. `_token` — monotonically increasing cancel token. Every resetor
///      immediate-schedule increments it; the staggered loop's pending
///      invocations are invalidated by token mismatch.
///
/// The actual pump work (`_pumpWebViewPoolNow`, `_pumpWebViewPoolStaggered`)
/// stays on the page — it touches too much State to be pure. The coordinator
/// invokes it via callbacks the page supplies, making the state machine
/// unit-testable in isolation.
///
/// Verbatim from `_PlayerPageState._scheduleWebViewPoolPump` and its
/// surrounding reset points (`_resetWebViewPool`, `_resetForNewSample`).

/// Signature of the synchronous pump used by [scheduleImmediate]. Returns
/// whether any job was started — the caller uses that to decide whether
/// to setState / update pool status.
typedef PumpNowCallback = bool Function();

/// Signature of the async pump used by [scheduleStaggered]. The coordinator
/// passes the issued token so the loop can detect cancellation.
typedef PumpStaggeredCallback = Future<void> Function(int token);

class WebViewPoolPumpCoordinator {
  bool _scheduled = false;
  int _token = 0;

  /// Whether a staggered pump is currently in flight (dedup flag).
  bool get isScheduled => _scheduled;

  /// The current cancel token. Incremented on reset / immediate / staggered.
  int get token => _token;

  /// Immediate pump — cancels any pending staggered pump by incrementing the
  /// token and clearing the flag, then synchronously invokes [pump]. Returns
  /// the value [pump] returned so the caller can drive setState / status.
  ///
  /// Verbatim from `_scheduleWebViewPoolPump(immediate: true)`:
  /// ```
  /// if (_webViewPoolPumpScheduled) {
  ///   _webViewPumpToken++;
  ///   _webViewPoolPumpScheduled = false;
  /// }
  /// final startedAny = _pumpWebViewPoolNow();
  /// ```
  bool scheduleImmediate(PumpNowCallback pump) {
    if (_scheduled) {
      _token++;
      _scheduled = false;
    }
    return pump();
  }

  /// Staggered pump — if a staggered pump is already scheduled, this is a
  /// no-op. Otherwise marks scheduled, issues a new token, and starts the
  /// async pump.
  ///
  /// Verbatim from `_scheduleWebViewPoolPump(immediate: false)`:
  /// ```
  /// if (_webViewPoolPumpScheduled) return;
  /// _webViewPoolPumpScheduled = true;
  /// _webViewPumpToken++;
  /// _pumpWebViewPoolStaggered(_webViewPumpToken);
  /// ```
  void scheduleStaggered(PumpStaggeredCallback pump) {
    if (_scheduled) return;
    _scheduled = true;
    _token++;
    pump(_token);
  }

  /// Clears the scheduled flag iff the given token is still current.
  ///
  /// Verbatim from `_pumpWebViewPoolStaggered`'s end:
  /// ```
  /// if (token == _webViewPumpToken) {
  ///   _webViewPoolPumpScheduled = false;
  /// }
  /// ```
  void clearScheduledIfCurrent(int token) {
    if (token == _token) _scheduled = false;
  }

  /// Returns `true` iff [token] matches the current token — used by an
  /// in-flight pump loop to know if it has been cancelled.
  ///
  /// Verbatim from `_pumpWebViewPoolStaggered`'s loop guard:
  /// ```
  /// if (!mounted || token != _webViewPumpToken) break;
  /// ```
  /// (The `mounted` guard stays on the page; this method only handles the
  /// token half.)
  bool isCurrentToken(int token) => token == _token;

  /// Resets the coordinator: clears the scheduled flag and increments the
  /// token (cancels any pending pump). Leaves the token monotonically
  /// increasing to match the page's historic behaviour.
  ///
  /// Verbatim from `_resetWebViewPool` / `_resetForNewSample`:
  /// ```
  /// _webViewPoolPumpScheduled = false;
  /// _webViewPumpToken++;
  /// ```
  void reset() {
    _scheduled = false;
    _token++;
  }
}
