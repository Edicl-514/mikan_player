import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

ScrollController createPlatformScrollController({
  double initialScrollOffset = 0.0,
  bool keepScrollOffset = true,
  String? debugLabel,
}) {
  final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  if (!isWindows) {
    return ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }

  return SmoothScrollController(
    initialScrollOffset: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
  });

  final Duration duration;
  final Curve curve;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
      duration: duration,
      curve: curve,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    required this.duration,
    required this.curve,
  });

  final Duration duration;
  final Curve curve;

  double? _targetPixels;
  int _animationGeneration = 0;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity is! DrivenScrollActivity) {
      _resetTarget();
    }
    super.beginActivity(newActivity);
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      _resetTarget();
      goBallistic(0.0);
      return;
    }

    final targetPixels = math.min(
      math.max((_targetPixels ?? pixels) + delta, minScrollExtent),
      maxScrollExtent,
    );
    if (targetPixels == pixels) {
      _resetTarget();
      return;
    }

    updateUserScrollDirection(
      -delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );

    _targetPixels = targetPixels;
    final generation = ++_animationGeneration;

    animateTo(targetPixels, duration: duration, curve: curve).whenComplete(() {
      if (_animationGeneration == generation) {
        _targetPixels = null;
      }
    });
  }

  void _resetTarget() {
    _targetPixels = null;
    _animationGeneration++;
  }
}
