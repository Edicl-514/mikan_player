import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/services/bangumi_details_service.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/bangumi_collection_cache.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';

/// Injectable data seam for [BangumiDetailsController].
///
/// Production wires [BangumiDetailsService]; tests pass fakes that complete out
/// of order so generation-token / dispose semantics are deterministic.
class BangumiDetailsDataPort {
  const BangumiDetailsDataPort({
    required this.loadCachedInitialData,
    required this.loadInitialData,
    required this.fetchCommentsPage,
  });

  final Future<BangumiDetailsLoadResult?> Function({
    required AnimeInfo anime,
    bool includeSubjectDetails,
  })
  loadCachedInitialData;

  final Future<BangumiDetailsLoadResult> Function({
    required AnimeInfo anime,
    bool includeSubjectDetails,
  })
  loadInitialData;

  final Future<BangumiCommentsPage> Function({
    required int subjectId,
    required int page,
  })
  fetchCommentsPage;
}

/// Injectable local-favorites seam. SnackBars stay on the page.
class BangumiDetailsFavoritesPort {
  const BangumiDetailsFavoritesPort({
    required this.getFavoriteType,
    required this.addFavorite,
    required this.removeFavorite,
    this.fetchCollection,
    this.patchMetadata,
    this.readLocalCollection,
    this.refreshCollectionInBackground,
  });

  final Future<int?> Function(int bangumiId) getFavoriteType;
  final Future<void> Function({
    required int bangumiId,
    required String title,
    required String coverUrl,
    required double score,
    required int type,
  })
  addFavorite;
  final Future<void> Function(int bangumiId) removeFavorite;
  final Future<BangumiUserCollection?> Function({
    required String username,
    required int bangumiId,
  })?
  fetchCollection;
  final Future<void> Function({
    required int bangumiId,
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  })?
  patchMetadata;

  /// Reads the locally stored collection. This is the editor's read path: it
  /// returns immediately so opening the panel costs no network round trip.
  final Future<LocalFavorite?> Function(int bangumiId)? readLocalCollection;

  /// Refreshes the local copy from Bangumi in the background, completing with
  /// `true` when the stored row changed. Failures are absorbed — a stale panel
  /// is better than a blocked one.
  final Future<bool> Function(int bangumiId)? refreshCollectionInBackground;
}

/// Phase 4 bangumi-details responsibility split: request state, comment paging,
/// and favorite-status ownership.
///
/// Pure Dart aside from [foundation] for `debugPrint` / optional
/// [onStateChanged]. No `BuildContext`, scroll controllers, navigation, or
/// dialogs. The page keeps layout and UI side effects; this controller owns
/// generation tokens so late cache/network/comment/favorite completions cannot
/// mutate a disposed or replaced instance.
class BangumiDetailsController {
  BangumiDetailsController({
    required AnimeInfo anime,
    required BangumiDetailsDataPort dataPort,
    required BangumiDetailsFavoritesPort favoritesPort,
    void Function()? onStateChanged,
  }) : _anime = anime,
       _dataPort = dataPort,
       _favoritesPort = favoritesPort,
       _onStateChanged = onStateChanged;

  AnimeInfo _anime;
  final BangumiDetailsDataPort _dataPort;
  final BangumiDetailsFavoritesPort _favoritesPort;
  final void Function()? _onStateChanged;

  Map<String, dynamic>? _subjectData;
  List<BangumiEpisode>? _episodes;
  List<BangumiCharacter>? _characters;
  List<BangumiRelatedSubject>? _relations;
  List<BangumiComment>? _comments;
  List<BangumiDataSiteEntry>? _sites;
  Map<String, int> _personIdMap = <String, int>{};

  bool _isLoadingEpisodes = false;
  bool _isLoadingCharacters = false;
  bool _isLoadingRelations = false;
  bool _isLoadingComments = false;
  bool _hasRequestedComments = false;
  int? _localFavoriteType;

  int _commentPage = 1;
  int? _commentsTotal;
  bool _hasMoreComments = true;
  bool _isLoadingMoreComments = false;

  // Shared generation for cache-prime + network refresh so they can both apply
  // during the initial concurrent load. Bumped only on dispose / subject reset.
  int _detailsGeneration = 0;
  // Invalidates in-flight first-page and load-more comment work when details
  // refresh resets comments, or on dispose.
  int _commentsToken = 0;
  int _favoriteToken = 0;
  bool _disposed = false;

  // ── Read-only views ────────────────────────────────────────────────────────

  AnimeInfo get anime => _anime;

  Map<String, dynamic>? get subjectData => _subjectData;

  List<BangumiEpisode>? get episodes => _episodes == null
      ? null
      : UnmodifiableListView<BangumiEpisode>(_episodes!);

  List<BangumiCharacter>? get characters => _characters == null
      ? null
      : UnmodifiableListView<BangumiCharacter>(_characters!);

  List<BangumiRelatedSubject>? get relations => _relations == null
      ? null
      : UnmodifiableListView<BangumiRelatedSubject>(_relations!);

  List<BangumiComment>? get comments => _comments == null
      ? null
      : UnmodifiableListView<BangumiComment>(_comments!);

  List<BangumiDataSiteEntry>? get sites => _sites == null
      ? null
      : UnmodifiableListView<BangumiDataSiteEntry>(_sites!);

  Map<String, int> get personIdMap =>
      UnmodifiableMapView<String, int>(_personIdMap);

  bool get isLoadingEpisodes => _isLoadingEpisodes;
  bool get isLoadingCharacters => _isLoadingCharacters;
  bool get isLoadingRelations => _isLoadingRelations;
  bool get isLoadingComments => _isLoadingComments;
  bool get hasRequestedComments => _hasRequestedComments;
  bool get isLocalFavorite => _localFavoriteType != null;
  int? get localFavoriteType => _localFavoriteType;
  int get commentPage => _commentPage;
  bool get hasMoreComments => _hasMoreComments;
  bool get isLoadingMoreComments => _isLoadingMoreComments;
  bool get isDisposed => _disposed;

  bool get hasSubjectDetails => _subjectData != null;

  // ── Seed / lifecycle ───────────────────────────────────────────────────────

  /// Decodes [AnimeInfo.fullJson] into [subjectData] when present.
  /// Mirrors the page's former `_parseData`.
  void seedFromAnimeFullJson() {
    if (_disposed) return;
    final fullJson = _anime.fullJson;
    if (fullJson == null) return;
    try {
      _subjectData = jsonDecode(fullJson) as Map<String, dynamic>;
      _notify();
    } catch (e) {
      debugPrint('Error parsing fullJson: $e');
    }
  }

  /// Rebinds the controller to a different anime identity and invalidates every
  /// in-flight request. Visible lists are cleared so a replacement cannot flash
  /// the previous subject's data under the new identity.
  void resetForAnime(AnimeInfo anime) {
    if (_disposed) return;
    _anime = anime;
    _detailsGeneration++;
    _commentsToken++;
    _favoriteToken++;
    _subjectData = null;
    _episodes = null;
    _characters = null;
    _relations = null;
    _comments = null;
    _sites = null;
    _personIdMap = <String, int>{};
    _isLoadingEpisodes = false;
    _isLoadingCharacters = false;
    _isLoadingRelations = false;
    _isLoadingComments = false;
    _hasRequestedComments = false;
    _localFavoriteType = null;
    _commentPage = 1;
    _commentsTotal = null;
    _hasMoreComments = true;
    _isLoadingMoreComments = false;
    _notify();
  }

  void clearForDispose() {
    _disposed = true;
    _detailsGeneration++;
    _commentsToken++;
    _favoriteToken++;
  }

  // ── Details load ───────────────────────────────────────────────────────────

  /// Cache-first prime. Concurrent with [refreshFromNetwork] during init; both
  /// share [ _detailsGeneration ] so neither invalidates the other.
  Future<void> primeFromCache() async {
    if (_disposed) return;
    final generation = _detailsGeneration;
    final includeSubjectDetails = !hasSubjectDetails;

    final result = await _dataPort.loadCachedInitialData(
      anime: _anime,
      includeSubjectDetails: includeSubjectDetails,
    );

    if (!_isDetailsCurrent(generation) || result == null) return;

    _applyCachedResult(result);
    _notify();
  }

  /// Network (service-layer cache-then-network) refresh. Resets list slots and
  /// comment paging before the await, matching former `_fetchBangumiData`.
  Future<void> refreshFromNetwork() async {
    if (_disposed) return;

    final subjectIdStr = _anime.bangumiId;
    if (subjectIdStr == null) {
      _isLoadingEpisodes = false;
      _isLoadingCharacters = false;
      _isLoadingRelations = false;
      _isLoadingComments = false;
      _notify();
      return;
    }

    final generation = _detailsGeneration;
    final includeSubjectDetails = !hasSubjectDetails;

    // Reset list/comment slots before the network await. Invalidate in-flight
    // comment work so a late first-page cannot repopulate under a refresh.
    _commentsToken++;
    _isLoadingEpisodes = true;
    _isLoadingCharacters = true;
    _isLoadingRelations = true;
    _isLoadingComments = false;
    _hasRequestedComments = false;
    _commentPage = 1;
    _commentsTotal = null;
    _hasMoreComments = true;
    _isLoadingMoreComments = false;
    _episodes = null;
    _characters = null;
    _relations = null;
    _comments = null;
    _personIdMap = <String, int>{};
    _notify();

    final result = await _dataPort.loadInitialData(
      anime: _anime,
      includeSubjectDetails: includeSubjectDetails,
    );

    if (!_isDetailsCurrent(generation)) return;

    _applyNetworkResult(result);
    _notify();
  }

  // ── Comments ───────────────────────────────────────────────────────────────

  Future<void> ensureCommentsLoaded() async {
    if (_disposed) return;
    if (_hasRequestedComments || _isLoadingComments) return;

    final subjectId = _parseSubjectId(_anime.bangumiId);
    if (subjectId == null) return;

    final token = _commentsToken;
    _hasRequestedComments = true;
    _isLoadingComments = true;
    _commentPage = 1;
    _hasMoreComments = true;
    _isLoadingMoreComments = false;
    _comments = null;
    _notify();

    try {
      final commentsPage = await _dataPort.fetchCommentsPage(
        subjectId: subjectId,
        page: 1,
      );
      if (!_isCommentsCurrent(token)) return;
      _commentsTotal = commentsPage.total;
      _comments = List<BangumiComment>.from(commentsPage.comments);
      _hasMoreComments = _hasMoreAfterPage(commentsPage.comments.length);
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      if (!_isCommentsCurrent(token)) return;
      _comments = <BangumiComment>[];
      _hasMoreComments = false;
    } finally {
      if (_isCommentsCurrent(token)) {
        _isLoadingComments = false;
        _notify();
      }
    }
  }

  Future<void> loadMoreComments() async {
    if (_disposed) return;
    if (_isLoadingMoreComments || !_hasMoreComments || !_hasRequestedComments) {
      return;
    }

    final subjectId = _parseSubjectId(_anime.bangumiId);
    if (subjectId == null) {
      _isLoadingMoreComments = false;
      _notify();
      return;
    }

    final token = _commentsToken;
    _isLoadingMoreComments = true;
    _notify();

    try {
      final commentsPage = await _dataPort.fetchCommentsPage(
        subjectId: subjectId,
        page: _commentPage + 1,
      );
      if (!_isCommentsCurrent(token)) return;

      _commentsTotal = commentsPage.total ?? _commentsTotal;
      if (commentsPage.comments.isEmpty) {
        _hasMoreComments = false;
      } else {
        final merged = <BangumiComment>[...?_comments, ...commentsPage.comments];
        _comments = merged;
        _commentPage++;
        _hasMoreComments = _hasMoreAfterPage(merged.length);
      }
      _isLoadingMoreComments = false;
      _notify();
    } catch (e) {
      debugPrint('Error loading more comments: $e');
      if (!_isCommentsCurrent(token)) return;
      _isLoadingMoreComments = false;
      _notify();
    }
  }

  bool _hasMoreAfterPage(int loadedCount) {
    final total = _commentsTotal;
    return total == null ? loadedCount > 0 : loadedCount < total;
  }

  // ── Favorites ──────────────────────────────────────────────────────────────

  Future<void> refreshFavoriteStatus() async {
    if (_disposed) return;
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return;

    final token = _favoriteToken;
    final favoriteType = await _favoritesPort.getFavoriteType(id);
    if (!_isFavoriteCurrent(token)) return;
    _localFavoriteType = favoriteType;
    _notify();
  }

  /// Adds a local favorite or updates its Bangumi-compatible collection type.
  Future<bool> setLocalFavoriteType({
    required String title,
    required String coverUrl,
    required double score,
    required int type,
  }) async {
    if (!LocalFavoriteType.isValid(type)) {
      throw ArgumentError.value(type, 'type', 'Unknown favorite type');
    }
    if (_disposed) return false;
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return false;

    final token = _favoriteToken;
    await _favoritesPort.addFavorite(
      bangumiId: id,
      title: title,
      coverUrl: coverUrl,
      score: score,
      type: type,
    );

    if (!_isFavoriteCurrent(token)) return false;

    final favoriteType = await _favoritesPort.getFavoriteType(id);
    if (!_isFavoriteCurrent(token)) return false;
    _localFavoriteType = favoriteType;
    _notify();
    return favoriteType == type;
  }

  /// Removes the local favorite and refreshes the controller's status.
  Future<bool> removeLocalFavorite() async {
    if (_disposed) return false;
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return false;

    final token = _favoriteToken;
    await _favoritesPort.removeFavorite(id);
    if (!_isFavoriteCurrent(token)) return false;

    final favoriteType = await _favoritesPort.getFavoriteType(id);
    if (!_isFavoriteCurrent(token)) return false;
    _localFavoriteType = favoriteType;
    _notify();
    return favoriteType == null;
  }

  /// Locally stored collection values for this subject, or `null` when it is not
  /// collected. Never hits the network, so the editor can open immediately.
  Future<LocalFavorite?> readLocalCollection() async {
    if (_disposed || _favoritesPort.readLocalCollection == null) return null;
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return null;
    return _favoritesPort.readLocalCollection!(id);
  }

  /// Refreshes this subject from Bangumi in the background and republishes the
  /// local status if anything changed.
  ///
  /// Fire-and-forget by design: the UI is already showing local state, so a
  /// failure here is silent rather than an error the user has to dismiss.
  Future<void> refreshCollectionInBackground() async {
    if (_disposed || _favoritesPort.refreshCollectionInBackground == null) {
      return;
    }
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return;

    final token = _favoriteToken;
    final changed = await _favoritesPort.refreshCollectionInBackground!(id);
    if (!changed || !_isFavoriteCurrent(token)) return;

    final favoriteType = await _favoritesPort.getFavoriteType(id);
    if (!_isFavoriteCurrent(token)) return;
    _localFavoriteType = favoriteType;
    _notify();
  }

  Future<void> patchRemoteMetadata({
    int? rate,
    String? comment,
    List<String>? tags,
    bool? private,
  }) async {
    if (_disposed || _favoritesPort.patchMetadata == null) return;
    final id = _parseSubjectId(_anime.bangumiId);
    if (id == null) return;
    await _favoritesPort.patchMetadata!(
      bangumiId: id,
      rate: rate,
      comment: comment,
      tags: tags,
      private: private,
    );
  }

  // ── Invariants ─────────────────────────────────────────────────────────────

  List<String> validateInvariants() {
    final errors = <String>[];
    if (_commentPage < 1) {
      errors.add('commentPage must be >= 1 (got $_commentPage)');
    }
    if (_isLoadingMoreComments && !_hasRequestedComments) {
      errors.add('isLoadingMoreComments requires hasRequestedComments');
    }
    if (_isLoadingMoreComments && !_hasMoreComments) {
      errors.add('isLoadingMoreComments requires hasMoreComments');
    }
    return errors;
  }

  // ── Internal apply ─────────────────────────────────────────────────────────

  void _applyCachedResult(BangumiDetailsLoadResult result) {
    final sortedCharacters = sortCharactersByRole(result.characters);
    _subjectData ??= result.subjectData;
    // Cache and network loads are intentionally concurrent. A late cache read
    // may fill an empty slot, but must never overwrite fresher non-empty data
    // that the network path has already committed.
    if (result.episodes.isNotEmpty &&
        (_episodes == null || _episodes!.isEmpty)) {
      _episodes = List<BangumiEpisode>.from(result.episodes);
      _isLoadingEpisodes = false;
    }
    if (sortedCharacters.isNotEmpty &&
        (_characters == null || _characters!.isEmpty)) {
      _characters = sortedCharacters;
      _isLoadingCharacters = false;
    }
    if (result.relations.isNotEmpty &&
        (_relations == null || _relations!.isEmpty)) {
      _relations = List<BangumiRelatedSubject>.from(result.relations);
      _isLoadingRelations = false;
    }
    if (result.sites.isNotEmpty && (_sites == null || _sites!.isEmpty)) {
      _sites = sortSitesByKind(result.sites);
    }
    _mergePersonIdMap(result.personIdMap);
  }

  void _applyNetworkResult(BangumiDetailsLoadResult result) {
    final sortedCharacters = sortCharactersByRole(result.characters);
    _subjectData ??= result.subjectData;
    if (result.episodes.isNotEmpty || _episodes == null || _episodes!.isEmpty) {
      _episodes = List<BangumiEpisode>.from(result.episodes);
    }
    if (sortedCharacters.isNotEmpty ||
        _characters == null ||
        _characters!.isEmpty) {
      _characters = sortedCharacters;
    }
    if (result.relations.isNotEmpty ||
        _relations == null ||
        _relations!.isEmpty) {
      _relations = List<BangumiRelatedSubject>.from(result.relations);
    }
    if (result.sites.isNotEmpty) {
      _sites = sortSitesByKind(result.sites);
    }
    _mergePersonIdMap(result.personIdMap);
    _isLoadingEpisodes = false;
    _isLoadingCharacters = false;
    _isLoadingRelations = false;
  }

  void _mergePersonIdMap(Map<String, int> entries) {
    for (final entry in entries.entries) {
      final id = entry.value;
      final rawName = entry.key.trim();
      if (id == 0 || rawName.isEmpty) continue;

      _personIdMap.putIfAbsent(rawName, () => id);

      final collapsedWhitespace = rawName.replaceAll(
        RegExp(r'\s+', unicode: true),
        ' ',
      );
      if (collapsedWhitespace != rawName) {
        _personIdMap.putIfAbsent(collapsedWhitespace, () => id);
      }
    }
  }

  bool _isDetailsCurrent(int generation) =>
      !_disposed && generation == _detailsGeneration;

  bool _isCommentsCurrent(int token) => !_disposed && token == _commentsToken;

  bool _isFavoriteCurrent(int token) => !_disposed && token == _favoriteToken;

  void _notify() {
    if (_disposed) return;
    _onStateChanged?.call();
  }

  static int? _parseSubjectId(String? bangumiId) {
    if (bangumiId == null || bangumiId.isEmpty) return null;
    return int.tryParse(bangumiId);
  }
}

/// Character role sort priority used when applying load results.
/// Mirrors the page's former `_characterRolePriority`.
int characterRolePriority(BangumiCharacter character) {
  final roleName = character.roleName;
  // i18n-ignore: upstream Bangumi role token used for matching
  if (roleName.contains('主角')) return 0;
  // i18n-ignore: upstream Bangumi role token used for matching
  if (roleName.contains('配角')) return 1;
  return 2;
}

List<BangumiCharacter> sortCharactersByRole(List<BangumiCharacter> characters) {
  final sorted = [...characters]
    ..sort((a, b) {
      final pa = characterRolePriority(a);
      final pb = characterRolePriority(b);
      return pa != pb ? pa.compareTo(pb) : a.name.compareTo(b.name);
    });
  return sorted;
}

List<BangumiDataSiteEntry> sortSitesByKind(List<BangumiDataSiteEntry> sites) {
  if (sites.isEmpty) return sites;
  return [...sites]..sort(
    (a, b) => siteKindPriority(a.kind).compareTo(siteKindPriority(b.kind)),
  );
}

/// Production wiring for [BangumiDetailsService.instance].
BangumiDetailsDataPort bangumiDetailsServiceDataPort([
  BangumiDetailsService? service,
]) {
  final s = service ?? BangumiDetailsService.instance;
  return BangumiDetailsDataPort(
    loadCachedInitialData: ({required anime, includeSubjectDetails = true}) =>
        s.loadCachedInitialData(
          anime: anime,
          includeSubjectDetails: includeSubjectDetails,
        ),
    loadInitialData: ({required anime, includeSubjectDetails = true}) =>
        s.loadInitialData(
          anime: anime,
          includeSubjectDetails: includeSubjectDetails,
        ),
    fetchCommentsPage: ({required subjectId, required page}) =>
        s.fetchCommentsPage(subjectId: subjectId, page: page),
  );
}

/// Production wiring for [FavoritesManager].
///
/// Reads are local-only: opening a details page or the collection editor makes
/// no network request. A stale local row is refreshed in the background by
/// [BangumiCollectionCache], which notifies through
/// [BangumiDetailsFavoritesPort.refreshCollectionInBackground].
///
/// Writes apply locally first and go to Bangumi through [BangumiSyncQueue], so
/// editing a collection works offline and survives a restart.
BangumiDetailsFavoritesPort bangumiDetailsFavoritesPort(
  FavoritesManager Function() managerFactory, {
  BangumiCollectionCache? cache,
}) {
  final collectionCache = cache ?? BangumiCollectionCache.instance;
  return BangumiDetailsFavoritesPort(
    getFavoriteType: (id) => managerFactory().getFavoriteType(id),
    readLocalCollection: (id) => managerFactory().getFavorite(id),
    refreshCollectionInBackground: collectionCache.refreshAndReportChange,
    addFavorite:
        ({
          required bangumiId,
          required title,
          required coverUrl,
          required score,
          required type,
        }) => collectionCache.setStatus(
          bangumiId: bangumiId,
          title: title,
          coverUrl: coverUrl,
          score: score,
          type: type,
        ),
    removeFavorite: (id) => collectionCache.remove(id),
    fetchCollection: ({required username, required bangumiId}) =>
        collectionCache.fetchRemote(username: username, subjectId: bangumiId),
    patchMetadata: ({required bangumiId, rate, comment, tags, private}) =>
        collectionCache.saveMetadata(
          bangumiId: bangumiId,
          rate: rate,
          comment: comment,
          tags: tags,
          private: private,
        ),
  );
}
