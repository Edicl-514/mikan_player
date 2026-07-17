import 'package:flutter/material.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Comments section of the Bangumi details page (wide layout).
///
/// Extracted from `_buildCommentsSection` in `bangumi_details_page.dart` to
/// isolate the display tree from the page's comment-fetching, pagination, and
/// lifecycle logic. The widget has no hidden service/global state — all data
/// and styling hooks are passed through the constructor. The page retains
/// `_ensureCommentsLoaded`/`_loadMoreComments`, the comment state fields, and
/// the scroll-listener wiring; this widget only renders the supplied list.
class CommentsSection extends StatelessWidget {
  final List<BangumiComment> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;

  const CommentsSection({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (comments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle,
        const SizedBox(height: 12),
        ...comments.map(
          (comment) => _CommentCard(
            key: ValueKey<BangumiComment>(comment),
            comment: comment,
            isDarkBg: isDarkBg,
          ),
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  final BangumiComment comment;
  final bool isDarkBg;

  const _CommentCard({
    super.key,
    required this.comment,
    required this.isDarkBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkBg ? Colors.white10 : Colors.grey[300]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkBg ? Colors.white10 : Colors.grey[200],
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: comment.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: comment.avatar,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.person,
                        size: 20,
                        color: isDarkBg ? Colors.white30 : Colors.grey[400],
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 20,
                      color: isDarkBg ? Colors.white30 : Colors.grey[400],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment.rate != null)
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < (comment.rate! / 2).round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 12,
                            color: Colors.amber,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                BangumiCommentHtml(
                  html: comment.contentHtml.isNotEmpty
                      ? comment.contentHtml
                      : comment.content,
                  textStyle: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
