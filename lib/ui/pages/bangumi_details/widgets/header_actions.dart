import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';

/// Share + favorite action buttons used in the wide layout's left panel.
///
/// Stateless presentational widget extracted from `_buildActionButtons` in
/// `bangumi_details_page.dart`. The host (page) owns the copied timer state
/// and the navigation/copy logic, exposing them through callbacks. The
/// `isCopied` flag toggles the share button's icon and color; `onShareTapped`
/// performs the actual clipboard write and resets the flag after two seconds.
class BangumiActionButtons extends StatelessWidget {
  final bool isLocalFavorite;
  final bool isCopied;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onShareTapped;

  const BangumiActionButtons({
    super.key,
    required this.isLocalFavorite,
    required this.isCopied,
    required this.onToggleFavorite,
    required this.onShareTapped,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onToggleFavorite,
            icon: Icon(
              isLocalFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            label: Text(isLocalFavorite ? "已收藏" : "收藏"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onShareTapped,
            icon: Icon(isCopied ? Icons.check_rounded : Icons.share),
            label: Text(isCopied ? l10n.copied : l10n.share),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isCopied
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              foregroundColor: isCopied ? Colors.greenAccent : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isCopied
                    ? const BorderSide(color: Colors.greenAccent, width: 1)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
