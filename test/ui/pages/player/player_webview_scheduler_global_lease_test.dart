import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/player_webview_scheduler.dart';

void main() {
  test('slot creation waits for the proposed worker lease', () {
    final scheduler = PlayerWebViewScheduler();
    final proposals = <int>[];

    final blocked = scheduler.acquireIdleVideoWorkerSlot(
      {'source'},
      useWorkerPool: true,
      maxConcurrent: 3,
      canCreateWorker: (workerId) {
        proposals.add(workerId);
        return false;
      },
    );
    expect(blocked.slot, isNull);
    expect(scheduler.workerCount, 0);
    expect(proposals, [0]);

    final granted = scheduler.acquireIdleVideoWorkerSlot(
      {'source'},
      useWorkerPool: true,
      maxConcurrent: 3,
      canCreateWorker: (workerId) {
        proposals.add(workerId);
        return true;
      },
    );
    expect(granted.slot?.workerId, 0);
    expect(granted.createdNew, isTrue);
    expect(proposals, [0, 0]);
  });

  test('reusing an idle slot does not request another lease', () {
    final scheduler = PlayerWebViewScheduler();
    var leaseRequests = 0;
    final first = scheduler.acquireIdleCaptchaWorkerSlot(
      useWorkerPool: true,
      maxConcurrent: 2,
      canCreateWorker: (_) {
        leaseRequests++;
        return true;
      },
    );
    expect(first.slot, isNotNull);

    final reused = scheduler.acquireIdleVideoWorkerSlot(
      {'source'},
      useWorkerPool: true,
      maxConcurrent: 2,
      canCreateWorker: (_) {
        leaseRequests++;
        return true;
      },
    );
    expect(reused.slot?.workerId, first.slot?.workerId);
    expect(reused.createdNew, isFalse);
    expect(leaseRequests, 1);
  });
}
