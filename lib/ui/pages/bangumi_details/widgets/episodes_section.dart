import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/stable_thumb_scrollbar.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/navigation/workspace_navigation.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/placeholder_section.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/section_title.dart';

/// Horizontal-scrolling list of episode cards for the Bangumi details page.
///
/// Stateless presentational widget extracted from `_buildEpisodesSection` in
/// `bangumi_details_page.dart`. Tapping a released episode invites the host
/// to push the player page via [onEpisodeTap] — the host owns the
/// `AnimeInfo` construction (it may need fresh tags from the page data).
class EpisodesSection extends StatelessWidget {
  final List<BangumiEpisode>? episodes;
  final bool isLoading;
  final bool isDarkBg;
  final ScrollController scrollController;
  final void Function(BangumiEpisode episode) onEpisodeTap;

  const EpisodesSection({
    super.key,
    required this.episodes,
    required this.isLoading,
    required this.isDarkBg,
    required this.scrollController,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return PlaceholderSection(
        title: AppLocalizations.of(context).bangumiDetailsEpisodes,
        icon: Icons.video_library,
        isDarkBg: isDarkBg,
      );
    }

    if (episodes == null || episodes!.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: AppLocalizations.of(context).bangumiDetailsEpisodes,
          isDarkBg: isDarkBg,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 138,
          child: StableThumbScrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 10),
              scrollDirection: Axis.horizontal,
              itemCount: episodes!.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final ep = episodes![index];
                final released = ep.isReleased();
                final epCardColor = released
                    ? cardColor
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey.shade50);
                final epBorderColor = released
                    ? (isDarkBg ? Colors.white10 : Colors.grey[300]!)
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200);
                final epTextColor = released
                    ? textColor
                    : (isDarkBg
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.42));
                final epIndexColor = released
                    ? (isDarkBg ? Colors.amber : Colors.deepPurple)
                    : (isDarkBg
                          ? Colors.amber.withValues(alpha: 0.45)
                          : Colors.blueGrey.withValues(alpha: 0.7));
                final epDateColor = released
                    ? epTextColor.withValues(alpha: 0.5)
                    : epTextColor.withValues(alpha: 0.72);
                return WorkspaceLinkAction(
                  onOpen: (disposition) {
                    if (released) {
                      WorkspaceNavigation.dispatchLink(
                        disposition,
                        () => onEpisodeTap(ep),
                      );
                    }
                  },
                  builder: (context, activate) => Material(
                    color: epCardColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: released ? activate : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: epBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // i18n-ignore: product lexicon episode index prefix
                              'EP ${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: epIndexColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (ep.name.isNotEmpty)
                              Text(
                                ep.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: epTextColor.withValues(alpha: 0.7),
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
                                  fontSize: 11,
                                  color: epTextColor,
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
                                  fontSize: 9,
                                  color: epDateColor,
                                ),
                              ),
                          ],
                        ),
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
