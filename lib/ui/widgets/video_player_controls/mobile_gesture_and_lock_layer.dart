import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:mikan_player/ui/widgets/video_player_controls/mobile_floating_lock_button.dart';

class MobileGestureAndLockLayer extends StatefulWidget {
  final bool isEnabled;
  final bool isFullscreen;
  final Player player;
  final VoidCallback onLeftDouble;
  final VoidCallback onLeftTriple;
  final VoidCallback onCenterDouble;
  final VoidCallback onRightDouble;
  final VoidCallback onRightTriple;
  final VoidCallback onLock;
  final VoidCallback onUserInteraction;

  const MobileGestureAndLockLayer({
    super.key,
    required this.isEnabled,
    required this.isFullscreen,
    required this.player,
    required this.onLeftDouble,
    required this.onLeftTriple,
    required this.onCenterDouble,
    required this.onRightDouble,
    required this.onRightTriple,
    required this.onLock,
    required this.onUserInteraction,
  });

  @override
  State<MobileGestureAndLockLayer> createState() =>
      _MobileGestureAndLockLayerState();
}

class _MobileGestureAndLockLayerState extends State<MobileGestureAndLockLayer> {
  static const Duration _lockButtonVisibleDuration = Duration(seconds: 3);

  bool _lockButtonVisible = false;
  Timer? _lockButtonTimer;

  @override
  void dispose() {
    _lockButtonTimer?.cancel();
    super.dispose();
  }

  void _handlePointerActivity() {
    if (!widget.isEnabled || !widget.isFullscreen) return;

    _lockButtonTimer?.cancel();
    if (_lockButtonVisible) {
      setState(() => _lockButtonVisible = false);
      return;
    }

    setState(() {
      _lockButtonVisible = true;
    });
    _lockButtonTimer = Timer(_lockButtonVisibleDuration, () {
      if (mounted) {
        setState(() => _lockButtonVisible = false);
      }
    });
  }

  void _handleLock() {
    _lockButtonTimer?.cancel();
    setState(() => _lockButtonVisible = false);
    widget.onLock();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 40,
          // 底部留出足够空间给进度条和按钮栏
          bottom: 80,
          child: _MobileMultiTapDetector(
            isEnabled: widget.isEnabled,
            player: widget.player,
            onPointerActivity: () {
              widget.onUserInteraction();
              _handlePointerActivity();
            },
            onLeftDouble: widget.onLeftDouble,
            onLeftTriple: widget.onLeftTriple,
            onCenterDouble: widget.onCenterDouble,
            onRightDouble: widget.onRightDouble,
            onRightTriple: widget.onRightTriple,
            child: const SizedBox.expand(),
          ),
        ),
        if (widget.isFullscreen && widget.isEnabled && _lockButtonVisible)
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Center(
                child: MobileFloatingLockButton(
                  icon: Icons.lock_outline,
                  tooltip: '锁定',
                  onPressed: _handleLock,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _MobileTapZone { left, center, right }

class _MobileMultiTapDetector extends StatefulWidget {
  final bool isEnabled;
  final Player player;
  final VoidCallback? onPointerActivity;
  final VoidCallback onLeftDouble;
  final VoidCallback onLeftTriple;
  final VoidCallback onCenterDouble;
  final VoidCallback onRightDouble;
  final VoidCallback onRightTriple;
  final Widget child;

  const _MobileMultiTapDetector({
    required this.isEnabled,
    required this.player,
    this.onPointerActivity,
    required this.onLeftDouble,
    required this.onLeftTriple,
    required this.onCenterDouble,
    required this.onRightDouble,
    required this.onRightTriple,
    required this.child,
  });

  @override
  State<_MobileMultiTapDetector> createState() =>
      _MobileMultiTapDetectorState();
}

class _MobileMultiTapDetectorState extends State<_MobileMultiTapDetector> {
  static const Duration _multiTapTimeout = Duration(milliseconds: 320);
  static const Duration _overlayDisplayDuration = Duration(milliseconds: 600);
  static const Duration _overlayFadeDuration = Duration(milliseconds: 160);

  Timer? _tapTimer;
  Timer? _overlayTimer;
  int _tapCount = 0;
  DateTime? _lastTapTime;
  _MobileTapZone? _lastZone;

  bool _isDragging = false;
  _MobileTapZone? _dragZone;
  double? _dragStartDy;
  double? _dragStartBrightness;
  double? _dragStartVolume;

  bool _isDraggingHorizontal = false;
  double? _dragStartDx;
  Duration? _dragStartPosition;
  Duration? _dragTargetPosition;

  bool _overlayVisible = false;
  IconData _overlayIcon = Icons.play_arrow;
  String _overlayLabel = '';

  // 长按快进状态
  bool _isLongPressFastForwarding = false;
  double? _originalPlaybackSpeed;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _overlayTimer?.cancel();
    if (_isLongPressFastForwarding && _originalPlaybackSpeed != null) {
      widget.player.setRate(_originalPlaybackSpeed!);
    }
    super.dispose();
  }

  void _handleTap(PointerDownEvent event, BoxConstraints constraints) {
    if (!widget.isEnabled) return;
    if (_isDragging) return;
    if (event.kind != PointerDeviceKind.touch &&
        event.kind != PointerDeviceKind.stylus) {
      return;
    }
    widget.onPointerActivity?.call();

    final width = constraints.maxWidth;
    if (width <= 0) return;

    final zone = _resolveZone(event.localPosition.dx, width);
    final now = DateTime.now();

    final isSameZone = _lastZone == zone;
    final isWithinTimeout =
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= _multiTapTimeout;

    if (!isSameZone || !isWithinTimeout) {
      _tapCount = 0;
    }

    _tapCount += 1;
    _lastZone = zone;
    _lastTapTime = now;

    _tapTimer?.cancel();

    if (_tapCount >= 3) {
      _fireAction(zone, isTriple: true);
      _resetTapState();
      return;
    }

    _tapTimer = Timer(_multiTapTimeout, () {
      if (!mounted) return;
      if (_tapCount == 2) {
        _fireAction(zone, isTriple: false);
      }
      _resetTapState();
    });
  }

  void _handleVerticalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;

    final zone = _resolveZone(details.localPosition.dx, constraints.maxWidth);
    if (zone == _MobileTapZone.center) return;

    _isDragging = true;
    _dragZone = zone;
    _dragStartDy = details.localPosition.dy;
    _resetTapState();

    if (zone == _MobileTapZone.left) {
      _prepareBrightnessOverlay();
    } else {
      // 隐藏系统音量条
      try {
        FlutterVolumeController.updateShowSystemUI(false);
      } catch (_) {}
      _prepareVolumeOverlay();
    }
  }

  void _handleVerticalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;
    if (!_isDragging || _dragZone == null || _dragStartDy == null) return;
    if (constraints.maxHeight <= 0) return;

    final delta =
        (_dragStartDy! - details.localPosition.dy) / constraints.maxHeight;

    if (_dragZone == _MobileTapZone.left) {
      if (_dragStartBrightness == null) return;
      final target = (_dragStartBrightness! + delta).clamp(0.0, 1.0);
      _setBrightness(target);
      _showBrightnessOverlay(target);
    } else if (_dragZone == _MobileTapZone.right) {
      if (_dragStartVolume == null) return;
      final target = (_dragStartVolume! + delta).clamp(0.0, 1.0);
      _setSystemVolume(target);
      _showVolumeOverlay(target);
    }
  }

  void _handleVerticalDragEnd() {
    if (!_isDragging) return;

    // 恢复系统音量条显示
    if (_dragZone == _MobileTapZone.right) {
      try {
        FlutterVolumeController.updateShowSystemUI(true);
      } catch (_) {}
    }

    _isDragging = false;
    _dragZone = null;
    _dragStartDy = null;
    _dragStartBrightness = null;
    _dragStartVolume = null;
    _scheduleOverlayHide();
  }

  _MobileTapZone _resolveZone(double dx, double width) {
    final third = width / 3;
    if (dx < third) return _MobileTapZone.left;
    if (dx < third * 2) return _MobileTapZone.center;
    return _MobileTapZone.right;
  }

  void _fireAction(_MobileTapZone zone, {required bool isTriple}) {
    switch (zone) {
      case _MobileTapZone.left:
        if (isTriple) {
          _showOverlay(Icons.fast_rewind, '快退 85s');
          widget.onLeftTriple();
        } else {
          _showOverlay(Icons.replay_10, '快退 10s');
          widget.onLeftDouble();
        }
        break;
      case _MobileTapZone.center:
        if (!isTriple) {
          final isPlaying = widget.player.state.playing;
          _showOverlay(
            isPlaying ? Icons.pause : Icons.play_arrow,
            isPlaying ? '暂停' : '播放',
          );
          widget.onCenterDouble();
        }
        break;
      case _MobileTapZone.right:
        if (isTriple) {
          _showOverlay(Icons.fast_forward, '快进 85s');
          widget.onRightTriple();
        } else {
          _showOverlay(Icons.forward_10, '快进 10s');
          widget.onRightDouble();
        }
        break;
    }
  }

  void _showOverlay(IconData icon, String label) {
    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = icon;
      _overlayLabel = label;
      _overlayVisible = true;
    });
    _overlayTimer = Timer(_overlayDisplayDuration, () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(_overlayDisplayDuration, () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  void _showBrightnessOverlay(double value) {
    final percent = (value * 100).round();
    _showOverlay(Icons.brightness_6, '亮度 $percent%');
  }

  void _showVolumeOverlay(double value) {
    final percent = (value * 100).round().clamp(0, 100);
    final icon = percent == 0
        ? Icons.volume_off
        : percent < 50
        ? Icons.volume_down
        : Icons.volume_up;
    _showOverlay(icon, '音量 $percent%');
  }

  Future<void> _prepareBrightnessOverlay() async {
    try {
      final current = await ScreenBrightness.instance.application;
      _dragStartBrightness = current;
      _showBrightnessOverlay(current);
    } catch (_) {
      _dragStartBrightness = null;
    }
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {
      // 忽略不支持的平台/权限错误
    }
  }

  Future<void> _prepareVolumeOverlay() async {
    try {
      final current = await FlutterVolumeController.getVolume();
      _dragStartVolume = current;
      _showVolumeOverlay(current ?? 0);
    } catch (_) {
      _dragStartVolume = null;
    }
  }

  Future<void> _setSystemVolume(double value) async {
    try {
      await FlutterVolumeController.setVolume(value);
    } catch (_) {
      // 忽略错误
    }
  }

  void _resetTapState() {
    _tapTimer?.cancel();
    _tapTimer = null;
    _tapCount = 0;
    _lastTapTime = null;
    _lastZone = null;
  }

  void _handleLongPressStart() {
    if (!widget.isEnabled) return;

    _tapTimer?.cancel();
    _resetTapState();

    _originalPlaybackSpeed = widget.player.state.rate;
    if (_originalPlaybackSpeed == null || _originalPlaybackSpeed! <= 0) {
      _originalPlaybackSpeed = 1.0;
    }

    _isLongPressFastForwarding = true;
    widget.player.setRate(2.0);

    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = Icons.fast_forward;
      _overlayLabel = '长按快进 2x';
      _overlayVisible = true;
    });
  }

  void _handleLongPressEnd() {
    if (!_isLongPressFastForwarding) return;

    _isLongPressFastForwarding = false;

    final targetRate = _originalPlaybackSpeed ?? 1.0;
    widget.player.setRate(targetRate);
    _originalPlaybackSpeed = null;

    _scheduleOverlayHide();
  }

  void _handleHorizontalDragStart(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;

    _isDraggingHorizontal = true;
    _dragStartDx = details.localPosition.dx;
    _dragStartPosition = widget.player.state.position;
    _dragTargetPosition = _dragStartPosition;
    _resetTapState();

    _showSeekOverlay(_dragStartPosition!, _dragStartPosition!);
  }

  void _handleHorizontalDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (!widget.isEnabled) return;
    if (!_isDraggingHorizontal || _dragStartDx == null) return;
    if (constraints.maxWidth <= 0) return;

    final deltaPixels = details.localPosition.dx - _dragStartDx!;
    // 每100像素代表10秒
    final deltaSeconds = (deltaPixels / 100) * 10;

    final duration = widget.player.state.duration;
    final newPosition = (_dragStartPosition!.inSeconds + deltaSeconds.round())
        .clamp(0, duration.inSeconds);

    _dragTargetPosition = Duration(seconds: newPosition);
    _showSeekOverlay(_dragStartPosition!, _dragTargetPosition!);
  }

  void _handleHorizontalDragEnd() {
    if (!_isDraggingHorizontal) return;

    if (_dragTargetPosition != null) {
      widget.player.seek(_dragTargetPosition!);
    }

    _isDraggingHorizontal = false;
    _dragStartDx = null;
    _dragStartPosition = null;
    _dragTargetPosition = null;
    _scheduleOverlayHide();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _showSeekOverlay(Duration startPos, Duration targetPos) {
    final delta = targetPos.inSeconds - startPos.inSeconds;
    final icon = delta >= 0 ? Icons.fast_forward : Icons.fast_rewind;
    final label =
        '${_formatDuration(targetPos)} ${delta >= 0 ? "+" : ""}${delta}s';

    _overlayTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _overlayIcon = icon;
      _overlayLabel = label;
      _overlayVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) =>
              _handleVerticalDragStart(details, constraints),
          onVerticalDragUpdate: (details) =>
              _handleVerticalDragUpdate(details, constraints),
          onVerticalDragEnd: (_) => _handleVerticalDragEnd(),
          onVerticalDragCancel: _handleVerticalDragEnd,
          onHorizontalDragStart: (details) =>
              _handleHorizontalDragStart(details, constraints),
          onHorizontalDragUpdate: (details) =>
              _handleHorizontalDragUpdate(details, constraints),
          onHorizontalDragEnd: (_) => _handleHorizontalDragEnd(),
          onHorizontalDragCancel: _handleHorizontalDragEnd,
          onLongPressStart: (_) => _handleLongPressStart(),
          onLongPressEnd: (_) => _handleLongPressEnd(),
          onLongPressCancel: () => _handleLongPressEnd(),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _handleTap(event, constraints),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _overlayVisible ? 1.0 : 0.0,
                      duration: _overlayFadeDuration,
                      child: AnimatedScale(
                        scale: _overlayVisible ? 1.0 : 0.9,
                        duration: _overlayFadeDuration,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_overlayIcon, color: Colors.white, size: 36),
                              const SizedBox(height: 6),
                              Text(
                                _overlayLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
