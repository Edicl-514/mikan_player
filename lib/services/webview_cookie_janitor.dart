import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Minimal cookie-store boundary used by [WebViewCookieJanitor].
///
/// The default implementation delegates to flutter_inappwebview. Tests can
/// inject a deterministic backend without starting a real WebView engine.
abstract interface class WebViewCookieBackend {
  Future<List<String>> cookieNamesForHost(String host);

  Future<void> deleteCookie({
    required String host,
    required String name,
    String path = '/',
  });
}

class _InAppWebViewCookieBackend implements WebViewCookieBackend {
  const _InAppWebViewCookieBackend();

  @override
  Future<List<String>> cookieNamesForHost(String host) async {
    final cookies = await CookieManager().getCookies(
      url: WebUri('https://$host'),
    );
    return cookies.map((cookie) => cookie.name).toList(growable: false);
  }

  @override
  Future<void> deleteCookie({
    required String host,
    required String name,
    String path = '/',
  }) {
    return CookieManager().deleteCookie(
      url: WebUri('https://$host'),
      name: name,
      domain: host,
      path: path,
    );
  }
}

/// Centralized WebView cookie cleanup service.
///
/// Accepts cookie- and host-level cleanup requests, deduplicates them, and
/// drains pending work in a single serialized batch — either on demand via
/// [drainNow], shortly after [markExtractionWaveIdle] is called, or via a
/// fallback max-defer timer so queued work always drains eventually even if
/// the player never signals idleness.
///
/// Safe to call from widget dispose(): [requestCleanup] / [requestHostCleanup]
/// only enqueue and never block.
class WebViewCookieJanitor {
  static final WebViewCookieJanitor _instance =
      WebViewCookieJanitor._internal();
  factory WebViewCookieJanitor() => _instance;
  WebViewCookieJanitor._internal()
    : this._(
        backend: const _InAppWebViewCookieBackend(),
        idleDelay: const Duration(seconds: 2),
        maxDeferDelay: const Duration(seconds: 30),
      );

  @visibleForTesting
  WebViewCookieJanitor.forTesting({
    required WebViewCookieBackend backend,
    Duration idleDelay = Duration.zero,
    Duration maxDeferDelay = const Duration(seconds: 30),
  }) : this._(
         backend: backend,
         idleDelay: idleDelay,
         maxDeferDelay: maxDeferDelay,
       );

  WebViewCookieJanitor._({
    required WebViewCookieBackend backend,
    required Duration idleDelay,
    required Duration maxDeferDelay,
  }) : _backend = backend,
       _idleDelay = idleDelay,
       _maxDeferDelay = maxDeferDelay;

  final WebViewCookieBackend _backend;
  final Duration _idleDelay;
  final Duration _maxDeferDelay;

  final Set<({String host, String name, String path})> _pendingCookies = {};
  final Set<String> _pendingHosts = {};

  Future<void> _chain = Future<void>.value();
  Timer? _idleTimer;
  Timer? _maxDeferTimer;
  bool _maxDeferScheduled = false;

  /// Pending cookie + host cleanup request count (debug / invariant snapshot).
  int get debugPendingCleanupCount =>
      _pendingCookies.length + _pendingHosts.length;

  /// Enqueue deletion of a single cookie for [host].
  /// Deduplicated by (host, cookieName, path).
  ///
  /// Optional [ownerTag] is log-only (Phase 0). Cleanup is still process-wide
  /// and not yet lease-aware — Phase 1 adds [CookieUsageRegistry].
  void requestCleanup({
    required String host,
    required String cookieName,
    String path = '/',
    String? ownerTag,
  }) {
    _pendingCookies.add((host: host, name: cookieName, path: path));
    _ensureMaxDeferTimer();
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [WebViewCookieJanitor] requestCleanup '
        'host=$host name=$cookieName path=$path',
      );
    }
  }

  /// Enqueue deletion of all cookies currently set for [host].
  /// Deduplicated by host.
  void requestHostCleanup({required String host, String? ownerTag}) {
    _pendingHosts.add(host);
    _ensureMaxDeferTimer();
    if (ownerTag != null) {
      debugPrint(
        '$ownerTag [WebViewCookieJanitor] requestHostCleanup host=$host',
      );
    }
  }

  /// Signal that the extraction wave has gone idle. Schedules a drain a short
  /// delay later so bursts of dispose() calls can coalesce into one batch.
  void markExtractionWaveIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDelay, () {
      _idleTimer = null;
      drainNow();
    });
  }

  /// Drain the pending batch immediately and resolve when done. Serialized:
  /// if a batch is already running, this one waits its turn.
  Future<void> drainNow() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _cancelMaxDeferTimer();
    final done = _chain.then((_) => _runBatch());
    // Keep the chain alive regardless of failures so later batches can run.
    _chain = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _runBatch() async {
    if (_pendingCookies.isEmpty && _pendingHosts.isEmpty) return;
    final hosts = _pendingHosts.toSet();
    final cookies = _pendingCookies.toSet();
    _pendingHosts.clear();
    _pendingCookies.clear();

    final sw = Stopwatch()..start();
    var cookieCount = 0;
    try {
      for (final host in hosts) {
        try {
          final names = await _backend.cookieNamesForHost(host);
          for (final name in names) {
            await _backend.deleteCookie(host: host, name: name);
            cookieCount++;
          }
        } catch (e) {
          debugPrint(
            '[WebViewCookieJanitor] host cleanup failed for $host: $e',
          );
        }
      }
      for (final entry in cookies) {
        try {
          await _backend.deleteCookie(
            host: entry.host,
            name: entry.name,
            path: entry.path,
          );
          cookieCount++;
        } catch (e) {
          debugPrint(
            '[WebViewCookieJanitor] cookie cleanup failed for '
            '${entry.host}/${entry.name}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[WebViewCookieJanitor] batch failed: $e');
    }
    sw.stop();
    debugPrint(
      '[WebViewCookieJanitor] batch done: hosts=${hosts.length}, '
      'cookies=$cookieCount, duration=${sw.elapsedMilliseconds}ms '
      'pendingAfter=$debugPendingCleanupCount',
    );
  }

  void _ensureMaxDeferTimer() {
    if (_maxDeferScheduled) return;
    _maxDeferScheduled = true;
    _maxDeferTimer = Timer(_maxDeferDelay, () {
      _maxDeferScheduled = false;
      _maxDeferTimer = null;
      drainNow();
    });
  }

  void _cancelMaxDeferTimer() {
    if (!_maxDeferScheduled) return;
    _maxDeferTimer?.cancel();
    _maxDeferTimer = null;
    _maxDeferScheduled = false;
  }
}
