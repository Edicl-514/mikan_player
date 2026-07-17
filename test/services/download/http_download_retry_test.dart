import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/http_download_retry.dart';

void main() {
  group('isTransientHttpDownloadError', () {
    test('treats transport / timeout errors as transient', () {
      expect(
        isTransientHttpDownloadError(
          Exception('SocketException: Connection reset'),
        ),
        isTrue,
      );
      expect(
        isTransientHttpDownloadError(
          Exception('ClientException: Connection closed before full header'),
        ),
        isTrue,
      );
      expect(
        isTransientHttpDownloadError(
          Exception('HandshakeException: Connection timed out'),
        ),
        isTrue,
      );
      expect(
        isTransientHttpDownloadError(
          Exception('Failed host lookup: cdn.example'),
        ),
        isTrue,
      );
    });

    test('retries only selected HTTP status codes', () {
      expect(isTransientHttpDownloadError(Exception('HTTP 408')), isTrue);
      expect(isTransientHttpDownloadError(Exception('HTTP 429')), isTrue);
      expect(isTransientHttpDownloadError(Exception('HTTP 500')), isTrue);
      expect(isTransientHttpDownloadError(Exception('HTTP 502')), isTrue);
      expect(isTransientHttpDownloadError(Exception('HTTP 403')), isFalse);
      expect(isTransientHttpDownloadError(Exception('HTTP 404')), isFalse);
      expect(isTransientHttpDownloadError(Exception('HTTP 451')), isFalse);
    });

    test('does not retry permanent application failures', () {
      expect(isTransientHttpDownloadError(Exception('暂不支持下载加密HLS流')), isFalse);
      expect(isTransientHttpDownloadError(Exception('未找到可下载的HLS分片')), isFalse);
      expect(isTransientHttpDownloadError(Exception('m3u8层级过深，无法解析')), isFalse);
    });
  });

  group('httpDownloadAutoRetryDelay', () {
    test('uses the configured backoff table and clamps the tail', () {
      expect(httpDownloadAutoRetryDelay(0), const Duration(seconds: 2));
      expect(httpDownloadAutoRetryDelay(1), const Duration(seconds: 5));
      expect(httpDownloadAutoRetryDelay(2), const Duration(seconds: 10));
      expect(httpDownloadAutoRetryDelay(99), const Duration(seconds: 10));
    });
  });
}
