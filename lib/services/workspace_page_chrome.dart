import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';

/// Builds a widget in the desktop frame's context, not the publishing page's.
///
/// Builders run above the workspace navigator, so they may read theme and
/// localizations but must not depend on page-local inherited widgets.
typedef WorkspaceToolbarActionBuilder = Widget Function(BuildContext context);

@immutable
class WorkspaceToolbarActionEntry {
  const WorkspaceToolbarActionEntry({required this.owner, required this.build});

  final Object owner;
  final WorkspaceToolbarActionBuilder build;
}

@immutable
class _TitleEntry {
  const _TitleEntry({required this.owner, required this.title});

  final Object owner;
  final String title;
}

/// Page-published chrome for the Windows workspace shell.
///
/// Routes live inside a tab's navigator while the title bar and context
/// toolbar live above it, so page contributions travel through this registry
/// instead of the widget tree. Titles are a stack: the topmost live route wins
/// and retracting it falls back to the next one, and finally to the tab's
/// [WorkspaceDestination] title.
class WorkspacePageChromeRegistry extends ChangeNotifier {
  WorkspacePageChromeRegistry._();

  static final WorkspacePageChromeRegistry instance =
      WorkspacePageChromeRegistry._();

  final Map<WorkspaceTabId, List<_TitleEntry>> _titles =
      <WorkspaceTabId, List<_TitleEntry>>{};
  final Map<WorkspaceTabId, List<WorkspaceToolbarActionEntry>> _toolbarActions =
      <WorkspaceTabId, List<WorkspaceToolbarActionEntry>>{};

  /// The title the topmost live route published for [tabId], if any.
  String? titleFor(WorkspaceTabId tabId) {
    final entries = _titles[tabId];
    if (entries == null || entries.isEmpty) return null;
    return entries.last.title;
  }

  List<WorkspaceToolbarActionEntry> toolbarActionsFor(WorkspaceTabId tabId) {
    final entries = _toolbarActions[tabId];
    if (entries == null || entries.isEmpty) {
      return const <WorkspaceToolbarActionEntry>[];
    }
    return List<WorkspaceToolbarActionEntry>.unmodifiable(entries);
  }

  void publishTitle(WorkspaceTabId tabId, Object owner, String title) {
    final entries = _titles.putIfAbsent(tabId, () => <_TitleEntry>[]);
    final index = entries.indexWhere((entry) => entry.owner == owner);
    if (index >= 0) {
      if (entries[index].title == title) return;
      entries[index] = _TitleEntry(owner: owner, title: title);
    } else {
      entries.add(_TitleEntry(owner: owner, title: title));
    }
    _notify();
  }

  void retractTitle(WorkspaceTabId tabId, Object owner) {
    final entries = _titles[tabId];
    if (entries == null) return;
    final removed = entries.length;
    entries.removeWhere((entry) => entry.owner == owner);
    if (entries.length == removed) return;
    if (entries.isEmpty) _titles.remove(tabId);
    _notify();
  }

  void publishToolbarActions(
    WorkspaceTabId tabId,
    Object owner,
    WorkspaceToolbarActionBuilder build,
  ) {
    final entries = _toolbarActions.putIfAbsent(
      tabId,
      () => <WorkspaceToolbarActionEntry>[],
    );
    final entry = WorkspaceToolbarActionEntry(owner: owner, build: build);
    final index = entries.indexWhere((existing) => existing.owner == owner);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    _notify();
  }

  void retractToolbarActions(WorkspaceTabId tabId, Object owner) {
    final entries = _toolbarActions[tabId];
    if (entries == null) return;
    final removed = entries.length;
    entries.removeWhere((entry) => entry.owner == owner);
    if (entries.length == removed) return;
    if (entries.isEmpty) _toolbarActions.remove(tabId);
    _notify();
  }

  /// Drops everything a closed tab published.
  void clearTab(WorkspaceTabId tabId) {
    final hadTitle = _titles.remove(tabId) != null;
    final hadActions = _toolbarActions.remove(tabId) != null;
    if (hadTitle || hadActions) _notify();
  }

  @visibleForTesting
  void debugReset() {
    _titles.clear();
    _toolbarActions.clear();
  }

  /// Pages publish from `initState`/`didChangeDependencies`/`dispose`, which can
  /// run while the frame above them has already built this frame. Defer the
  /// notification so listeners are never marked dirty mid-build.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }
}
