import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player/player_episode_controller.dart';

/// Phase 2 player-page responsibility split: composition tests for
/// [PlayerEpisodeController].
///
/// These mirror the `player_webview_scheduler_test.dart` precedent — pure Dart
/// composition tests exercising the cross-cutting state invariants that the
/// page's side-effect fan-out cannot reach from a unit test (no
/// `flutter/widgets.dart`, `WidgetTester`, `BuildContext`, WebView, player, or
/// prefs). Every mutation step that the page's `_onEpisodeSelected` /
/// `_onSkipNext` would normally drive is followed by
/// [PlayerEpisodeController.validateInvariants] (via [expectConsistent]) so any
/// drift between `_currentEpisode`, the `ValueNotifier`, and the
/// `playableEpisodes` snapshot surfaces immediately.
///
/// Listener hygiene: every test that attaches a listener to
/// [PlayerEpisodeController.currentEpisodeListenable] removes it via
/// [addTearDown] BEFORE the controller's [clearForDispose] runs. LIFO
/// `addTearDown` ordering guarantees the listener removal runs first; the
/// `clearForDispose` then disposes the notifier.

const _released =
    ''; // empty airdate → BangumiEpisodeFilter.isReleased() returns true
const _unreleased = '2999-01-01'; // future airdate → isReleased() returns false

BangumiEpisode _ep({
  required int id,
  required double sort,
  String? name,
  String nameCn = '',
  String airdate = _released,
  String description = '',
  String duration = '',
}) {
  return BangumiEpisode(
    id: id,
    sort: sort,
    name: name ?? 'ep$id',
    nameCn: nameCn,
    description: description,
    airdate: airdate,
    duration: duration,
  );
}

PlayerEpisodeController _controller({
  required List<BangumiEpisode> allEpisodes,
  required BangumiEpisode initialEpisode,
}) {
  final c = PlayerEpisodeController(
    allEpisodes: allEpisodes,
    initialEpisode: initialEpisode,
  );
  addTearDown(c.clearForDispose);
  return c;
}

void expectConsistent(PlayerEpisodeController c, [String? label]) {
  final errors = c.validateInvariants();
  if (errors.isNotEmpty) {
    fail(
      'invariants violated${label == null ? '' : ' ($label)'}:\n'
      '${errors.map((e) => '  - $e').join('\n')}',
    );
  }
}

void main() {
  group('validateInvariants is empty on a freshly-constructed controller', () {
    test('all-released corpus + released initial', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: b);
      expectConsistent(controller, 'fresh');
    });

    test('unreleased-initial with a released fallback', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 5);
      final u = _ep(id: 9, sort: 7, airdate: _unreleased);
      // initial is unreleased -> controller seeds `latestReleasedEpisode()` (= b).
      final controller = _controller(allEpisodes: [a, b, u], initialEpisode: u);
      expectConsistent(controller, 'fresh with released fallback');
    });

    test(
      'unreleased-initial with NO released fallback (empty released list)',
      () {
        final u = _ep(id: 9, sort: 1, airdate: _unreleased);
        final controller = _controller(allEpisodes: [u], initialEpisode: u);
        expectConsistent(controller, 'fresh with no released fallback');
      },
    );
  });

  group('seeding', () {
    test('released initial is seeded as the current episode', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: b);
      expect(controller.currentEpisode, same(b));
      expect(controller.currentEpisodeIndex, 1);
      expect(controller.episodesCount, 3);
    });

    test(
      'unreleased initial + released list -> seeded as latestReleasedEpisode',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 5);
        final u = _ep(id: 9, sort: 99, airdate: _unreleased);
        final controller = _controller(
          allEpisodes: [a, b, u],
          initialEpisode: u,
        );
        // latestReleasedEpisode() picks the released episode with the maximum
        // sort, i.e. b (sort=5).
        expect(controller.currentEpisode, same(b));
        // b is in playableEpisodes at index 1.
        expect(controller.currentEpisodeIndex, 1);
      },
    );

    test('unreleased initial + NO released episodes -> seeded as the original '
        'unreleased initial', () {
      final u = _ep(id: 9, sort: 1, airdate: _unreleased);
      final controller = _controller(allEpisodes: [u], initialEpisode: u);
      expect(controller.currentEpisode, same(u));
      // u is unreleased, so playableEpisodes is empty -> indexOf returns -1.
      expect(controller.currentEpisodeIndex, -1);
      expect(controller.episodesCount, 0);
    });
  });

  group('selectEpisode guard', () {
    test(
      'unreleased episode -> changed:false, no mutation, notifier silent',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final u = _ep(id: 9, sort: 5, airdate: _unreleased);
        final controller = _controller(allEpisodes: [a, b], initialEpisode: a);

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        final result = controller.selectEpisode(u);
        expect(result.changed, isFalse);
        expect(result.previous, same(a));
        expect(result.next, same(a));
        expect(fireCount, 0);
        expect(controller.currentEpisode, same(a));
        expectConsistent(controller, 'after unrelected select');
      },
    );

    test(
      'same-id (different object, same .id) -> changed:false, no mutation',
      () {
        final a = _ep(id: 1, sort: 1, nameCn: 'A-cn');
        final b = _ep(id: 2, sort: 3);
        // a2 has the SAME id as a but is a different object with different name
        // (so BangumiEpisode.== is false, but the id-keyed guard still fires).
        final a2 = _ep(id: 1, sort: 1, nameCn: 'A2-cn');
        final controller = _controller(allEpisodes: [a, b], initialEpisode: a);

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        final result = controller.selectEpisode(a2);
        expect(result.changed, isFalse);
        expect(fireCount, 0);
        expect(controller.currentEpisode, same(a));
        expectConsistent(controller, 'after same-id select');
      },
    );

    test('identical episode object -> changed:false, no mutation', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final controller = _controller(allEpisodes: [a, b], initialEpisode: a);

      var fireCount = 0;
      void listener() => fireCount++;
      controller.currentEpisodeListenable.addListener(listener);
      addTearDown(
        () => controller.currentEpisodeListenable.removeListener(listener),
      );

      // identical() object -> guard fires (same id).
      final result = controller.selectEpisode(controller.currentEpisode);
      expect(result.changed, isFalse);
      expect(fireCount, 0);
      expect(controller.currentEpisode, same(a));
    });

    test('a different released episode -> changed:true, notifier fires once, '
        'validateInvariants stays empty', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: a);

      var fireCount = 0;
      BangumiEpisode? lastValue;
      void listener() {
        fireCount++;
        lastValue = controller.currentEpisodeListenable.value;
      }

      controller.currentEpisodeListenable.addListener(listener);
      addTearDown(
        () => controller.currentEpisodeListenable.removeListener(listener),
      );

      final result = controller.selectEpisode(b);
      expect(result.changed, isTrue);
      expect(result.previous, same(a));
      expect(result.next, same(b));
      expect(fireCount, 1);
      expect(lastValue, same(b));
      expect(controller.currentEpisode, same(b));
      // currentEpisodeIndex now points to b's slot (index 1).
      expect(controller.currentEpisodeIndex, 1);
      expectConsistent(controller, 'after passing select');
    });
  });

  group('resolveByOffset (pure resolve, no mutation)', () {
    test('+1 on last episode returns null', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: c);
      expect(controller.resolveByOffset(1), isNull);
      expect(controller.currentEpisode, same(c));
    });

    test('+1 mid-list returns the next episode WITHOUT mutation', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: a);

      var fireCount = 0;
      void listener() => fireCount++;
      controller.currentEpisodeListenable.addListener(listener);
      addTearDown(
        () => controller.currentEpisodeListenable.removeListener(listener),
      );

      final next = controller.resolveByOffset(1);
      expect(next, same(b));
      expect(fireCount, 0);
      expect(controller.currentEpisode, same(a));
      expect(controller.currentEpisodeIndex, 0);
    });

    test('-1 on first episode returns null', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final controller = _controller(allEpisodes: [a, b], initialEpisode: a);
      expect(controller.resolveByOffset(-1), isNull);
      expect(controller.currentEpisode, same(a));
    });

    test('-1 mid-list returns the previous episode WITHOUT mutation', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: c);

      var fireCount = 0;
      void listener() => fireCount++;
      controller.currentEpisodeListenable.addListener(listener);
      addTearDown(
        () => controller.currentEpisodeListenable.removeListener(listener),
      );

      final prev = controller.resolveByOffset(-1);
      expect(prev, same(b));
      expect(fireCount, 0);
      expect(controller.currentEpisode, same(c));
    });

    test(
      '+1 on a current episode NOT in playableEpisodes returns null (no throw)',
      () {
        // Unreleased initial + no released fallback: currentEpisode lives
        // outside playableEpisodes (indexOf returns -1).
        final u = _ep(id: 9, sort: 1, airdate: _unreleased);
        final controller = _controller(allEpisodes: [u], initialEpisode: u);

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        expect(controller.resolveByOffset(1), isNull);
        expect(controller.resolveByOffset(-1), isNull);
        expect(fireCount, 0);
        expect(controller.currentEpisode, same(u));
      },
    );

    test(
      'notifier listener counter stays at 0 across all resolveByOffset calls',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final c = _ep(id: 3, sort: 5);
        final d = _ep(id: 4, sort: 7);
        final controller = _controller(
          allEpisodes: [a, b, c, d],
          initialEpisode: b,
        );

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        // Drive +1/-1 around the corpus boundary and the middle. None of these
        // may mutate state.
        expect(controller.resolveByOffset(1), same(c));
        expect(controller.resolveByOffset(-1), same(a));
        expect(controller.resolveByOffset(2), same(d));
        expect(controller.resolveByOffset(-2), isNull);
        expect(controller.resolveByOffset(5), isNull);
        expect(fireCount, 0);
        expect(controller.currentEpisode, same(b));
        expect(controller.currentEpisodeIndex, 1);
      },
    );
  });

  group('currentEpisodeNumbers / currentEpisodeNumbersAgainst', () {
    test(
      'released initial as the 3rd by-id -> EpisodeNumbers(absolute:5, relative:3)',
      () {
        final x = _ep(id: 10, sort: 0);
        final y = _ep(id: 11, sort: 2);
        final b = _ep(id: 3, sort: 5);
        final controller = _controller(
          allEpisodes: [x, y, b],
          initialEpisode: b,
        );
        final n = controller.currentEpisodeNumbers;
        expect(n.absolute, 5);
        expect(n.relative, 3);
      },
    );

    test(
      'unreleased initial not found by id in allEpisodes -> relative == absolute',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final u = _ep(id: 99, sort: 7, airdate: _unreleased);
        final controller = _controller(allEpisodes: [a, b], initialEpisode: u);
        // u is unreleased + released fallback b exists -> current = b (sort=3).
        // The current episode is b, which IS in allEpisodes=[a, b] at index 1.
        // So relative would be 2. To exercise the "not found" branch, we ask
        // currentEpisodeNumbersAgainst against an allEpisodes list that does
        // NOT contain b by id.
        final n = controller.currentEpisodeNumbersAgainst([a]);
        expect(n.absolute, b.sort.toInt());
        expect(n.relative, n.absolute);
      },
    );

    test(
      'currentEpisodeNumbersAgainst does NOT cache: fresh list returns fresh '
      'relative',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final x = _ep(id: 9, sort: 0);
        final controller = _controller(
          allEpisodes: [x, a, b],
          initialEpisode: b,
        );
        // initial constructor list: [x, a, b] -> b at index 2 -> relative 3.
        expect(controller.currentEpisodeNumbers.relative, 3);

        // Asking against a fresh list where b is now 1st returns relative 1.
        final fresh = controller.currentEpisodeNumbersAgainst([b, x, a]);
        expect(fresh.absolute, 3);
        expect(fresh.relative, 1);

        // And the cached getter is unaffected (still computed against the
        // constructor's _allEpisodes snapshot).
        expect(controller.currentEpisodeNumbers.relative, 3);
      },
    );
  });

  group('reset', () {
    test('with newAllEpisodes recomputes playableEpisodes; newInitial released '
        're-seeds currentEpisode and fires the notifier', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final dNew = _ep(id: 4, sort: 7);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: a);
      expect(controller.episodesCount, 3);
      expect(controller.currentEpisode, same(a));

      var fireCount = 0;
      BangumiEpisode? lastValue;
      void listener() {
        fireCount++;
        lastValue = controller.currentEpisodeListenable.value;
      }

      controller.currentEpisodeListenable.addListener(listener);
      addTearDown(
        () => controller.currentEpisodeListenable.removeListener(listener),
      );

      controller.reset(newInitial: dNew, newAllEpisodes: [b, c, dNew]);
      expect(controller.episodesCount, 3);
      expect(controller.playableEpisodes.map((e) => e.id).toList(), [2, 3, 4]);
      expect(controller.currentEpisode, same(dNew));
      expect(fireCount, 1);
      expect(lastValue, same(dNew));
      expect(controller.currentEpisodeIndex, 2);
      expectConsistent(controller, 'after reset with new corpus + new initial');
    });

    test(
      'with both null is a strict no-op: no state change, notifier silent',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final c = _ep(id: 3, sort: 5);
        final controller = _controller(
          allEpisodes: [a, b, c],
          initialEpisode: b,
        );

        final currentBefore = controller.currentEpisode;
        final idsBefore = controller.playableEpisodes.map((e) => e.id).toList();
        final indexBefore = controller.currentEpisodeIndex;

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        controller.reset();

        expect(fireCount, 0);
        expect(controller.currentEpisode, same(currentBefore));
        expect(
          controller.playableEpisodes.map((e) => e.id).toList(),
          idsBefore,
        );
        expect(controller.currentEpisodeIndex, indexBefore);
        expectConsistent(controller, 'after no-op reset');
      },
    );

    test(
      'reset with newInitial only (no newAllEpisodes) re-seeds against the existing playable list',
      () {
        final a = _ep(id: 1, sort: 1);
        final b = _ep(id: 2, sort: 3);
        final c = _ep(id: 3, sort: 5);
        final controller = _controller(
          allEpisodes: [a, b, c],
          initialEpisode: a,
        );

        var fireCount = 0;
        void listener() => fireCount++;
        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        controller.reset(newInitial: c);
        expect(controller.currentEpisode, same(c));
        expect(fireCount, 1);
        // playableEpisodes is unchanged (no newAllEpisodes supplied).
        expect(controller.episodesCount, 3);
        expect(controller.currentEpisodeIndex, 2);
        expectConsistent(controller, 'after initial-only reset');
      },
    );

    test(
      'with newAllEpisodes only re-anchors current episode by id and keeps offset navigation usable',
      () {
        final a = _ep(id: 1, sort: 1);
        final bOld = _ep(id: 2, sort: 2, nameCn: 'old title');
        final c = _ep(id: 3, sort: 3);
        final d = _ep(id: 4, sort: 4);
        final bRefreshed = _ep(id: 2, sort: 2, nameCn: 'fresh title');
        final controller = _controller(
          allEpisodes: [a, bOld, c],
          initialEpisode: bOld,
        );

        var fireCount = 0;
        BangumiEpisode? lastValue;
        void listener() {
          fireCount++;
          lastValue = controller.currentEpisodeListenable.value;
        }

        controller.currentEpisodeListenable.addListener(listener);
        addTearDown(
          () => controller.currentEpisodeListenable.removeListener(listener),
        );

        controller.reset(newAllEpisodes: [a, bRefreshed, c, d]);

        expect(controller.currentEpisode, same(bRefreshed));
        expect(controller.currentEpisode.nameCn, 'fresh title');
        expect(controller.currentEpisodeIndex, 1);
        expect(controller.resolveByOffset(1), same(c));
        expect(controller.allEpisodes.map((e) => e.id).toList(), [1, 2, 3, 4]);
        expect(controller.currentEpisodeNumbers.relative, 2);
        expect(fireCount, 1);
        expect(lastValue, same(bRefreshed));
        expectConsistent(controller, 'after metadata refresh re-anchor');
      },
    );
  });

  group('validateInvariants catches violations', () {
    test('advancing via selectEpisode to a different released episode keeps '
        'invariants empty', () {
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: a);
      expectConsistent(controller, 'before advance');
      controller.selectEpisode(b);
      expectConsistent(controller, 'after first advance');
      controller.selectEpisode(c);
      expectConsistent(controller, 'after second advance');
      expect(controller.currentEpisode, same(c));
    });

    test('selecting a released-but-phantom episode (filtered out of '
        'playableEpisodes) trips check #2', () {
      // A is a named episode; P is a nameless, same-sort, released phantom
      // that withoutPhantomEpisodes() drops because its sort is covered by
      // the named A. P.id is distinct from A.id.
      final a = _ep(id: 1, sort: 3, nameCn: 'A');
      final p = _ep(id: 2, sort: 3, name: '', nameCn: '', airdate: _released);
      final controller = _controller(allEpisodes: [a, p], initialEpisode: a);
      // The phantom dedup leaves playableEpisodes as just [A].
      expect(controller.playableEpisodes.map((e) => e.id).toList(), [1]);
      expectConsistent(controller, 'before phantom select');

      // P is released and carries a distinct id, so selectEpisode's guard
      // passes and the controller mutates _currentEpisode to P. P is NOT in
      // playableEpisodes (phantom) and NOT the original initialEpisode (A),
      // so validateInvariants check #2 fires.
      final result = controller.selectEpisode(p);
      expect(result.changed, isTrue);
      expect(controller.currentEpisode, same(p));

      final errors = controller.validateInvariants();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('is neither in playableEpisodes'));
    });

    test('unreachable-from-public-surface branches: notifier/_currentEpisode '
        'never drift, released-filter never drops a released ep, no dup ids, '
        'allEpisodes snapshot stays consistent', () {
      // This is a regression guard: any future code change that opens a path
      // for the unreachable branches would trip here. The public surface
      // alone cannot drive checks #1/#3/#4/#5 to fire, so we assert that all
      // branches STAY green under the full public surface (construct +
      // selectEpisode advancing + reset with new corpus + reset no-op).
      final a = _ep(id: 1, sort: 1);
      final b = _ep(id: 2, sort: 3);
      final c = _ep(id: 3, sort: 5);
      final d = _ep(id: 4, sort: 7);
      final controller = _controller(allEpisodes: [a, b, c], initialEpisode: a);
      expectConsistent(controller, 'construct');
      controller.selectEpisode(b);
      expectConsistent(controller, 'advance to b');
      controller.selectEpisode(c);
      expectConsistent(controller, 'advance to c');
      controller.reset(newInitial: d, newAllEpisodes: [b, c, d]);
      expectConsistent(controller, 'reset corpus+initial');
      controller.reset();
      expectConsistent(controller, 'no-op reset');
    });
  });

  group('playableEpisodes is an unmodifiable view', () {
    test('add throws UnsupportedError', () {
      final a = _ep(id: 1, sort: 1);
      final controller = _controller(allEpisodes: [a], initialEpisode: a);
      expect(
        () => controller.playableEpisodes.add(_ep(id: 2, sort: 3)),
        throwsUnsupportedError,
      );
    });

    test('remove throws UnsupportedError', () {
      final a = _ep(id: 1, sort: 1);
      final controller = _controller(allEpisodes: [a], initialEpisode: a);
      expect(
        () => controller.playableEpisodes.remove(a),
        throwsUnsupportedError,
      );
    });
  });
}
