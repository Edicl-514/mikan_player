// Characterization tests for pure sample-search finish policy.
//
// Grounded in PlayerPage `_maybeFinishSampleSearch` / `_isSourceSearchFinished`
// and docs/player_search_session_design.md. No WebView, gate, or PlayerPage.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/sample_search_finish_policy.dart';

SourceSearchProgress _progress(String name, SearchStep step) =>
    SourceSearchProgress(
      sourceName: name,
      step: step,
      error: null,
      playPageUrl: null,
      videoRegex: null,
      directVideoUrl: null,
      cookies: null,
      headers: null,
      enableNestedUrl: false,
    );

void main() {
  group('isSearchStepTerminal', () {
    test('success and failed are terminal', () {
      expect(isSearchStepTerminal(SearchStep.success), isTrue);
      expect(isSearchStepTerminal(SearchStep.failed), isTrue);
    });

    test('pending and intermediate steps are not terminal', () {
      expect(isSearchStepTerminal(SearchStep.pending), isFalse);
      expect(isSearchStepTerminal(SearchStep.searching), isFalse);
      expect(isSearchStepTerminal(SearchStep.fetchingDetail), isFalse);
      expect(isSearchStepTerminal(SearchStep.fetchingEpisodes), isFalse);
      expect(isSearchStepTerminal(SearchStep.extractingVideo), isFalse);
    });
  });

  group('allEnabledSourcesTerminal', () {
    test('empty enabled list is not finished', () {
      expect(
        allEnabledSourcesTerminal(
          enabledSourceNames: const [],
          sourceProgressMap: const {},
        ),
        isFalse,
      );
    });

    test('missing progress blocks finish', () {
      expect(
        allEnabledSourcesTerminal(
          enabledSourceNames: const ['a'],
          sourceProgressMap: const {},
        ),
        isFalse,
      );
    });

    test('non-terminal step blocks finish', () {
      expect(
        allEnabledSourcesTerminal(
          enabledSourceNames: const ['a', 'b'],
          sourceProgressMap: {
            'a': _progress('a', SearchStep.success),
            'b': _progress('b', SearchStep.pending),
          },
        ),
        isFalse,
      );
    });

    test('all terminal allows finish', () {
      expect(
        allEnabledSourcesTerminal(
          enabledSourceNames: const ['a', 'b'],
          sourceProgressMap: {
            'a': _progress('a', SearchStep.success),
            'b': _progress('b', SearchStep.failed),
          },
        ),
        isTrue,
      );
    });
  });

  group('mayMarkSampleSearchIdle', () {
    bool idle({
      bool isMounted = true,
      bool isLoadingSample = true,
      bool searchSubscriptionsNonEmpty = false,
      bool pendingOrActiveCaptcha = false,
      bool activeExtraction = false,
      bool resolvingChannelKeysNonEmpty = false,
      bool probingSourceKeysNonEmpty = false,
      bool hasPendingExtraction = false,
      bool allSourcesTerminal = true,
    }) => mayMarkSampleSearchIdle(
      isMounted: isMounted,
      isLoadingSample: isLoadingSample,
      searchSubscriptionsNonEmpty: searchSubscriptionsNonEmpty,
      pendingOrActiveCaptcha: pendingOrActiveCaptcha,
      activeExtraction: activeExtraction,
      resolvingChannelKeysNonEmpty: resolvingChannelKeysNonEmpty,
      probingSourceKeysNonEmpty: probingSourceKeysNonEmpty,
      hasPendingExtraction: hasPendingExtraction,
      allSourcesTerminal: allSourcesTerminal,
    );

    test('all clear + terminal sources may finish', () {
      expect(idle(), isTrue);
    });

    test('not mounted or not loading cannot finish', () {
      expect(idle(isMounted: false), isFalse);
      expect(idle(isLoadingSample: false), isFalse);
    });

    test('active rust subscriptions block finish', () {
      expect(idle(searchSubscriptionsNonEmpty: true), isFalse);
    });

    test('pending or active captcha blocks finish', () {
      expect(idle(pendingOrActiveCaptcha: true), isFalse);
    });

    test('active extraction or channel resolve blocks finish', () {
      expect(idle(activeExtraction: true), isFalse);
      expect(idle(resolvingChannelKeysNonEmpty: true), isFalse);
    });

    test('probing sources block finish (zombie false-finish guard)', () {
      expect(idle(probingSourceKeysNonEmpty: true), isFalse);
    });

    test('pending extraction pages block finish', () {
      expect(idle(hasPendingExtraction: true), isFalse);
    });

    test('non-terminal sources block finish', () {
      expect(idle(allSourcesTerminal: false), isFalse);
    });
  });
}
