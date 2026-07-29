import 'package:flutter/material.dart';

import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// A single Bangumi reaction chip: the upstream sticker plus its count.
///
/// Shared by the comments list and the blog / topic detail dialogs so the
/// "reacted by me" highlight and sticker sizing stay identical everywhere.
class BangumiReactionBadge extends StatelessWidget {
  const BangumiReactionBadge({
    super.key,
    required this.reaction,
    required this.isDarkBg,
  });

  final BangumiCommentReaction reaction;
  final bool isDarkBg;

  @override
  Widget build(BuildContext context) {
    final foreground = isDarkBg ? Colors.white70 : Colors.black54;
    return Tooltip(
      message: '(${reaction.name}) ${reaction.count}',
      child: Container(
        key: ValueKey('bangumi-reaction-${reaction.name}'),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: reaction.reacted
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : (isDarkBg
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: reaction.name,
              image: true,
              child: ExcludeSemantics(
                child: CachedNetworkImage(
                  imageUrl: reaction.imageUrl,
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  // Stickers are tiny and part of the text flow, so load them
                  // with their row rather than waiting for a viewport check.
                  deferOffscreenLoad: false,
                  networkFallbackWhileCaching: false,
                  placeholder: const SizedBox(width: 16, height: 16),
                  errorWidget: const Icon(Icons.sentiment_neutral, size: 14),
                ),
              ),
            ),
            if (reaction.count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${reaction.count}',
                style: TextStyle(fontSize: 11, color: foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
