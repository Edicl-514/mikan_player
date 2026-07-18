import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/ui/pages/bangumi_details/bangumi_details_helpers.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/characters_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/comments_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/episodes_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_collection_stats.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/header_rating.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/placeholder_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/relations_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/sites_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/summary_tags.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Mobile layout for the Bangumi details page.
///
/// Stateless presentational widget extracted from `_buildMobileLayout` /
/// `_buildMobileHeaderContent` / `_buildMobileDetailsTab` in
/// `bangumi_details_page.dart`. The host owns the controller, scroll
/// controllers, and the UI state; this widget only assembles them.
class BangumiDetailsMobileLayout extends StatelessWidget {
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
  final bool showOriginalSummary;
  final bool isInfoBoxExpanded;
  final bool enableCharacterHero;

  // Scroll controllers.
  final ScrollController mobileDetailsScrollController;
  final ScrollController episodesScrollController;
  final ScrollController charactersScrollController;
  final ScrollController relationsScrollController;
  final ScrollController sitesScrollController;

  // Callbacks.
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleShowOriginal;
  final VoidCallback onToggleInfoBoxExpanded;
  final void Function(String tagName) onTagTap;
  final void Function(int personId) onPersonTap;
  final void Function(int characterId, {String? characterName, String? heroImageUrl}) onCharacterTap;
  final void Function(BangumiEpisode episode) onEpisodeTap;
  final void Function(BangumiRelatedSubject relation) onRelationTap;
  final void Function(BangumiDataSiteEntry site) onSiteTap;
  final VoidCallback onLoadMoreComments;
  final VoidCallback onEnsureCommentsLoaded;

  const BangumiDetailsMobileLayout({
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
    required this.showOriginalSummary,
    required this.isInfoBoxExpanded,
    required this.enableCharacterHero,
    required this.mobileDetailsScrollController,
    required this.episodesScrollController,
    required this.charactersScrollController,
    required this.relationsScrollController,
    required this.sitesScrollController,
    required this.onToggleFavorite,
    required this.onToggleShowOriginal,
    required this.onToggleInfoBoxExpanded,
    required this.onTagTap,
    required this.onPersonTap,
    required this.onCharacterTap,
    required this.onEpisodeTap,
    required this.onRelationTap,
    required this.onSiteTap,
    required this.onLoadMoreComments,
    required this.onEnsureCommentsLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF16161E)
        : Theme.of(context).scaffoldBackgroundColor;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: bgColor,
                surfaceTintColor: bgColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildMobileHeaderContent(context, isDark, bgColor),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      labelColor: isDark
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      unselectedLabelColor: isDark
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
                        Tab(text: AppLocalizations.of(context).bangumiDetailsTabDetails),
                        Tab(text: AppLocalizations.of(context).bangumiDetailsTabComments),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildMobileDetailsTab(context, isDark),
              _buildMobileCommentsTab(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeaderContent(BuildContext context, bool isDark, Color bgColor) {
    final l10n = AppLocalizations.of(context);
    final imgUrl = getImageUrl(data, anime.coverUrl);
    final displayTitle = getDisplayTitle(data, anime.title);
    final rating = data?['rating'];
    final collection = data?['collection'];

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imgUrl != null)
          CachedNetworkImage(
            imageUrl: imgUrl,
            fit: BoxFit.cover,
            height: 500,
            errorWidget: Container(color: Colors.grey[900]),
          )
        else
          Container(color: Colors.grey[900]),
        RepaintBoundary(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                    bgColor,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: heroTag ??
                          '${anime.bangumiId ?? anime.mikanId ?? anime.title.hashCode}',
                      child: Container(
                        width: 110,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: imgUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  width: 110,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.movie, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (data?['date'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                formatDateToMonth(
                                  data!['date'].toString(),
                                  l10n,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (data?['date'] != null) const SizedBox(height: 8),
                          Text(
                            getEpisodeStatusText(data, episodes, l10n),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          BangumiRatingRow(rating: rating),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                BangumiCollectionStatsRow(
                  collection: collection,
                  isLocalFavorite: isLocalFavorite,
                  onToggleFavorite: onToggleFavorite,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDetailsTab(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final infobox = (data?['infobox'] as List?)
            ?.where((item) => !isInfoboxItemEmpty(item))
            .toList() ??
        const [];

    return SingleChildScrollView(
      controller: defaultTargetPlatform == TargetPlatform.windows
          ? mobileDetailsScrollController
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EpisodesSection(
            episodes: episodes,
            isLoading: isLoadingEpisodes,
            isDarkBg: isDark,
            scrollController: episodesScrollController,
            onEpisodeTap: onEpisodeTap,
          ),
          const SizedBox(height: 24),
          BangumiSummarySection(
            summary:
                getDisplaySummary(
                  data?['summary']?.toString(),
                  showOriginal: showOriginalSummary,
                ) ??
                l10n.bangumiDetailsNoSummary,
            showOriginal: showOriginalSummary,
            hasBothTranslationAndOriginal: hasBothTranslationAndOriginal(
              data?['summary']?.toString(),
            ),
            onToggle:
                hasBothTranslationAndOriginal(data?['summary']?.toString())
                ? onToggleShowOriginal
                : null,
            isDarkBg: isDark,
          ),
          const SizedBox(height: 24),
          BangumiMobileTags(
            tags: data?['tags'],
            isDarkBg: isDark,
            onTagTap: onTagTap,
          ),
          const SizedBox(height: 24),
          BangumiInfoBoxList(
            infobox: infobox,
            isExpanded: isInfoBoxExpanded,
            onToggleExpanded: onToggleInfoBoxExpanded,
            isDarkBg: isDark,
            personIdMap: personIdMap,
            onPersonTap: onPersonTap,
          ),
          const SizedBox(height: 24),
          CharactersSection(
            characters: characters ?? const [],
            isLoading: isLoadingCharacters,
            isDarkBg: isDark,
            enableCharacterHero: enableCharacterHero,
            scrollController: charactersScrollController,
            onCharacterTap: onCharacterTap,
            onPersonTap: onPersonTap,
            personIdMap: personIdMap,
            loadingPlaceholder: (context) => PlaceholderSection(
              title: l10n.bangumiDetailsCharacters,
              icon: Icons.person,
              isDarkBg: isDark,
            ),
            sectionTitle: l10n.bangumiDetailsCharacters,
          ),
          if (relations != null && relations!.isNotEmpty) ...[
            const SizedBox(height: 40),
            _buildRelationsCard(context, isDark),
          ],
          if (sites != null && sites!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSitesCard(context, isDark),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMobileCommentsTab(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    if (!hasRequestedComments && !isLoadingComments) {
      onEnsureCommentsLoaded();
    }

    if (isLoadingComments) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionTitle(
              title: l10n.bangumiDetailsComments,
              isDarkBg: isDark,
            ),
          ),
          const SizedBox(height: 96),
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.loading,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    if (comments == null || comments!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionTitle(
              title: l10n.bangumiDetailsComments,
              isDarkBg: isDark,
            ),
          ),
          const SizedBox(height: 96),
          Center(
            child: Text(
              l10n.bangumiDetailsNoComments,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey,
              ),
            ),
          ),
        ],
      );
    }

    // Reuse the wide-layout CommentsSection widget so the comment card
    // markup / pagination rendering stays identical across layouts. Wrap it
    // in a scrollable + the load-more notification listener.
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification ||
            notification is OverscrollNotification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            onLoadMoreComments();
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: CommentsSection(
          comments: comments!,
          isLoading: false,
          isLoadingMore: isLoadingMoreComments,
          isDarkBg: isDark,
          sectionTitle: SectionTitle(
            title: l10n.bangumiDetailsComments,
            isDarkBg: isDark,
          ),
          loadingPlaceholder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildRelationsCard(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return RelationsSection(
      relations: relations ?? const [],
      isLoading: isLoadingRelations,
      isDarkBg: isDark,
      sectionTitle: SectionTitle(
        title: l10n.bangumiDetailsRelatedItems,
        isDarkBg: isDark,
      ),
      loadingPlaceholder: (context) => PlaceholderSection(
        title: l10n.bangumiDetailsRelatedItems,
        icon: Icons.link,
        isDarkBg: isDark,
      ),
      scrollController: relationsScrollController,
      onItemTap: onRelationTap,
    );
  }

  Widget _buildSitesCard(BuildContext context, bool isDark) {
    if (sites == null || sites!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SitesSection(
      sites: sites!,
      isDarkBg: isDark,
      sectionTitle: SectionTitle(
        title: AppLocalizations.of(context).bangumiDetailsRelatedSites,
        isDarkBg: isDark,
      ),
      scrollController: sitesScrollController,
      onSiteTap: onSiteTap,
    );
  }

}
