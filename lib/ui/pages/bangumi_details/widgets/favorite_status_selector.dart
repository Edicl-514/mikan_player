import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/models/local_favorite.dart';

/// Localized label for a Bangumi-compatible local favorite type.
///
/// Falls back to [AppLocalizations.bangumiDetailsFavorited] when [type] is
/// null/unknown so callers can safely use it for the idle favorite button.
String bangumiFavoriteStatusLabel(AppLocalizations l10n, int? type) {
  return switch (type) {
    LocalFavoriteType.wish => l10n.favoritesStatusWish,
    LocalFavoriteType.watched => l10n.favoritesStatusWatched,
    LocalFavoriteType.watching => l10n.favoritesStatusWatching,
    LocalFavoriteType.onHold => l10n.favoritesStatusOnHold,
    LocalFavoriteType.dropped => l10n.favoritesStatusDropped,
    _ => l10n.bangumiDetailsFavorited,
  };
}

/// Compact horizontal selector for Bangumi-compatible collection states.
///
/// Fills the parent constraints (full width + given [height]) so toggling
/// into selector mode does not resize the surrounding action / stats row.
class BangumiFavoriteStatusSelector extends StatelessWidget {
  final int? selectedType;
  final bool isUpdating;
  final ValueChanged<int> onSelected;
  final VoidCallback onTrailingAction;

  /// Outer height of the control; keep in sync with the idle-state sibling.
  final double height;

  const BangumiFavoriteStatusSelector({
    super.key,
    required this.selectedType,
    required this.isUpdating,
    required this.onSelected,
    required this.onTrailingAction,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFavorite = selectedType != null;
    final colorScheme = Theme.of(context).colorScheme;
    // Leave a little air so outline buttons don't touch the outer clip edges.
    final buttonHeight = (height - 4).clamp(32.0, height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                key: const ValueKey('favorite-status-segments'),
                children: [
                  for (
                    var index = 0;
                    index < LocalFavoriteType.values.length;
                    index++
                  )
                    Semantics(
                      selected: selectedType == LocalFavoriteType.values[index],
                      child: OutlinedButton(
                        onPressed: isUpdating
                            ? null
                            : () =>
                                  onSelected(LocalFavoriteType.values[index]),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, buttonHeight),
                          maximumSize: Size(double.infinity, buttonHeight),
                          fixedSize: Size.fromHeight(buttonHeight),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          foregroundColor:
                              selectedType == LocalFavoriteType.values[index]
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          backgroundColor:
                              selectedType == LocalFavoriteType.values[index]
                              ? colorScheme.primary
                              : colorScheme.surface.withValues(alpha: 0.7),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.7),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: index == 0
                                  ? const Radius.circular(20)
                                  : Radius.zero,
                              right: index == LocalFavoriteType.values.length - 1
                                  ? const Radius.circular(20)
                                  : Radius.zero,
                            ),
                          ),
                        ),
                        child: Text(
                          bangumiFavoriteStatusLabel(
                            l10n,
                            LocalFavoriteType.values[index],
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: ValueKey(isFavorite ? 'remove-favorite-action' : 'back-action'),
            onPressed: isUpdating ? null : onTrailingAction,
            icon: isUpdating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isFavorite
                        ? Icons.favorite_border_rounded
                        : Icons.arrow_back_rounded,
                    size: 18,
                  ),
            label: Text(isFavorite ? l10n.cancel : l10n.back),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, buttonHeight),
              maximumSize: Size(double.infinity, buttonHeight),
              fixedSize: Size.fromHeight(buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              foregroundColor: isFavorite
                  ? colorScheme.error
                  : colorScheme.onSurface,
              side: BorderSide(
                color: isFavorite
                    ? colorScheme.error.withValues(alpha: 0.7)
                    : colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
