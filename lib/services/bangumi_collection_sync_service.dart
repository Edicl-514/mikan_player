import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_auth_manager.dart';
import 'package:mikan_player/services/bangumi_collection_merge.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/services/bangumi_sync_queue.dart';
import 'package:mikan_player/services/favorites_manager.dart';

/// One subject that needs the user to decide, with the field-level detail of
/// what differs.
class BangumiCollectionConflict {
  const BangumiCollectionConflict({
    required this.local,
    required this.bangumi,
    required this.plan,
  });

  final LocalFavorite local;

  /// The remote entry. Absent when Bangumi no longer has the collection (see
  /// [isRemoteDeleted]).
  final BangumiUserCollection? bangumi;

  final SubjectMergePlan plan;

  int get subjectId => plan.subjectId;

  /// Only the fields changed on both sides. Fields that merged automatically are
  /// deliberately not surfaced — showing them would bury the real decision.
  List<BangumiCollectionFieldConflict> get fields => plan.conflicts;

  /// The collection was synced before under this account and is now gone from
  /// Bangumi. Re-uploading or deleting locally are both defensible, so the user
  /// picks.
  bool get isRemoteDeleted =>
      plan.kind == BangumiCollectionMergeKind.remoteDeleted;
}

/// How a [BangumiCollectionConflict] should be settled.
class BangumiCollectionResolution {
  const BangumiCollectionResolution({
    this.fields = const {},
    this.remoteDeleted,
  });

  /// Chosen side per conflicting field.
  final Map<BangumiCollectionField, MergeSide> fields;

  /// For a [BangumiCollectionConflict.isRemoteDeleted] entry: `local` re-uploads
  /// it, `remote` accepts the deletion and removes it locally.
  final MergeSide? remoteDeleted;
}

/// Legacy whole-entry choice, kept so existing call sites and tests continue to
/// work. Applies to every conflicting field of a subject at once.
enum BangumiCollectionConflictChoice { local, bangumi }

class BangumiCollectionSyncResult {
  const BangumiCollectionSyncResult({
    required this.favorites,
    required this.conflicts,
    required this.uploadedCount,
    required this.downloadedCount,
    this.pendingCount = 0,
  });

  final List<LocalFavorite> favorites;
  final List<BangumiCollectionConflict> conflicts;

  /// Subjects queued for upload this run (the send itself may still be pending).
  final int uploadedCount;
  final int downloadedCount;

  /// Queued writes not yet accepted by Bangumi, so the UI can say "still
  /// syncing" rather than implying everything landed.
  final int pendingCount;
}

/// Reconciles the local collection with the authenticated Bangumi collection,
/// field by field.
///
/// Every write goes through [BangumiSyncQueue], so the local database is the
/// source of truth for the UI and the network catches up when it can. Automatic
/// merges only happen where exactly one side changed a field relative to the
/// last synced baseline; anything else is handed back as a conflict rather than
/// resolved by a rule the user did not choose.
class BangumiCollectionSyncService {
  BangumiCollectionSyncService({
    FavoritesManager? favoritesManager,
    BangumiCollectionsRepository? repository,
    BangumiSyncQueue? queue,
    BangumiAuthManager? authManager,
    int? accountId,
  }) : _favoritesManager = favoritesManager ?? FavoritesManager(),
       _repository = repository ?? BangumiCollectionsRepository(),
       _authManager = authManager,
       _explicitAccountId = accountId {
    _queue =
        queue ??
        BangumiSyncQueue(
          repository: _repository,
          ensureFreshToken: () =>
              (_authManager ?? BangumiAuthManager()).ensureFreshToken(),
        );
  }

  final FavoritesManager _favoritesManager;
  final BangumiCollectionsRepository _repository;
  final BangumiAuthManager? _authManager;
  final int? _explicitAccountId;
  late final BangumiSyncQueue _queue;

  BangumiSyncQueue get queue => _queue;

  /// Bangumi user id that owns the current session. Sync is account-scoped: a
  /// baseline or queued task from another account must never be applied here.
  int get accountId =>
      _explicitAccountId ?? (_authManager ?? BangumiAuthManager()).userId ?? 0;

  Future<BangumiCollectionSyncResult> synchronize(String username) async {
    await _favoritesManager.init();
    final account = accountId;
    if (account <= 0) {
      throw StateError('Bangumi account id is unavailable');
    }

    // Account-owned rows from another user must not become local-only uploads
    // for this account. Queued work remains account-scoped and is preserved so
    // it can resume if that account signs in again.
    await _favoritesManager.removeFavoritesForOtherAccounts(account);

    // Send pending local writes first. Otherwise this run would read a remote
    // state that predates them and treat our own un-sent edits as remote
    // changes, reverting them.
    final beforeInitialDrain = await _favoriteSnapshots();
    final initialDrain = await _queue.drain(accountId: account);
    await _confirmSettled(initialDrain, account, beforeInitialDrain);

    final results = await Future.wait<Object>([
      _favoritesManager.getAllFavorites(),
      _repository.fetchMine(username),
    ]);
    final local = results[0] as List<LocalFavorite>;
    final remote = (results[1] as List<BangumiUserCollection>)
        .where((item) => LocalFavoriteType.isValid(item.type))
        .toList(growable: false);

    final localById = {for (final item in local) item.bangumiId: item};
    final remoteById = {for (final item in remote) item.subjectId: item};

    final conflicts = <BangumiCollectionConflict>[];
    var uploadedCount = 0;
    var downloadedCount = 0;

    for (final subjectId in {...localById.keys, ...remoteById.keys}) {
      final localItem = localById[subjectId];
      final remoteItem = remoteById[subjectId];
      final plan = mergeCollectionSubject(
        subjectId: subjectId,
        local: localItem == null
            ? null
            : BangumiCollectionSnapshot.fromLocal(localItem),
        remote: remoteItem == null
            ? null
            : BangumiCollectionSnapshot.fromRemote(remoteItem),
        baseline: localItem == null
            ? BangumiCollectionSnapshot.unknown
            : BangumiCollectionSnapshot.fromBaseline(
                localItem,
                accountId: account,
              ),
        hadBaseline: localItem?.hasBaselineFor(account) ?? false,
      );

      if (plan.kind == BangumiCollectionMergeKind.remoteDeleted ||
          plan.hasConflicts) {
        conflicts.add(
          BangumiCollectionConflict(
            local: localItem!,
            bangumi: remoteItem,
            plan: plan,
          ),
        );
        continue;
      }

      switch (plan.kind) {
        case BangumiCollectionMergeKind.remoteOnly:
          await _writeRemoteToLocal(remoteItem!, account);
          downloadedCount++;
        case BangumiCollectionMergeKind.localOnly:
          await _queueUpload(localItem!, plan, account, create: true);
          uploadedCount++;
        case BangumiCollectionMergeKind.fieldMerge:
          if (plan.needsLocalWrite) {
            await _applyPlanLocally(localItem!, remoteItem!, plan, account);
          }
          if (plan.needsUpload) {
            await _queueUpload(localItem!, plan, account, create: false);
            uploadedCount++;
          } else if (!plan.needsLocalWrite) {
            // Both sides already agree; record that so the next run can tell a
            // future edit apart from this settled state.
            await _favoritesManager.confirmBaseline(
              bangumiId: subjectId,
              accountId: account,
              remoteUpdatedAt: remoteItem?.date,
            );
          }
        case BangumiCollectionMergeKind.remoteDeleted:
          break; // handled above
      }
    }

    final beforeFinalDrain = await _favoriteSnapshots();
    final drain = await _queue.drain(accountId: account);
    await _confirmSettled(drain, account, beforeFinalDrain);

    return BangumiCollectionSyncResult(
      favorites: await _favoritesManager.getAllFavorites(),
      conflicts: conflicts,
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      pendingCount: drain.pendingCount,
    );
  }

  /// Applies field-level [resolutions], keyed by subject id.
  Future<List<LocalFavorite>> resolveFieldConflicts(
    List<BangumiCollectionConflict> conflicts,
    Map<int, BangumiCollectionResolution> resolutions,
  ) async {
    final account = accountId;
    for (final conflict in conflicts) {
      final resolution = resolutions[conflict.subjectId];
      if (resolution == null) continue;

      if (conflict.isRemoteDeleted) {
        await _resolveRemoteDeleted(conflict, resolution, account);
        continue;
      }

      final remote = conflict.bangumi;
      if (remote == null) continue;

      final merged = conflict.plan.resolveValues(resolution.fields);
      await _favoritesManager.applyMergedValues(
        bangumiId: conflict.subjectId,
        type: merged.type ?? conflict.local.type,
        rate: merged.rate,
        comment: merged.comment,
        tags: merged.tags,
        private: merged.private,
      );

      // Upload the fields the user kept from the local side, and only when the
      // result actually differs from what Bangumi holds.
      final uploadFields = _fieldsToUpload(conflict.plan, resolution.fields);
      final remoteSnapshot = BangumiCollectionSnapshot.fromRemote(remote);
      if (uploadFields.isNotEmpty && _differs(merged, remoteSnapshot)) {
        await _queueUploadValues(
          subjectId: conflict.subjectId,
          account: account,
          values: merged,
          uploadFields: uploadFields,
          fallbackType: conflict.local.type,
          create: false,
        );
      } else {
        await _favoritesManager.confirmBaseline(
          bangumiId: conflict.subjectId,
          accountId: account,
          remoteUpdatedAt: remote.date,
        );
      }
    }

    final beforeDrain = await _favoriteSnapshots();
    final drain = await _queue.drain(accountId: account);
    await _confirmSettled(drain, account, beforeDrain);
    return _favoritesManager.getAllFavorites();
  }

  /// Whole-entry resolution kept for existing callers: applies one side to every
  /// conflicting field of a subject.
  Future<List<LocalFavorite>> resolveConflicts(
    List<BangumiCollectionConflict> conflicts,
    Map<int, BangumiCollectionConflictChoice> choices,
  ) {
    final resolutions = <int, BangumiCollectionResolution>{};
    for (final conflict in conflicts) {
      final choice = choices[conflict.subjectId];
      if (choice == null) continue;
      final side = choice == BangumiCollectionConflictChoice.local
          ? MergeSide.local
          : MergeSide.remote;
      resolutions[conflict.subjectId] = BangumiCollectionResolution(
        fields: {
          for (final field in BangumiCollectionField.values) field: side,
        },
        remoteDeleted: side,
      );
    }
    return resolveFieldConflicts(conflicts, resolutions);
  }

  /// Removes a collection locally and queues the remote delete.
  ///
  /// Local-first so the action works offline; the queue guarantees Bangumi
  /// catches up, and a queued delete supersedes that subject's pending writes.
  Future<void> deleteFavorite(int subjectId) async {
    await _favoritesManager.init();
    final account = accountId;
    await _favoritesManager.removeFavorite(subjectId);
    await _queue.enqueueDelete(accountId: account, subjectId: subjectId);
    await _queue.drain(accountId: account);
  }

  Future<void> _resolveRemoteDeleted(
    BangumiCollectionConflict conflict,
    BangumiCollectionResolution resolution,
    int account,
  ) async {
    switch (resolution.remoteDeleted) {
      case MergeSide.local:
        // Re-create the entry from the local row. The plan resolved nothing
        // (that was the user's decision to make), so every field the app knows
        // has to be part of the create.
        await _queueUploadValues(
          subjectId: conflict.subjectId,
          account: account,
          values: BangumiCollectionSnapshot.fromLocal(conflict.local),
          uploadFields: BangumiCollectionField.values.toSet(),
          fallbackType: conflict.local.type,
          create: true,
        );
      case MergeSide.remote:
        await _favoritesManager.removeFavorite(conflict.subjectId);
      case null:
        break;
    }
  }

  Future<void> _applyPlanLocally(
    LocalFavorite localItem,
    BangumiUserCollection remoteItem,
    SubjectMergePlan plan,
    int account,
  ) async {
    final merged = plan.resolveValues();
    await _favoritesManager.applyMergedValues(
      bangumiId: plan.subjectId,
      type: merged.type ?? localItem.type,
      rate: merged.rate,
      comment: merged.comment,
      tags: merged.tags,
      private: merged.private,
    );
    // When nothing needs uploading the merged values now match Bangumi, so this
    // is a legitimate baseline.
    if (!plan.needsUpload) {
      await _favoritesManager.confirmBaseline(
        bangumiId: plan.subjectId,
        accountId: account,
        remoteUpdatedAt: remoteItem.date,
      );
    }
  }

  Future<void> _queueUpload(
    LocalFavorite localItem,
    SubjectMergePlan plan,
    int account, {
    required bool create,
    Map<BangumiCollectionField, MergeSide> choices = const {},
  }) => _queueUploadValues(
    subjectId: plan.subjectId,
    account: account,
    values: plan.resolveValues(choices),
    uploadFields: _fieldsToUpload(plan, choices),
    fallbackType: localItem.type,
    create: create,
  );

  /// Fields whose resolved value has to reach Bangumi.
  ///
  /// Only fields that resolved to the local side qualify. Sending a field that
  /// resolved to *remote* would at best be a no-op and at worst destructive: an
  /// untouched tag list resolves to remote, and uploading it as `[]` would
  /// delete every tag the user has.
  Set<BangumiCollectionField> _fieldsToUpload(
    SubjectMergePlan plan,
    Map<BangumiCollectionField, MergeSide> choices,
  ) {
    final fields = <BangumiCollectionField>{};
    for (final entry in {...plan.resolved, ...choices}.entries) {
      if (entry.value == MergeSide.local) fields.add(entry.key);
    }
    return fields;
  }

  Future<void> _queueUploadValues({
    required int subjectId,
    required int account,
    required BangumiCollectionSnapshot values,
    required Set<BangumiCollectionField> uploadFields,
    required int fallbackType,
    required bool create,
  }) async {
    BangumiFieldUpdate<T> update<T>(BangumiCollectionField field, T? value) =>
        uploadFields.contains(field) && value != null
        ? BangumiFieldUpdate<T>.set(value)
        : BangumiFieldUpdate<T>.unchanged();

    final metadata = BangumiMetadataPayload(
      rate: update(BangumiCollectionField.rate, values.rate),
      comment: update(BangumiCollectionField.comment, values.comment),
      tags: update(BangumiCollectionField.tags, values.tags),
      private: update(BangumiCollectionField.private, values.private),
    );

    if (create) {
      await _queue.enqueueUpsert(
        accountId: account,
        subjectId: subjectId,
        type: values.type ?? fallbackType,
        payload: metadata,
      );
      return;
    }

    // Only touch the status when it is actually part of the upload; a stray
    // status POST could revert a status changed on Bangumi.
    if (uploadFields.contains(BangumiCollectionField.status)) {
      await _queue.enqueueStatus(
        accountId: account,
        subjectId: subjectId,
        type: values.type ?? fallbackType,
      );
    }
    await _queue.enqueueMetadata(
      accountId: account,
      subjectId: subjectId,
      payload: metadata,
    );
  }

  bool _differs(
    BangumiCollectionSnapshot merged,
    BangumiCollectionSnapshot remote,
  ) {
    for (final field in BangumiCollectionField.values) {
      final mergedValue = merged.valueOf(field);
      // A null merged value means this app never knew the field; it carries no
      // intent, so it cannot justify a write.
      if (mergedValue == null) continue;
      if (field == BangumiCollectionField.tags) {
        final remoteTags = remote.tags;
        if (remoteTags == null) return true;
        if (canonicalTagKey(mergedValue as List<String>) !=
            canonicalTagKey(remoteTags)) {
          return true;
        }
        continue;
      }
      if (mergedValue != remote.valueOf(field)) return true;
    }
    return false;
  }

  Future<void> _writeRemoteToLocal(BangumiUserCollection item, int account) {
    final subject = item.subject;
    return _favoritesManager.applyRemoteSnapshot(
      bangumiId: item.subjectId,
      title: subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
      coverUrl: subject.images.large.isNotEmpty
          ? subject.images.large
          : subject.images.common,
      score: subject.score,
      type: item.type,
      accountId: account,
      rate: item.rate,
      comment: item.comment,
      tags: item.tags.map((tag) => tag.toString()).toList(growable: false),
      private: item.private,
      remoteUpdatedAt: item.date,
    );
  }

  Future<Map<int, LocalFavorite>> _favoriteSnapshots() async => {
    for (final favorite in await _favoritesManager.getAllFavorites())
      favorite.bangumiId: favorite,
  };

  Future<void> _confirmSettled(
    BangumiSyncDrainResult result,
    int account,
    Map<int, LocalFavorite> expected,
  ) async {
    for (final subjectId in result.settledSubjectIds) {
      final favorite = expected[subjectId];
      if (favorite == null ||
          (favorite.ownerAccountId != null &&
              favorite.ownerAccountId != account)) {
        continue;
      }
      await _favoritesManager.markQueueSettledIfUnchanged(
        expected: favorite,
        accountId: account,
      );
    }
  }
}

/// Convenience for callers that only need the queue to catch up (app start,
/// before a write) without a full reconciliation.
Future<void> drainBangumiSyncQueue({
  BangumiSyncQueue? queue,
  BangumiAuthManager? authManager,
  FavoritesManager? favoritesManager,
}) async {
  final auth = authManager ?? BangumiAuthManager();
  final account = auth.userId;
  if (!auth.isAuthenticated || account == null || account <= 0) return;
  final target =
      queue ?? BangumiSyncQueue(ensureFreshToken: auth.ensureFreshToken);
  try {
    final favorites = favoritesManager ?? FavoritesManager();
    await favorites.init();
    final expected = {
      for (final favorite in await favorites.getAllFavorites())
        favorite.bangumiId: favorite,
    };
    final result = await target.drain(accountId: account);
    for (final subjectId in result.settledSubjectIds) {
      final favorite = expected[subjectId];
      if (favorite == null ||
          (favorite.ownerAccountId != null &&
              favorite.ownerAccountId != account)) {
        continue;
      }
      await favorites.markQueueSettledIfUnchanged(
        expected: favorite,
        accountId: account,
      );
    }
  } catch (error) {
    debugPrint('Bangumi sync queue drain failed: $error');
  }
}
