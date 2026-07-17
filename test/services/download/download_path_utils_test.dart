import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/download_path_utils.dart';

void main() {
  group('stableDownloadHash', () {
    test('is deterministic and fixed-width', () {
      expect(stableDownloadHash('https://example.com/video.mp4'), 'a3f67f3e');
      expect(stableDownloadHash('same'), stableDownloadHash('same'));
      expect(stableDownloadHash('same'), hasLength(8));
    });
  });

  group('sanitizeDownloadFileName', () {
    test('replaces reserved characters and supplies a fallback', () {
      expect(
        sanitizeDownloadFileName(r'a\b/c:d*e?f"g<h>i|j'),
        'a_b_c_d_e_f_g_h_i_j',
      );
      expect(sanitizeDownloadFileName('   '), 'download');
    });

    test('caps the filename stem at 80 characters', () {
      expect(sanitizeDownloadFileName('x' * 100), hasLength(80));
    });
  });

  group('guessVideoExtension', () {
    test('keeps the existing extension priority and fallback', () {
      expect(guessVideoExtension('https://e.test/a.MKV?token=1'), '.mkv');
      expect(guessVideoExtension('https://e.test/master.m3u8'), '.ts');
      expect(guessVideoExtension('https://e.test/no-extension'), '.mp4');
    });
  });

  group('isM3u8Url', () {
    test('checks the URL path case-insensitively', () {
      expect(isM3u8Url('https://e.test/live/MASTER.M3U8?token=1'), isTrue);
      expect(isM3u8Url('https://e.test/video.mp4?next=.m3u8'), isFalse);
    });
  });
}
