import 'package:flutter/material.dart';

import 'package:mikan_player/src/rust/api/bangumi/types.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_tile.dart';

/// Renders the loading / failed / empty / list states for a Bangumi comment
/// surface, in either a box widget or a sliver child.
///
/// Each detail page previously had a `_buildXxCommentsSection` (box) and a
/// `_buildXxCommentsSlivers` (sliver) pair that re-implemented the same three
/// state branches twice. This widget unifies them behind a single [useSliver]
/// flag so the page-level code only declares the canonical list of comments
/// and the localised strings once.
///
/// Set [useSliver] `true` when the section is a child of a [CustomScrollView]
/// (desktop layout); otherwise it behaves as a normal box widget (mobile
/// layout). [sliverPadding] only applies to the sliver variant.
class BangumiCommentSection extends StatelessWidget {
  const BangumiCommentSection({
    super.key,
    required this.isLoading,
    required this.failed,
    required this.comments,
    required this.isDarkBg,
    required this.emptyMessage,
    required this.errorMessage,
    required this.retryLabel,
    required this.onRetry,
    this.useSliver = false,
    this.sliverPadding = EdgeInsets.zero,
  });

  final bool isLoading;
  final bool failed;
  final List<BangumiEpisodeComment> comments;
  final bool isDarkBg;
  final bool useSliver;
  final EdgeInsets sliverPadding;
  final String emptyMessage;
  final String errorMessage;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (useSliver) return _buildSliver(context);
    return _buildBox(context);
  }

  Widget _buildBox(BuildContext context) {
    if (failed) return _failedCard(context);
    if (isLoading) return _loadingBox();
    if (comments.isEmpty) return _emptyCard(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return BangumiCommentTile(
          key: ValueKey(comment.id),
          comment: comment,
          isDarkBg: isDarkBg,
        );
      },
    );
  }

  Widget _buildSliver(BuildContext context) {
    final Widget content;
    if (failed) {
      content = SliverToBoxAdapter(child: _failedCard(context));
    } else if (isLoading) {
      content = SliverToBoxAdapter(child: _loadingBox());
    } else if (comments.isEmpty) {
      content = SliverToBoxAdapter(child: _emptyCard(context));
    } else {
      content = SliverList.builder(
        itemCount: comments.length,
        itemBuilder: (context, index) {
          final comment = comments[index];
          return BangumiCommentTile(
            key: ValueKey(comment.id),
            comment: comment,
            isDarkBg: isDarkBg,
          );
        },
      );
    }
    return SliverPadding(padding: sliverPadding, sliver: content);
  }

  Widget _loadingBox() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _failedCard(BuildContext context) {
    return _StateCard(
      icon: Icons.error_outline,
      iconSize: 40,
      iconColor: isDarkBg
          ? Colors.redAccent[100]
          : Theme.of(context).colorScheme.error,
      message: errorMessage,
      isDarkBg: isDarkBg,
      verticalPadding: 24,
      cardAlpha: 0.5,
      action: ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return _StateCard(
      icon: Icons.comment_outlined,
      iconSize: 48,
      iconColor: isDarkBg
          ? Colors.white38
          : Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      message: emptyMessage,
      isDarkBg: isDarkBg,
      verticalPadding: 48,
      cardAlpha: 0.3,
    );
  }
}

/// Card used by the failed / empty states. Private so callers go through
/// [BangumiCommentSection] instead of recreating the palette.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.message,
    required this.isDarkBg,
    required this.verticalPadding,
    required this.cardAlpha,
    this.action,
  });

  final IconData icon;
  final double iconSize;
  final Color? iconColor;
  final String message;
  final bool isDarkBg;
  final double verticalPadding;
  final double cardAlpha;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isDarkBg
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 24),
      decoration: BoxDecoration(
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: cardAlpha,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkBg
              ? Colors.white.withValues(alpha: 0.08)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(fontSize: 14, color: textColor)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
