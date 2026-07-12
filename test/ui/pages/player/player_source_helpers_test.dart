// Phase 2 step 1: unit tests for the pure helpers extracted from
// `lib/ui/pages/player_page.dart` into
// `lib/ui/pages/player/player_source_helpers.dart`.
//
// Type-shape note for [magnetOf] / [titleOf] / [sizeOf]:
// the [MikanEpisodeResource] and [DmhyResource] types in
// `lib/src/rust/api/{mikan,dmhy}.dart` are concrete final classes with `const`
// constructors and no platform bindings. They are constructible in unit tests
// without bringing up the rust runtime, so we instantiate them directly and
// assert that the dispatch (`r is MikanEpisodeResource` / `r is DmhyResource`)
// reads the right field for each subtype, plus a negative case for an
// unrelated object.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/ui/pages/player/player_source_helpers.dart';
import 'package:mikan_player/ui/pages/player/widgets/bt_resource.dart';

MikanEpisodeResource _mikan({
  String title = 't',
  String magnet = '',
  String size = '0',
  String updateTime = '',
  int? episode,
}) => MikanEpisodeResource(
  title: title,
  magnet: magnet,
  size: size,
  updateTime: updateTime,
  episode: episode,
);

DmhyResource _dmhy({
  String title = 't',
  String magnet = '',
  String size = '0',
  String publishDate = '',
  int? episode,
}) => DmhyResource(
  title: title,
  magnet: magnet,
  size: size,
  publishDate: publishDate,
  episode: episode,
);

void main() {
  group('resolvePlayerResourceContent', () {
    test('hides every source while the source control is collapsed', () {
      expect(
        resolvePlayerResourceContent(isExpanded: false, activeSource: 'bt'),
        PlayerResourceContent.hidden,
      );
      expect(
        resolvePlayerResourceContent(isExpanded: false, activeSource: 'sample'),
        PlayerResourceContent.hidden,
      );
    });

    test('selects the expanded BT or subscription content', () {
      expect(
        resolvePlayerResourceContent(isExpanded: true, activeSource: 'bt'),
        PlayerResourceContent.bt,
      );
      expect(
        resolvePlayerResourceContent(isExpanded: true, activeSource: 'sample'),
        PlayerResourceContent.sample,
      );
    });

    test('keeps the page\'s historic BT fallback for an unknown source', () {
      expect(
        resolvePlayerResourceContent(isExpanded: true, activeSource: 'unknown'),
        PlayerResourceContent.bt,
      );
    });
  });

  group('dedupBtResources', () {
    test('empty list returns empty list', () {
      final out = dedupBtResources(<dynamic>[]);
      expect(out, isEmpty);
    });

    test('distinct btih hashes are all kept in order', () {
      final a = _mikan(
        title: 'A',
        magnet: 'urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final b = _mikan(
        title: 'B',
        magnet: 'urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final c = _mikan(
        title: 'C',
        magnet: 'urn:btih:cccccccccccccccccccccccccccccccccccccccc',
      );
      final out = dedupBtResources(<dynamic>[a, b, c]);
      expect(out, [a, b, c]);
    });

    test('duplicate btih hash (case-insensitive) keeps only the first', () {
      final first = _mikan(
        title: 'A',
        magnet: 'urn:btih:ABCDEF0123456789ABCDEF0123456789ABCDEF01',
      );
      final dup = _mikan(
        title: 'A2',
        magnet: 'urn:btih:abcdef0123456789abcdef0123456789abcdef01',
      );
      final out = dedupBtResources(<dynamic>[first, dup]);
      expect(out, [first]);
    });

    test('resources with no magnet are deduped by title|size', () {
      final a = _mikan(title: 'NoMagnet', size: '1.0GB');
      final b = _mikan(title: 'NoMagnet', size: '1.0GB');
      final c = _mikan(title: 'NoMagnet', size: '2.0GB');
      final out = dedupBtResources(<dynamic>[a, b, c]);
      expect(out, [a, c]);
    });

    test('different titles with same size are both kept', () {
      final a = _mikan(title: 'Alpha', size: '1.0GB');
      final b = _mikan(title: 'Beta', size: '1.0GB');
      final out = dedupBtResources(<dynamic>[a, b]);
      expect(out, [a, b]);
    });

    test(
      'hash-bearing and fallback-bucket resources with same title are both kept',
      () {
        final withHash = _mikan(
          title: 'Shared',
          magnet: 'urn:btih:1111111111111111111111111111111111111111',
        );
        final withoutHash = _mikan(title: 'Shared', magnet: '', size: '1.0GB');
        final out = dedupBtResources(<dynamic>[withHash, withoutHash]);
        expect(out, [withHash, withoutHash]);
      },
    );

    test('returns a new list and does not mutate the input', () {
      final a = _mikan(
        title: 'A',
        magnet: 'urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final b = _mikan(
        title: 'B',
        magnet: 'urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final input = <dynamic>[a, b];
      final out = dedupBtResources(input);
      expect(identical(out, input), isFalse);
      expect(input.length, 2);
      expect(out.length, 2);
    });
  });

  group('sortBtResourcesByTitle', () {
    test('empty list returns empty list', () {
      final out = sortBtResourcesByTitle(<dynamic>[]);
      expect(out, isEmpty);
    });

    test('single resource returns same content (new list)', () {
      final a = _mikan(title: 'Solo');
      final input = <dynamic>[a];
      final out = sortBtResourcesByTitle(input);
      expect(out, [a]);
      expect(identical(out, input), isFalse);
    });

    test('three clearly different titles sort alphabetically', () {
      final a = _mikan(title: 'Bravo');
      final b = _mikan(title: 'Alpha');
      final c = _mikan(title: 'Charlie');
      final out = sortBtResourcesByTitle(<dynamic>[a, b, c]);
      // `compareTo` is case-sensitive: A(65) < B(66) < C(67), so order
      // matches the alphabetically sorted list directly.
      expect(out, [b, a, c]);
    });

    test(
      'case-sensitive compareTo: uppercase title comes before lowercase',
      () {
        // Sanity check: capital 'Z' (90) > lower 'a' (97) is false — but
        // 'B' (66) < 'a' (97), so "Banana" sorts before "apple".
        final upper = _mikan(title: 'Banana');
        final lower = _mikan(title: 'apple');
        final out = sortBtResourcesByTitle(<dynamic>[lower, upper]);
        expect(out, [upper, lower]);
      },
    );

    test('same title falls back to size string ascending', () {
      final small = _mikan(title: 'Same', size: '100MB');
      final mid = _mikan(title: 'Same', size: '500MB');
      final big = _mikan(title: 'Same', size: '2.0GB');
      final out = sortBtResourcesByTitle(<dynamic>[big, small, mid]);
      // String compareTo is lexicographic, not numeric, so '2.0GB' < '500MB'
      // ('2' < '5'). Verbatim algorithm behavior.
      expect(out, [small, big, mid]);
    });

    test('returns a new list and does not mutate the input', () {
      final a = _mikan(title: 'Z');
      final b = _mikan(title: 'A');
      final input = <dynamic>[a, b];
      final out = sortBtResourcesByTitle(input);
      expect(identical(out, input), isFalse);
      expect(input, [a, b]);
    });
  });

  group('magnetOf', () {
    test('returns magnet of a MikanEpisodeResource', () {
      final r = _mikan(magnet: 'm1');
      expect(magnetOf(r), 'm1');
    });

    test('returns magnet of a DmhyResource', () {
      final r = _dmhy(magnet: 'm2');
      expect(magnetOf(r), 'm2');
    });

    test('returns "" for an unrelated object', () {
      expect(magnetOf(Object()), '');
    });
  });

  group('titleOf', () {
    test('returns title of a MikanEpisodeResource', () {
      final r = _mikan(title: 'Mikan title');
      expect(titleOf(r), 'Mikan title');
    });

    test('returns title of a DmhyResource', () {
      final r = _dmhy(title: 'Dmhy title');
      expect(titleOf(r), 'Dmhy title');
    });

    test('returns "" for an unrelated object', () {
      expect(titleOf(Object()), '');
    });
  });

  group('sizeOf', () {
    test('returns size of a MikanEpisodeResource', () {
      final r = _mikan(size: '1.0GB');
      expect(sizeOf(r), '1.0GB');
    });

    test('returns size of a DmhyResource', () {
      final r = _dmhy(size: '500MB');
      expect(sizeOf(r), '500MB');
    });

    test('returns "" for an unrelated object', () {
      expect(sizeOf(Object()), '');
    });
  });

  group('timeOf', () {
    test('returns updateTime of a MikanEpisodeResource', () {
      final r = _mikan(updateTime: '2024-01-02');
      expect(timeOf(r), '2024-01-02');
    });

    test('returns publishDate of a DmhyResource', () {
      final r = _dmhy(publishDate: 'Mon, 01 Jan 2024 00:00:00 +0800');
      expect(timeOf(r), 'Mon, 01 Jan 2024 00:00:00 +0800');
    });

    test('returns "" for an unrelated object', () {
      expect(timeOf(Object()), '');
    });
  });

  group('episodeOf', () {
    test('returns episode of a MikanEpisodeResource', () {
      final r = _mikan(episode: 7);
      expect(episodeOf(r), 7);
    });

    test('returns episode of a DmhyResource', () {
      final r = _dmhy(episode: 12);
      expect(episodeOf(r), 12);
    });

    test('returns null when episode is null', () {
      expect(episodeOf(_mikan()), isNull);
      expect(episodeOf(_dmhy()), isNull);
    });

    test('returns null for an unrelated object', () {
      expect(episodeOf(Object()), isNull);
    });
  });

  group('toBtResource', () {
    test('maps a MikanEpisodeResource field-by-field', () {
      final r = _mikan(
        title: 'S0 1080p',
        magnet: 'magnet:?xt=urn:btih:aaa',
        size: '1.2GB',
        updateTime: '2024-05-06',
        episode: 3,
      );
      final vm = toBtResource(r);
      expect(vm, isA<BtResource>());
      expect(vm.title, 'S0 1080p');
      expect(vm.magnet, 'magnet:?xt=urn:btih:aaa');
      expect(vm.size, '1.2GB');
      expect(vm.time, '2024-05-06');
      expect(vm.episode, 3);
    });

    test('maps a DmhyResource field-by-field', () {
      final r = _dmhy(
        title: 'DMHY S0 1080p',
        magnet: 'magnet:?xt=urn:btih:bbb',
        size: '2.4GB',
        publishDate: 'Tue, 06 May 2024 12:00:00 +0800',
        episode: 4,
      );
      final vm = toBtResource(r);
      expect(vm.title, 'DMHY S0 1080p');
      expect(vm.magnet, 'magnet:?xt=urn:btih:bbb');
      expect(vm.size, '2.4GB');
      expect(vm.time, 'Tue, 06 May 2024 12:00:00 +0800');
      expect(vm.episode, 4);
    });

    test('falls back to empty strings / null for an unrelated object', () {
      final vm = toBtResource(Object());
      expect(vm.title, '');
      expect(vm.magnet, '');
      expect(vm.size, '');
      expect(vm.time, '');
      expect(vm.episode, isNull);
    });

    test('preserves null episode', () {
      final vm = toBtResource(_mikan(title: 'no ep'));
      expect(vm.episode, isNull);
    });
  });

  group('toBtResourceViewModels', () {
    test('empty input returns empty list', () {
      expect(toBtResourceViewModels(<dynamic>[]), isEmpty);
    });

    test('preserves order and length for mixed sources', () {
      final a = _mikan(title: 'A', magnet: 'm1');
      final b = _dmhy(title: 'B', magnet: 'm2');
      final c = _mikan(title: 'C', magnet: 'm3', episode: 2);
      final out = toBtResourceViewModels(<dynamic>[a, b, c]);
      expect(out.length, 3);
      expect(out[0].title, 'A');
      expect(out[0].magnet, 'm1');
      expect(out[1].title, 'B');
      expect(out[1].magnet, 'm2');
      expect(out[2].title, 'C');
      expect(out[2].episode, 2);
    });

    test('returns a new List<BtResource>', () {
      final input = <dynamic>[_mikan(title: 'X')];
      final out = toBtResourceViewModels(input);
      expect(out, isA<List<BtResource>>());
      expect(identical(out, input), isFalse);
    });
  });

  group('btihRegex', () {
    test('matches a valid 40-hex btih urn', () {
      final m = btihRegex.firstMatch(
        'urn:btih:abcdef0123456789abcdef0123456789abcdef01',
      );
      expect(m, isNotNull);
      expect(m!.group(1), 'abcdef0123456789abcdef0123456789abcdef01');
    });

    test('matches a valid 32-base32 btih urn', () {
      final m = btihRegex.firstMatch(
        'urn:btih:ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
      );
      expect(m, isNotNull);
      expect(m!.group(1), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567');
    });

    test('group(1) is the hash without the urn:btih: prefix', () {
      final m = btihRegex.firstMatch(
        'prefix urn:btih:deadbeefdeadbeefdeadbeefdeadbeefdeadbeef suffix',
      );
      expect(m, isNotNull);
      expect(m!.group(1), 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef');
    });

    test('does not match wrong-length hash', () {
      final m = btihRegex.firstMatch(
        'urn:btih:abcdef0123456789abcdef0123456789abcdef',
      );
      expect(m, isNull);
    });

    test('does not match wrong-charset hash', () {
      // Lowercase g fails both [a-fA-F0-9] (hex) and [2-7A-Z] (base32 is
      // uppercase A-Z only), so 40 g's cannot match either alternation.
      final m = btihRegex.firstMatch(
        'urn:btih:gggggggggggggggggggggggggggggggggggggggg',
      );
      expect(m, isNull);
    });

    test('does not match unrelated text', () {
      expect(btihRegex.firstMatch('not a magnet at all'), isNull);
      expect(btihRegex.firstMatch('magnet:?xt=urn:btmh:1222...'), isNull);
    });
  });

  group('normalizeRecommendationTags', () {
    test('empty input returns empty output', () {
      expect(normalizeRecommendationTags(const <String>[]), isEmpty);
    });

    test('all-invalid input returns empty output', () {
      final out = normalizeRecommendationTags(<String>['tv', '2024', 'a', '']);
      expect(out, isEmpty);
    });

    test('drops date-like tags but keeps non-date tags', () {
      final out = normalizeRecommendationTags(<String>[
        '2024',
        '2024-03',
        '2024/3',
        'Drama',
        'Action',
      ]);
      expect(out, ['Drama', 'Action']);
    });

    test('case-insensitive deduplication keeps first occurrence', () {
      final out = normalizeRecommendationTags(<String>['Sci-Fi', 'sci-fi']);
      expect(out, ['Sci-Fi']);
    });

    test('trims surrounding whitespace', () {
      final out = normalizeRecommendationTags(<String>['  Drama  ']);
      expect(out, ['Drama']);
    });

    test('drops tags with length <= 1', () {
      final out = normalizeRecommendationTags(<String>['a', 'B', 'Cool']);
      expect(out, ['Cool']);
    });

    test('drops members of the invalid set (exact case-insensitive match)', () {
      // The algorithm is `invalidTags.contains(lower)` — an exact
      // case-insensitive match against the whole tag, NOT a substring
      // contains check. So 'OVA show' (lower 'ova show') is NOT in the
      // set and is kept; only the exact (case-insensitive) matches in the
      // set are dropped.
      final out = normalizeRecommendationTags(<String>[
        'tv',
        'TV',
        'ova',
        'OVA show',
        '日本',
        '中国制造',
        '动画',
        'anime',
        'Anime Original',
        'Sci-Fi',
      ]);
      expect(out, ['OVA show', '中国制造', 'Anime Original', 'Sci-Fi']);
    });

    test('mixed realistic input preserves expected subset', () {
      final out = normalizeRecommendationTags(<String>[
        'Drama',
        'drama',
        '  Action  ',
        '2024',
        'tv',
        'Animation',
        'anime',
        'Sci-Fi',
        'sci-fi',
        'x',
        '',
      ]);
      expect(out, ['Drama', 'Action', 'Animation', 'Sci-Fi']);
    });
  });
}
