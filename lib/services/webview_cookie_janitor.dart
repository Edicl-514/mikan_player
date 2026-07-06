import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  WebViewCookieJanitor._internal();

  final Set<({String host, String name, String path})> _pendingCookies = {};
  final Set<String> _pendingHosts = {};

  Future<void> _chain = Future<void>.value();
  Timer? _idleTimer;
  Timer? _maxDeferTimer;
  bool _maxDeferScheduled = false;

  static const Duration _idleDelay = Duration(seconds: 2);
  static const Duration _maxDeferDelay = Duration(seconds: 30);

  /// Enqueue deletion of a single cookie for [host].
  /// Deduplicated by (host, cookieName, path).
  void requestCleanup({
    required String host,
    required String cookieName,
    String path = '/',
  }) {
    _pendingCookies.add((host: host, name: cookieName, path: path));
    _ensureMaxDeferTimer();
  }

  /// Enqueue deletion of all cookies currently set for [host].
  /// Deduplicated by host.
  void requestHostCleanup({required String host}) {
    _pendingHosts.add(host);
    _ensureMaxDeferTimer();
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
      final cookieManager = CookieManager();
      for (final host in hosts) {
        try {
          final got = await cookieManager.getCookies(
            url: WebUri('https://$host'),
          );
          for (final cookie in got) {
            await cookieManager.deleteCookie(
              url: WebUri('https://$host'),
              name: cookie.name,
              domain: host,
            );
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
          await cookieManager.deleteCookie(
            url: WebUri('https://${entry.host}'),
            name: entry.name,
            domain: entry.host,
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
      'cookies=$cookieCount, duration=${sw.elapsedMilliseconds}ms',
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
