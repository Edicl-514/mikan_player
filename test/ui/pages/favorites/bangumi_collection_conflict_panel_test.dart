import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/bangumi_user_collection.dart';
import 'package:mikan_player/models/local_favorite.dart';
import 'package:mikan_player/services/bangumi_collection_merge.dart';
import 'package:mikan_player/services/bangumi_collection_sync_service.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/favorites/bangumi_collection_conflict_panel.dart';

import '../../../support/localized_widget_tester.dart';

void main() {
  testWidgets('requires an explicit choice for every conflicting field', (
    tester,
  ) async {
    final local = LocalFavorite.create(
      bangumiId: 1,
      title: 'Show',
      coverUrl: '',
      score: 7,
      type: 3,
      rate: 9,
      comment: 'local',
      tags: const [],
      private: false,
    );
    final remote = BangumiUserCollection(
      date: '2026-07-28T00:00:00Z',
      comment: 'remote',
      tags: const [],
      subject: BangumiUserCollectionSubject(
        id: 1,
        name: 'Show',
        nameCn: '',
        shortSummary: '',
        score: 7,
        images: const BangumiImages(
          small: '',
          grid: '',
          large: '',
          medium: '',
          common: '',
        ),
        eps: 12,
        collectionTotal: 1,
      ),
      subjectId: 1,
      type: 3,
      rate: 2,
      private: false,
    );
    final plan = mergeCollectionSubject(
      subjectId: 1,
      local: const BangumiCollectionSnapshot(
        type: 3,
        rate: 9,
        comment: 'local',
        tags: [],
        private: false,
      ),
      remote: const BangumiCollectionSnapshot(
        type: 3,
        rate: 2,
        comment: 'remote',
        tags: [],
        private: false,
      ),
      baseline: const BangumiCollectionSnapshot(
        type: 3,
        rate: 5,
        comment: 'base',
        tags: [],
        private: false,
      ),
      hadBaseline: true,
    );
    Map<int, BangumiCollectionResolution>? submitted;

    await pumpLocalizedWidget(
      tester,
      Scaffold(
        body: SizedBox(
          width: 600,
          height: 700,
          child: BangumiCollectionConflictPanel(
            conflicts: [
              BangumiCollectionConflict(
                local: local,
                bangumi: remote,
                plan: plan,
              ),
            ],
            statusLabel: (type) => '$type',
            onResolve: (resolutions) async => submitted = resolutions,
            isResolving: false,
          ),
        ),
      ),
    );
    final l10n = localizedOf(tester);
    FilledButton submitButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    expect(submitButton().onPressed, isNull);

    await tester.tap(find.text(l10n.collectionKeepLocal).first);
    await tester.pump();
    expect(submitButton().onPressed, isNull);

    final secondRemote = find.text(l10n.collectionKeepBangumi).last;
    await tester.ensureVisible(secondRemote);
    await tester.tap(secondRemote);
    await tester.pump();
    expect(submitButton().onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(submitted, isNotNull);
    expect(submitted![1]!.fields.length, 2);
  });
}
