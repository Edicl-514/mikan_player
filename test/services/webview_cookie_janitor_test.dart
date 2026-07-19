import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
    await janitor.drainNow();

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
