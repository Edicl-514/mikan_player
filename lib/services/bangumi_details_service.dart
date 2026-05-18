import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/cache/cache_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';

class BangumiDetailsLoadResult {
  final Map<String, dynamic>? subjectData;
  final List<BangumiEpisode> episodes;
  final List<BangumiCharacter> characters;
  final List<BangumiRelatedSubject> relations;
  final Map<String, int> personIdMap;

  const BangumiDetailsLoadResult({
    required this.subjectData,
    required this.episodes,
    required this.characters,
    required this.relations,
    required this.personIdMap,
  });
}

class BangumiDetailsService {
  BangumiDetailsService._();

  static final BangumiDetailsService instance = BangumiDetailsService._();

  CacheManager get _cache => CacheManager.instance;

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
      );
    }

    final subjectFuture = includeSubjectDetails
        ? _loadSubjectData(anime, subjectId)
        : Future<Map<String, dynamic>?>.value(null);
    final episodesFuture = _loadEpisodes(subjectId);
    final charactersFuture = _loadCharacters(subjectId);
    final relationsFuture = _loadRelations(subjectId);
    final personsFuture = _loadPersons(subjectId);

    final results = await Future.wait<Object?>([
      subjectFuture,
      episodesFuture,
      charactersFuture,
      relationsFuture,
      personsFuture,
    ]);

    final subjectData = results[0] as Map<String, dynamic>?;
    final episodes = results[1] as List<BangumiEpisode>;
    final characters = results[2] as List<BangumiCharacter>;
    final relations = results[3] as List<BangumiRelatedSubject>;
    final persons = results[4] as List<BangumiPerson>;

    return BangumiDetailsLoadResult(
      subjectData: subjectData,
      episodes: episodes,
      characters: characters,
      relations: relations,
      personIdMap: _buildPersonIdMap(characters: characters, persons: persons),
    );
  }

  Future<List<BangumiComment>> fetchCommentsPage({
    required int subjectId,
    required int page,
  }) async {
    return fetchBangumiComments(subjectId: subjectId, page: page);
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
      final cachedAnime = await _cache.getSubject(subjectId);
      if (cachedAnime != null && cachedAnime.fullJson != null) {
        debugPrint('Subject loaded from cache: $subjectId');
        return jsonDecode(cachedAnime.fullJson!) as Map<String, dynamic>;
      }

      final details = await fillAnimeDetails(animes: [anime]);
      if (details.isEmpty) return null;

      final detail = details.first;
      if (detail.fullJson == null) return null;

      final data = jsonDecode(detail.fullJson!) as Map<String, dynamic>;
      unawaited(_cache.cacheAnimeInfo(detail));
      return data;
    } catch (e) {
      debugPrint('Error loading anime details: $e');
      return null;
    }
  }

  Future<List<BangumiEpisode>> _loadEpisodes(int subjectId) async {
    try {
      final allEpisodes = await _cache.getEpisodes(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiEpisodes(subjectId: subjectId),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return allEpisodes.where((ep) {
        if (ep.airdate.isEmpty) return true;
        try {
          final date = DateTime.parse(ep.airdate);
          final episodeDate = DateTime(date.year, date.month, date.day);
          return !episodeDate.isAfter(today);
        } catch (_) {
          return true;
        }
      }).toList();
    } catch (e) {
      debugPrint('Error fetching episodes: $e');
      return [];
    }
  }

  Future<List<BangumiCharacter>> _loadCharacters(int subjectId) async {
    try {
      return await _cache.getCharacters(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiCharacters(subjectId: subjectId),
      );
    } catch (e) {
      debugPrint('Error fetching characters: $e');
      return [];
    }
  }

  Future<List<BangumiRelatedSubject>> _loadRelations(int subjectId) async {
    try {
      return await _cache.getRelations(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiRelations(subjectId: subjectId),
      );
    } catch (e) {
      debugPrint('Error fetching relations: $e');
      return [];
    }
  }

  Future<List<BangumiPerson>> _loadPersons(int subjectId) async {
    try {
      return await _cache.getPersons(
        subjectId: subjectId,
        fetchFromNetwork: () => fetchBangumiPersons(subjectId: subjectId),
      );
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
