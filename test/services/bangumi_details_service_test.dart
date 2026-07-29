import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_details_service.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';

void main() {
  late FakeBangumiDetailsBackend backend;
  late BangumiDetailsService service;

  setUp(() {
    backend = FakeBangumiDetailsBackend();
    service = BangumiDetailsService.forTesting(backend);
  });

  test(
    'invalid subject ids return empty results without backend calls',
    () async {
      const anime = AnimeInfo(title: 'No id', bangumiId: 'bad', tags: []);

      expect(await service.loadCachedSubjectData(anime), isNull);
      expect(await service.loadCachedInitialData(anime: anime), isNull);
      final result = await service.loadInitialData(anime: anime);

      expect(result.subjectData, isNull);
      expect(result.episodes, isEmpty);
      expect(result.characters, isEmpty);
      expect(result.relations, isEmpty);
      expect(result.personIdMap, isEmpty);
      expect(result.sites, isEmpty);
      expect(backend.calls, isEmpty);
    },
  );

  test(
    'cached subject returns decoded map and malformed payload returns null',
    () async {
      backend.cachedSubject = animeInfo(
        fullJson: jsonEncode({'name': 'cached', 'unicode': '动画🎬'}),
      );

      expect(await service.loadCachedSubjectData(animeInfo()), {
        'name': 'cached',
        'unicode': '动画🎬',
      });

      backend.cachedSubject = animeInfo(fullJson: '[1,2,3]');
      expect(await service.loadCachedSubjectData(animeInfo()), isNull);
      backend.cachedSubject = animeInfo(fullJson: '{broken');
      expect(await service.loadCachedSubjectData(animeInfo()), isNull);
    },
  );

  test(
    'cached initial data parses embedded episodes and builds person map',
    () async {
      backend.cachedSubject = animeInfo(
        fullJson: jsonEncode({
          'title': 'Subject',
          'episodes': [
            {'id': 11, 'type': 0, 'name': '', 'name_cn': '', 'sort': 1},
            {
              'id': '10',
              'type': '0',
              'name': 'Episode 1',
              'name_cn': '第一话',
              'description': 'desc',
              'airdate': '2026-01-01',
              'duration': '24m',
              'sort': '1.0',
            },
            {'id': 10, 'type': 0, 'name': 'duplicate id', 'sort': 2},
            {'id': 12, 'type': 1, 'name': 'Special', 'sort': 1.5},
            {'id': 'bad', 'type': 0, 'name': 'Bad id', 'sort': 2},
          ],
        }),
      );
      backend.cachedCharacters = const [
        BangumiCharacter(
          id: 1,
          name: 'Character',
          roleName: '主角',
          actors: [BangumiActor(id: 20, name: 'Shared Person')],
        ),
      ];
      backend.cachedPersons = const [
        BangumiPerson(
          id: 30,
          name: 'Shared Person',
          relation: '声优',
          career: [],
          personType: 1,
        ),
        BangumiPerson(
          id: 31,
          name: 'Staff',
          relation: '导演',
          career: [],
          personType: 1,
        ),
      ];
      backend.sites = const [
        BangumiDataSiteEntry(
          site: 'mikan',
          title: 'Mikan',
          url: 'https://mikan.example',
          kind: 'onair',
        ),
      ];

      final result = await service.loadCachedInitialData(anime: animeInfo());

      expect(result, isNotNull);
      expect(result!.episodes, hasLength(1));
      expect(result.episodes.single.id, 10);
      expect(result.episodes.single.nameCn, '第一话');
      expect(result.personIdMap, {'Shared Person': 20, 'Staff': 31});
      expect(result.sites, backend.sites);
    },
  );

  test(
    'cached episodes take precedence over embedded subject episodes',
    () async {
      backend.cachedSubject = animeInfo(
        fullJson: jsonEncode({
          'episodes': [
            {'id': 1, 'type': 0, 'name': 'embedded', 'sort': 1},
          ],
        }),
      );
      backend.cachedEpisodes = [episode(2, 'cached', 2)];

      final result = await service.loadCachedInitialData(anime: animeInfo());

      expect(result!.episodes.single.id, 2);
      expect(result.episodes.single.name, 'cached');
    },
  );

  test('all-empty cached data returns null', () async {
    expect(await service.loadCachedInitialData(anime: animeInfo()), isNull);
  });

  test(
    'initial load uses cached subject and embedded episodes without episode fetch',
    () async {
      backend.subject = animeInfo(
        fullJson: jsonEncode({
          'episodes': [
            {'id': 3, 'type': 0, 'name': 'embedded', 'sort': 3},
          ],
        }),
      );

      final result = await service.loadInitialData(anime: animeInfo());

      expect(result.episodes.single.id, 3);
      expect(backend.calls, isNot(contains('getEpisodes')));
      expect(
        backend.calls,
        containsAll([
          'getSubject',
          'getCharacters',
          'getRelations',
          'getPersons',
          'getSites',
        ]),
      );
    },
  );

  test(
    'network detail is decoded, cached, and falls back to episode endpoint',
    () async {
      backend.filled = [
        animeInfo(fullJson: jsonEncode({'title': 'network'})),
      ];
      backend.episodes = [episode(4, 'network episode', 4)];

      final result = await service.loadInitialData(anime: animeInfo());
      await pumpEventQueue();

      expect(result.subjectData, {'title': 'network'});
      expect(result.episodes.single.id, 4);
      expect(backend.cachedWrites, hasLength(1));
      expect(backend.calls, contains('fillDetails'));
      expect(backend.calls, contains('getEpisodes'));
    },
  );

  test(
    'excluding subject details still loads episodes and never fills details',
    () async {
      backend.episodes = [episode(5, 'episode only', 5)];

      final result = await service.loadInitialData(
        anime: animeInfo(),
        includeSubjectDetails: false,
      );

      expect(result.subjectData, isNull);
      expect(result.episodes.single.id, 5);
      expect(backend.calls, isNot(contains('getSubject')));
      expect(backend.calls, isNot(contains('fillDetails')));
    },
  );

  test(
    'component failures degrade to partial data instead of failing whole load',
    () async {
      backend.subjectError = StateError('subject failed');
      backend.charactersError = StateError('characters failed');
      backend.relationsError = StateError('relations failed');
      backend.personsError = StateError('persons failed');
      backend.episodesError = StateError('episodes failed');
      backend.sites = const [
        BangumiDataSiteEntry(
          site: 'only',
          title: 'Only surviving data',
          url: 'https://example.test',
          kind: 'info',
        ),
      ];

      final result = await service.loadInitialData(anime: animeInfo());

      expect(result.subjectData, isNull);
      expect(result.episodes, isEmpty);
      expect(result.characters, isEmpty);
      expect(result.relations, isEmpty);
      expect(result.personIdMap, isEmpty);
      expect(result.sites, backend.sites);
    },
  );

  test('comments preserve page arguments and backend errors', () async {
    backend.commentsPage = const BangumiCommentsPage(
      comments: [
        BangumiComment(
          id: 1,
          userId: 'user',
          userName: 'user',
          rate: 8,
          content: 'text',
          contentHtml: '<p>text</p>',
          time: 'now',
          avatar: '',
          reactions: [],
        ),
      ],
    );

    expect(
      await service.fetchCommentsPage(subjectId: 9, page: 3),
      backend.commentsPage,
    );
    expect(backend.commentArgs, [(9, 3)]);

    backend.commentsError = StateError('comments failed');
    await expectLater(
      service.fetchCommentsPage(subjectId: 9, page: 4),
      throwsStateError,
    );
  });

  test('topics preserve page arguments and backend errors', () async {
    backend.topicsPage = const BangumiTopicsPage(
      topics: [
        BangumiTopic(
          id: 2001,
          userId: 'moyis',
          userName: 'Uaoko',
          avatar: '',
          title: 'Topic',
          time: 'now',
          updatedAt: 'now',
          repliesCount: 24,
        ),
      ],
      total: 1,
      fetchedCount: 1,
    );

    expect(
      await service.fetchTopicsPage(subjectId: 9, page: 3),
      backend.topicsPage,
    );
    expect(backend.topicArgs, [(9, 3)]);

    backend.topicsError = StateError('topics failed');
    await expectLater(
      service.fetchTopicsPage(subjectId: 9, page: 4),
      throwsStateError,
    );
  });
}

AnimeInfo animeInfo({String? fullJson}) => AnimeInfo(
  title: 'Anime',
  bangumiId: '123',
  tags: const [],
  fullJson: fullJson,
);

BangumiEpisode episode(int id, String name, double sort) => BangumiEpisode(
  id: id,
  name: name,
  nameCn: '',
  description: '',
  airdate: '',
  duration: '',
  sort: sort,
);

class FakeBangumiDetailsBackend implements BangumiDetailsBackend {
  final calls = <String>[];
  AnimeInfo? cachedSubject;
  AnimeInfo? subject;
  List<BangumiEpisode> cachedEpisodes = const [];
  List<BangumiCharacter> cachedCharacters = const [];
  List<BangumiRelatedSubject> cachedRelations = const [];
  List<BangumiPerson> cachedPersons = const [];
  List<BangumiEpisode> episodes = const [];
  List<BangumiCharacter> characters = const [];
  List<BangumiRelatedSubject> relations = const [];
  List<BangumiPerson> persons = const [];
  List<AnimeInfo> filled = const [];
  List<BangumiDataSiteEntry> sites = const [];
  BangumiCommentsPage commentsPage = const BangumiCommentsPage(comments: []);
  BangumiReviewsPage reviewsPage = const BangumiReviewsPage(reviews: []);
  BangumiTopicsPage topicsPage = const BangumiTopicsPage(
    topics: [],
    fetchedCount: 0,
  );
  final cachedWrites = <AnimeInfo>[];
  final commentArgs = <(int, int)>[];
  final reviewArgs = <(int, int)>[];
  final topicArgs = <(int, int)>[];
  Object? subjectError;
  Object? episodesError;
  Object? charactersError;
  Object? relationsError;
  Object? personsError;
  Object? commentsError;
  Object? reviewsError;
  Object? topicsError;

  @override
  Future<AnimeInfo?> getCachedSubject(int subjectId) async {
    calls.add('getCachedSubject');
    return cachedSubject;
  }

  @override
  Future<AnimeInfo?> getSubject(int subjectId) async {
    calls.add('getSubject');
    if (subjectError case final error?) throw error;
    return subject;
  }

  @override
  Future<List<BangumiEpisode>> getCachedEpisodes(int subjectId) async {
    calls.add('getCachedEpisodes');
    return cachedEpisodes;
  }

  @override
  Future<List<BangumiCharacter>> getCachedCharacters(int subjectId) async {
    calls.add('getCachedCharacters');
    return cachedCharacters;
  }

  @override
  Future<List<BangumiRelatedSubject>> getCachedRelations(int subjectId) async {
    calls.add('getCachedRelations');
    return cachedRelations;
  }

  @override
  Future<List<BangumiPerson>> getCachedPersons(int subjectId) async {
    calls.add('getCachedPersons');
    return cachedPersons;
  }

  @override
  Future<List<BangumiEpisode>> getEpisodes(int subjectId) async {
    calls.add('getEpisodes');
    if (episodesError case final error?) throw error;
    return episodes;
  }

  @override
  Future<List<BangumiCharacter>> getCharacters(int subjectId) async {
    calls.add('getCharacters');
    if (charactersError case final error?) throw error;
    return characters;
  }

  @override
  Future<List<BangumiRelatedSubject>> getRelations(int subjectId) async {
    calls.add('getRelations');
    if (relationsError case final error?) throw error;
    return relations;
  }

  @override
  Future<List<BangumiPerson>> getPersons(int subjectId) async {
    calls.add('getPersons');
    if (personsError case final error?) throw error;
    return persons;
  }

  @override
  Future<List<AnimeInfo>> fillDetails(List<AnimeInfo> animes) async {
    calls.add('fillDetails');
    if (subjectError case final error?) throw error;
    return filled;
  }

  @override
  Future<void> cacheAnimeInfo(AnimeInfo anime) async {
    calls.add('cacheAnimeInfo');
    cachedWrites.add(anime);
  }

  @override
  Future<List<BangumiDataSiteEntry>> getSites(String? bangumiId) async {
    calls.add('getSites');
    return sites;
  }

  @override
  Future<BangumiCommentsPage> fetchComments({
    required int subjectId,
    required int page,
  }) async {
    calls.add('fetchComments');
    commentArgs.add((subjectId, page));
    if (commentsError case final error?) throw error;
    return commentsPage;
  }

  @override
  Future<BangumiReviewsPage> fetchReviews({
    required int subjectId,
    required int page,
  }) async {
    calls.add('fetchReviews');
    reviewArgs.add((subjectId, page));
    if (reviewsError case final error?) throw error;
    return reviewsPage;
  }

  @override
  Future<BangumiTopicsPage> fetchTopics({
    required int subjectId,
    required int page,
  }) async {
    calls.add('fetchTopics');
    topicArgs.add((subjectId, page));
    if (topicsError case final error?) throw error;
    return topicsPage;
  }
}
