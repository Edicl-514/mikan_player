import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/services/bangumi_data_service.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';

abstract interface class BangumiDetailsBackend {
  Future<AnimeInfo?> getCachedSubject(int subjectId);
  Future<AnimeInfo?> getSubject(int subjectId);
  Future<List<BangumiEpisode>> getCachedEpisodes(int subjectId);
  Future<List<BangumiCharacter>> getCachedCharacters(int subjectId);
  Future<List<BangumiRelatedSubject>> getCachedRelations(int subjectId);
  Future<List<BangumiPerson>> getCachedPersons(int subjectId);
  Future<List<BangumiEpisode>> getEpisodes(int subjectId);
  Future<List<BangumiCharacter>> getCharacters(int subjectId);
  Future<List<BangumiRelatedSubject>> getRelations(int subjectId);
  Future<List<BangumiPerson>> getPersons(int subjectId);
  Future<List<AnimeInfo>> fillDetails(List<AnimeInfo> animes);
  Future<void> cacheAnimeInfo(AnimeInfo anime);
  Future<List<BangumiDataSiteEntry>> getSites(String? bangumiId);
  Future<List<BangumiComment>> fetchComments({
    required int subjectId,
    required int page,
  });
}

class DefaultBangumiDetailsBackend implements BangumiDetailsBackend {
  const DefaultBangumiDetailsBackend();

  CacheManager get _cache => CacheManager.instance;

  @override
  Future<AnimeInfo?> getCachedSubject(int subjectId) =>
      _cache.getCachedSubject(subjectId);

  @override
  Future<AnimeInfo?> getSubject(int subjectId) => _cache.getSubject(subjectId);

  @override
  Future<List<BangumiEpisode>> getCachedEpisodes(int subjectId) =>
      _cache.getCachedEpisodes(subjectId);

  @override
  Future<List<BangumiCharacter>> getCachedCharacters(int subjectId) =>
      _cache.getCachedCharacters(subjectId);

  @override
  Future<List<BangumiRelatedSubject>> getCachedRelations(int subjectId) =>
      _cache.getCachedRelations(subjectId);

  @override
  Future<List<BangumiPerson>> getCachedPersons(int subjectId) =>
      _cache.getCachedPersons(subjectId);

  @override
  Future<List<BangumiEpisode>> getEpisodes(int subjectId) => _cache.getEpisodes(
    subjectId: subjectId,
    fetchFromNetwork: () => fetchBangumiEpisodes(subjectId: subjectId),
  );

  @override
  Future<List<BangumiCharacter>> getCharacters(int subjectId) =>
      _cache.getCharacters(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiCharacters(subjectId: subjectId),
      );

  @override
  Future<List<BangumiRelatedSubject>> getRelations(int subjectId) =>
      _cache.getRelations(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiRelations(subjectId: subjectId),
      );

  @override
  Future<List<BangumiPerson>> getPersons(int subjectId) => _cache.getPersons(
    subjectId: subjectId,
    fetchFromNetwork: () => fetchBangumiPersons(subjectId: subjectId),
  );

  @override
  Future<List<AnimeInfo>> fillDetails(List<AnimeInfo> animes) =>
      fillAnimeDetails(animes: animes);

  @override
  Future<void> cacheAnimeInfo(AnimeInfo anime) => _cache.cacheAnimeInfo(anime);

  @override
  Future<List<BangumiDataSiteEntry>> getSites(String? bangumiId) =>
      BangumiDataService.getSites(bangumiId);

  @override
  Future<List<BangumiComment>> fetchComments({
    required int subjectId,
    required int page,
  }) => fetchBangumiComments(subjectId: subjectId, page: page);
}

class BangumiDetailsLoadResult {
  final Map<String, dynamic>? subjectData;
  final List<BangumiEpisode> episodes;
  final List<BangumiCharacter> characters;
  final List<BangumiRelatedSubject> relations;
  final Map<String, int> personIdMap;
  final List<BangumiDataSiteEntry> sites;

  const BangumiDetailsLoadResult({
    required this.subjectData,
    required this.episodes,
    required this.characters,
    required this.relations,
    required this.personIdMap,
    required this.sites,
  });
}

class BangumiDetailsService {
  BangumiDetailsService._({BangumiDetailsBackend? backend})
    : _backend = backend ?? const DefaultBangumiDetailsBackend();

  static final BangumiDetailsService instance = BangumiDetailsService._();
  final BangumiDetailsBackend _backend;

  @visibleForTesting
  factory BangumiDetailsService.forTesting(BangumiDetailsBackend backend) =>
      BangumiDetailsService._(backend: backend);

  Future<Map<String, dynamic>?> loadCachedSubjectData(AnimeInfo anime) async {
    final subjectId = _parseSubjectId(anime.bangumiId);
    if (subjectId == null) return null;

    try {
      final cachedAnime = await _backend.getCachedSubject(subjectId);
      if (cachedAnime?.fullJson == null) return null;

      debugPrint('Subject primed from cache: $subjectId');
      return jsonDecode(cachedAnime!.fullJson!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error priming subject from cache: $e');
      return null;
    }
  }

  Future<BangumiDetailsLoadResult?> loadCachedInitialData({
    required AnimeInfo anime,
    bool includeSubjectDetails = true,
  }) async {
    final subjectId = _parseSubjectId(anime.bangumiId);
    if (subjectId == null) return null;

    try {
      final subjectFuture = includeSubjectDetails
          ? loadCachedSubjectData(anime)
          : Future<Map<String, dynamic>?>.value(null);
      final episodesFuture = _backend.getCachedEpisodes(subjectId);
      final charactersFuture = _backend.getCachedCharacters(subjectId);
      final relationsFuture = _backend.getCachedRelations(subjectId);
      final personsFuture = _backend.getCachedPersons(subjectId);
      final sitesFuture = _backend.getSites(anime.bangumiId);

      final results = await Future.wait<Object?>([
        subjectFuture,
        episodesFuture,
        charactersFuture,
        relationsFuture,
        personsFuture,
        sitesFuture,
      ]);

      final subjectData = results[0] as Map<String, dynamic>?;
      final cachedEpisodes = results[1] as List<BangumiEpisode>;
      final episodes = cachedEpisodes.isNotEmpty
          ? cachedEpisodes
          : _parseEpisodesFromSubjectData(subjectData);
      final characters = results[2] as List<BangumiCharacter>;
      final relations = results[3] as List<BangumiRelatedSubject>;
      final persons = results[4] as List<BangumiPerson>;
      final sites = results[5] as List<BangumiDataSiteEntry>;

      if (subjectData == null &&
          episodes.isEmpty &&
          characters.isEmpty &&
          relations.isEmpty &&
          persons.isEmpty &&
          sites.isEmpty) {
        return null;
      }

      return BangumiDetailsLoadResult(
        subjectData: subjectData,
        episodes: episodes,
        characters: characters,
        relations: relations,
        personIdMap: _buildPersonIdMap(
          characters: characters,
          persons: persons,
        ),
        sites: sites,
      );
    } catch (e) {
      debugPrint('Error loading cached initial data: $e');
      return null;
    }
  }

  Future<BangumiDetailsLoadResult> loadInitialData({
    required AnimeInfo anime,
    bool includeSubjectDetails = true,
  }) async {
    final subjectId = _parseSubjectId(anime.bangumiId);
    if (subjectId == null) {
      return const BangumiDetailsLoadResult(
        subjectData: null,
        episodes: [],
        characters: [],
        relations: [],
        personIdMap: {},
        sites: [],
      );
    }

    final subjectFuture = includeSubjectDetails
        ? _loadSubjectData(anime, subjectId)
        : Future<Map<String, dynamic>?>.value(null);
    final charactersFuture = _loadCharacters(subjectId);
    final relationsFuture = _loadRelations(subjectId);
    final personsFuture = _loadPersons(subjectId);
    final sitesFuture = _backend.getSites(anime.bangumiId);

    final results = await Future.wait<Object?>([
      subjectFuture,
      charactersFuture,
      relationsFuture,
      personsFuture,
      sitesFuture,
    ]);

    final subjectData = results[0] as Map<String, dynamic>?;
    final characters = results[1] as List<BangumiCharacter>;
    final relations = results[2] as List<BangumiRelatedSubject>;
    final persons = results[3] as List<BangumiPerson>;
    final sites = results[4] as List<BangumiDataSiteEntry>;

    final embeddedEpisodes = includeSubjectDetails
        ? _parseEpisodesFromSubjectData(subjectData)
        : const <BangumiEpisode>[];
    final episodes = embeddedEpisodes.isNotEmpty
        ? embeddedEpisodes
        : await _loadEpisodes(subjectId);

    return BangumiDetailsLoadResult(
      subjectData: subjectData,
      episodes: episodes,
      characters: characters,
      relations: relations,
      personIdMap: _buildPersonIdMap(characters: characters, persons: persons),
      sites: sites,
    );
  }

  Future<List<BangumiComment>> fetchCommentsPage({
    required int subjectId,
    required int page,
  }) async {
    return _backend.fetchComments(subjectId: subjectId, page: page);
  }

  int? _parseSubjectId(String? bangumiId) {
    if (bangumiId == null || bangumiId.isEmpty) return null;
    return int.tryParse(bangumiId);
  }

  Future<Map<String, dynamic>?> _loadSubjectData(
    AnimeInfo anime,
    int subjectId,
  ) async {
    try {
      final cachedAnime = await _backend.getSubject(subjectId);
      if (cachedAnime != null && cachedAnime.fullJson != null) {
        debugPrint('Subject loaded from cache: $subjectId');
        return jsonDecode(cachedAnime.fullJson!) as Map<String, dynamic>;
      }

      final details = await _backend.fillDetails([anime]);
      if (details.isEmpty) return null;

      final detail = details.first;
      if (detail.fullJson == null) return null;

      final data = jsonDecode(detail.fullJson!) as Map<String, dynamic>;
      unawaited(_backend.cacheAnimeInfo(detail));
      return data;
    } catch (e) {
      debugPrint('Error loading anime details: $e');
      return null;
    }
  }

  Future<List<BangumiEpisode>> _loadEpisodes(int subjectId) async {
    try {
      final allEpisodes = await _backend.getEpisodes(subjectId);
      return allEpisodes;
    } catch (e) {
      debugPrint('Error fetching episodes: $e');
      return [];
    }
  }

  List<BangumiEpisode> _parseEpisodesFromSubjectData(
    Map<String, dynamic>? subjectData,
  ) {
    final episodes = subjectData?['episodes'];
    if (episodes is! List) return const [];

    final parsed = <BangumiEpisode>[];
    for (final item in episodes) {
      if (item is! Map) continue;

      final rawType = item['type'];
      final type = rawType is int
          ? rawType
          : int.tryParse(rawType?.toString() ?? '') ?? 0;
      if (type != 0) continue;

      final id = _readInt(item['id']);
      if (id == null) continue;

      final name = item['name']?.toString() ?? '';
      final nameCn = item['name_cn']?.toString() ?? '';
      final description = item['description']?.toString() ?? '';
      final airdate = item['airdate']?.toString() ?? '';
      final duration = item['duration']?.toString() ?? '';
      final sort = _readDouble(item['sort']) ?? 0.0;

      parsed.add(
        BangumiEpisode(
          id: id,
          name: name,
          nameCn: nameCn,
          description: description,
          airdate: airdate,
          duration: duration,
          sort: sort,
        ),
      );
    }

    return parsed.withoutPhantomEpisodes();
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<List<BangumiCharacter>> _loadCharacters(int subjectId) async {
    try {
      return await _backend.getCharacters(subjectId);
    } catch (e) {
      debugPrint('Error fetching characters: $e');
      return [];
    }
  }

  Future<List<BangumiRelatedSubject>> _loadRelations(int subjectId) async {
    try {
      return await _backend.getRelations(subjectId);
    } catch (e) {
      debugPrint('Error fetching relations: $e');
      return [];
    }
  }

  Future<List<BangumiPerson>> _loadPersons(int subjectId) async {
    try {
      return await _backend.getPersons(subjectId);
    } catch (e) {
      debugPrint('Error fetching persons: $e');
      return [];
    }
  }

  Map<String, int> _buildPersonIdMap({
    required List<BangumiCharacter> characters,
    required List<BangumiPerson> persons,
  }) {
    final personMap = <String, int>{};

    for (final character in characters) {
      for (final actor in character.actors) {
        if (actor.name.isNotEmpty && actor.id != 0) {
          personMap.putIfAbsent(actor.name, () => actor.id.toInt());
        }
      }
    }

    for (final person in persons) {
      if (person.name.isNotEmpty && person.id != 0) {
        personMap.putIfAbsent(person.name, () => person.id.toInt());
      }
    }

    return personMap;
  }
}
