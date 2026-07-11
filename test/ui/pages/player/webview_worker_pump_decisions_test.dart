import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_pump_decisions.dart';

///sher B3 tests for the pure WebView pump decision helpers.
///
/// Subject:
///   - canStartCaptchaDecision: captcha vs video competition gate
///   - pickBestPending: tier + enqueue-seq stable sort
///   - selectVideoJobForAffinitySlot: source-affinity selection + soft limit + global fallback
///
/// SearchPlayResult is an frb-generated `class` with a `const` constructor;
/// we use a helper to create minimal instances for sorting decisions.

const _emptySourceTiers = <String, int>{};
const _emptyEnqueueSeq = <String, int>{};

SearchPlayResult _page(
  String sourceName, {
  BigInt? channelIndex,
  String? channelName,
}) {
  return SearchPlayResult(
    sourceName: sourceName,
    playPageUrl: 'http://test/$sourceName',
    videoRegex: '',
    channelName: channelName,
    channelIndex: channelIndex,
    enableNestedUrl: false,
  );
}

String _pageKeyOf(SearchPlayResult p) {
  // Mirrors _buildSourceChannelKey for tests: sourceName + ':' + channelIndex.
  // Tests use stable string keys independent of the real SourceChannelKey.
  final ch = p.channelIndex?.toString() ?? 'null';
  return '${p.sourceName}:$ch';
}

void main() {
  group('canStartCaptchaDecision', () {
    test('true when no pending extraction (give slot to captcha)', () {
      expect(
        canStartCaptchaDecision(
          hasPendingExtraction: false,
          hasActiveExtraction: false,
          slotsRemaining: 1,
        ),
        isTrue,
      );
    });

    test(
      'true when extraction active (remaining slots not video-exclusive)',
      () {
        expect(
          canStartCaptchaDecision(
            hasPendingExtraction: true,
            hasActiveExtraction: true,
            slotsRemaining: 1,
          ),
          isTrue,
        );
      },
    );

    test('true when more than one slot vacant (video can still get one)', () {
      expect(
        canStartCaptchaDecision(
          hasPendingExtraction: true,
          hasActiveExtraction: false,
          slotsRemaining: 2,
        ),
        isTrue,
      );
    });

    test('false when video-only + no active + one slot left', () {
      // The gate protects video: last remaining slot must go to video.
      expect(
        canStartCaptchaDecision(
          hasPendingExtraction: true,
          hasActiveExtraction: false,
          slotsRemaining: 1,
        ),
        isFalse,
      );
    });

    test('slotsRemaining=0: gate follows other flags (no slot pump guards anyway)', () {
      // slotsRemaining=0 doesn't force false — the pump loop's outer guard
      // already stops when no slots are available. Here the gate just
      // reflects the flags: with active extraction, true; else false.
      expect(
        canStartCaptchaDecision(
          hasPendingExtraction: true,
          hasActiveExtraction: false,
          slotsRemaining: 0,
        ),
        isFalse,
      );
      expect(
        canStartCaptchaDecision(
          hasPendingExtraction: true,
          hasActiveExtraction: true,
          slotsRemaining: 0,
        ),
        isTrue,
      );
    });
  });

  group('pickBestPending', () {
    test('sorts by tier ascending — tier 0 beats tier 1', () {
      final candidates = [_page('highTier'), _page('lowTier')];
      final sourceTiers = {'lowTier': 0, 'highTier': 1};
      final picked = pickBestPending(
        candidates,
        sourceTiers: sourceTiers,
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      expect(picked.sourceName, 'lowTier');
    });

    test('tier ties -> enqueue-seq ascending wins', () {
      final candidates = [
        _page('srcA', channelIndex: BigInt.zero),
        _page('srcA', channelIndex: BigInt.one),
      ];
      final enqueueSeq = {
        _pageKeyOf(candidates[0]): 10,
        _pageKeyOf(candidates[1]): 3,
      };
      final picked = pickBestPending(
        candidates,
        sourceTiers: _emptySourceTiers,
        enqueueSeqByPageKey: enqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      // Both tier 999 (default); seq 3 < 10 -> channelIndex 1 wins.
      expect(picked.channelIndex, BigInt.one);
    });

    test('unknown source -> tier 999 (lowest priority default)', () {
      final candidates = [_page('mystery')];
      final picked = pickBestPending(
        candidates,
        sourceTiers: _emptySourceTiers,
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      expect(picked.sourceName, 'mystery');
    });

    test(
      'stable for identical source + identical seq (preserves caller order)',
      () {
        final candidates = [
          _page('srcX', channelIndex: BigInt.zero),
          _page('srcX', channelIndex: BigInt.one),
        ];
        final picked = pickBestPending(
          candidates,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq, // all default 0
          pageKeyOf: _pageKeyOf,
        );
        expect(picked.channelIndex, BigInt.zero);
      },
    );
  });

  group('selectVideoJobForAffinitySlot', () {
    test(
      'picks same-source pending when affinity matches and not saturated',
      () {
        final pending = [_page('srcA'), _page('srcB')];
        final picked = selectVideoJobForAffinitySlot(
          affinitySource: 'srcA',
          pending: pending,
          activeSourceWorkers: const {'srcA': 0},
          softLimit: 2,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq,
          pageKeyOf: _pageKeyOf,
        );
        expect(picked!.sourceName, 'srcA');
      },
    );

    test('same-source pending but saturated -> falls back to other source', () {
      // softLimit=1, other sources pending, currentActive=1 -> limited.
      final pending = [_page('srcA'), _page('srcB')];
      final picked = selectVideoJobForAffinitySlot(
        affinitySource: 'srcA',
        pending: pending,
        activeSourceWorkers: const {'srcA': 1},
        softLimit: 1,
        sourceTiers: _emptySourceTiers,
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      expect(picked!.sourceName, 'srcB');
    });

    test(
      'same-source pending + no other sources pending -> can eat all slots',
      () {
        // otherSourcesPending=false -> limited=false even if currentActive > softLimit.
        final pending = [_page('soloSource')];
        final picked = selectVideoJobForAffinitySlot(
          affinitySource: 'soloSource',
          pending: pending,
          activeSourceWorkers: const {'soloSource': 5},
          softLimit: 1,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq,
          pageKeyOf: _pageKeyOf,
        );
        expect(picked!.sourceName, 'soloSource');
      },
    );

    test('null affinity -> global fallback picks best-by-tier', () {
      final pending = [_page('srcLow'), _page('srcHigh')];
      final picked = selectVideoJobForAffinitySlot(
        affinitySource: null,
        pending: pending,
        activeSourceWorkers: const {},
        softLimit: 1,
        sourceTiers: const {'srcLow': 0, 'srcHigh': 1},
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      expect(picked!.sourceName, 'srcLow');
    });

    test('empty affinity (worker has never run a job) -> global fallback', () {
      final pending = [_page('srcA')];
      final picked = selectVideoJobForAffinitySlot(
        affinitySource: '',
        pending: pending,
        activeSourceWorkers: const {},
        softLimit: 1,
        sourceTiers: _emptySourceTiers,
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      expect(picked!.sourceName, 'srcA');
    });

    test('every source saturated -> deadlock guard allows any', () {
      // Two sources, both at softLimit, both have pending — no non-saturated
      // candidate exists; guard kicks in and returns one anyway.
      final pending = [_page('srcA'), _page('srcB')];
      final picked = selectVideoJobForAffinitySlot(
        affinitySource: 'srcA',
        pending: pending,
        activeSourceWorkers: const {'srcA': 2, 'srcB': 2},
        softLimit: 2,
        sourceTiers: const {'srcB': 0, 'srcA': 1},
        enqueueSeqByPageKey: _emptyEnqueueSeq,
        pageKeyOf: _pageKeyOf,
      );
      // Guard allows any; tiebreak by tier picks srcB (tier 0).
      expect(picked!.sourceName, 'srcB');
    });

    test('empty pending -> null', () {
      expect(
        selectVideoJobForAffinitySlot(
          affinitySource: 'srcA',
          pending: const [],
          activeSourceWorkers: const {},
          softLimit: 1,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq,
          pageKeyOf: _pageKeyOf,
        ),
        isNull,
      );
    });

    test(
      'affinity matches a source with only channelB pending -> picks channelB',
      () {
        final pending = [_page('srcA', channelIndex: BigInt.one)];
        final picked = selectVideoJobForAffinitySlot(
          affinitySource: 'srcA',
          pending: pending,
          activeSourceWorkers: const {'srcA': 0},
          softLimit: 2,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq,
          pageKeyOf: _pageKeyOf,
        );
        expect(picked!.channelIndex, BigInt.one);
      },
    );

    test(
      'soft limit preserves slot for other source: 4 slots cap=3, A=3 vs B=0',
      () {
        // softLimit=3, 4 slots, A has 3 active, B has 0 active.
        // A saturated (otherSourcesPending=Y, currentActive=3 >= 3).
        // B available. Should pick B even though A has affinity.
        final pending = [
          _page('srcA', channelIndex: BigInt.zero),
          _page('srcB', channelIndex: BigInt.zero),
        ];
        final picked = selectVideoJobForAffinitySlot(
          affinitySource: 'srcA',
          pending: pending,
          activeSourceWorkers: const {'srcA': 3},
          softLimit: 3,
          sourceTiers: _emptySourceTiers,
          enqueueSeqByPageKey: _emptyEnqueueSeq,
          pageKeyOf: _pageKeyOf,
        );
        expect(picked!.sourceName, 'srcB');
      },
    );
  });
}
