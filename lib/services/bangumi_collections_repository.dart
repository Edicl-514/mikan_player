import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/services/bangumi_auth_manager.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart' as rust_bangumi;
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

List<String> normalizeBangumiTags(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in values) {
    final tag = raw.trim();
    if (tag.isEmpty) continue;
    if (tag.contains(RegExp(r'\s'))) {
      throw FormatException('Bangumi tags cannot contain whitespace');
    }
    if (seen.add(tag)) result.add(tag);
  }
  return result;
}

abstract interface class BangumiCollectionsBackend {
  Future<List<rust_bangumi.BangumiUserCollectionEntry>> fetchPublicPage({
    required String username,
    required int limit,
    required int offset,
  });

  Future<List<rust_bangumi.BangumiUserCollectionEntry>> fetchMyPage({
    required String username,
    required int limit,
    required int offset,
  });

  /// Status-only upsert (`POST`). Never carries metadata, so changing a status
  /// cannot clobber a rating or comment written elsewhere.
  Future<void> setStatus({required int subjectId, required int type});

  /// Status *and* metadata in one `POST`. Only for creating a collection that
  /// exists locally but not on Bangumi, where there is no remote value to lose.
  Future<void> upsertWithMetadata({
    required int subjectId,
    required int type,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  });

  /// Metadata-only `PATCH`. `null` omits a field; `tags: []` clears every tag.
  Future<void> patchMetadata({
    required int subjectId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  });

  Future<void> delete({required int subjectId});

  Future<int?> fetchType({required int subjectId});

  /// One full collection entry, or `null` when the subject is not collected.
  Future<rust_bangumi.BangumiUserCollectionEntry?> fetchMineOne({
    required String username,
    required int subjectId,
  });
}

class RustBangumiCollectionsBackend implements BangumiCollectionsBackend {
  const RustBangumiCollectionsBackend();

  @override
  Future<List<rust_bangumi.BangumiUserCollectionEntry>> fetchPublicPage({
    required String username,
    required int limit,
    required int offset,
  }) => rust_bangumi.fetchBangumiUserCollections(
    username: username,
    subjectType: 2,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<rust_bangumi.BangumiUserCollectionEntry>> fetchMyPage({
    required String username,
    required int limit,
    required int offset,
  }) => rust_bangumi.fetchMyBangumiCollections(
    username: username,
    subjectType: 2,
    collectionType: 0,
    limit: limit,
    offset: offset,
  );

  @override
  Future<void> setStatus({required int subjectId, required int type}) =>
      rust_bangumi.setBangumiCollectionStatus(
        subjectId: subjectId,
        collectionType: type,
      );

  @override
  Future<void> upsertWithMetadata({
    required int subjectId,
    required int type,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) => rust_bangumi.updateBangumiCollection(
    subjectId: subjectId,
    collectionType: type,
    rate: rate,
    comment: comment,
    tags: tags,
    private: private,
  );

  @override
  Future<void> patchMetadata({
    required int subjectId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) => rust_bangumi.patchBangumiCollectionMetadata(
    subjectId: subjectId,
    rate: rate,
    comment: comment,
    tags: tags,
    private: private,
  );

  @override
  Future<rust_bangumi.BangumiUserCollectionEntry?> fetchMineOne({
    required String username,
    required int subjectId,
  }) => rust_bangumi.fetchMyBangumiCollection(
    username: username,
    subjectId: subjectId,
  );

  @override
  Future<void> delete({required int subjectId}) =>
      rust_bangumi.deleteBangumiCollection(subjectId: subjectId);

  @override
  Future<int?> fetchType({required int subjectId}) =>
      rust_bangumi.fetchMyBangumiCollectionType(
        username: UserManager().user?.username ?? '',
        subjectId: subjectId,
      );
}

/// Collection API boundary shared by public browsing, account sync, and the
/// Bangumi details page. The Rust backend keeps every network request on the
/// existing reverse-proxy/ECH-aware client.
class BangumiCollectionsRepository {
  BangumiCollectionsRepository({
    BangumiCollectionsBackend backend = const RustBangumiCollectionsBackend(),
    BangumiAuthManager? authManager,
    Future<bool> Function()? ensureAuthenticated,
    Future<String> Function()? apiHostResolver,
  }) : _backend = backend,
       _authManager = authManager ?? BangumiAuthManager(),
       _ensureAuthenticated = ensureAuthenticated,
       _apiHostResolver = apiHostResolver;

  final BangumiCollectionsBackend _backend;
  final BangumiAuthManager _authManager;
  final Future<bool> Function()? _ensureAuthenticated;
  final Future<String> Function()? _apiHostResolver;

  Future<List<BangumiUserCollection>> fetchPublic(String username) =>
      _fetchAll(username: username, authenticated: false);

  Future<List<BangumiUserCollection>> fetchMine(String username) async {
    await _requireAuthentication();
    return _fetchAll(username: username, authenticated: true);
  }

  /// Retained for callers that only ever change the status; [setStatus] is the
  /// name that says what the request actually is.
  Future<void> update({required int subjectId, required int type}) =>
      setStatus(subjectId: subjectId, type: type);

  Future<void> setStatus({required int subjectId, required int type}) async {
    await _requireAuthentication();
    await _backend.setStatus(subjectId: subjectId, type: type);
  }

  Future<void> patchMetadata({
    required int subjectId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    await _requireAuthentication();
    await _backend.patchMetadata(
      subjectId: subjectId,
      rate: rate,
      comment: comment,
      tags: tags,
      private: private,
    );
  }

  /// Creates or replaces a collection in one request, status and metadata
  /// together. Used when uploading a local-only entry, where a status POST
  /// followed by a metadata PATCH would leave a window with no metadata.
  Future<void> upsertWithMetadata({
    required int subjectId,
    required int type,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    await _requireAuthentication();
    await _backend.upsertWithMetadata(
      subjectId: subjectId,
      type: type,
      rate: rate,
      comment: comment,
      tags: tags,
      private: private,
    );
  }

  Future<BangumiUserCollection?> fetchMineOne({
    required String username,
    required int subjectId,
  }) async {
    await _requireAuthentication();
    final entry = await _backend.fetchMineOne(
      username: username,
      subjectId: subjectId,
    );
    return entry == null ? null : _mapEntry(entry);
  }

  Future<void> delete(int subjectId) async {
    await _requireAuthentication();
    await _backend.delete(subjectId: subjectId);
  }

  Future<int?> fetchType(int subjectId) async {
    await _requireAuthentication();
    return _backend.fetchType(subjectId: subjectId);
  }

  BangumiUserCollection _mapEntry(
    rust_bangumi.BangumiUserCollectionEntry entry,
  ) {
    return BangumiUserCollection(
      date: entry.updatedAt,
      comment: entry.comment,
      tags: entry.tags,
      subjectId: entry.subjectId,
      type: entry.collectionType,
      rate: entry.rate,
      private: entry.private,
      subject: BangumiUserCollectionSubject(
        id: entry.subjectId,
        name: entry.subjectName,
        nameCn: entry.subjectNameCn,
        shortSummary: entry.subjectShortSummary,
        score: entry.subjectScore,
        eps: entry.subjectEps,
        collectionTotal: entry.subjectCollectionTotal,
        images: rust_bangumi.BangumiImages(
          small: entry.imageSmall,
          grid: entry.imageGrid,
          large: entry.imageLarge,
          medium: entry.imageMedium,
          common: entry.imageCommon,
        ),
      ),
    );
  }

  Future<void> _requireAuthentication() async {
    if (_ensureAuthenticated != null) {
      if (!await _ensureAuthenticated()) {
        throw StateError('Bangumi login expired');
      }
      return;
    }
    if (!_authManager.isAuthenticated ||
        !await _authManager.ensureFreshToken()) {
      throw StateError('Bangumi login expired');
    }
  }

  Future<List<BangumiUserCollection>> _fetchAll({
    required String username,
    required bool authenticated,
  }) async {
    const pageSize = 100;
    final raw = <rust_bangumi.BangumiUserCollectionEntry>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = authenticated
          ? await _backend.fetchMyPage(
              username: username,
              limit: pageSize,
              offset: offset,
            )
          : await _backend.fetchPublicPage(
              username: username,
              limit: pageSize,
              offset: offset,
            );
      raw.addAll(page);
      if (page.length < pageSize) break;
    }

    final apiHost =
        await (_apiHostResolver?.call() ?? BangumiUrlRewriter.hostFor('api'));
    String rewrite(String url) {
      if (url.isEmpty) return url;
      return BangumiUrlRewriter.rewrite(
        url,
      ).replaceFirst('api.bgm.tv', apiHost);
    }

    return raw
        .map((entry) => _mapEntryWithImages(entry, rewrite))
        .toList(growable: false);
  }

  BangumiUserCollection _mapEntryWithImages(
    rust_bangumi.BangumiUserCollectionEntry entry,
    String Function(String) rewrite,
  ) {
    final mapped = _mapEntry(entry);
    return BangumiUserCollection(
      date: mapped.date,
      comment: mapped.comment,
      tags: mapped.tags,
      subjectId: mapped.subjectId,
      type: mapped.type,
      rate: mapped.rate,
      private: mapped.private,
      subject: BangumiUserCollectionSubject(
        id: mapped.subject.id,
        name: mapped.subject.name,
        nameCn: mapped.subject.nameCn,
        shortSummary: mapped.subject.shortSummary,
        score: mapped.subject.score,
        eps: mapped.subject.eps,
        collectionTotal: mapped.subject.collectionTotal,
        images: rust_bangumi.BangumiImages(
          small: rewrite(entry.imageSmall),
          grid: rewrite(entry.imageGrid),
          large: rewrite(entry.imageLarge),
          medium: rewrite(entry.imageMedium),
          common: rewrite(entry.imageCommon),
        ),
      ),
    );
  }
}
