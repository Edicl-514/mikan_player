import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_lifecycle.dart';
import 'package:mikan_player/services/workspace_route_observer.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/ui/screens/home_screen.dart';

typedef WorkspaceDestinationBuilder =
    Widget Function(BuildContext context, WorkspaceDestination destination);

class WorkspaceTabScope extends InheritedWidget {
  const WorkspaceTabScope({
    super.key,
    required this.tabId,
    required this.controller,
    required super.child,
  });

  final WorkspaceTabId tabId;
  final WorkspaceTabController controller;

  static WorkspaceTabId? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceTabScope>()?.tabId;

  static WorkspaceTabController? controllerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceTabScope>()
      ?.controller;

  @override
  bool updateShouldNotify(WorkspaceTabScope oldWidget) =>
      tabId != oldWidget.tabId || controller != oldWidget.controller;
}

class WorkspaceTabHostController extends ChangeNotifier {
  _WorkspaceTabHostState? _host;

  bool get isAttached => _host != null;

  Future<void> closeTab(WorkspaceTabId id) async => _host?.closeTab(id);

  Future<void> closeOthers(WorkspaceTabId id) async => _host?.closeOthers(id);

  Future<void> goBack() async => _host?.goBack();

  void goForward() => _host?.goForward();

  void open(WorkspaceDestination destination, {WorkspaceTabId? tabId}) =>
      _host?.open(destination, tabId: tabId);

  void _attach(_WorkspaceTabHostState host) {
    _host = host;
    notifyListeners();
  }

  void _detach(_WorkspaceTabHostState host) {
    if (_host != host) return;
    _host = null;
    notifyListeners();
  }
}

class WorkspaceTabHost extends StatefulWidget {
  const WorkspaceTabHost({
    super.key,
    required this.controller,
    required this.hostController,
    this.destinationBuilder,
  });

  final WorkspaceTabController controller;
  final WorkspaceTabHostController hostController;
  final WorkspaceDestinationBuilder? destinationBuilder;

  @override
  State<WorkspaceTabHost> createState() => _WorkspaceTabHostState();
}

class _WorkspaceTabHostState extends State<WorkspaceTabHost> {
  final Map<WorkspaceTabId, _TabNavigatorEntry> _entries = {};
  late WorkspaceTabId _previousActiveTabId;

  @override
  void initState() {
    super.initState();
    _previousActiveTabId = widget.controller.activeTabId;
    _syncEntries();
    widget.controller.addListener(_onControllerChanged);
    widget.hostController._attach(this);
  }

  @override
  void didUpdateWidget(WorkspaceTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      for (final entry in _entries.values) {
        entry.dispose();
      }
      _entries.clear();
      _previousActiveTabId = widget.controller.activeTabId;
      _syncEntries();
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.hostController != widget.hostController) {
      oldWidget.hostController._detach(this);
      widget.hostController._attach(this);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final homeTitle = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    )?.navHome;
    if (homeTitle == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.updateHomeTitle(homeTitle);
    });
  }

  @override
  void dispose() {
    widget.hostController._detach(this);
    widget.controller.removeListener(_onControllerChanged);
    for (final entry in _entries.values) {
      entry.dispose();
    }
    super.dispose();
  }

  void _syncEntries() {
    final liveIds = widget.controller.tabs.map((tab) => tab.id).toSet();
    _entries.removeWhere((id, entry) {
      if (liveIds.contains(id)) return false;
      entry.dispose();
      return true;
    });
    for (final tab in widget.controller.tabs) {
      _entries.putIfAbsent(
        tab.id,
        () => _TabNavigatorEntry(
          onNavigationChanged: () => _updateNavigationCapability(tab.id),
        ),
      );
    }
  }

  void _onControllerChanged() {
    final active = widget.controller.activeTabId;
    if (active != _previousActiveTabId) {
      final old = _previousActiveTabId;
      _previousActiveTabId = active;
      unawaited(WorkspaceLifecycleRegistry.instance.notifyTabBackgrounded(old));
      unawaited(WorkspaceLifecycleRegistry.instance.notifyTabActivated(active));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entries[active]?.focusScopeNode.requestFocus();
      });
    }
    _syncEntries();
    if (mounted) setState(() {});
  }

  void _updateNavigationCapability(WorkspaceTabId tabId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = _entries[tabId]?.navigatorKey.currentState;
      final canPop = navigator?.canPop() ?? false;
      widget.controller.updateNavigationCapability(tabId, canPop);
      if (!canPop) {
        final destination = widget.controller
            .tabById(tabId)
            ?.currentDestination;
        if (destination != null) {
          widget.controller.updateMetadata(
            tabId,
            title: destination.title,
            icon: destination.icon,
            isAudible: false,
          );
        }
      }
    });
  }

  Future<void> closeTab(WorkspaceTabId id) async {
    if (!widget.controller.beginClose(id)) return;
    await WorkspaceLifecycleRegistry.instance.prepareTabToClose(id);
    if (!mounted) return;
    widget.controller.completeClose(id);
  }

  Future<void> closeOthers(WorkspaceTabId keepId) async {
    final ids = widget.controller.tabs
        .where((tab) => tab.id != keepId)
        .map((tab) => tab.id)
        .toList(growable: false);
    for (final id in ids) {
      await closeTab(id);
      if (!mounted) return;
    }
    widget.controller.activate(keepId);
  }

  Future<void> goBack() async {
    final id = widget.controller.activeTabId;
    final navigator = _entries[id]?.navigatorKey.currentState;
    if (navigator != null && await navigator.maybePop()) return;
    widget.controller.back(id);
  }

  void goForward() => widget.controller.forward();

  void open(WorkspaceDestination destination, {WorkspaceTabId? tabId}) {
    widget.controller.navigate(
      tabId ?? widget.controller.activeTabId,
      destination,
    );
  }

  void _cycleTab(bool reverse) {
    final tabs = widget.controller.tabs;
    if (tabs.length < 2) return;
    final current = tabs.indexWhere(
      (tab) => tab.id == widget.controller.activeTabId,
    );
    final delta = reverse ? -1 : 1;
    final next = (current + delta) % tabs.length;
    widget.controller.activate(tabs[next].id);
  }

  Widget _buildDestination(
    BuildContext context,
    WorkspaceDestination destination,
  ) {
    final customBuilder = widget.destinationBuilder;
    if (customBuilder != null) return customBuilder(context, destination);
    if (destination.kind == WorkspaceDestination.homeKind) {
      return const HomeScreen();
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final activeId = widget.controller.activeTabId;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            widget.controller.create,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          unawaited(closeTab(widget.controller.activeTabId));
        },
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () {
          _cycleTab(false);
        },
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () {
          _cycleTab(true);
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final tab in widget.controller.tabs)
              _buildTab(tab, tab.id == activeId),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(WorkspaceTabState tab, bool isActive) {
    final entry = _entries[tab.id]!;
    final visibleDestinations = tab.destinations.take(tab.historyIndex + 1);
    return Offstage(
      key: ValueKey(tab.id),
      offstage: !isActive,
      child: TickerMode(
        enabled: isActive,
        child: FocusScope(
          node: entry.focusScopeNode,
          canRequestFocus: isActive,
          child: IgnorePointer(
            ignoring: !isActive,
            child: WorkspaceTabScope(
              tabId: tab.id,
              controller: widget.controller,
              child: WorkspaceRouteObserverScope(
                observer: entry.routeObserver,
                child: Navigator(
                  key: entry.navigatorKey,
                  observers: <NavigatorObserver>[
                    entry.routeObserver,
                    entry.capabilityObserver,
                  ],
                  pages: <Page<void>>[
                    for (final destination in visibleDestinations)
                      MaterialPage<void>(
                        key: ValueKey(destination.routeId),
                        name: destination.kind,
                        child: Builder(
                          builder: (context) =>
                              _buildDestination(context, destination),
                        ),
                      ),
                  ],
                  onDidRemovePage: (page) {
                    final key = page.key;
                    if (key is! ValueKey<WorkspaceRouteId>) return;
                    final current = widget.controller.tabById(tab.id);
                    if (current?.currentDestination.routeId == key.value) {
                      widget.controller.back(tab.id);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabNavigatorEntry {
  _TabNavigatorEntry({required VoidCallback onNavigationChanged})
    : capabilityObserver = _NavigationCapabilityObserver(onNavigationChanged);

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FocusScopeNode focusScopeNode = FocusScopeNode();
  final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();
  final _NavigationCapabilityObserver capabilityObserver;

  void dispose() => focusScopeNode.dispose();
}

class _NavigationCapabilityObserver extends NavigatorObserver {
  _NavigationCapabilityObserver(this.onChanged);

  final VoidCallback onChanged;

  void _changed() => onChanged();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _changed();
}
