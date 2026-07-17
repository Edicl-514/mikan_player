// Phase 1.1: unit tests for player_side_panel_loader pure helpers + state.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/player/player_side_panel_loader.dart';

BangumiEpisodeComment _comment({int id = 1, String time = '2024-01-01'}) =>
    BangumiEpisodeComment(
      id: id,
      userName: 'u',
      userId: '1',
      avatar: '',
      time: time,
      contentHtml: '',
      replies: const [],
    );

BangumiRelatedSubject _rel({
  int id = 1,
  String name = 'name',
  String nameCn = '',
  String relation = '其他',
  String image = '',
}) => BangumiRelatedSubject(
  id: id,
  name: name,
  nameCn: nameCn,
  relation: relation,
  image: image,
);

RankingAnime _rank({String title = 't', String bangumiId = '1'}) =>
    RankingAnime(
      title: title,
      bangumiId: bangumiId,
      coverUrl: '',
      info: '',
      originalTitle: null,
    );

PlayerSidePanelLoader _loader() {
  final l = PlayerSidePanelLoader();
  addTearDown(l.clearForDispose);
  return l;
}

void main() {
  group('sortCommentsList / setCommentSortMode', () {
    test('default mode sorts by id ascending', () {
      final comments = [
        _comment(id: 3, time: 'c'),
        _comment(id: 1, time: 'a'),
        _comment(id: 2, time: 'b'),
      ];
      sortCommentsList(comments, mode: 'default');
      expect(comments.map((c) => c.id).toList(), [1, 2, 3]);
    });

    test('time mode sorts by time descending', () {
      final comments = [
        _comment(id: 1, time: '2024-01-01'),
        _comment(id: 2, time: '2024-03-01'),
        _comment(id: 3, time: '2024-02-01'),
      ];
      sortCommentsList(comments, mode: 'time');
      expect(comments.map((c) => c.id).toList(), [2, 3, 1]);
    });

    test('setCommentSortMode re-sorts and reports change', () {
      final l = _loader();
      l.setComments([
        _comment(id: 2, time: '2024-01-01'),
        _comment(id: 1, time: '2024-02-01'),
      ]);
      expect(l.comments.map((c) => c.id).toList(), [1, 2]); // default id asc

      expect(l.setCommentSortMode('time'), isTrue);
      expect(l.commentSortMode, 'time');
      expect(l.comments.map((c) => c.id).toList(), [
        1,
        2,
      ]); // id1 later time first? id1 time Feb, id2 Jan → [1,2]
      // Actually id1=Feb > id2=Jan so time desc → id1 then id2. Same order.
      // Swap times for a clearer assertion:
      l.setComments([
        _comment(id: 10, time: '2024-01-01'),
        _comment(id: 20, time: '2024-03-01'),
      ]);
      // setComments re-sorts with current mode 'time'
      expect(l.comments.map((c) => c.id).toList(), [20, 10]);

      expect(l.setCommentSortMode('time'), isFalse);
      expect(l.setCommentSortMode('default'), isTrue);
      expect(l.comments.map((c) => c.id).toList(), [10, 20]);
    });
  });

  group('comments load state', () {
    test('begin / success / error / reset', () {
      final l = _loader();
      l.beginCommentsLoad();
      expect(l.isLoadingComments, isTrue);
      expect(l.commentsError, isNull);

      l.setComments([_comment(id: 5)]);
      expect(l.isLoadingComments, isFalse);
      expect(l.comments, hasLength(1));
      expect(l.commentsError, isNull);

      l.beginCommentsLoad();
      l.setCommentsError('boom');
      expect(l.isLoadingComments, isFalse);
      expect(l.commentsError, 'boom');

      l.resetComments();
      expect(l.comments, isEmpty);
      expect(l.isLoadingComments, isFalse);
      expect(l.commentsError, isNull);
    });
  });

  group('extractRecommendationTagsFromBangumiJson', () {
    test('empty / invalid', () {
      expect(extractRecommendationTagsFromBangumiJson(null), isEmpty);
      expect(extractRecommendationTagsFromBangumiJson(''), isEmpty);
      expect(extractRecommendationTagsFromBangumiJson('not-json'), isEmpty);
      expect(extractRecommendationTagsFromBangumiJson('[]'), isEmpty);
    });

    test('meta_tags + tags with de-dupe', () {
      final json = '''
{
  "meta_tags": ["  SF  ", "冒险", "sf"],
  "tags": [
    {"name": "机战"},
    "冒险",
    {"name": "  "}
  ]
}
''';
      expect(extractRecommendationTagsFromBangumiJson(json), [
        'SF',
        '冒险',
        '机战',
      ]);
    });
  });

  group('recommendationLimitPerTag', () {
    test('bounds 2..5 and zero for empty', () {
      expect(recommendationLimitPerTag(0), 0);
      expect(recommendationLimitPerTag(1), 5); // 12/1=12 → clamp 5
      expect(recommendationLimitPerTag(3), 4); // 12/3=4
      expect(recommendationLimitPerTag(6), 2); // 12/6=2
      expect(recommendationLimitPerTag(12), 2); // ceil(1)=1 → clamp 2
    });
  });

  group('appendRelationRecommendations', () {
    test('prioritizes 前传/续集 and skips duplicates', () {
      final results = <RankingAnime>[];
      final added = <String>{'99'};
      appendRelationRecommendations(
        relations: [
          _rel(id: 1, nameCn: '其他A', relation: '其他'),
          _rel(id: 2, nameCn: '续集B', relation: '续集'),
          _rel(id: 3, name: 'Prequel EN', nameCn: '', relation: '前传'),
          _rel(id: 99, nameCn: 'already', relation: '续集'),
        ],
        results: results,
        addedIds: added,
      );

      expect(results.map((r) => r.bangumiId).toList(), ['2', '3', '1']);
      expect(results[0].title, '续集B');
      expect(results[1].title, 'Prequel EN'); // falls back to name
      expect(results[1].info, '前传');
      expect(added.contains('1'), isTrue);
    });
  });

  group('appendTagRecommendations', () {
    test('respects limit and de-dupes', () {
      final results = <RankingAnime>[];
      final added = <String>{'a'};
      appendTagRecommendations(
        tagGroups: [
          [_rank(bangumiId: 'a'), _rank(bangumiId: 'b'), _rank(bangumiId: 'c')],
          [_rank(bangumiId: 'b'), _rank(bangumiId: 'd')],
        ],
        limitPerTag: 1,
        results: results,
        addedIds: added,
      );
      expect(results.map((r) => r.bangumiId).toList(), ['b', 'd']);
    });
  });

  group('filterOnairSites / onair + recommendations state', () {
    test('filters kind=onair', () {
      final sites = [
        const BangumiDataSiteEntry(
          site: 'bilibili',
          title: 'A',
          url: 'u1',
          kind: 'onair',
        ),
        const BangumiDataSiteEntry(
          site: 'netflix',
          title: 'B',
          url: 'u2',
          kind: 'info',
        ),
      ];
      final onair = filterOnairSites(sites);
      expect(onair, hasLength(1));
      expect(onair.single.site, 'bilibili');
    });

    test('recommendations and onair mutators', () {
      final l = _loader();
      l.beginRecommendationsLoad();
      expect(l.isLoadingRecommendations, isTrue);
      l.setRecommendations([_rank(bangumiId: 'x')]);
      expect(l.isLoadingRecommendations, isFalse);
      expect(l.recommendations, hasLength(1));

      l.beginRecommendationsLoad();
      l.markRecommendationsLoadFailed();
      expect(l.isLoadingRecommendations, isFalse);

      l.setOnairSites([
        const BangumiDataSiteEntry(
          site: 's',
          title: 't',
          url: 'u',
          kind: 'onair',
        ),
      ]);
      expect(l.onairSites, hasLength(1));
      l.clearOnairSites();
      expect(l.onairSites, isEmpty);
    });
  });
}
