import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/cookie_usage_registry.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';

void main() {
  test('deduplicates host and cookie cleanup requests', () async {
    final backend = _FakeCookieBackend()
      ..namesByHost['example.com'] = ['session', 'challenge'];
    final janitor = WebViewCookieJanitor.forTesting(backend: backend);

    janitor.requestHostCleanup(host: 'example.com');
    janitor.requestHostCleanup(host: 'example.com');
    janitor.requestCleanup(host: 'example.com', cookieName: 'explicit');
    janitor.requestCleanup(host: 'example.com', cookieName: 'explicit');
    expect(janitor.debugPendingCleanupCount, 2);
    await janitor.drainNow();
    expect(janitor.debugPendingCleanupCount, 0);

    expect(backend.hostLookups, ['example.com']);
    expect(backend.deletions, [
      ('example.com', 'session', '/'),
      ('example.com', 'challenge', '/'),
      ('example.com', 'explicit', '/'),
    ]);
  });

  test('cleanup failure does not block later cleanup work', () async {
    final backend = _FakeCookieBackend()..failNames.add('broken');
    final janitor = WebViewCookieJanitor.forTesting(backend: backend);

    janitor.requestCleanup(host: 'first.example', cookieName: 'broken');
    await janitor.drainNow();

    janitor.requestCleanup(host: 'second.example', cookieName: 'healthy');
    await janitor.drainNow();

    expect(backend.attempts, [
      ('first.example', 'broken', '/'),
      ('second.example', 'healthy', '/'),
    ]);
    expect(backend.deletions, [('second.example', 'healthy', '/')]);
  });

  test(
    'requests added during a drain are serialized into the next batch',
    () async {
      final backend = _FakeCookieBackend();
      final janitor = WebViewCookieJanitor.forTesting(backend: backend);
      final releaseFirst = backend.blockName('first');

      janitor.requestCleanup(host: 'example.com', cookieName: 'first');
      final firstDrain = janitor.drainNow();
      await backend.firstBlockedAttempt.future;

      janitor.requestCleanup(host: 'example.com', cookieName: 'second');
      final secondDrain = janitor.drainNow();
      releaseFirst.complete();
      await Future.wait([firstDrain, secondDrain]);

      expect(backend.deletions, [
        ('example.com', 'first', '/'),
        ('example.com', 'second', '/'),
      ]);
    },
  );

  test('host cleanup waits until every session lease is released', () async {
    const a = PlayerSessionId('a');
    const b = PlayerSessionId('b');
    final usage = CookieUsageRegistry()
      ..registerSession(a, generation: 1)
      ..registerSession(b, generation: 1);
    const leaseA = CookieHostLeaseId(sessionId: a, resourceKey: 'worker-a');
    const leaseB = CookieHostLeaseId(sessionId: b, resourceKey: 'worker-b');
    usage.acquireHost(leaseA, 'shared.example');
    usage.acquireHost(leaseB, 'shared.example');
    final backend = _FakeCookieBackend()
      ..namesByHost['shared.example'] = ['challenge'];
    final janitor = WebViewCookieJanitor.forTesting(
      backend: backend,
      usageRegistry: usage,
    );

    janitor.requestHostCleanup(
      host: 'shared.example',
      sessionId: a,
      generation: 1,
    );
    usage.releaseLease(leaseA);
    await janitor.drainNow();
    expect(backend.deletions, isEmpty);
    expect(janitor.debugPendingCleanupCount, 1);

    usage.releaseLease(leaseB);
    await janitor.drainNow();
    expect(backend.deletions, [('shared.example', 'challenge', '/')]);
    expect(janitor.debugPendingCleanupCount, 0);
  });

  test('stale owner generation cleanup is discarded', () async {
    const a = PlayerSessionId('a');
    final usage = CookieUsageRegistry()..registerSession(a, generation: 1);
    final backend = _FakeCookieBackend();
    final janitor = WebViewCookieJanitor.forTesting(
      backend: backend,
      usageRegistry: usage,
    );
    janitor.requestCleanup(
      host: 'example.com',
      cookieName: 'old',
      sessionId: a,
      generation: 1,
    );

    usage.updateSessionGeneration(a, 2);
    await janitor.drainNow();
    expect(backend.attempts, isEmpty);
    expect(janitor.debugPendingCleanupCount, 0);
  });

  test('shutdown drain may ignore active host leases', () async {
    const a = PlayerSessionId('a');
    final usage = CookieUsageRegistry()..registerSession(a, generation: 1);
    const lease = CookieHostLeaseId(sessionId: a, resourceKey: 'worker');
    usage.acquireHost(lease, 'example.com');
    final backend = _FakeCookieBackend();
    final janitor = WebViewCookieJanitor.forTesting(
      backend: backend,
      usageRegistry: usage,
    );
    janitor.requestCleanup(
      host: 'example.com',
      cookieName: 'shutdown',
      sessionId: a,
      generation: 1,
    );

    await janitor.drainForShutdown();
    expect(backend.deletions, [('example.com', 'shutdown', '/')]);
  });
}

class _FakeCookieBackend implements WebViewCookieBackend {
  final Map<String, List<String>> namesByHost = <String, List<String>>{};
  final Set<String> failNames = <String>{};
  final List<String> hostLookups = <String>[];
  final List<(String, String, String?)> attempts = [];
  final List<(String, String, String?)> deletions = [];
  final Map<String, Completer<void>> _blocks = <String, Completer<void>>{};
  final Completer<void> firstBlockedAttempt = Completer<void>();

  Completer<void> blockName(String name) {
    return _blocks.putIfAbsent(name, Completer<void>.new);
  }

  @override
  Future<List<String>> cookieNamesForHost(String host) async {
    hostLookups.add(host);
    return namesByHost[host] ?? const <String>[];
  }

  @override
  Future<void> deleteCookie({
    required String host,
    required String name,
    String path = '/',
  }) async {
    attempts.add((host, name, path));
    final block = _blocks[name];
    if (block != null) {
      if (!firstBlockedAttempt.isCompleted) firstBlockedAttempt.complete();
      await block.future;
    }
    if (failNames.contains(name)) throw StateError('delete failed: $name');
    deletions.add((host, name, path));
  }
}
