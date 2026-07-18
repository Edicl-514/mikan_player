import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

/// Vertical episode list used by the PC player sidebar.
class PlayerPcEpisodeList extends StatelessWidget {
  final List<BangumiEpisode> episodes;
  final BangumiEpisode currentEpisode;
  final ScrollController scrollController;
  final ValueChanged<BangumiEpisode> onEpisodeSelected;

  const PlayerPcEpisodeList({
    super.key,
    required this.episodes,
    required this.currentEpisode,
    required this.scrollController,
    required this.onEpisodeSelected,
  });

  @override
  Widget build(BuildContext context) {
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
    // Must receive a bounded height from the parent. shrinkWrap + nested
    // CustomScrollView breaks mouse-wheel scrolling on desktop (PC sidebar).
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: scrollController,
        primary: false,
        padding: const EdgeInsets.only(right: 12),
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
      ),
    );
  }
}
