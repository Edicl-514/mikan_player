import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/characters_section.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

import '../../../../support/localized_widget_tester.dart';

BangumiCharacter _character({
  int id = 1,
  String name = '',
  String roleName = '主角',
  String? largeImage,
  String? actorName,
}) => BangumiCharacter(
  id: id,
  name: name,
  roleName: roleName,
  images: largeImage != null
      ? BangumiImages(
          small: largeImage,
          grid: largeImage,
          large: largeImage,
          medium: largeImage,
          common: largeImage,
        )
      : null,
  actors: actorName != null
      ? [BangumiActor(id: 100, name: actorName)]
      : const [],
);

Widget _loadingStub(BuildContext context) => const Text('LOADING_STUB');

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<BangumiCharacter> characters,
  required bool isLoading,
  required bool isDarkBg,
  Map<String, int> personIdMap = const {},
  void Function(int, {String? characterName, String? heroImageUrl})?
  onCharacterTap,
  void Function(int, {String? personName})? onPersonTap,
  Locale locale = const Locale('zh'),
}) async {
  await pumpLocalizedWidget(
    tester,
    Scaffold(
      body: CharactersSection(
        characters: characters,
        isLoading: isLoading,
        isDarkBg: isDarkBg,
        enableCharacterHero: true,
        scrollController: ScrollController(),
        onCharacterTap: onCharacterTap ?? (_, {characterName, heroImageUrl}) {},
        onPersonTap: onPersonTap ?? (_, {personName}) {},
        personIdMap: personIdMap,
        loadingPlaceholder: _loadingStub,
        sectionTitle: '角色',
      ),
    ),
    locale: locale,
  );
}

void main() {
  group('CharactersSection', () {
    testWidgets('loading state renders loadingPlaceholder', (tester) async {
      await _pumpSection(
        tester,
        characters: const [],
        isLoading: true,
        isDarkBg: false,
      );

      expect(find.text('LOADING_STUB'), findsOneWidget);
    });

    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        characters: const [],
        isLoading: false,
        isDarkBg: false,
      );

      expect(find.text('LOADING_STUB'), findsNothing);
      expect(find.text('角色'), findsNothing);
    });

    testWidgets('populated state renders character cards and role badges', (
      tester,
    ) async {
      final characters = [
        _character(
          id: 1,
          name: 'Character One',
          roleName: '主角',
          actorName: 'Actor One',
        ),
        _character(
          id: 2,
          name: 'Character Two',
          roleName: '配角',
          actorName: 'Actor Two',
        ),
      ];

      await _pumpSection(
        tester,
        characters: characters,
        isLoading: false,
        isDarkBg: false,
      );

      expect(find.text('角色'), findsOneWidget);
      expect(find.text('Character One'), findsOneWidget);
      expect(find.text('Character Two'), findsOneWidget);
      expect(find.text('主角'), findsOneWidget);
      expect(find.text('配角'), findsOneWidget);
      expect(find.text('Actor One'), findsOneWidget);
      expect(find.text('Actor Two'), findsOneWidget);
      expect(find.byType(StableThumbScrollbar), findsOneWidget);
    });

    testWidgets('character tap dispatches callback', (tester) async {
      int? tappedId;
      String? tappedName;
      final characters = [
        _character(id: 42, name: 'Tappable Hero', roleName: '主角'),
      ];

      await _pumpSection(
        tester,
        characters: characters,
        isLoading: false,
        isDarkBg: false,
        onCharacterTap: (id, {characterName, heroImageUrl}) {
          tappedId = id;
          tappedName = characterName;
        },
      );

      await tester.tap(find.text('Tappable Hero'));
      await tester.pump();

      expect(tappedId, 42);
      expect(tappedName, 'Tappable Hero');
    });

    testWidgets('CV name tap with personIdMap dispatches callback', (
      tester,
    ) async {
      int? tappedPersonId;
      String? tappedPersonName;
      final characters = [
        _character(id: 1, name: 'Hero', roleName: '主角', actorName: 'Famous CV'),
      ];

      await _pumpSection(
        tester,
        characters: characters,
        isLoading: false,
        isDarkBg: false,
        personIdMap: {'Famous CV': 888},
        onPersonTap: (personId, {personName}) {
          tappedPersonId = personId;
          tappedPersonName = personName;
        },
      );

      await tester.tap(find.text('Famous CV'));
      await tester.pump();

      expect(tappedPersonId, 888);
      expect(tappedPersonName, 'Famous CV');
    });
  });
}
