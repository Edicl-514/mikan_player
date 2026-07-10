import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/download/magnet_helpers.dart';

void main() {
  group('injectMagnetTrackers (dedupe)', () {
    test('appends all default trackers to a bare magnet', () {
      const magnet = 'magnet:?xt=urn:btih:DEADBEEF';
      final result = injectMagnetTrackers(magnet);
      for (final tracker in kInjectedMagnetTrackers) {
        expect(
          result.contains('&tr=$tracker'),
          isTrue,
          reason: 'missing tracker $tracker in $result',
        );
      }
      expect(result.startsWith(magnet), isTrue);
    });

    test('does not duplicate an already-present tracker', () {
      final firstPass = injectMagnetTrackers('magnet:?xt=urn:btih:DEAD');
      final secondPass = injectMagnetTrackers(firstPass);
      expect(secondPass, firstPass);
    });

    test('preserves pre-existing tracker that is not in the default set', () {
      const magnet =
          'magnet:?xt=urn:btih:DEAD&tr=udp://custom.example:1337/announce';
      final result = injectMagnetTrackers(magnet);
      expect(result.contains('&tr=udp://custom.example:1337/announce'), isTrue);
    });

    test('injection is idempotent for already-injected magnet', () {
      const base = 'magnet:?xt=urn:btih:DEAD';
      final injected = injectMagnetTrackers(base);
      expect(injectMagnetTrackers(injected), injected);
    });
  });

  group('extractInfoHashFromMagnet', () {
    test('extracts btmh:1220<sha256> and lowercases', () {
      // 64 hex chars (SHA-256 length).
      const hash =
          'ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789';
      const magnet = 'magnet:?xt=urn:btmh:1220$hash&dn=x';
      expect(
        extractInfoHashFromMagnet(magnet),
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      );
    });

    test('extracts btih:<64 hex>', () {
      const hash =
          'AABBCCDDEEFF00112233445566778899AABBCCDDEEFF00112233445566778899';
      final magnet = 'magnet:?xt=urn:btih:$hash&dn=foo';
      expect(extractInfoHashFromMagnet(magnet), hash.toLowerCase());
    });

    test('extracts btih:<32 base32 chars>', () {
      // 32 base32 chars: A-Z + 2-7.
      const base32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      final magnet = 'magnet:?xt=urn:btih:$base32&dn=foo';
      expect(extractInfoHashFromMagnet(magnet), base32.toLowerCase());
    });

    test('extracts legacy 40-hex btih (without trailing hex chars)', () {
      const hash40 = '0123456789abcdef0123456789abcdef01234567';
      const magnet = 'magnet:?xt=urn:btih:$hash40&dn=foo';
      expect(extractInfoHashFromMagnet(magnet), hash40);
    });

    test('prefers btmh > btih-hex64 > btih-base32 > btih-hex40', () {
      // btmh + btih-hex64 + btih-base32 all present → btmh wins.
      const btmhHash =
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      const hex64Hash =
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      const base32Hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa32';
      // Ensure base32Hash has no characters outside [A-Za-z2-7] (digits 2-7).
      expect(RegExp(r'^[A-Za-z2-7]{32}$').hasMatch(base32Hash), isTrue);
      final magnet =
          'magnet:?xt=urn:btmh:1220$btmhHash&xt=urn:btih:$hex64Hash&xt=urn:btih:$base32Hash';
      expect(extractInfoHashFromMagnet(magnet), btmhHash);
    });

    test('returns null when no recognized hash is present', () {
      const magnet = 'magnet:?xt=urn:btih:zz&dn=foo';
      expect(extractInfoHashFromMagnet(magnet), isNull);
    });
  });

  group('extractInfoHashFromStreamUrl', () {
    test('extracts hex hash from /torrents/<hash>/...', () {
      const hash = 'abcdef0123456789abcdef0123456789abcdef01';
      const url = 'http://localhost:8080/torrents/$hash/stream/0';
      expect(extractInfoHashFromStreamUrl(url), hash);
    });

    test('lowercases the extracted hash', () {
      const upper = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01';
      const url = 'http://localhost:8080/torrents/$upper/stream/0';
      expect(extractInfoHashFromStreamUrl(url), upper.toLowerCase());
    });

    test('returns null for non-matching URLs', () {
      expect(extractInfoHashFromStreamUrl('http://example.com/foo'), isNull);
      expect(extractInfoHashFromStreamUrl(''), isNull);
    });

    test('captures the longest run of hex chars between the slashes', () {
      const url = 'http://h/torrents/0123456789abcdef/extra';
      expect(extractInfoHashFromStreamUrl(url), '0123456789abcdef');
    });
  });
}
