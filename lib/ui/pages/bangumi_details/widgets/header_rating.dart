import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Compact rating row used in the mobile header.
///
/// Stateless presentational widget extracted from `_buildHeaderRatingRow` in
/// `bangumi_details_page.dart`. Always renders against the blurred cover
/// background, so text colors are hard-coded to white.
class BangumiRatingRow extends StatelessWidget {
  final dynamic rating;

  const BangumiRatingRow({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final score = (rating['score'] as num?)?.toDouble() ?? 0.0;
    final total = (rating['total'] as num?)?.toInt() ?? 0;
    final rank = (rating['rank'] as num?)?.toInt() ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$score",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < (score / 2).round()
                        ? Icons.star
                        : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  );
                }),
              ),
              const SizedBox(height: 2),
              Text(
                rank > 0
                    ? l10n.bangumiDetailsRatingVotesWithRank(total, rank)
                    : l10n.bangumiDetailsRatingVotes(total),
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rating card used in the wide layout's left panel, including voting totals,
/// the rank row, and the compact collection stats (wish / doing / dropped).
///
/// Stateless presentational widget extracted from `_buildRatingCard` and
/// `_buildCompactStatItem` in `bangumi_details_page.dart`.
class BangumiRatingCard extends StatelessWidget {
  final Map<String, dynamic>? rating;
  final Map<String, dynamic>? collection;

  const BangumiRatingCard({
    super.key,
    required this.rating,
    required this.collection,
  });

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final score = rating!['score'];
    final rank = (rating!['rank'] as num?)?.toInt() ?? 0;
    final count = (rating!['total'] as num?)?.toInt() ?? 0;

    final wish = (collection?['wish'] as num?)?.toInt() ?? 0;
    final doing = (collection?['doing'] as num?)?.toInt() ?? 0;
    final dropped = (collection?['dropped'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text(
                "$score",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.bangumiDetailsVotes(count),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (rank > 0) ...[
            const Divider(color: Colors.white24, height: 24),
            Text(
              l10n.bangumiDetailsRanked(rank),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
          if (collection != null) ...[
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStatItem(l10n.bangumiDetailsCollectWish, wish),
                _buildCompactStatItem(l10n.bangumiDetailsCollectDoing, doing),
                _buildCompactStatItem(
                  l10n.bangumiDetailsCollectDropped,
                  dropped,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          "$value",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}
