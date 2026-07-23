import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/webview_resource_coordinator.dart';

void main() {
  const a = PlayerSessionId('a');
  const b = PlayerSessionId('b');
  const c = PlayerSessionId('c');

  WebViewWorkerLeaseId lease(PlayerSessionId owner, int worker) =>
      WebViewWorkerLeaseId(playerSessionId: owner, localWorkerId: worker);

  void register(
    WebViewResourceCoordinator coordinator,
    PlayerSessionId session, {
    WebViewSessionPriority priority = WebViewSessionPriority.foreground,
    void Function()? onCapacity,
    void Function()? onReclaim,
  }) {
    coordinator.registerSession(
      sessionId: session,
      priority: priority,
      onCapacityAvailable: onCapacity ?? () {},
      onReleaseIdleWorkers: onReclaim ?? () {},
    );
  }

  test(
    'hard limit applies across sessions and release is idempotent',
    () async {
      final coordinator = WebViewResourceCoordinator(initialLimit: 2);
      register(coordinator, a);
      register(coordinator, b);

      expect(coordinator.requestLease(lease(a, 0)), isTrue);
      expect(coordinator.requestLease(lease(b, 0)), isTrue);
      expect(coordinator.requestLease(lease(a, 1)), isFalse);
      expect(coordinator.snapshot().liveLeaseCount, 2);
      expect(coordinator.snapshot().pendingRequestCount, 1);

      coordinator.releaseLease(lease(b, 0));
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.ownsLease(lease(a, 1)), isTrue);
      expect(coordinator.liveLeaseCount, 2);

      coordinator.releaseLease(lease(b, 0));
      expect(coordinator.liveLeaseCount, 2);
    },
  );

  test('same-priority sessions are served round-robin', () async {
    final coordinator = WebViewResourceCoordinator(initialLimit: 1);
    register(coordinator, c);
    register(coordinator, a);
    register(coordinator, b);
    expect(coordinator.requestLease(lease(c, 0)), isTrue);

    expect(coordinator.requestLease(lease(a, 0)), isFalse);
    expect(coordinator.requestLease(lease(a, 1)), isFalse);
    expect(coordinator.requestLease(lease(b, 0)), isFalse);
    expect(coordinator.requestLease(lease(b, 1)), isFalse);

    coordinator.releaseLease(lease(c, 0));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(a, 0)), isTrue);

    coordinator.releaseLease(lease(a, 0));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(b, 0)), isTrue);

    coordinator.releaseLease(lease(b, 0));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(a, 1)), isTrue);
  });

  test('foreground request wins over queued background request', () async {
    final coordinator = WebViewResourceCoordinator(initialLimit: 1);
    register(coordinator, c);
    register(coordinator, b, priority: WebViewSessionPriority.background);
    register(coordinator, a);
    coordinator.requestLease(lease(c, 0));
    coordinator.requestLease(lease(b, 0));
    coordinator.requestLease(lease(a, 0));

    coordinator.releaseLease(lease(c, 0));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(a, 0)), isTrue);
    expect(coordinator.ownsLease(lease(b, 0)), isFalse);
  });

  test('shrinking drains naturally and blocks new leases', () async {
    final coordinator = WebViewResourceCoordinator(initialLimit: 3);
    register(coordinator, a);
    register(coordinator, b);
    coordinator.requestLease(lease(a, 0));
    coordinator.requestLease(lease(a, 1));
    coordinator.requestLease(lease(a, 2));

    coordinator.updateLimit(1);
    expect(coordinator.snapshot().draining, isTrue);
    expect(coordinator.requestLease(lease(b, 0)), isFalse);
    coordinator.releaseLease(lease(a, 0));
    coordinator.releaseLease(lease(a, 1));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(b, 0)), isFalse);
    expect(coordinator.snapshot().draining, isFalse);

    coordinator.releaseLease(lease(a, 2));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.ownsLease(lease(b, 0)), isTrue);
    expect(coordinator.liveLeaseCount, 1);
  });

  test(
    'session close requests widget disposal without touching another owner',
    () async {
      final coordinator = WebViewResourceCoordinator(initialLimit: 3);
      var reclaimA = 0;
      register(coordinator, a, onReclaim: () => reclaimA++);
      register(coordinator, b);
      coordinator.requestLease(lease(a, 0));
      coordinator.requestLease(lease(b, 0));
      coordinator.markLeaseMaterialized(lease(a, 0));
      coordinator.markLeaseMaterialized(lease(b, 0));

      coordinator.releaseAllOwnedBy(a);
      expect(reclaimA, 1);
      expect(coordinator.ownsLease(lease(a, 0)), isTrue);
      expect(coordinator.ownsLease(lease(b, 0)), isTrue);

      final released = coordinator.waitUntilSessionReleased(a);
      coordinator.releaseLease(lease(a, 0));
      await released;
      expect(coordinator.ownsLease(lease(b, 0)), isTrue);
    },
  );

  test('close immediately drops a granted permit with no widget owner', () {
    final coordinator = WebViewResourceCoordinator(initialLimit: 1);
    register(coordinator, a);
    coordinator.requestLease(lease(a, 0));

    coordinator.releaseAllOwnedBy(a);
    expect(coordinator.liveLeaseCount, 0);
  });
}
