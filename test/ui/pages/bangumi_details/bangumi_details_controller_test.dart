// Phase 4: characterization / composition tests for
// [BangumiDetailsController].
//
// Pure Dart (plus flutter_test assertions). Fake data/favorites ports complete
// out of order so generation tokens and dispose semantics are exercised without
// real network, cache, WebView, or SharedPreferences.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_details_service.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_controller.dart';

AnimeInfo _anime({
  String title = 'Title',
  String? bangumiId = '123',
  String? fullJson,
  String? coverUrl = 'https://example.com/c.jpg',
  double? score = 7.5,
}) => AnimeInfo(
  title: title,
  bangumiId: bangumiId,
  coverUrl: coverUrl,
  score: score,
  tags: const [],
  fullJson: fullJson,
);

BangumiEpisode _episode({int id = 1, double sort = 1, String name = 'ep'}) =>
    BangumiEpisode(
      id: id,
      name: name,
      nameCn: '',
      description: '',
      airdate: '',
      duration: '',
      sort: sort,
    );

BangumiCharacter _character({
  int id = 1,
  String name = 'char',
  String roleName = '主角',
}) =>
    BangumiCharacter(id: id, name: name, roleName: roleName, actors: const []);

BangumiRelatedSubject _relation({
  int id = 1,
  String name = 'rel',
  String nameCn = '关联',
}) => BangumiRelatedSubject(
  id: id,
  name: name,
  nameCn: nameCn,
  relation: '续集',
  image: '',
);

BangumiComment _comment({String userName = 'u', String content = 'c'}) =>
    BangumiComment(
      userName: userName,
      content: content,
      contentHtml: content,
      time: 't',
      avatar: '',
    );

BangumiDataSiteEntry _site({
  String site = 'unknown_site',
  String title = 'Site',
  String kind = 'info',
}) => BangumiDataSiteEntry(
  site: site,
  title: title,
  url: 'https://example.com',
  kind: kind,
  comment: null,
);

BangumiDetailsLoadResult _loadResult({
  Map<String, dynamic>? subjectData,
  List<BangumiEpisode> episodes = const [],
  List<BangumiCharacter> characters = const [],
  List<BangumiRelatedSubject> relations = const [],
  Map<String, int> personIdMap = const {},
  List<BangumiDataSiteEntry> sites = const [],
}) => BangumiDetailsLoadResult(
  subjectData: subjectData,
  episodes: episodes,
  characters: characters,
  relations: relations,
  personIdMap: personIdMap,
  sites: sites,
);

class _FakeDataPort {
  _FakeDataPort({
    this.cached,
    this.network,
    this.commentsByPage = const {},
    this.commentsError,
    this.holdFutures = false,
  });

  BangumiDetailsLoadResult? cached;
  BangumiDetailsLoadResult? network;
  Map<int, List<BangumiComment>> commentsByPage;
  Duration cachedDelay = Duration.zero;
  Duration networkDelay = Duration.zero;
  Duration commentsDelay = Duration.zero;
  Object? networkError;
  Object? commentsError;
  bool holdFutures;

  int cachedCalls = 0;
  int networkCalls = 0;
  final List<int> commentPagesRequested = <int>[];
  bool? lastIncludeSubjectDetailsCached;
  bool? lastIncludeSubjectDetailsNetwork;

  final _cachedCompleters = <Completer<BangumiDetailsLoadResult?>>[];
  final _networkCompleters = <Completer<BangumiDetailsLoadResult>>[];
  final _commentCompleters = <Completer<List<BangumiComment>>>[];

  void releaseCached([BangumiDetailsLoadResult? result]) {
    final value = result ?? cached;
    for (final c in List.of(_cachedCompleters)) {
      if (!c.isCompleted) c.complete(value);
    }
    _cachedCompleters.clear();
  }

  void releaseNetwork([BangumiDetailsLoadResult? result]) {
    final value = result ?? network;
    if (value == null && networkError == null) {
      throw StateError('no network result configured');
    }
    for (final c in List.of(_networkCompleters)) {
      if (!c.isCompleted) {
        if (networkError != null) {
          c.completeError(networkError!);
        } else {
          c.complete(value!);
        }
      }
    }
    _networkCompleters.clear();
  }

  void releaseComments([List<BangumiComment>? page]) {
    for (final c in List.of(_commentCompleters)) {
      if (!c.isCompleted) {
        if (commentsError != null) {
          c.completeError(commentsError!);
        } else {
          c.complete(page ?? const <BangumiComment>[]);
        }
      }
    }
    _commentCompleters.clear();
  }

  BangumiDetailsDataPort asPort() => BangumiDetailsDataPort(
    loadCachedInitialData:
        ({required anime, includeSubjectDetails = true}) async {
          cachedCalls++;
          lastIncludeSubjectDetailsCached = includeSubjectDetails;
          if (holdFutures) {
            final c = Completer<BangumiDetailsLoadResult?>();
            _cachedCompleters.add(c);
            return c.future;
          }
          if (cachedDelay > Duration.zero) {
            await Future<void>.delayed(cachedDelay);
          }
          return cached;
        },
    loadInitialData: ({required anime, includeSubjectDetails = true}) async {
      networkCalls++;
      lastIncludeSubjectDetailsNetwork = includeSubjectDetails;
      if (holdFutures) {
        final c = Completer<BangumiDetailsLoadResult>();
        _networkCompleters.add(c);
        return c.future;
      }
      if (networkDelay > Duration.zero) {
        await Future<void>.delayed(networkDelay);
      }
      if (networkError != null) throw networkError!;
      return network ??
          const BangumiDetailsLoadResult(
            subjectData: null,
            episodes: [],
            characters: [],
            relations: [],
            personIdMap: {},
            sites: [],
          );
    },
    fetchCommentsPage: ({required subjectId, required page}) async {
      commentPagesRequested.add(page);
      if (holdFutures) {
        final c = Completer<List<BangumiComment>>();
        _commentCompleters.add(c);
        return c.future;
      }
      if (commentsDelay > Duration.zero) {
        await Future<void>.delayed(commentsDelay);
      }
      if (commentsError != null) throw commentsError!;
      return commentsByPage[page] ?? const <BangumiComment>[];
    },
  );
}

class _FakeFavorites {
  _FakeFavorites({this.isFav = false, this.hold = false});

  bool isFav;
  Duration delay = Duration.zero;
  bool hold;
  final _statusCompleters = <Completer<bool>>[];
  int isFavoriteCalls = 0;
  int addCalls = 0;
  int removeCalls = 0;

  void releaseStatus([bool? value]) {
    for (final c in List.of(_statusCompleters)) {
      if (!c.isCompleted) c.complete(value ?? isFav);
    }
    _statusCompleters.clear();
  }

  BangumiDetailsFavoritesPort asPort() => BangumiDetailsFavoritesPort(
    isFavorite: (id) async {
      isFavoriteCalls++;
      if (hold) {
        final c = Completer<bool>();
        _statusCompleters.add(c);
        return c.future;
      }
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      return isFav;
    },
    addFavorite:
        ({
          required bangumiId,
          required title,
          required coverUrl,
          required score,
        }) async {
          addCalls++;
          isFav = true;
        },
    removeFavorite: (id) async {
      removeCalls++;
      isFav = false;
    },
  );
}

BangumiDetailsController _controller({
  AnimeInfo? anime,
  _FakeDataPort? data,
  _FakeFavorites? favorites,
  void Function()? onStateChanged,
}) {
  final d = data ?? _FakeDataPort();
  final f = favorites ?? _FakeFavorites();
  final c = BangumiDetailsController(
    anime: anime ?? _anime(),
    dataPort: d.asPort(),
    favoritesPort: f.asPort(),
    onStateChanged: onStateChanged,
  );
  addTearDown(c.clearForDispose);
  return c;
}

void expectConsistent(BangumiDetailsController c, [String? label]) {
  final errors = c.validateInvariants();
  if (errors.isNotEmpty) {
    fail(
      'invariants violated${label == null ? '' : ' ($label)'}:\n'
      '${errors.map((e) => '  - $e').join('\n')}',
    );
  }
}

void main() {
  group('seedFromAnimeFullJson', () {
    test('decodes fullJson into subjectData', () {
      final c = _controller(
        anime: _anime(fullJson: jsonEncode({'name': 'A', 'name_cn': '甲'})),
      );
      c.seedFromAnimeFullJson();
      expect(c.subjectData?['name'], 'A');
      expect(c.hasSubjectDetails, isTrue);
      expectConsistent(c);
    });

    test('bad json leaves subjectData null', () {
      final c = _controller(anime: _anime(fullJson: '{not-json'));
      c.seedFromAnimeFullJson();
      expect(c.subjectData, isNull);
      expectConsistent(c);
    });
  });

  group('cache-first then network', () {
    test(
      'cache success then network success merges and clears loading',
      () async {
        final data = _FakeDataPort(
          cached: _loadResult(
            subjectData: {'name': 'cached'},
            episodes: [_episode(id: 1, name: 'c-ep')],
            characters: [_character(id: 1, name: 'c-char', roleName: '配角')],
            sites: [_site(title: 'CacheSite', kind: 'resource')],
          ),
          network: _loadResult(
            subjectData: {'name': 'network'},
            episodes: [_episode(id: 2, name: 'n-ep')],
            characters: [
              _character(id: 2, name: 'n-support', roleName: '配角'),
              _character(id: 3, name: 'n-main', roleName: '主角'),
            ],
            relations: [_relation()],
            personIdMap: {'声优': 9},
            sites: [
              _site(title: 'Res', kind: 'resource'),
              _site(title: 'Info', kind: 'info'),
              _site(title: 'OnAir', kind: 'onair'),
            ],
          ),
        );
        final c = _controller(data: data);

        await Future.wait([c.primeFromCache(), c.refreshFromNetwork()]);

        expect(data.cachedCalls, 1);
        expect(data.networkCalls, 1);
        // Network subject only fills when subjectData was null; cache already set it.
        expect(c.subjectData?['name'], 'cached');
        expect(c.episodes?.single.name, 'n-ep');
        expect(c.characters?.map((e) => e.name).toList(), [
          'n-main',
          'n-support',
        ]);
        expect(c.relations, isNotEmpty);
        expect(c.sites?.map((e) => e.title).toList(), ['Info', 'OnAir', 'Res']);
        expect(c.personIdMap['声优'], 9);
        expect(c.isLoadingEpisodes, isFalse);
        expect(c.isLoadingCharacters, isFalse);
        expect(c.isLoadingRelations, isFalse);
        expectConsistent(c);
      },
    );

    test(
      'seeded fullJson skips includeSubjectDetails for both loads',
      () async {
        final data = _FakeDataPort(
          cached: _loadResult(episodes: [_episode()]),
          network: _loadResult(episodes: [_episode(id: 2)]),
        );
        final c = _controller(
          anime: _anime(fullJson: jsonEncode({'name': 'seeded'})),
          data: data,
        );
        c.seedFromAnimeFullJson();
        await Future.wait([c.primeFromCache(), c.refreshFromNetwork()]);
        expect(data.lastIncludeSubjectDetailsCached, isFalse);
        expect(data.lastIncludeSubjectDetailsNetwork, isFalse);
        expect(c.subjectData?['name'], 'seeded');
      },
    );

    test('sequential network empty after cache clear replaces lists', () async {
      final data = _FakeDataPort(
        cached: _loadResult(
          episodes: [_episode(id: 1)],
          characters: [_character(id: 1)],
          relations: [_relation(id: 1)],
        ),
        network: _loadResult(), // all empty
      );
      final c = _controller(data: data);
      await c.primeFromCache();
      expect(c.episodes, isNotEmpty);
      await c.refreshFromNetwork();
      // refreshFromNetwork nulls slots before await, so empty network commits.
      expect(c.episodes, isEmpty);
      expect(c.characters, isEmpty);
      expect(c.relations, isEmpty);
      expect(c.isLoadingEpisodes, isFalse);
      expectConsistent(c);
    });

    test('concurrent cache survives empty network via merge rules', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = _controller(data: data);
      final cacheFuture = c.primeFromCache();
      final netFuture = c.refreshFromNetwork();
      // Network started first and cleared slots; release cache then empty network.
      data.releaseCached(
        _loadResult(
          episodes: [_episode(id: 1)],
          characters: [_character(id: 1)],
          relations: [_relation(id: 1)],
        ),
      );
      await cacheFuture;
      expect(c.episodes, isNotEmpty);
      data.releaseNetwork(_loadResult());
      await netFuture;
      expect(c.episodes?.single.id, 1);
      expect(c.characters?.single.id, 1);
      expect(c.relations?.single.id, 1);
      expectConsistent(c);
    });

    test('late cache after dispose is ignored', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = BangumiDetailsController(
        anime: _anime(),
        dataPort: data.asPort(),
        favoritesPort: _FakeFavorites().asPort(),
      );
      final pending = c.primeFromCache();
      c.clearForDispose();
      data.releaseCached(
        _loadResult(episodes: [_episode(id: 99, name: 'late')]),
      );
      await pending;
      expect(c.episodes, isNull);
      expect(c.isDisposed, isTrue);
    });

    test('late network after dispose is ignored', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = BangumiDetailsController(
        anime: _anime(),
        dataPort: data.asPort(),
        favoritesPort: _FakeFavorites().asPort(),
      );
      final pending = c.refreshFromNetwork();
      expect(c.isLoadingEpisodes, isTrue);
      c.clearForDispose();
      data.releaseNetwork(
        _loadResult(episodes: [_episode(id: 99, name: 'late')]),
      );
      await pending;
      expect(c.episodes, isNull);
    });

    test('resetForAnime invalidates prior network completion', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = _controller(
        anime: _anime(bangumiId: '1'),
        data: data,
      );
      final first = c.refreshFromNetwork();
      c.resetForAnime(_anime(bangumiId: '2', title: 'Other'));
      data.releaseNetwork(
        _loadResult(episodes: [_episode(id: 1, name: 'old-gen')]),
      );
      await first;

      // New generation can still load.
      data.holdFutures = false;
      data.network = _loadResult(episodes: [_episode(id: 2, name: 'new-gen')]);
      await c.refreshFromNetwork();
      expect(c.anime.bangumiId, '2');
      expect(c.episodes?.single.name, 'new-gen');
      expectConsistent(c);
    });
  });

  group('comments', () {
    test('ensureCommentsLoaded populates first page', () async {
      final data = _FakeDataPort(
        commentsByPage: {
          1: [_comment(userName: 'a'), _comment(userName: 'b')],
        },
      );
      final c = _controller(data: data);
      await c.ensureCommentsLoaded();
      expect(c.hasRequestedComments, isTrue);
      expect(c.isLoadingComments, isFalse);
      expect(c.comments?.map((e) => e.userName).toList(), ['a', 'b']);
      expect(c.hasMoreComments, isTrue);
      expect(c.commentPage, 1);
      expect(data.commentPagesRequested, [1]);
      expectConsistent(c);
    });

    test('concurrent ensureCommentsLoaded dedupes', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = _controller(data: data);
      final a = c.ensureCommentsLoaded();
      final b = c.ensureCommentsLoaded();
      expect(c.isLoadingComments, isTrue);
      data.releaseComments([_comment(userName: 'only')]);
      await Future.wait([a, b]);
      expect(data.commentPagesRequested, [1]);
      expect(c.comments?.single.userName, 'only');
    });

    test('loadMoreComments appends and advances page; empty ends', () async {
      final data = _FakeDataPort(
        commentsByPage: {
          1: [_comment(userName: 'p1')],
          2: [_comment(userName: 'p2')],
          3: const [],
        },
      );
      final c = _controller(data: data);
      await c.ensureCommentsLoaded();
      await c.loadMoreComments();
      expect(c.commentPage, 2);
      expect(c.comments?.map((e) => e.userName).toList(), ['p1', 'p2']);
      await c.loadMoreComments();
      expect(c.hasMoreComments, isFalse);
      expect(c.commentPage, 2);
      expect(data.commentPagesRequested, [1, 2, 3]);
      // Terminal page: further load-more is a no-op.
      await c.loadMoreComments();
      expect(data.commentPagesRequested, [1, 2, 3]);
      expectConsistent(c);
    });

    test('concurrent loadMoreComments dedupes', () async {
      final data = _FakeDataPort(
        commentsByPage: {
          1: [_comment(userName: 'p1')],
        },
        holdFutures: true,
      );
      final c = _controller(data: data);
      // First page without hold
      data.holdFutures = false;
      await c.ensureCommentsLoaded();
      data.holdFutures = true;
      data.commentsByPage = {
        2: [_comment(userName: 'p2')],
      };

      final a = c.loadMoreComments();
      final b = c.loadMoreComments();
      expect(c.isLoadingMoreComments, isTrue);
      // Only one in-flight request should have been started.
      expect(data.commentPagesRequested.where((p) => p == 2).length, 1);
      data.releaseComments([_comment(userName: 'p2')]);
      await Future.wait([a, b]);
      expect(c.comments?.map((e) => e.userName).toList(), ['p1', 'p2']);
      expectConsistent(c);
    });

    test('first-page error sets empty comments and no more', () async {
      final data = _FakeDataPort(commentsError: Exception('boom'));
      final c = _controller(data: data);
      await c.ensureCommentsLoaded();
      expect(c.comments, isEmpty);
      expect(c.hasMoreComments, isFalse);
      expect(c.isLoadingComments, isFalse);
      expectConsistent(c);
    });

    test('load-more error clears loading flag and allows retry', () async {
      final data = _FakeDataPort(
        commentsByPage: {
          1: [_comment(userName: 'p1')],
        },
      );
      final c = _controller(data: data);
      await c.ensureCommentsLoaded();
      data.commentsError = Exception('more-fail');
      await c.loadMoreComments();
      expect(c.isLoadingMoreComments, isFalse);
      expect(c.hasMoreComments, isTrue);
      expect(c.comments?.single.userName, 'p1');

      data.commentsError = null;
      data.commentsByPage = {
        2: [_comment(userName: 'p2')],
      };
      await c.loadMoreComments();
      expect(c.comments?.map((e) => e.userName).toList(), ['p1', 'p2']);
      expectConsistent(c);
    });

    test('refreshFromNetwork invalidates in-flight comments', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = _controller(data: data);
      final commentsFuture = c.ensureCommentsLoaded();
      // Start network refresh which bumps comments token and clears slots.
      final net = c.refreshFromNetwork();
      data.releaseComments([_comment(userName: 'stale')]);
      await commentsFuture;
      expect(c.comments, isNull);
      expect(c.hasRequestedComments, isFalse);

      data.releaseNetwork(_loadResult(episodes: [_episode()]));
      await net;
      expect(c.episodes, isNotEmpty);
      expectConsistent(c);
    });

    test('late comments after dispose ignored', () async {
      final data = _FakeDataPort(holdFutures: true);
      final c = BangumiDetailsController(
        anime: _anime(),
        dataPort: data.asPort(),
        favoritesPort: _FakeFavorites().asPort(),
      );
      final pending = c.ensureCommentsLoaded();
      c.clearForDispose();
      data.releaseComments([_comment(userName: 'late')]);
      await pending;
      expect(c.comments, isNull);
    });
  });

  group('favorites', () {
    test('refreshFavoriteStatus success', () async {
      final fav = _FakeFavorites(isFav: true);
      final c = _controller(favorites: fav);
      await c.refreshFavoriteStatus();
      expect(c.isLocalFavorite, isTrue);
      expect(fav.isFavoriteCalls, 1);
      expectConsistent(c);
    });

    test('toggleLocalFavorite add then remove', () async {
      final fav = _FakeFavorites(isFav: false);
      final c = _controller(favorites: fav);
      final was = await c.toggleLocalFavorite(
        title: 'T',
        coverUrl: 'u',
        score: 1.0,
      );
      expect(was, isFalse);
      expect(c.isLocalFavorite, isTrue);
      expect(fav.addCalls, 1);

      final was2 = await c.toggleLocalFavorite(
        title: 'T',
        coverUrl: 'u',
        score: 1.0,
      );
      expect(was2, isTrue);
      expect(c.isLocalFavorite, isFalse);
      expect(fav.removeCalls, 1);
      expectConsistent(c);
    });

    test('stale favorite status after dispose is ignored', () async {
      final fav = _FakeFavorites(hold: true, isFav: false);
      final c = BangumiDetailsController(
        anime: _anime(),
        dataPort: _FakeDataPort().asPort(),
        favoritesPort: fav.asPort(),
      );
      final pending = c.refreshFavoriteStatus();
      c.clearForDispose();
      fav.isFav = true;
      fav.releaseStatus(true);
      await pending;
      expect(c.isLocalFavorite, isFalse);
    });

    test('stale favorite after resetForAnime is ignored', () async {
      final fav = _FakeFavorites(hold: true, isFav: false);
      final c = _controller(favorites: fav);
      final pending = c.refreshFavoriteStatus();
      c.resetForAnime(_anime(bangumiId: '999'));
      fav.isFav = true;
      fav.releaseStatus(true);
      await pending;
      expect(c.isLocalFavorite, isFalse);
    });
  });

  group('sorting helpers', () {
    test('sortCharactersByRole orders main before support', () {
      final sorted = sortCharactersByRole([
        _character(id: 1, name: 'b', roleName: '配角'),
        _character(id: 2, name: 'a', roleName: '主角'),
        _character(id: 3, name: 'c', roleName: '客串'),
      ]);
      expect(sorted.map((e) => e.name).toList(), ['a', 'b', 'c']);
    });

    test('sortSitesByKind orders info, onair, resource', () {
      final sorted = sortSitesByKind([
        _site(title: 'R', kind: 'resource'),
        _site(title: 'I', kind: 'info'),
        _site(title: 'O', kind: 'onair'),
      ]);
      expect(sorted.map((e) => e.title).toList(), ['I', 'O', 'R']);
    });
  });

  group('onStateChanged', () {
    test('fires on successful mutations', () async {
      var n = 0;
      final data = _FakeDataPort(
        network: _loadResult(episodes: [_episode()]),
        commentsByPage: {
          1: [_comment()],
        },
      );
      final c = _controller(data: data, onStateChanged: () => n++);
      await c.refreshFromNetwork();
      expect(n, greaterThan(0));
      final before = n;
      await c.ensureCommentsLoaded();
      expect(n, greaterThan(before));
    });
  });
}
