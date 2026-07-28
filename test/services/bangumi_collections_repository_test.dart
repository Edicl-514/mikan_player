import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';

import '../support/fake_bangumi_collections_backend.dart';

BangumiCollectionsRepository _repository(
  FakeBangumiCollectionsBackend backend, {
  bool authenticated = true,
}) => BangumiCollectionsRepository(
  backend: backend,
  ensureAuthenticated: () async => authenticated,
  apiHostResolver: () async => 'api.bgm.tv',
);

void main() {
  group('tag normalization', () {
    test('normalizes tags without turning an empty list into a no-op sentinel', () {
      expect(normalizeBangumiTags([' sci-fi ', '', 'sci-fi', 'drama']), [
        'sci-fi',
        'drama',
      ]);
      expect(normalizeBangumiTags(const <String>[]), isEmpty);
    });

    test('rejects whitespace inside a single tag', () {
      expect(
        () => normalizeBangumiTags(['science fiction']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('write routing', () {
    test('setStatus uses the status POST and sends no metadata', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).setStatus(subjectId: 12, type: 3);

      expect(backend.statusUpdates, [(12, 3)]);
      expect(backend.metadataPatches, isEmpty);
      expect(backend.upserts, isEmpty);
    });

    test('update is a thin alias for setStatus', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).update(subjectId: 5, type: 2);

      expect(backend.statusUpdates, [(5, 2)]);
      expect(backend.upserts, isEmpty);
    });

    test('patchMetadata never carries a collection type', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).patchMetadata(
        subjectId: 7,
        rate: 8,
        comment: 'good',
        tags: const ['sci-fi'],
        private: true,
      );

      expect(backend.statusUpdates, isEmpty);
      final patch = backend.metadataPatches.single;
      expect(patch.subjectId, 7);
      expect(patch.rate, 8);
      expect(patch.comment, 'good');
      expect(patch.tags, ['sci-fi']);
      expect(patch.private, isTrue);
    });

    test('omitted metadata fields stay null instead of becoming empty', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).patchMetadata(subjectId: 7, rate: 5);

      final patch = backend.metadataPatches.single;
      expect(patch.rate, 5);
      // null tags mean "leave unchanged"; sending [] here would delete every
      // tag the user has on Bangumi.
      expect(patch.tags, isNull);
      expect(patch.comment, isNull);
      expect(patch.private, isNull);
    });

    test('clearing values passes through the explicit empty forms', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).patchMetadata(
        subjectId: 7,
        rate: 0,
        comment: '',
        tags: const [],
      );

      final patch = backend.metadataPatches.single;
      expect(patch.rate, 0);
      expect(patch.comment, '');
      expect(patch.tags, isEmpty);
      expect(patch.tags, isNotNull);
    });

    test('upsertWithMetadata sends status and metadata together', () async {
      final backend = FakeBangumiCollectionsBackend();
      await _repository(backend).upsertWithMetadata(
        subjectId: 9,
        type: 2,
        rate: 7,
        comment: 'done',
        tags: const ['tv'],
        private: false,
      );

      expect(backend.statusUpdates, isEmpty);
      expect(backend.metadataPatches, isEmpty);
      final upsert = backend.upserts.single;
      expect(upsert.subjectId, 9);
      expect(upsert.type, 2);
      expect(upsert.rate, 7);
      expect(upsert.comment, 'done');
      expect(upsert.tags, ['tv']);
      expect(upsert.private, isFalse);
    });
  });

  group('single collection read', () {
    test('maps a full entry without paging the whole collection', () async {
      final backend = FakeBangumiCollectionsBackend([
        fakeCollectionEntry(
          11,
          3,
          rate: 9,
          comment: 'nice',
          tags: const ['a', 'b'],
          private: true,
        ),
      ]);

      final entry = await _repository(
        backend,
      ).fetchMineOne(username: 'alice', subjectId: 11);

      expect(entry, isNotNull);
      expect(entry!.subjectId, 11);
      expect(entry.type, 3);
      expect(entry.rate, 9);
      expect(entry.comment, 'nice');
      expect(entry.tags, ['a', 'b']);
      expect(entry.private, isTrue);
      expect(backend.fetchedOne, [11]);
      // The dedicated endpoint replaced the old "page through everything and
      // filter" fallback.
      expect(backend.fetchMyPageCalls, 0);
    });

    test('an uncollected subject reads as null, not as an error', () async {
      final backend = FakeBangumiCollectionsBackend();
      final entry = await _repository(
        backend,
      ).fetchMineOne(username: 'alice', subjectId: 404);

      expect(entry, isNull);
    });
  });

  group('authentication gate', () {
    test('every write refuses to run once the session is gone', () async {
      final backend = FakeBangumiCollectionsBackend();
      final repository = _repository(backend, authenticated: false);

      await expectLater(
        repository.setStatus(subjectId: 1, type: 1),
        throwsStateError,
      );
      await expectLater(
        repository.patchMetadata(subjectId: 1, rate: 1),
        throwsStateError,
      );
      await expectLater(
        repository.upsertWithMetadata(subjectId: 1, type: 1),
        throwsStateError,
      );
      await expectLater(repository.delete(1), throwsStateError);
      await expectLater(
        repository.fetchMineOne(username: 'alice', subjectId: 1),
        throwsStateError,
      );

      // Nothing reached the network.
      expect(backend.statusUpdates, isEmpty);
      expect(backend.metadataPatches, isEmpty);
      expect(backend.upserts, isEmpty);
      expect(backend.deletes, isEmpty);
      expect(backend.fetchedOne, isEmpty);
    });
  });
}
