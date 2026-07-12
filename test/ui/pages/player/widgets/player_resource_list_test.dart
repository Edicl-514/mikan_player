// Phase 2 / R2 focused widget tests for the extracted `BtResourceList`
// widget.
//
// No network, no WebView, no media player, no platform channels — all data and
// callbacks passed via constructor. `BtResource` view-models are built directly
// via the const constructor (no mikan/dmhy bindings needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/pages/player/widgets/bt_resource.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_resource_list.dart';

BtResource _res({
  String title = 't',
  String magnet =
      'magnet:?xt=urn:btih:0000000000000000000000000000000000000000',
  String size = '1.0GB',
  String time = '2024-01-01',
  int? episode,
}) => BtResource(
  title: title,
  magnet: magnet,
  size: size,
  time: time,
  episode: episode,
);

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

BtResourceList _list({
  required List<BtResource> resources,
  bool isExpanded = true,
  bool isLoading = false,
  bool hasError = false,
  String? loadingMagnet,
  bool isPlayBlocked = false,
  VoidCallback? onRetrySearch,
  void Function(BtResource)? onCopyMagnet,
  void Function(BtResource)? onDownload,
  void Function(BtResource)? onPlay,
}) => BtResourceList(
  resources: resources,
  isExpanded: isExpanded,
  isLoading: isLoading,
  hasError: hasError,
  loadingMagnet: loadingMagnet,
  isPlayBlocked: isPlayBlocked,
  onRetrySearch: onRetrySearch ?? () {},
  onCopyMagnet: onCopyMagnet ?? (_) {},
  onDownload: onDownload ?? (_) {},
  onPlay: onPlay ?? (_) {},
);

void main() {
  group('BtResourceList', () {
    testWidgets(
      'isExpanded false renders a single SizedBox.shrink and no content',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_list(resources: const [], isExpanded: false)),
        );

        expect(
          find.descendant(
            of: find.byType(BtResourceList),
            matching: find.byType(SizedBox),
          ),
          findsOneWidget,
        );
        expect(find.text('正在搜索BT源...'), findsNothing);
        expect(find.text('尚未开始搜索BT源'), findsNothing);
        expect(find.text('搜索BT源'), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BtResourceList),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'empty + isLoading true renders only SizedBox.shrink (loader in tab)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(_list(resources: const [], isLoading: true)),
        );

        expect(
          find.descendant(
            of: find.byType(BtResourceList),
            matching: find.byType(SizedBox),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(BtResourceList),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(find.text('正在搜索BT源...'), findsNothing);
        expect(find.text('尚未开始搜索BT源'), findsNothing);
      },
    );

    testWidgets(
      'empty + not loading + no error renders the empty state and the '
      'search ElevatedButton; tapping the button fires onRetrySearch',
      (tester) async {
        var fired = 0;
        await tester.pumpWidget(
          _wrap(
            _list(
              resources: const [],
              isLoading: false,
              hasError: false,
              onRetrySearch: () => fired++,
            ),
          ),
        );

        // Status bar AND empty card both render "尚未开始搜索BT源".
        expect(find.text('尚未开始搜索BT源'), findsNWidgets(2));
        expect(find.text('点击下方按钮开始搜索'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, '搜索BT源'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, '搜索BT源'));
        await tester.pump();

        expect(fired, 1);
      },
    );

    testWidgets('empty + hasError true shows "BT搜索失败" in the status bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_list(resources: const [], hasError: true, isLoading: false)),
      );

      expect(find.text('BT搜索失败'), findsOneWidget);
      // The empty card still renders its fixed message.
      expect(find.text('尚未开始搜索BT源'), findsOneWidget);
    });

    testWidgets('populated renders all titles, status bar, sizes and times', (
      tester,
    ) async {
      final resources = [
        _res(title: 'Title A', size: '1.0GB', time: 't1', magnet: 'm1'),
        _res(title: 'Title B', size: '2.0GB', time: 't2', magnet: 'm2'),
        _res(title: 'Title C', size: '3.0GB', time: 't3', magnet: 'm3'),
      ];

      await tester.pumpWidget(_wrap(_list(resources: resources)));

      expect(find.text('Title A'), findsOneWidget);
      expect(find.text('Title B'), findsOneWidget);
      expect(find.text('Title C'), findsOneWidget);
      expect(find.text('已找到 3 个BT源'), findsOneWidget);
      expect(find.text('1.0GB'), findsOneWidget);
      expect(find.text('2.0GB'), findsOneWidget);
      expect(find.text('3.0GB'), findsOneWidget);
      expect(find.text('t1'), findsOneWidget);
      expect(find.text('t2'), findsOneWidget);
      expect(find.text('t3'), findsOneWidget);
    });

    testWidgets(
      'loadingMagnet on one card shows "加载中" + spinner; other card shows '
      '"播放"',
      (tester) async {
        final resources = [
          _res(title: 'Loading', magnet: 'm-loading'),
          _res(title: 'Ready', magnet: 'm-ready'),
        ];

        await tester.pumpWidget(
          _wrap(
            _list(
              resources: resources,
              loadingMagnet: 'm-loading',
              isPlayBlocked: false,
            ),
          ),
        );

        expect(find.text('加载中'), findsOneWidget);
        expect(find.text('播放'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BtResourceList),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      },
    );

    testWidgets(
      'isPlayBlocked true (loadingMagnet null) disables play taps; both '
      'cards show play_arrow',
      (tester) async {
        var playCalls = 0;
        final resources = [
          _res(title: 'A', magnet: 'm1'),
          _res(title: 'B', magnet: 'm2'),
        ];

        await tester.pumpWidget(
          _wrap(
            _list(
              resources: resources,
              isPlayBlocked: true,
              onPlay: (_) => playCalls++,
            ),
          ),
        );

        expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
        expect(find.text('播放'), findsNWidgets(2));

        await tester.tap(find.text('播放').first);
        await tester.pump();

        expect(playCalls, 0);
      },
    );

    testWidgets('callback forwarding: 复制/下载/播放 tap the second card and capture '
        'the right BtResource', (tester) async {
      BtResource? copied;
      BtResource? downloaded;
      BtResource? played;

      final resources = [
        _res(title: 'First', magnet: 'm-first'),
        _res(title: 'Second', magnet: 'm-second'),
      ];

      await tester.pumpWidget(
        _wrap(
          _list(
            resources: resources,
            isPlayBlocked: false,
            onCopyMagnet: (r) => copied = r,
            onDownload: (r) => downloaded = r,
            onPlay: (r) => played = r,
          ),
        ),
      );

      await tester.tap(find.text('复制').at(1));
      await tester.pump();
      expect(copied?.magnet, 'm-second');

      await tester.tap(find.text('下载').at(1));
      await tester.pump();
      expect(downloaded?.magnet, 'm-second');

      await tester.tap(find.text('播放').at(1));
      await tester.pump();
      expect(played?.magnet, 'm-second');
    });

    testWidgets('dark-theme smoke renders populated titles without throwing', (
      tester,
    ) async {
      final resources = [_res(title: 'DarkMode Title', magnet: 'm-d')];

      await tester.pumpWidget(
        _wrap(
          _list(resources: resources, isPlayBlocked: false),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('DarkMode Title'), findsOneWidget);
      expect(find.text('已找到 1 个BT源'), findsOneWidget);
    });

    testWidgets(
      'renders the R1 tag chips for a title with resolution/codec/subLang/'
      'subType markers',
      (tester) async {
        final resources = [
          _res(title: '[X] Show [01][1080p][HEVC][简日内嵌]', magnet: 'm-t'),
        ];

        await tester.pumpWidget(
          _wrap(_list(resources: resources, isPlayBlocked: false)),
        );

        expect(find.text('1080P'), findsOneWidget);
        expect(find.text('HEVC'), findsOneWidget);
        expect(find.text('简日'), findsOneWidget);
        expect(find.text('内嵌'), findsOneWidget);
      },
    );
  });
}
