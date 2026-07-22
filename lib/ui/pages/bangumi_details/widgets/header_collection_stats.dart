import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/favorite_status_selector.dart';

/// Collection-stats row with a compact favorite button used in the mobile
/// header. Stateless presentational widget extracted from
/// `_buildCollectionStatsRow` in `bangumi_details_page.dart`.
class BangumiCollectionStatsRow extends StatelessWidget {
  /// Inner control height shared by the stats/favorite row and the selector so
  /// expanding into status-picker mode does not reflow the mobile header.
  static const double controlHeight = 36;

  final Map<String, dynamic>? collection;
  final bool isLocalFavorite;
  final int? favoriteType;
  final bool isSelectingFavoriteStatus;
  final bool isUpdatingFavorite;
  final VoidCallback onToggleFavorite;
  final ValueChanged<int> onFavoriteTypeSelected;
  final VoidCallback onFavoriteAction;

  const BangumiCollectionStatsRow({
    super.key,
    required this.collection,
    required this.isLocalFavorite,
    required this.favoriteType,
    required this.isSelectingFavoriteStatus,
    required this.isUpdatingFavorite,
    required this.onToggleFavorite,
    required this.onFavoriteTypeSelected,
    required this.onFavoriteAction,
  });

  @override
  Widget build(BuildContext context) {
    if (collection == null && !isSelectingFavoriteStatus) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final wish = (collection?['wish'] as num?)?.toInt() ?? 0;
    final doing = (collection?['doing'] as num?)?.toInt() ?? 0;
    final dropped = (collection?['dropped'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: SizedBox(
        height: controlHeight,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isSelectingFavoriteStatus
              ? BangumiFavoriteStatusSelector(
                  key: const ValueKey('favorite-status-selector'),
                  selectedType: favoriteType,
                  isUpdating: isUpdatingFavorite,
                  onSelected: onFavoriteTypeSelected,
                  onTrailingAction: onFavoriteAction,
                  height: controlHeight,
                )
              : Row(
                  key: const ValueKey('collection-stats-controls'),
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.collections_bookmark_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.bangumiDetailsCollectionStats(
                                wish,
                                doing,
                                dropped,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          height: controlHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
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
                                isLocalFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isLocalFavorite
                                    ? bangumiFavoriteStatusLabel(
                                        l10n,
                                        favoriteType,
                                      )
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
        ),
      ),
    );
  }
}
