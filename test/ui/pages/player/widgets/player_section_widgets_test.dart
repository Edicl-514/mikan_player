// Phase 1.7 smoke tests for extracted player UI section widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comment_sort_button.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_current_source_actions.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_onair_sites_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_episode_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_section_header.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_source_progress_item.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('PlayerSectionHeader shows title', (tester) async {
    await tester.pumpWidget(_wrap(const PlayerSectionHeader('播放源')));
    expect(find.text('播放源'), findsOneWidget);
  });

  testWidgets('PlayerCommentSortButton shows mode label and fires onSelected', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        PlayerCommentSortButton(
          sortMode: 'default',
          onSelected: (v) => selected = v,
        ),
      ),
    );
    expect(find.text('默认排序'), findsOneWidget);
    await tester.tap(find.byType(PlayerCommentSortButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按时间排序').last);
    await tester.pumpAndSettle();
    expect(selected, 'time');
  });

  testWidgets('PlayerCurrentSourceActions disables when canAct=false', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        PlayerCurrentSourceActions(
          canAct: false,
          onDownload: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('下载'));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('PlayerSourceProgressItem maps failed step', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PlayerSourceProgressItem(
          sourceName: 'srcA',
          progress: SourceSearchProgress(
            sourceName: 'srcA',
            step: SearchStep.failed,
            error: 'boom',
            playPageUrl: null,
            videoRegex: null,
            directVideoUrl: null,
            cookies: null,
            headers: null,
            enableNestedUrl: false,
          ),
        ),
      ),
    );
    expect(find.text('srcA'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('PlayerOnairSitesList renders titles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PlayerOnairSitesList(
          sites: [
            BangumiDataSiteEntry(
              site: 'bilibili',
              title: '哔哩哔哩',
              url: 'https://example.com',
              kind: 'onair',
            ),
          ],
        ),
      ),
    );
    expect(find.text('哔哩哔哩'), findsOneWidget);
  });

  testWidgets('PlayerPcEpisodeList selects episode', (tester) async {
    final eps = [
      const BangumiEpisode(
        id: 1,
        name: 'EP1',
        nameCn: '第一集',
        description: '',
        airdate: '2024-01-01',
        duration: '',
        sort: 1,
      ),
      const BangumiEpisode(
        id: 2,
        name: 'EP2',
        nameCn: '第二集',
        description: '',
        airdate: '2024-01-08',
        duration: '',
        sort: 2,
      ),
    ];
    BangumiEpisode? picked;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          height: 400,
          child: PlayerPcEpisodeList(
            episodes: eps,
            currentEpisode: eps.first,
            scrollController: ScrollController(),
            onEpisodeSelected: (e) => picked = e,
          ),
        ),
      ),
    );
    expect(find.text('第一集'), findsOneWidget);
    await tester.tap(find.text('第二集'));
    await tester.pump();
    expect(picked?.id, 2);
  });
}
