// DT-1: pure-Dart composition tests for `models/bangumi_episode_filter.dart`.
//
// Covers:
//   * `BangumiEpisode.isReleased()` — empty airdate, valid date in the
//     past / present / future, malformed date fallback, and the
//     end-of-day / next-day boundary (the implementation compares
//     `DateTime` truncated to the day, so an `airdate` of `YYYY-MM-DD`
//     and today's wall-clock date at any time must count as released).
//   * `BangumiEpisodeFilterList.withoutPhantomEpisodes()` — preserves named
//     episodes, drops nameless duplicates that share a `sort` with a named
//     one, keeps nameless episodes that own a unique `sort`, and
//     de-duplicates by `id` even when `sort` differs.
//   * `releasedEpisodes()` combines both rules and preserves original order.
//   * `latestReleasedEpisode()` returns the highest-`sort` released
//     episode, and tolerates empty / all-unreleased inputs.
//
// All time-sensitive cases use an injected fixed clock so running across a
// local-midnight boundary cannot make the suite flaky.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

final DateTime _now = DateTime(2026, 7, 19, 12);

BangumiEpisode _ep({
  required int id,
  required double sort,
  String? name,
  String? nameCn,
  String airdate = '',
  String description = '',
  String duration = '',
}) {
  return BangumiEpisode(
    id: id,
    sort: sort,
    // `name` / `nameCn` are nullable here ONLY so tests can opt out
    // of the default `'ep$id'` non-empty name and exercise the
    // nameless phantom path. The constructor wants non-null Strings,
    // so we coerce explicit `null` to the empty string.
    name: name ?? 'ep$id',
    nameCn: nameCn ?? '',
    description: description,
    airdate: airdate,
    duration: duration,
  );
}

/// A nameless phantom episode helper: keeps the call-site short
/// and unambiguous. Pass through id / sort / airdate to set those.
BangumiEpisode _phantom({
  required int id,
  required double sort,
  String airdate = '',
}) => _ep(id: id, sort: sort, name: '', nameCn: '', airdate: airdate);

String _formatDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

void main() {
  group('BangumiEpisode.isReleased()', () {
    test('empty airdate is treated as released', () {
      expect(_ep(id: 1, sort: 1, airdate: '').isReleased(now: _now), isTrue);
    });

    test('yesterday is released', () {
      final yesterday = _now.subtract(const Duration(days: 1));
      expect(
        _ep(
          id: 1,
          sort: 1,
          airdate: _formatDate(yesterday),
        ).isReleased(now: _now),
        isTrue,
      );
    });

    test('far-future airdate is not released', () {
      expect(
        _ep(id: 1, sort: 1, airdate: '2999-12-31').isReleased(now: _now),
        isFalse,
      );
    });

    test('same-day airdate is released (end-of-day boundary)', () {
      // The production code truncates `now` to a date-only `DateTime`
      // and compares via `isAfter`, so an airdate that equals today
      // (regardless of the wall-clock hour) must report released.
      expect(
        _ep(id: 1, sort: 1, airdate: _formatDate(_now)).isReleased(now: _now),
        isTrue,
      );
    });

    test('tomorrow is not released', () {
      final tomorrow = _now.add(const Duration(days: 1));
      expect(
        _ep(
          id: 1,
          sort: 1,
          airdate: _formatDate(tomorrow),
        ).isReleased(now: _now),
        isFalse,
      );
    });

    test('malformed airdate falls back to released (not crashing)', () {
      expect(
        _ep(id: 1, sort: 1, airdate: 'not-a-date').isReleased(now: _now),
        isTrue,
      );
    });

    test('Cyrillic / unicode description does not break parsing', () {
      // Description is irrelevant for isReleased, but a Cyrillic title
      // mixed with a real airdate should still parse and release.
      final yesterday = _now.subtract(const Duration(days: 1));
      expect(
        _ep(
          id: 1,
          sort: 1,
          name: 'Тест',
          nameCn: '测试集',
          airdate: _formatDate(yesterday),
          description: 'Описание эпизода',
        ).isReleased(now: _now),
        isTrue,
      );
    });
  });

  group('withoutPhantomEpisodes()', () {
    test('keeps named episodes and drops nameless duplicates by sort', () {
      // Real API quirk: same sort, different id, one with title and one
      // with no title (the phantom). The phantom must be dropped.
      final real = _ep(id: 100, sort: 1, name: 'Pilot');
      final phantom = _phantom(id: 200, sort: 1);
      final survivor = _ep(id: 101, sort: 2, name: 'Episode 2');

      final result = [real, phantom, survivor].withoutPhantomEpisodes();

      expect(result, hasLength(2));
      expect(result.map((e) => e.id), [100, 101]);
    });

    test('keeps nameless episodes whose sort is unique', () {
      // When no named episode owns a sort, a nameless entry must
      // survive the filter — otherwise the panel would silently lose
      // legitimate entries.
      final uniqueNameless = _ep(id: 50, sort: 7);
      final result = [uniqueNameless].withoutPhantomEpisodes();
      expect(result, hasLength(1));
      expect(result.first.id, 50);
    });

    test('drops phantoms even when they come before the named entry', () {
      final phantom = _phantom(id: 200, sort: 1);
      final real = _ep(id: 100, sort: 1, name: 'Pilot');
      final result = [phantom, real].withoutPhantomEpisodes();
      expect(result, hasLength(1));
      expect(result.first.id, 100);
    });

    test('de-duplicates by id across differing sorts', () {
      // Defensive guard: even if a (mistaken) backend sends the same
      // id twice, the filter must surface it only once.
      final a = _ep(id: 1, sort: 1, name: 'A');
      final dup = _ep(id: 1, sort: 2, name: 'A2');
      final b = _ep(id: 2, sort: 3, name: 'B');
      final result = [a, dup, b].withoutPhantomEpisodes();
      expect(result.map((e) => e.id), [1, 2]);
    });

    test('nameCn alone is enough to claim a sort as "named"', () {
      // Per the comment in the production code: `name.isNotEmpty ||
      // nameCn.isNotEmpty` qualifies a sort as named. A CN-only title
      // should still protect its sort from phantom duplicates.
      final cnOnly = _ep(id: 10, sort: 4, name: '', nameCn: '第一集');
      final phantom = _phantom(id: 20, sort: 4);
      final result = [cnOnly, phantom].withoutPhantomEpisodes();
      expect(result, hasLength(1));
      expect(result.first.id, 10);
    });

    test('preserves original order of the input', () {
      final a = _ep(id: 1, sort: 3, name: 'A');
      final b = _ep(id: 2, sort: 1, name: 'B');
      final c = _ep(id: 3, sort: 2, name: 'C');
      final result = [a, b, c].withoutPhantomEpisodes();
      expect(result.map((e) => e.id), [1, 2, 3]);
    });

    test('empty input is empty output', () {
      expect(<BangumiEpisode>[].withoutPhantomEpisodes(), isEmpty);
    });
  });

  group('releasedEpisodes()', () {
    test('combines phantom removal with isReleased()', () {
      final yesterday = _now.subtract(const Duration(days: 1));
      final tomorrow = _now.add(const Duration(days: 1));
      final phantomUnreleased = _phantom(
        id: 200,
        sort: 1,
        airdate: _formatDate(tomorrow),
      );
      final releasedReal = _ep(
        id: 100,
        sort: 1,
        name: 'Pilot',
        airdate: _formatDate(yesterday),
      );
      final releasedUnique = _ep(
        id: 300,
        sort: 5,
        airdate: _formatDate(yesterday),
      );
      final unreleasedReal = _ep(
        id: 400,
        sort: 7,
        name: 'Future',
        airdate: _formatDate(tomorrow),
      );

      final result = [
        phantomUnreleased,
        releasedReal,
        releasedUnique,
        unreleasedReal,
      ].releasedEpisodes(now: _now);

      expect(result.map((e) => e.id), [100, 300]);
    });
  });

  group('latestReleasedEpisode()', () {
    test('returns the highest-sort released episode', () {
      final yesterday = _now.subtract(const Duration(days: 1));
      final a = _ep(id: 1, sort: 1, airdate: _formatDate(yesterday));
      final b = _ep(id: 2, sort: 5, airdate: _formatDate(yesterday));
      final c = _ep(id: 3, sort: 3, airdate: _formatDate(yesterday));
      final latest = [a, b, c].latestReleasedEpisode(now: _now);
      expect(latest, isNotNull);
      expect(latest!.id, 2);
    });

    test('skips unreleased episodes even if they have the highest sort', () {
      final yesterday = _now.subtract(const Duration(days: 1));
      final tomorrow = _now.add(const Duration(days: 1));
      final released = _ep(id: 1, sort: 1, airdate: _formatDate(yesterday));
      final unreleased = _ep(id: 2, sort: 99, airdate: _formatDate(tomorrow));
      final latest = [released, unreleased].latestReleasedEpisode(now: _now);
      expect(latest!.id, 1);
    });

    test('returns null for an empty iterable', () {
      expect(<BangumiEpisode>[].latestReleasedEpisode(now: _now), isNull);
    });

    test('returns null when no episode is released yet', () {
      final tomorrow = _now.add(const Duration(days: 1));
      final a = _ep(id: 1, sort: 1, airdate: _formatDate(tomorrow));
      final b = _ep(id: 2, sort: 5, airdate: _formatDate(tomorrow));
      expect([a, b].latestReleasedEpisode(now: _now), isNull);
    });

    test('treats empty airdate as released', () {
      // Defensive: an episode with no airdate is "released" per
      // isReleased, so it should be eligible for latestReleasedEpisode.
      final noDate = _ep(id: 1, sort: 1, airdate: '');
      final withDate = _ep(
        id: 2,
        sort: 5,
        airdate: _formatDate(_now.subtract(const Duration(days: 1))),
      );
      final latest = [noDate, withDate].latestReleasedEpisode(now: _now);
      expect(latest!.id, 2);
    });
  });
}
