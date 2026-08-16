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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
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
  int state = 0,
  String contentHtml = '',
  List<BangumiEpisodeComment> replies = const [],
  List<BangumiCommentReaction> reactions = const [],
}) => BangumiEpisodeComment(
  id: id,
  userName: userName,
  userId: userId,
  avatar: avatar,
  time: time,
  state: state,
  contentHtml: contentHtml,
  replies: replies,
  reactions: reactions,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('PlayerComments', () {
    testWidgets('loading state shows CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
            comments: const [],
            isLoading: true,
            error: null,
            scrollController: ScrollController(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error state shows error text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
            comments: const [],
            isLoading: false,
            error: 'network timeout',
            scrollController: ScrollController(),
          ),
        ),
      );

      expect(
        find.text(l10n.playerCommentsLoadFailed('network timeout')),
        findsOneWidget,
      );
    });

    testWidgets('empty state shows localized empty copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
            comments: const [],
            isLoading: false,
            error: null,
            scrollController: ScrollController(),
          ),
        ),
      );

      expect(find.text(l10n.playerCommentsEmpty), findsOneWidget);
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
        _wrap(
          PlayerComments(
            comments: comments,
            isLoading: false,
            error: null,
            scrollController: ScrollController(),
          ),
        ),
      );

      expect(find.text(l10n.playerCommentsTitle), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('1月1日'), findsOneWidget);
      expect(find.text('1月2日'), findsOneWidget);
      expect(find.text('1月3日'), findsOneWidget);
    });

    testWidgets('sortButton is rendered when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
            comments: [_comment(id: 1, userName: 'Test', contentHtml: '')],
            isLoading: false,
            error: null,
            scrollController: ScrollController(),
            sortButton: const Text('SORT_BTN'),
          ),
        ),
      );

      expect(find.text('SORT_BTN'), findsOneWidget);
    });

    testWidgets('text_mask span renders soft-wrapping BangumiCommentHtml', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
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
        _wrap(
          StatefulBuilder(
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
          _wrap(
            PlayerComments(
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
        );

        // Only the smile <img> exercises CachedNetworkImage on this page
        // (the avatar fallback path is bypassed by the empty avatar above).
        // Classic main-site smile hosts are rewritten to the lain CDN.
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(image.imageUrl, 'https://lain.bgm.tv/img/smiles/bgm/01.png');
        expect(image.fit, BoxFit.contain);
        // Smiles render inline at the resolved size (24x24 for old small smiles).
        expect(image.width, 24);
        expect(image.height, 24);
      },
    );

    testWidgets('quote block HTML is accepted without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerComments(
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
      test(
        'both attributes null falls back to 24x24 for old small smiles and 42x42 for large smiles',
        () {
          expect(bangumiSmileSize(), const Size.square(24));
          expect(
            bangumiSmileSize(widthAttr: '', heightAttr: ''),
            const Size.square(24),
          );
          expect(bangumiSmileSize(isLarge: true), const Size.square(42));
        },
      );

      test('small smile with raw dimensions is clamped to 14..28', () {
        final size = bangumiSmileSize(widthAttr: '20', heightAttr: '20');
        expect(size.width, 20);
        expect(size.height, 20);

        final largeClamped = bangumiSmileSize(
          widthAttr: '100',
          heightAttr: '100',
        );
        expect(largeClamped.width, 24);
        expect(largeClamped.height, 24);
      });

      test('landscape input for large smiles scales to a width of 42', () {
        final size = bangumiSmileSize(
          widthAttr: '100',
          heightAttr: '50',
          isLarge: true,
        );
        expect(size.width, 42);
        expect(size.height, closeTo(21, 1e-9));
      });

      test('portrait input for large smiles scales to a height of 42', () {
        final size = bangumiSmileSize(
          widthAttr: '50',
          heightAttr: '100',
          isLarge: true,
        );
        expect(size.width, closeTo(21, 1e-9));
        expect(size.height, 42);
      });

      test('only width given falls back to width for height', () {
        final size = bangumiSmileSize(widthAttr: '20');
        expect(size.width, 20);
        expect(size.height, 20);
      });

      test('only height given falls back to height for width', () {
        final size = bangumiSmileSize(heightAttr: '20');
        expect(size.width, 20);
        expect(size.height, 20);
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
