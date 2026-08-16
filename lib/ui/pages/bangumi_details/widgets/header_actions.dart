import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/pages/bangumi_details/widgets/favorite_status_selector.dart';

/// Share + favorite action buttons used in the wide layout's left panel.
///
/// Stateless presentational widget extracted from `_buildActionButtons` in
/// `bangumi_details_page.dart`. The host (page) owns the copied timer state
/// and the navigation/copy logic, exposing them through callbacks. The
/// `isCopied` flag toggles the share button's icon and color; `onShareTapped`
/// performs the actual clipboard write and resets the flag after two seconds.
class BangumiActionButtons extends StatelessWidget {
  /// Matches [ElevatedButton] height with `vertical: 16` padding + 24px icon.
  static const double actionHeight = 56;

  final bool isLocalFavorite;
  final int? favoriteType;
  final bool isCopied;
  final bool isSelectingFavoriteStatus;
  final bool isUpdatingFavorite;
  final VoidCallback onToggleFavorite;
  final ValueChanged<int> onFavoriteTypeSelected;
  final VoidCallback onFavoriteAction;
  final VoidCallback? onShareTapped;

  const BangumiActionButtons({
    super.key,
    required this.isLocalFavorite,
    required this.favoriteType,
    required this.isCopied,
    required this.isSelectingFavoriteStatus,
    required this.isUpdatingFavorite,
    required this.onToggleFavorite,
    required this.onFavoriteTypeSelected,
    required this.onFavoriteAction,
    required this.onShareTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Fixed outer box keeps the left-panel stack from shifting when the
    // favorite control swaps between the dual buttons and the status selector.
    return SizedBox(
      height: actionHeight,
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
                height: actionHeight,
              )
            : Row(
                key: const ValueKey('bangumi-action-buttons'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: actionHeight,
                      child: ElevatedButton.icon(
                        onPressed: onToggleFavorite,
                        icon: Icon(
                          isLocalFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          isLocalFavorite
                              ? bangumiFavoriteStatusLabel(l10n, favoriteType)
                              : l10n.bangumiDetailsFavorite,
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(actionHeight),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: actionHeight,
                      child: ElevatedButton.icon(
                        onPressed: onShareTapped,
                        icon: Icon(
                          isCopied ? Icons.check_rounded : Icons.share,
                        ),
                        label: Text(isCopied ? l10n.copied : l10n.share),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(actionHeight),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isCopied
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          foregroundColor: isCopied
                              ? Colors.greenAccent
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isCopied
                                ? const BorderSide(
                                    color: Colors.greenAccent,
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
