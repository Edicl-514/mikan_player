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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
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

    testWidgets('text_mask span renders soft-wrapping BangumiCommentHtml', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: [
                _comment(
                  id: 1,
                  userName: 'SpoilerAuthor',
                  contentHtml: 'before<span class="text_mask">剧透剧透</span>after',
                ),
              ],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      // Masks are soft-wrapping TextSpans inside BangumiCommentHtml, not a
      // rigid InlineCustomWidget box. HtmlWidget may keep body text in nested
      // Text.rich spans rather than plain Text widgets.
      expect(find.byType(BangumiCommentHtml), findsOneWidget);
      expect(find.text('SpoilerAuthor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('revealed mask follows its comment after sorting', (
      tester,
    ) async {
      var comments = [
        _comment(
          id: 1,
          userName: 'First',
          contentHtml: '<span class="text_mask">secret-a</span>',
        ),
        _comment(
          id: 2,
          userName: 'Second',
          contentHtml: '<span class="text_mask">secret-b</span>',
        ),
      ];
      late StateSetter rebuild;
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PlayerComments(
                  comments: comments,
                  isLoading: false,
                  error: null,
                  scrollController: scrollController,
                );
              },
            ),
          ),
        ),
      );

      var secretA = _textSpans(tester, 'secret-a').single;
      expect(_isHiddenMask(secretA), isTrue);
      (secretA.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(_isHiddenMask(_textSpans(tester, 'secret-a').single), isFalse);

      rebuild(() {
        comments = comments.reversed.toList();
      });
      await tester.pump();

      secretA = _textSpans(tester, 'secret-a').single;
      expect(_isHiddenMask(secretA), isFalse);
      expect(_isHiddenMask(_textSpans(tester, 'secret-b').single), isTrue);
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
        // Classic main-site smile hosts are rewritten to the lain CDN.
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.imageUrl, 'https://lain.bgm.tv/img/smiles/bgm/01.png');
        expect(image.fit, BoxFit.contain);
        // Smiles render inline at the resolved size.
        expect(image.width, 42);
        expect(image.height, 42);
      },
    );

    testWidgets('quote block HTML is accepted without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerComments(
              comments: [
                _comment(
                  id: 1,
                  userName: 'Quoter',
                  contentHtml:
                      '<div class="quote"><q><span style="font-weight:bold;">'
                      'Alice</span> 说: hello</q></div>world',
                ),
              ],
              isLoading: false,
              error: null,
              scrollController: ScrollController(),
            ),
          ),
        ),
      );

      // Smoke test: HtmlWidget + quote styles don't throw; header still
      // renders. Quote body may be nested inside package-internal widgets
      // rather than plain Text nodes.
      expect(find.text('Quoter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PlayerComments HTML helpers', () {
    group('normalizeBangumiImageSrc', () {
      test('protocol-relative //bangumi host becomes an https URL', () {
        expect(
          normalizeBangumiImageSrc('//bgm.tv/img/smiles/bgm/01.png'),
          'https://lain.bgm.tv/img/smiles/bgm/01.png',
        );
      });

      test('root-relative /img/smiles/ path is served from lain CDN', () {
        expect(
          normalizeBangumiImageSrc('/img/smiles/bgm/01.png'),
          'https://lain.bgm.tv/img/smiles/bgm/01.png',
        );
      });

      test('root-relative non-smile /img/ path keeps bangumi.tv', () {
        expect(
          normalizeBangumiImageSrc('/img/cover/foo.png'),
          'https://bangumi.tv/img/cover/foo.png',
        );
      });

      test('classic main-site smile URL is rewritten to lain CDN', () {
        expect(
          normalizeBangumiImageSrc('https://bgm.tv/img/smiles/bgm/01.png'),
          'https://lain.bgm.tv/img/smiles/bgm/01.png',
        );
        expect(
          normalizeBangumiImageSrc('https://chii.in/img/smiles/tv/15.gif'),
          'https://lain.bgm.tv/img/smiles/tv/15.gif',
        );
        expect(
          normalizeBangumiImageSrc('https://bangumi.tv/img/smiles/tv/15.gif'),
          'https://lain.bgm.tv/img/smiles/tv/15.gif',
        );
      });

      test('already-lain smile URL is left intact when proxy is disabled', () {
        expect(
          normalizeBangumiImageSrc(
            'https://lain.bgm.tv/img/smiles/musume/musume_82.gif',
          ),
          'https://lain.bgm.tv/img/smiles/musume/musume_82.gif',
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

    group('bangumiCommentHtmlStyles', () {
      test('img gets max size constraints', () {
        final styles = bangumiCommentHtmlStyles(_FakeElement(localName: 'img'));
        expect(styles?['max-width'], '100%');
        expect(styles?['max-height'], '350px');
      });

      test('div.quote gets a left border and muted colors', () {
        final styles = bangumiCommentHtmlStyles(
          _FakeElement(localName: 'div', classes: {'quote'}),
        );
        expect(styles?['border-left'], contains('3px solid'));
        expect(styles?['background-color'], isNotNull);
        expect(styles?['color'], isNotNull);
      });

      test('q inside quotes drops default italic/quotes', () {
        final styles = bangumiCommentHtmlStyles(_FakeElement(localName: 'q'));
        expect(styles?['quotes'], 'none');
        expect(styles?['font-style'], 'normal');
      });

      test('unrelated elements return null', () {
        expect(bangumiCommentHtmlStyles(_FakeElement(localName: 'p')), isNull);
        expect(
          bangumiCommentHtmlStyles(
            _FakeElement(localName: 'div', classes: {'other'}),
          ),
          isNull,
        );
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

/// Minimal stand-in for `package:html` elements used by
/// [bangumiCommentHtmlStyles] unit tests (avoids spinning up HtmlWidget).
class _FakeElement {
  final String? localName;
  final Set<String> classes;

  _FakeElement({this.localName, this.classes = const {}});
}

List<TextSpan> _textSpans(WidgetTester tester, String text) {
  final matches = <TextSpan>[];

  void visit(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text == text) matches.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child);
    }
  }

  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(richText.text);
  }
  return matches;
}

bool _isHiddenMask(TextSpan span) =>
    span.style?.background?.color.toARGB32() == 0xFF555555 &&
    span.style?.color?.toARGB32() == 0xFF555555;
