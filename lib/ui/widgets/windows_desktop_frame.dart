import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Shares player and native-window fullscreen state with the desktop frame
/// without coupling either mode to the application navigator.
class WindowsDesktopFrameController extends ChangeNotifier {
  WindowsDesktopFrameController._();

  static final WindowsDesktopFrameController instance =
      WindowsDesktopFrameController._();

  bool _isContentFullscreen = false;
  bool _isWindowFullscreen = false;

  bool get isContentFullscreen => _isContentFullscreen;

  bool get isWindowFullscreen => _isWindowFullscreen;

  void setContentFullscreen(bool value) {
    if (_isContentFullscreen == value) return;
    _isContentFullscreen = value;
    notifyListeners();
  }

  void setWindowFullscreen(bool value) {
    if (_isWindowFullscreen == value) return;
    _isWindowFullscreen = value;
    notifyListeners();
  }
}

/// Windows-only application chrome rendered around the root navigator.
///
/// Phase 3 owns the window controls and slots only. Tab state/navigation is
/// deliberately deferred to the workspace implementation in Phase 4.
class WindowsDesktopFrame extends StatefulWidget {
  const WindowsDesktopFrame({
    super.key,
    required this.child,
    this.tabStrip,
    this.contextToolbar,
    this.onNewTab,
  });

  static const double titleBarHeight = 40;
  static const double windowControlWidth = 46;

  final Widget child;
  final Widget? tabStrip;
  final Widget? contextToolbar;
  final VoidCallback? onNewTab;

  @override
  State<WindowsDesktopFrame> createState() => _WindowsDesktopFrameState();
}

class _WindowsDesktopFrameState extends State<WindowsDesktopFrame>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    WindowsDesktopFrameController.instance.setWindowFullscreen(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    WindowsDesktopFrameController.instance.setWindowFullscreen(false);
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp.builder places the desktop frame above the Navigator's
    // Overlay. Keep title-bar tooltips and tab drag proxies in a local overlay.
    return Overlay.wrap(
      child: AnimatedBuilder(
        animation: WindowsDesktopFrameController.instance,
        builder: (context, _) {
          final frameController = WindowsDesktopFrameController.instance;
          if (frameController.isContentFullscreen ||
              frameController.isWindowFullscreen) {
            return widget.child;
          }

          final colors = Theme.of(context).colorScheme;
          return ColoredBox(
            color: colors.surface,
            child: Column(
              children: [
                _buildTitleBar(context, colors),
                if (widget.contextToolbar != null) widget.contextToolbar!,
                Expanded(child: widget.child),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, ColorScheme colors) {
    final iconColor = colors.onSurfaceVariant;
    return SizedBox(
      height: WindowsDesktopFrame.titleBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const fixedWidth = 48 + WindowsDesktopFrame.windowControlWidth * 4;
          final tabStripMaxWidth = (constraints.maxWidth - fixedWidth).clamp(
            0.0,
            double.infinity,
          );
          return Row(
            children: [
              SizedBox(
                width: 48,
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
              ),
              if (widget.tabStrip != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tabStripMaxWidth),
                  child: widget.tabStrip!,
                ),
              _TitleBarButton(
                tooltip: 'New tab',
                icon: Icons.add,
                iconColor: iconColor,
                onPressed: widget.onNewTab,
              ),
              Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
              _TitleBarButton(
                tooltip: 'Minimize',
                icon: Icons.remove,
                iconColor: iconColor,
                onPressed: () => windowManager.minimize(),
              ),
              _TitleBarButton(
                tooltip: _isMaximized ? 'Restore' : 'Maximize',
                icon: _isMaximized
                    ? Icons.filter_none_outlined
                    : Icons.crop_square,
                iconColor: iconColor,
                onPressed: _toggleMaximize,
              ),
              _TitleBarButton(
                tooltip: 'Close',
                icon: Icons.close,
                iconColor: iconColor,
                isCloseButton: true,
                onPressed: () => windowManager.close(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  const _TitleBarButton({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.isCloseButton = false,
  });

  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool isCloseButton;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: WindowsDesktopFrame.windowControlWidth,
        height: WindowsDesktopFrame.titleBarHeight,
        child: IconButton(
          icon: Icon(icon, size: 18),
          color: iconColor,
          disabledColor: iconColor.withValues(alpha: 0.38),
          style: IconButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            hoverColor: isCloseButton
                ? const Color(0xffc42b1c)
                : colors.onSurface.withValues(alpha: 0.08),
            highlightColor: isCloseButton
                ? const Color(0xffa92519)
                : colors.onSurface.withValues(alpha: 0.12),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
