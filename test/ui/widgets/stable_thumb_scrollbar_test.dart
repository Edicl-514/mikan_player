import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

/// A scroll view whose extent grows once, the first time it is scrolled.
///
/// This reproduces what lazily-built content does mid-drag. `SliverList` and
/// `ListView.builder` extrapolate `maxScrollExtent` from the average extent of
/// the children currently realized, so dragging realizes new children and
/// revises the estimate. Growing a spacer on first scroll produces the same
/// observable event — a larger `maxScrollExtent` reported part-way through a
/// drag — without depending on the estimator's heuristics.
class _GrowingScrollView extends StatefulWidget {
  const _GrowingScrollView({
    super.key,
    required this.controller,
    required this.growBy,
    this.axis = Axis.vertical,
  });

  final ScrollController controller;
  final double growBy;
  final Axis axis;

  @override
  State<_GrowingScrollView> createState() => _GrowingScrollViewState();
}

class _GrowingScrollViewState extends State<_GrowingScrollView> {
  static const double baseExtent = 4000;
  bool _grown = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        if (!_grown && widget.growBy > 0) {
          _grown = true;
          // Deferred: growing during notification dispatch would mutate layout
          // inside the scroll's own frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        return false;
      },
      child: ListView(
        controller: widget.controller,
        scrollDirection: widget.axis,
        children: [
          SizedBox(
            width: widget.axis == Axis.horizontal
                ? baseExtent + (_grown ? widget.growBy : 0)
                : null,
            height: widget.axis == Axis.vertical
                ? baseExtent + (_grown ? widget.growBy : 0)
                : null,
          ),
        ],
      ),
    );
  }
}

enum _Bar { stable, material }

/// What one stepped thumb drag did.
class _DragTrace {
  _DragTrace({
    required this.offsets,
    required this.maxBefore,
    required this.maxAfter,
  });

  /// Scroll offset sampled before the drag and after every pointer step.
  final List<double> offsets;
  final double maxBefore;
  final double maxAfter;

  /// Scroll travel produced by each individual pointer step.
  List<double> get deltas => [
    for (var i = 1; i < offsets.length; i++) offsets[i] - offsets[i - 1],
  ];
}

Widget _wrap({
  required _Bar bar,
  required ScrollController controller,
  required Widget child,
}) {
  return MaterialApp(
    // The interactive scrollbar under test is desktop-only.
    theme: ThemeData(platform: TargetPlatform.windows),
    home: switch (bar) {
      _Bar.stable => StableThumbScrollbar(
        controller: controller,
        thumbVisibility: true,
        child: child,
      ),
      _Bar.material => Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: child,
      ),
    },
  );
}

/// Drags the thumb down in equal steps, sampling the scroll offset after each.
///
/// The content grows after the first step, so step 1 is measured against the
/// original extent and the later steps against the grown one.
Future<_DragTrace> _dragThumb(
  WidgetTester tester, {
  required _Bar bar,
  required double growBy,
  Axis axis = Axis.vertical,
  double step = 15,
  int steps = 8,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    _wrap(
      bar: bar,
      controller: controller,
      child: _GrowingScrollView(
        key: ValueKey('grow-$growBy'),
        controller: controller,
        growBy: growBy,
        axis: axis,
      ),
    ),
  );
  await tester.pumpAndSettle();

  final maxBefore = controller.position.maxScrollExtent;

  // Grab the thumb near the top of the track, at the right edge where the
  // scrollbar paints.
  final size = tester.getSize(find.byType(ListView));
  final gesture = await tester.startGesture(
    axis == Axis.vertical
        ? Offset(size.width - 4, 20)
        : Offset(20, size.height - 4),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump(const Duration(milliseconds: 20));

  final offsets = <double>[controller.offset];
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(
      axis == Axis.vertical ? Offset(0, step) : Offset(step, 0),
    );
    await tester.pump(const Duration(milliseconds: 16));
    offsets.add(controller.offset);
  }
  final maxAfter = controller.position.maxScrollExtent;

  await gesture.up();
  await tester.pumpAndSettle();

  return _DragTrace(offsets: offsets, maxBefore: maxBefore, maxAfter: maxAfter);
}

void main() {
  group('StableThumbScrollbar', () {
    testWidgets('keeps one constant drag mapping when content grows mid-drag', (
      tester,
    ) async {
      final trace = await _dragThumb(tester, bar: _Bar.stable, growBy: 6000);

      // The scenario is only meaningful if the extent really did change.
      expect(
        trace.maxAfter,
        greaterThan(trace.maxBefore + 1000),
        reason: 'harness should have grown the content mid-drag',
      );

      final deltas = trace.deltas;
      expect(deltas.first, greaterThan(0));
      // Equal pointer steps must produce equal scroll steps throughout: the
      // mapping is pinned for the gesture, so the thumb stays under the
      // pointer instead of being rescaled by the new extent.
      for (final delta in deltas) {
        expect(
          delta,
          moreOrLessEquals(deltas.first, epsilon: 1.0),
          reason: 'pinned mapping should ignore mid-drag extent growth',
        );
      }
    });

    testWidgets(
      'keeps one constant horizontal drag mapping when content grows',
      (tester) async {
        final trace = await _dragThumb(
          tester,
          bar: _Bar.stable,
          growBy: 6000,
          axis: Axis.horizontal,
        );

        expect(trace.maxAfter, greaterThan(trace.maxBefore + 1000));
        final deltas = trace.deltas;
        expect(deltas.first, greaterThan(0));
        for (final delta in deltas) {
          expect(
            delta,
            moreOrLessEquals(deltas.first, epsilon: 1.0),
            reason: 'horizontal mapping should stay pinned mid-drag',
          );
        }
      },
    );

    testWidgets('Material Scrollbar rescales mid-drag in the same scenario', (
      tester,
    ) async {
      final trace = await _dragThumb(tester, bar: _Bar.material, growBy: 6000);

      expect(trace.maxAfter, greaterThan(trace.maxBefore + 1000));

      final deltas = trace.deltas;
      // Documents the framework behavior this widget exists to correct: the
      // same pointer step scrolls a different distance once the extent is
      // revised, which is what makes the thumb jump. If a future Flutter
      // release fixes this upstream, this fails and StableThumbScrollbar can
      // be reconsidered.
      expect(
        deltas.last,
        isNot(moreOrLessEquals(deltas.first, epsilon: 1.0)),
        reason: 'baseline: live-metrics mapping rescales mid-drag',
      );
    });

    testWidgets('drag still reaches the true end of grown content', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          bar: _Bar.stable,
          controller: controller,
          child: _GrowingScrollView(controller: controller, growBy: 6000),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(ListView));
      final gesture = await tester.startGesture(
        Offset(size.width - 4, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      // Enough travel to exhaust the track. Pinning maps the gesture onto the
      // extent captured at press time, so once the content grows past that the
      // remaining distance is covered by the framework's own shrink guard —
      // meaning the end takes more pointer travel to reach than the pinned
      // mapping alone would suggest.
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Pinning is a scrollbar-geometry concern only. The position still
      // clamps against real extents, so the true end stays reachable.
      expect(controller.position.maxScrollExtent, greaterThan(4000));
      expect(controller.offset, controller.position.maxScrollExtent);
    });

    testWidgets('releases the pin when a drag is cancelled', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          bar: _Bar.stable,
          controller: controller,
          child: _GrowingScrollView(controller: controller, growBy: 6000),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(ListView));
      final gesture = await tester.startGesture(
        Offset(size.width - 4, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 16));
      // A cancelled drag never reaches handleThumbPressEnd, so the pin has to
      // be dropped on the scroll-end notification instead.
      await gesture.cancel();
      await tester.pumpAndSettle();

      final grownMax = controller.position.maxScrollExtent;
      expect(grownMax, greaterThan(4000));

      // Back to the top so the thumb is under the grab point again, then drag
      // the whole track. Reaching the end proves the next gesture re-derived
      // its mapping from the settled extent rather than a stale pin.
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      final gesture2 = await tester.startGesture(
        Offset(size.width - 4, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      for (var i = 0; i < 20; i++) {
        await gesture2.moveBy(const Offset(0, 80));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controller.offset, grownMax);
    });
  });

  group('StableThumbScrollBehavior', () {
    // MaterialScrollBehavior.getPlatform reads Theme.of(context).platform.
    Future<void> pumpList(
      WidgetTester tester, {
      Axis axis = Axis.vertical,
      TargetPlatform platform = TargetPlatform.windows,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          scrollBehavior: const StableThumbScrollBehavior(),
          home: ListView(
            scrollDirection: axis,
            children: [
              SizedBox(
                height: axis == Axis.vertical ? 4000 : null,
                width: axis == Axis.horizontal ? 4000 : null,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('installs the scrollbar on desktop vertical scrollables', (
      tester,
    ) async {
      await pumpList(tester);
      expect(find.byType(StableThumbScrollbar), findsOneWidget);
    });

    testWidgets('leaves horizontal scrollables alone', (tester) async {
      await pumpList(tester, axis: Axis.horizontal);
      expect(find.byType(StableThumbScrollbar), findsNothing);
    });

    testWidgets('leaves mobile scrollables alone', (tester) async {
      await pumpList(tester, platform: TargetPlatform.android);
      expect(find.byType(StableThumbScrollbar), findsNothing);
    });
  });
}
