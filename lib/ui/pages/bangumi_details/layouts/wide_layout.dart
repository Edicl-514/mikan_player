import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/characters_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/comments_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/episodes_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_actions.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_poster.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_rating.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_title.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/placeholder_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/relations_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/reviews_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/topics_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/sites_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/summary_tags.dart';
import 'package:mikan_player/ui/widgets/desktop_page_chrome.dart';

/// Wide (PC) layout for the Bangumi details page.
///
/// Stateless presentational widget extracted from `_buildWideLayout` in
/// `bangumi_details_page.dart`. The host owns the controller, scroll
/// controllers, and the UI state; this widget only assembles the left
/// (poster / rating / actions / infobox) and right (title / episodes /
/// summary / tags / characters / relations / sites / comments) panels.
class BangumiDetailsWideLayout extends StatefulWidget {
  final AnimeInfo anime;
  final String? heroTag;

  // Subject data getters (read-only views).
  final Map<String, dynamic>? data;
  final List<BangumiEpisode>? episodes;
  final List<BangumiCharacter>? characters;
  final List<BangumiRelatedSubject>? relations;
  final List<BangumiComment>? comments;
  final List<BangumiReview>? reviews;
  final List<BangumiTopic>? topics;
  final List<BangumiDataSiteEntry>? sites;
  final Map<String, int> personIdMap;

  // Loading / pagination flags.
  final bool isLoadingEpisodes;
  final bool isLoadingCharacters;
  final bool isLoadingRelations;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool hasRequestedComments;
  final bool isLoadingReviews;
  final bool isLoadingMoreReviews;
  final bool hasRequestedReviews;
  final bool isLoadingTopics;
  final bool isLoadingMoreTopics;
  final bool hasRequestedTopics;

  // Page-level UI state.
  final bool isLocalFavorite;
  final int? favoriteType;
  final bool isSelectingFavoriteStatus;
  final bool isUpdatingFavorite;
  final bool isCopied;
  final bool showOriginalSummary;
  final bool isInfoBoxExpanded;
  final bool enableCharacterHero;

  // Scroll controllers.
  final ScrollController wideLeftScrollController;
  final ScrollController wideRightScrollController;
  final ScrollController episodesScrollController;
  final ScrollController charactersScrollController;
  final ScrollController relationsScrollController;
  final ScrollController sitesScrollController;

  // Callbacks.
  final VoidCallback onToggleFavorite;
  final ValueChanged<int> onFavoriteTypeSelected;
  final VoidCallback onFavoriteAction;
  final VoidCallback? onShareTapped;
  final VoidCallback onToggleShowOriginal;
  final VoidCallback onToggleInfoBoxExpanded;
  final void Function(String tagName) onTagTap;
  final void Function(int personId, {String? personName}) onPersonTap;
  final void Function(
    int characterId, {
    String? characterName,
    String? heroImageUrl,
  })
  onCharacterTap;
  final void Function(BangumiEpisode episode) onEpisodeTap;
  final void Function(BangumiRelatedSubject relation) onRelationTap;
  final void Function(BangumiDataSiteEntry site) onSiteTap;
  final VoidCallback onEnsureCommentsLoaded;
  final VoidCallback onLoadMoreComments;
  final VoidCallback? onEnsureReviewsLoaded;
  final VoidCallback? onLoadMoreReviews;
  final void Function(BangumiReview review)? onReviewTap;
  final VoidCallback? onEnsureTopicsLoaded;
  final VoidCallback? onLoadMoreTopics;
  final void Function(BangumiTopic topic)? onTopicTap;

  const BangumiDetailsWideLayout({
    super.key,
    required this.anime,
    required this.heroTag,
    required this.data,
    required this.episodes,
    required this.characters,
    required this.relations,
    required this.comments,
    this.reviews,
    this.topics,
    required this.sites,
    required this.personIdMap,
    required this.isLoadingEpisodes,
    required this.isLoadingCharacters,
    required this.isLoadingRelations,
    required this.isLoadingComments,
    required this.isLoadingMoreComments,
    required this.hasRequestedComments,
    this.isLoadingReviews = false,
    this.isLoadingMoreReviews = false,
    this.hasRequestedReviews = false,
    this.isLoadingTopics = false,
    this.isLoadingMoreTopics = false,
    this.hasRequestedTopics = false,
    required this.isLocalFavorite,
    required this.favoriteType,
    required this.isSelectingFavoriteStatus,
    required this.isUpdatingFavorite,
    required this.isCopied,
    required this.showOriginalSummary,
    required this.isInfoBoxExpanded,
    required this.enableCharacterHero,
    required this.wideLeftScrollController,
    required this.wideRightScrollController,
    required this.episodesScrollController,
    required this.charactersScrollController,
    required this.relationsScrollController,
    required this.sitesScrollController,
    required this.onToggleFavorite,
    required this.onFavoriteTypeSelected,
    required this.onFavoriteAction,
    required this.onShareTapped,
    required this.onToggleShowOriginal,
    required this.onToggleInfoBoxExpanded,
    required this.onTagTap,
    required this.onPersonTap,
    required this.onCharacterTap,
    required this.onEpisodeTap,
    required this.onRelationTap,
    required this.onSiteTap,
    required this.onEnsureCommentsLoaded,
    required this.onLoadMoreComments,
    this.onEnsureReviewsLoaded,
    this.onLoadMoreReviews,
    this.onReviewTap,
    this.onEnsureTopicsLoaded,
    this.onLoadMoreTopics,
    this.onTopicTap,
  });

  @override
  State<BangumiDetailsWideLayout> createState() =>
      _BangumiDetailsWideLayoutState();
}

class _BangumiDetailsWideLayoutState extends State<BangumiDetailsWideLayout> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.wideRightScrollController.addListener(_handleRightScroll);
  }

  @override
  void didUpdateWidget(covariant BangumiDetailsWideLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wideRightScrollController !=
        widget.wideRightScrollController) {
      oldWidget.wideRightScrollController.removeListener(_handleRightScroll);
      widget.wideRightScrollController.addListener(_handleRightScroll);
    }
    if (!_sameAnimeIdentity(oldWidget.anime, widget.anime)) {
      _selectedTabIndex = 0;
    }
    if (_selectedTabIndex == 1 ||
        _selectedTabIndex == 2 ||
        _selectedTabIndex == 3) {
      _scheduleViewportFillCheck();
    }
  }

  bool _sameAnimeIdentity(AnimeInfo a, AnimeInfo b) =>
      a.bangumiId == b.bangumiId &&
      a.mikanId == b.mikanId &&
      a.title == b.title;

  void _handleRightScroll() {
    if (!widget.wideRightScrollController.hasClients) {
      return;
    }
    final position = widget.wideRightScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      if (_selectedTabIndex == 1) {
        widget.onLoadMoreComments();
      } else if (_selectedTabIndex == 2) {
        widget.onLoadMoreReviews?.call();
      } else if (_selectedTabIndex == 3) {
        widget.onLoadMoreTopics?.call();
      }
    }
  }

  void _scheduleViewportFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleRightScroll();
    });
  }

  @override
  void dispose() {
    widget.wideRightScrollController.removeListener(_handleRightScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostsNavigation = DesktopPageChromeScope.hostsNavigation(context);
    return Stack(
      children: [
        Positioned.fill(
          child: BlurredBackground(
            imageUrl: getImageUrl(widget.data, widget.anime.coverUrl),
            publishTint: true,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: !hostsNavigation,
          appBar: hostsNavigation
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          // The state listens to the shared right controller and gates comment
          // pagination by the selected tab.
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildLeftPanel(context), _buildRightPanel(context)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final infobox =
        (widget.data?['infobox'] as List?)
            ?.where((item) => !isInfoboxItemEmpty(item))
            .toList() ??
        const [];

    return SizedBox(
      width: 350,
      child: SingleChildScrollView(
        controller: widget.wideLeftScrollController,
        padding: EdgeInsets.fromLTRB(
          24,
          DesktopPageMetrics.navigationTopInsetFor(
                context,
                reserved: kToolbarHeight,
              ) +
              24,
          24,
          24,
        ),
        child: Column(
          children: [
            BangumiPoster(
              imageUrl: getImageUrl(widget.data, widget.anime.coverUrl),
              heroTag: widget.heroTag,
              heroIdFallback:
                  '${widget.anime.bangumiId ?? widget.anime.mikanId ?? widget.anime.title.hashCode}',
              radius: 16,
            ),
            const SizedBox(height: 24),
            BangumiRatingCard(
              rating: widget.data?['rating'],
              collection: widget.data?['collection'],
            ),
            const SizedBox(height: 24),
            BangumiActionButtons(
              isLocalFavorite: widget.isLocalFavorite,
              favoriteType: widget.favoriteType,
              isCopied: widget.isCopied,
              isSelectingFavoriteStatus: widget.isSelectingFavoriteStatus,
              isUpdatingFavorite: widget.isUpdatingFavorite,
              onToggleFavorite: widget.onToggleFavorite,
              onFavoriteTypeSelected: widget.onFavoriteTypeSelected,
              onFavoriteAction: widget.onFavoriteAction,
              onShareTapped: widget.onShareTapped,
            ),
            const SizedBox(height: 24),
            BangumiInfoBoxList(
              infobox: infobox,
              isExpanded: widget.isInfoBoxExpanded,
              onToggleExpanded: widget.onToggleInfoBoxExpanded,
              isDarkBg: true,
              personIdMap: widget.personIdMap,
              onPersonTap: widget.onPersonTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Expanded(
      child: CustomScrollView(
        controller: widget.wideRightScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              32,
              DesktopPageMetrics.navigationTopInsetFor(
                    context,
                    reserved: kToolbarHeight,
                  ) +
                  24,
              32,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BangumiTitleSection(
                    title: getDisplayTitle(widget.data, widget.anime.title),
                    cnName: widget.data?['name_cn'] ?? widget.anime.subTitle,
                    isDarkBg: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      style: SegmentedButton.styleFrom(
                        selectedForegroundColor: Colors.white,
                        selectedBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.35),
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.black.withValues(alpha: 0.25),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      segments: [
                        ButtonSegment<int>(
                          value: 0,
                          label: Text(l10n.bangumiDetailsTabDetails),
                          icon: const Icon(Icons.info_outline),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          label: Text(l10n.bangumiDetailsTabComments),
                          icon: const Icon(Icons.chat_bubble_outline),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          label: Text(l10n.bangumiDetailsTabReviews),
                          icon: const Icon(Icons.article_outlined),
                        ),
                        ButtonSegment<int>(
                          value: 3,
                          label: Text(l10n.bangumiDetailsTabTopics),
                          icon: const Icon(Icons.forum_outlined),
                        ),
                      ],
                      selected: {_selectedTabIndex},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedTabIndex = newSelection.first;
                        });
                        if (_selectedTabIndex == 1 ||
                            _selectedTabIndex == 2 ||
                            _selectedTabIndex == 3) {
                          _scheduleViewportFillCheck();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_selectedTabIndex == 0)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverToBoxAdapter(child: _buildDetailsTab(context)),
            ),
          if (_selectedTabIndex == 1)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: _buildCommentsSliver(context),
            ),
          if (_selectedTabIndex == 2)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: _buildReviewsSliver(context),
            ),
          if (_selectedTabIndex == 3)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: _buildTopicsSliver(context),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 74)),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EpisodesSection(
          episodes: widget.episodes,
          isLoading: widget.isLoadingEpisodes,
          isDarkBg: true,
          scrollController: widget.episodesScrollController,
          onEpisodeTap: widget.onEpisodeTap,
        ),
        const SizedBox(height: 32),
        BangumiSummarySection(
          summary:
              getDisplaySummary(
                widget.data?['summary']?.toString(),
                showOriginal: widget.showOriginalSummary,
              ) ??
              AppLocalizations.of(context).bangumiDetailsNoSummary,
          showOriginal: widget.showOriginalSummary,
          hasBothTranslationAndOriginal: hasBothTranslationAndOriginal(
            widget.data?['summary']?.toString(),
          ),
          onToggle:
              hasBothTranslationAndOriginal(widget.data?['summary']?.toString())
              ? widget.onToggleShowOriginal
              : null,
          isDarkBg: true,
        ),
        const SizedBox(height: 32),
        BangumiTagsSection(
          tags: widget.data?['tags'],
          isDarkBg: true,
          onTagTap: widget.onTagTap,
        ),
        const SizedBox(height: 32),
        _buildCharactersCard(context),
        if (widget.relations != null && widget.relations!.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildRelationsCard(context),
        ],
        if (widget.sites != null && widget.sites!.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSitesCard(context),
        ] else if (widget.relations == null || widget.relations!.isEmpty) ...[
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildCharactersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CharactersSection(
      characters: widget.characters ?? const [],
      isLoading: widget.isLoadingCharacters,
      isDarkBg: true,
      enableCharacterHero: widget.enableCharacterHero,
      scrollController: widget.charactersScrollController,
      onCharacterTap: widget.onCharacterTap,
      onPersonTap: widget.onPersonTap,
      personIdMap: widget.personIdMap,
      loadingPlaceholder: (context) => PlaceholderSection(
        title: l10n.bangumiDetailsCharacters,
        icon: Icons.person,
        isDarkBg: true,
      ),
      sectionTitle: l10n.bangumiDetailsCharacters,
    );
  }

  Widget _buildRelationsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RelationsSection(
      relations: widget.relations ?? const [],
      isLoading: widget.isLoadingRelations,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: l10n.bangumiDetailsRelatedItems,
        isDarkBg: true,
      ),
      loadingPlaceholder: (context) => PlaceholderSection(
        title: l10n.bangumiDetailsRelatedItems,
        icon: Icons.link,
        isDarkBg: true,
      ),
      scrollController: widget.relationsScrollController,
      onItemTap: widget.onRelationTap,
    );
  }

  Widget _buildSitesCard(BuildContext context) {
    if (widget.sites == null || widget.sites!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SitesSection(
      sites: widget.sites!,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: AppLocalizations.of(context).bangumiDetailsRelatedSites,
        isDarkBg: true,
      ),
      scrollController: widget.sitesScrollController,
      onSiteTap: widget.onSiteTap,
    );
  }

  Widget _buildCommentsSliver(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!widget.hasRequestedComments && !widget.isLoadingComments) {
      // Defer to after the current build so the controller's synchronous
      // _notify() → setState() chain does not run mid-build, which would
      // trip "setState() or markNeedsBuild() called during build" on the
      // parent BangumiDetailsPage.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEnsureCommentsLoaded();
      });
    }
    return CommentsSliver(
      comments: widget.comments ?? const [],
      isLoading: widget.isLoadingComments,
      isLoadingMore: widget.isLoadingMoreComments,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: l10n.bangumiDetailsComments,
        isDarkBg: true,
      ),
      loadingPlaceholder: (ctx) => PlaceholderSection(
        title: l10n.bangumiDetailsComments,
        icon: Icons.comment,
        isDarkBg: true,
      ),
    );
  }

  Widget _buildReviewsSliver(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!widget.hasRequestedReviews && !widget.isLoadingReviews) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEnsureReviewsLoaded?.call();
      });
    }
    return ReviewsSliver(
      reviews: widget.reviews ?? const [],
      isLoading: widget.isLoadingReviews,
      isLoadingMore: widget.isLoadingMoreReviews,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: l10n.bangumiDetailsTabReviews,
        isDarkBg: true,
      ),
      loadingPlaceholder: (ctx) => PlaceholderSection(
        title: l10n.bangumiDetailsTabReviews,
        icon: Icons.article_outlined,
        isDarkBg: true,
      ),
      onReviewTap: widget.onReviewTap,
    );
  }

  Widget _buildTopicsSliver(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!widget.hasRequestedTopics && !widget.isLoadingTopics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEnsureTopicsLoaded?.call();
      });
    }
    return TopicsSliver(
      topics: widget.topics ?? const [],
      isLoading: widget.isLoadingTopics,
      isLoadingMore: widget.isLoadingMoreTopics,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: l10n.bangumiDetailsTabTopics,
        isDarkBg: true,
      ),
      loadingPlaceholder: (ctx) => PlaceholderSection(
        title: l10n.bangumiDetailsTabTopics,
        icon: Icons.forum_outlined,
        isDarkBg: true,
      ),
      onTopicTap: widget.onTopicTap,
    );
  }
}
