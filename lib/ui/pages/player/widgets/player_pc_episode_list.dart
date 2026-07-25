import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

/// Vertical episode list used by the PC player sidebar.
class PlayerPcEpisodeList extends StatelessWidget {
  final List<BangumiEpisode> episodes;
  final BangumiEpisode currentEpisode;
  final ScrollController scrollController;
  final ValueChanged<BangumiEpisode> onEpisodeSelected;
  final double maxHeight;

  const PlayerPcEpisodeList({
    super.key,
    required this.episodes,
    required this.currentEpisode,
    required this.scrollController,
    required this.onEpisodeSelected,
    this.maxHeight = 420.0,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E1E2C)
        : theme.colorScheme.surfaceContainer;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final mutedTextColor = isDark
        ? Colors.white54
        : theme.colorScheme.onSurfaceVariant;
    final faintTextColor = isDark
        ? Colors.white24
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    // Calculate estimated total height for all items to determine if shrinkWrap
    // should be used (when total height fits within [maxHeight]).
    double totalEstimatedHeight = 0;
    for (int i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      final hasTwoLines = ep.nameCn.isNotEmpty && ep.name.isNotEmpty;
      totalEstimatedHeight += hasTwoLines ? 58.0 : 44.0;
      if (i < episodes.length - 1) {
        totalEstimatedHeight += 8.0;
      }
    }

    final bool fitsInMaxHeight = totalEstimatedHeight <= maxHeight;

    Widget buildListView() {
      return ListView.separated(
        controller: fitsInMaxHeight ? null : scrollController,
        primary: false,
        shrinkWrap: fitsInMaxHeight,
        physics: fitsInMaxHeight
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(right: fitsInMaxHeight ? 0 : 12),
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final ep = episodes[index];
          final isSelected = ep == currentEpisode;
          final epCardColor = isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : cardColor;

          return Container(
            decoration: BoxDecoration(
              color: epCardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () => onEpisodeSelected(ep),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        "${ep.sort % 1 == 0 ? ep.sort.toInt() : ep.sort}",
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : subTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ep.nameCn.isNotEmpty)
                            Text(
                              ep.nameCn,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : textColor,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (ep.name.isNotEmpty)
                            Text(
                              ep.name,
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (ep.airdate.isNotEmpty)
                      Text(
                        ep.airdate,
                        style: TextStyle(color: faintTextColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (fitsInMaxHeight) {
      return buildListView();
    }

    return SizedBox(
      height: maxHeight,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: buildListView(),
      ),
    );
  }
}
