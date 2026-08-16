// Field-level three-way merge rules for Bangumi collection sync.
//
// Pure functions, no IO. The matrix that matters is, per field:
//   local == remote                        -> nothing to do
//   local == base, remote != base          -> take remote
//   local != base, remote == base          -> take local
//   local != base, remote != base, L != R  -> conflict

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collection_merge.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' show BangumiImages;

const int _account = 42;

BangumiCollectionSnapshot _snap({
  int? type = 3,
  int? rate = 0,
  String? comment = '',
  List<String>? tags = const <String>[],
  bool? private = false,
}) => BangumiCollectionSnapshot(
  type: type,
  rate: rate,
  comment: comment,
  tags: tags,
  private: private,
);

LocalFavorite _local({
  int type = 3,
  int? rate,
  String? comment,
  List<String>? tags,
  bool? private,
  int? baseType,
  int? baseRate,
  String? baseComment,
  List<String>? baseTags,
  bool? basePrivate,
  int? lastSyncedAt,
  int? ownerAccountId,
}) => LocalFavorite()
  ..bangumiId = 1
  ..title = 'T'
  ..coverUrl = ''
  ..score = 8
  ..createdAt = 0
  ..type = type
  ..rate = rate
  ..comment = comment
  ..tags = tags
  ..private = private
  ..baseType = baseType
  ..baseRate = baseRate
  ..baseComment = baseComment
  ..baseTags = baseTags
  ..basePrivate = basePrivate
  ..lastSyncedAt = lastSyncedAt
  ..ownerAccountId = ownerAccountId;

BangumiUserCollection _remote({
  int type = 3,
  int rate = 0,
  String comment = '',
  List<String> tags = const <String>[],
  bool private = false,
}) => BangumiUserCollection(
  date: '2026-07-27T00:00:00Z',
  comment: comment,
  tags: tags,
  subjectId: 1,
  type: type,
  rate: rate,
  private: private,
  subject: BangumiUserCollectionSubject(
    id: 1,
    name: 'N',
    nameCn: '',
    shortSummary: '',
    score: 8,
    eps: 12,
    collectionTotal: 3,
    images: BangumiImages(
      small: '',
      grid: '',
      large: '',
      medium: '',
      common: '',
    ),
  ),
);

SubjectMergePlan _merge({
  required BangumiCollectionSnapshot? local,
  required BangumiCollectionSnapshot? remote,
  BangumiCollectionSnapshot baseline = BangumiCollectionSnapshot.unknown,
  bool hadBaseline = false,
}) => mergeCollectionSubject(
  subjectId: 1,
  local: local,
  remote: remote,
  baseline: baseline,
  hadBaseline: hadBaseline,
);

void main() {
  group('one-sided entries', () {
    test('local only without a baseline uploads the whole entry', () {
      final plan = _merge(local: _snap(rate: 7), remote: null);

      expect(plan.kind, BangumiCollectionMergeKind.localOnly);
      expect(plan.needsUpload, isTrue);
      expect(plan.needsLocalWrite, isFalse);
      expect(plan.hasConflicts, isFalse);
      // Upload must carry the local metadata, not just the status.
      expect(plan.resolveValues().rate, 7);
    });

    test('remote only writes the whole entry locally', () {
      final plan = _merge(local: null, remote: _snap(rate: 9, comment: 'hi'));

      expect(plan.kind, BangumiCollectionMergeKind.remoteOnly);
      expect(plan.needsLocalWrite, isTrue);
      expect(plan.needsUpload, isFalse);
      final values = plan.resolveValues();
      expect(values.rate, 9);
      expect(values.comment, 'hi');
    });

    test('a previously synced entry missing remotely is a remote delete', () {
      final plan = _merge(
        local: _snap(),
        remote: null,
        baseline: _snap(),
        hadBaseline: true,
      );

      // Silently re-creating it would resurrect a collection the user deleted
      // on Bangumi; silently deleting locally would lose data. Ask instead.
      expect(plan.kind, BangumiCollectionMergeKind.remoteDeleted);
      expect(plan.needsUpload, isFalse);
      expect(plan.needsLocalWrite, isFalse);
    });

    test('two missing sides is a programming error', () {
      expect(
        () => _merge(local: null, remote: null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('field matrix', () {
    test('equal values on both sides resolve to nothing', () {
      final plan = _merge(
        local: _snap(rate: 8, comment: 'same', tags: ['a']),
        remote: _snap(rate: 8, comment: 'same', tags: ['a']),
        baseline: _snap(rate: 8, comment: 'same', tags: ['a']),
      );

      expect(plan.resolved, isEmpty);
      expect(plan.conflicts, isEmpty);
      expect(plan.needsUpload, isFalse);
      expect(plan.needsLocalWrite, isFalse);
    });

    test('remote-only change takes remote', () {
      final plan = _merge(
        local: _snap(rate: 5),
        remote: _snap(rate: 9),
        baseline: _snap(rate: 5),
      );

      expect(plan.resolved[BangumiCollectionField.rate], MergeSide.remote);
      expect(plan.conflicts, isEmpty);
      expect(plan.resolveValues().rate, 9);
    });

    test('local-only change takes local', () {
      final plan = _merge(
        local: _snap(rate: 9),
        remote: _snap(rate: 5),
        baseline: _snap(rate: 5),
      );

      expect(plan.resolved[BangumiCollectionField.rate], MergeSide.local);
      expect(plan.conflicts, isEmpty);
      expect(plan.needsUpload, isTrue);
      expect(plan.resolveValues().rate, 9);
    });

    test('both sides changed differently is a conflict', () {
      final plan = _merge(
        local: _snap(rate: 9),
        remote: _snap(rate: 4),
        baseline: _snap(rate: 5),
      );

      expect(plan.resolved, isEmpty);
      final conflict = plan.conflicts.single;
      expect(conflict.field, BangumiCollectionField.rate);
      expect(conflict.localValue, 9);
      expect(conflict.remoteValue, 4);
    });

    test('independent per-field edits merge without any conflict', () {
      // The whole point of field-level merge: rating changed on Bangumi while
      // the comment changed locally, and both survive.
      final plan = _merge(
        local: _snap(rate: 5, comment: 'local note'),
        remote: _snap(rate: 9, comment: 'base note'),
        baseline: _snap(rate: 5, comment: 'base note'),
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.needsUpload, isTrue);
      expect(plan.needsLocalWrite, isTrue);
      final values = plan.resolveValues();
      expect(values.rate, 9);
      expect(values.comment, 'local note');
    });

    test('every field can resolve independently in one pass', () {
      final plan = _merge(
        local: _snap(
          type: 2,
          rate: 5,
          comment: 'local',
          tags: ['local'],
          private: true,
        ),
        remote: _snap(
          type: 4,
          rate: 5,
          comment: 'remote',
          tags: ['base'],
          private: false,
        ),
        baseline: _snap(
          type: 4,
          rate: 5,
          comment: 'base',
          tags: ['base'],
          private: false,
        ),
      );

      expect(plan.resolved[BangumiCollectionField.status], MergeSide.local);
      expect(plan.resolved[BangumiCollectionField.tags], MergeSide.local);
      expect(plan.resolved[BangumiCollectionField.private], MergeSide.local);
      expect(plan.resolved.containsKey(BangumiCollectionField.rate), isFalse);
      expect(plan.conflicts.single.field, BangumiCollectionField.comment);
    });
  });

  group('missing baseline', () {
    test('divergent values without a baseline are a conflict, not a guess', () {
      final plan = _merge(
        local: _snap(rate: 7),
        remote: _snap(rate: 3),
        baseline: BangumiCollectionSnapshot.unknown,
      );

      expect(plan.conflicts.single.field, BangumiCollectionField.rate);
      expect(plan.resolved, isEmpty);
    });

    test('a null local field follows Bangumi instead of conflicting', () {
      // Pre-v4 rows have no metadata at all. There is no local intent to
      // protect, so adopting the server value is safe.
      final plan = _merge(
        local: _snap(rate: null, comment: null, tags: null, private: null),
        remote: _snap(rate: 8, comment: 'server', tags: ['x'], private: true),
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.resolved[BangumiCollectionField.rate], MergeSide.remote);
      expect(plan.resolved[BangumiCollectionField.comment], MergeSide.remote);
      expect(plan.resolved[BangumiCollectionField.tags], MergeSide.remote);
      expect(plan.resolved[BangumiCollectionField.private], MergeSide.remote);
      final values = plan.resolveValues();
      expect(values.rate, 8);
      expect(values.tags, ['x']);
    });

    test('equal values without a baseline need no write', () {
      final plan = _merge(
        local: _snap(rate: 8, comment: 'same'),
        remote: _snap(rate: 8, comment: 'same'),
      );

      expect(plan.resolved, isEmpty);
      expect(plan.conflicts, isEmpty);
    });
  });

  group('tags', () {
    test('reordering is not an edit', () {
      final plan = _merge(
        local: _snap(tags: ['b', 'a']),
        remote: _snap(tags: ['a', 'b']),
        baseline: _snap(tags: ['a', 'b']),
      );

      expect(plan.resolved, isEmpty);
      expect(plan.conflicts, isEmpty);
    });

    test('duplicates and surrounding whitespace are not an edit', () {
      final plan = _merge(
        local: _snap(tags: [' a ', 'a', 'b']),
        remote: _snap(tags: ['a', 'b']),
        baseline: _snap(tags: ['a', 'b']),
      );

      expect(plan.resolved, isEmpty);
      expect(plan.conflicts, isEmpty);
    });

    test('clearing tags locally is an edit that uploads an empty list', () {
      final plan = _merge(
        local: _snap(tags: const <String>[]),
        remote: _snap(tags: ['a']),
        baseline: _snap(tags: ['a']),
      );

      expect(plan.resolved[BangumiCollectionField.tags], MergeSide.local);
      // [] must survive as [] — Bangumi reads it as "clear every tag", while
      // null would mean "leave them alone".
      expect(plan.resolveValues().tags, isEmpty);
      expect(plan.resolveValues().tags, isNotNull);
    });

    test('adding a tag remotely does not clear the local list', () {
      final plan = _merge(
        local: _snap(tags: ['a']),
        remote: _snap(tags: ['a', 'b']),
        baseline: _snap(tags: ['a']),
      );

      expect(plan.resolved[BangumiCollectionField.tags], MergeSide.remote);
      expect(plan.resolveValues().tags, ['a', 'b']);
    });

    test('canonical key ignores order, blanks, and duplicates', () {
      expect(canonicalTagKey(['b', 'a']), canonicalTagKey(['a', 'b']));
      expect(canonicalTagKey(['a', '', ' ']), canonicalTagKey(['a']));
      expect(canonicalTagKey(['a', 'a']), canonicalTagKey(['a']));
      expect(canonicalTagKey(['a']), isNot(canonicalTagKey(['a', 'b'])));
    });
  });

  group('conflict resolution', () {
    test('an explicit choice overrides the automatic resolution', () {
      final plan = _merge(
        local: _snap(rate: 9, comment: 'local'),
        remote: _snap(rate: 4, comment: 'remote'),
        baseline: _snap(rate: 5, comment: 'base'),
      );

      final keepLocal = plan.resolveValues({
        BangumiCollectionField.rate: MergeSide.local,
        BangumiCollectionField.comment: MergeSide.local,
      });
      expect(keepLocal.rate, 9);
      expect(keepLocal.comment, 'local');

      final keepRemote = plan.resolveValues({
        BangumiCollectionField.rate: MergeSide.remote,
        BangumiCollectionField.comment: MergeSide.remote,
      });
      expect(keepRemote.rate, 4);
      expect(keepRemote.comment, 'remote');
    });

    test('a choice can override an auto-resolved field too', () {
      final plan = _merge(
        local: _snap(rate: 5),
        remote: _snap(rate: 9),
        baseline: _snap(rate: 5),
      );

      expect(plan.resolveValues().rate, 9);
      expect(
        plan.resolveValues({BangumiCollectionField.rate: MergeSide.local}).rate,
        5,
      );
    });

    test('agreed fields keep their value when other fields are chosen', () {
      final plan = _merge(
        local: _snap(rate: 9, comment: 'agreed'),
        remote: _snap(rate: 4, comment: 'agreed'),
        baseline: _snap(rate: 5, comment: 'agreed'),
      );

      final values = plan.resolveValues({
        BangumiCollectionField.rate: MergeSide.remote,
      });
      expect(values.rate, 4);
      expect(values.comment, 'agreed');
    });
  });

  group('snapshot adapters', () {
    test('a baseline from another account is unusable', () {
      final favorite = _local(
        baseType: 2,
        baseRate: 7,
        lastSyncedAt: 100,
        ownerAccountId: 999,
      );

      expect(favorite.hasBaselineFor(_account), isFalse);
      final baseline = BangumiCollectionSnapshot.fromBaseline(
        favorite,
        accountId: _account,
      );
      // Otherwise account A's baseline would make account B's untouched values
      // look like local edits and upload them.
      expect(baseline.type, isNull);
      expect(baseline.rate, isNull);
    });

    test('a never-synced row has no baseline', () {
      final favorite = _local(baseType: 2, baseRate: 7);
      expect(favorite.hasBaselineFor(_account), isFalse);
      expect(
        BangumiCollectionSnapshot.fromBaseline(
          favorite,
          accountId: _account,
        ).rate,
        isNull,
      );
    });

    test('a baseline for the active account is used', () {
      final favorite = _local(
        baseType: 2,
        baseRate: 7,
        baseComment: 'b',
        baseTags: ['t'],
        basePrivate: true,
        lastSyncedAt: 100,
        ownerAccountId: _account,
      );

      expect(favorite.hasBaselineFor(_account), isTrue);
      final baseline = BangumiCollectionSnapshot.fromBaseline(
        favorite,
        accountId: _account,
      );
      expect(baseline.type, 2);
      expect(baseline.rate, 7);
      expect(baseline.comment, 'b');
      expect(baseline.tags, ['t']);
      expect(baseline.private, isTrue);
    });

    test('local and remote adapters read their own shapes', () {
      final local = BangumiCollectionSnapshot.fromLocal(
        _local(type: 4, rate: 6, comment: 'c', tags: ['x'], private: true),
      );
      expect(local.type, 4);
      expect(local.rate, 6);
      expect(local.tags, ['x']);
      expect(local.private, isTrue);

      final remote = BangumiCollectionSnapshot.fromRemote(
        _remote(type: 5, rate: 2, comment: 'r', tags: ['y'], private: true),
      );
      expect(remote.type, 5);
      expect(remote.rate, 2);
      expect(remote.comment, 'r');
      expect(remote.tags, ['y']);
      expect(remote.private, isTrue);
    });

    test('the subject public score never reaches the user rating', () {
      // subjectScore is 8 in the fixture; rate is 2. Conflating them would
      // overwrite the user's own rating with the crowd average.
      final remote = BangumiCollectionSnapshot.fromRemote(_remote(rate: 2));
      expect(remote.rate, 2);
    });
  });
}
