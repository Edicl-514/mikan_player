import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/utils/dominant_color.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';

class WorkspaceTabStrip extends StatefulWidget {
  const WorkspaceTabStrip({
    super.key,
    required this.controller,
    required this.hostController,
  });

  final WorkspaceTabController controller;
  final WorkspaceTabHostController hostController;

  @override
  State<WorkspaceTabStrip> createState() => _WorkspaceTabStripState();
}

class _WorkspaceTabStripState extends State<WorkspaceTabStrip> {
  static const double _autoScrollEdge = 32;
  static const double _autoScrollStep = 24;

  final GlobalKey _stripKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  WorkspaceTabId? _draggedTabId;
  int? _dragStartIndex;
  double? _dragTabWidth;
  double _dragDistance = 0;
  Offset? _lastDragPosition;
  double _dragStartScrollOffset = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startTabDrag(
    WorkspaceTabId tabId,
    DragStartDetails details,
    double tabWidth,
  ) {
    setState(() {
      _draggedTabId = tabId;
      _dragStartIndex = widget.controller.tabs.indexWhere(
        (tab) => tab.id == tabId,
      );
      _dragTabWidth = tabWidth;
      _dragDistance = 0;
      _lastDragPosition = details.globalPosition;
      _dragStartScrollOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0;
    });
  }

  void _updateTabDrag(WorkspaceTabId tabId, DragUpdateDetails details) {
    if (_draggedTabId != tabId) return;
    final previousPosition = _lastDragPosition;
    _lastDragPosition = details.globalPosition;
    if (previousPosition == null) return;
    final delta = details.globalPosition.dx - previousPosition.dx;
    if (delta == 0) return;

    setState(() => _dragDistance += delta);
    if (_autoScroll(details.globalPosition)) {
      setState(() {});
    }
  }

  void _endTabDrag() {
    final tabId = _draggedTabId;
    final startIndex = _dragStartIndex;
    final tabWidth = _dragTabWidth;
    final distance = _dragDistance;
    setState(() {
      _draggedTabId = null;
      _dragStartIndex = null;
      _dragTabWidth = null;
      _dragDistance = 0;
      _lastDragPosition = null;
      _dragStartScrollOffset = 0;
    });

    if (tabId == null || startIndex == null || tabWidth == null) return;
    final currentIndex = widget.controller.tabs.indexWhere(
      (tab) => tab.id == tabId,
    );
    if (currentIndex < 0) return;

    final targetIndex = (startIndex + (distance / tabWidth).round()).clamp(
      0,
      widget.controller.tabs.length - 1,
    );
    widget.controller.reorder(currentIndex, targetIndex);
  }

  bool _autoScroll(Offset globalPosition) {
    if (!_scrollController.hasClients) return false;
    final stripBox = _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (stripBox == null) return false;

    final localX = stripBox.globalToLocal(globalPosition).dx;
    final position = _scrollController.position;
    double? targetOffset;
    if (localX < _autoScrollEdge) {
      targetOffset = (position.pixels - _autoScrollStep).clamp(
        0.0,
        position.maxScrollExtent,
      );
    } else if (localX > stripBox.size.width - _autoScrollEdge) {
      targetOffset = (position.pixels + _autoScrollStep).clamp(
        0.0,
        position.maxScrollExtent,
      );
    }
    if (targetOffset == null || targetOffset == position.pixels) return false;
    _scrollController.jumpTo(targetOffset);
    return true;
  }

  int? _previewIndex(List<WorkspaceTabState> tabs, double tabWidth) {
    final tabId = _draggedTabId;
    final startIndex = _dragStartIndex;
    if (tabId == null || startIndex == null) return null;
    if (tabs.indexWhere((tab) => tab.id == tabId) < 0) return null;
    return (startIndex + (_dragDistance / tabWidth).round()).clamp(
      0,
      tabs.length - 1,
    );
  }

  double _dragVisualOffset(
    int currentIndex,
    int previewIndex,
    double tabWidth,
  ) {
    final currentScrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : _dragStartScrollOffset;
    return _dragDistance -
        (previewIndex - currentIndex) * tabWidth +
        currentScrollOffset -
        _dragStartScrollOffset;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final tabs = widget.controller.tabs;
            final tabWidth = (constraints.maxWidth / tabs.length).clamp(
              120.0,
              220.0,
            );
            final draggedIndex = tabs.indexWhere(
              (tab) => tab.id == _draggedTabId,
            );
            final previewIndex = _previewIndex(tabs, tabWidth);
            final displayTabs = [...tabs];
            if (draggedIndex >= 0 &&
                previewIndex != null &&
                previewIndex != draggedIndex) {
              final draggedTab = displayTabs.removeAt(draggedIndex);
              displayTabs.insert(previewIndex, draggedTab);
            }
            final dragOffset = draggedIndex >= 0 && previewIndex != null
                ? _dragVisualOffset(draggedIndex, previewIndex, tabWidth)
                : 0.0;
            // Keep the strip's reported width to the visible tabs so the
            // title bar can place the new-tab button directly after them.
            return SizedBox(
              key: _stripKey,
              width: tabWidth * tabs.length,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _scrollController,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (final tab in displayTabs)
                      SizedBox(
                        key: ValueKey(tab.id),
                        width: tabWidth,
                        child: Transform.translate(
                          offset: tab.id == _draggedTabId
                              ? Offset(dragOffset, 0)
                              : Offset.zero,
                          child: _WorkspaceTab(
                            tab: tab,
                            isActive: tab.id == widget.controller.activeTabId,
                            isDragging: tab.id == _draggedTabId,
                            onActivate: () =>
                                widget.controller.activate(tab.id),
                            onClose: () => unawaited(
                              widget.hostController.closeTab(tab.id),
                            ),
                            onDragStart: (details) =>
                                _startTabDrag(tab.id, details, tabWidth),
                            onDragUpdate: (details) =>
                                _updateTabDrag(tab.id, details),
                            onDragEnd: _endTabDrag,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkspaceTab extends StatefulWidget {
  const _WorkspaceTab({
    required this.tab,
    required this.isActive,
    required this.isDragging,
    required this.onActivate,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final WorkspaceTabState tab;
  final bool isActive;
  final bool isDragging;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  final ValueChanged<DragStartDetails> onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<_WorkspaceTab> {
  bool _hovered = false;

  IconData get _icon => switch (widget.tab.icon) {
    WorkspaceTabIcon.home => Icons.home_outlined,
    WorkspaceTabIcon.page => Icons.description_outlined,
    WorkspaceTabIcon.media => Icons.play_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showClose = widget.isActive || _hovered;
    final l10n = AppLocalizations.of(context);
    // On a tinted shell the strip rides the page color; keep chrome contrast by
    // drawing with the chrome foreground instead of theme colors.
    final tint = WorkspaceChromeTintScope.tintOf(context);
    final contentColor =
        tint != null ? chromeForeground(tint) : colors.onSurfaceVariant;
    final activeChipColor =
        tint != null
        ? contentColor.withValues(alpha: 0.16)
        : colors.surfaceContainerHighest;
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color:
          tint != null
          ? contentColor.withValues(
              alpha: widget.isActive ? 0.95 : 0.72,
            )
          : null,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: widget.tab.isClosing ? null : widget.onDragStart,
      onHorizontalDragUpdate: widget.tab.isClosing ? null : widget.onDragUpdate,
      onHorizontalDragEnd: widget.tab.isClosing
          ? null
          : (_) => widget.onDragEnd(),
      onHorizontalDragCancel: widget.onDragEnd,
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kMiddleMouseButton && !widget.tab.isClosing) {
            widget.onClose();
          }
        },
        child: MouseRegion(
          cursor: widget.isDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: widget.isActive ? activeChipColor : Colors.transparent,
            child: InkWell(
              onTap: widget.tab.isClosing ? null : widget.onActivate,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  children: [
                    Icon(_icon, size: 16, color: contentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    SizedBox(
                      width: 20,
                      child: widget.tab.isAudible
                          ? Icon(
                              Icons.volume_up_outlined,
                              size: 14,
                              color: contentColor,
                            )
                          : null,
                    ),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: widget.tab.isClosing
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IgnorePointer(
                              ignoring: !showClose,
                              child: AnimatedOpacity(
                                opacity: showClose ? 1 : 0,
                                duration: const Duration(milliseconds: 100),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: l10n.closeTab,
                                  icon: const Icon(Icons.close, size: 15),
                                  color: contentColor,
                                  onPressed: widget.onClose,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back, Forward and the active tab's title.
///
/// The trailing slot only carries what the active route published through
/// [WorkspacePageChromeRegistry]; page-level business actions belong in the
/// page's own action row so they cannot crowd out the title.
class WorkspaceContextToolbar extends StatelessWidget {
  const WorkspaceContextToolbar({
    super.key,
    required this.controller,
    required this.hostController,
  });

  static const double height = 42;

  final WorkspaceTabController controller;
  final WorkspaceTabHostController hostController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        controller,
        WorkspacePageChromeRegistry.instance,
      ]),
      builder: (context, _) {
        final tab = controller.activeTab;
        final l10n = AppLocalizations.of(context);
        final actions = WorkspacePageChromeRegistry.instance.toolbarActionsFor(
          tab.id,
        );
        final tint = WorkspaceChromeTintScope.tintOf(context);
        final colors = Theme.of(context).colorScheme;
        final background = tint ?? colors.surface;
        final foreground = tint != null ? chromeForeground(tint) : colors.onSurface;
        return Material(
          color: background,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.back,
                  icon: const Icon(Icons.arrow_back, size: 19),
                  color: foreground,
                  disabledColor: foreground.withValues(alpha: 0.38),
                  onPressed: tab.canGoBack
                      ? () => unawaited(hostController.goBack())
                      : null,
                ),
                IconButton(
                  tooltip: l10n.forward,
                  icon: const Icon(Icons.arrow_forward, size: 19),
                  color: foreground,
                  disabledColor: foreground.withValues(alpha: 0.38),
                  onPressed: tab.canGoForward ? hostController.goForward : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: foreground),
                  ),
                ),
                for (final action in actions) action.build(context),
                if (actions.isNotEmpty) const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
