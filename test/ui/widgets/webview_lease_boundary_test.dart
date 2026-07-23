import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/webview_resource_coordinator.dart';
import 'package:mikan_player/ui/widgets/webview_lease_boundary.dart';

void main() {
  testWidgets('lease is held until the widget boundary is disposed', (
    tester,
  ) async {
    const session = PlayerSessionId('widget');
    const leaseId = WebViewWorkerLeaseId(
      playerSessionId: session,
      localWorkerId: 0,
    );
    final coordinator = WebViewResourceCoordinator(initialLimit: 1)
      ..registerSession(
        sessionId: session,
        onCapacityAvailable: () {},
        onReleaseIdleWorkers: () {},
      );
    expect(coordinator.requestLease(leaseId), isTrue);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebViewLeaseBoundary(
          leaseId: leaseId,
          coordinator: coordinator,
          child: const SizedBox(width: 1, height: 1),
        ),
      ),
    );
    expect(coordinator.ownsLease(leaseId), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(coordinator.ownsLease(leaseId), isFalse);
  });
}
