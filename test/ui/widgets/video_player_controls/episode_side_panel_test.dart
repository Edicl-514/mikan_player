// Phase 1 / Package A focused widget tests for the extracted
// `EpisodeSidePanel` widget.
//
// The panel is a pure Flutter widget tree (no network, no WebView, no media
// player), so these tests exercise the real widget under a `MaterialApp` and
// assert on the rendered cells, selection styling, and selection callback
// + navigator-pop behavior.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/video_player_controls/episode_side_panel.dart';

BangumiEpisode _episode({int id = 0, double sort = 1}) => BangumiEpisode(
  id: id,
  name: '',
  nameCn: '',
  description: '',
  airdate: '',
  duration: '',
  sort: sort,
);

Widget _wrap(
  Widget child, {
  ValueListenable<BangumiEpisode>? currentEpisodeListenable,
  required List<BangumiEpisode> allEpisodes,
  required BangumiEpisode currentEpisode,
  void Function(BangumiEpisode)? onSelected,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: EpisodeSidePanel(
            allEpisodes: allEpisodes,
            currentEpisode: currentEpisode,
            currentEpisodeListenable: currentEpisodeListenable,
            onEpisodeSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('EpisodeSidePanel', () {
    testWidgets('renders one cell per episode with sort label', (tester) async {
      final eps = [
        _episode(id: 1, sort: 1),
        _episode(id: 2, sort: 2),
        _episode(id: 3, sort: 3),
      ];
      await tester.pumpWidget(
        _wrap(Container(), allEpisodes: eps, currentEpisode: eps[1]),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('共3集'), findsOneWidget);
      expect(find.text('选集'), findsOneWidget);
    });

    testWidgets('current episode cell is bold-styled (selected)', (
      tester,
    ) async {
      final eps = [
        _episode(id: 1, sort: 1),
        _episode(id: 2, sort: 2),
        _episode(id: 3, sort: 3),
      ];
      await tester.pumpWidget(
        _wrap(Container(), allEpisodes: eps, currentEpisode: eps[1]),
      );

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

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
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
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('选集'), findsOneWidget);

        // Tap the cell labelled "1" (non-current)
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();

        // Navigator route should be popped
        expect(find.text('选集'), findsNothing);
        expect(captured, isNotNull);
        expect(captured!.id, eps[0].id);
        expect(captured!.sort, eps[0].sort);
      },
    );

    testWidgets(
      'empty episode list renders header with "共0集" without exception',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Container(),
            allEpisodes: const <BangumiEpisode>[],
            currentEpisode: _episode(id: 0, sort: 0),
          ),
        );

        expect(find.text('共0集'), findsOneWidget);
        expect(find.text('选集'), findsOneWidget);
        // No episode cells
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

      await tester.pumpWidget(
        _wrap(
          Container(),
          allEpisodes: eps,
          currentEpisode: eps[0],
          currentEpisodeListenable: notifier,
        ),
      );

      // Initially episode 1 is selected -> "1" should be bold
      var labels = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '1' || t.data == '2' || t.data == '3');
      var oneText = labels.firstWhere((t) => t.data == '1');
      var twoText = labels.firstWhere((t) => t.data == '2');
      expect(oneText.style?.fontWeight, FontWeight.bold);
      expect(twoText.style?.fontWeight, isNot(FontWeight.bold));

      // Update notifier -> episode 2 becomes selected
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
