import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/http_header_strategies.dart';

void main() {
  group('buildHttpDownloadHeaderStrategies', () {
    test(
      'orders base → no-referer → no-referer/origin → UA-only and dedupes',
      () {
        final strategies = buildHttpDownloadHeaderStrategies({
          'User-Agent': 'ua-1',
          'Referer': 'https://play.example/watch',
          'Origin': 'https://play.example',
          'X-Keep': 'yes',
        });

        expect(strategies.map((s) => s.id).toList(), [
          HttpDownloadHeaderStrategyId.base,
          HttpDownloadHeaderStrategyId.withoutReferer,
          HttpDownloadHeaderStrategyId.withoutRefererAndOrigin,
          HttpDownloadHeaderStrategyId.userAgentOnly,
        ]);
        expect(strategies[0].headers, {
          'User-Agent': 'ua-1',
          'Referer': 'https://play.example/watch',
          'Origin': 'https://play.example',
          'X-Keep': 'yes',
        });
        expect(strategies[1].headers, {
          'User-Agent': 'ua-1',
          'Origin': 'https://play.example',
          'X-Keep': 'yes',
        });
        expect(strategies[2].headers, {'User-Agent': 'ua-1', 'X-Keep': 'yes'});
        expect(strategies[3].headers, {'User-Agent': 'ua-1'});
      },
    );

    test('collapses identical strategies when base already has no referer', () {
      final strategies = buildHttpDownloadHeaderStrategies({
        'User-Agent': 'ua-1',
        'X-Keep': 'yes',
      });
      // base == withoutReferer == withoutRefererAndOrigin after dedupe; only
      // UA-only differs if X-Keep is present, so expect base + UA-only.
      expect(strategies.map((s) => s.id).toList(), [
        HttpDownloadHeaderStrategyId.base,
        HttpDownloadHeaderStrategyId.userAgentOnly,
      ]);
    });

    test('null base yields empty base plus default UA-only', () {
      final strategies = buildHttpDownloadHeaderStrategies(null);
      // base is a true empty request (null map); UA-only is the only rewrite.
      expect(strategies.map((s) => s.id).toList(), [
        HttpDownloadHeaderStrategyId.base,
        HttpDownloadHeaderStrategyId.userAgentOnly,
      ]);
      expect(strategies[0].headers, isNull);
      expect(
        strategies[1].headers?['User-Agent'],
        kDefaultHttpDownloadUserAgent,
      );
    });
  });

  group('isRetryableHttpHeaderStatusError', () {
    test('matches 401/403/407/451 only', () {
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 403')), isTrue);
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 401')), isTrue);
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 407')), isTrue);
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 451')), isTrue);
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 404')), isFalse);
      expect(isRetryableHttpHeaderStatusError(Exception('HTTP 500')), isFalse);
      expect(
        isRetryableHttpHeaderStatusError(Exception('SocketException')),
        isFalse,
      );
    });
  });
}
