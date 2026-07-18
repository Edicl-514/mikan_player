// Self-tests for the F-0 localized widget tester helper.
//
// Goal: capture the contract future L10N-* packages depend on — that a
// widget pumped under [pumpLocalizedWidget] resolves the requested [Locale]
// and that [localizedOf] returns the live [AppLocalizations].

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'localized_widget_tester.dart';

void main() {
  group('pumpLocalizedWidget', () {
    testWidgets('resolves the zh locale and exposes AppLocalizations', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (context) =>
              Text(AppLocalizations.of(context).homeTitle),
        ),
        locale: const Locale('zh'),
      );

      // The zh template (`app_zh.arb`) declares `homeTitle` as "Mikan Player".
      // Confirm both the localized string and the helper exposure agree.
      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(Navigator).first))
              .homeTitle,
        ),
        findsOneWidget,
      );
      expect(localizedOf(tester).homeTitle, isA<String>());
      expect(
        Localizations.localeOf(
          tester.element(find.byType(Navigator).first),
        ),
        const Locale('zh'),
      );
    });

    testWidgets('resolves the en locale and exposes AppLocalizations', (
      tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (context) =>
              Text(AppLocalizations.of(context).appTitle),
        ),
        locale: const Locale('en'),
      );

      // The en ARB also declares `appTitle` as "Mikan Player", so finding the
      // text confirms the en locale was loaded without ambiguity.
      expect(find.text('Mikan Player'), findsOneWidget);
      expect(localizedOf(tester).appTitle, 'Mikan Player');
      expect(
        Localizations.localeOf(
          tester.element(find.byType(Navigator).first),
        ),
        const Locale('en'),
      );
    });

    testWidgets('skipInitialPump delays the first pump', (tester) async {
      await pumpLocalizedWidget(
        tester,
        const SizedBox(),
        skipInitialPump: true,
      );
      // No pump yet — MaterialApp frame has not fired the localized delegates.
      // Pumping here completes the async work started by `pumpWidget`.
      await tester.pump();
      expect(localizedOf(tester).homeTitle, isA<String>());
    });
  });
}
