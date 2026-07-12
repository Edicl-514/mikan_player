// Phase 2 / Package E2 focused widget tests for the extracted
// `PlayerComments` widget.
//
// No network, no WebView, no media — the test instances below use empty
// `avatar` to avoid the avatar `CachedNetworkImage` network decode path.
// The Bangumi-smile `<img>` path does instantiate `CachedNetworkImage`,
// but only its first-frame tree is asserted: `_maybeStartLoading`'s
// post-frame callback awaits `ImageCacheService.initialize()`, which fails
// with `MissingPluginException` on a Flutter test host; the error is
// swallowed by the widget's own try/catch and never reaches the test Zone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/widgets/bangumi_mask_text.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

BangumiEpisodeComment _comment({
  int id = 1,
  String userName = '',
  String userId = '',
  String avatar = '',
  String time = '',
  String contentHtml = '',
  List<BangumiEpisodeComment> replies = const [],
}) => BangumiEpisodeComment(
  id: id,
  userName: userName,
  userId: userId,
  avatar: avatar,
  time: time,
  contentHtml: contentHtml,
  replies: replies,
);

void main() {
  group('PlayerComments', () {
    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: true,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error state shows error text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: false,
              error: 'network timeout',
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('加载失败: network timeout'), findsOneWidget);
    });

    testWidgets('empty state shows "暂无评论"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: const [],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('暂无评论'), findsOneWidget);
    });

    testWidgets('populated renders comment items with user names', (
      tester,
    ) async {
      final comments = [
        _comment(id: 1, userName: 'Alice', time: '1月1日', contentHtml: ''),
        _comment(id: 2, userName: 'Bob', time: '1月2日', contentHtml: ''),
        _comment(id: 3, userName: 'Charlie', time: '1月3日', contentHtml: ''),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: comments,
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.text('全部评论'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('1月1日'), findsOneWidget);
      expect(find.text('1月2日'), findsOneWidget);
      expect(find.text('1月3日'), findsOneWidget);
    });

    testWidgets('sortButton is rendered when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: [_comment(id: 1, userName: 'Test', contentHtml: '')],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
              sortButton: const Text('SORT_BTN'),
            ),
          ),
        ),
      );

      expect(find.text('SORT_BTN'), findsOneWidget);
    });

    testWidgets('text_mask span renders BangumiMaskText', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: [
                _comment(
                  id: 1,
                  userName: 'SpoilerAuthor',
                  contentHtml: '<span class="text_mask">剧透剧透</span>',
                ),
              ],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      expect(find.byType(BangumiMaskText), findsOneWidget);
      // The widget renders the masked body and exposes the text once
      // revealed, but the hidden state keeps the raw innerHtml inside the
      // nested HtmlWidget (not directly findable as a plain Text node).
      expect(find.text('SpoilerAuthor'), findsOneWidget);
    });

    testWidgets(
      'Bangumi smile <img> routes through CachedNetworkImage with the smile URL',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlayerComments(
                comments: [
                  _comment(
                    id: 1,
                    userName: 'Smiler',
                    contentHtml:
                        '<div>'
                        '<img src="https://bgm.tv/img/smiles/bgm/01.png" '
                        'width="42" height="42">'
                        'hello'
                        '</div>',
                  ),
                ],
                isLoading: false,
                error: null,
                scrollController: ScrollController(),
              ),
            ),
          ),
        );

        // Only the smile <img> exercises CachedNetworkImage on this page
        // (the avatar fallback path is bypassed by the empty avatar above).
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.imageUrl, 'https://bgm.tv/img/smiles/bgm/01.png');
        expect(image.fit, BoxFit.contain);
        // Smiles render inline at the resolved size.
        expect(image.width, 42);
        expect(image.height, 42);
      },
    );
  });

  group('PlayerComments HTML helpers', () {
    group('normalizeBangumiImageSrc', () {
      test('protocol-relative //bangumi host becomes an https URL', () {
        expect(
          normalizeBangumiImageSrc('//bgm.tv/img/smiles/bgm/01.png'),
          'https://bgm.tv/img/smiles/bgm/01.png',
        );
      });

      test('root-relative /img/ path is prefixed with bangumi.tv', () {
        expect(
          normalizeBangumiImageSrc('/img/smiles/bgm/01.png'),
          'https://bangumi.tv/img/smiles/bgm/01.png',
        );
      });

      test('absolute URL is left intact when proxy is disabled', () {
        expect(
          normalizeBangumiImageSrc('https://bgm.tv/img/smiles/bgm/01.png'),
          'https://bgm.tv/img/smiles/bgm/01.png',
        );
      });

      test('empty input returns empty', () {
        expect(normalizeBangumiImageSrc(''), '');
      });

      test('non-bangumi URL is returned as-is', () {
        expect(
          normalizeBangumiImageSrc('https://example.com/foo.png'),
          'https://example.com/foo.png',
        );
      });
    });

    group('isBangumiSmileUrl', () {
      test('true for canonical bangumi.tv smile path', () {
        expect(
          isBangumiSmileUrl('https://bangumi.tv/img/smiles/bgm/01.png'),
          isTrue,
        );
      });

      test('true for bgm.tv alias host', () {
        expect(
          isBangumiSmileUrl('https://bgm.tv/img/smiles/tv/02.png'),
          isTrue,
        );
      });

      test('true for *.bgm.tv subdomain', () {
        expect(
          isBangumiSmileUrl('https://next.bgm.tv/img/smiles/bg/03.gif'),
          isTrue,
        );
      });

      test('true for chii.in host', () {
        expect(
          isBangumiSmileUrl('https://chii.in/img/smiles/bgm/01.png'),
          isTrue,
        );
      });

      test('true for bangumi.lol mirror and *.bangumi.lol subdomains', () {
        expect(
          isBangumiSmileUrl('https://bangumi.lol/img/smiles/bgm/01.png'),
          isTrue,
        );
        expect(
          isBangumiSmileUrl('https://lain.bangumi.lol/img/smiles/bgm/01.png'),
          isTrue,
        );
      });

      test('false when host matches but path is not a smile path', () {
        expect(isBangumiSmileUrl('https://bgm.tv/img/cover/foo.png'), isFalse);
      });

      test('false for non-bangumi host with a smile-shaped path', () {
        expect(
          isBangumiSmileUrl('https://example.com/img/smiles/bgm/01.png'),
          isFalse,
        );
      });

      test('false for unparseable input', () {
        expect(isBangumiSmileUrl('::not-a-url::'), isFalse);
      });
    });

    group('bangumiSmileSize', () {
      test('both attributes null falls back to 42x42', () {
        const size = Size.square(42);
        expect(bangumiSmileSize(), size);
        expect(bangumiSmileSize(widthAttr: '', heightAttr: ''), size);
      });

      test('scale >= 1 keeps raw clamped to 18..64 (e.g. 20x20)', () {
        final size = bangumiSmileSize(widthAttr: '20', heightAttr: '20');
        expect(size.width, 20);
        expect(size.height, 20);
      });

      test('landscape input scales to a width of 42 (42x21 for 100x50)', () {
        final size = bangumiSmileSize(widthAttr: '100', heightAttr: '50');
        expect(size.width, 42);
        expect(size.height, closeTo(21, 1e-9));
      });

      test('portrait input scales to a height of 42 (21x42 for 50x100)', () {
        final size = bangumiSmileSize(widthAttr: '50', heightAttr: '100');
        expect(size.width, closeTo(21, 1e-9));
        expect(size.height, 42);
      });

      test('oversized clamps the smaller axis to 18 (portrait 300x3000)', () {
        final size = bangumiSmileSize(widthAttr: '300', heightAttr: '3000');
        // scale = 42/3000 (the larger axis dominates); the smaller axis
        // 300 * 0.014 = 4.2 → clamped to 18, the larger axis stays 42.
        expect(size.width, 18);
        expect(size.height, 42);
      });

      test('oversized clamps the smaller axis to 18 (landscape 3000x300)', () {
        final size = bangumiSmileSize(widthAttr: '3000', heightAttr: '300');
        expect(size.width, 42);
        expect(size.height, 18);
      });

      test('only width given falls back to width for height', () {
        final size = bangumiSmileSize(widthAttr: '32');
        expect(size.width, 32);
        expect(size.height, 32);
      });

      test('only height given falls back to height for width', () {
        final size = bangumiSmileSize(heightAttr: '32');
        expect(size.width, 32);
        expect(size.height, 32);
      });
    });
  });
}
