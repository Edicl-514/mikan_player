import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_topic_detail_dialog.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Topics section of the Bangumi details page (mobile + wide layouts).
class TopicsSection extends StatelessWidget {
  final List<BangumiTopic> topics;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final void Function(BangumiTopic topic)? onTopicTap;

  const TopicsSection({
    super.key,
    required this.topics,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    this.scrollController,
    this.onLoadMore,
    this.onTopicTap,
  });

  static const double _loadMoreThreshold = 200;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingPlaceholder(context);
    }

    if (topics.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = _topicItemCount(topics, isLoadingMore);
    final list = ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildTopicItem(
          context: context,
          index: index,
          itemCount: itemCount,
          topics: topics,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
          onTopicTap: onTopicTap,
        );
      },
    );

    if (onLoadMore == null) return list;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
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

/// Sliver variant used by the wide details layout so topics remain lazy
/// children of the page's primary scroll view.
class TopicsSliver extends StatelessWidget {
  final List<BangumiTopic> topics;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDarkBg;
  final Widget sectionTitle;
  final WidgetBuilder loadingPlaceholder;
  final void Function(BangumiTopic topic)? onTopicTap;

  const TopicsSliver({
    super.key,
    required this.topics,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isDarkBg,
    required this.sectionTitle,
    required this.loadingPlaceholder,
    this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverToBoxAdapter(child: loadingPlaceholder(context));
    }
    if (topics.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final itemCount = _topicItemCount(topics, isLoadingMore);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildTopicItem(
          context: context,
          index: index,
          itemCount: itemCount,
          topics: topics,
          isLoadingMore: isLoadingMore,
          isDarkBg: isDarkBg,
          sectionTitle: sectionTitle,
          onTopicTap: onTopicTap,
        ),
        childCount: itemCount,
      ),
    );
  }
}

int _topicItemCount(List<BangumiTopic> topics, bool isLoadingMore) =>
    topics.length + 1 + (isLoadingMore ? 1 : 0);

Widget _buildTopicItem({
  required BuildContext context,
  required int index,
  required int itemCount,
  required List<BangumiTopic> topics,
  required bool isLoadingMore,
  required bool isDarkBg,
  required Widget sectionTitle,
  void Function(BangumiTopic topic)? onTopicTap,
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
  final topic = topics[index - 1];
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _TopicCard(
      key: ValueKey<BangumiTopic>(topic),
      topic: topic,
      isDarkBg: isDarkBg,
      onTap: () {
        if (onTopicTap != null) {
          onTopicTap(topic);
        } else {
          showBangumiTopicDetailDialog(context, topic: topic);
        }
      },
    ),
  );
}

class _TopicCard extends StatelessWidget {
  final BangumiTopic topic;
  final bool isDarkBg;
  final VoidCallback onTap;

  const _TopicCard({
    super.key,
    required this.topic,
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

    final displayTime = topic.updatedAt.isNotEmpty
        ? topic.updatedAt
        : topic.time;
    final authorName = topic.userName.isNotEmpty
        ? topic.userName
        : (topic.userId.isNotEmpty ? topic.userId : '');

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
                      child: topic.avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: topic.avatar,
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
                      authorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (displayTime.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      displayTime,
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
                topic.title.isNotEmpty
                    ? topic.title
                    : AppLocalizations.of(context).bangumiDetailsTabTopics,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
                    '${topic.repliesCount}',
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
