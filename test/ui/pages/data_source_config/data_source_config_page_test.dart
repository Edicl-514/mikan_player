// Widget + i18n smoke tests for `DataSourceConfigPage` (L10N-1A).
//
// Scope: the page is a 1300+ line config form whose only `AppLocalizations`
// consumer is the 100+ labels/helper/validator/SnackBar/section-title
// surface. The Rust FRB `addSourceConfig` / `updateSingleSourceConfig` calls
// inside `_save` are not exercised here (they require a running native bridge
// and are covered by integration tests downstream); these tests assert the
// localized surface in both `zh` and `en`, the AppBar title swap between
// "new" and "edit" modes, the localized validator messages, and the empty
// "Not configured" preview fallback. Per `i18n_workflow.md` §1 the page is
// always pumped through `pumpLocalizedWidget` so the delegates mirror
// `lib/main.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/data_source_config_page.dart';

import '../../../support/localized_widget_tester.dart';

SourceState _existingSource() {
  return const SourceState(
    name: 'sample-source',
    description: 'desc',
    iconUrl: 'https://example/icon.png',
    tier: 1,
    defaultSubtitleLanguage: 'CHS',
    defaultResolution: '1080P',
    searchUrl: 'https://example.com/search?wd={keyword}',
    searchConfigJson: r'''{
      "searchUrl": "https://example.com/search?wd={keyword}",
      "subjectFormatId": "a",
      "selectorSubjectFormatA": {
        "selectLists": ".subject",
        "preferShorterName": true
      },
      "channelFormatId": "no-channel",
      "selectorChannelFormatNoChannel": {
        "selectEpisodes": ".episode",
        "selectEpisodeLinks": "a"
      },
      "matchVideo": {
        "matchVideoUrl": "(?<v>https?://.+)",
        "enableNestedUrl": true,
        "matchNestedUrl": "$^"
      }
    }''',
    captchaConfigJson: null,
    enabled: true,
    isManual: true,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  SourceState? source,
  Locale locale = const Locale('zh'),
  SourceConfigPersistCallback? onCreateSourceConfig,
  SourceConfigPersistCallback? onUpdateSourceConfig,
}) async {
  await pumpLocalizedWidget(
    tester,
    DataSourceConfigPage(
      source: source,
      onCreateSourceConfig: onCreateSourceConfig,
      onUpdateSourceConfig: onUpdateSourceConfig,
    ),
    locale: locale,
  );
  // Two pumps: first lets the async localizations resolve, the second flushes
  // the FormField error text once validators run.
  await tester.pump();
}

void main() {
  group('DataSourceConfigPage i18n (L10N-1A)', () {
    testWidgets('zh: new mode shows the localized section titles and form '
        'labels', (tester) async {
      await _pumpPage(tester, locale: const Locale('zh'));

      expect(find.text('新建数据源'), findsOneWidget);
      expect(find.text('基本信息'), findsOneWidget);
      expect(find.text('步骤 1：搜索条目'), findsOneWidget);
      expect(find.text('步骤 2：解析线路和剧集'), findsOneWidget);
      expect(find.text('步骤 3：匹配视频'), findsOneWidget);
      expect(find.text('验证码'), findsOneWidget);
      expect(find.text('生成的 JSON'), findsOneWidget);

      // Spot-check a handful of form labels. The resolution / subtitle
      // dropdowns default to "1080P" / "CHS" in new mode, so their empty
      // option label "不标记" is not rendered until the user clears them.
      expect(find.text('名称'), findsOneWidget);
      expect(find.text('优先级'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('标记分辨率'), findsOneWidget);
      expect(find.text('标记字幕语言'), findsOneWidget);
      expect(find.text('不标记'), findsNothing);
    });

    testWidgets('en: new mode shows the localized section titles and form '
        'labels', (tester) async {
      await _pumpPage(tester, locale: const Locale('en'));

      expect(find.text('New data source'), findsOneWidget);
      expect(find.text('Basic information'), findsOneWidget);
      expect(find.text('Step 1: search subjects'), findsOneWidget);
      expect(find.text('Step 2: parse channels and episodes'), findsOneWidget);
      expect(find.text('Step 3: match video'), findsOneWidget);
      expect(find.text('Captcha'), findsOneWidget);
      expect(find.text('Generated JSON'), findsOneWidget);

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('Tag resolution'), findsOneWidget);
      expect(find.text('Tag subtitle language'), findsOneWidget);
      expect(find.text('Not tagged'), findsNothing);
    });

    testWidgets('edit mode swaps the AppBar title to "{name}"', (tester) async {
      await _pumpPage(
        tester,
        source: _existingSource(),
        locale: const Locale('en'),
      );

      expect(find.text('Edit: sample-source'), findsOneWidget);
    });

    testWidgets('edit mode in zh shows the localized "配置: {name}" title', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        source: _existingSource(),
        locale: const Locale('zh'),
      );

      expect(find.text('配置: sample-source'), findsOneWidget);
    });

    testWidgets('save tooltip is localized', (tester) async {
      await _pumpPage(tester, locale: const Locale('en'));
      expect(
        find.byTooltip('Save'),
        findsOneWidget,
        reason: 'AppBar IconButton tooltip must follow the active locale',
      );

      await _pumpPage(tester, locale: const Locale('zh'));
      expect(find.byTooltip('保存'), findsOneWidget);
    });

    testWidgets('required validator shows localized message in zh/en', (
      tester,
    ) async {
      // Leave "Name" empty and tap save — the validator should produce a
      // localized error message. We do not need the save itself to succeed
      // (it would call FRB), only that validation runs and emits the right
      // text.
      await _pumpPage(tester, locale: const Locale('zh'));
      await tester.tap(find.byTooltip('保存'));
      await tester.pump();

      expect(find.text('必填'), findsWidgets);

      // Re-render in en and re-trigger validation.
      await _pumpPage(tester, locale: const Locale('en'));
      await tester.tap(find.byTooltip('Save'));
      await tester.pump();

      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('integer validator shows localized message when text is not '
        'an integer', (tester) async {
      await _pumpPage(tester, locale: const Locale('zh'));
      // Tier is the first integer-only field on the page.
      final tierFinder = find.widgetWithText(TextFormField, '优先级');
      expect(tierFinder, findsOneWidget);
      await tester.enterText(tierFinder, 'abc');
      await tester.tap(find.byTooltip('保存'));
      await tester.pump();
      expect(find.text('请输入整数'), findsWidgets);
    });

    testWidgets('integer validator rejects values outside Rust i32 range', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        source: _existingSource(),
        locale: const Locale('en'),
      );
      final tierFinder = find.widgetWithText(TextFormField, 'Priority');
      await tester.enterText(tierFinder, '2147483648');
      await tester.tap(find.byTooltip('Save'));
      await tester.pump();

      expect(
        find.text('Enter an integer from -2147483648 to 2147483647'),
        findsWidgets,
      );
    });

    testWidgets('save success uses the persistence callback with a valid '
        'configuration', (tester) async {
      SourceConfigUpdate? persisted;
      await _pumpPage(
        tester,
        source: _existingSource(),
        locale: const Locale('en'),
        onUpdateSourceConfig: (update) async => persisted = update,
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(persisted, isNotNull);
      expect(persisted!.name, 'sample-source');
      expect(persisted!.tier, 1);
    });

    testWidgets('save failure shows the localized error message', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        source: _existingSource(),
        locale: const Locale('en'),
        onUpdateSourceConfig: (update) async {
          throw StateError('simulated persistence failure');
        },
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text('Save failed: Bad state: simulated persistence failure'),
        findsOneWidget,
      );
    });

    testWidgets('preview section shows the localized "Not configured" '
        'placeholder when captcha is unset', (tester) async {
      await _pumpPage(tester, locale: const Locale('en'));
      // The form is taller than the test viewport — drag the outer ListView
      // until the preview section title is on-screen, then expand it so the
      // captcha placeholder is built.
      await tester.dragUntilVisible(
        find.text('Generated JSON'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();
      await tester.tap(find.text('Generated JSON'));
      await tester.pump();
      expect(find.text('Not configured'), findsOneWidget);
    });

    testWidgets('localizedOf exposes the active locale', (tester) async {
      await _pumpPage(tester, locale: const Locale('en'));
      final l10n = localizedOf(tester);
      expect(l10n.dataSourceConfigNew, 'New data source');
      expect(l10n.dataSourceConfigSaved, 'Configuration saved');
      expect(l10n.dataSourceConfigRequired, 'Required');
    });
  });
}
