// Shared in-memory [BangumiCollectionsBackend] for collection sync, queue, and
// repository tests.
//
// Records every call so tests can assert on the exact request shape — in
// particular that a metadata PATCH distinguishes "leave unchanged" (`null`) from
// "clear" (`[]` / `0` / `''`), which is the difference between preserving and
// silently deleting a user's tags.

import 'package:mikan_player/services/bangumi_collections_repository.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

/// A recorded status-and-metadata upsert (`POST` with `type`).
class RecordedUpsert {
  const RecordedUpsert({
    required this.subjectId,
    required this.type,
    required this.rate,
    required this.comment,
    required this.tags,
    required this.private,
  });

  final int subjectId;
  final int type;
  final int? rate;
  final String? comment;
  final List<String>? tags;
  final bool? private;
}

/// A recorded metadata-only patch (`PATCH`, never carries `type`).
class RecordedPatch {
  const RecordedPatch({
    required this.subjectId,
    required this.rate,
    required this.comment,
    required this.tags,
    required this.private,
  });

  final int subjectId;
  final int? rate;
  final String? comment;
  final List<String>? tags;
  final bool? private;
}

/// Operation names used by [FakeBangumiCollectionsBackend.failWith].
abstract final class FakeBackendOperation {
  static const String setStatus = 'setStatus';
  static const String upsert = 'upsertWithMetadata';
  static const String patchMetadata = 'patchMetadata';
  static const String delete = 'delete';
  static const String fetchMineOne = 'fetchMineOne';
  static const String fetchMyPage = 'fetchMyPage';
}

class FakeBangumiCollectionsBackend implements BangumiCollectionsBackend {
  FakeBangumiCollectionsBackend([
    List<BangumiUserCollectionEntry> entries = const [],
  ]) : entries = [...entries];

  final List<BangumiUserCollectionEntry> entries;

  final List<(int subjectId, int type)> statusUpdates = [];
  final List<RecordedUpsert> upserts = [];
  final List<RecordedPatch> metadataPatches = [];
  final List<int> deletes = [];
  final List<int> fetchedOne = [];
  int fetchMyPageCalls = 0;

  /// Returns the error to throw for a given operation, or `null` to succeed.
  /// Lets one test simulate an offline backend, a 401, or a per-subject 404.
  Object? Function(String operation, int subjectId)? failWith;

  void _maybeThrow(String operation, int subjectId) {
    final error = failWith?.call(operation, subjectId);
    if (error != null) throw error;
  }

  @override
  Future<List<BangumiUserCollectionEntry>> fetchPublicPage({
    required String username,
    required int limit,
    required int offset,
  }) async => offset == 0 ? entries : const [];

  @override
  Future<List<BangumiUserCollectionEntry>> fetchMyPage({
    required String username,
    required int limit,
    required int offset,
  }) async {
    fetchMyPageCalls++;
    _maybeThrow(FakeBackendOperation.fetchMyPage, 0);
    return offset == 0 ? entries : const [];
  }

  @override
  Future<void> setStatus({required int subjectId, required int type}) async {
    _maybeThrow(FakeBackendOperation.setStatus, subjectId);
    statusUpdates.add((subjectId, type));
  }

  @override
  Future<void> upsertWithMetadata({
    required int subjectId,
    required int type,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    _maybeThrow(FakeBackendOperation.upsert, subjectId);
    upserts.add(
      RecordedUpsert(
        subjectId: subjectId,
        type: type,
        rate: rate,
        comment: comment,
        tags: tags,
        private: private,
      ),
    );
  }

  @override
  Future<void> patchMetadata({
    required int subjectId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    _maybeThrow(FakeBackendOperation.patchMetadata, subjectId);
    metadataPatches.add(
      RecordedPatch(
        subjectId: subjectId,
        rate: rate,
        comment: comment,
        tags: tags,
        private: private,
      ),
    );
  }

  @override
  Future<void> delete({required int subjectId}) async {
    _maybeThrow(FakeBackendOperation.delete, subjectId);
    deletes.add(subjectId);
    entries.removeWhere((entry) => entry.subjectId == subjectId);
  }

  @override
  Future<int?> fetchType({required int subjectId}) async => entries
      .where((entry) => entry.subjectId == subjectId)
      .firstOrNull
      ?.collectionType;

  @override
  Future<BangumiUserCollectionEntry?> fetchMineOne({
    required String username,
    required int subjectId,
  }) async {
    fetchedOne.add(subjectId);
    _maybeThrow(FakeBackendOperation.fetchMineOne, subjectId);
    return entries
        .where((entry) => entry.subjectId == subjectId)
        .firstOrNull;
  }
}

/// Builds a collection entry with sensible defaults for the fields a test is
/// not asserting on.
BangumiUserCollectionEntry fakeCollectionEntry(
  int subjectId,
  int type, {
  String title = 'Cloud',
  int rate = 0,
  String comment = '',
  List<String> tags = const [],
  bool private = false,
  String updatedAt = '2026-07-27T00:00:00Z',
  double subjectScore = 8,
}) => BangumiUserCollectionEntry(
  updatedAt: updatedAt,
  comment: comment,
  tags: tags,
  subjectId: subjectId,
  collectionType: type,
  rate: rate,
  private: private,
  subjectName: title,
  subjectNameCn: '',
  subjectShortSummary: '',
  subjectScore: subjectScore,
  subjectEps: 12,
  subjectCollectionTotal: 10,
  imageSmall: '',
  imageGrid: '',
  imageLarge: 'https://example.com/$subjectId.jpg',
  imageMedium: '',
  imageCommon: '',
);
