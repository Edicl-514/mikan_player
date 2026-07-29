import 'package:flutter/material.dart';

import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// A single Bangumi comment row used by every read-only comment surface.
///
/// Previously this layout was duplicated four times (`_BangumiCommentTile`,
/// `_PersonCommentTile`, `_BlogCommentTile`, `_TopicCommentTile`); each copy
/// rendered the avatar / author / time / BBCode body / reactions / nested
/// replies almost line-for-line identically. Centralising it keeps the avatar
/// sizing, reaction gating and state-based content hiding consistent and lets
/// the blog / topic dialogs pick up the same hierarchy visual.
///
/// [isDarkBg] chooses between the white-with-alpha palette (rendered on the
/// fixed dark backgrounds of the desktop detail pages / dialogs) and the
/// themed `ColorScheme.surfaceContainerHighest` palette (mobile / light).
/// [floorLabel] renders the optional floor badge used by topic replies;
/// [isSubReply] tightens spacing and avatar size for nested replies.
class BangumiCommentTile extends StatelessWidget {
  const BangumiCommentTile({
    super.key,
    required this.comment,
    required this.isDarkBg,
    this.isSubReply = false,
    this.floorLabel,
  });

  final BangumiEpisodeComment comment;
  final bool isDarkBg;
  final bool isSubReply;
  final String? floorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = isSubReply ? 24.0 : 32.0;

    final cardBg = isDarkBg
        ? Colors.white.withValues(alpha: isSubReply ? 0.03 : 0.05)
        : (isSubReply
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ));

    final textColor = isDarkBg ? Colors.white : theme.colorScheme.onSurface;
    final secondaryTextColor = isDarkBg
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;

    final authorName = comment.userName.isNotEmpty
        ? comment.userName
        : (comment.userId.isNotEmpty ? comment.userId : '');

    return Container(
      margin: EdgeInsets.only(bottom: isSubReply ? 8 : 12),
      padding: EdgeInsets.all(isSubReply ? 10 : 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: isSubReply
            ? Border(
                left: BorderSide(
                  color: isDarkBg
                      ? Colors.amber.withValues(alpha: 0.5)
                      : theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkBg
                      ? Colors.white10
                      : theme.colorScheme.surfaceContainerHigh,
                ),
                child: ClipOval(
                  child: comment.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: comment.avatar,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          errorWidget: Icon(
                            Icons.person,
                            size: avatarSize * 0.6,
                            color: secondaryTextColor,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: avatarSize * 0.6,
                          color: secondaryTextColor,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        authorName,
                        style: TextStyle(
                          fontSize: isSubReply ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (floorLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        floorLabel!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (comment.time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        comment.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BangumiCommentBody(
            state: comment.state,
            html: comment.contentHtml,
            textStyle: TextStyle(fontSize: 13, color: textColor, height: 1.4),
          ),
          if (!bangumiCommentStateHidesContent(comment.state) &&
              comment.reactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: comment.reactions
                  .map(
                    (r) =>
                        BangumiReactionBadge(reaction: r, isDarkBg: isDarkBg),
                  )
                  .toList(),
            ),
          ],
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: comment.replies
                    .asMap()
                    .entries
                    .map(
                      (entry) => BangumiCommentTile(
                        key: ValueKey(entry.value.id),
                        comment: entry.value,
                        isDarkBg: isDarkBg,
                        isSubReply: true,
                        floorLabel: _nestedFloorLabel(floorLabel, entry.key),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Builds the floor label for a nested reply given the parent's label.
///
/// Topic replies cascade their floor numbers (`#2-1`). When the current tile
/// has no floor label (blog / character / person comments) replies stay
/// unlabelled rather than inventing a numbering scheme.
String? _nestedFloorLabel(String? parentLabel, int index) {
  if (parentLabel == null) return null;
  return '$parentLabel-${index + 1}';
}
