import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

void main() {
  setUp(PlayerSessionId.debugResetAllocator);

  test('PlayerSessionId.allocate is unique and monotonic', () {
    final a = PlayerSessionId.allocate();
    final b = PlayerSessionId.allocate();
    expect(a, isNot(equals(b)));
    expect(a.value, 'ps-1');
    expect(b.value, 'ps-2');
  });

  test('WebViewWorkerLeaseId equality requires session + worker', () {
    const sessionA = PlayerSessionId('a');
    const sessionB = PlayerSessionId('b');
    final lease1 = WebViewWorkerLeaseId(
      playerSessionId: sessionA,
      localWorkerId: 1,
    );
    final lease1b = WebViewWorkerLeaseId(
      playerSessionId: sessionA,
      localWorkerId: 1,
    );
    final leaseOtherSession = WebViewWorkerLeaseId(
      playerSessionId: sessionB,
      localWorkerId: 1,
    );
    final leaseOtherWorker = WebViewWorkerLeaseId(
      playerSessionId: sessionA,
      localWorkerId: 2,
    );

    expect(lease1, equals(lease1b));
    expect(lease1.hashCode, lease1b.hashCode);
    expect(lease1, isNot(equals(leaseOtherSession)));
    expect(lease1, isNot(equals(leaseOtherWorker)));
  });

  test('PlayerSessionLogContext.tag includes optional fields', () {
    const ctx = PlayerSessionLogContext(
      tabId: WorkspaceTabId('t1'),
      sessionId: PlayerSessionId('ps-9'),
      workerId: 3,
      generation: 12,
    );
    expect(ctx.tag, '[tab:t1 session:ps-9 worker:3 gen:12]');
  });

  test('copyWith can clear worker / generation', () {
    const base = PlayerSessionLogContext(
      sessionId: PlayerSessionId('ps-1'),
      workerId: 4,
      generation: 2,
    );
    final cleared = base.copyWith(clearWorkerId: true, clearGeneration: true);
    expect(cleared.workerId, isNull);
    expect(cleared.generation, isNull);
    expect(cleared.tag, '[session:ps-1]');
  });
}
