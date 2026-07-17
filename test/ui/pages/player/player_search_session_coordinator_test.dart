// Phase 1.4 / 1.6 unit tests for search session + autoplay pure helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_autoplay_coordinator.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_coordinator.dart';
import 'package:mikan_player/utils/source_channel_key.dart';

SourceState _src({
  required String name,
  int tier = 1,
  String? captchaConfigJson,
}) =>
    SourceState(
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
    );

String _pageKey(String source, [int? channel]) => SourceChannelKey(
  sourceName: source,
  channelIndex: channel == null ? null : BigInt.from(channel),
).toPageKey();

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
          completedCount: 2,
          enabledCount: 5,
          activeCaptcha: 1,
          pendingCaptcha: 3,
        ),
        '搜索进度: 2/5，验证码 1 运行/3 排队',
      );
    });

    test('finish messages', () {
      expect(
        sampleSearchFinishMessage(
          playPageCount: 0,
          successfulSourceCount: 0,
        ).error,
        '未在任何源中找到该动画',
      );
      expect(
        sampleSearchFinishMessage(
          playPageCount: 2,
          successfulSourceCount: 0,
        ).error,
        '所有源都无法提取视频链接',
      );
      expect(
        sampleSearchFinishMessage(
          playPageCount: 2,
          successfulSourceCount: 3,
        ).status,
        '搜索完成，共找到 3 个可用源',
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
  });
}
