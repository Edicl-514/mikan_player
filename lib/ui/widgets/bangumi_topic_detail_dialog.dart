import 'package:flutter/material.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/src/rust/frb_api/bangumi.dart' as bangumi_api;
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_tile.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/smooth_scroll_controller.dart';

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
  final ScrollController _scrollController = createPlatformScrollController();
  BangumiTopicDetail? _detail;
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadTopicDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
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
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            userName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.bangumiTopicFloor(1),
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
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                              ],
                            ]),
                          ),
                        ),
                        if (_detail!.replies.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.builder(
                              itemCount: _detail!.replies.length,
                              itemBuilder: (context, index) =>
                                  BangumiCommentTile(
                                    key: ValueKey(_detail!.replies[index].id),
                                    comment: _detail!.replies[index],
                                    isDarkBg: isDark,
                                    floorLabel: l10n.bangumiTopicFloor(index + 2),
                                  ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
