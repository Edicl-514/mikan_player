// Offline outbox behavior: task coalescing, account binding, and the retry
// policy (401 refresh-once, 429 Retry-After, bounded backoff).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_api_error.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/bangumi_sync_queue.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';

import '../support/drift_in_memory.dart';
import '../support/fake_bangumi_collections_backend.dart';

/// Mirrors how Rust reports a failure: `bangumi_api_error:{json}` embedded in an
/// anyhow chain. Tests must go through this envelope rather than throwing
/// [BangumiApiError] directly, so the parsing contract is exercised too.
Object rustApiError(int status, {int? retryAfterSeconds, String? code}) {
  final payload = <String, Object?>{
    'operation': 'bangumi.collection.update',
    'status': status,
    'upstream_code': code,
    'retry_after_seconds': retryAfterSeconds,
    'message': 'upstream said no',
  };
  return Exception(
    'request failed: bangumi_api_error:'
    '${jsonEncode(payload)}: while sending request',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const account = 42;
  const otherAccount = 99;

  late AppDatabase db;
  late FakeBangumiCollectionsBackend backend;
  late BangumiSyncQueue queue;
  late DateTime now;

  BangumiSyncQueue buildQueue({Future<bool> Function()? ensureFreshToken}) {
    final q = BangumiSyncQueue(
      database: db,
      repository: BangumiCollectionsRepository(
        backend: backend,
        ensureAuthenticated: () async => true,
        apiHostResolver: () async => 'api.bgm.tv',
      ),
      ensureFreshToken: ensureFreshToken,
    );
    q.clock = () => now;
    return q;
  }

  setUp(() {
    now = DateTime.utc(2026, 7, 28, 12);
    db = AppDatabase.forTesting(driftInMemoryExecutor());
    backend = FakeBangumiCollectionsBackend();
    queue = buildQueue();
  });

  tearDown(() async {
    await db.close();
  });

  group('field update encoding', () {
    test('distinguishes unchanged from an explicit clear', () {
      const unchanged = BangumiMetadataPayload();
      expect(unchanged.isEmpty, isTrue);
      expect(unchanged.toJson(), isEmpty);

      const cleared = BangumiMetadataPayload(
        tags: BangumiFieldUpdate<List<String>>.set(<String>[]),
      );
      expect(cleared.isEmpty, isFalse);

      // The distinction has to survive storage: an omitted key and a key set to
      // an empty list mean "keep tags" vs "delete all tags".
      final roundTripped = BangumiMetadataPayload.fromJson(cleared.toJson());
      expect(roundTripped.tags.isPresent, isTrue);
      expect(roundTripped.tags.value, isEmpty);

      final emptyRoundTrip = BangumiMetadataPayload.fromJson(
        unchanged.toJson(),
      );
      expect(emptyRoundTrip.tags.isPresent, isFalse);
      expect(emptyRoundTrip.tags.value, isNull);
    });

    test('preserves rate 0 and empty comment as real values', () {
      const payload = BangumiMetadataPayload(
        rate: BangumiFieldUpdate<int>.set(0),
        comment: BangumiFieldUpdate<String>.set(''),
      );
      final decoded = BangumiMetadataPayload.fromJson(payload.toJson());
      expect(decoded.rate.isPresent, isTrue);
      expect(decoded.rate.value, 0);
      expect(decoded.comment.isPresent, isTrue);
      expect(decoded.comment.value, '');
    });

    test('later edits win per field and untouched fields survive', () {
      const first = BangumiMetadataPayload(
        rate: BangumiFieldUpdate<int>.set(6),
        comment: BangumiFieldUpdate<String>.set('first'),
      );
      const second = BangumiMetadataPayload(
        comment: BangumiFieldUpdate<String>.set('second'),
        private: BangumiFieldUpdate<bool>.set(true),
      );
      final merged = first.mergedWith(second);
      expect(merged.rate.value, 6);
      expect(merged.comment.value, 'second');
      expect(merged.private.value, isTrue);
      expect(merged.tags.isPresent, isFalse);
    });
  });

  group('enqueue and coalescing', () {
    test('repeated metadata edits collapse into one task', () async {
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(5),
        ),
      );
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(9),
          comment: BangumiFieldUpdate<String>.set('done'),
        ),
      );

      final tasks = await queue.pendingTasks(account);
      expect(tasks, hasLength(1));
      final payload = BangumiMetadataPayload.fromJson(
        Map<String, Object?>.from(
          (tasks.single.payloadJson.isEmpty
              ? <String, Object?>{}
              : _decode(tasks.single.payloadJson)),
        ),
      );
      expect(payload.rate.value, 9);
      expect(payload.comment.value, 'done');
    });

    test('an empty metadata payload is not queued at all', () async {
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(),
      );
      expect(await queue.pendingCount(account), 0);
    });

    test('status and metadata for one subject stay separate tasks', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 3);
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(8),
        ),
      );
      expect(await queue.pendingCount(account), 2);
    });

    test('a delete supersedes the subject other pending writes', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 3);
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(8),
        ),
      );
      await queue.enqueueDelete(accountId: account, subjectId: 7);

      final tasks = await queue.pendingTasks(account);
      expect(tasks, hasLength(1));
      expect(tasks.single.operation, BangumiSyncOperation.delete);
    });

    test('re-adding after a queued delete drops the delete', () async {
      await queue.enqueueDelete(accountId: account, subjectId: 7);
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 1);

      final tasks = await queue.pendingTasks(account);
      expect(tasks, hasLength(1));
      expect(tasks.single.operation, BangumiSyncOperation.status);
    });

    test('a pending create absorbs a later status edit', () async {
      await queue.enqueueUpsert(
        accountId: account,
        subjectId: 7,
        type: 1,
        payload: const BangumiMetadataPayload(rate: BangumiFieldUpdate.set(8)),
      );
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 3);

      // A separate status task would be fine, but a metadata PATCH would 404
      // while the collection still does not exist upstream — so everything has
      // to stay in the single create.
      final tasks = await queue.pendingTasks(account);
      expect(tasks, hasLength(1));
      expect(tasks.single.operation, BangumiSyncOperation.upsert);

      await queue.drain(accountId: account);
      expect(backend.upserts.single.type, 3);
      expect(backend.upserts.single.rate, 8);
      expect(backend.metadataPatches, isEmpty);
      expect(backend.statusUpdates, isEmpty);
    });

    test('a pending create absorbs a later metadata edit', () async {
      await queue.enqueueUpsert(
        accountId: account,
        subjectId: 7,
        type: 2,
        payload: const BangumiMetadataPayload(rate: BangumiFieldUpdate.set(5)),
      );
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          comment: BangumiFieldUpdate.set('later'),
          tags: BangumiFieldUpdate.set(['sci-fi']),
        ),
      );

      expect(await queue.pendingTasks(account), hasLength(1));

      await queue.drain(accountId: account);
      final upsert = backend.upserts.single;
      expect(upsert.type, 2);
      expect(upsert.rate, 5);
      expect(upsert.comment, 'later');
      expect(upsert.tags, ['sci-fi']);
      expect(backend.metadataPatches, isEmpty);
    });

    test('a fresh edit clears the previous backoff', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 3);
      backend.failWith = (_, _) => Exception('offline');
      await queue.drain(accountId: account);
      expect(
        (await queue.pendingTasks(account)).single.nextAttemptAt,
        greaterThan(0),
      );

      backend.failWith = null;
      await queue.enqueueStatus(accountId: account, subjectId: 7, type: 4);
      final task = (await queue.pendingTasks(account)).single;
      expect(task.attemptCount, 0);
      expect(task.nextAttemptAt, 0);
    });
  });

  group('account isolation', () {
    test('drain only sends tasks belonging to the account', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueStatus(accountId: otherAccount, subjectId: 2, type: 4);

      final result = await queue.drain(accountId: account);

      expect(result.sentCount, 1);
      expect(backend.statusUpdates, [(1, 3)]);
      // The other account's task is untouched, not sent under this session.
      expect(await queue.pendingCount(otherAccount), 1);
    });

    test('clearTasksForOtherAccounts keeps only the active account', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueStatus(accountId: otherAccount, subjectId: 2, type: 4);

      await queue.clearTasksForOtherAccounts(account);

      expect(await queue.pendingCount(account), 1);
      expect(await queue.pendingCount(otherAccount), 0);
    });

    test('logout clears every queued task', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueStatus(accountId: otherAccount, subjectId: 2, type: 4);

      await queue.clearTasksForOtherAccounts(null);

      expect(await queue.pendingCount(account), 0);
      expect(await queue.pendingCount(otherAccount), 0);
    });
  });

  group('drain', () {
    test('an empty queue is idle', () async {
      final result = await queue.drain(accountId: account);
      expect(result.outcome, BangumiSyncDrainOutcome.idle);
      expect(result.sentCount, 0);
    });

    test('sends each operation kind through the right call', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 2,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(0),
          tags: BangumiFieldUpdate<List<String>>.set(<String>[]),
        ),
      );
      await queue.enqueueDelete(accountId: account, subjectId: 3);

      final result = await queue.drain(accountId: account);

      expect(result.outcome, BangumiSyncDrainOutcome.completed);
      expect(result.sentCount, 3);
      expect(backend.statusUpdates, [(1, 3)]);
      expect(backend.deletes, [3]);
      final patch = backend.metadataPatches.single;
      expect(patch.subjectId, 2);
      expect(patch.rate, 0);
      expect(patch.tags, isEmpty);
      // Fields the user did not touch must not be sent at all.
      expect(patch.comment, isNull);
      expect(patch.private, isNull);
      expect(await queue.pendingCount(account), 0);
    });

    test('a network failure keeps the task and backs off', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      backend.failWith = (_, _) => Exception('connection reset');

      final result = await queue.drain(accountId: account);

      expect(result.outcome, BangumiSyncDrainOutcome.partial);
      expect(result.sentCount, 0);
      expect(result.pendingCount, 1);
      final task = (await queue.pendingTasks(account)).single;
      expect(task.attemptCount, 1);
      expect(task.nextAttemptAt, greaterThan(now.millisecondsSinceEpoch));
      // Only classification is stored, never the payload or a token.
      expect(task.lastError, 'network');
    });

    test('backoff grows and is capped', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      backend.failWith = (_, _) => Exception('offline');

      var previous = 0;
      for (var attempt = 0; attempt < 12; attempt++) {
        await queue.drain(accountId: account);
        final task = (await queue.pendingTasks(account)).single;
        final delay = task.nextAttemptAt - now.millisecondsSinceEpoch;
        expect(
          delay,
          lessThanOrEqualTo(BangumiSyncQueue.maxBackoff.inMilliseconds),
        );
        expect(delay, greaterThanOrEqualTo(previous == 0 ? 1 : 0));
        previous = delay;
        // Move past the backoff so the next drain actually retries.
        now = now.add(BangumiSyncQueue.maxBackoff * 2);
      }
      expect(previous, BangumiSyncQueue.maxBackoff.inMilliseconds);
    });

    test('a task still in backoff is skipped without a call', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      backend.failWith = (_, _) => Exception('offline');
      await queue.drain(accountId: account);

      backend.failWith = null;
      final result = await queue.drain(accountId: account);

      expect(result.sentCount, 0);
      expect(backend.statusUpdates, isEmpty);

      // Once the window passes, the same task goes out.
      now = now.add(const Duration(minutes: 30));
      final retry = await queue.drain(accountId: account);
      expect(retry.sentCount, 1);
      expect(backend.statusUpdates, [(1, 3)]);
    });

    test('429 honors Retry-After instead of the backoff curve', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      backend.failWith = (_, _) => rustApiError(429, retryAfterSeconds: 120);

      await queue.drain(accountId: account);

      final task = (await queue.pendingTasks(account)).single;
      expect(
        task.nextAttemptAt - now.millisecondsSinceEpoch,
        const Duration(seconds: 120).inMilliseconds,
      );
      expect(task.lastError, 'status=429');
    });

    test('429 without Retry-After falls back to backoff', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      backend.failWith = (_, _) => rustApiError(429);

      await queue.drain(accountId: account);

      final task = (await queue.pendingTasks(account)).single;
      expect(task.nextAttemptAt, greaterThan(now.millisecondsSinceEpoch));
    });

    test('401 refreshes the token once and retries the same task', () async {
      var refreshCalls = 0;
      var failures = 0;
      backend.failWith = (_, _) {
        if (failures++ == 0) return rustApiError(401);
        return null;
      };
      queue = buildQueue(
        ensureFreshToken: () async {
          refreshCalls++;
          return true;
        },
      );
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);

      final result = await queue.drain(accountId: account);

      expect(refreshCalls, 1);
      expect(result.sentCount, 1);
      expect(backend.statusUpdates, [(1, 3)]);
      expect(await queue.pendingCount(account), 0);
    });

    test('a persistent 401 stops the drain and keeps the work', () async {
      backend.failWith = (_, _) => rustApiError(401);
      queue = buildQueue(ensureFreshToken: () async => true);
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueStatus(accountId: account, subjectId: 2, type: 4);

      final result = await queue.drain(accountId: account);

      expect(result.outcome, BangumiSyncDrainOutcome.unauthenticated);
      expect(result.sentCount, 0);
      // Stopping early matters: every later task would fail the same way, and
      // hammering a rejected token risks the account.
      expect(await queue.pendingCount(account), 2);
    });

    test('a failed refresh does not retry with the old token', () async {
      var sendAttempts = 0;
      backend.failWith = (_, _) {
        sendAttempts++;
        return rustApiError(401);
      };
      queue = buildQueue(ensureFreshToken: () async => false);
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);

      final result = await queue.drain(accountId: account);

      expect(sendAttempts, 1);
      expect(result.outcome, BangumiSyncDrainOutcome.unauthenticated);
    });

    test('404 surfaces the subject instead of re-creating it', () async {
      await queue.enqueueMetadata(
        accountId: account,
        subjectId: 7,
        payload: const BangumiMetadataPayload(
          rate: BangumiFieldUpdate<int>.set(8),
        ),
      );
      backend.failWith = (_, _) => rustApiError(404);

      final result = await queue.drain(accountId: account);

      expect(result.conflictSubjectIds, [7]);
      expect(result.sentCount, 0);
      // No status POST was attempted: recreating a collection the user may have
      // deleted on purpose is not the queue's call.
      expect(backend.statusUpdates, isEmpty);
      expect(backend.upserts, isEmpty);
    });

    test('a delete 404 is treated as idempotent success', () async {
      await queue.enqueueDelete(accountId: account, subjectId: 7);
      backend.failWith = (operation, _) =>
          operation == FakeBackendOperation.delete ? rustApiError(404) : null;

      final result = await queue.drain(accountId: account);

      expect(result.outcome, BangumiSyncDrainOutcome.completed);
      expect(result.pendingCount, 0);
      expect(result.conflictSubjectIds, isEmpty);
      expect(result.settledSubjectIds, [7]);
    });

    test('one failing task does not block the rest', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      await queue.enqueueStatus(accountId: account, subjectId: 2, type: 4);
      backend.failWith = (_, subjectId) =>
          subjectId == 1 ? Exception('offline') : null;

      final result = await queue.drain(accountId: account);

      expect(result.sentCount, 1);
      expect(backend.statusUpdates, [(2, 4)]);
      expect(result.pendingCount, 1);
    });

    test('concurrent drains join one run', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);

      final results = await Future.wait([
        queue.drain(accountId: account),
        queue.drain(accountId: account),
      ]);

      // Both callers observe the same run; the task is sent exactly once.
      expect(backend.statusUpdates, [(1, 3)]);
      expect(results.first.sentCount, results.last.sentCount);
    });

    test('a newer edit arriving during send is drained, not deleted', () async {
      final requestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      var calls = 0;
      backend.beforeCall = (operation, _) async {
        if (operation != FakeBackendOperation.setStatus || calls++ != 0) return;
        requestStarted.complete();
        await releaseFirstRequest.future;
      };
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);

      final drain = queue.drain(accountId: account);
      await requestStarted.future;
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 4);
      releaseFirstRequest.complete();
      final result = await drain;

      expect(backend.statusUpdates, [(1, 3), (1, 4)]);
      expect(result.pendingCount, 0);
      expect(result.settledSubjectIds, [1]);
    });

    test('queue instances over one database share a drain', () async {
      final requestStarted = Completer<void>();
      final releaseRequest = Completer<void>();
      backend.beforeCall = (operation, _) async {
        if (operation != FakeBackendOperation.setStatus ||
            requestStarted.isCompleted) {
          return;
        }
        requestStarted.complete();
        await releaseRequest.future;
      };
      await queue.enqueueStatus(accountId: account, subjectId: 1, type: 3);
      final otherQueue = buildQueue();

      final first = queue.drain(accountId: account);
      await requestStarted.future;
      final second = otherQueue.drain(accountId: account);
      releaseRequest.complete();
      await Future.wait([first, second]);

      expect(backend.statusUpdates, [(1, 3)]);
    });

    test('queued work survives a new queue over the same database', () async {
      await queue.enqueueStatus(accountId: account, subjectId: 5, type: 2);

      final restarted = buildQueue();
      final result = await restarted.drain(accountId: account);

      expect(result.sentCount, 1);
      expect(backend.statusUpdates, [(5, 2)]);
    });
  });
}

/// Reads a stored payload without reaching into the queue's private decoder, so
/// the test asserts on what actually landed in the column.
Map<String, Object?> _decode(String raw) =>
    Map<String, Object?>.from(jsonDecode(raw) as Map);
