import 'package:flutter/material.dart';

/// Observes full page navigation while deliberately ignoring dialogs, menus,
/// and bottom sheets layered over the current player route.
final RouteObserver<PageRoute<dynamic>> workspaceRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class WorkspaceRouteObserverScope extends InheritedWidget {
  const WorkspaceRouteObserverScope({
    super.key,
    required this.observer,
    required super.child,
  });

  final RouteObserver<PageRoute<dynamic>> observer;

  static RouteObserver<PageRoute<dynamic>>? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkspaceRouteObserverScope>()
          ?.observer;

  @override
  bool updateShouldNotify(WorkspaceRouteObserverScope oldWidget) =>
      observer != oldWidget.observer;
}
