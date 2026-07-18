// Phase 1 / Package A focused widget tests for the extracted
// `SourceListPanel` widget.
//
// L10N-2: empty-state copy uses AppLocalizations, so the tree is pumped through
// pumpLocalizedWidget. Pure helpers remain locale-free.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/source_list_panel.dart';

import '../../../support/localized_widget_tester.dart';

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

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<SearchPlayResult> availableSources,
  String currentSourceLabel = '',
  ValueListenable<List<SearchPlayResult>>? availableSourcesListenable,
  ValueNotifier<int>? sourceIndexNotifier,
  ValueListenable<String>? currentSourceLabelListenable,
  void Function(int)? onSourceSelected,
  ScrollController? scrollController,
  Locale locale = const Locale('zh'),
}) async {
  await pumpLocalizedWidget(
    tester,
    Scaffold(
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
    locale: locale,
  );
}

void main() {
  group('SourceListPanel', () {
    testWidgets('empty availableSources renders localized empty-state (zh)', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        availableSources: const <SearchPlayResult>[],
        locale: const Locale('zh'),
      );

      final l10n = localizedOf(tester);
      expect(find.text(l10n.noAvailablePlaybackSource), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('empty availableSources renders localized empty-state (en)', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        availableSources: const <SearchPlayResult>[],
        locale: const Locale('en'),
      );

      final l10n = localizedOf(tester);
      expect(find.text(l10n.noAvailablePlaybackSource), findsOneWidget);
      expect(find.text('暂无可用播放源'), findsNothing);
    });

    testWidgets('renders one card per source with sourceName label', (
      tester,
    ) async {
      final sources = [
        _source(sourceName: 'sourceOne'),
        _source(sourceName: 'sourceTwo'),
      ];
      await _pumpPanel(tester, availableSources: sources);

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
      await _pumpPanel(
        tester,
        availableSources: sources,
        currentSourceLabel: 'alpha(ch1)',
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
      await _pumpPanel(
        tester,
        availableSources: sources,
        onSourceSelected: (index) => captured = index,
      );

      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(captured, 1);
    });

    testWidgets(
      'initState prefers listenable values over stale constructor props',
      (tester) async {
        final staleSources = [_source(sourceName: 'stale')];
        final freshSources = [_source(sourceName: 'fresh')];
        final sourcesNotifier = ValueNotifier<List<SearchPlayResult>>(
          freshSources,
        );
        final labelNotifier = ValueNotifier<String>('fresh');
        final indexNotifier = ValueNotifier<int>(0);

        await _pumpPanel(
          tester,
          availableSources: staleSources,
          availableSourcesListenable: sourcesNotifier,
          currentSourceLabel: 'stale',
          currentSourceLabelListenable: labelNotifier,
          sourceIndexNotifier: indexNotifier,
        );

        expect(find.text('fresh'), findsOneWidget);
        expect(find.text('stale'), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets('availableSourcesListenable changes update the rendered list', (
      tester,
    ) async {
      final notifier = ValueNotifier<List<SearchPlayResult>>(const []);
      await _pumpPanel(
        tester,
        availableSources: const <SearchPlayResult>[],
        availableSourcesListenable: notifier,
      );

      final l10n = localizedOf(tester);
      expect(find.text(l10n.noAvailablePlaybackSource), findsOneWidget);

      notifier.value = [_source(sourceName: 'lateOne')];
      await tester.pumpAndSettle();

      expect(find.text(l10n.noAvailablePlaybackSource), findsNothing);
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
        await _pumpPanel(
          tester,
          availableSources: sources,
          currentSourceLabelListenable: labelNotifier,
          currentSourceLabel: '',
        );

        expect(find.byIcon(Icons.check_circle), findsNothing);

        labelNotifier.value = 'alpha';
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        final alpha = tester
            .widgetList<Text>(find.byType(Text))
            .firstWhere((t) => t.data == 'alpha');
        expect(alpha.style?.fontWeight, FontWeight.bold);

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

    test('protocol source-label sentinels stay fixed Chinese tokens', () {
      expect(kPlayerSourceLabelUnknown, '未知');
      expect(kPlayerSourceLabelNotPlaying, '未播放');
    });
  });
}
