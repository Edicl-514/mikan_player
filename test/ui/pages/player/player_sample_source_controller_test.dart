import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_sample_source_controller.dart';

/// Phase 2 Sub-commit B: composition tests for [PlayerSampleSourceController].
///
/// Pure Dart (no WidgetTester / WebView / scheduler). Every mutation step is
/// followed by [PlayerSampleSourceController.validateInvariants] via
/// [expectConsistent].

SearchPlayResult _page({
  String sourceName = 'srcA',
  String playPageUrl = 'https://example.com/play',
  String? channelName,
  BigInt? channelIndex,
  String? directVideoUrl,
}) => SearchPlayResult(
  sourceName: sourceName,
  playPageUrl: playPageUrl,
  videoRegex: r'\.m3u8',
  directVideoUrl: directVideoUrl,
  channelName: channelName,
  channelIndex: channelIndex,
  enableNestedUrl: false,
);

SourceSearchProgress _progress(
  String name, {
  SearchStep step = SearchStep.pending,
  String? error,
}) => SourceSearchProgress(
  sourceName: name,
  step: step,
  error: error,
  enableNestedUrl: false,
);

PlayerSampleSourceController _controller() {
  final c = PlayerSampleSourceController();
  addTearDown(c.clearForDispose);
  return c;
}

void expectConsistent(PlayerSampleSourceController c, [String? label]) {
  final errors = c.validateInvariants();
  if (errors.isNotEmpty) {
    fail(
      'invariants violated${label == null ? '' : ' ($label)'}:\n'
      '${errors.map((e) => '  - $e').join('\n')}',
    );
  }
}

void main() {
  group('construction', () {
    test('fresh controller has defaults and empty validateInvariants', () {
      final c = _controller();
      expect(c.isLoadingSample, isFalse);
      expect(c.sampleError, isNull);
      expect(c.samplePlayPages, isEmpty);
      expect(c.sampleSuccessfulSources, isEmpty);
      expect(c.sampleLoadToken, 0);
      expect(c.enabledSourceNames, isEmpty);
      expect(c.sourceTiers, isEmpty);
      expect(c.sourceProgressMap, isEmpty);
      expect(c.pageEnqueueSeq, isEmpty);
      expect(c.nextPageEnqueueSeq, 0);
      expectConsistent(c, 'fresh');
    });
  });

  group('load token', () {
    test('bumpLoadToken increments and isCurrentLoadToken tracks currency', () {
      final c = _controller();
      expect(c.isCurrentLoadToken(0), isTrue);

      final t1 = c.bumpLoadToken();
      expect(t1, 1);
      expect(c.sampleLoadToken, 1);
      expect(c.isCurrentLoadToken(1), isTrue);
      expect(c.isCurrentLoadToken(0), isFalse);

      final t2 = c.bumpLoadToken();
      expect(t2, 2);
      expect(c.isCurrentLoadToken(1), isFalse);
      expectConsistent(c, 'after bumps');
    });
  });

  group('loading / error', () {
    test('markSampleLoading clears error and sets loading', () {
      final c = _controller();
      c.setSampleError('boom');
      c.markSampleLoading();
      expect(c.isLoadingSample, isTrue);
      expect(c.sampleError, isNull);
      expectConsistent(c);
    });

    test('setSampleErrorAndIdle ends load with message', () {
      final c = _controller();
      c.markSampleLoading();
      c.setSampleErrorAndIdle('未启用任何播放源');
      expect(c.isLoadingSample, isFalse);
      expect(c.sampleError, '未启用任何播放源');
      expectConsistent(c);
    });

    test('markSampleIdle leaves error untouched', () {
      final c = _controller();
      c.setSampleError('linger');
      c.markSampleIdle();
      expect(c.isLoadingSample, isFalse);
      expect(c.sampleError, 'linger');
      expectConsistent(c);
    });
  });

  group('beginNewSearchReset', () {
    test('clears owned fields and marks loading', () {
      final c = _controller();
      c.bumpLoadToken();
      c.beginNewSearchReset();
      // token is NOT reset by beginNewSearchReset (token lives across reset)
      expect(c.sampleLoadToken, 1);

      c.setEnabledSources(names: ['a', 'b'], tiers: {'a': 0, 'b': 1});
      c.initPendingProgressForEnabled();
      c.appendPlayPage(_page(sourceName: 'a'), pageKey: 'a');
      c.addSuccessfulSource(_page(sourceName: 'a', directVideoUrl: 'u'));
      c.setSampleError('old');

      c.beginNewSearchReset();
      expect(c.isLoadingSample, isTrue);
      expect(c.sampleError, isNull);
      expect(c.samplePlayPages, isEmpty);
      expect(c.sampleSuccessfulSources, isEmpty);
      expect(c.pageEnqueueSeq, isEmpty);
      expect(c.nextPageEnqueueSeq, 0);
      expect(c.sourceProgressMap, isEmpty);
      expect(c.enabledSourceNames, isEmpty);
      expect(c.sourceTiers, isEmpty);
      expect(c.sampleLoadToken, 1); // preserved
      expectConsistent(c, 'after beginNewSearchReset');
    });
  });

  group('appendPlayPage / enqueue seq', () {
    test('assigns monotonic enqueue seq per pageKey', () {
      final c = _controller();
      c.appendPlayPage(_page(sourceName: 'a'), pageKey: 'a');
      c.appendPlayPage(_page(sourceName: 'b'), pageKey: 'b');
      c.appendPlayPage(
        _page(sourceName: 'a', channelIndex: BigInt.one),
        pageKey: 'a#1',
      );

      expect(c.samplePlayPages, hasLength(3));
      expect(c.pageEnqueueSeq['a'], 0);
      expect(c.pageEnqueueSeq['b'], 1);
      expect(c.pageEnqueueSeq['a#1'], 2);
      expect(c.nextPageEnqueueSeq, 3);
      expectConsistent(c, 'after appends');
    });

    test('replacePlayPageAt updates entry without touching enqueue', () {
      final c = _controller();
      c.appendPlayPage(
        _page(sourceName: 'a', playPageUrl: 'old'),
        pageKey: 'a',
      );
      final seqBefore = Map<String, int>.from(c.pageEnqueueSeq);
      c.replacePlayPageAt(0, _page(sourceName: 'a', playPageUrl: 'new'));
      expect(c.samplePlayPages.single.playPageUrl, 'new');
      expect(c.pageEnqueueSeq, seqBefore);
      expectConsistent(c);
    });
  });

  group('progress map / enabled sources', () {
    test('setEnabledSources + initPending + setSourceProgress', () {
      final c = _controller();
      c.setEnabledSources(names: ['x', 'y'], tiers: {'x': 0, 'y': 2});
      expect(c.enabledSourceNames, ['x', 'y']);
      expect(c.sourceTiers['x'], 0);
      expect(c.sourceTiers['y'], 2);

      c.initPendingProgressForEnabled();
      expect(c.sourceProgressMap['x']!.step, SearchStep.pending);
      expect(c.sourceProgressMap['y']!.step, SearchStep.pending);

      c.setSourceProgress('x', _progress('x', step: SearchStep.success));
      expect(c.sourceProgressMap['x']!.step, SearchStep.success);
      expect(c.sourceProgressMap['y']!.step, SearchStep.pending);
      expectConsistent(c);
    });
  });

  group('successful sources', () {
    test(
      'addSuccessfulSource appends; anySuccessfulSource matches page policy',
      () {
        final c = _controller();
        final a = _page(sourceName: 'a', directVideoUrl: 'u1');
        final b = _page(sourceName: 'b', directVideoUrl: 'u2');
        c.addSuccessfulSource(a);
        c.addSuccessfulSource(b);
        // Unconditional append — page-level dedupe is external.
        c.addSuccessfulSource(a);
        expect(c.sampleSuccessfulSources, hasLength(3));
        expect(c.anySuccessfulSource((s) => s.sourceName == 'a'), isTrue);
        expect(c.anySuccessfulSource((s) => s.sourceName == 'z'), isFalse);
        expectConsistent(c);
      },
    );
  });

  group('sortPlayPagesByTier', () {
    test('orders by tier ascending with missing → 999', () {
      final c = _controller();
      c.setEnabledSources(
        names: ['low', 'high', 'mid'],
        tiers: {'low': 0, 'mid': 1},
      );
      c.appendPlayPage(_page(sourceName: 'high'), pageKey: 'high');
      c.appendPlayPage(_page(sourceName: 'low'), pageKey: 'low');
      c.appendPlayPage(_page(sourceName: 'mid'), pageKey: 'mid');
      c.sortPlayPagesByTier();
      expect(c.samplePlayPages.map((p) => p.sourceName).toList(), [
        'low',
        'mid',
        'high',
      ]);
      // enqueue seq unchanged by sort
      expect(c.pageEnqueueSeq['high'], 0);
      expect(c.pageEnqueueSeq['low'], 1);
      expectConsistent(c);
    });
  });

  group('resetForSwitching', () {
    test('clears sample transient state like episode switch', () {
      final c = _controller();
      c.bumpLoadToken();
      c.beginNewSearchReset();
      c.setEnabledSources(names: ['a'], tiers: {'a': 0});
      c.initPendingProgressForEnabled();
      c.appendPlayPage(_page(), pageKey: 'a');
      c.addSuccessfulSource(_page(directVideoUrl: 'u'));

      c.resetForSwitching();
      expect(c.isLoadingSample, isFalse);
      expect(c.sampleError, isNull);
      expect(c.samplePlayPages, isEmpty);
      expect(c.sampleSuccessfulSources, isEmpty);
      expect(c.pageEnqueueSeq, isEmpty);
      expect(c.nextPageEnqueueSeq, 0);
      expect(c.sourceProgressMap, isEmpty);
      expect(c.enabledSourceNames, isEmpty);
      expect(c.sourceTiers, isEmpty);
      expect(c.sampleLoadToken, 1); // not cleared
      expectConsistent(c, 'after resetForSwitching');
    });
  });

  group('unmodifiable views', () {
    test('list and map views throw on mutation', () {
      final c = _controller();
      c.setEnabledSources(names: ['a'], tiers: {'a': 0});
      c.initPendingProgressForEnabled();
      c.appendPlayPage(_page(), pageKey: 'a');
      c.addSuccessfulSource(_page(directVideoUrl: 'u'));

      expect(
        () => c.samplePlayPages.add(_page(sourceName: 'x')),
        throwsUnsupportedError,
      );
      expect(
        () => c.sampleSuccessfulSources.add(_page(sourceName: 'x')),
        throwsUnsupportedError,
      );
      expect(() => c.enabledSourceNames.add('z'), throwsUnsupportedError);
      expect(() => c.sourceTiers['a'] = 9, throwsUnsupportedError);
      expect(
        () => c.sourceProgressMap['a'] = _progress('a'),
        throwsUnsupportedError,
      );
      expect(() => c.pageEnqueueSeq['a'] = 99, throwsUnsupportedError);
      expectConsistent(c);
    });
  });

  group('validateInvariants', () {
    test('empty after public surface exercise', () {
      final c = _controller();
      final token = c.bumpLoadToken();
      expect(c.isCurrentLoadToken(token), isTrue);
      c.beginNewSearchReset();
      c.setEnabledSources(names: ['a', 'b'], tiers: {'a': 0, 'b': 1});
      c.initPendingProgressForEnabled();
      c.setSourceProgress('a', _progress('a', step: SearchStep.searching));
      c.appendPlayPage(_page(sourceName: 'a'), pageKey: 'a');
      c.appendPlayPage(_page(sourceName: 'b'), pageKey: 'b');
      c.sortPlayPagesByTier();
      c.addSuccessfulSource(_page(sourceName: 'a', directVideoUrl: 'u'));
      c.markSampleIdle();
      c.setSampleError(null);
      expectConsistent(c, 'full surface');
      c.resetForSwitching();
      expectConsistent(c, 'after switch');
      c.clearForDispose();
    });
  });
}
