import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/bangumi_api_error.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/cache/database/app_database.dart';

/// Queue operation kinds. Stored as text so the table stays readable and a
/// future kind cannot silently shift existing rows' meaning.
abstract final class BangumiSyncOperation {
  static const String status = 'status';
  static const String metadata = 'metadata';
  static const String delete = 'delete';

  /// Status *and* metadata in one POST, for a collection that does not exist on
  /// Bangumi yet. A status POST followed by a metadata PATCH would briefly
  /// publish the entry without its rating or comment, and the PATCH would 404 if
  /// the POST failed.
  static const String upsert = 'upsert';
}

/// A metadata field's intent, kept explicit so "leave unchanged" and "clear"
/// survive a round trip through storage.
///
/// Bangumi treats `tags: null` as "ignore" and `tags: []` as "delete every
/// tag"; encoding presence by key omission would make those two collapse.
class BangumiFieldUpdate<T> {
  const BangumiFieldUpdate.set(this.value) : isPresent = true;
  const BangumiFieldUpdate.unchanged() : value = null, isPresent = false;

  final T? value;
  final bool isPresent;

  Object? toJson() => isPresent ? {'set': value} : null;

  static BangumiFieldUpdate<T> fromJson<T>(Object? raw) {
    if (raw is! Map) return BangumiFieldUpdate<T>.unchanged();
    if (!raw.containsKey('set')) return BangumiFieldUpdate<T>.unchanged();
    final value = raw['set'];
    if (value == null) return BangumiFieldUpdate<T>.set(null);
    if (T == int) return BangumiFieldUpdate<T>.set((value as num).toInt() as T);
    if (T == String) return BangumiFieldUpdate<T>.set(value.toString() as T);
    if (T == bool) return BangumiFieldUpdate<T>.set(value as T);
    return BangumiFieldUpdate<T>.set(value as T);
  }
}

/// Metadata payload for a queued PATCH.
class BangumiMetadataPayload {
  const BangumiMetadataPayload({
    this.rate = const BangumiFieldUpdate.unchanged(),
    this.comment = const BangumiFieldUpdate.unchanged(),
    this.tags = const BangumiFieldUpdate.unchanged(),
    this.private = const BangumiFieldUpdate.unchanged(),
  });

  final BangumiFieldUpdate<int> rate;
  final BangumiFieldUpdate<String> comment;
  final BangumiFieldUpdate<List<String>> tags;
  final BangumiFieldUpdate<bool> private;

  bool get isEmpty =>
      !rate.isPresent &&
      !comment.isPresent &&
      !tags.isPresent &&
      !private.isPresent;

  Map<String, Object?> toJson() => {
    if (rate.isPresent) 'rate': rate.toJson(),
    if (comment.isPresent) 'comment': comment.toJson(),
    if (tags.isPresent) 'tags': tags.toJson(),
    if (private.isPresent) 'private': private.toJson(),
  };

  factory BangumiMetadataPayload.fromJson(Map<String, Object?> json) {
    final rawTags = json['tags'];
    return BangumiMetadataPayload(
      rate: BangumiFieldUpdate.fromJson<int>(json['rate']),
      comment: BangumiFieldUpdate.fromJson<String>(json['comment']),
      tags: switch (rawTags) {
        final Map<Object?, Object?> map when map.containsKey('set') =>
          BangumiFieldUpdate<List<String>>.set(
            (map['set'] as List?)
                ?.map((tag) => tag.toString())
                .toList(growable: false),
          ),
        _ => const BangumiFieldUpdate<List<String>>.unchanged(),
      },
      private: BangumiFieldUpdate.fromJson<bool>(json['private']),
    );
  }

  /// Later edits win per field; untouched fields keep the earlier intent.
  BangumiMetadataPayload mergedWith(BangumiMetadataPayload newer) =>
      BangumiMetadataPayload(
        rate: newer.rate.isPresent ? newer.rate : rate,
        comment: newer.comment.isPresent ? newer.comment : comment,
        tags: newer.tags.isPresent ? newer.tags : tags,
        private: newer.private.isPresent ? newer.private : private,
      );
}

/// Why a drain stopped, so the caller can tell "all sent" from "still pending".
enum BangumiSyncDrainOutcome { idle, completed, partial, unauthenticated }

class BangumiSyncDrainResult {
  const BangumiSyncDrainResult({
    required this.outcome,
    required this.sentCount,
    required this.pendingCount,
    this.conflictSubjectIds = const [],
  });

  final BangumiSyncDrainOutcome outcome;
  final int sentCount;
  final int pendingCount;

  /// Subjects whose queued write hit a 404 — the collection is gone on Bangumi
  /// and the user has to decide what happens next.
  final List<int> conflictSubjectIds;
}

/// Durable outbox for Bangumi collection writes.
///
/// Local state is applied immediately by the caller; this queue makes the
/// remote side eventually consistent across offline periods and restarts. Every
/// task is bound to the Bangumi account that created it, so a logout or account
/// switch can never replay one user's edits into another's collection.
class BangumiSyncQueue {
  BangumiSyncQueue({
    AppDatabase? database,
    BangumiCollectionsRepository? repository,
    Future<bool> Function()? ensureFreshToken,
  }) : _database = database,
       _repository = repository ?? BangumiCollectionsRepository(),
       _ensureFreshToken = ensureFreshToken;

  final AppDatabase? _database;
  final BangumiCollectionsRepository _repository;
  final Future<bool> Function()? _ensureFreshToken;

  AppDatabase get _db => _database ?? AppDatabase.instance;

  Future<BangumiSyncDrainResult>? _drainInFlight;

  /// Upper bound on exponential backoff. Long enough to stop hammering a failing
  /// server, short enough that a recovered connection is picked up in one sync.
  static const Duration maxBackoff = Duration(minutes: 15);

  /// Called by tests to make backoff deterministic.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  int get _nowMs => clock().millisecondsSinceEpoch;

  Future<void> enqueueStatus({
    required int accountId,
    required int subjectId,
    required int type,
  }) async {
    // Fold into a pending create instead of queueing a separate status write:
    // the collection does not exist on Bangumi yet.
    final pendingUpsert = await _taskFor(
      accountId,
      subjectId,
      BangumiSyncOperation.upsert,
    );
    if (pendingUpsert != null) {
      final payload = _decodePayload(pendingUpsert.payloadJson);
      await _enqueue(
        accountId: accountId,
        subjectId: subjectId,
        operation: BangumiSyncOperation.upsert,
        payload: {...payload, 'type': type},
      );
      return;
    }
    await _enqueue(
      accountId: accountId,
      subjectId: subjectId,
      operation: BangumiSyncOperation.status,
      payload: {'type': type},
    );
  }

  /// Queues creation of a collection that exists locally but not on Bangumi,
  /// sending status and metadata together.
  Future<void> enqueueUpsert({
    required int accountId,
    required int subjectId,
    required int type,
    required BangumiMetadataPayload payload,
  }) => _enqueue(
    accountId: accountId,
    subjectId: subjectId,
    operation: BangumiSyncOperation.upsert,
    payload: {'type': type, ...payload.toJson()},
  );

  Future<void> enqueueMetadata({
    required int accountId,
    required int subjectId,
    required BangumiMetadataPayload payload,
  }) async {
    if (payload.isEmpty) return;
    // As above: a PATCH would 404 while the create is still pending, so merge
    // the new field values into it.
    final pendingUpsert = await _taskFor(
      accountId,
      subjectId,
      BangumiSyncOperation.upsert,
    );
    if (pendingUpsert != null) {
      final existing = _decodePayload(pendingUpsert.payloadJson);
      final merged = BangumiMetadataPayload.fromJson(
        existing,
      ).mergedWith(payload);
      await _enqueue(
        accountId: accountId,
        subjectId: subjectId,
        operation: BangumiSyncOperation.upsert,
        payload: {
          if (existing['type'] != null) 'type': existing['type'],
          ...merged.toJson(),
        },
      );
      return;
    }
    await _enqueue(
      accountId: accountId,
      subjectId: subjectId,
      operation: BangumiSyncOperation.metadata,
      payload: payload.toJson(),
    );
  }

  /// Enqueues a delete and drops the subject's other pending writes — sending a
  /// status or metadata change for something we are about to delete is at best
  /// wasted work and at worst re-creates the collection.
  Future<void> enqueueDelete({
    required int accountId,
    required int subjectId,
  }) async {
    await (_db.delete(_db.dbBangumiSyncQueue)..where(
          (tbl) =>
              tbl.accountId.equals(accountId) &
              tbl.subjectId.equals(subjectId) &
              tbl.operation.isNotValue(BangumiSyncOperation.delete),
        ))
        .go();
    await _enqueue(
      accountId: accountId,
      subjectId: subjectId,
      operation: BangumiSyncOperation.delete,
      payload: const {},
    );
  }

  Future<void> _enqueue({
    required int accountId,
    required int subjectId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    // A pending delete means the user removed the collection and is now
    // re-adding or editing it; the delete must not outlive that decision.
    if (operation != BangumiSyncOperation.delete) {
      await (_db.delete(_db.dbBangumiSyncQueue)..where(
            (tbl) =>
                tbl.accountId.equals(accountId) &
                tbl.subjectId.equals(subjectId) &
                tbl.operation.equals(BangumiSyncOperation.delete),
          ))
          .go();
    }

    final existing = await _taskFor(accountId, subjectId, operation);
    final now = _nowMs;

    if (existing == null) {
      await _db.into(_db.dbBangumiSyncQueue).insert(
        DbBangumiSyncQueueCompanion.insert(
          accountId: accountId,
          subjectId: subjectId,
          operation: operation,
          payloadJson: jsonEncode(payload),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    // Collapse repeated edits to one task so a long offline session does not
    // replay a keystroke-by-keystroke history.
    final merged = operation == BangumiSyncOperation.metadata
        ? BangumiMetadataPayload.fromJson(
            _decodePayload(existing.payloadJson),
          ).mergedWith(BangumiMetadataPayload.fromJson(payload)).toJson()
        : payload;

    await (_db.update(_db.dbBangumiSyncQueue)
          ..where((tbl) => tbl.id.equals(existing.id)))
        .write(
          DbBangumiSyncQueueCompanion(
            payloadJson: Value(jsonEncode(merged)),
            // A fresh user edit deserves an immediate attempt even if the
            // previous one had backed off.
            attemptCount: const Value(0),
            nextAttemptAt: const Value(0),
            lastError: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  /// Number of queued tasks for [accountId].
  Future<int> pendingCount(int accountId) async {
    final count = _db.dbBangumiSyncQueue.id.count();
    final row =
        await (_db.selectOnly(_db.dbBangumiSyncQueue)
              ..addColumns([count])
              ..where(_db.dbBangumiSyncQueue.accountId.equals(accountId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<List<DbBangumiSyncQueueData>> pendingTasks(int accountId) =>
      (_db.select(_db.dbBangumiSyncQueue)
            ..where((tbl) => tbl.accountId.equals(accountId))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
          .get();

  /// Deletes queued work for every account except [accountId]; pass `null` on
  /// logout to clear everything.
  Future<void> clearTasksForOtherAccounts(int? accountId) =>
      (_db.delete(_db.dbBangumiSyncQueue)..where(
            (tbl) => accountId == null
                ? const Constant(true)
                : tbl.accountId.equals(accountId).not(),
          ))
          .go();

  /// Sends queued work for [accountId], oldest first.
  ///
  /// Single-flight: concurrent callers (startup, manual sync, a write) join the
  /// same run instead of racing to send the same task twice.
  Future<BangumiSyncDrainResult> drain({required int accountId}) {
    final existing = _drainInFlight;
    if (existing != null) return existing;
    final future = _drain(accountId);
    _drainInFlight = future;
    return future.whenComplete(() {
      if (identical(_drainInFlight, future)) _drainInFlight = null;
    });
  }

  Future<BangumiSyncDrainResult> _drain(int accountId) async {
    final tasks = await pendingTasks(accountId);
    if (tasks.isEmpty) {
      return const BangumiSyncDrainResult(
        outcome: BangumiSyncDrainOutcome.idle,
        sentCount: 0,
        pendingCount: 0,
      );
    }

    var sent = 0;
    var refreshedOnce = false;
    final conflicts = <int>[];

    for (final task in tasks) {
      if (task.nextAttemptAt > _nowMs) continue;

      var attempted = false;
      while (true) {
        try {
          await _send(task);
          await (_db.delete(_db.dbBangumiSyncQueue)
                ..where((tbl) => tbl.id.equals(task.id)))
              .go();
          sent++;
          break;
        } catch (error) {
          final apiError = BangumiApiError.tryParse(error);

          // One refresh-and-retry for the whole drain: if the token is still
          // rejected afterwards, every remaining task would fail the same way.
          if (apiError != null &&
              apiError.isUnauthorized &&
              !attempted &&
              !refreshedOnce) {
            attempted = true;
            refreshedOnce = true;
            if (await _refreshToken()) continue;
          }

          if (apiError != null && apiError.isUnauthorized) {
            await _recordFailure(task, error, retryAfter: null);
            return BangumiSyncDrainResult(
              outcome: BangumiSyncDrainOutcome.unauthenticated,
              sentCount: sent,
              pendingCount: await pendingCount(accountId),
              conflictSubjectIds: conflicts,
            );
          }

          if (apiError != null && apiError.isNotFound) {
            // The collection is gone upstream. Re-creating it silently would
            // resurrect something the user may have deleted on purpose.
            conflicts.add(task.subjectId);
            await _recordFailure(task, error, retryAfter: null);
            break;
          }

          // Honor Retry-After when the server sent one; otherwise fall through
          // to normal backoff rather than inventing a delay.
          final retryAfterSeconds = apiError?.isRateLimited == true
              ? apiError?.retryAfterSeconds
              : null;
          await _recordFailure(
            task,
            error,
            retryAfter: retryAfterSeconds == null
                ? null
                : Duration(seconds: retryAfterSeconds),
          );
          break;
        }
      }
    }

    final pending = await pendingCount(accountId);
    return BangumiSyncDrainResult(
      outcome: pending == 0
          ? BangumiSyncDrainOutcome.completed
          : BangumiSyncDrainOutcome.partial,
      sentCount: sent,
      pendingCount: pending,
      conflictSubjectIds: conflicts,
    );
  }

  Future<void> _send(DbBangumiSyncQueueData task) async {
    final payload = _decodePayload(task.payloadJson);
    switch (task.operation) {
      case BangumiSyncOperation.status:
        final type = (payload['type'] as num?)?.toInt();
        if (type == null) {
          throw StateError('queued status task ${task.id} has no type');
        }
        await _repository.setStatus(subjectId: task.subjectId, type: type);
      case BangumiSyncOperation.upsert:
        final type = (payload['type'] as num?)?.toInt();
        if (type == null) {
          throw StateError('queued upsert task ${task.id} has no type');
        }
        final metadata = BangumiMetadataPayload.fromJson(payload);
        await _repository.upsertWithMetadata(
          subjectId: task.subjectId,
          type: type,
          rate: metadata.rate.value,
          comment: metadata.comment.value,
          tags: metadata.tags.value,
          private: metadata.private.value,
        );
      case BangumiSyncOperation.metadata:
        final metadata = BangumiMetadataPayload.fromJson(payload);
        await _repository.patchMetadata(
          subjectId: task.subjectId,
          rate: metadata.rate.value,
          comment: metadata.comment.value,
          tags: metadata.tags.value,
          private: metadata.private.value,
        );
      case BangumiSyncOperation.delete:
        await _repository.delete(task.subjectId);
      default:
        // An unknown kind means a newer build wrote this row. Retrying it
        // forever is pointless, so surface it as a failure and let backoff
        // keep it out of the way.
        throw StateError('unknown queue operation ${task.operation}');
    }
  }

  Future<bool> _refreshToken() async {
    final refresh = _ensureFreshToken;
    if (refresh == null) return false;
    try {
      return await refresh();
    } catch (error) {
      debugPrint('Bangumi queue token refresh failed: $error');
      return false;
    }
  }

  Future<void> _recordFailure(
    DbBangumiSyncQueueData task,
    Object error, {
    Duration? retryAfter,
  }) async {
    final attempts = task.attemptCount + 1;
    final delay = retryAfter ?? _backoffFor(attempts);
    final apiError = BangumiApiError.tryParse(error);
    // Never log the payload or a bearer: operation, target, and status only.
    final summary = apiError == null
        ? 'network'
        : 'status=${apiError.status}'
              '${apiError.upstreamCode == null ? '' : ' code=${apiError.upstreamCode}'}';

    await (_db.update(_db.dbBangumiSyncQueue)
          ..where((tbl) => tbl.id.equals(task.id)))
        .write(
          DbBangumiSyncQueueCompanion(
            attemptCount: Value(attempts),
            nextAttemptAt: Value(_nowMs + delay.inMilliseconds),
            lastError: Value(summary),
            updatedAt: Value(_nowMs),
          ),
        );
    debugPrint(
      'Bangumi sync queue: ${task.operation} subject=${task.subjectId} '
      'failed ($summary), retry in ${delay.inSeconds}s',
    );
  }

  static Duration _backoffFor(int attempts) {
    final seconds = 15 * (1 << (attempts - 1).clamp(0, 10));
    final capped = seconds > maxBackoff.inSeconds
        ? maxBackoff.inSeconds
        : seconds;
    return Duration(seconds: capped);
  }

  Future<DbBangumiSyncQueueData?> _taskFor(
    int accountId,
    int subjectId,
    String operation,
  ) => (_db.select(_db.dbBangumiSyncQueue)..where(
          (tbl) =>
              tbl.accountId.equals(accountId) &
              tbl.subjectId.equals(subjectId) &
              tbl.operation.equals(operation),
        ))
      .getSingleOrNull();

  static Map<String, Object?> _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
