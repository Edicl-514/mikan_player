// Phase 4 / Package D focused widget tests for the extracted
// `SitesSection` widget.
//
// No network, no WebView, no media player — all data passed via constructor.
// Test instances use unknown `site` keys so `siteIconAssetPath` returns null
// and `_SiteIcon` returns `Icons.public` directly (no `Image.asset` decode).
//
// After L10N-3, kind badges resolve via AppLocalizations, so the widget tree
// is pumped through `pumpLocalizedWidget`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/sites_section.dart';

import '../../../../support/localized_widget_tester.dart';

BangumiDataSiteEntry _site({
  String site = 'unknown',
  String title = '',
  String url = '',
  String kind = 'info',
  String? comment,
}) => BangumiDataSiteEntry(
  site: site,
  title: title,
  url: url,
  kind: kind,
  comment: comment,
);

Widget _buildSectionTitleStub(String text, bool isDarkBg) => Text(
  'SECTION_TITLE:$text',
  style: TextStyle(color: isDarkBg ? Colors.white : Colors.black87),
);

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<BangumiDataSiteEntry> sites,
  required Widget sectionTitle,
  required bool isDarkBg,
  void Function(BangumiDataSiteEntry site)? onSiteTap,
  Locale locale = const Locale('zh'),
}) async {
  await pumpLocalizedWidget(
    tester,
    Scaffold(
      body: SitesSection(
        sites: sites,
        isDarkBg: isDarkBg,
        sectionTitle: sectionTitle,
        scrollController: ScrollController(),
        onSiteTap: onSiteTap ?? (_) {},
      ),
    ),
    locale: locale,
  );
}

void main() {
  group('SitesSection', () {
    testWidgets('empty state renders nothing (SizedBox.shrink)', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        sites: const [],
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
      );

      // The widget returns SizedBox.shrink BEFORE building the Column, so the
      // section-title stub is not inserted into the tree. Matches the page's
      // `if (_sites == null || _sites!.isEmpty) return SizedBox.shrink()`.
      expect(find.text('SECTION_TITLE:站'), findsNothing);
    });

    testWidgets('populated state renders all site titles', (tester) async {
      final sites = [
        _site(site: 'unknown_a', title: 'Site One'),
        _site(site: 'unknown_b', title: 'Site Two'),
        _site(site: 'unknown_c', title: 'Site Three'),
      ];

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
      );

      expect(find.text('SECTION_TITLE:站'), findsOneWidget);
      expect(find.text('Site One'), findsOneWidget);
      expect(find.text('Site Two'), findsOneWidget);
      expect(find.text('Site Three'), findsOneWidget);
    });

    testWidgets('kind badge labels render for known and unknown kinds', (
      tester,
    ) async {
      final sites = [
        _site(site: 'unknown_a', title: 'A', kind: 'onair'),
        _site(site: 'unknown_b', title: 'B', kind: 'info'),
        _site(site: 'unknown_c', title: 'C', kind: 'resource'),
        _site(site: 'unknown_d', title: 'D', kind: 'unknown'),
      ];

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
        locale: const Locale('zh'),
      );

      expect(find.text('放送'), findsOneWidget);
      expect(find.text('资料'), findsOneWidget);
      expect(find.text('资源'), findsOneWidget);
      expect(find.text('unknown'), findsOneWidget);

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
        locale: const Locale('en'),
      );

      expect(find.text('On air'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Resource'), findsOneWidget);
      expect(find.text('unknown'), findsOneWidget);
    });

    testWidgets('tap forwards the right site to onSiteTap', (tester) async {
      final sites = [
        _site(site: 'unknown_a', title: 'Tap First', url: 'https://first'),
        _site(site: 'unknown_b', title: 'Tap Second', url: 'https://second'),
      ];
      BangumiDataSiteEntry? captured;

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
        onSiteTap: (site) => captured = site,
      );

      await tester.tap(find.text('Tap Second'));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.title, 'Tap Second');
      expect(captured!.url, 'https://second');
    });

    testWidgets('isDarkBg true renders without exception', (tester) async {
      final sites = [_site(site: 'unknown_a', title: 'Dark', kind: 'info')];

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: true,
        sectionTitle: _buildSectionTitleStub('站', true),
      );

      expect(find.text('SECTION_TITLE:站'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('populated case wires a Scrollbar', (tester) async {
      final sites = [_site(site: 'unknown_a', title: 'One')];

      await _pumpSection(
        tester,
        sites: sites,
        isDarkBg: false,
        sectionTitle: _buildSectionTitleStub('站', false),
      );

      expect(find.byType(Scrollbar), findsOneWidget);
    });
  });
}
