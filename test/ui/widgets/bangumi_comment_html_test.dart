import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

void main() {
  group('Bangumi comment mask HTML', () {
    test('removes style attribute from text_mask spans', () {
      const input =
          'x<span class="text_mask" style="background-color:#555;color:#555;border:1px solid #555;">'
          '<span class="inner">spoiler</span></span>y';
      final out = stripTextMaskInlineStyles(input);
      expect(out, contains('class="text_mask"'));
      expect(out, isNot(contains('style=')));
      expect(out, contains('spoiler'));
      expect(out, startsWith('x'));
      expect(out, endsWith('y'));
    });

    test('leaves non-mask spans alone', () {
      const input = '<span style="color:red">hi</span>';
      expect(stripTextMaskInlineStyles(input), input);
    });

    test('assigns different stable IDs to duplicate masks', () {
      const input =
          '<span class="text_mask">same</span>'
          '<span class="text_mask">same</span>';
      final once = annotateTextMaskIds(input);
      final twice = annotateTextMaskIds(input);

      expect(once, contains('data-mikan-mask-id="0"'));
      expect(once, contains('data-mikan-mask-id="1"'));
      expect(twice, once);
    });
  });

  group('defaultBangumiCommentHtmlStyles', () {
    test('img gets max size constraints', () {
      final styles = defaultBangumiCommentHtmlStyles(_FakeElement(localName: 'img'));
      expect(styles?['max-width'], '100%');
      expect(styles?['max-height'], '350px');
    });

    test('div.quote and blockquote get left border and muted background', () {
      final divStyles = defaultBangumiCommentHtmlStyles(
        _FakeElement(localName: 'div', classes: {'quote'}),
      );
      expect(divStyles?['border-left'], contains('3px solid'));
      expect(divStyles?['background-color'], isNotNull);
      expect(divStyles?['color'], isNotNull);

      final bqStyles = defaultBangumiCommentHtmlStyles(
        _FakeElement(localName: 'blockquote'),
      );
      expect(bqStyles?['border-left'], contains('3px solid'));
    });

    test('q inside quotes drops default italic/quotes', () {
      final styles = defaultBangumiCommentHtmlStyles(_FakeElement(localName: 'q'));
      expect(styles?['quotes'], 'none');
      expect(styles?['font-style'], 'normal');
    });

    test('unrelated elements return null', () {
      expect(defaultBangumiCommentHtmlStyles(_FakeElement(localName: 'p')), isNull);
    });
  });

  test('only permits absolute HTTP(S) external URLs', () {
    expect(isSafeBangumiExternalUrl('https://bgm.tv/subject/1'), isTrue);
    expect(isSafeBangumiExternalUrl('http://example.com/a.png'), isTrue);
    expect(isSafeBangumiExternalUrl('javascript:alert(1)'), isFalse);
    expect(isSafeBangumiExternalUrl('file:///C:/secret.txt'), isFalse);
    expect(isSafeBangumiExternalUrl('/subject/1'), isFalse);
  });

  testWidgets('moderated and folded comment states are respected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        const Column(
          children: [
            BangumiCommentBody(state: 6, html: 'deleted secret'),
            BangumiCommentBody(state: 8, html: 'folded content'),
          ],
        ),
      ),
    );

    expect(find.text('该评论不可见'), findsOneWidget);
    expect(find.text('deleted secret'), findsNothing);
    expect(find.text('该评论已折叠'), findsOneWidget);
    expect(find.text('folded content'), findsNothing);

    await tester.tap(find.text('展开'));
    await tester.pump();

    expect(find.text('该评论已折叠'), findsNothing);
    expect(find.byType(BangumiCommentHtml), findsOneWidget);
  });

  testWidgets('duplicate masks toggle independently', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BangumiCommentHtml(
            html:
                '<span class="text_mask">same</span> between '
                '<span class="text_mask">same</span>',
            textStyle: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    var spans = _textSpans(tester, 'same');
    expect(spans, hasLength(2));
    expect(spans.every(_isHiddenMask), isTrue);

    final recognizer = spans.first.recognizer! as TapGestureRecognizer;
    recognizer.onTap!();
    await tester.pump();

    spans = _textSpans(tester, 'same');
    expect(spans.where(_isHiddenMask), hasLength(1));
  });

  testWidgets('mask reveals on hover and hides after exit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BangumiCommentHtml(
            html: '<span class="text_mask">hover me</span>',
            textStyle: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );

    expect(_isHiddenMask(_textSpans(tester, 'hover me').single), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(-10, -10));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(BangumiCommentHtml)));
    await tester.pump(const Duration(milliseconds: 40));

    var span = _textSpans(tester, 'hover me').single;
    expect(_isHiddenMask(span), isFalse);
    await mouse.moveTo(tester.getBottomRight(find.byType(Scaffold)));
    await tester.pump(const Duration(milliseconds: 40));

    span = _textSpans(tester, 'hover me').single;
    expect(_isHiddenMask(span), isTrue);
  });

  testWidgets('Bangumi smile <img> and regular <img> route through CachedNetworkImage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BangumiCommentHtml(
            html:
                '<p>Smile: <img src="/img/smiles/tv/15.gif" class="smile" smileid="38" /></p>'
                '<p>Photo: <img src="https://lain.bgm.tv/pic/photo/l/foo.jpg" class="code" /></p>',
          ),
        ),
      ),
    );

    expect(find.byType(BangumiCommentHtml), findsOneWidget);
    // Both smile image and regular image should be rendered using CachedNetworkImage
    final cachedImages = tester.widgetList(find.byType(CachedNetworkImage)).whereType<CachedNetworkImage>();
    expect(cachedImages.length, greaterThanOrEqualTo(2));
    expect(cachedImages.any((img) => img.imageUrl.contains('/img/smiles/tv/15.gif')), isTrue);
    expect(cachedImages.any((img) => img.imageUrl == 'https://lain.bgm.tv/pic/photo/l/foo.jpg'), isTrue);
  });
}

Widget _localized(Widget child) => MaterialApp(
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

class _FakeElement {
  final String? localName;
  final Set<String> classes;

  _FakeElement({this.localName, this.classes = const {}});
}
