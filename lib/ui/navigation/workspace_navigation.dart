import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/workspace_tab_controller.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/about_page.dart';
import 'package:mikan_player/ui/pages/bangumi_details_page.dart';
import 'package:mikan_player/ui/pages/character_detail_page.dart';
import 'package:mikan_player/ui/pages/data_source_settings_page.dart';
import 'package:mikan_player/ui/pages/download_settings_page.dart';
import 'package:mikan_player/ui/pages/favorites_page.dart';
import 'package:mikan_player/ui/pages/history_page.dart';
import 'package:mikan_player/ui/pages/index_page.dart';
import 'package:mikan_player/ui/pages/network_settings_page.dart';
import 'package:mikan_player/ui/pages/my_page.dart';
import 'package:mikan_player/ui/pages/person_detail_page.dart';
import 'package:mikan_player/ui/pages/player_page.dart';
import 'package:mikan_player/ui/pages/ranking_page.dart';
import 'package:mikan_player/ui/pages/search_page.dart';
import 'package:mikan_player/ui/pages/search_settings_page.dart';
import 'package:mikan_player/ui/pages/settings_page.dart';
import 'package:mikan_player/ui/pages/subscription_debug_page.dart';
import 'package:mikan_player/ui/pages/tag_browse_page.dart';
import 'package:mikan_player/ui/pages/theme_settings_page.dart';
import 'package:mikan_player/ui/pages/timetable_page.dart';
import 'package:mikan_player/ui/screens/home_screen.dart';

enum WorkspaceOpenDisposition { currentTab, backgroundTab }

typedef WorkspaceOpenCallback = void Function(WorkspaceDestination destination);

class WorkspaceNavigationScope extends InheritedWidget {
  const WorkspaceNavigationScope({
    super.key,
    required this.openCurrent,
    required this.openBackground,
    required super.child,
  });

  final WorkspaceOpenCallback openCurrent;
  final WorkspaceOpenCallback openBackground;

  static WorkspaceNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceNavigationScope>();

  @override
  bool updateShouldNotify(WorkspaceNavigationScope oldWidget) =>
      openCurrent != oldWidget.openCurrent ||
      openBackground != oldWidget.openBackground;
}

class WorkspaceNavigation {
  const WorkspaceNavigation._();

  static const Object _dispositionZoneKey = Object();

  static T dispatchLink<T>(
    WorkspaceOpenDisposition disposition,
    T Function() action,
  ) => runZoned(
    action,
    zoneValues: <Object, Object>{_dispositionZoneKey: disposition},
  );

  static Future<T?> open<T>(
    BuildContext context,
    WorkspaceDestination destination, {
    WorkspaceOpenDisposition? disposition,
  }) {
    final effectiveDisposition =
        disposition ??
        Zone.current[_dispositionZoneKey] as WorkspaceOpenDisposition? ??
        WorkspaceOpenDisposition.currentTab;
    final scope = WorkspaceNavigationScope.maybeOf(context);
    if (scope != null) {
      switch (effectiveDisposition) {
        case WorkspaceOpenDisposition.currentTab:
          scope.openCurrent(destination);
          return Future<T?>.value();
        case WorkspaceOpenDisposition.backgroundTab:
          scope.openBackground(destination);
          return Future<T?>.value();
      }
    }
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        settings: RouteSettings(name: destination.kind),
        builder: (context) => buildWorkspaceDestination(context, destination),
      ),
    );
  }

  /// Result-bearing editors remain imperative and in the current navigator.
  static Future<T?> pushForResult<T>(
    BuildContext context,
    WorkspaceDestination destination,
  ) => Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      settings: RouteSettings(name: destination.kind),
      builder: (context) => buildWorkspaceDestination(context, destination),
    ),
  );
}

typedef WorkspaceLinkBuilder =
    Widget Function(BuildContext context, VoidCallback activate);
typedef WorkspaceDispositionCallback =
    void Function(WorkspaceOpenDisposition disposition);

/// Adds browser-style pointer semantics to an existing Material link surface.
class WorkspaceLink extends StatefulWidget {
  const WorkspaceLink({
    super.key,
    required this.destination,
    required this.builder,
  });

  final WorkspaceDestination destination;
  final WorkspaceLinkBuilder builder;

  @override
  State<WorkspaceLink> createState() => _WorkspaceLinkState();
}

class _WorkspaceLinkState extends State<WorkspaceLink> {
  int? _middlePointer;
  int? _primaryPointer;
  WorkspaceOpenDisposition? _primaryDisposition;

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kMiddleMouseButton) {
      _middlePointer = event.pointer;
      return;
    }
    if (event.buttons == kPrimaryMouseButton &&
        event.kind == PointerDeviceKind.mouse) {
      _primaryPointer = event.pointer;
      _primaryDisposition = HardwareKeyboard.instance.isControlPressed
          ? WorkspaceOpenDisposition.backgroundTab
          : WorkspaceOpenDisposition.currentTab;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_middlePointer == event.pointer) {
      _middlePointer = null;
      WorkspaceNavigation.open<void>(
        context,
        widget.destination,
        disposition: WorkspaceOpenDisposition.backgroundTab,
      );
    }
    if (_primaryPointer == event.pointer) {
      scheduleMicrotask(() {
        if (_primaryPointer != event.pointer) return;
        _primaryPointer = null;
        _primaryDisposition = null;
      });
    }
  }

  void _activate() {
    final disposition =
        _primaryDisposition ?? WorkspaceOpenDisposition.currentTab;
    _primaryPointer = null;
    _primaryDisposition = null;
    WorkspaceNavigation.open<void>(
      context,
      widget.destination,
      disposition: disposition,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerUp: _onPointerUp,
    onPointerCancel: (_) {
      _middlePointer = null;
      _primaryPointer = null;
      _primaryDisposition = null;
    },
    child: widget.builder(context, _activate),
  );
}

/// Browser-style link handling for destinations resolved asynchronously.
class WorkspaceLinkAction extends StatefulWidget {
  const WorkspaceLinkAction({
    super.key,
    required this.onOpen,
    required this.builder,
  });

  final WorkspaceDispositionCallback onOpen;
  final WorkspaceLinkBuilder builder;

  @override
  State<WorkspaceLinkAction> createState() => _WorkspaceLinkActionState();
}

class _WorkspaceLinkActionState extends State<WorkspaceLinkAction> {
  int? _middlePointer;
  int? _primaryPointer;
  WorkspaceOpenDisposition? _primaryDisposition;

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kMiddleMouseButton) {
      _middlePointer = event.pointer;
    } else if (event.buttons == kPrimaryMouseButton &&
        event.kind == PointerDeviceKind.mouse) {
      _primaryPointer = event.pointer;
      _primaryDisposition = HardwareKeyboard.instance.isControlPressed
          ? WorkspaceOpenDisposition.backgroundTab
          : WorkspaceOpenDisposition.currentTab;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_middlePointer == event.pointer) {
      _middlePointer = null;
      widget.onOpen(WorkspaceOpenDisposition.backgroundTab);
    }
    if (_primaryPointer == event.pointer) {
      scheduleMicrotask(() {
        if (_primaryPointer != event.pointer) return;
        _primaryPointer = null;
        _primaryDisposition = null;
      });
    }
  }

  void _activate() {
    widget.onOpen(_primaryDisposition ?? WorkspaceOpenDisposition.currentTab);
    _primaryPointer = null;
    _primaryDisposition = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerUp: _onPointerUp,
    onPointerCancel: (_) {
      _middlePointer = null;
      _primaryPointer = null;
      _primaryDisposition = null;
    },
    child: widget.builder(context, _activate),
  );
}

class WorkspaceDestinations {
  const WorkspaceDestinations._();

  static WorkspaceDestination _create(
    String kind,
    String title, {
    WorkspaceTabIcon icon = WorkspaceTabIcon.page,
    Map<String, Object?> arguments = const <String, Object?>{},
  }) => WorkspaceDestination(
    routeId: WorkspaceRouteId.allocate(),
    kind: kind,
    title: title,
    icon: icon,
    arguments: arguments,
  );

  static WorkspaceDestination home(BuildContext context) =>
      WorkspaceDestination.home(title: AppLocalizations.of(context).navHome);

  static WorkspaceDestination search(
    BuildContext context, {
    String? initialKeyword,
    String? initialTag,
  }) => _create(
    'search',
    AppLocalizations.of(context).searchHint,
    arguments: {'initialKeyword': initialKeyword, 'initialTag': initialTag},
  );

  static WorkspaceDestination ranking(BuildContext context) =>
      _create('ranking', AppLocalizations.of(context).rankingTitle);

  static WorkspaceDestination timetable(BuildContext context) =>
      _create('timetable', AppLocalizations.of(context).navTimetable);

  static WorkspaceDestination index(BuildContext context) =>
      _create('index', AppLocalizations.of(context).navIndex);

  static WorkspaceDestination history(BuildContext context) =>
      _create('history', AppLocalizations.of(context).historyTitle);

  static WorkspaceDestination favorites(BuildContext context) =>
      _create('favorites', AppLocalizations.of(context).favoritesTitle);

  static WorkspaceDestination settings(BuildContext context) =>
      _create('settings', AppLocalizations.of(context).navSettings);

  static WorkspaceDestination downloads(BuildContext context) =>
      _create('downloads', AppLocalizations.of(context).downloadTitle);

  static WorkspaceDestination about(BuildContext context) =>
      _create('about', AppLocalizations.of(context).aboutTitle);

  static WorkspaceDestination dataSourceSettings(BuildContext context) =>
      _create(
        'settings.dataSource',
        AppLocalizations.of(context).dataSourceSettings,
      );

  static WorkspaceDestination networkSettings(BuildContext context) =>
      _create('settings.network', AppLocalizations.of(context).networkSettings);

  static WorkspaceDestination searchSettings(BuildContext context) =>
      _create('settings.search', AppLocalizations.of(context).searchSettings);

  static WorkspaceDestination subscriptionDebug(BuildContext context) =>
      _create(
        'settings.subscriptionDebug',
        AppLocalizations.of(context).subscriptionDebugEntryTitle,
      );

  static WorkspaceDestination downloadSettings(BuildContext context) => _create(
    'settings.download',
    AppLocalizations.of(context).downloadSettingsTitle,
  );

  static WorkspaceDestination themeSettings(BuildContext context) =>
      _create('settings.theme', AppLocalizations.of(context).themeSettings);

  static WorkspaceDestination bangumiDetails({
    required AnimeInfo anime,
    String? heroTag,
    bool enableCharacterHero = true,
  }) => _create(
    'bangumi',
    anime.title,
    arguments: {
      'anime': anime,
      'heroTag': heroTag,
      'enableCharacterHero': enableCharacterHero,
    },
  );

  static WorkspaceDestination character({
    required int characterId,
    String? characterName,
    String? heroImageUrl,
    bool enableHeroAnimation = true,
    String? heroTag,
  }) => _create(
    'character',
    characterName ?? '#$characterId',
    arguments: {
      'characterId': characterId,
      'characterName': characterName,
      'heroImageUrl': heroImageUrl,
      'enableHeroAnimation': enableHeroAnimation,
      'heroTag': heroTag,
    },
  );

  static WorkspaceDestination person({
    required int personId,
    String? personName,
    String? heroImageUrl,
    bool enableHeroAnimation = true,
    String? heroTag,
  }) => _create(
    'person',
    personName ?? '#$personId',
    arguments: {
      'personId': personId,
      'personName': personName,
      'heroImageUrl': heroImageUrl,
      'enableHeroAnimation': enableHeroAnimation,
      'heroTag': heroTag,
    },
  );

  static WorkspaceDestination tag(String tagName) =>
      _create('tag', tagName, arguments: {'tagName': tagName});

  static WorkspaceDestination player({
    required AnimeInfo anime,
    required BangumiEpisode currentEpisode,
    required List<BangumiEpisode> allEpisodes,
    int? startPositionMs,
    String? btStreamUrl,
  }) => _create(
    'player',
    anime.title,
    icon: WorkspaceTabIcon.media,
    arguments: {
      'anime': anime,
      'currentEpisode': currentEpisode,
      'allEpisodes': allEpisodes,
      'startPositionMs': startPositionMs,
      'btStreamUrl': btStreamUrl,
    },
  );
}

Widget buildWorkspaceDestination(
  BuildContext context,
  WorkspaceDestination destination,
) {
  final args = destination.arguments;
  switch (destination.kind) {
    case WorkspaceDestination.homeKind:
      return const HomeScreen();
    case 'search':
      return SearchPage(
        initialKeyword: args['initialKeyword'] as String?,
        initialTag: args['initialTag'] as String?,
      );
    case 'ranking':
      return const RankingPage();
    case 'timetable':
      return const TimeTablePage();
    case 'index':
      return const IndexPage();
    case 'history':
      return const HistoryPage();
    case 'favorites':
      return const FavoritesPage();
    case 'settings':
      return const SettingsPage();
    case 'downloads':
      return const DownloadManagerPage();
    case 'about':
      return const AboutPage();
    case 'settings.dataSource':
      return const DataSourceSettingsPage();
    case 'settings.network':
      return const NetworkSettingsPage();
    case 'settings.search':
      return const SearchSettingsPage();
    case 'settings.subscriptionDebug':
      return const SubscriptionDebugPage();
    case 'settings.download':
      return const DownloadSettingsPage();
    case 'settings.theme':
      return const ThemeSettingsPage();
    case 'bangumi':
      return BangumiDetailsPage(
        anime: args['anime']! as AnimeInfo,
        heroTag: args['heroTag'] as String?,
        enableCharacterHero: args['enableCharacterHero']! as bool,
      );
    case 'character':
      return CharacterDetailPage(
        characterId: args['characterId']! as int,
        characterName: args['characterName'] as String?,
        heroImageUrl: args['heroImageUrl'] as String?,
        enableHeroAnimation: args['enableHeroAnimation']! as bool,
        heroTag: args['heroTag'] as String?,
      );
    case 'person':
      return PersonDetailPage(
        personId: args['personId']! as int,
        personName: args['personName'] as String?,
        heroImageUrl: args['heroImageUrl'] as String?,
        enableHeroAnimation: args['enableHeroAnimation']! as bool,
        heroTag: args['heroTag'] as String?,
      );
    case 'tag':
      return TagBrowsePage(tagName: args['tagName']! as String);
    case 'player':
      return PlayerPage(
        anime: args['anime']! as AnimeInfo,
        currentEpisode: args['currentEpisode']! as BangumiEpisode,
        allEpisodes: args['allEpisodes']! as List<BangumiEpisode>,
        startPositionMs: args['startPositionMs'] as int?,
        btStreamUrl: args['btStreamUrl'] as String?,
      );
  }
  throw FlutterError('Unknown workspace destination: ${destination.kind}');
}
