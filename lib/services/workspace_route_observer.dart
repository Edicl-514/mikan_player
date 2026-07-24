import 'package:flutter/material.dart';

/// Observes full page navigation while deliberately ignoring dialogs, menus,
/// and bottom sheets layered over the current player route.
final RouteObserver<PageRoute<dynamic>> workspaceRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
