import 'package:flutter/material.dart';
import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_comments.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_onair_sites_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_pc_episode_list.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_recommendations.dart';
import 'package:mikan_player/ui/pages/player/widgets/player_section_header.dart';

/// Wide-screen player layout: main column + right sidebar.
class PlayerPcLayout extends StatelessWidget {
  final String animeTitle;
  final BangumiEpisode currentEpisode;
  final Widget currentSourceActions;
  final Widget videoArea;
  final bool isDescriptionExpanded;
  final VoidCallback onToggleDescription;
  final Widget playSourceSelector;
  final Widget resourceList;
  final List<BangumiDataSiteEntry> onairSites;
  final Widget commentSortButton;
  final List<BangumiEpisodeComment> comments;
  final bool isLoadingComments;
  final String? commentsError;
  final List<BangumiEpisode> playableEpisodes;
  final ScrollController episodeScrollController;
  final ValueChanged<BangumiEpisode> onEpisodeSelected;
  final List<RankingAnime> recommendations;
  final bool isLoadingRecommendations;
  final ValueChanged<RankingAnime> onRecommendationTap;
  final ScrollController mainScrollController;
  final ScrollController sidebarScrollController;

  const PlayerPcLayout({
    super.key,
    required this.animeTitle,
    required this.currentEpisode,
    required this.currentSourceActions,
    required this.videoArea,
    required this.isDescriptionExpanded,
    required this.onToggleDescription,
    required this.playSourceSelector,
    required this.resourceList,
    required this.onairSites,
    required this.commentSortButton,
    required this.comments,
    required this.isLoadingComments,
    required this.commentsError,
    required this.playableEpisodes,
    required this.episodeScrollController,
    required this.onEpisodeSelected,
    required this.recommendations,
    required this.isLoadingRecommendations,
    required this.onRecommendationTap,
    required this.mainScrollController,
    required this.sidebarScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF0F0F13)
        : theme.scaffoldBackgroundColor;
    final sidebarColor = isDark
        ? const Color(0xFF13131A)
        : theme.colorScheme.surfaceContainerLow;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final borderColor = isDark
        ? Colors.white10
        : Colors.grey.withValues(alpha: 0.3);

    final episodeLabel =
        'EP ${currentEpisode.sort % 1 == 0 ? currentEpisode.sort.toInt() : currentEpisode.sort} - ${currentEpisode.nameCn.isNotEmpty ? currentEpisode.nameCn : currentEpisode.name}';

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                color: bgColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: textColor,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                animeTitle,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episodeLabel,
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        currentSourceActions,
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  controller: mainScrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: Colors.black,
                                  child: videoArea,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            color: bgColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: onToggleDescription,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color.fromARGB(
                                              255,
                                              20,
                                              20,
                                              25,
                                            )
                                          : theme
                                                .colorScheme
                                                .surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentEpisode.description.isNotEmpty
                                              ? currentEpisode.description
                                              : l10n.playerNoDescription,
                                          maxLines: isDescriptionExpanded
                                              ? null
                                              : 2,
                                          overflow: isDescriptionExpanded
                                              ? null
                                              : TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                        if (currentEpisode
                                            .description
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  isDescriptionExpanded
                                                      ? l10n.playerCollapse
                                                      : l10n.playerExpand,
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Icon(
                                                  isDescriptionExpanded
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons
                                                            .keyboard_arrow_down,
                                                  size: 16,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                PlayerSectionHeader(l10n.playerMobilePlaySource),
                                const SizedBox(height: 12),
                                playSourceSelector,
                                const SizedBox(height: 12),
                                resourceList,
                                if (onairSites.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  PlayerSectionHeader(
                                    l10n.playerMobileOfficialPlaySource,
                                  ),
                                  const SizedBox(height: 12),
                                  PlayerOnairSitesList(sites: onairSites),
                                ],
                              ],
                            ),
                          ),
                          Divider(height: 1, color: borderColor),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlayerSectionHeader(
                              l10n.playerPcCommentsSection,
                              trailing: commentSortButton,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (isLoadingComments)
                      const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (commentsError != null)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              l10n.playerCommentsLoadFailedPc(
                                commentsError!,
                              ),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      )
                    else if (comments.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              l10n.playerCommentsEmptyPc,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return PlayerComments.buildItem(
                              context,
                              comments[index],
                            );
                          }, childCount: comments.length),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 380,
          color: sidebarColor,
          child: CustomScrollView(
            controller: sidebarScrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    PlayerSectionHeader(l10n.playerPcPlaylist),
                    const SizedBox(height: 12),
                    Text(
                      l10n.playerPcEpisodeList,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Tight height so the inner ListView gets a real viewport.
                  // ConstrainedBox(maxHeight) + shrinkWrap nested under
                  // CustomScrollView does not reliably receive wheel events on PC.
                  child: SizedBox(
                    height: 500,
                    child: PlayerPcEpisodeList(
                      episodes: playableEpisodes,
                      currentEpisode: currentEpisode,
                      scrollController: episodeScrollController,
                      onEpisodeSelected: onEpisodeSelected,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    PlayerSectionHeader(l10n.playerMobileRelated),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PlayerRecommendations(
                        recommendations: recommendations,
                        isLoading: isLoadingRecommendations,
                        isVertical: true,
                        onItemTap: onRecommendationTap,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
