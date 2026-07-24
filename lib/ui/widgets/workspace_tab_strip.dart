import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';

class WorkspaceTabStrip extends StatelessWidget {
  const WorkspaceTabStrip({
    super.key,
    required this.controller,
    required this.hostController,
  });

  final WorkspaceTabController controller;
  final WorkspaceTabHostController hostController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = (constraints.maxWidth / controller.tabs.length)
                .clamp(120.0, 220.0);
            return ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: controller.tabs.length,
              onReorderItem: controller.reorder,
              itemBuilder: (context, index) {
                final tab = controller.tabs[index];
                return SizedBox(
                  key: ValueKey(tab.id),
                  width: tabWidth,
                  child: ReorderableDelayedDragStartListener(
                    index: index,
                    child: _WorkspaceTab(
                      tab: tab,
                      isActive: tab.id == controller.activeTabId,
                      onActivate: () => controller.activate(tab.id),
                      onClose: () => unawaited(hostController.closeTab(tab.id)),
                    ),
                  ),
                );
              },
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
    required this.onActivate,
    required this.onClose,
  });

  final WorkspaceTabState tab;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClose;

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
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton && !widget.tab.isClosing) {
          widget.onClose();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: widget.isActive
              ? colors.surfaceContainerHighest
              : Colors.transparent,
          child: InkWell(
            onTap: widget.tab.isClosing ? null : widget.onActivate,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  Icon(_icon, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    child: widget.tab.isAudible
                        ? Icon(
                            Icons.volume_up_outlined,
                            size: 14,
                            color: colors.onSurfaceVariant,
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
                                tooltip: 'Close tab',
                                icon: const Icon(Icons.close, size: 15),
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
    );
  }
}

class WorkspaceContextToolbar extends StatelessWidget {
  const WorkspaceContextToolbar({
    super.key,
    required this.controller,
    required this.hostController,
  });

  final WorkspaceTabController controller;
  final WorkspaceTabHostController hostController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tab = controller.activeTab;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, size: 19),
                  onPressed: tab.canGoBack
                      ? () => unawaited(hostController.goBack())
                      : null,
                ),
                IconButton(
                  tooltip: 'Forward',
                  icon: const Icon(Icons.arrow_forward, size: 19),
                  onPressed: tab.canGoForward ? hostController.goForward : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
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
