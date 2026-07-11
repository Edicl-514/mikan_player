import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/services/webview_video_extractor.dart';
import 'package:mikan_player/ui/pages/player/webview_worker_state_transitions.dart';

/// Phase 2 B4 tests for the pure worker complete/cancel/late-result helpers.
///
/// Subject:
///   - isVideoResultLateAfterCancel: late-after-cancel tier guard (suppress
///     non-Tier-0 results when a source is already playing)
///   - buildUpdatedPlayPageFromResult: pure construct+merge of the resolved
///     SearchPlayResult from page + VideoExtractResult
///   - shouldClearCaptchaSlotOnIdle: stale captcha task cleanup predicate
///
/// The page keeps the effects (setState / debugPrint / _webviewStats /
/// probe dispatch / pump), the pure helpers capture only the predicates and
/// transforms — these tests pin them down without State.

SearchPlayResult _page({
  String sourceName = 'srcA',
  String playPageUrl = 'http://host/play',
  String videoRegex = 'regexA',
  String? directVideoUrl,
  String? cookies,
  Map<String, String>? headers,
  String? channelName,
  BigInt? channelIndex,
  bool enableNestedUrl = false,
  String? matchNestedUrl,
  String? captchaConfigJson,
}) {
  return SearchPlayResult(
    sourceName: sourceName,
    playPageUrl: playPageUrl,
    videoRegex: videoRegex,
    directVideoUrl: directVideoUrl,
    cookies: cookies,
    headers: headers,
    channelName: channelName,
    channelIndex: channelIndex,
    captchaConfigJson: captchaConfigJson,
    enableNestedUrl: enableNestedUrl,
    matchNestedUrl: matchNestedUrl,
  );
}

VideoExtractResult _result({
  String? videoUrl = 'http://host/video.mp4',
  String? error,
  Map<String, String> headers = const {},
  bool timedOut = false,
}) {
  return VideoExtractResult(
    videoUrl: videoUrl,
    error: error,
    headers: headers,
    timedOut: timedOut,
  );
}

void main() {
  group('isVideoResultLateAfterCancel', () {
    test('no accepted source -> false (normal path always)', () {
      expect(
        isVideoResultLateAfterCancel(acceptedSourcePageKey: null, tier: 999),
        isFalse,
      );
      expect(
        isVideoResultLateAfterCancel(acceptedSourcePageKey: null, tier: 0),
        isFalse,
      );
    });

    test('accepted source + tier 0 -> false (Tier-0 still probes)', () {
      expect(
        isVideoResultLateAfterCancel(
          acceptedSourcePageKey: 'acc-pkey',
          tier: 0,
        ),
        isFalse,
      );
    });

    test('accepted source + tier 1 -> true (non-Tier-0 late path)', () {
      expect(
        isVideoResultLateAfterCancel(
          acceptedSourcePageKey: 'acc-pkey',
          tier: 1,
        ),
        isTrue,
      );
    });

    test(
      'accepted source + unknown tier (999) -> true (default not Tier-0)',
      () {
        expect(
          isVideoResultLateAfterCancel(
            acceptedSourcePageKey: 'acc-pkey',
            tier: 999,
          ),
          isTrue,
        );
      },
    );

    test(
      'accepted source + negative tier -> true (only tier==0 is special)',
      () {
        expect(
          isVideoResultLateAfterCancel(acceptedSourcePageKey: 'acc', tier: -1),
          isTrue,
        );
      },
    );
  });

  group('buildUpdatedPlayPageFromResult', () {
    test('sets directVideoUrl + merges headers (result wins on dup)', () {
      final page = _page(headers: {'Referer': 'page-ref', 'UA': 'page-ua'});
      final result = _result(
        videoUrl: 'http://host/hijack.mp4',
        headers: {'UA': 'new-ua', 'Cookie': 'session=y'},
      );
      final updated = buildUpdatedPlayPageFromResult(
        page: page,
        result: result,
      );
      expect(updated.directVideoUrl, 'http://host/hijack.mp4');
      expect(updated.headers, {
        'Referer': 'page-ref', // page-only header preserved
        'UA': 'new-ua', // duplicate -> result wins
        'Cookie': 'session=y', // result-only added
      });
    });

    test(
      'preserves page identity fields (sourceName, playPageUrl, channelIndex)',
      () {
        final page = _page(
          sourceName: 'srcX',
          playPageUrl: 'http://srcX/play',
          channelName: 'chY',
          channelIndex: BigInt.two,
          enableNestedUrl: true,
          matchNestedUrl: 'nested-re',
        );
        final result = _result(videoUrl: 'http://v/x');
        final updated = buildUpdatedPlayPageFromResult(
          page: page,
          result: result,
        );
        expect(updated.sourceName, 'srcX');
        expect(updated.playPageUrl, 'http://srcX/play');
        expect(updated.channelName, 'chY');
        expect(updated.channelIndex, BigInt.two);
        expect(updated.enableNestedUrl, isTrue);
        expect(updated.matchNestedUrl, 'nested-re');
        expect(updated.cookies, page.cookies);
        expect(updated.videoRegex, page.videoRegex);
      },
    );

    test(
      'page has null headers + result has headers -> headers map = result headers',
      () {
        final page = _page(headers: null);
        final result = _result(headers: {'Referer': 'ref'});
        final updated = buildUpdatedPlayPageFromResult(
          page: page,
          result: result,
        );
        expect(updated.headers, {'Referer': 'ref'});
      },
    );

    test(
      'page has headers + result has empty headers -> page headers preserved',
      () {
        final page = _page(headers: {'X-Page': '1'});
        final result = _result(headers: {});
        final updated = buildUpdatedPlayPageFromResult(
          page: page,
          result: result,
        );
        expect(updated.headers, {'X-Page': '1'});
      },
    );

    test(
      'clears directVideoUrl when result.videoUrl is null (failed extraction)',
      () {
        final page = _page(directVideoUrl: 'http://old');
        final result = _result(videoUrl: null, error: 'failed');
        final updated = buildUpdatedPlayPageFromResult(
          page: page,
          result: result,
        );
        expect(updated.directVideoUrl, isNull);
      },
    );

    test('captchaConfigJson reflects verbatim page behavior (not forwarded)', () {
      // The original inline constructor in `_onWebViewResult` does NOT set
      // captchaConfigJson from `page`, so the field defaults to null on the
      // updated page. The pure helper preserves this verbatim behavior.
      final page = _page(captchaConfigJson: '{ "type":"simple_click" }');
      final result = _result();
      final updated = buildUpdatedPlayPageFromResult(page: page, result: result);
      expect(updated.captchaConfigJson, isNull);
    });
  });

  group('shouldClearCaptchaSlotOnIdle', () {
    test('taskKey null + any containsKey -> false (no cleanup needed)', () {
      expect(
        shouldClearCaptchaSlotOnIdle(
          slotTaskKey: null,
          activeCaptchaTasksContainsKey: false,
        ),
        isFalse,
      );
      expect(
        shouldClearCaptchaSlotOnIdle(
          slotTaskKey: null,
          activeCaptchaTasksContainsKey: true, // impossible but defensive
        ),
        isFalse,
      );
    });

    test('taskKey set + task still active -> false (normal case)', () {
      expect(
        shouldClearCaptchaSlotOnIdle(
          slotTaskKey: 'taskA',
          activeCaptchaTasksContainsKey: true,
        ),
        isFalse,
      );
    });

    test(
      'taskKey set + task no longer active -> true (stale cleanup needed)',
      () {
        // The slot believes it's running 'taskA' but the page has already
        // removed it from _activeCaptchaTasks — clear the slot bookkeeping.
        expect(
          shouldClearCaptchaSlotOnIdle(
            slotTaskKey: 'taskA',
            activeCaptchaTasksContainsKey: false,
          ),
          isTrue,
        );
      },
    );
  });
}
