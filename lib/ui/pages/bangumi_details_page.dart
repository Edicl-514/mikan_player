import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/services/favorites_manager.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_controller.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/mobile_layout.dart';
import 'package:mikan_player/ui/pages/bangumi_details/layouts/wide_layout.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';
import 'package:mikan_player/ui/widgets/bangumi_site_launcher.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

class BangumiDetailsPage extends StatefulWidget {
  final AnimeInfo anime;
  final String? heroTag;
  final bool enableCharacterHero;

  const BangumiDetailsPage({
    super.key,
    required this.anime,
    this.heroTag,
    this.enableCharacterHero = true,
  });

  @override
  State<BangumiDetailsPage> createState() => _BangumiDetailsPageState();
}

/// Glue-only State for [BangumiDetailsPage].
///
/// The page owns the [BangumiDetailsController] lifecycle, the scroll
/// controllers, the four page-level UI state flags (`_isCopied`,
/// `_copyTimer`, `_showOriginalSummary`, `_isInfoBoxExpanded`), the
/// navigation/share/favorite plumbing, and the layout-switch `build` body.
/// All section presentation lives in `bangumi_details/widgets/**` and the
/// mobile/wide layout assemblies live in `bangumi_details/layouts/**`.
class _BangumiDetailsPageState extends State<BangumiDetailsPage> {
  late final BangumiDetailsController _detailsController;
  int _detailsLoadToken = 0;
  late ScrollController _wideLeftScrollController;
  late ScrollController _wideRightScrollController;

  bool _isCopied = false;
  Timer? _copyTimer;
  bool _isSelectingFavoriteStatus = false;
  bool _isUpdatingFavorite = false;
  bool _showOriginalSummary = false;
  bool _isInfoBoxExpanded = false;

  late ScrollController _episodesScrollController;
  late ScrollController _charactersScrollController;
  late ScrollController _relationsScrollController;
  late ScrollController _sitesScrollController;

  // Convenience aliases for read-only views over the controller. The
  // controller owns the request state; these only forward the values that
  // the layouts/section widgets need.
  Map<String, dynamic>? get _data => _detailsController.subjectData;
  List<BangumiEpisode>? get _episodes => _detailsController.episodes;
  List<BangumiCharacter>? get _characters => _detailsController.characters;
  List<BangumiRelatedSubject>? get _relations => _detailsController.relations;
  List<BangumiComment>? get _comments => _detailsController.comments;
  List<BangumiDataSiteEntry>? get _sites => _detailsController.sites;
  Map<String, int> get _personIdMap => _detailsController.personIdMap;
  bool get _isLoadingEpisodes => _detailsController.isLoadingEpisodes;
  bool get _isLoadingCharacters => _detailsController.isLoadingCharacters;
  bool get _isLoadingRelations => _detailsController.isLoadingRelations;
  bool get _isLoadingComments => _detailsController.isLoadingComments;
  bool get _hasRequestedComments => _detailsController.hasRequestedComments;
  bool get _isLocalFavorite => _detailsController.isLocalFavorite;
  int? get _localFavoriteType => _detailsController.localFavoriteType;
  bool get _isLoadingMoreComments => _detailsController.isLoadingMoreComments;

  @override
  void initState() {
    super.initState();
    _detailsController = BangumiDetailsController(
      anime: widget.anime,
      dataPort: bangumiDetailsServiceDataPort(),
      favoritesPort: bangumiDetailsFavoritesPort(() => FavoritesManager()),
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _wideLeftScrollController = createPlatformScrollController();
    _wideRightScrollController = createPlatformScrollController();
    _wideRightScrollController.addListener(_handleWideRightScroll);
    _episodesScrollController = createPlatformScrollController();
    _charactersScrollController = createPlatformScrollController();
    _relationsScrollController = createPlatformScrollController();
    _sitesScrollController = createPlatformScrollController();
    _startDetailsLoad();
  }

  @override
  void didUpdateWidget(covariant BangumiDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAnimeIdentity(oldWidget.anime, widget.anime)) {
      _detailsController.resetForAnime(widget.anime);
      _isSelectingFavoriteStatus = false;
      _isUpdatingFavorite = false;
      _showOriginalSummary = false;
      _isInfoBoxExpanded = false;
      _startDetailsLoad();
    }
  }

  bool _sameAnimeIdentity(AnimeInfo a, AnimeInfo b) =>
      a.bangumiId == b.bangumiId &&
      a.mikanId == b.mikanId &&
      a.title == b.title;

  void _startDetailsLoad() {
    final loadToken = ++_detailsLoadToken;
    _detailsController.seedFromAnimeFullJson();
    unawaited(_detailsController.refreshFavoriteStatus());
    unawaited(_detailsController.primeFromCache());
    unawaited(_fetchBangumiData(loadToken));
  }

  void _handleWideRightScroll() {
    if (!_wideRightScrollController.hasClients) return;
    final position = _wideRightScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_detailsController.loadMoreComments());
    }
  }

  Future<void> _ensureCommentsLoaded() =>
      _detailsController.ensureCommentsLoaded();

  Future<void> _fetchBangumiData(int loadToken) async {
    await _detailsController.refreshFromNetwork();
    if (!mounted || loadToken != _detailsLoadToken) return;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250), () async {
        if (!mounted || loadToken != _detailsLoadToken) return;
        await _ensureCommentsLoaded();
      }),
    );
  }

  /// Rebuilds an [AnimeInfo] snapshot from the latest subject data so that
  /// the player page receives the freshest tags, full-json, and CN subtitle.
  AnimeInfo _buildAnimeForPlayer() {
    final currentNameCn = _data?['name_cn']?.toString().trim() ?? '';

    return AnimeInfo(
      title: widget.anime.title,
      subTitle: currentNameCn.isNotEmpty
          ? currentNameCn
          : widget.anime.subTitle,
      bangumiId: widget.anime.bangumiId,
      mikanId: widget.anime.mikanId,
      coverUrl: widget.anime.coverUrl,
      siteUrl: widget.anime.siteUrl,
      broadcastDay: widget.anime.broadcastDay,
      broadcastTime: widget.anime.broadcastTime,
      score: widget.anime.score,
      rank: widget.anime.rank,
      tags: extractCurrentTags(_data?['tags'], widget.anime.tags),
      fullJson: _data != null ? jsonEncode(_data) : widget.anime.fullJson,
    );
  }

  // --- Navigation handlers ---

  void _openPersonPage(int personId) {
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.person(
        personId: personId,
        enableHeroAnimation: false,
      ),
    );
  }

  void _openCharacterPage(
    int characterId, {
    String? characterName,
    String? heroImageUrl,
  }) {
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.character(
        characterId: characterId,
        characterName: characterName,
        heroImageUrl: heroImageUrl,
      ),
    );
  }

  void _openTagBrowsePage(String tagName) {
    WorkspaceNavigation.open<void>(context, WorkspaceDestinations.tag(tagName));
  }

  Future<void> _openEpisodePlayer(BangumiEpisode ep) async {
    final anime = _buildAnimeForPlayer();
    int? startPositionMs;
    try {
      startPositionMs = await PlaybackHistoryManager().resumePositionMsFor(
        anime: anime,
        episode: ep,
      );
    } catch (_) {
      startPositionMs = null;
    }
    if (!mounted) return;
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.player(
        anime: anime,
        currentEpisode: ep,
        allEpisodes: _episodes!,
        startPositionMs: startPositionMs,
      ),
    );
  }

  void _openRelationPage(BangumiRelatedSubject rel) {
    WorkspaceNavigation.open<void>(
      context,
      WorkspaceDestinations.bangumiDetails(
        anime: AnimeInfo(
          title: rel.nameCn.isNotEmpty ? rel.nameCn : rel.name,
          bangumiId: rel.id.toString(),
          coverUrl: rel.image,
          tags: const [],
        ),
        heroTag: 'bangumi_relation_${rel.id.toInt()}',
        enableCharacterHero: false,
      ),
    );
  }

  // --- UI state mutations ---

  void _showFavoriteStatusSelector() {
    if (_isUpdatingFavorite) return;
    setState(() => _isSelectingFavoriteStatus = true);
  }

  void _handleFavoriteAction() {
    if (_isUpdatingFavorite) return;
    if (_isLocalFavorite) {
      unawaited(_removeFavorite());
    } else {
      setState(() => _isSelectingFavoriteStatus = false);
    }
  }

  Future<void> _selectFavoriteType(int type) async {
    if (_isUpdatingFavorite) return;
    final wasFavorite = _isLocalFavorite;
    setState(() => _isUpdatingFavorite = true);

    Object? error;
    var saved = false;
    try {
      saved = await _detailsController.setLocalFavoriteType(
        title: widget.anime.title,
        coverUrl: widget.anime.coverUrl ?? '',
        score: widget.anime.score ?? 0.0,
        type: type,
      );
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFavorite = false;
          _isSelectingFavoriteStatus = false;
        });
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (error != null) {
      _showFavoriteSnackBar(l10n.favoriteUpdateFailed(error.toString()));
    } else if (saved) {
      _showFavoriteSnackBar(
        wasFavorite ? l10n.favoriteStatusUpdated : l10n.addToLocalFavorites,
      );
    }
  }

  Future<void> _removeFavorite() async {
    setState(() => _isUpdatingFavorite = true);

    Object? error;
    var removed = false;
    try {
      removed = await _detailsController.removeLocalFavorite();
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFavorite = false;
          _isSelectingFavoriteStatus = false;
        });
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (error != null) {
      _showFavoriteSnackBar(l10n.favoriteUpdateFailed(error.toString()));
    } else if (removed) {
      _showFavoriteSnackBar(l10n.removeFromFavorites);
    }
  }

  void _showFavoriteSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleShowOriginal() {
    setState(() {
      _showOriginalSummary = !_showOriginalSummary;
    });
  }

  void _toggleInfoBoxExpanded() {
    setState(() {
      _isInfoBoxExpanded = !_isInfoBoxExpanded;
    });
  }

  Future<void> _onShareTapped() async {
    final subjectId = widget.anime.bangumiId;
    if (subjectId == null) return;
    final mainHost = await BangumiUrlRewriter.hostFor('main');
    final url = BangumiUrlRewriter.rewrite(
      "https://bgm.tv/subject/$subjectId",
    ).replaceFirst('bgm.tv', mainHost);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() {
      _isCopied = true;
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _detailsLoadToken++;
    _detailsController.clearForDispose();
    _copyTimer?.cancel();
    _wideRightScrollController.removeListener(_handleWideRightScroll);
    _wideLeftScrollController.dispose();
    _wideRightScrollController.dispose();
    _episodesScrollController.dispose();
    _charactersScrollController.dispose();
    _relationsScrollController.dispose();
    _sitesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isWide
          ? BangumiDetailsWideLayout(
              anime: widget.anime,
              heroTag: widget.heroTag,
              data: _data,
              episodes: _episodes,
              characters: _characters,
              relations: _relations,
              comments: _comments,
              sites: _sites,
              personIdMap: _personIdMap,
              isLoadingEpisodes: _isLoadingEpisodes,
              isLoadingCharacters: _isLoadingCharacters,
              isLoadingRelations: _isLoadingRelations,
              isLoadingComments: _isLoadingComments,
              isLoadingMoreComments: _isLoadingMoreComments,
              hasRequestedComments: _hasRequestedComments,
              isLocalFavorite: _isLocalFavorite,
              favoriteType: _localFavoriteType,
              isSelectingFavoriteStatus: _isSelectingFavoriteStatus,
              isUpdatingFavorite: _isUpdatingFavorite,
              isCopied: _isCopied,
              showOriginalSummary: _showOriginalSummary,
              isInfoBoxExpanded: _isInfoBoxExpanded,
              enableCharacterHero: widget.enableCharacterHero,
              wideLeftScrollController: _wideLeftScrollController,
              wideRightScrollController: _wideRightScrollController,
              episodesScrollController: _episodesScrollController,
              charactersScrollController: _charactersScrollController,
              relationsScrollController: _relationsScrollController,
              sitesScrollController: _sitesScrollController,
              onToggleFavorite: _showFavoriteStatusSelector,
              onFavoriteTypeSelected: (type) =>
                  unawaited(_selectFavoriteType(type)),
              onFavoriteAction: _handleFavoriteAction,
              onShareTapped: _onShareTapped,
              onToggleShowOriginal: _toggleShowOriginal,
              onToggleInfoBoxExpanded: _toggleInfoBoxExpanded,
              onTagTap: _openTagBrowsePage,
              onPersonTap: _openPersonPage,
              onCharacterTap: _openCharacterPage,
              onEpisodeTap: _openEpisodePlayer,
              onRelationTap: _openRelationPage,
              onSiteTap: (site) => launchBangumiSiteUrl(site.url),
              onEnsureCommentsLoaded: () => unawaited(_ensureCommentsLoaded()),
            )
          : BangumiDetailsMobileLayout(
              anime: widget.anime,
              heroTag: widget.heroTag,
              data: _data,
              episodes: _episodes,
              characters: _characters,
              relations: _relations,
              comments: _comments,
              sites: _sites,
              personIdMap: _personIdMap,
              isLoadingEpisodes: _isLoadingEpisodes,
              isLoadingCharacters: _isLoadingCharacters,
              isLoadingRelations: _isLoadingRelations,
              isLoadingComments: _isLoadingComments,
              isLoadingMoreComments: _isLoadingMoreComments,
              hasRequestedComments: _hasRequestedComments,
              isLocalFavorite: _isLocalFavorite,
              favoriteType: _localFavoriteType,
              isSelectingFavoriteStatus: _isSelectingFavoriteStatus,
              isUpdatingFavorite: _isUpdatingFavorite,
              showOriginalSummary: _showOriginalSummary,
              isInfoBoxExpanded: _isInfoBoxExpanded,
              enableCharacterHero: widget.enableCharacterHero,
              episodesScrollController: _episodesScrollController,
              charactersScrollController: _charactersScrollController,
              relationsScrollController: _relationsScrollController,
              sitesScrollController: _sitesScrollController,
              onToggleFavorite: _showFavoriteStatusSelector,
              onFavoriteTypeSelected: (type) =>
                  unawaited(_selectFavoriteType(type)),
              onFavoriteAction: _handleFavoriteAction,
              onToggleShowOriginal: _toggleShowOriginal,
              onToggleInfoBoxExpanded: _toggleInfoBoxExpanded,
              onTagTap: _openTagBrowsePage,
              onPersonTap: _openPersonPage,
              onCharacterTap: _openCharacterPage,
              onEpisodeTap: _openEpisodePlayer,
              onRelationTap: _openRelationPage,
              onSiteTap: (site) => launchBangumiSiteUrl(site.url),
              onLoadMoreComments: () =>
                  unawaited(_detailsController.loadMoreComments()),
              onEnsureCommentsLoaded: () => unawaited(_ensureCommentsLoaded()),
            ),
    );
  }
}
