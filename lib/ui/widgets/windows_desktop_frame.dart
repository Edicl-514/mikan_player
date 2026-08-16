import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/utils/dominant_color.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';
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
    this.controller,
  });

  static const double titleBarHeight = 40;
  static const double windowControlWidth = 46;

  final Widget child;
  final Widget? tabStrip;
  final Widget? contextToolbar;
  final VoidCallback? onNewTab;

  /// Tab state used to resolve which tab's published chrome tint colors the
  /// shell. Optional so chrome can be exercised without a workspace.
  final WorkspaceTabController? controller;

  @override
  State<WindowsDesktopFrame> createState() => _WindowsDesktopFrameState();
}

class _WindowsDesktopFrameState extends State<WindowsDesktopFrame>
    with WindowListener {
  static const Duration _chromeTransitionDuration = Duration(milliseconds: 300);

  bool _isMaximized = false;
  late final Listenable _chromeListenable;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _chromeListenable = Listenable.merge(<Listenable>[
      WindowsDesktopFrameController.instance,
      WorkspacePageChromeRegistry.instance,
      if (widget.controller != null) widget.controller!,
    ]);
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
      child: ListenableBuilder(
        listenable: _chromeListenable,
        builder: (context, _) {
          final frameController = WindowsDesktopFrameController.instance;
          if (frameController.isContentFullscreen ||
              frameController.isWindowFullscreen) {
            return widget.child;
          }

          final colors = Theme.of(context).colorScheme;
          final tint = _activeTint();
          return WorkspaceChromeTintScope(
            tint: tint,
            child: AnimatedContainer(
              key: const ValueKey('workspace_chrome_background'),
              duration: _chromeTransitionDuration,
              curve: Curves.easeOut,
              color: tint ?? colors.surface,
              child: Column(
                children: [
                  _buildTitleBar(context, colors, tint),
                  if (widget.contextToolbar != null) widget.contextToolbar!,
                  Expanded(child: widget.child),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// The active tab's published chrome tint, if any.
  Color? _activeTint() {
    final controller = widget.controller;
    if (controller == null) return null;
    return WorkspacePageChromeRegistry.instance.tintFor(controller.activeTabId);
  }

  Widget _buildTitleBar(BuildContext context, ColorScheme colors, Color? tint) {
    final l10n = AppLocalizations.of(context);
    final foreground = tint != null ? chromeForeground(tint) : colors.onSurface;
    final iconColor = foreground;
    final brandColor = tint != null ? foreground : colors.primary;
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
                    color: brandColor,
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
                tooltip: l10n.windowNewTab,
                icon: Icons.add,
                iconColor: iconColor,
                onPressed: widget.onNewTab,
              ),
              Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
              _TitleBarButton(
                tooltip: l10n.windowMinimize,
                icon: Icons.remove,
                iconColor: iconColor,
                onPressed: () => windowManager.minimize(),
              ),
              _TitleBarButton(
                tooltip: _isMaximized
                    ? l10n.windowRestore
                    : l10n.windowMaximize,
                icon: _isMaximized
                    ? Icons.filter_none_outlined
                    : Icons.crop_square,
                iconColor: iconColor,
                onPressed: _toggleMaximize,
              ),
              _TitleBarButton(
                tooltip: l10n.windowClose,
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
