// Shared test helpers for the i18n + stability plan (work package `F-0`).
//
// Tests that need a localized `MaterialApp` should pump widgets through
// [pumpLocalizedWidget] so the delegates mirror the production app defined in
// `lib/main.dart`. New work packages must NOT roll their own
// `localizationsDelegates` list — every drift in delegates here would silently
// change the locale-loading semantics for downstream widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Locales covered by the tests. Mirrors
/// [AppLocalizations.supportedLocales] minus ordering — keep this list in
/// sync with `lib/gen/app_localizations.dart` whenever a new locale is added.
const List<Locale> kTestSupportedLocales = <Locale>[
  Locale('en'),
  Locale('zh'),
];

/// Localizations delegates to inject in test [MaterialApp]s. Identical to the
/// production list in `lib/main.dart` so widget trees resolve the same
/// `GlobalMaterialLocalizations` / `GlobalWidgetsLocalizations` /
/// `GlobalCupertinoLocalizations` flavor at runtime.
const List<LocalizationsDelegate<dynamic>> kTestLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// Pumps [child] inside a [MaterialApp] wired with the production localization
/// delegates and the supplied [locale].
///
/// The supplied [child] becomes [MaterialApp.home], so a [Navigator] and a
/// [Directionality] are available right away. After [WidgetTester.pumpWidget]
/// we issue one extra [WidgetTester.pump] to let the asynchronous
/// `GlobalMaterialLocalizations` delegate publish its values for the first
/// frame; synchronous delegates (our generated [AppLocalizations.delegate])
/// are already available on the first build.
///
/// Set [skipInitialPump] to `true` when the test needs to assert on the
/// loading state before localizations resolve.
///
/// Pass [locale] to switch between supported locales. Use [kTestSupportedLocales]
/// to enumerate the supported set programmatically.
Future<void> pumpLocalizedWidget(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('zh'),
  bool skipInitialPump = false,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.light,
  String? title,
  Iterable<Locale>? supportedLocales,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales:
          supportedLocales?.toList() ?? kTestSupportedLocales,
      localizationsDelegates: kTestLocalizationsDelegates,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      title: title,
      home: child,
    ),
  );
  if (!skipInitialPump) {
    await tester.pump();
  }
}

/// Returns the [AppLocalizations] currently resolved on the rendered tree.
///
/// [finder] defaults to `find.byType(Navigator).first` — i.e. the navigator
/// injected by [pumpLocalizedWidget]. Pass an explicit [finder] when the test
/// wants the [BuildContext] of a specific widget (for example when asserting
/// on `AppLocalizations.of(context).x` from within a custom page).
AppLocalizations localizedOf(
  WidgetTester tester, [
  Finder? finder,
]) {
  final target = finder ?? find.byType(Navigator).first;
  final element = tester.element(target);
  // `nullable-getter: false` in l10n.yaml makes `AppLocalizations.of` return
  // a non-nullable instance and throw a FlutterError when no delegate resolved.
  // Surface the streaming-friendly hint by catching and rethrowing.
  try {
    return AppLocalizations.of(element);
  } catch (e) {
    throw StateError(
      'AppLocalizations is not available in the tree at $target. Did you pump '
      'the widget via pumpLocalizedWidget? Original error: $e',
    );
  }
}
