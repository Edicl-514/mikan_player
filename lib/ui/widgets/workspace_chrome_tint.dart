import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:mikan_player/services/bangumi_image_bridge.dart';
import 'package:mikan_player/services/cache/image_cache_service.dart';
import 'package:mikan_player/services/player_session/player_session_identity.dart';
import 'package:mikan_player/services/workspace_page_chrome.dart';
import 'package:mikan_player/ui/utils/dominant_color.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';
import 'package:mikan_player/ui/widgets/workspace_tab_host.dart';

/// Exposes the window-chrome tint the desktop frame computed from the active
/// tab's published page color.
///
/// Installed by [WindowsDesktopFrame] above the title bar and toolbar. `null`
/// means the shell falls back to its theme surface color. Descendants read it
/// with [maybeOf]; pages *publish* a tint with [WorkspaceChromeTintPublisher]
/// rather than reading this.
class WorkspaceChromeTintScope extends InheritedWidget {
  const WorkspaceChromeTintScope({
    super.key,
    required this.tint,
    required super.child,
  });

  final Color? tint;

  static WorkspaceChromeTintScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceChromeTintScope>();

  static Color? tintOf(BuildContext context) => maybeOf(context)?.tint;

  @override
  bool updateShouldNotify(WorkspaceChromeTintScope oldWidget) =>
      oldWidget.tint != tint;
}

/// Owns the tint decision for one workspace route.
///
/// A route without a publisher installs a null barrier so it cannot inherit a
/// stale tint. A publisher temporarily removes that barrier while its image is
/// being resolved, allowing the previous route's tint to bridge the loading
/// period without a flash.
class WorkspaceRouteTintBoundary extends StatefulWidget {
  const WorkspaceRouteTintBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<WorkspaceRouteTintBoundary> createState() =>
      _WorkspaceRouteTintBoundaryState();
}

class _WorkspaceRouteTintBoundaryState extends State<WorkspaceRouteTintBoundary>
    with WorkspaceChromeRouteAware<WorkspaceRouteTintBoundary> {
  final Object _owner = Object();
  final Set<Object> _inheritingPublishers = <Object>{};
  WorkspaceTabId? _tabId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateRouteSubscription(context);
    final tabId = WorkspaceTabScope.maybeOf(context);
    if (tabId != _tabId) {
      _retract();
      _tabId = tabId;
    }
    _syncBarrier();
  }

  void allowInheritance(Object publisher) {
    if (!_inheritingPublishers.add(publisher)) return;
    _syncBarrier();
  }

  void disallowInheritance(Object publisher) {
    if (!_inheritingPublishers.remove(publisher)) return;
    _syncBarrier();
  }

  void _syncBarrier() {
    final tabId = _tabId;
    if (tabId == null) return;
    if (_inheritingPublishers.isNotEmpty) {
      WorkspacePageChromeRegistry.instance.retractTint(tabId, _owner);
    } else if (isRouteVisible) {
      WorkspacePageChromeRegistry.instance.publishTintBarrier(tabId, _owner);
    }
  }

  @override
  void onRouteVisibilityChanged() {
    if (isRouteVisible) _syncBarrier();
  }

  void _retract() {
    final tabId = _tabId;
    if (tabId == null) return;
    WorkspacePageChromeRegistry.instance.retractTint(tabId, _owner);
  }

  @override
  void dispose() {
    _retract();
    disposeRouteSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _WorkspaceRouteTintBoundaryScope(boundary: this, child: widget.child);
}

class _WorkspaceRouteTintBoundaryScope extends InheritedWidget {
  const _WorkspaceRouteTintBoundaryScope({
    required this.boundary,
    required super.child,
  });

  final _WorkspaceRouteTintBoundaryState boundary;

  static _WorkspaceRouteTintBoundaryState? maybeOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<_WorkspaceRouteTintBoundaryScope>()
      ?.boundary;

  @override
  bool updateShouldNotify(_WorkspaceRouteTintBoundaryScope oldWidget) =>
      boundary != oldWidget.boundary;
}

/// Publishes a cover-derived chrome tint for the current tab.
///
/// Wraps a page's image background (the detail page's blurred wallpaper) and,
/// once the cover is available, extracts a dominant color and publishes it to
/// [WorkspacePageChromeRegistry] so the desktop frame can tint its title bar
/// and toolbar. A covering publisher inherits this route's tint while its image
/// is loading, then replaces it with its own color. Routes without a publisher
/// install a [WorkspaceRouteTintBoundary] barrier instead. Renders nothing
/// itself.
class WorkspaceChromeTintPublisher extends StatefulWidget {
  const WorkspaceChromeTintPublisher({
    super.key,
    required this.imageUrl,
    required this.child,
  });

  final String? imageUrl;
  final Widget child;

  // Shared across instances so reopening a page with a familiar cover reuses
  // the computed tint instead of re-decoding the image.
  static final Map<String, Color?> _chromeCache = <String, Color?>{};
  static const int _chromeCacheMax = 96;

  /// Test seam: short-circuits extraction with a fixed chrome color, so tests
  /// can exercise the publish lifecycle without image bytes.
  @visibleForTesting
  static FutureOr<Color?> Function(String url)? debugChromeOverride;

  @visibleForTesting
  static void debugResetForTest() {
    debugChromeOverride = null;
    _chromeCache.clear();
  }

  @override
  State<WorkspaceChromeTintPublisher> createState() =>
      _WorkspaceChromeTintPublisherState();
}

class _WorkspaceChromeTintPublisherState
    extends State<WorkspaceChromeTintPublisher>
    with WorkspaceChromeRouteAware<WorkspaceChromeTintPublisher> {
  final Object _owner = Object();
  WorkspaceTabId? _tabId;
  _WorkspaceRouteTintBoundaryState? _boundary;
  bool _allowsInheritance = false;
  Color? _chrome;
  bool _extracting = false;
  int _extractionGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateRouteSubscription(context);
    final boundary = _WorkspaceRouteTintBoundaryScope.maybeOf(context);
    if (boundary != _boundary) {
      if (_allowsInheritance) _boundary?.disallowInheritance(_owner);
      _boundary = boundary;
      if (_allowsInheritance) _boundary?.allowInheritance(_owner);
    }
    _syncTabAndPublish();
  }

  @override
  void didUpdateWidget(WorkspaceChromeTintPublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retract();
      _setAllowsInheritance(false);
      _extractionGeneration++;
      _extracting = false;
      _chrome = null;
      _syncTabAndPublish();
    }
  }

  @override
  void dispose() {
    _retract();
    _setAllowsInheritance(false);
    disposeRouteSubscription();
    super.dispose();
  }

  @override
  void onRouteVisibilityChanged() {
    // Never retract on cover: tints stack per tab (see
    // [WorkspacePageChromeRegistry]), so a covering route without a tint yet
    // falls back to this route's tint instead of dropping to the shell surface
    // (a white flash in light mode). The covering route's own tint replaces it
    // once published; this tint resurfaces when the cover pops. It is retracted
    // on dispose (route popped) or on image URL change below.
    if (isRouteVisible) {
      _publishFromState();
    }
  }

  void _syncTabAndPublish() {
    final tabId = WorkspaceTabScope.maybeOf(context);
    if (tabId != _tabId) {
      _retract();
      _extractionGeneration++;
      _extracting = false;
      _tabId = tabId;
    }
    if (tabId != null && isRouteVisible) _publishFromState();
  }

  void _publishFromState() {
    final tabId = _tabId;
    if (tabId == null || !isRouteVisible) return;
    final chrome = _chrome;
    if (chrome != null) {
      _setAllowsInheritance(true);
      WorkspacePageChromeRegistry.instance.publishTint(tabId, _owner, chrome);
      return;
    }
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      _setAllowsInheritance(false);
      return;
    }
    _setAllowsInheritance(true);
    if (_extracting) return;
    _extracting = true;
    unawaited(_extract(url, tabId));
  }

  Future<void> _extract(String url, WorkspaceTabId tabId) async {
    final generation = ++_extractionGeneration;
    final chrome = await _chromeForUrl(url);
    if (!mounted || generation != _extractionGeneration || _tabId != tabId) {
      return;
    }
    _extracting = false;
    _chrome = chrome;
    if (chrome == null) {
      _setAllowsInheritance(false);
      return;
    }
    if (!isRouteVisible) return;
    WorkspacePageChromeRegistry.instance.publishTint(tabId, _owner, chrome);
  }

  void _retract() {
    final tabId = _tabId;
    if (tabId == null) return;
    WorkspacePageChromeRegistry.instance.retractTint(tabId, _owner);
  }

  void _setAllowsInheritance(bool value) {
    if (_allowsInheritance == value) return;
    _allowsInheritance = value;
    if (value) {
      _boundary?.allowInheritance(_owner);
    } else {
      _boundary?.disallowInheritance(_owner);
    }
  }

  Future<Color?> _chromeForUrl(String url) async {
    final override = WorkspaceChromeTintPublisher.debugChromeOverride;
    if (override != null) return await override(url);
    final cache = WorkspaceChromeTintPublisher._chromeCache;
    final cached = cache[url];
    if (cached != null) return cached;
    final chrome = await _resolveChrome(url);
    if (chrome != null) {
      cache[url] = chrome;
      if (cache.length > WorkspaceChromeTintPublisher._chromeCacheMax) {
        cache.remove(cache.keys.first);
      }
    }
    return chrome;
  }

  Future<Color?> _resolveChrome(String url) async {
    final bytes = await _imageBytes(url);
    if (bytes == null || bytes.isEmpty) return null;
    final dominant = await extractDominantColor(bytes);
    if (dominant == null) return null;
    return deriveChromeBackground(dominant);
  }

  Future<Uint8List?> _imageBytes(String url) async {
    try {
      final cache = ImageCacheService.instance;
      if (!cache.isInitialized) await cache.initialize();
      var path = await cache.getCachedPath(url);
      path ??= await cache.cacheImage(url);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) return await file.readAsBytes();
      }
    } catch (_) {
      // Fall through to the bridge.
    }
    try {
      return await BangumiImageBridge.fetchFromUrl(url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
