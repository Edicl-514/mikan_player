import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Comments section of the Bangumi details page (mobile + wide layouts).
///
/// Extracted from `_buildCommentsSection` in `bangumi_details_page.dart` to
/// isolate the display tree from the page's comment-fetching, pagination, and
/// lifecycle logic. The widget has no hidden service/global state — all data
/// and styling hooks are passed through the constructor. The page retains
/// `_ensureCommentsLoaded`/`_loadMoreComments`, the comment state fields, and
/// the scroll-listener wiring; this widget only renders the supplied list.
///
/// Renders the comment list with [ListView.builder] so only viewport-visible
/// cards are built (avoids the previous eager `Column` mapping of every
/// `_CommentCard`, which made switching to the 评论 tab drop frames on
/// subjects with many comments).
///
/// On mobile, [onLoadMore] observes the list's own scroll notifications. This
/// lets a surrounding [NestedScrollView] continue to supply the primary scroll
/// controller while still supporting comment pagination.
class CommentsSection extends StatelessWidget {
  final List<BangumiComment> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;

  const CommentsSection({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    this.scrollController,
    this.onLoadMore,
  });

  static const double _loadMoreThreshold = 200;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (comments.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = _commentItemCount(comments, isLoadingMore);
    final list = ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildCommentItem(
          index: index,
          itemCount: itemCount,
          comments: comments,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
        );
      },
    );

    if (onLoadMore == null) return list;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final isScrollEvent =
            notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification ||
            notification is OverscrollNotification;
        if (isScrollEvent &&
            notification.metrics.axis == Axis.vertical &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - _loadMoreThreshold) {
          onLoadMore!();
        }
        return false;
      },
      child: list,
    );
  }
}

/// Sliver variant used by the wide details layout so comments remain lazy
/// children of the page's primary scroll view.
class CommentsSliver extends StatelessWidget {
  final List<BangumiComment> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;

  const CommentsSliver({
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
      return SliverToBoxAdapter(child: loadingPlaceholder(context));
    }
    if (comments.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final itemCount = _commentItemCount(comments, isLoadingMore);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildCommentItem(
          index: index,
          itemCount: itemCount,
          comments: comments,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
        ),
        childCount: itemCount,
      ),
    );
  }
}

int _commentItemCount(List<BangumiComment> comments, bool isLoadingMore) =>
    comments.length + 1 + (isLoadingMore ? 1 : 0);

Widget _buildCommentItem({
  required int index,
  required int itemCount,
  required List<BangumiComment> comments,
  required bool isLoadingMore,
  required bool isDarkBg,
  required Widget sectionTitle,
}) {
  if (index == 0) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: sectionTitle,
    );
  }
  if (isLoadingMore && index == itemCount - 1) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
  final comment = comments[index - 1];
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _CommentCard(
      key: ValueKey<BangumiComment>(comment),
      comment: comment,
      isDarkBg: isDarkBg,
    ),
  );
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
                if (comment.collectionType != null) ...[
                  const SizedBox(height: 4),
                  _CollectionTypeLabel(
                    collectionType: comment.collectionType!,
                    isDarkBg: isDarkBg,
                  ),
                ],
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
                if (comment.reactions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: comment.reactions
                        .where((reaction) => reaction.count > 0)
                        .map(
                          (reaction) => BangumiReactionBadge(
                            reaction: reaction,
                            isDarkBg: isDarkBg,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTypeLabel extends StatelessWidget {
  const _CollectionTypeLabel({
    required this.collectionType,
    required this.isDarkBg,
  });

  final int collectionType;
  final bool isDarkBg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (collectionType) {
      1 => l10n.favoritesStatusWish,
      2 => l10n.favoritesStatusWatched,
      3 => l10n.favoritesStatusWatching,
      4 => l10n.favoritesStatusOnHold,
      5 => l10n.favoritesStatusDropped,
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();

    final color = isDarkBg ? Colors.white60 : Colors.black54;
    return Text(label, style: TextStyle(fontSize: 11, color: color));
  }
}
