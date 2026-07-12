// Phase 1 / Package A focused widget tests for the extracted
// `SourceListPanel` widget.
//
// The panel is a pure Flutter widget tree (no network, no WebView, no media
// player, no platform channels), so these tests exercise the real widget under
// a `MaterialApp` and assert on the rendered source cards, empty state,
// selection styling, callback forwarding, and `ValueListenable` reactivity.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/source_list_panel.dart';

SearchPlayResult _source({
  String sourceName = 'srcA',
  String? channelName,
  String? directVideoUrl,
  BigInt? channelIndex,
}) {
  return SearchPlayResult(
    sourceName: sourceName,
    playPageUrl: 'http://host/play',
    videoRegex: 'regexA',
    directVideoUrl: directVideoUrl,
    channelName: channelName,
    channelIndex: channelIndex,
    enableNestedUrl: false,
  );
}

Widget _wrap(
  Widget child, {
  required List<SearchPlayResult> availableSources,
  String currentSourceLabel = '',
  ValueListenable<List<SearchPlayResult>>? availableSourcesListenable,
  ValueNotifier<int>? sourceIndexNotifier,
  ValueListenable<String>? currentSourceLabelListenable,
  void Function(int)? onSourceSelected,
  ScrollController? scrollController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SourceListPanel(
          availableSources: availableSources,
          availableSourcesListenable: availableSourcesListenable,
          sourceIndexNotifier: sourceIndexNotifier,
          currentSourceLabel: currentSourceLabel,
          currentSourceLabelListenable: currentSourceLabelListenable,
          onSourceSelected: onSourceSelected ?? (_) {},
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

void main() {
  group('SourceListPanel', () {
    testWidgets('empty availableSources renders the empty-state message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(Container(), availableSources: const <SearchPlayResult>[]),
      );

      expect(find.text('暂无可用播放源'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders one card per source with sourceName label', (
      tester,
    ) async {
      final sources = [
        _source(sourceName: 'sourceOne'),
        _source(sourceName: 'sourceTwo'),
      ];
      await tester.pumpWidget(_wrap(Container(), availableSources: sources));

      expect(find.text('sourceOne'), findsOneWidget);
      expect(find.text('sourceTwo'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('selected card shows the Icons.check_circle trailing icon', (
      tester,
    ) async {
      final sources = [
        _source(sourceName: 'alpha', channelName: 'ch1'),
        _source(sourceName: 'beta'),
      ];
      // currentSourceLabel matches sourceDisplayLabel(sources[0]) == 'alpha(ch1)'.
      await tester.pumpWidget(
        _wrap(
          Container(),
          availableSources: sources,
          currentSourceLabel: 'alpha(ch1)',
        ),
      );

      // Only the selected card renders the trailing check_circle icon.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // The selected sourceName should be styled bold.
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final selectedText = textWidgets.firstWhere((t) => t.data == 'alpha');
      expect(selectedText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('tapping a card forwards the index to onSourceSelected', (
      tester,
    ) async {
      final sources = [
        _source(sourceName: 'alpha'),
        _source(sourceName: 'beta'),
      ];
      int? captured;
      await tester.pumpWidget(
        _wrap(
          Container(),
          availableSources: sources,
          onSourceSelected: (index) => captured = index,
        ),
      );

      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(captured, 1);
    });

    testWidgets('availableSourcesListenable changes update the rendered list', (
      tester,
    ) async {
      final notifier = ValueNotifier<List<SearchPlayResult>>(const []);
      await tester.pumpWidget(
        _wrap(
          Container(),
          availableSources: const <SearchPlayResult>[],
          availableSourcesListenable: notifier,
        ),
      );

      expect(find.text('暂无可用播放源'), findsOneWidget);

      notifier.value = [_source(sourceName: 'lateOne')];
      await tester.pumpAndSettle();

      expect(find.text('暂无可用播放源'), findsNothing);
      expect(find.text('lateOne'), findsOneWidget);
    });

    testWidgets(
      'currentSourceLabelListenable change moves the selection highlight',
      (tester) async {
        final sources = [
          _source(sourceName: 'alpha'),
          _source(sourceName: 'beta'),
        ];
        final labelNotifier = ValueNotifier<String>('');
        await tester.pumpWidget(
          _wrap(
            Container(),
            availableSources: sources,
            currentSourceLabelListenable: labelNotifier,
            currentSourceLabel: '',
          ),
        );

        // No label -> nothing selected.
        expect(find.byIcon(Icons.check_circle), findsNothing);

        // Move selection to source 1 (display label == 'alpha').
        labelNotifier.value = 'alpha';
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        final alpha = tester
            .widgetList<Text>(find.byType(Text))
            .firstWhere((t) => t.data == 'alpha');
        expect(alpha.style?.fontWeight, FontWeight.bold);

        // Move selection to source 2 (display label == 'beta').
        labelNotifier.value = 'beta';
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        final alphaAgain = tester
            .widgetList<Text>(find.byType(Text))
            .firstWhere((t) => t.data == 'alpha');
        final beta = tester
            .widgetList<Text>(find.byType(Text))
            .firstWhere((t) => t.data == 'beta');
        expect(beta.style?.fontWeight, FontWeight.bold);
        expect(alphaAgain.style?.fontWeight, isNot(FontWeight.bold));
      },
    );
  });

  group('source-list pure helpers', () {
    test('sourceDisplayLabel appends channelName when present', () {
      expect(sourceDisplayLabel(_source(sourceName: 'a')), 'a');
      expect(
        sourceDisplayLabel(_source(sourceName: 'a', channelName: 'ch1')),
        'a(ch1)',
      );
      expect(
        sourceDisplayLabel(_source(sourceName: 'a', channelName: '')),
        'a',
      );
    });

    test('clampSourceIndex bounds the index to the list range', () {
      expect(clampSourceIndex(5, const <SearchPlayResult>[]), 0);
      expect(clampSourceIndex(-1, [_source()]), 0);
      expect(clampSourceIndex(99, [_source(), _source()]), 1);
    });

    test('resolveActiveOnlineSourceIndex matches label then sourceName', () {
      final sources = [
        _source(sourceName: 'alpha', channelName: 'ch1'),
        _source(sourceName: 'beta'),
      ];

      expect(resolveActiveOnlineSourceIndex(sources, 'alpha(ch1)'), 0);
      expect(resolveActiveOnlineSourceIndex(sources, 'beta'), 1);
      expect(resolveActiveOnlineSourceIndex(sources, 'unknown'), isNull);
      expect(
        resolveActiveOnlineSourceIndex(const <SearchPlayResult>[], 'x'),
        isNull,
      );
    });
  });
}
