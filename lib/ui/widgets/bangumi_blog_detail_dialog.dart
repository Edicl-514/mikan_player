import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/src/rust/frb_api/bangumi.dart' as bangumi_api;
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_tile.dart';
import 'package:mikan_player/ui/widgets/bangumi_reaction_badge.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

/// Shows a dialog displaying the full Bangumi blog entry (review) and its comments.
Future<void> showBangumiBlogDetailDialog(
  BuildContext context, {
  required BangumiReview review,
  Future<BangumiBlogDetail> Function(int entryId)? fetchDetail,
  Future<List<BangumiEpisodeComment>> Function(int entryId)? fetchComments,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BangumiBlogDetailDialog(
      review: review,
      fetchDetail: fetchDetail,
      fetchComments: fetchComments,
    ),
  );
}

class BangumiBlogDetailDialog extends StatefulWidget {
  final BangumiReview review;
  final Future<BangumiBlogDetail> Function(int entryId)? fetchDetail;
  final Future<List<BangumiEpisodeComment>> Function(int entryId)?
  fetchComments;

  const BangumiBlogDetailDialog({
    super.key,
    required this.review,
    this.fetchDetail,
    this.fetchComments,
  });

  @override
  State<BangumiBlogDetailDialog> createState() =>
      _BangumiBlogDetailDialogState();
}

class _BangumiBlogDetailDialogState extends State<BangumiBlogDetailDialog> {
  BangumiBlogDetail? _detail;
  List<BangumiEpisodeComment>? _comments;
  bool _isLoadingDetail = true;
  bool _isLoadingComments = true;
  bool _detailFailed = false;
  bool _commentsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadBlogDetail();
  }

  Future<void> _loadBlogDetail() async {
    if (mounted) {
      setState(() {
        _isLoadingDetail = true;
        _isLoadingComments = true;
        _detailFailed = false;
        _commentsFailed = false;
      });
    }

    await Future.wait<void>([_loadDetail(), _loadComments()]);
  }

  Future<void> _loadDetail() async {
    try {
      final detail =
          await (widget.fetchDetail?.call(widget.review.entryId) ??
              bangumi_api.fetchBangumiBlogDetail(
                entryId: widget.review.entryId,
              ));
      if (mounted) {
        setState(() {
          _detail = detail;
          _detailFailed = false;
          _isLoadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detailFailed = true;
          _isLoadingDetail = false;
        });
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments =
          await (widget.fetchComments?.call(widget.review.entryId) ??
              bangumi_api.fetchBangumiBlogComments(
                entryId: widget.review.entryId,
              ));
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsFailed = false;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _commentsFailed = true;
          _isLoadingComments = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final title = _detail?.title ?? widget.review.title;
    final userName = _detail?.userName ?? widget.review.userName;
    final avatar = _detail?.avatar ?? widget.review.avatar;
    final time = _detail?.time ?? widget.review.time;

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
                      l10n.bangumiDetailsTabReviews,
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
              child: _isLoadingDetail
                  ? const Center(child: CircularProgressIndicator())
                  : _detailFailed
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
                              l10n.bangumiBlogDetailLoadFailed,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _loadBlogDetail();
                              },
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Article Header
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 20,
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
                                      Text(
                                        userName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
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
                              if (_detail != null &&
                                  _detail!.tags.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _detail!.tags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                            ]),
                          ),
                        ),
                        // A long review can contain many top-level HTML blocks.
                        // Keep them in the same lazy sliver pipeline as comments.
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: BangumiCommentHtml(
                            html: _detail!.contentHtml,
                            renderMode: RenderMode.sliverList,
                            textStyle: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              height: 1.6,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (_detail!.reactions.isNotEmpty) ...[
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
                              const SizedBox(height: 24),
                              // Comments Section
                              if (_isLoadingComments) ...[
                                const Divider(),
                                const SizedBox(height: 16),
                                const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ] else if (_commentsFailed) ...[
                                const Divider(),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.bangumiBlogCommentsLoadFailed,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isLoadingComments = true;
                                          _commentsFailed = false;
                                        });
                                        _loadComments();
                                      },
                                      child: Text(l10n.retry),
                                    ),
                                  ],
                                ),
                              ] else if (_comments != null &&
                                  _comments!.isNotEmpty) ...[
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.bangumiDetailsTabComments,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ]),
                          ),
                        ),
                        if (!_isLoadingComments &&
                            !_commentsFailed &&
                            _comments != null &&
                            _comments!.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.builder(
                              itemCount: _comments!.length,
                              itemBuilder: (context, index) =>
                                  BangumiCommentTile(
                                    key: ValueKey(_comments![index].id),
                                    comment: _comments![index],
                                    isDarkBg: isDark,
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
