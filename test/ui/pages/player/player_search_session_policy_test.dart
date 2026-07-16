// Characterization tests for the pure PlayerSearchSession policy helpers.
//
// Grounded in docs/player_search_session_design.md and the plan matrix in
// docs/ai_refactor_test_plan.md. No WebView, network, or PlayerPage.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_state_transitions.dart';

void main() {
  group('matrix: start then immediate replacement', () {
    test('old progress/captcha/extraction load tokens are rejected', () {
      const current = 2;
      const stale = 1;

      expect(
        isSearchGenerationCurrent(
          resultLoadToken: stale,
          currentLoadToken: current,
          isDisposed: false,
        ),
        isFalse,
      );
      expect(
        mayApplyCaptchaResult(
          resultLoadToken: stale,
          currentLoadToken: current,
          isDisposed: false,
          activeTaskPresent: true,
          activeTaskKey: 'search:src',
          resultTaskKey: 'search:src',
        ),
        isFalse,
      );
      expect(
        mayProbeVideoExtractionResult(
          resultLoadToken: stale,
          currentLoadToken: current,
          isDisposed: false,
          isLateNonTier0AfterAccept: false,
        ),
        isFalse,
      );
    });

    test('current generation remains accepted', () {
      expect(
        isSearchGenerationCurrent(
          resultLoadToken: 3,
          currentLoadToken: 3,
          isDisposed: false,
        ),
        isTrue,
      );
      expect(
        mayStartSearchScopedJob(
          jobLoadToken: 3,
          currentLoadToken: 3,
          isDisposed: false,
        ),
        isTrue,
      );
    });
  });

  group('matrix: cancel then restart same source', () {
    test('new generation cannot be claimed by old job token', () {
      // Restart bumps token 5 → 6; old captcha task still carries 5.
      expect(
        mayApplyCaptchaResult(
          resultLoadToken: 5,
          currentLoadToken: 6,
          isDisposed: false,
          activeTaskPresent: false, // cancelled bookkeeping cleared
          activeTaskKey: null,
          resultTaskKey: 'search:src',
        ),
        isFalse,
      );
      expect(
        mayStartSearchScopedJob(
          jobLoadToken: 6,
          currentLoadToken: 6,
          isDisposed: false,
        ),
        isTrue,
      );
    });

    test('same generation but missing active task is rejected', () {
      expect(
        mayApplyCaptchaResult(
          resultLoadToken: 1,
          currentLoadToken: 1,
          isDisposed: false,
          activeTaskPresent: false,
          activeTaskKey: null,
          resultTaskKey: 'search:src',
        ),
        isFalse,
      );
    });

    test('task key mismatch is rejected even when generation matches', () {
      expect(
        mayApplyCaptchaResult(
          resultLoadToken: 1,
          currentLoadToken: 1,
          isDisposed: false,
          activeTaskPresent: true,
          activeTaskKey: 'search:srcA',
          resultTaskKey: 'search:srcB',
        ),
        isFalse,
      );
    });
  });

  group('matrix: captcha refresh', () {
    test('briefly missing DOM without success selector is not success', () {
      expect(
        shouldTreatMissingCaptchaAfterRefreshAsSuccess(
          captchaStillDetectable: false,
          successSelectorPresent: false,
        ),
        isFalse,
      );
    });

    test('missing captcha DOM with success selector is success', () {
      expect(
        shouldTreatMissingCaptchaAfterRefreshAsSuccess(
          captchaStillDetectable: false,
          successSelectorPresent: true,
        ),
        isTrue,
      );
    });

    test('still-detectable captcha is never treated as success here', () {
      expect(
        shouldTreatMissingCaptchaAfterRefreshAsSuccess(
          captchaStillDetectable: true,
          successSelectorPresent: true,
        ),
        isFalse,
      );
    });
  });

  group('matrix: last worker slot / late video', () {
    test('late non-tier0 after accept cannot probe', () {
      expect(
        mayProbeVideoExtractionResult(
          resultLoadToken: 1,
          currentLoadToken: 1,
          isDisposed: false,
          isLateNonTier0AfterAccept: true,
        ),
        isFalse,
      );
      // Cross-check existing pure predicate used by the page.
      expect(
        isVideoResultLateAfterCancel(
          acceptedSourcePageKey: 'tier0-key',
          tier: 2,
        ),
        isTrue,
      );
      expect(
        isVideoResultLateAfterCancel(
          acceptedSourcePageKey: 'tier0-key',
          tier: 0,
        ),
        isFalse,
      );
    });

    test('current generation tier0 path may probe', () {
      expect(
        mayProbeVideoExtractionResult(
          resultLoadToken: 1,
          currentLoadToken: 1,
          isDisposed: false,
          isLateNonTier0AfterAccept: false,
        ),
        isTrue,
      );
    });
  });

  group('matrix: dispose during search', () {
    test('dispose rejects generation, captcha apply, probe, and new jobs', () {
      expect(
        isSearchGenerationCurrent(
          resultLoadToken: 4,
          currentLoadToken: 4,
          isDisposed: true,
        ),
        isFalse,
      );
      expect(
        mayApplyCaptchaResult(
          resultLoadToken: 4,
          currentLoadToken: 4,
          isDisposed: true,
          activeTaskPresent: true,
          activeTaskKey: 'search:src',
          resultTaskKey: 'search:src',
        ),
        isFalse,
      );
      expect(
        mayProbeVideoExtractionResult(
          resultLoadToken: 4,
          currentLoadToken: 4,
          isDisposed: true,
          isLateNonTier0AfterAccept: false,
        ),
        isFalse,
      );
      expect(
        mayStartSearchScopedJob(
          jobLoadToken: 4,
          currentLoadToken: 4,
          isDisposed: true,
        ),
        isFalse,
      );
    });

    test('stale captcha idle on reassigned slot is ignored', () {
      expect(mayProcessCaptchaWorkerIdle(slotHasActiveKind: true), isFalse);
      expect(mayProcessCaptchaWorkerIdle(slotHasActiveKind: false), isTrue);
    });

    test(
      'idle clear still uses shouldClearCaptchaSlotOnIdle for bookkeeping',
      () {
        expect(
          shouldClearCaptchaSlotOnIdle(
            slotTaskKey: 'search:src',
            activeCaptchaTasksContainsKey: false,
          ),
          isTrue,
        );
        expect(
          shouldClearCaptchaSlotOnIdle(
            slotTaskKey: 'search:src',
            activeCaptchaTasksContainsKey: true,
          ),
          isFalse,
        );
      },
    );
  });
}
