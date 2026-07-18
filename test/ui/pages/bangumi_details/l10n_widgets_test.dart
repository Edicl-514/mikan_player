// Widget i18n smoke tests for L10N-3 bangumi details surfaces.
//
// These presentational widgets are pure UI; tests only assert zh/en labels
// and that English copy does not overflow a narrow mobile width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_actions.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_collection_stats.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_rating.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/placeholder_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/summary_tags.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  group('Bangumi details i18n (L10N-3)', () {
    testWidgets('header actions localize favorite labels in zh/en', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiActionButtons(
            isLocalFavorite: false,
            isCopied: false,
            onToggleFavorite: () {},
            onShareTapped: () {},
          ),
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiActionButtons(
            isLocalFavorite: true,
            isCopied: false,
            onToggleFavorite: () {},
            onShareTapped: () {},
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Favorited'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('collection stats row localizes counts and action', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiCollectionStatsRow(
            collection: const {'wish': 10, 'doing': 3, 'dropped': 1},
            isLocalFavorite: false,
            onToggleFavorite: () {},
          ),
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('10 收藏 / 3 在看 / 1 抛弃'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: SizedBox(
            width: 360,
            child: BangumiCollectionStatsRow(
              collection: const {'wish': 10, 'doing': 3, 'dropped': 1},
              isLocalFavorite: true,
              onToggleFavorite: () {},
            ),
          ),
        ),
        locale: const Locale('en'),
      );
      expect(
        find.text('10 wish / 3 watching / 1 dropped'),
        findsOneWidget,
      );
      expect(find.text('Favorited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rating card localizes votes, rank, and collection buckets', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiRatingCard(
            rating: const {'score': 8.5, 'total': 1200, 'rank': 42},
            collection: const {'wish': 5, 'doing': 2, 'dropped': 0},
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('1200 votes'), findsOneWidget);
      expect(find.text('Ranked #42'), findsOneWidget);
      expect(find.text('Wish'), findsOneWidget);
      expect(find.text('Watching'), findsOneWidget);
      expect(find.text('Dropped'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiRatingRow(
            rating: const {'score': 8.5, 'total': 1200, 'rank': 42},
          ),
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('1200 人评 | #42'), findsOneWidget);
    });

    testWidgets('placeholder section localizes loading lines', (tester) async {
      await pumpLocalizedWidget(
        tester,
        const Scaffold(
          body: PlaceholderSection(
            title: 'Characters',
            icon: Icons.person,
            isDarkBg: true,
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Loading Characters...'), findsOneWidget);
      expect(find.text('(Coming Soon)'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        const Scaffold(
          body: PlaceholderSection(
            title: '角色',
            icon: Icons.person,
            isDarkBg: true,
          ),
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('正在加载角色...'), findsOneWidget);
      expect(find.text('（即将推出）'), findsOneWidget);
    });

    testWidgets('summary toggle and infobox controls localize', (tester) async {
      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiSummarySection(
            summary: 'hello',
            showOriginal: false,
            hasBothTranslationAndOriginal: true,
            onToggle: () {},
            isDarkBg: true,
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Tap to show original'), findsOneWidget);

      await pumpLocalizedWidget(
        tester,
        Scaffold(
          body: BangumiInfoBoxList(
            infobox: List.generate(
              8,
              (i) => {'key': 'k$i', 'value': 'v$i'},
            ),
            isExpanded: false,
            onToggleExpanded: () {},
            isDarkBg: true,
            personIdMap: const {},
            onPersonTap: (_) {},
          ),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Information'), findsOneWidget);
      expect(find.text('Expand'), findsOneWidget);
      expect(
        find.text('2 more items — tap Expand for full info'),
        findsOneWidget,
      );
    });
  });
}
