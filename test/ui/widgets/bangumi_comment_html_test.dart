import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';

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
