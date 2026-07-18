import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Collection-stats row with a compact favorite button used in the mobile
/// header. Stateless presentational widget extracted from
/// `_buildCollectionStatsRow` in `bangumi_details_page.dart`.
class BangumiCollectionStatsRow extends StatelessWidget {
  final Map<String, dynamic>? collection;
  final bool isLocalFavorite;
  final VoidCallback onToggleFavorite;

  const BangumiCollectionStatsRow({
    super.key,
    required this.collection,
    required this.isLocalFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (collection == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final wish = (collection!['wish'] as num?)?.toInt() ?? 0;
    final doing = (collection!['doing'] as num?)?.toInt() ?? 0;
    final dropped = (collection!['dropped'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.bangumiDetailsCollectionStats(wish, doing, dropped),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleFavorite,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4081), Color(0xFFF50057)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLocalFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLocalFavorite
                          ? l10n.bangumiDetailsFavorited
                          : l10n.bangumiDetailsFavorite,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
