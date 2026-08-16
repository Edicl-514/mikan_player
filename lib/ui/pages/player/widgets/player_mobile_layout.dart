import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_onair_sites_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_recommendations.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_section_header.dart';

/// Horizontal expandable episode strip used on the mobile info tab.
class PlayerMobileEpisodeStrip extends StatelessWidget {
  final List<BangumiEpisode> episodes;
  final BangumiEpisode currentEpisode;
  final bool isExpanded;
  final ScrollController scrollController;
  final VoidCallback onToggleExpanded;
  final ValueChanged<BangumiEpisode> onEpisodeSelected;

  const PlayerMobileEpisodeStrip({
    super.key,
    required this.episodes,
    required this.currentEpisode,
    required this.isExpanded,
    required this.scrollController,
    required this.onToggleExpanded,
    required this.onEpisodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggleExpanded,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.playerMobileEpisodeSelector,
                style: TextStyle(
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: isDark ? Colors.white70 : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isExpanded)
          SizedBox(
            height: 138,
            child: StableThumbScrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                scrollDirection: Axis.horizontal,
                itemCount: episodes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final ep = episodes[index];
                  final isSelected = ep == currentEpisode;
                  final borderColor = isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : theme.colorScheme.outlineVariant);
                  final epTextColor = isDark
                      ? Colors.white
                      : theme.colorScheme.onSurface;
                  final epCardColor = isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : (isDark
                            ? const Color(0xFF1B1D28)
                            : theme.colorScheme.surfaceContainerLow);
                  final epIndexColor = isSelected
                      ? theme.colorScheme.primary
                      : (isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurfaceVariant);
                  final epMetaColor = isDark
                      ? Colors.white54
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        );

                  return Material(
                    color: epCardColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: !isSelected ? () => onEpisodeSelected(ep) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // i18n-ignore: EP-style English episode label — product lexicon
                              'EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}',
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : epIndexColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (ep.name.isNotEmpty)
                              Text(
                                ep.name,
                                style: TextStyle(
                                  color: epTextColor.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (ep.nameCn.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                ep.nameCn,
                                style: TextStyle(
                                  color: epTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const Spacer(),
                            if (ep.airdate.isNotEmpty)
                              Text(
                                ep.airdate,
                                style: TextStyle(
                                  color: epMetaColor,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Mobile info tab body: title, description, episodes, sources, recommendations.
class PlayerMobileInfoLayout extends StatelessWidget {
  final String animeTitle;
  final BangumiEpisode currentEpisode;
  final int playableEpisodeCount;
  final bool isDescriptionExpanded;
  final VoidCallback onToggleDescription;
  final Widget currentSourceActions;
  final PlayerMobileEpisodeStrip episodeStrip;
  final Widget playSourceSelector;
  final Widget resourceList;
  final List<BangumiDataSiteEntry> onairSites;
  final ScrollController onairSitesScrollController;
  final List<RankingAnime> recommendations;
  final bool isLoadingRecommendations;
  final ValueChanged<RankingAnime> onRecommendationTap;
  final ScrollController scrollController;

  const PlayerMobileInfoLayout({
    super.key,
    required this.animeTitle,
    required this.currentEpisode,
    required this.playableEpisodeCount,
    required this.isDescriptionExpanded,
    required this.onToggleDescription,
    required this.currentSourceActions,
    required this.episodeStrip,
    required this.playSourceSelector,
    required this.resourceList,
    required this.onairSites,
    required this.onairSitesScrollController,
    required this.recommendations,
    required this.isLoadingRecommendations,
    required this.onRecommendationTap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final descBgColor = isDark
        ? const Color.fromARGB(255, 20, 20, 25)
        : theme.colorScheme.surfaceContainerHigh;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            animeTitle,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentEpisode.nameCn.isNotEmpty
                ? currentEpisode.nameCn
                : currentEpisode.name,
            style: TextStyle(
              color: subTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  // i18n-ignore: EP-style English episode label — product lexicon
                  'EP ${currentEpisode.sort % 1 == 0 ? currentEpisode.sort.toInt() : currentEpisode.sort}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.playerMobilePlayableEpisodeCount(playableEpisodeCount),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              currentSourceActions,
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onToggleDescription,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: descBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentEpisode.description.isNotEmpty
                        ? currentEpisode.description
                        : l10n.playerNoDescription,
                    maxLines: isDescriptionExpanded ? null : 2,
                    overflow: isDescriptionExpanded
                        ? null
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (currentEpisode.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isDescriptionExpanded
                                ? l10n.playerCollapse
                                : l10n.playerExpand,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          episodeStrip,
          const SizedBox(height: 24),
          PlayerSectionHeader(l10n.playerMobilePlaySource),
          const SizedBox(height: 12),
          playSourceSelector,
          const SizedBox(height: 12),
          resourceList,
          const SizedBox(height: 24),
          if (onairSites.isNotEmpty) ...[
            PlayerSectionHeader(l10n.playerMobileOfficialPlaySource),
            const SizedBox(height: 12),
            PlayerOnairSitesList(
              sites: onairSites,
              scrollController: onairSitesScrollController,
            ),
            const SizedBox(height: 24),
          ],
          PlayerSectionHeader(l10n.playerMobileRelated),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlayerRecommendations(
              recommendations: recommendations,
              isLoading: isLoadingRecommendations,
              isVertical: false,
              onItemTap: onRecommendationTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-level mobile scaffold: video area + tabbed info/comments.
class PlayerMobileLayout extends StatelessWidget {
  final Widget videoArea;
  final TabController tabController;
  final int commentsCount;
  final Widget infoTab;
  final Widget commentsTab;

  const PlayerMobileLayout({
    super.key,
    required this.videoArea,
    required this.tabController,
    required this.commentsCount,
    required this.infoTab,
    required this.commentsTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: AspectRatio(aspectRatio: 16 / 9, child: videoArea),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                color: isDark
                    ? const Color(0xFF16161E)
                    : theme.colorScheme.surfaceContainerLow,
                child: TabBar(
                  controller: tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: isDark
                      ? Colors.grey
                      : theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: l10n.playerMobileSummaryAndRecommend),
                    Tab(text: l10n.playerMobileCommentsTab(commentsCount)),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [infoTab, commentsTab],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
