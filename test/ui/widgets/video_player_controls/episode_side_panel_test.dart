// Phase 1 / Package A focused widget tests for the extracted
// `EpisodeSidePanel` widget.
//
// L10N-2: panel title / episode-count use AppLocalizations, so the tree is
// pumped through pumpLocalizedWidget (zh + en smoke).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/episode_side_panel.dart';

import '../../../support/localized_widget_tester.dart';

BangumiEpisode _episode({int id = 0, double sort = 1}) => BangumiEpisode(
  id: id,
  name: '',
  nameCn: '',
  description: '',
  airdate: '',
  duration: '',
  sort: sort,
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  ValueListenable<BangumiEpisode>? currentEpisodeListenable,
  required List<BangumiEpisode> allEpisodes,
  required BangumiEpisode currentEpisode,
  void Function(BangumiEpisode)? onSelected,
  Locale locale = const Locale('zh'),
}) async {
  await pumpLocalizedWidget(
    tester,
    Scaffold(
      body: Center(
        child: EpisodeSidePanel(
          allEpisodes: allEpisodes,
          currentEpisode: currentEpisode,
          currentEpisodeListenable: currentEpisodeListenable,
          onEpisodeSelected: onSelected ?? (_) {},
        ),
      ),
    ),
    locale: locale,
  );
}

void main() {
  group('EpisodeSidePanel', () {
    testWidgets('renders one cell per episode with sort label (zh)', (
      tester,
    ) async {
      final eps = [
        _episode(id: 1, sort: 1),
        _episode(id: 2, sort: 2),
        _episode(id: 3, sort: 3),
      ];
      await _pumpPanel(
        tester,
        allEpisodes: eps,
        currentEpisode: eps[1],
        locale: const Locale('zh'),
      );

      final l10n = localizedOf(tester);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text(l10n.subtitleTrackCount(3)), findsOneWidget);
      expect(find.text(l10n.selectEpisode), findsOneWidget);
    });

    testWidgets('renders localized header in en', (tester) async {
      final eps = [_episode(id: 1, sort: 1), _episode(id: 2, sort: 2)];
      await _pumpPanel(
        tester,
        allEpisodes: eps,
        currentEpisode: eps[0],
        locale: const Locale('en'),
      );

      final l10n = localizedOf(tester);
      expect(find.text(l10n.selectEpisode), findsOneWidget);
      expect(find.text(l10n.subtitleTrackCount(2)), findsOneWidget);
      expect(find.byTooltip(l10n.closeEpisodesBarrier), findsOneWidget);
      expect(find.text('共2集'), findsNothing);
    });

    testWidgets('current episode cell is bold-styled (selected)', (
      tester,
    ) async {
      final eps = [
        _episode(id: 1, sort: 1),
        _episode(id: 2, sort: 2),
        _episode(id: 3, sort: 3),
      ];
      await _pumpPanel(tester, allEpisodes: eps, currentEpisode: eps[1]);

      final textWidgets = find.byType(Text);
      final selectedText = tester
          .widgetList<Text>(textWidgets)
          .firstWhere((t) => t.data == '2');
      final unselectedText = tester
          .widgetList<Text>(textWidgets)
          .firstWhere((t) => t.data == '1');

      expect(selectedText.style?.fontWeight, FontWeight.bold);
      expect(unselectedText.style?.fontWeight, isNot(FontWeight.bold));
    });

    testWidgets(
      'tapping a non-current episode calls onEpisodeSelected and pops the route',
      (tester) async {
        final eps = [
          _episode(id: 1, sort: 1),
          _episode(id: 2, sort: 2),
          _episode(id: 3, sort: 3),
        ];
        BangumiEpisode? captured;

        await pumpLocalizedWidget(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EpisodeSidePanel(
                          allEpisodes: eps,
                          currentEpisode: eps[1],
                          onEpisodeSelected: (ep) => captured = ep,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final l10n = localizedOf(tester);
        expect(find.text(l10n.selectEpisode), findsOneWidget);

        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.selectEpisode), findsNothing);
        expect(captured, isNotNull);
        expect(captured!.id, eps[0].id);
        expect(captured!.sort, eps[0].sort);
      },
    );

    testWidgets(
      'empty episode list renders localized header without exception',
      (tester) async {
        await _pumpPanel(
          tester,
          allEpisodes: const <BangumiEpisode>[],
          currentEpisode: _episode(id: 0, sort: 0),
        );

        final l10n = localizedOf(tester);
        expect(find.text(l10n.subtitleTrackCount(0)), findsOneWidget);
        expect(find.text(l10n.selectEpisode), findsOneWidget);
        expect(find.text('1'), findsNothing);
      },
    );

    testWidgets('ValueListenable changes update the highlighted cell', (
      tester,
    ) async {
      final eps = [
        _episode(id: 1, sort: 1),
        _episode(id: 2, sort: 2),
        _episode(id: 3, sort: 3),
      ];
      final notifier = ValueNotifier<BangumiEpisode>(eps[0]);

      await _pumpPanel(
        tester,
        allEpisodes: eps,
        currentEpisode: eps[0],
        currentEpisodeListenable: notifier,
      );

      var labels = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '1' || t.data == '2' || t.data == '3');
      var oneText = labels.firstWhere((t) => t.data == '1');
      var twoText = labels.firstWhere((t) => t.data == '2');
      expect(oneText.style?.fontWeight, FontWeight.bold);
      expect(twoText.style?.fontWeight, isNot(FontWeight.bold));

      notifier.value = eps[1];
      await tester.pumpAndSettle();

      labels = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '1' || t.data == '2' || t.data == '3');
      oneText = labels.firstWhere((t) => t.data == '1');
      twoText = labels.firstWhere((t) => t.data == '2');
      expect(twoText.style?.fontWeight, FontWeight.bold);
      expect(oneText.style?.fontWeight, isNot(FontWeight.bold));
    });
  });
}
