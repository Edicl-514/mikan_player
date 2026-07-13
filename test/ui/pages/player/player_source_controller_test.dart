import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';
import 'package:mikan_player/ui/pages/player/player_source_controller.dart';

/// Phase 2 player-page responsibility split: composition tests for
/// [PlayerSourceController].
///
/// These mirror the `player_episode_controller_test.dart` precedent — pure
/// Dart composition tests exercising every mutator on the Mikan + DMHY
/// source-loading state object (no `flutter/widgets.dart`, `WidgetTester`,
/// `BuildContext`, WebView, player, or prefs). Every mutation step is
/// followed by [PlayerSourceController.validateInvariants] (via
/// [expectConsistent]) so the deliberate asymmetries (the
/// `markMikanReloadForEpisode` preserve-error case, the `resetForSwitching`
/// preserve-anime case) surface as explicit assertions rather than silent
/// regressions.

MikanSearchResult _anime({String id = 'm1', String name = 'anime'}) =>
    MikanSearchResult(id: id, name: name, imageUrl: '');

MikanEpisodeResource _mikanRes({
  required String magnet,
  String title = 'ep',
  String size = '1GB',
  String updateTime = '2024-01-01',
  int? episode,
}) => MikanEpisodeResource(
  title: title,
  magnet: magnet,
  size: size,
  updateTime: updateTime,
  episode: episode,
);

DmhyResource _dmhyRes({
  required String magnet,
  String title = 'ep',
  String size = '1GB',
  String publishDate = '2024-01-01',
  int? episode,
}) => DmhyResource(
  title: title,
  magnet: magnet,
  size: size,
  publishDate: publishDate,
  episode: episode,
);

PlayerSourceController _controller() {
  final c = PlayerSourceController();
  addTearDown(c.clearForDispose);
  return c;
}

void expectConsistent(PlayerSourceController c, [String? label]) {
  final errors = c.validateInvariants();
  if (errors.isNotEmpty) {
    fail(
      'invariants violated${label == null ? '' : ' ($label)'}:\n'
      '${errors.map((e) => '  - $e').join('\n')}',
    );
  }
}

void expectState(
  PlayerSourceController c, {
  required bool isLoadingMikan,
  Object? mikanError, // Object? so null vs "未找到番剧" vs "boom" distinguish
  Object? mikanAnime,
  Object? mikanResources,
  required bool isLoadingDmhy,
  Object? dmhyError,
  Object? dmhyResources,
}) {
  expect(c.isLoadingMikan, isLoadingMikan);
  expect(c.isLoadingDmhy, isLoadingDmhy);
  if (mikanError is String?) {
    expect(c.mikanError, mikanError);
  }
  if (dmhyError is String?) {
    expect(c.dmhyError, dmhyError);
  }
  if (mikanAnime == null) {
    expect(c.mikanAnime, isNull);
  } else if (mikanAnime is MikanSearchResult) {
    expect(c.mikanAnime, same(mikanAnime));
  }
  if (mikanResources is List<MikanEpisodeResource>) {
    expect(c.mikanResources, mikanResources);
  } else if (mikanResources == <Object>[]) {
    expect(c.mikanResources, isEmpty);
  }
  if (dmhyResources is List<DmhyResource>) {
    expect(c.dmhyResources, dmhyResources);
  } else if (dmhyResources == <Object>[]) {
    expect(c.dmhyResources, isEmpty);
  }
}

void main() {
  group('construction', () {
    test('fresh controller has all defaults and empty validateInvariants', () {
      final c = _controller();
      expectState(
        c,
        isLoadingMikan: false,
        mikanError: null,
        mikanAnime: null,
        mikanResources: <Object>[],
        isLoadingDmhy: false,
        dmhyError: null,
        dmhyResources: <Object>[],
      );
      expectConsistent(c, 'fresh');
    });
  });

  group('mikan load lifecycle', () {
    test('markMikanLoading -> setMikanAnime -> setMikanResources', () {
      final c = _controller();
      final anime = _anime();

      c.markMikanLoading();
      expectState(
        c,
        isLoadingMikan: true,
        mikanError: null,
        mikanAnime: null, // preserved from prior (null)
        mikanResources: <Object>[],
        isLoadingDmhy: false,
        dmhyError: null,
        dmhyResources: <Object>[],
      );
      expectConsistent(c, 'after markMikanLoading');

      c.setMikanAnime(anime);
      expect(c.mikanAnime, same(anime));
      expect(c.isLoadingMikan, isTrue); // still loading resources
      expectConsistent(c, 'after setMikanAnime');

      final eps = [
        _mikanRes(magnet: 'magnet:?xt=urn:btih:aaa', episode: 1),
        _mikanRes(magnet: 'magnet:?xt=urn:btih:bbb', episode: 1),
      ];
      c.setMikanResources(eps);
      expect(c.mikanResources, eps);
      expect(c.isLoadingMikan, isFalse);
      expect(c.mikanError, isNull);
      expectConsistent(c, 'after setMikanResources');
    });

    test('explicit relative-error check asserts isObject value-equal list', () {
      final c = _controller();
      final eps = [_mikanRes(magnet: 'x', episode: 1)];
      c.setMikanResources(eps);
      expect(c.mikanResources, equals(eps));
      expectConsistent(c, 'after setMikanResources single');
    });
  });

  group('mikan not-found path', () {
    test(
      'markMikanLoading -> setMikanNotFound sets the verbatim Chinese error',
      () {
        final c = _controller();
        c.markMikanLoading();
        expectConsistent(c, 'after markMikanLoading');

        c.setMikanNotFound();
        expect(c.isLoadingMikan, isFalse);
        expect(c.mikanError, '未找到番剧');
        expectConsistent(c, 'after setMikanNotFound');
      },
    );
  });

  group('mikan error path', () {
    test('markMikanLoading -> setMikanError("boom") ends loading', () {
      final c = _controller();
      c.markMikanLoading();
      expectConsistent(c, 'after markMikanLoading');

      c.setMikanError('boom');
      expect(c.isLoadingMikan, isFalse);
      expect(c.mikanError, 'boom');
      expectConsistent(c, 'after setMikanError');
    });
  });

  group('mikan episode.id==0 idle path', () {
    test('markMikanLoading -> setMikanAnime -> markMikanIdle leaves resources '
        'empty', () {
      final c = _controller();
      final anime = _anime();
      c.markMikanLoading();
      c.setMikanAnime(anime);
      expectConsistent(c, 'after setMikanAnime');

      c.markMikanIdle();
      expect(c.isLoadingMikan, isFalse);
      expect(c.mikanResources, isEmpty);
      expect(c.mikanAnime, same(anime)); // anime still bound
      expectConsistent(c, 'after markMikanIdle');
    });
  });

  group('mikan reload-for-episode preserves error', () {
    test(
      'an error set before reload is NOT cleared by markMikanReloadForEpisode',
      () {
        final c = _controller();
        c.markMikanLoading();
        c.setMikanError('boom');
        expectConsistent(c, 'after setMikanError');

        // CRITICAL asymmetry: markMikanReloadForEpisode does NOT clear mikanError.
        c.markMikanReloadForEpisode();
        expect(c.isLoadingMikan, isTrue);
        expect(c.mikanError, 'boom'); // NOT cleared
        expect(c.mikanResources, isEmpty);
        expectConsistent(c, 'after markMikanReloadForEpisode');

        final eps = [_mikanRes(magnet: 'magnet:?xt=urn:btih:ccc', episode: 2)];
        c.setMikanResources(eps);
        expect(c.mikanResources, eps);
        expect(c.isLoadingMikan, isFalse);
        expect(
          c.mikanError,
          'boom',
        ); // still set until a fresh markMikanLoading
        expectConsistent(c, 'after setMikanResources');
      },
    );
  });

  group('mikan reload-for-episode preserves anime', () {
    test('markMikanReloadForEpisode keeps mikanAnime and clears resources', () {
      final c = _controller();
      final anime = _anime();
      c.markMikanLoading();
      c.setMikanAnime(anime);
      final eps = [_mikanRes(magnet: 'magnet:?xt=urn:btih:ddd', episode: 1)];
      c.setMikanResources(eps);
      expectConsistent(c, 'after populated state');

      c.markMikanReloadForEpisode();
      expect(c.mikanAnime, same(anime)); // preserved
      expect(c.mikanResources, isEmpty); // cleared
      expect(c.isLoadingMikan, isTrue);
      expectConsistent(c, 'after markMikanReloadForEpisode');
    });
  });

  group('dmhy lifecycle', () {
    test('markDmhyLoading -> setDmhyResources', () {
      final c = _controller();
      c.markDmhyLoading();
      expect(c.isLoadingDmhy, isTrue);
      expect(c.dmhyError, isNull);
      expect(c.dmhyResources, isEmpty);
      expectConsistent(c, 'after markDmhyLoading');

      final dres = [
        _dmhyRes(magnet: 'magnet:?xt=urn:btih:eee', episode: 1),
        _dmhyRes(magnet: 'magnet:?xt=urn:btih:fff', episode: 1),
      ];
      c.setDmhyResources(dres);
      expect(c.dmhyResources, dres);
      expect(c.isLoadingDmhy, isFalse);
      expect(c.dmhyError, isNull);
      expectConsistent(c, 'after setDmhyResources');
    });
  });

  group('dmhy error', () {
    test('markDmhyLoading -> setDmhyError("boom") ends loading', () {
      final c = _controller();
      c.markDmhyLoading();
      expectConsistent(c, 'after markDmhyLoading');

      c.setDmhyError('boom');
      expect(c.isLoadingDmhy, isFalse);
      expect(c.dmhyError, 'boom');
      expectConsistent(c, 'after setDmhyError');
    });
  });

  group('resetForSwitching clears transient state but preserves mikanAnime', () {
    test('populated state -> resetForSwitching keeps mikanAnime only', () {
      final c = _controller();
      final anime = _anime();
      c.markMikanLoading();
      c.setMikanAnime(anime);
      final eps = [_mikanRes(magnet: 'magnet:?xt=urn:btih:ggg', episode: 1)];
      c.setMikanResources(eps);
      c.markDmhyLoading();
      final dres = [_dmhyRes(magnet: 'magnet:?xt=urn:btih:hhh', episode: 1)];
      c.setDmhyResources(dres);
      expectConsistent(c, 'after populated state');

      c.resetForSwitching();
      // CRITICAL asymmetry: mikanAnime preserved, everything transient cleared.
      expect(c.mikanAnime, same(anime));
      expect(c.isLoadingMikan, isFalse);
      expect(c.mikanError, isNull);
      expect(c.mikanResources, isEmpty);
      expect(c.isLoadingDmhy, isFalse);
      expect(c.dmhyError, isNull);
      expect(c.dmhyResources, isEmpty);
      expectConsistent(c, 'after resetForSwitching');
    });

    test('resetForSwitching with no prior anime keeps mikanAnime null', () {
      final c = _controller();
      c.resetForSwitching();
      expect(c.mikanAnime, isNull);
      expect(c.isLoadingMikan, isFalse);
      expect(c.isLoadingDmhy, isFalse);
      expectConsistent(c, 'after bare resetForSwitching');
    });
  });

  group('async source request tokens', () {
    test('a newer request invalidates only the same provider request', () {
      final c = _controller();
      final firstMikan = c.beginMikanRequest();
      final dmhy = c.beginDmhyRequest();
      final secondMikan = c.beginMikanRequest();

      expect(c.isMikanRequestCurrent(firstMikan), isFalse);
      expect(c.isMikanRequestCurrent(secondMikan), isTrue);
      // Mikan and DMHY load in parallel, so a Mikan retry must not discard a
      // still-current DMHY response.
      expect(c.isDmhyRequestCurrent(dmhy), isTrue);
      expectConsistent(c, 'after provider-local replacement');
    });

    test('context invalidation discards both in-flight provider requests', () {
      final c = _controller();
      final mikan = c.beginMikanRequest();
      final dmhy = c.beginDmhyRequest();

      c.invalidatePendingRequests();

      expect(c.isMikanRequestCurrent(mikan), isFalse);
      expect(c.isDmhyRequestCurrent(dmhy), isFalse);
      expectConsistent(c, 'after explicit context invalidation');
    });

    test('switching and disposal invalidate in-flight requests', () {
      final c = _controller();
      final beforeSwitchMikan = c.beginMikanRequest();
      final beforeSwitchDmhy = c.beginDmhyRequest();

      c.resetForSwitching();

      expect(c.isMikanRequestCurrent(beforeSwitchMikan), isFalse);
      expect(c.isDmhyRequestCurrent(beforeSwitchDmhy), isFalse);

      final beforeDisposeMikan = c.beginMikanRequest();
      final beforeDisposeDmhy = c.beginDmhyRequest();
      c.clearForDispose();

      expect(c.isMikanRequestCurrent(beforeDisposeMikan), isFalse);
      expect(c.isDmhyRequestCurrent(beforeDisposeDmhy), isFalse);
      expectConsistent(c, 'after disposal invalidation');
    });
  });

  group('read views return unmodifiable lists', () {
    test('mikanResources.add throws UnsupportedError', () {
      final c = _controller();
      final eps = [_mikanRes(magnet: 'magnet:?xt=urn:btih:iii', episode: 1)];
      c.setMikanResources(eps);
      expect(
        () => c.mikanResources.add(_mikanRes(magnet: 'extra', episode: 1)),
        throwsUnsupportedError,
      );
    });

    test('dmhyResources.add throws UnsupportedError', () {
      final c = _controller();
      final dres = [_dmhyRes(magnet: 'magnet:?xt=urn:btih:jjj', episode: 1)];
      c.setDmhyResources(dres);
      expect(
        () => c.dmhyResources.add(_dmhyRes(magnet: 'extra', episode: 1)),
        throwsUnsupportedError,
      );
    });

    test('mikanResources.remove throws UnsupportedError', () {
      final c = _controller();
      final first = _mikanRes(magnet: 'magnet:?xt=urn:btih:kkk', episode: 1);
      c.setMikanResources([first]);
      expect(() => c.mikanResources.remove(first), throwsUnsupportedError);
    });
  });

  group('isLoadingAny / hasErrorAny convenience', () {
    test('fresh: both false', () {
      final c = _controller();
      expect(c.isLoadingAny, isFalse);
      expect(c.hasErrorAny, isFalse);
    });

    test('mikan-only loading true -> isLoadingAny true', () {
      final c = _controller();
      c.markMikanLoading();
      expect(c.isLoadingAny, isTrue);
      expect(c.hasErrorAny, isFalse);
    });

    test('dmhy-only loading true -> isLoadingAny true', () {
      final c = _controller();
      c.markDmhyLoading();
      expect(c.isLoadingAny, isTrue);
      expect(c.hasErrorAny, isFalse);
    });

    test('mikan error only -> hasErrorAny true, isLoadingAny false', () {
      final c = _controller();
      c.setMikanError('boom');
      expect(c.isLoadingAny, isFalse);
      expect(c.hasErrorAny, isTrue);
    });

    test('dmhy error only -> hasErrorAny true', () {
      final c = _controller();
      c.setDmhyError('boom');
      expect(c.hasErrorAny, isTrue);
      expect(c.isLoadingAny, isFalse);
    });

    test('mixed: mikan loading + dmhy error -> both conveniences true', () {
      final c = _controller();
      c.markMikanLoading();
      c.setDmhyError('boom');
      expect(c.isLoadingAny, isTrue);
      expect(c.hasErrorAny, isTrue);
    });

    test('resetForSwitching zeros both conveniences', () {
      final c = _controller();
      c.markMikanLoading();
      c.setDmhyError('boom');
      c.resetForSwitching();
      expect(c.isLoadingAny, isFalse);
      expect(c.hasErrorAny, isFalse);
    });
  });
}
