import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/ranking.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// 相关推荐 - player-side recommendation list.
///
/// A display-only widget extracted from `PlayerPage`. It reproduces the three
/// layouts of the original inline builder (loading / empty / vertical column /
/// horizontal scroll) byte-for-byte and forwards item taps through
/// [onItemTap]. The page keeps ownership of recommendation loading state,
/// error handling, and navigation.
class PlayerRecommendations extends StatelessWidget {
  final List<RankingAnime> recommendations;
  final bool isLoading;
  final bool isVertical;
  final void Function(RankingAnime)? onItemTap;

  const PlayerRecommendations({
    super.key,
    required this.recommendations,
    required this.isLoading,
    required this.isVertical,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Text(
          l10n.playerRecommendationsEmpty,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    if (isVertical) {
      return Column(
        children: recommendations
            .map((item) => _buildItemVertical(context, item))
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < recommendations.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _buildItemHorizontal(context, recommendations[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildItemHorizontal(BuildContext context, RankingAnime item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onTap = onItemTap;
    return InkWell(
      onTap: onTap == null ? null : () => onTap(item),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF252535)
                    : theme.colorScheme.surfaceContainerHigh,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildCover(item, borderRadius: 12),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.info.isNotEmpty)
              Text(
                item.info.split(' / ').first,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemVertical(BuildContext context, RankingAnime item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onTap = onItemTap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap(item),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark
                    ? const Color(0xFF252535)
                    : theme.colorScheme.surfaceContainerHigh,
              ),
              child: _buildCover(item, borderRadius: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.info.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.info.split(' / ').first,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (item.score != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 10, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          "${item.score}",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildCover(RankingAnime item, {required double borderRadius}) {
    if (item.coverUrl.isEmpty) return null;

    return Hero(
      tag: 'player_rec_${item.bangumiId}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(imageUrl: item.coverUrl, fit: BoxFit.cover),
      ),
    );
  }
}
