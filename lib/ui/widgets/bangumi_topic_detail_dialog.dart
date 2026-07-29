import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/src/rust/frb_api/bangumi.dart' as bangumi_api;
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Shows a dialog displaying the full Bangumi topic and its floor replies.
Future<void> showBangumiTopicDetailDialog(
  BuildContext context, {
  required BangumiTopic topic,
  Future<BangumiTopicDetail> Function(int topicId)? fetchDetail,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        BangumiTopicDetailDialog(topic: topic, fetchDetail: fetchDetail),
  );
}

class BangumiTopicDetailDialog extends StatefulWidget {
  final BangumiTopic topic;
  final Future<BangumiTopicDetail> Function(int topicId)? fetchDetail;

  const BangumiTopicDetailDialog({
    super.key,
    required this.topic,
    this.fetchDetail,
  });

  @override
  State<BangumiTopicDetailDialog> createState() =>
      _BangumiTopicDetailDialogState();
}

class _BangumiTopicDetailDialogState extends State<BangumiTopicDetailDialog> {
  BangumiTopicDetail? _detail;
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadTopicDetail();
  }

  Future<void> _loadTopicDetail() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _failed = false;
      });
    }

    try {
      final detail =
          await (widget.fetchDetail?.call(widget.topic.id) ??
              bangumi_api.fetchBangumiTopicDetail(topicId: widget.topic.id));
      if (mounted) {
        setState(() {
          _detail = detail;
          _failed = false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final title = _detail?.title ?? widget.topic.title;
    final userName = _detail?.userName ?? widget.topic.userName;
    final avatar = _detail?.avatar ?? widget.topic.avatar;
    final time = _detail?.time ?? widget.topic.time;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.bangumiDetailsTabTopics,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.bangumiTopicDetailLoadFailed,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _loadTopicDetail();
                              },
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic Header
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ClipOval(
                                child: avatar.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: avatar,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorWidget: Icon(
                                          Icons.person,
                                          size: 18,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 18,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        userName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '#1',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (time.isNotEmpty)
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (_detail!.contentHtml.isNotEmpty ||
                              bangumiCommentStateHidesContent(
                                _detail!.contentState,
                              )) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            // Opening post. Routed through BangumiCommentBody so a
                            // deleted or folded floor 1 is not rendered as normal.
                            BangumiCommentBody(
                              state: _detail!.contentState,
                              html: _detail!.contentHtml,
                              textStyle: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                                height: 1.6,
                              ),
                            ),
                            if (!bangumiCommentStateHidesContent(
                                  _detail!.contentState,
                                ) &&
                                _detail!.reactions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _detail!.reactions
                                    .map(
                                      (r) => BangumiReactionBadge(
                                        reaction: r,
                                        isDarkBg: isDark,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                          const SizedBox(height: 24),
                          // Floor Replies
                          if (_detail!.replies.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              l10n.bangumiDetailsComments,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._detail!.replies.asMap().entries.map(
                              (entry) => _TopicCommentTile(
                                comment: entry.value,
                                floorLabel: '#${entry.key + 2}',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCommentTile extends StatelessWidget {
  final BangumiEpisodeComment comment;
  final String? floorLabel;
  final bool isDark;
  final bool isSubReply;

  const _TopicCommentTile({
    required this.comment,
    this.floorLabel,
    required this.isDark,
    this.isSubReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = isSubReply ? 24.0 : 32.0;
    final authorName = comment.userName.isNotEmpty
        ? comment.userName
        : (comment.userId.isNotEmpty ? comment.userId : '');

    return Container(
      margin: EdgeInsets.only(bottom: isSubReply ? 8 : 12),
      padding: EdgeInsets.all(isSubReply ? 10 : 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: isSubReply ? 0.03 : 0.05)
            : (isSubReply
                  ? Colors.grey.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(8),
        border: isSubReply
            ? Border(
                left: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
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
                  color: isDark ? Colors.white10 : Colors.grey[200],
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: avatarSize * 0.6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontSize: isSubReply ? 12 : 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
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
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BangumiCommentBody(
            state: comment.state,
            html: comment.contentHtml,
            textStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          if (!bangumiCommentStateHidesContent(comment.state) &&
              comment.reactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: comment.reactions
                  .map(
                    (r) => BangumiReactionBadge(reaction: r, isDarkBg: isDark),
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
                      (entry) => _TopicCommentTile(
                        comment: entry.value,
                        floorLabel: floorLabel != null
                            ? '$floorLabel-${entry.key + 1}'
                            : null,
                        isDark: isDark,
                        isSubReply: true,
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
