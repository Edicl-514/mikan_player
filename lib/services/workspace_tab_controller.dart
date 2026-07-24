import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

class WorkspaceRouteId {
  const WorkspaceRouteId(this.value);

  factory WorkspaceRouteId.allocate() => WorkspaceRouteId('route-${++_next}');

  final String value;
  static int _next = 0;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceRouteId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum WorkspaceTabIcon { home, page, media }

@immutable
class WorkspaceDestination {
  const WorkspaceDestination({
    required this.routeId,
    required this.kind,
    required this.title,
    this.icon = WorkspaceTabIcon.page,
    this.arguments = const <String, Object?>{},
  });

  factory WorkspaceDestination.home({String title = 'Home'}) {
    return WorkspaceDestination(
      routeId: WorkspaceRouteId.allocate(),
      kind: homeKind,
      title: title,
      icon: WorkspaceTabIcon.home,
    );
  }

  static const String homeKind = 'home';

  final WorkspaceRouteId routeId;
  final String kind;
  final String title;
  final WorkspaceTabIcon icon;
  final Map<String, Object?> arguments;
}

@immutable
class WorkspaceTabState {
  const WorkspaceTabState({
    required this.id,
    required this.destinations,
    required this.historyIndex,
    required this.title,
    required this.icon,
    this.isAudible = false,
    this.isClosing = false,
    this.navigatorCanPop = false,
  });

  final WorkspaceTabId id;
  final List<WorkspaceDestination> destinations;
  final int historyIndex;
  final String title;
  final WorkspaceTabIcon icon;
  final bool isAudible;
  final bool isClosing;
  final bool navigatorCanPop;

  WorkspaceDestination get currentDestination => destinations[historyIndex];
  bool get canGoBack => navigatorCanPop || historyIndex > 0;
  bool get canGoForward => historyIndex + 1 < destinations.length;

  WorkspaceTabState copyWith({
    List<WorkspaceDestination>? destinations,
    int? historyIndex,
    String? title,
    WorkspaceTabIcon? icon,
    bool? isAudible,
    bool? isClosing,
    bool? navigatorCanPop,
  }) {
    return WorkspaceTabState(
      id: id,
      destinations: destinations ?? this.destinations,
      historyIndex: historyIndex ?? this.historyIndex,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      isAudible: isAudible ?? this.isAudible,
      isClosing: isClosing ?? this.isClosing,
      navigatorCanPop: navigatorCanPop ?? this.navigatorCanPop,
    );
  }
}

class WorkspaceTabController extends ChangeNotifier {
  WorkspaceTabController({String homeTitle = 'Home'}) : _homeTitle = homeTitle {
    final first = _newTabState();
    _tabs = <WorkspaceTabState>[first];
    _activeTabId = first.id;
  }

  String _homeTitle;
  List<WorkspaceTabState> _tabs = const <WorkspaceTabState>[];
  late WorkspaceTabId _activeTabId;
  int _nextTabId = 0;

  List<WorkspaceTabState> get tabs => List.unmodifiable(_tabs);
  WorkspaceTabId get activeTabId => _activeTabId;
  WorkspaceTabState get activeTab => tabById(_activeTabId)!;

  WorkspaceTabState? tabById(WorkspaceTabId id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  WorkspaceTabId create({
    bool activate = true,
    WorkspaceDestination? initialDestination,
  }) {
    final tab = _newTabState(initialDestination: initialDestination);
    _tabs = <WorkspaceTabState>[..._tabs, tab];
    if (activate) _activeTabId = tab.id;
    notifyListeners();
    return tab.id;
  }

  void activate(WorkspaceTabId id) {
    final tab = tabById(id);
    if (tab == null || tab.isClosing || id == _activeTabId) return;
    _activeTabId = id;
    notifyListeners();
  }

  bool beginClose(WorkspaceTabId id) {
    final tab = tabById(id);
    if (tab == null || tab.isClosing) return false;
    _replace(id, tab.copyWith(isClosing: true));
    notifyListeners();
    return true;
  }

  void completeClose(WorkspaceTabId id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final wasActive = _activeTabId == id;
    final next = [..._tabs]..removeAt(index);
    if (next.isEmpty) next.add(_newTabState());
    _tabs = next;
    if (wasActive) {
      _activeTabId = next[index.clamp(0, next.length - 1)].id;
    }
    notifyListeners();
  }

  void close(WorkspaceTabId id) {
    if (beginClose(id)) completeClose(id);
  }

  void closeOthers(WorkspaceTabId keepId) {
    if (tabById(keepId) == null) return;
    _tabs = <WorkspaceTabState>[tabById(keepId)!];
    _activeTabId = keepId;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length || newIndex == oldIndex) {
      return;
    }
    final next = [..._tabs];
    final tab = next.removeAt(oldIndex);
    next.insert(newIndex, tab);
    _tabs = next;
    notifyListeners();
  }

  void navigate(WorkspaceTabId id, WorkspaceDestination destination) {
    final tab = tabById(id);
    if (tab == null || tab.isClosing) return;
    final history = tab.destinations.sublist(0, tab.historyIndex + 1)
      ..add(destination);
    _replace(
      id,
      tab.copyWith(
        destinations: List.unmodifiable(history),
        historyIndex: history.length - 1,
        title: destination.title,
        icon: destination.icon,
        navigatorCanPop: true,
      ),
    );
    notifyListeners();
  }

  bool back([WorkspaceTabId? id]) {
    final tabId = id ?? _activeTabId;
    final tab = tabById(tabId);
    if (tab == null || tab.historyIndex == 0) return false;
    final index = tab.historyIndex - 1;
    final destination = tab.destinations[index];
    _replace(
      tabId,
      tab.copyWith(
        historyIndex: index,
        title: destination.title,
        icon: destination.icon,
        navigatorCanPop: index > 0,
      ),
    );
    notifyListeners();
    return true;
  }

  bool forward([WorkspaceTabId? id]) {
    final tabId = id ?? _activeTabId;
    final tab = tabById(tabId);
    if (tab == null || !tab.canGoForward) return false;
    final index = tab.historyIndex + 1;
    final destination = tab.destinations[index];
    _replace(
      tabId,
      tab.copyWith(
        historyIndex: index,
        title: destination.title,
        icon: destination.icon,
        navigatorCanPop: true,
      ),
    );
    notifyListeners();
    return true;
  }

  void updateMetadata(
    WorkspaceTabId id, {
    String? title,
    WorkspaceTabIcon? icon,
    bool? isAudible,
  }) {
    final tab = tabById(id);
    if (tab == null) return;
    if ((title == null || title == tab.title) &&
        (icon == null || icon == tab.icon) &&
        (isAudible == null || isAudible == tab.isAudible)) {
      return;
    }
    _replace(id, tab.copyWith(title: title, icon: icon, isAudible: isAudible));
    notifyListeners();
  }

  void updateNavigationCapability(WorkspaceTabId id, bool canPop) {
    final tab = tabById(id);
    if (tab == null || tab.navigatorCanPop == canPop) return;
    _replace(id, tab.copyWith(navigatorCanPop: canPop));
    notifyListeners();
  }

  void updateHomeTitle(String value) {
    if (value == _homeTitle) return;
    _homeTitle = value;
    for (final tab in _tabs) {
      if (tab.destinations.length == 1 &&
          tab.currentDestination.kind == WorkspaceDestination.homeKind) {
        final home = tab.currentDestination;
        final localizedHome = WorkspaceDestination(
          routeId: home.routeId,
          kind: home.kind,
          title: value,
          icon: home.icon,
          arguments: home.arguments,
        );
        _replace(
          tab.id,
          tab.copyWith(
            destinations: <WorkspaceDestination>[localizedHome],
            title: value,
          ),
        );
      }
    }
    notifyListeners();
  }

  WorkspaceTabState _newTabState({WorkspaceDestination? initialDestination}) {
    final destination =
        initialDestination ?? WorkspaceDestination.home(title: _homeTitle);
    return WorkspaceTabState(
      id: WorkspaceTabId('workspace-${++_nextTabId}'),
      destinations: <WorkspaceDestination>[destination],
      historyIndex: 0,
      title: destination.title,
      icon: destination.icon,
    );
  }

  void _replace(WorkspaceTabId id, WorkspaceTabState replacement) {
    _tabs = <WorkspaceTabState>[
      for (final tab in _tabs)
        if (tab.id == id) replacement else tab,
    ];
  }
}
