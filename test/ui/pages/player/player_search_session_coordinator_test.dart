// Phase 1.4 / 1.6 unit tests for search session + autoplay pure helpers.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_autoplay_coordinator.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_coordinator.dart';
import 'package:mikan_player/utils/source_channel_key.dart';

SourceState _src({
  required String name,
  int tier = 1,
  String? captchaConfigJson,
}) => SourceState(
  name: name,
  description: '',
  iconUrl: '',
  tier: tier,
  defaultSubtitleLanguage: '',
  defaultResolution: '',
  searchUrl: 'https://example.com',
  searchConfigJson: '{}',
  captchaConfigJson: captchaConfigJson,
  enabled: true,
  isManual: true,
);

String _pageKey(String source, [int? channel]) => SourceChannelKey(
  sourceName: source,
  channelIndex: channel == null ? null : BigInt.from(channel),
).toPageKey();

SourceSearchProgress _progress(String sourceName, SearchStep step) =>
    SourceSearchProgress(
      sourceName: sourceName,
      step: step,
      enableNestedUrl: false,
    );

void main() {
  group('partitionEnabledSources', () {
    test('splits and sorts captcha by tier', () {
      final cohorts = partitionEnabledSources([
        _src(name: 'c-high', tier: 2, captchaConfigJson: '{"enable":true}'),
        _src(name: 'plain', tier: 0),
        _src(name: 'c-low', tier: 0, captchaConfigJson: '{"enable":true}'),
        _src(name: 'bad-captcha', captchaConfigJson: 'nope'),
      ]);
      expect(cohorts.captchaSources.map((s) => s.name).toList(), [
        'c-low',
        'c-high',
      ]);
      expect(cohorts.nonCaptchaSources.map((s) => s.name).toList(), [
        'plain',
        'bad-captcha',
      ]);
    });
  });

  group('sample search status / finish messages', () {
    test('progress label', () {
      expect(
        sampleSearchProgressLabel(
          formatter: (completed, enabled, active, pending) =>
              'progress=$completed/$enabled active=$active pending=$pending',
          completedCount: 2,
          enabledCount: 5,
          activeCaptcha: 1,
          pendingCaptcha: 3,
        ),
        'progress=2/5 active=1 pending=3',
      );
    });

    test('finish messages', () {
      expect(
        sampleSearchFinishMessage(
          notFoundMessage: 'not found',
          allFailedMessage: 'all failed',
          doneFormatter: (count) => 'done=$count',
          playPageCount: 0,
          successfulSourceCount: 0,
        ).error,
        'not found',
      );
      expect(
        sampleSearchFinishMessage(
          notFoundMessage: 'not found',
          allFailedMessage: 'all failed',
          doneFormatter: (count) => 'done=$count',
          playPageCount: 2,
          successfulSourceCount: 0,
        ).error,
        'all failed',
      );
      expect(
        sampleSearchFinishMessage(
          notFoundMessage: 'not found',
          allFailedMessage: 'all failed',
          doneFormatter: (count) => 'done=$count',
          playPageCount: 2,
          successfulSourceCount: 3,
        ).status,
        'done=3',
      );
    });
  });

  group('autoplay cancel-after-accept policy', () {
    test('protects accepted source name and tier 0', () {
      final accepted = _pageKey('good', 0);
      final tiers = {'good': 0, 'ok': 0, 'bad': 1, 'unknown': 2};
      expect(
        isCancellableSourceAfterAccept(
          sourceName: 'good',
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        isFalse,
      );
      expect(
        isCancellableSourceAfterAccept(
          sourceName: 'ok',
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        isFalse,
      );
      expect(
        isCancellableSourceAfterAccept(
          sourceName: 'bad',
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        isTrue,
      );
      // Missing tier defaults to 999 → cancellable
      expect(
        isCancellableSourceAfterAccept(
          sourceName: 'missing',
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        isTrue,
      );
      expect(
        isCancellableWebViewPageKeyAfterAccept(
          pageKey: accepted,
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        isFalse,
      );
      expect(
        videoPageKeysToCancelAfterAccept(
          activeVideoPageKeys: [
            accepted,
            _pageKey('bad', 1),
            _pageKey('ok', 0),
            _pageKey('unknown', 3),
          ],
          acceptedPageKey: accepted,
          sourceTiers: tiers,
        ),
        [_pageKey('bad', 1), _pageKey('unknown', 3)],
      );
    });
  });

  group('PlayerSearchSessionCoordinator', () {
    test('cancelAll empties tracking', () async {
      final c = PlayerSearchSessionCoordinator();
      expect(c.hasSubscriptions, isFalse);
      await c.cancelAll();
      expect(c.subscriptionCount, 0);
    });

    test(
      'forwards current target progress and removes subscription on done',
      () async {
        final c = PlayerSearchSessionCoordinator();
        final stream = StreamController<SourceSearchProgress>(sync: true);
        final received = <SourceSearchProgress>[];
        var doneCount = 0;

        c.launchStream(
          stream: stream.stream,
          targetSources: const {'wanted'},
          loadToken: 7,
          currentLoadToken: () => 7,
          isDisposed: () => false,
          onProgress: received.add,
          onStreamError: (_, _) => fail('unexpected stream error'),
          onDoneOrMaybeFinish: () => doneCount++,
          streamTag: 'test',
        );

        expect(c.subscriptionCount, 1);
        expect(() => c.subscriptions.clear(), throwsUnsupportedError);
        stream.add(_progress('ignored', SearchStep.searching));
        stream.add(_progress('wanted', SearchStep.success));
        await stream.close();

        expect(received.map((progress) => progress.sourceName), ['wanted']);
        expect(doneCount, 1);
        expect(c.subscriptionCount, 0);
      },
    );

    test('drops stale generation progress and completion callbacks', () async {
      final c = PlayerSearchSessionCoordinator();
      final stream = StreamController<SourceSearchProgress>(sync: true);
      var currentToken = 1;
      final received = <SourceSearchProgress>[];
      var doneCount = 0;

      c.launchStream(
        stream: stream.stream,
        targetSources: const {'source'},
        loadToken: 1,
        currentLoadToken: () => currentToken,
        isDisposed: () => false,
        onProgress: received.add,
        onStreamError: (_, _) => fail('unexpected stream error'),
        onDoneOrMaybeFinish: () => doneCount++,
        streamTag: 'stale',
      );

      currentToken = 2;
      stream.add(_progress('source', SearchStep.success));
      await stream.close();

      expect(received, isEmpty);
      expect(doneCount, 0);
      expect(c.subscriptionCount, 0);
    });

    test(
      'reports stream errors and cancelAll cancels active subscriptions',
      () async {
        final errorCoordinator = PlayerSearchSessionCoordinator();
        final errorStream = StreamController<SourceSearchProgress>(sync: true);
        Object? reportedError;
        Iterable<String>? reportedSources;

        errorCoordinator.launchStream(
          stream: errorStream.stream,
          targetSources: const {'a', 'b'},
          loadToken: 3,
          currentLoadToken: () => 3,
          isDisposed: () => false,
          onProgress: (_) {},
          onStreamError: (error, sources) {
            reportedError = error;
            reportedSources = sources;
          },
          onDoneOrMaybeFinish: () =>
              fail('error stream must not complete normally'),
          streamTag: 'error',
        );
        errorStream.addError(StateError('boom'));
        await errorStream.close();

        expect(reportedError, isA<StateError>());
        expect(reportedSources, unorderedEquals(['a', 'b']));
        expect(errorCoordinator.subscriptionCount, 0);

        final cancelCoordinator = PlayerSearchSessionCoordinator();
        final cancelStream = StreamController<SourceSearchProgress>();
        var wasCancelled = false;
        cancelStream.onCancel = () => wasCancelled = true;
        cancelCoordinator.launchStream(
          stream: cancelStream.stream,
          targetSources: const {'source'},
          loadToken: 1,
          currentLoadToken: () => 1,
          isDisposed: () => false,
          onProgress: (_) {},
          onStreamError: (_, _) {},
          onDoneOrMaybeFinish: () {},
          streamTag: 'cancel',
        );

        await cancelCoordinator.cancelAll();
        expect(wasCancelled, isTrue);
        expect(cancelCoordinator.subscriptionCount, 0);
        await cancelStream.close();
      },
    );
  });
}
