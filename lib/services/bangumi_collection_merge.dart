import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';

/// The user-owned collection fields that participate in two-way sync.
///
/// Deliberately excludes the subject's public `score` (that is upstream data,
/// not a user value) and `ep_status` / `vol_status` (book-only).
enum BangumiCollectionField { status, rate, comment, tags, private }

/// Which side a field resolves to.
enum MergeSide { local, remote }

/// Shape of a subject's difference, which decides what the caller does with it.
enum BangumiCollectionMergeKind {
  /// Present locally, never synced under this account, absent on Bangumi:
  /// upload the whole entry.
  localOnly,

  /// Present on Bangumi only: write the whole entry locally.
  remoteOnly,

  /// Synced before under this account and now gone from Bangumi. Someone
  /// removed it elsewhere, so the choice (re-upload vs delete locally) belongs
  /// to the user rather than to a silent rule.
  remoteDeleted,

  /// Present on both sides: resolve field by field.
  fieldMerge,
}

/// A neutral value holder so the merge rules never touch a database row or an
/// API response type directly.
class BangumiCollectionSnapshot {
  const BangumiCollectionSnapshot({
    this.type,
    this.rate,
    this.comment,
    this.tags,
    this.private,
  });

  /// Collection status (1=wish … 5=dropped).
  final int? type;

  /// The user's own rating. `0` means "no rating" in Bangumi's model; `null`
  /// means this app has never known a value.
  final int? rate;
  final String? comment;
  final List<String>? tags;
  final bool? private;

  static const BangumiCollectionSnapshot unknown = BangumiCollectionSnapshot();

  /// Current local values.
  factory BangumiCollectionSnapshot.fromLocal(LocalFavorite favorite) =>
      BangumiCollectionSnapshot(
        type: favorite.type,
        rate: favorite.rate,
        comment: favorite.comment,
        tags: favorite.tags,
        private: favorite.private,
      );

  /// The baseline both sides agreed on at the last successful sync, or
  /// [unknown] when there is no usable baseline (pre-v4 row, or a baseline that
  /// belongs to a different account).
  factory BangumiCollectionSnapshot.fromBaseline(
    LocalFavorite favorite, {
    required int accountId,
  }) {
    if (!favorite.hasBaselineFor(accountId)) return unknown;
    return BangumiCollectionSnapshot(
      type: favorite.baseType,
      rate: favorite.baseRate,
      comment: favorite.baseComment,
      tags: favorite.baseTags,
      private: favorite.basePrivate,
    );
  }

  /// Bangumi's current values. The server always sends concrete values, so
  /// nothing here is "unknown": `rate: 0` and `comment: ''` mean unset.
  factory BangumiCollectionSnapshot.fromRemote(BangumiUserCollection remote) =>
      BangumiCollectionSnapshot(
        type: remote.type,
        rate: remote.rate,
        comment: remote.comment,
        tags: remote.tags.map((tag) => tag.toString()).toList(growable: false),
        private: remote.private,
      );

  Object? valueOf(BangumiCollectionField field) => switch (field) {
    BangumiCollectionField.status => type,
    BangumiCollectionField.rate => rate,
    BangumiCollectionField.comment => comment,
    BangumiCollectionField.tags => tags,
    BangumiCollectionField.private => private,
  };
}

class BangumiCollectionFieldConflict {
  const BangumiCollectionFieldConflict({
    required this.field,
    required this.localValue,
    required this.remoteValue,
  });

  final BangumiCollectionField field;
  final Object? localValue;
  final Object? remoteValue;
}

/// Per-subject merge outcome: what was decided automatically, and what still
/// needs the user.
class SubjectMergePlan {
  const SubjectMergePlan({
    required this.subjectId,
    required this.kind,
    required this.local,
    required this.remote,
    required this.resolved,
    required this.conflicts,
  });

  final int subjectId;
  final BangumiCollectionMergeKind kind;
  final BangumiCollectionSnapshot local;
  final BangumiCollectionSnapshot remote;

  /// Fields the rules settled without asking. Fields where both sides already
  /// agree are absent — there is nothing to write on either side.
  final Map<BangumiCollectionField, MergeSide> resolved;

  /// Fields changed on both sides to different values.
  final List<BangumiCollectionFieldConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;

  /// True when Bangumi needs a write once every conflict is decided.
  bool get needsUpload => resolved.containsValue(MergeSide.local);

  /// True when the local row needs a write.
  bool get needsLocalWrite => resolved.containsValue(MergeSide.remote);

  /// Final values for the subject, applying [choices] on top of the automatic
  /// resolutions. A field with neither an automatic resolution nor a choice
  /// keeps its local value, since both sides already agreed on it.
  BangumiCollectionSnapshot resolveValues([
    Map<BangumiCollectionField, MergeSide> choices = const {},
  ]) {
    Object? pick(BangumiCollectionField field) {
      final side = choices[field] ?? resolved[field] ?? MergeSide.local;
      return side == MergeSide.local
          ? local.valueOf(field)
          : remote.valueOf(field);
    }

    return BangumiCollectionSnapshot(
      type: pick(BangumiCollectionField.status) as int?,
      rate: pick(BangumiCollectionField.rate) as int?,
      comment: pick(BangumiCollectionField.comment) as String?,
      tags: pick(BangumiCollectionField.tags) as List<String>?,
      private: pick(BangumiCollectionField.private) as bool?,
    );
  }
}

/// Field-level three-way merge for one subject.
///
/// Comparing only local against remote cannot tell "I changed this" from "they
/// changed this", so every decision is made against the baseline captured at
/// the last successful sync.
SubjectMergePlan mergeCollectionSubject({
  required int subjectId,
  required BangumiCollectionSnapshot? local,
  required BangumiCollectionSnapshot? remote,
  required BangumiCollectionSnapshot baseline,
  bool hadBaseline = false,
}) {
  if (local != null && remote == null) {
    // A baseline proves the entry existed on Bangumi under this account, so its
    // absence now is a remote delete, not a local-only addition.
    final deleted = hadBaseline;
    return SubjectMergePlan(
      subjectId: subjectId,
      kind: deleted
          ? BangumiCollectionMergeKind.remoteDeleted
          : BangumiCollectionMergeKind.localOnly,
      local: local,
      remote: BangumiCollectionSnapshot.unknown,
      // A local-only entry uploads every field. A remote delete resolves
      // nothing: re-upload vs local delete is the user's call.
      resolved: deleted ? const {} : _allFieldsTo(MergeSide.local),
      conflicts: const [],
    );
  }
  if (local == null && remote != null) {
    return SubjectMergePlan(
      subjectId: subjectId,
      kind: BangumiCollectionMergeKind.remoteOnly,
      local: BangumiCollectionSnapshot.unknown,
      remote: remote,
      resolved: _allFieldsTo(MergeSide.remote),
      conflicts: const [],
    );
  }
  if (local == null || remote == null) {
    throw ArgumentError('mergeCollectionSubject requires at least one side');
  }

  final resolved = <BangumiCollectionField, MergeSide>{};
  final conflicts = <BangumiCollectionFieldConflict>[];

  for (final field in BangumiCollectionField.values) {
    final localValue = local.valueOf(field);
    final remoteValue = remote.valueOf(field);
    final baseValue = baseline.valueOf(field);

    if (_sameValue(field, localValue, remoteValue)) continue;

    // No local value was ever recorded (a pre-v4 row, or a field this app has
    // not tracked). There is no local intent to lose, so follow Bangumi.
    if (localValue == null && baseValue == null) {
      resolved[field] = MergeSide.remote;
      continue;
    }

    final localChanged = !_sameValue(field, localValue, baseValue);
    final remoteChanged = !_sameValue(field, remoteValue, baseValue);

    if (baseValue == null && localChanged && remoteChanged) {
      // Without a baseline neither side can be shown to be the newer edit.
      conflicts.add(
        BangumiCollectionFieldConflict(
          field: field,
          localValue: localValue,
          remoteValue: remoteValue,
        ),
      );
      continue;
    }

    if (!localChanged && remoteChanged) {
      resolved[field] = MergeSide.remote;
    } else if (localChanged && !remoteChanged) {
      resolved[field] = MergeSide.local;
    } else {
      conflicts.add(
        BangumiCollectionFieldConflict(
          field: field,
          localValue: localValue,
          remoteValue: remoteValue,
        ),
      );
    }
  }

  return SubjectMergePlan(
    subjectId: subjectId,
    kind: BangumiCollectionMergeKind.fieldMerge,
    local: local,
    remote: remote,
    resolved: resolved,
    conflicts: conflicts,
  );
}

Map<BangumiCollectionField, MergeSide> _allFieldsTo(MergeSide side) => {
  for (final field in BangumiCollectionField.values) field: side,
};

/// Value equality per field. Tags compare as an order-insensitive set so
/// reordering alone never looks like an edit.
bool _sameValue(BangumiCollectionField field, Object? a, Object? b) {
  if (field != BangumiCollectionField.tags) return a == b;
  if (a == null || b == null) return a == null && b == null;
  final left = canonicalTagKey(a as List<String>);
  final right = canonicalTagKey(b as List<String>);
  return left == right;
}

/// Order-insensitive, duplicate-free comparison key for a tag list.
String canonicalTagKey(List<String> tags) {
  final normalized =
      tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return normalized.join(' ');
}
