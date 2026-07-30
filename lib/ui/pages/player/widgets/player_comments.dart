import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/ui/widgets/bangumi_comment_html.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

/// Display widget for the player page's comments tab.
///
/// Extracted from `_buildCommentsTab`, `_buildCommentItem`, and its private
/// HTML-rendering helpers in `player_page.dart`. The widget takes all state
/// and an optional [sortButton] via its constructor — no hidden service or
/// global state. The page retains ownership of comment fetching, sort-mode
/// state, and scroll-controller lifecycle.
///
/// The `PlayerComments.buildItem` static method exposes the comment-item
/// rendering for the desktop Sliver-based comments block, which stays on
/// the page because its layout is too deeply integrated with the page's
/// sliver-tree to extract cleanly in one step.
///
export 'package:mikan_player/ui/widgets/bangumi_comment_html.dart'
    show normalizeBangumiImageSrc, isBangumiSmileUrl, bangumiSmileSize;

/// CSS-ish styles for Bangumi comment HTML, shared by top-level comments and
/// nested replies. Keeps quote blocks visually distinct from body text.
Map<String, String>? bangumiCommentHtmlStyles(dynamic element) {
  return defaultBangumiCommentHtmlStyles(element);
}

class PlayerComments extends StatelessWidget {
  final List<BangumiEpisodeComment> comments;
  final bool isLoading;
  final String? error;
  final ScrollController scrollController;
  final Widget? sortButton;

  const PlayerComments({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.error,
    required this.scrollController,
    this.sortButton,
  });

  // --- Public factory for the desktop Sliver block ---

  /// Builds a single comment item (avatar, header, HTML body, replies).
  /// Called from the page's desktop Sliver-list delegate so that the
  /// `_buildCommentItem` body lives in one place.
  static Widget buildItem(BuildContext context, BangumiEpisodeComment comment) {
    return _buildCommentItem(context, comment);
  }

  // --- Layout ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedTextColor = isDark
        ? Colors.white54
        : theme.colorScheme.onSurfaceVariant;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          l10n.playerCommentsLoadFailed(error!),
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (comments.isEmpty) {
      return Center(
        child: Text(
          l10n.playerCommentsEmpty,
          style: TextStyle(color: mutedTextColor),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                l10n.playerCommentsTitle,
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ?sortButton,
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.3),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: comments.length,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<Object>) return null;
              final index = comments.indexWhere(
                (comment) => comment.id == key.value,
              );
              return index < 0 ? null : index;
            },
            itemBuilder: (context, index) {
              return _buildCommentItem(context, comments[index]);
            },
          ),
        ),
      ],
    );
  }

  // --- Comment item (private, identical to original) ---

  static Widget _buildCommentItem(
    BuildContext context,
    BangumiEpisodeComment comment,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      key: ValueKey<Object>(comment.id),
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: comment.avatar.isEmpty
                  ? (isDark ? Colors.grey[800] : Colors.grey[300])
                  : null,
            ),
            child: comment.avatar.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: comment.avatar,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      comment.userName.isNotEmpty ? comment.userName[0] : '?',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + Time
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Content
                BangumiCommentBody(
                  state: comment.state,
                  html: comment.contentHtml,
                  textStyle: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  customStylesBuilder: bangumiCommentHtmlStyles,
                  customWidgetBuilder: (element) {
                    return _buildCommentHtmlWidget(
                      element,
                      const TextStyle(fontSize: 14, height: 1.5),
                    );
                  },
                ),

                // Replies (樓中樓)
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: comment.replies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reply = entry.value;
                        final isLast = index == comment.replies.length - 1;
                        return Padding(
                          key: ValueKey<Object>(reply.id),
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: reply.avatar.isEmpty
                                      ? (isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[300])
                                      : null,
                                ),
                                child: reply.avatar.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: reply.avatar,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          reply.userName,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          reply.time,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    BangumiCommentBody(
                                      state: reply.state,
                                      html: reply.contentHtml,
                                      textStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : theme.colorScheme.onSurface,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      customStylesBuilder:
                                          bangumiCommentHtmlStyles,
                                      customWidgetBuilder: (element) {
                                        return _buildCommentHtmlWidget(
                                          element,
                                          const TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HTML-rendering helpers (private, identical to original) ---

  static Widget? _buildCommentHtmlWidget(dynamic element, TextStyle textStyle) {
    // `.text_mask` is handled by [BangumiCommentHtml] as soft-wrapping
    // TextSpans; only smile images still need a custom widget.
    if (element.localName == 'img') {
      return _buildBangumiSmileImage(element);
    }

    return null;
  }

  static Widget? _buildBangumiSmileImage(dynamic element) {
    final src = normalizeBangumiImageSrc(element.attributes['src'] ?? '');
    if (!isBangumiSmileUrl(src)) {
      return null;
    }

    final size = bangumiSmileSize(
      widthAttr: element.attributes['width'],
      heightAttr: element.attributes['height'],
    );
    return InlineCustomWidget(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: CachedNetworkImage(
          imageUrl: src,
          width: size.width,
          height: size.height,
          fit: BoxFit.contain,
          deferOffscreenLoad: false,
          networkFallbackWhileCaching: false,
          placeholder: SizedBox(width: size.width, height: size.height),
          errorWidget: SizedBox(width: size.width, height: size.height),
        ),
      ),
    );
  }
}
