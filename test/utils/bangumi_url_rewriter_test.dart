// DT-1: pure-Dart composition tests for `utils/bangumi_url_rewriter.dart`.
//
// Covers:
//   * `rewrite` is a no-op when the cached enabled flag is null/false.
//   * `rewrite` flips every canonical host to its mirror when enabled,
//     including alias collapse (`bgm.tv` → `bangumi.tv` is handled by
//     `canonicalize`, not `rewrite` — see below).
//   * `rewrite` is idempotent on mirror URLs (re-applying it must not
//     flip a mirror to a different mirror).
//   * `rewrite` upgrades protocol-relative URLs to https.
//   * `canonicalize` is independent of the cached flag and always
//     produces the canonical real host; both `bangumi.lol` and
//     `bgm.tv` / `chii.in` aliases collapse to `bangumi.tv`.
//   * `setEnabled` / `enabled` expose the cached toggle state without
//     invoking the Rust-backed `hostFor` API.
//
// The rewrite class is a global-singleton, so each test must reset
// the cache via `setEnabled(...)` to keep the suite deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

void main() {
  // The cache is a static field. Reset to null (the "never been
  // toggled" state) between tests so a stray `setEnabled(true)` in
  // one assertion cannot leak into the next.
  tearDown(() {
    BangumiUrlRewriter.setEnabled(false);
  });

  group('rewrite() with reverse-proxy disabled (cache = false)', () {
    test('passes through bangumi.tv / bgm.tv URLs unchanged', () {
      BangumiUrlRewriter.setEnabled(false);
      expect(
        BangumiUrlRewriter.rewrite('https://bangumi.tv/subject/1'),
        'https://bangumi.tv/subject/1',
      );
      expect(
        BangumiUrlRewriter.rewrite('https://bgm.tv/subject/1'),
        'https://bgm.tv/subject/1',
      );
      expect(
        BangumiUrlRewriter.rewrite('https://api.bgm.tv/v0/subjects/1'),
        'https://api.bgm.tv/v0/subjects/1',
      );
    });

    test('empty input is empty output', () {
      BangumiUrlRewriter.setEnabled(false);
      expect(BangumiUrlRewriter.rewrite(''), '');
    });
  });

  group('rewrite() with reverse-proxy enabled (cache = true)', () {
    setUp(() {
      BangumiUrlRewriter.setEnabled(true);
    });

    test('bangumi.tv / bgm.tv / chii.in all collapse to bangumi.lol', () {
      const cases = <String, String>{
        'https://bangumi.tv/subject/1': 'https://bangumi.lol/subject/1',
        'https://bgm.tv/subject/1': 'https://bangumi.lol/subject/1',
        'https://chii.in/subject/1': 'https://bangumi.lol/subject/1',
      };
      cases.forEach((input, expected) {
        expect(
          BangumiUrlRewriter.rewrite(input),
          expected,
          reason: 'failed for $input',
        );
      });
    });

    test('api.bgm.tv / next/lain/fast/doujin all map to .bangumi.lol', () {
      const cases = <String, String>{
        'https://api.bgm.tv/v0/subjects/1':
            'https://api.bangumi.lol/v0/subjects/1',
        'https://next.bgm.tv/subject/1': 'https://next.bangumi.lol/subject/1',
        'https://lain.bgm.tv/img/1': 'https://lain.bangumi.lol/img/1',
        'https://fast.bgm.tv/img/1': 'https://fast.bangumi.lol/img/1',
        'https://doujin.bgm.tv/img/1': 'https://doujin.bangumi.lol/img/1',
      };
      cases.forEach((input, expected) {
        expect(
          BangumiUrlRewriter.rewrite(input),
          expected,
          reason: 'failed for $input',
        );
      });
    });

    test('rewrites http:// (not just https://) hosts', () {
      // The production check covers both `startsWith('https://')` and
      // `startsWith('http://')` — make sure plain http is also
      // rewritten so an old share link still hits the mirror.
      expect(
        BangumiUrlRewriter.rewrite('http://bangumi.tv/subject/1'),
        'http://bangumi.lol/subject/1',
      );
    });

    test('upgrades protocol-relative URLs to https before rewriting', () {
      // `//lain.bgm.tv/img/1` must be promoted to `https://...` and
      // then mapped to the mirror.
      expect(
        BangumiUrlRewriter.rewrite('//lain.bgm.tv/img/1'),
        'https://lain.bangumi.lol/img/1',
      );
    });

    test('is idempotent on already-mirrored URLs', () {
      // Running rewrite twice must produce the same string. If the
      // implementation accidentally re-rewrote `bangumi.lol` →
      // `bangumi.lol` is a no-op today, but `api.bangumi.lol` does
      // not contain any of the real-host keys, so the inner loop
      // should skip it.
      final once = BangumiUrlRewriter.rewrite('https://bangumi.tv/subject/1');
      final twice = BangumiUrlRewriter.rewrite(once);
      expect(twice, once);
      expect(twice, 'https://bangumi.lol/subject/1');
    });

    test('preserves unknown hosts', () {
      // Hosts outside the known bangumi.tv family must be left alone
      // — otherwise image proxies for other services would silently
      // change.
      expect(
        BangumiUrlRewriter.rewrite('https://example.com/img/1'),
        'https://example.com/img/1',
      );
    });

    test('does not rewrite a known host used as an unrelated host prefix', () {
      final raw = 'https://bangumi.tv.example.com/img/1';
      expect(BangumiUrlRewriter.rewrite(raw), raw);
    });

    test(
      'only rewrites the host in `://` / `//` host position (not substrings)',
      () {
        // The host-boundary check in `rewrite` requires the canonical
        // host to appear in a real origin position (`://host` or
        // `//host/`). A host embedded in a query string — even when
        // not URL-encoded — is intentionally left alone, because
        // flipping it would silently change redirect targets,
        // analytics parameters, and similar metadata. This is a
        // documented design choice, not a bug.
        final raw =
            'https://cdn.example.com/track?target=https://bangumi.tv/subject/1';
        expect(BangumiUrlRewriter.rewrite(raw), raw);
      },
    );

    test('URL-encoded hosts in query strings are not rewritten', () {
      // Same intent, but with the host percent-encoded inside a
      // redirect parameter. The rewrite must not touch encoded
      // values; the encoded occurrence stays verbatim.
      final raw =
          'https://other.example.com/?next=https%3A%2F%2Fbangumi.tv%2Fsubject%2F1';
      expect(BangumiUrlRewriter.rewrite(raw), raw);
    });
  });

  group('canonicalize()', () {
    test('is independent of the cached flag (always uses real host)', () {
      // The function explicitly does NOT consult the cache; the
      // canonical form must be produced whether or not the user
      // currently has the reverse proxy enabled.
      for (final flag in [false, true]) {
        BangumiUrlRewriter.setEnabled(flag);
        expect(
          BangumiUrlRewriter.canonicalize('https://bangumi.lol/subject/1'),
          'https://bangumi.tv/subject/1',
          reason: 'failed with cache=$flag',
        );
        expect(
          BangumiUrlRewriter.canonicalize('https://api.bangumi.lol/v0/...'),
          'https://api.bgm.tv/v0/...',
          reason: 'failed with cache=$flag',
        );
      }
    });

    test('bgm.tv and chii.in aliases both collapse to bangumi.tv', () {
      expect(
        BangumiUrlRewriter.canonicalize('https://bgm.tv/subject/1'),
        'https://bangumi.tv/subject/1',
      );
      expect(
        BangumiUrlRewriter.canonicalize('https://chii.in/subject/1'),
        'https://bangumi.tv/subject/1',
      );
    });

    test('upgrades protocol-relative URLs to https before normalizing', () {
      expect(
        BangumiUrlRewriter.canonicalize('//bangumi.lol/subject/1'),
        'https://bangumi.tv/subject/1',
      );
    });

    test('empty input is empty output', () {
      expect(BangumiUrlRewriter.canonicalize(''), '');
    });

    test('preserves non-bangumi URLs unchanged', () {
      expect(
        BangumiUrlRewriter.canonicalize('https://example.com/x'),
        'https://example.com/x',
      );
    });

    test('does not canonicalize a known host used as a host prefix', () {
      final raw = 'https://bangumi.lol.example.com/img/1';
      expect(BangumiUrlRewriter.canonicalize(raw), raw);
    });

    test('does not canonicalize a URL nested in a query parameter', () {
      final raw =
          'https://example.com/redirect?next=https://bangumi.lol/subject/1';
      expect(BangumiUrlRewriter.canonicalize(raw), raw);
    });

    test('is idempotent (canonical → canonical)', () {
      // A canonical URL, when canonicalized again, must stay canonical.
      final first = BangumiUrlRewriter.canonicalize('https://bangumi.lol/x');
      final second = BangumiUrlRewriter.canonicalize(first);
      expect(second, first);
    });

    test('api.bangumi.lol maps to api.bgm.tv (not api.bangumi.tv)', () {
      // Regression for `canonicalize` host-substring collision: the
      // bare `bangumi.lol` key would otherwise match inside
      // `api.bangumi.lol` and rewrite it to `api.bangumi.tv`, a
      // host that does not exist. The cache key would then differ
      // from the URL `https://api.bgm.tv/...` and toggle-proxy
      // cycles would write to a different file. The fix anchors
      // the rewrite on a `://` host boundary.
      expect(
        BangumiUrlRewriter.canonicalize(
          'https://api.bangumi.lol/v0/subjects/1',
        ),
        'https://api.bgm.tv/v0/subjects/1',
      );
    });

    test('mirror and real forms of the same API host share a cache key', () {
      // End-to-end property for the image cache: toggling
      // reverse-proxy must not invalidate the on-disk cache.
      final mirrorKey = BangumiUrlRewriter.canonicalize(
        'https://api.bangumi.lol/v0/subjects/1/cover.jpg',
      );
      final realKey = BangumiUrlRewriter.canonicalize(
        'https://api.bgm.tv/v0/subjects/1/cover.jpg',
      );
      expect(mirrorKey, realKey);
    });

    test('mirror and real forms of the lain host share a cache key', () {
      // Same property for lain.bgm.tv / lain.bangumi.lol — these
      // host user-uploaded images and toggling the proxy must not
      // orphan the on-disk cache.
      final mirrorKey = BangumiUrlRewriter.canonicalize(
        'https://lain.bangumi.lol/img/1',
      );
      final realKey = BangumiUrlRewriter.canonicalize(
        'https://lain.bgm.tv/img/1',
      );
      expect(mirrorKey, realKey);
    });
  });

  group('setEnabled / enabled cache', () {
    test('round-trips true and false values', () {
      BangumiUrlRewriter.setEnabled(true);
      expect(BangumiUrlRewriter.enabled, isTrue);
      BangumiUrlRewriter.setEnabled(false);
      expect(BangumiUrlRewriter.enabled, isFalse);
    });
  });
}
