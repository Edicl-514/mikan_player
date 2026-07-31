import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';

import '../../support/localized_widget_tester.dart';

RankingAnime _anime(String title, String id) =>
    RankingAnime(title: title, bangumiId: id, coverUrl: '', info: 'TV / 2026');

PlaybackHistoryItem _history(
  String key,
  String title, {
  int lastPositionMs = 0,
}) => PlaybackHistoryItem(
  key: key,
  title: title,
  subTitle: null,
  bangumiId: '1',
  mikanId: null,
  coverUrl: null,
  siteUrl: null,
  broadcastDay: null,
  broadcastTime: null,
  score: null,
  rank: null,
  tags: const [],
  fullJson: null,
  episodeId: 1,
  episodeSort: 1,
  episodeName: 'Episode 1',
  episodeNameCn: '第一集',
  episodesJson: '[]',
  updatedAt: 1,
  lastPositionMs: lastPositionMs,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('search: late old query cannot replace latest results', (
    tester,
  ) async {
    final oldRequest = Completer<List<RankingAnime>>();
    final newRequest = Completer<List<RankingAnime>>();

    await pumpLocalizedWidget(
      tester,
      SearchPage(
        initialKeyword: 'old',
        autofocus: false,
        fetchPage: (request, page) {
          expect(page, 1);
          return request.keyword == 'old'
              ? oldRequest.future
              : newRequest.future;
        },
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    newRequest.complete([_anime('New Result', '2')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('New Result'), findsOneWidget);

    oldRequest.complete([_anime('Old Result', '1')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('New Result'), findsOneWidget);
    expect(find.text('Old Result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking: error is retryable and retry reaches empty state', (
    tester,
  ) async {
    var attempts = 0;
    await pumpLocalizedWidget(
      tester,
      RankingList(
        sortType: 'rank',
        fetchPage: (_, _) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return <RankingAnime>[];
        },
      ),
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No data'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('history: load failure is retryable instead of looking empty', (
    tester,
  ) async {
    var attempts = 0;
    await pumpLocalizedWidget(
      tester,
      HistoryPage(
        loadHistory: () async {
          attempts++;
          if (attempts == 1) throw StateError('corrupt store');
          return [_history('one', 'Recovered History')];
        },
      ),
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('corrupt store'), findsOneWidget);
    expect(find.text('No history'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Recovered History'), findsOneWidget);
  });

  testWidgets('history: successful storage changes refresh a mounted page', (
    tester,
  ) async {
    var item = _history('one', 'Live History');

    await pumpLocalizedWidget(
      tester,
      HistoryPage(loadHistory: () async => [item]),
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('00:30'), findsNothing);

    item = _history('one', 'Live History', lastPositionMs: 30_000);
    PlaybackHistoryManager().debugNotifyListenersForTest();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('00:30'), findsOneWidget);
  });

  testWidgets('history: delete waits for persistence then refreshes', (
    tester,
  ) async {
    var items = [_history('one', 'Delete Me')];
    final removed = <String>[];
    await pumpLocalizedWidget(
      tester,
      HistoryPage(
        loadHistory: () async => List<PlaybackHistoryItem>.from(items),
        removeHistory: (key) async {
          removed.add(key);
          items = <PlaybackHistoryItem>[];
        },
      ),
      locale: const Locale('en'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Delete Me'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump();
    expect(removed, ['one']);
    expect(find.text('Delete Me'), findsNothing);
    expect(find.text('No history'), findsOneWidget);
  });
}
