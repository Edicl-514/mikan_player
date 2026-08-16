import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Desktop scrollbar whose thumb keeps following the pointer even when the
/// scroll view's content length changes mid-drag.
///
/// ## The problem
///
/// Flutter maps a thumb drag onto a scroll offset using the *live* scroll
/// metrics, but anchors the drag to the thumb offset captured when the press
/// started (see `RawScrollbarState._getPrimaryDelta`). Both the thumb's length
/// and its track position are re-derived from `maxScrollExtent` on every
/// metrics update:
///
/// * `thumbExtent  = traversableTrack * viewport / (maxScrollExtent + viewport)`
/// * `thumbOffset  = pixels / maxScrollExtent * (traversableTrack - thumbExtent)`
/// * `trackToScroll = maxScrollExtent * trackOffset / (traversableTrack - thumbExtent)`
///
/// So any change to `maxScrollExtent` during a drag rescales the mapping while
/// the drag's anchor stays frozen, and the thumb visibly jumps out from under
/// the pointer — upward or downward depending on whether the content grew or
/// shrank.
///
/// `maxScrollExtent` changes constantly in lazily-built content, which is
/// unavoidable rather than a bug: a `SliverList`/`ListView.builder` cannot know
/// the extent of children it has not laid out yet, so it extrapolates from the
/// average extent of the children currently realized
/// (`SliverMultiBoxAdaptorElement._extrapolateMaxScrollOffset`). Dragging
/// realizes different children, the average shifts, and the estimate is
/// rewritten every frame. Network images that resize as they decode and
/// pagination that appends rows have the same effect.
///
/// ## The fix
///
/// While the thumb is held, pin the extents the painter does its math with to
/// the values captured at press time, leaving `pixels` live so the thumb still
/// tracks the pointer. The mapping stays a single constant linear function for
/// the whole gesture, which is what the drag anchor already assumes — and it
/// matches how native Windows scrollbars behave, where the thumb does not
/// resize mid-drag either.
///
/// Pinning only affects the scrollbar's own geometry. The real [ScrollPosition]
/// is untouched, so lazy building, pagination and overscroll clamping continue
/// to use true extents: [RawScrollbarState] clamps each drag step against
/// `position.maxScrollExtent`, so a drag to the end of the track still lands at
/// the real end of the content. On release the pin is dropped and the thumb
/// resizes to the settled content in one step.
class StableThumbScrollbar extends RawScrollbar {
  const StableThumbScrollbar({
    super.key,
    required super.child,
    super.controller,
    super.thumbVisibility,
    super.thickness,
    super.radius,
    super.notificationPredicate,
    super.scrollbarOrientation,
    super.interactive,
  });

  @override
  RawScrollbarState<StableThumbScrollbar> createState() =>
      _StableThumbScrollbarState();
}

const double _kScrollbarThickness = 8.0;
const double _kScrollbarThicknessWithTrack = 12.0;
const double _kScrollbarMargin = 2.0;
const double _kScrollbarMinLength = 48.0;
const Radius _kScrollbarRadius = Radius.circular(8.0);

/// Thickness shared by the app's horizontal card strips (characters, relations,
/// onair sites). Wider than the vertical default so the thumb stays easy to
/// grab in a list that is only one card tall.
const double kHorizontalListScrollbarThickness = 12.0;

/// Bottom padding a horizontal card strip must reserve so its scrollbar sits
/// *below* the cards rather than on top of them.
///
/// A bottom-oriented thumb is laid out at
/// `height - thickness - crossAxisMargin` (see `ScrollbarPainter.paint`), so it
/// claims [kHorizontalListScrollbarThickness] plus [_kScrollbarMargin] of the
/// strip's height. Deriving the padding from the thickness keeps the two from
/// drifting apart — reserving less clips the bottom of the card content, which
/// for these strips is the trailing text line (CV name, site title).
const double kHorizontalListScrollbarClearance =
    kHorizontalListScrollbarThickness + _kScrollbarMargin;

class _StableThumbScrollbarState
    extends RawScrollbarState<StableThumbScrollbar> {
  late AnimationController _hoverAnimationController;
  bool _dragIsActive = false;
  bool _hoverIsActive = false;
  late ColorScheme _colorScheme;
  late ScrollbarThemeData _scrollbarTheme;

  /// Extents captured when the thumb was pressed, or null when not dragging.
  ///
  /// Only the extents are held; `pixels` is refreshed from the live metrics on
  /// every update so the thumb keeps moving with the pointer.
  ScrollMetrics? _pinnedExtents;

  @override
  bool get showScrollbar =>
      widget.thumbVisibility ??
      _scrollbarTheme.thumbVisibility?.resolve(_states) ??
      false;

  @override
  bool get enableGestures =>
      widget.interactive ?? _scrollbarTheme.interactive ?? true;

  Set<WidgetState> get _states => <WidgetState>{
    if (_dragIsActive) WidgetState.dragged,
    if (_hoverIsActive) WidgetState.hovered,
  };

  WidgetStateProperty<bool> get _trackVisibility =>
      WidgetStateProperty.resolveWith((states) {
        return _scrollbarTheme.trackVisibility?.resolve(states) ?? false;
      });

  WidgetStateProperty<Color> get _thumbColor {
    final onSurface = _colorScheme.onSurface;
    final Color dragColor;
    final Color hoverColor;
    final Color idleColor;
    switch (_colorScheme.brightness) {
      case Brightness.light:
        dragColor = onSurface.withValues(alpha: 0.6);
        hoverColor = onSurface.withValues(alpha: 0.5);
        idleColor = onSurface.withValues(alpha: 0.1);
      case Brightness.dark:
        dragColor = onSurface.withValues(alpha: 0.75);
        hoverColor = onSurface.withValues(alpha: 0.65);
        idleColor = onSurface.withValues(alpha: 0.3);
    }

    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.dragged)) {
        return _scrollbarTheme.thumbColor?.resolve(states) ?? dragColor;
      }
      if (_trackVisibility.resolve(states)) {
        return _scrollbarTheme.thumbColor?.resolve(states) ?? hoverColor;
      }
      return Color.lerp(
        _scrollbarTheme.thumbColor?.resolve(states) ?? idleColor,
        _scrollbarTheme.thumbColor?.resolve(states) ?? hoverColor,
        _hoverAnimationController.value,
      )!;
    });
  }

  WidgetStateProperty<Color> get _trackColor {
    final onSurface = _colorScheme.onSurface;
    return WidgetStateProperty.resolveWith((states) {
      if (showScrollbar && _trackVisibility.resolve(states)) {
        return _scrollbarTheme.trackColor?.resolve(states) ??
            switch (_colorScheme.brightness) {
              Brightness.light => onSurface.withValues(alpha: 0.03),
              Brightness.dark => onSurface.withValues(alpha: 0.05),
            };
      }
      return const Color(0x00000000);
    });
  }

  WidgetStateProperty<Color> get _trackBorderColor {
    final onSurface = _colorScheme.onSurface;
    return WidgetStateProperty.resolveWith((states) {
      if (showScrollbar && _trackVisibility.resolve(states)) {
        return _scrollbarTheme.trackBorderColor?.resolve(states) ??
            switch (_colorScheme.brightness) {
              Brightness.light => onSurface.withValues(alpha: 0.1),
              Brightness.dark => onSurface.withValues(alpha: 0.25),
            };
      }
      return const Color(0x00000000);
    });
  }

  WidgetStateProperty<double> get _thickness {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) &&
          _trackVisibility.resolve(states)) {
        return widget.thickness ??
            _scrollbarTheme.thickness?.resolve(states) ??
            _kScrollbarThicknessWithTrack;
      }
      return widget.thickness ??
          _scrollbarTheme.thickness?.resolve(states) ??
          _kScrollbarThickness;
    });
  }

  @override
  void initState() {
    super.initState();
    _hoverAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimationController.addListener(updateScrollbarPainter);
  }

  @override
  void didChangeDependencies() {
    final theme = Theme.of(context);
    _colorScheme = theme.colorScheme;
    _scrollbarTheme = ScrollbarTheme.of(context);
    super.didChangeDependencies();
  }

  @override
  void updateScrollbarPainter() {
    scrollbarPainter
      ..color = _thumbColor.resolve(_states)
      ..trackColor = _trackColor.resolve(_states)
      ..trackBorderColor = _trackBorderColor.resolve(_states)
      ..textDirection = Directionality.of(context)
      ..thickness = _thickness.resolve(_states)
      ..radius = widget.radius ?? _scrollbarTheme.radius ?? _kScrollbarRadius
      ..crossAxisMargin = _scrollbarTheme.crossAxisMargin ?? _kScrollbarMargin
      ..mainAxisMargin = _scrollbarTheme.mainAxisMargin ?? 0.0
      ..minLength = _scrollbarTheme.minThumbLength ?? _kScrollbarMinLength
      ..padding = MediaQuery.paddingOf(context)
      ..scrollbarOrientation = widget.scrollbarOrientation
      ..ignorePointer = !enableGestures;
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    // Capture before super, which reads getThumbScrollOffset() to anchor the
    // drag: the anchor and the pin must describe the same geometry.
    _pinnedExtents = _currentMetrics();
    super.handleThumbPressStart(localPosition);
    setState(() {
      _dragIsActive = true;
    });
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _releasePin();
    setState(() {
      _dragIsActive = false;
    });
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    if (isPointerOverScrollbar(event.position, event.kind, forHover: true)) {
      if (!_hoverIsActive) {
        setState(() {
          _hoverIsActive = true;
        });
      }
      _hoverAnimationController.forward();
    } else if (_hoverIsActive) {
      setState(() {
        _hoverIsActive = false;
      });
      _hoverAnimationController.reverse();
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    setState(() {
      _hoverIsActive = false;
    });
    _hoverAnimationController.reverse();
  }

  @override
  void dispose() {
    _hoverAnimationController.dispose();
    _pinnedExtents = null;
    super.dispose();
  }

  ScrollMetrics? _currentMetrics() {
    final controller = widget.controller;
    if (controller == null || !controller.hasClients) return null;
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return null;
    }
    return position.copyWith();
  }

  void _releasePin() {
    if (_pinnedExtents == null) return;
    _pinnedExtents = null;
    // Hand the painter the settled geometry so the thumb resizes once, here,
    // instead of on the next incidental scroll notification.
    final metrics = _currentMetrics();
    if (metrics != null) {
      scrollbarPainter.update(metrics, metrics.axisDirection);
    }
  }

  @override
  Widget build(BuildContext context) {
    // RawScrollbar.build installs the listeners that feed live metrics to the
    // painter. Wrapping it means these listeners run *after* those for the same
    // notification, so the pinned extents are the last write to the painter
    // before it paints and before the next drag update reads them back through
    // getTrackToScroll().
    //
    // Both notification types matter, and they are disjoint:
    //   * ScrollNotification carries the drag's own position updates.
    //   * ScrollMetricsNotification carries content-dimension changes — which
    //     is exactly the event this widget exists to absorb. It is not a
    //     ScrollNotification, so it needs its own listener.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _repin(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // A drag that was cancelled rather than lifted (pointer capture
          // lost, the scrollable being disposed) never reaches
          // handleThumbPressEnd. The end of the drag activity is the reliable
          // signal, so drop the pin there.
          if (notification is ScrollEndNotification) {
            _releasePin();
            return false;
          }
          _repin(notification.metrics);
          return false;
        },
        child: super.build(context),
      ),
    );
  }

  /// Rewrites the painter's extents back to the pinned ones, keeping the live
  /// `pixels` so the thumb still follows the pointer.
  void _repin(ScrollMetrics live) {
    final pinned = _pinnedExtents;
    if (pinned == null) return;
    if (live.axis != pinned.axis) return;

    scrollbarPainter.update(
      pinned.copyWith(pixels: live.pixels),
      pinned.axisDirection,
    );
  }
}

/// Applies [StableThumbScrollbar] to every desktop scroll view in the app.
///
/// Mirrors `MaterialScrollBehavior.buildScrollbar`: vertical scrollables get a
/// scrollbar on desktop platforms, and mobile keeps its overlay-free scrolling.
class StableThumbScrollBehavior extends MaterialScrollBehavior {
  const StableThumbScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            return StableThumbScrollbar(
              controller: details.controller,
              child: child,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }
}
