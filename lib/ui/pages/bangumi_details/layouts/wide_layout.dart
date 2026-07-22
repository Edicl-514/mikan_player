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
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/sites_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/summary_tags.dart';

/// Wide (PC) layout for the Bangumi details page.
///
/// Stateless presentational widget extracted from `_buildWideLayout` in
/// `bangumi_details_page.dart`. The host owns the controller, scroll
/// controllers, and the UI state; this widget only assembles the left
/// (poster / rating / actions / infobox) and right (title / episodes /
/// summary / tags / characters / relations / sites / comments) panels.
class BangumiDetailsWideLayout extends StatelessWidget {
  final AnimeInfo anime;
  final String? heroTag;

  // Subject data getters (read-only views).
  final Map<String, dynamic>? data;
  final List<BangumiEpisode>? episodes;
  final List<BangumiCharacter>? characters;
  final List<BangumiRelatedSubject>? relations;
  final List<BangumiComment>? comments;
  final List<BangumiDataSiteEntry>? sites;
  final Map<String, int> personIdMap;

  // Loading / pagination flags.
  final bool isLoadingEpisodes;
  final bool isLoadingCharacters;
  final bool isLoadingRelations;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool hasRequestedComments;

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
  final void Function(int personId) onPersonTap;
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

  const BangumiDetailsWideLayout({
    super.key,
    required this.anime,
    required this.heroTag,
    required this.data,
    required this.episodes,
    required this.characters,
    required this.relations,
    required this.comments,
    required this.sites,
    required this.personIdMap,
    required this.isLoadingEpisodes,
    required this.isLoadingCharacters,
    required this.isLoadingRelations,
    required this.isLoadingComments,
    required this.isLoadingMoreComments,
    required this.hasRequestedComments,
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
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BlurredBackground(imageUrl: getImageUrl(data, anime.coverUrl)),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
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
          // Load-more is owned by the host via [wideRightScrollController]
          // listener; keep this body free of a second NotificationListener so
          // end-of-list scroll does not fire pagination twice.
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
        (data?['infobox'] as List?)
            ?.where((item) => !isInfoboxItemEmpty(item))
            .toList() ??
        const [];

    return SizedBox(
      width: 350,
      child: SingleChildScrollView(
        controller: wideLeftScrollController,
        padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 24, 24, 24),
        child: Column(
          children: [
            BangumiPoster(
              imageUrl: getImageUrl(data, anime.coverUrl),
              heroTag: heroTag,
              heroIdFallback:
                  '${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}',
              radius: 16,
            ),
            const SizedBox(height: 24),
            BangumiRatingCard(
              rating: data?['rating'],
              collection: data?['collection'],
            ),
            const SizedBox(height: 24),
            BangumiActionButtons(
              isLocalFavorite: isLocalFavorite,
              favoriteType: favoriteType,
              isCopied: isCopied,
              isSelectingFavoriteStatus: isSelectingFavoriteStatus,
              isUpdatingFavorite: isUpdatingFavorite,
              onToggleFavorite: onToggleFavorite,
              onFavoriteTypeSelected: onFavoriteTypeSelected,
              onFavoriteAction: onFavoriteAction,
              onShareTapped: onShareTapped,
            ),
            const SizedBox(height: 24),
            BangumiInfoBoxList(
              infobox: infobox,
              isExpanded: isInfoBoxExpanded,
              onToggleExpanded: onToggleInfoBoxExpanded,
              isDarkBg: true,
              personIdMap: personIdMap,
              onPersonTap: onPersonTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        controller: wideRightScrollController,
        padding: const EdgeInsets.fromLTRB(32, kToolbarHeight + 24, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BangumiTitleSection(
              title: getDisplayTitle(data, anime.title),
              cnName: data?['name_cn'] ?? anime.subTitle,
              isDarkBg: true,
            ),
            const SizedBox(height: 32),

            EpisodesSection(
              episodes: episodes,
              isLoading: isLoadingEpisodes,
              isDarkBg: true,
              scrollController: episodesScrollController,
              onEpisodeTap: onEpisodeTap,
            ),
            const SizedBox(height: 32),

            BangumiSummarySection(
              summary:
                  getDisplaySummary(
                    data?['summary']?.toString(),
                    showOriginal: showOriginalSummary,
                  ) ??
                  AppLocalizations.of(context).bangumiDetailsNoSummary,
              showOriginal: showOriginalSummary,
              hasBothTranslationAndOriginal: hasBothTranslationAndOriginal(
                data?['summary']?.toString(),
              ),
              onToggle:
                  hasBothTranslationAndOriginal(data?['summary']?.toString())
                  ? onToggleShowOriginal
                  : null,
              isDarkBg: true,
            ),
            const SizedBox(height: 32),

            BangumiTagsSection(
              tags: data?['tags'],
              isDarkBg: true,
              onTagTap: onTagTap,
            ),
            const SizedBox(height: 32),

            _buildCharactersCard(context),
            if (relations != null && relations!.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildRelationsCard(context),
            ],
            if (sites != null && sites!.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSitesCard(context),
            ] else if (relations == null || relations!.isEmpty) ...[
              const SizedBox(height: 32),
            ],

            _buildCommentsCard(context),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCharactersCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CharactersSection(
      characters: characters ?? const [],
      isLoading: isLoadingCharacters,
      isDarkBg: true,
      enableCharacterHero: enableCharacterHero,
      scrollController: charactersScrollController,
      onCharacterTap: onCharacterTap,
      onPersonTap: onPersonTap,
      personIdMap: personIdMap,
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
      relations: relations ?? const [],
      isLoading: isLoadingRelations,
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
      scrollController: relationsScrollController,
      onItemTap: onRelationTap,
    );
  }

  Widget _buildSitesCard(BuildContext context) {
    if (sites == null || sites!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SitesSection(
      sites: sites!,
      isDarkBg: true,
      sectionTitle: SectionTitle(
        title: AppLocalizations.of(context).bangumiDetailsRelatedSites,
        isDarkBg: true,
      ),
      scrollController: sitesScrollController,
      onSiteTap: onSiteTap,
    );
  }

  Widget _buildCommentsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!hasRequestedComments && !isLoadingComments) {
      // Defer to after the current build so the controller's synchronous
      // _notify() → setState() chain does not run mid-build, which would
      // trip "setState() or markNeedsBuild() called during build" on the
      // parent BangumiDetailsPage.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onEnsureCommentsLoaded();
      });
    }
    return CommentsSection(
      comments: comments ?? const [],
      isLoading: isLoadingComments,
      isLoadingMore: isLoadingMoreComments,
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
}
