import 'package:flutter/material.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/services/workspace_route_observer.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';

/// Declares which parts of a page header the surrounding desktop shell already
/// draws, so pages can drop their own duplicates.
///
/// Presence of this scope is the capability signal: it is installed by the
/// workspace tab host, which only runs where the desktop frame is active. Pages
/// must never substitute a width breakpoint for it — a narrow Windows window is
/// still a desktop window, and a wide phone is still a phone.
///
/// The host installs it per tab destination, so a route pushed imperatively on
/// top of one keeps its own `AppBar`: the tab title still names the destination
/// underneath it. Such a route can drop just its back button — which the shell
/// toolbar already provides via `maybePop` — by overriding the scope with
/// `providesTitle: false`, or publish its own title with [WorkspaceRouteTitle].
class DesktopPageChromeScope extends InheritedWidget {
  const DesktopPageChromeScope({
    super.key,
    this.providesNavigation = true,
    this.providesTitle = true,
    required super.child,
  });

  /// The shell owns Back/Forward for the current route.
  final bool providesNavigation;

  /// The shell owns the route title.
  final bool providesTitle;

  static DesktopPageChromeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopPageChromeScope>();

  /// Whether a desktop shell is hosting this page at all.
  static bool isHosted(BuildContext context) => maybeOf(context) != null;

  /// Whether the shell already draws a back affordance for this route.
  static bool hostsNavigation(BuildContext context) =>
      maybeOf(context)?.providesNavigation ?? false;

  /// Whether the shell already draws this route's title.
  static bool hostsTitle(BuildContext context) =>
      maybeOf(context)?.providesTitle ?? false;

  /// Whether the page should skip its own `AppBar` entirely.
  ///
  /// Pages whose header carries business actions still need somewhere to put
  /// them — see [DesktopPageScaffold] and [DesktopPageActionRow].
  static bool hostsPageHeader(BuildContext context) {
    final scope = maybeOf(context);
    return scope != null && scope.providesNavigation && scope.providesTitle;
  }

  @override
  bool updateShouldNotify(DesktopPageChromeScope oldWidget) =>
      providesNavigation != oldWidget.providesNavigation ||
      providesTitle != oldWidget.providesTitle;
}

/// Shared spacing for desktop pages that no longer own an `AppBar`.
///
/// The frame already contributes [shellChromeHeight] above the page, so pages
/// must not keep padding that was reserved for their removed toolbar.
class DesktopPageMetrics {
  const DesktopPageMetrics._();

  /// Title bar (40) + context toolbar (42) drawn by the desktop frame.
  static const double shellChromeHeight = 82;

  /// Height of a single-line page action row.
  static const double actionRowHeight = 48;

  /// Top inset for page content once the page owns no toolbar.
  ///
  /// Zero on purpose: the shell's toolbar is the visual separator, so any extra
  /// gap here reads as an empty strip above the first list item.
  static const double contentTopInset = 0;

  static const EdgeInsets actionRowPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 4,
  );

  /// Replaces a navigation bar's `kToolbarHeight`-based top padding.
  ///
  /// Immersive pages remove their transparent `AppBar` as soon as the shell
  /// owns navigation, even when the route keeps publishing its own title.
  /// Match that condition here so a navigation-only scope cannot leave behind
  /// an empty toolbar-height strip. Non-hosted pages keep the inset required by
  /// their own `AppBar`.
  static double navigationTopInsetFor(
    BuildContext context, {
    required double reserved,
  }) => DesktopPageChromeScope.hostsNavigation(context)
      ? contentTopInset
      : reserved;
}

/// Publishes a route title to the desktop shell.
///
/// The tab's [WorkspaceDestination] title stays the base value; this only
/// refines it for the lifetime of the route (an episode suffix, a resolved
/// entity name). Retracting restores whatever the shell would otherwise show,
/// which keeps async opens and forward-history rebuilds correct without the
/// page tracking navigation itself.
class WorkspaceRouteTitle extends StatefulWidget {
  const WorkspaceRouteTitle({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  State<WorkspaceRouteTitle> createState() => _WorkspaceRouteTitleState();
}

class _WorkspaceRouteTitleState extends State<WorkspaceRouteTitle>
    with WorkspaceChromeRouteAware<WorkspaceRouteTitle> {
  final Object _owner = Object();
  WorkspaceTabId? _tabId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateRouteSubscription(context);
    _publish(WorkspaceTabScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(WorkspaceRouteTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _publish(_tabId);
  }

  @override
  void dispose() {
    _retract();
    disposeRouteSubscription();
    super.dispose();
  }

  void _publish(WorkspaceTabId? tabId) {
    if (tabId != _tabId) _retract();
    _tabId = tabId;
    if (tabId == null || !isRouteVisible) return;
    WorkspacePageChromeRegistry.instance.publishTitle(
      tabId,
      _owner,
      widget.title,
    );
  }

  @override
  void onRouteVisibilityChanged() {
    if (isRouteVisible) {
      _publish(_tabId);
    } else {
      _retract();
    }
  }

  void _retract() {
    final tabId = _tabId;
    if (tabId == null) return;
    WorkspacePageChromeRegistry.instance.retractTitle(tabId, _owner);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Publishes trailing actions into the shell's context toolbar.
///
/// Reserved for operations that must stay reachable while the page's own
/// content scrolls — the player's download/copy pair is the motivating case.
/// Everything else belongs in a [DesktopPageActionRow] next to what it acts on,
/// where it cannot crowd out the tab title.
class WorkspaceToolbarActions extends StatefulWidget {
  const WorkspaceToolbarActions({
    super.key,
    required this.builder,
    required this.child,
  });

  final WorkspaceToolbarActionBuilder builder;
  final Widget child;

  @override
  State<WorkspaceToolbarActions> createState() =>
      _WorkspaceToolbarActionsState();
}

class _WorkspaceToolbarActionsState extends State<WorkspaceToolbarActions>
    with WorkspaceChromeRouteAware<WorkspaceToolbarActions> {
  final Object _owner = Object();
  WorkspaceTabId? _tabId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateRouteSubscription(context);
    _publish(WorkspaceTabScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(WorkspaceToolbarActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.builder != widget.builder) _publish(_tabId);
  }

  @override
  void dispose() {
    _retract();
    disposeRouteSubscription();
    super.dispose();
  }

  void _publish(WorkspaceTabId? tabId) {
    if (tabId != _tabId) _retract();
    _tabId = tabId;
    if (tabId == null || !isRouteVisible) return;
    WorkspacePageChromeRegistry.instance.publishToolbarActions(
      tabId,
      _owner,
      widget.builder,
    );
  }

  @override
  void onRouteVisibilityChanged() {
    if (isRouteVisible) {
      _publish(_tabId);
    } else {
      _retract();
    }
  }

  void _retract() {
    final tabId = _tabId;
    if (tabId == null) return;
    WorkspacePageChromeRegistry.instance.retractToolbarActions(tabId, _owner);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Route-visibility plumbing for widgets that publish page chrome.
///
/// Publishes are only valid while the widget's route is the current one, so
/// these states subscribe to the nearest [RouteObserver] and expose
/// [isRouteVisible] plus the lifecycle overrides to run the publish/retract
/// dance. Pages must call [updateRouteSubscription] from
/// `didChangeDependencies` and [disposeRouteSubscription] from `dispose`.
mixin WorkspaceChromeRouteAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  RouteObserver<PageRoute<dynamic>> _routeObserver = workspaceRouteObserver;
  PageRoute<dynamic>? _subscribedRoute;
  bool _isRouteVisible = true;

  bool get isRouteVisible => _isRouteVisible;

  void updateRouteSubscription(BuildContext context) {
    final modalRoute = ModalRoute.of(context);
    final route = modalRoute is PageRoute<dynamic> ? modalRoute : null;
    final observer =
        WorkspaceRouteObserverScope.maybeOf(context) ?? workspaceRouteObserver;
    if (route == _subscribedRoute && observer == _routeObserver) return;
    final previous = _subscribedRoute;
    if (previous != null) _routeObserver.unsubscribe(this);
    _routeObserver = observer;
    _subscribedRoute = route;
    if (route != null) {
      _routeObserver.subscribe(this, route);
      _setRouteVisible(route.isCurrent);
    } else {
      _setRouteVisible(true);
    }
  }

  void disposeRouteSubscription() {
    final route = _subscribedRoute;
    if (route != null) _routeObserver.unsubscribe(this);
    _subscribedRoute = null;
  }

  void _setRouteVisible(bool value) {
    if (_isRouteVisible == value) return;
    _isRouteVisible = value;
    onRouteVisibilityChanged();
  }

  void onRouteVisibilityChanged();

  @override
  void didPush() => _setRouteVisible(true);

  @override
  void didPushNext() => _setRouteVisible(false);

  @override
  void didPopNext() => _setRouteVisible(true);

  @override
  void didPop() => _setRouteVisible(false);
}
