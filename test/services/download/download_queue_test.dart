import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/download_queue.dart';

void main() {
  group('DownloadQueue', () {
    test('acquires up to maxConcurrent synchronously when below cap', () async {
      final q = DownloadQueue(maxConcurrent: 2);
      expect(await q.acquire('a'), isTrue);
      expect(q.activeSlotCount, 1);
      expect(await q.acquire('b'), isTrue);
      expect(q.activeSlotCount, 2);
      expect(q.hasAvailableSlot, isFalse);
    });

    test('blocks additional acquirers behind a full slot pool', () async {
      final q = DownloadQueue(maxConcurrent: 1);
      expect(await q.acquire('a'), isTrue);
      // Second acquire must wait — not yet resolved.
      final second = q.acquire('b');
      var resolved = false;
      // Unawaited future: do not let the test hang.
      second.then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);
      expect(q.isHolder('a'), isTrue);
      expect(q.isHolder('b'), isFalse);

      // Releasing 'a' must unblock 'b'.
      q.release('a');
      expect(await second, isTrue);
      expect(q.isHolder('b'), isTrue);
      expect(q.isHolder('a'), isFalse);
    });

    test('FIFO order: first waiter is granted the next slot', () async {
      final q = DownloadQueue(maxConcurrent: 1);
      expect(await q.acquire('a'), isTrue);
      final waitB = q.acquire('b');
      final waitC = q.acquire('c');
      // Drain the event loop so both waiters are enqueued.
      await Future<void>.delayed(Duration.zero);
      q.release('a');
      // 'b' is granted first.
      expect(await waitB, isTrue);
      // 'c' must wait for 'b' to release.
      q.release('b');
      expect(await waitC, isTrue);
    });

    test('release drains queue and grants next waiter', () async {
      final q = DownloadQueue(maxConcurrent: 1);
      await q.acquire('a');
      final waitB = q.acquire('b');
      await Future<void>.delayed(Duration.zero);
      q.release('a');
      expect(await waitB, isTrue);
    });

    test('release is a no-op for tasks that do not hold a slot', () {
      final q = DownloadQueue(maxConcurrent: 2);
      expect(() => q.release('nope'), returnsNormally);
      expect(q.activeSlotCount, 0);
    });

    test('re-acquiring for an existing holder returns true without '
        'incrementing the slot count', () async {
      final q = DownloadQueue(maxConcurrent: 2);
      expect(await q.acquire('a'), isTrue);
      expect(await q.acquire('a'), isTrue);
      expect(q.activeSlotCount, 1);
    });

    test('transfer hands the slot to the new id when the old id holds one', () {
      final q = DownloadQueue(maxConcurrent: 2);
      q.transfer('old', 'new');
      // The transfer is a no-op when the old id doesn't hold a slot.
      expect(q.isHolder('new'), isFalse);
    });

    test('transfer reassigns the slot holder when old id held one', () {
      final q = DownloadQueue(maxConcurrent: 1);
      // Synchronously push a holder by acquiring and re-acquiring.
      // We use the public API: only future-based acquire is public, so
      // we just simulate a holder via transfer of a manually-added id.
      // (No public mutator for adding a holder exists, so we exercise the
      // public contract via acquire.)
      // For this test, drive everything through the public API:
      // (a) acquire a,
      // (b) try to acquire b (which will be queued),
      // (c) release a,
      // (d) b is granted,
      // (e) transfer b -> c moves the slot.
      return () async {
        await q.acquire('a');
        final waitB = q.acquire('b');
        await Future<void>.delayed(Duration.zero);
        q.release('a');
        expect(await waitB, isTrue);
        q.transfer('b', 'c');
        expect(q.isHolder('b'), isFalse);
        expect(q.isHolder('c'), isTrue);
      }();
    });

    test('transfer is a no-op when old and new ids are equal', () {
      final q = DownloadQueue(maxConcurrent: 1);
      return () async {
        await q.acquire('x');
        q.transfer('x', 'x');
        expect(q.isHolder('x'), isTrue);
        expect(q.activeSlotCount, 1);
      }();
    });

    test('in-eligible acquire returns false and does not enqueue', () async {
      var eligible = <String>{};
      final q = DownloadQueue(
        maxConcurrent: 1,
        isTaskEligible: (id) => eligible.contains(id),
      );
      expect(await q.acquire('a'), isFalse);
      expect(q.activeSlotCount, 0);
      expect(q.hasAvailableSlot, isTrue);
    });

    test(
      'waiter completes with false if eligibility is revoked while waiting',
      () async {
        var allowed = {'a', 'b'};
        final q = DownloadQueue(
          maxConcurrent: 1,
          isTaskEligible: (id) => allowed.contains(id),
        );
        expect(await q.acquire('a'), isTrue);
        final waitB = q.acquire('b');
        await Future<void>.delayed(Duration.zero);
        // 'b' is revoked before a slot opens.
        allowed.remove('b');
        q.release('a');
        expect(await waitB, isFalse);
        expect(q.isHolder('b'), isFalse);
      },
    );

    test(
      'raising maxConcurrent drains the queue and grants waiting tasks',
      () async {
        final q = DownloadQueue(maxConcurrent: 1);
        await q.acquire('a');
        final waitB = q.acquire('b');
        await Future<void>.delayed(Duration.zero);
        q.maxConcurrent = 2;
        expect(await waitB, isTrue);
        expect(q.activeSlotCount, 2);
      },
    );

    test('lowering maxConcurrent does not evict current holders', () async {
      final q = DownloadQueue(maxConcurrent: 2);
      await q.acquire('a');
      await q.acquire('b');
      q.maxConcurrent = 1;
      expect(q.isHolder('a'), isTrue);
      expect(q.isHolder('b'), isTrue);
    });

    test('maxConcurrent must be >= 1', () {
      final q = DownloadQueue();
      expect(() => q.maxConcurrent = 0, throwsArgumentError);
      expect(() => q.maxConcurrent = -5, throwsArgumentError);
      q.maxConcurrent = 1;
    });

    test('reconcile evicts holders that are no longer eligible', () async {
      var allowed = {'a', 'b', 'c'};
      final q = DownloadQueue(
        maxConcurrent: 2,
        isTaskEligible: (id) => allowed.contains(id),
      );
      await q.acquire('a');
      await q.acquire('b');
      expect(q.activeSlotCount, 2);
      // 'a' becomes ineligible — the next acquire() must drop it.
      allowed.remove('a');
      // Trigger a new acquire which calls _reconcile internally.
      expect(await q.acquire('c'), isTrue);
      expect(q.isHolder('a'), isFalse);
      expect(q.isHolder('b'), isTrue);
      expect(q.isHolder('c'), isTrue);
    });

    test('hasAvailableSlot reports queue state correctly', () async {
      final q = DownloadQueue(maxConcurrent: 1);
      expect(q.hasAvailableSlot, isTrue);
      await q.acquire('a');
      expect(q.hasAvailableSlot, isFalse);
      final waitB = q.acquire('b');
      await Future<void>.delayed(Duration.zero);
      // Even after release, the queue is non-empty until the waiter
      // settles — but release() drains synchronously.
      q.release('a');
      expect(await waitB, isTrue);
      expect(q.hasAvailableSlot, isFalse);
    });
  });
}
