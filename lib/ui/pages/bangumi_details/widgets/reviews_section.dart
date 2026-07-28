import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_blog_detail_dialog.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Reviews section of the Bangumi details page (mobile + wide layouts).
class ReviewsSection extends StatelessWidget {
  final List<BangumiReview> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final void Function(BangumiReview review)? onReviewTap;

  const ReviewsSection({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    this.scrollController,
    this.onLoadMore,
    this.onReviewTap,
  });

  static const double _loadMoreThreshold = 200;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = _reviewItemCount(reviews, isLoadingMore);
    final list = ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildReviewItem(
          context: context,
          index: index,
          itemCount: itemCount,
          reviews: reviews,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
          onReviewTap: onReviewTap,
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

/// Sliver variant used by the wide details layout so reviews remain lazy
/// children of the page's primary scroll view.
class ReviewsSliver extends StatelessWidget {
  final List<BangumiReview> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final void Function(BangumiReview review)? onReviewTap;

  const ReviewsSliver({
    super.key,
    required this.reviews,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverToBoxAdapter(child: loadingPlaceholder(context));
    }
    if (reviews.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final itemCount = _reviewItemCount(reviews, isLoadingMore);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildReviewItem(
          context: context,
          index: index,
          itemCount: itemCount,
          reviews: reviews,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
          onReviewTap: onReviewTap,
        ),
        childCount: itemCount,
      ),
    );
  }
}

int _reviewItemCount(List<BangumiReview> reviews, bool isLoadingMore) =>
    reviews.length + 1 + (isLoadingMore ? 1 : 0);

Widget _buildReviewItem({
  required BuildContext context,
  required int index,
  required int itemCount,
  required List<BangumiReview> reviews,
  required bool isLoadingMore,
  required bool isDarkBg,
  required Widget sectionTitle,
  void Function(BangumiReview review)? onReviewTap,
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
  final review = reviews[index - 1];
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _ReviewCard(
      key: ValueKey<BangumiReview>(review),
      review: review,
      isDarkBg: isDarkBg,
      onTap: () {
        if (onReviewTap != null) {
          onReviewTap(review);
        } else {
          showBangumiBlogDetailDialog(context, review: review);
        }
      },
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  final BangumiReview review;
  final bool isDarkBg;
  final VoidCallback onTap;

  const _ReviewCard({
    super.key,
    required this.review,
    required this.isDarkBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkBg ? Colors.white : Colors.black87;
    final cardColor = isDarkBg
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey[100];
    final subTextColor = isDarkBg ? Colors.white60 : Colors.black54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkBg ? Colors.white10 : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkBg ? Colors.white10 : Colors.grey[200],
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: review.avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: review.avatar,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.person,
                                size: 16,
                                color: isDarkBg
                                    ? Colors.white30
                                    : Colors.grey[400],
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 16,
                              color: isDarkBg
                                  ? Colors.white30
                                  : Colors.grey[400],
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review.userName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (review.time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      review.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                review.title.isNotEmpty
                    ? review.title
                    : AppLocalizations.of(context).bangumiDetailsTabReviews,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (review.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  review.summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 13,
                    color: subTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${review.repliesCount}',
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
