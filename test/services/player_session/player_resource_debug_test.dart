import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_resource_debug.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/source_request_gate.dart';
import 'package:mikan_player/services/webview_cookie_janitor.dart';

void main() {
  late PlayerResourceDebugRegistry registry;
  late SourceRequestGate gate;

  setUp(() {
    PlayerSessionId.debugResetAllocator();
    registry = PlayerResourceDebugRegistry.instance;
    registry.debugReset();
    gate = SourceRequestGate.instance;
    gate.debugReset();
  });

  tearDown(() {
    registry.debugReset();
    gate.debugReset();
  });

  test('register / unregister is idempotent', () {
    final id = PlayerSessionId.allocate();
    final handle = PlayerSessionDebugHandle(sessionId: id);
    registry.register(handle);
    expect(registry.sessionCount, 1);
    registry.register(handle);
    expect(registry.sessionCount, 1);
    registry.unregister(id);
    expect(registry.sessionCount, 0);
    registry.unregister(id);
    expect(registry.sessionCount, 0);
  });

  test('snapshot aggregates per-session worker and job counts', () {
    final aId = const PlayerSessionId('a');
    final bId = const PlayerSessionId('b');
    registry.register(
      PlayerSessionDebugHandle(
        sessionId: aId,
        reportCounts: () => const PlayerSessionResourceCounts(
          liveWorkerCount: 3,
          activeJobCount: 2,
        ),
      ),
    );
    registry.register(
      PlayerSessionDebugHandle(
        sessionId: bId,
        reportCounts: () => const PlayerSessionResourceCounts(
          liveWorkerCount: 2,
          activeJobCount: 1,
        ),
      ),
    );
    registry.playbackFocusSessionId = aId;

    gate.markStarted('src');
    gate.scheduleWhenReady(
      sourceName: 'src',
      minInterval: const Duration(seconds: 5),
      token: 't',
      onReady: () {},
    );

    final snap = registry.snapshot(cookieLeaseCount: 4);
    expect(snap.sessionCount, 2);
    expect(snap.liveWorkerCount, 5);
    expect(snap.activeJobCount, 3);
    expect(snap.pendingGateWaiterCount, 1);
    expect(snap.cookieLeaseCount, 4);
    expect(snap.playbackFocusSessionId, aId);
    expect(snap.shortSummary(), contains('sessions=2'));
    expect(snap.shortSummary(), contains('liveWorkers=5'));
  });

  test('mode-aware counts include legacy WebView and captcha jobs', () {
    final pooled = playerSessionResourceCountsForMode(
      useWorkerPool: true,
      pooledWorkerCount: 4,
      pooledActiveVideoJobCount: 2,
      legacyActiveVideoJobCount: 99,
      activeCaptchaJobCount: 1,
      lifecycleState: PlayerSessionLifecycleState.active,
    );
    expect(pooled.liveWorkerCount, 4);
    expect(pooled.activeJobCount, 3);

    final legacy = playerSessionResourceCountsForMode(
      useWorkerPool: false,
      pooledWorkerCount: 99,
      pooledActiveVideoJobCount: 99,
      legacyActiveVideoJobCount: 2,
      activeCaptchaJobCount: 1,
      lifecycleState: PlayerSessionLifecycleState.active,
    );
    expect(legacy.liveWorkerCount, 3);
    expect(legacy.activeJobCount, 3);
  });

  test(
    'snapshot reads pending cleanup count from the cookie janitor',
    () async {
      final janitor = WebViewCookieJanitor.forTesting(
        backend: const _NoopCookieBackend(),
        maxDeferDelay: const Duration(hours: 1),
      );
      janitor.requestCleanup(host: 'example.com', cookieName: 'session-cookie');

      expect(
        registry.snapshot(cookieJanitor: janitor).pendingCookieCleanupCount,
        1,
      );

      await janitor.drainNow();
      expect(
        registry.snapshot(cookieJanitor: janitor).pendingCookieCleanupCount,
        0,
      );
    },
  );

  test('unregister clears focus when owner was focus session', () {
    final id = const PlayerSessionId('focus');
    registry.register(PlayerSessionDebugHandle(sessionId: id));
    registry.playbackFocusSessionId = id;
    registry.unregister(id);
    expect(registry.playbackFocusSessionId, isNull);
  });
}

class _NoopCookieBackend implements WebViewCookieBackend {
  const _NoopCookieBackend();

  @override
  Future<List<String>> cookieNamesForHost(String host) async => const [];

  @override
  Future<void> deleteCookie({
    required String host,
    required String name,
    String path = '/',
  }) async {}
}
