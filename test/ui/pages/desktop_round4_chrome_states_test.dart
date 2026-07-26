import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/settings_page.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';

import '../../support/localized_widget_tester.dart';

void main() {
  group('hosted page state branches', () {
    testWidgets('history stays headerless through loading, error, and empty', (
      tester,
    ) async {
      final requests = <Completer<List<PlaybackHistoryItem>>>[];

      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(
          child: HistoryPage(
            loadHistory: () {
              final request = Completer<List<PlaybackHistoryItem>>();
              requests.add(request);
              return request.future;
            },
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      requests.single.completeError(StateError('load failed'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(requests, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      requests.last.complete(const <PlaybackHistoryItem>[]);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('search keeps its command row in loading and empty states', (
      tester,
    ) async {
      final request = Completer<List<RankingAnime>>();

      await pumpLocalizedWidget(
        tester,
        DesktopPageChromeScope(
          child: SearchPage(
            initialKeyword: 'missing',
            fetchPage: (_, _) => request.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      request.complete(const <RankingAnime>[]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });
  });

  testWidgets('opening and closing a page dialog does not restore an AppBar', (
    tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      const DesktopPageChromeScope(child: SettingsPage()),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    final dialogContext = tester.element(find.byType(AlertDialog));
    final cancelLabel = AppLocalizations.of(dialogContext).cancel;
    await tester.tap(find.text(cancelLabel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });
}
