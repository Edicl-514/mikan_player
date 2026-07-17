import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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

/// Bangumi comment HTML rendering helpers.
///
/// Promoted to top-level (without the leading underscore) so the URL
/// classification, host rewrites, and size math for `text_mask` and
/// Bangumi smile `<img>` rendering can be unit-tested without pumping a
/// real `HtmlWidget` / `CachedNetworkImage`. The widget still owns the
/// DOM-element-to-attribute glue in `_buildCommentHtmlWidget` /
/// `_buildBangumiSmileImage`.
String normalizeBangumiImageSrc(String src) {
  if (src.startsWith('//')) {
    return BangumiUrlRewriter.rewrite(_preferLainSmileHost('https:$src'));
  }
  if (src.startsWith('/img/smiles/')) {
    // Classic relative smile paths on bangumi HTML pages resolve to the main
    // site host, which is nginx-only and frequently fails under ECH. Serve
    // them from the lain CDN (Cloudflare) instead; reverse-proxy rewrite still
    // maps lain.bgm.tv → lain.bangumi.lol when enabled.
    return BangumiUrlRewriter.rewrite('https://lain.bgm.tv$src');
  }
  if (src.startsWith('/img/')) {
    return BangumiUrlRewriter.rewrite('https://bangumi.tv$src');
  }
  return BangumiUrlRewriter.rewrite(_preferLainSmileHost(src));
}

/// Rewrite classic smile hosts (`bangumi.tv` / `bgm.tv` / `chii.in` / mirror
/// main site) to `lain.bgm.tv` so legacy and API-rendered smile URLs share the
/// same Cloudflare-friendly CDN. Dynamic musume/blake URLs already point at
/// lain and are left alone.
String _preferLainSmileHost(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return src;
  if (!uri.path.startsWith('/img/smiles/')) return src;

  final host = uri.host.toLowerCase();
  final isClassicMainHost =
      host == 'bangumi.tv' ||
      host == 'bgm.tv' ||
      host == 'chii.in' ||
      host == 'bangumi.lol';
  if (!isClassicMainHost) return src;

  return uri.replace(host: 'lain.bgm.tv').toString();
}

bool isBangumiSmileUrl(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  return uri.path.startsWith('/img/smiles/') &&
      (host == 'bangumi.tv' ||
          host == 'bgm.tv' ||
          host.endsWith('.bgm.tv') ||
          host == 'chii.in' ||
          host == 'bangumi.lol' ||
          host.endsWith('.bangumi.lol'));
}

/// CSS-ish styles for Bangumi comment HTML, shared by top-level comments and
/// nested replies. Keeps quote blocks visually distinct from body text.
Map<String, String>? bangumiCommentHtmlStyles(dynamic element) {
  final name = element.localName as String?;
  if (name == 'img') {
    return {'max-width': '100%', 'max-height': '350px'};
  }
  if (name == 'div' && element.classes.contains('quote')) {
    return {
      'margin': '0 0 8px 0',
      'padding': '8px 10px',
      'border-left': '3px solid #9e9e9e',
      'border-radius': '4px',
      'background-color': 'rgba(158, 158, 158, 0.12)',
      'color': '#9e9e9e',
      'font-size': '0.92em',
      'line-height': '1.4',
    };
  }
  if (name == 'q') {
    // Nested inside `.quote`; drop browser default italic/quotes so the
    // parent block styles carry the visual weight.
    return {'quotes': 'none', 'font-style': 'normal', 'color': 'inherit'};
  }
  return null;
}

/// Resolves the inline size for a Bangumi smile `<img>` from its `width`/
/// `height` attributes. Falls back to a 42×42 square when both are absent,
/// scales the larger axis down to 42 when necessary, then clamps each axis
/// to the 18–64 px usable range.
Size bangumiSmileSize({String? widthAttr, String? heightAttr}) {
  final width = double.tryParse(widthAttr ?? '');
  final height = double.tryParse(heightAttr ?? '');
  const fallback = Size.square(42);

  if (width == null && height == null) {
    return fallback;
  }

  final rawWidth = width ?? height ?? fallback.width;
  final rawHeight = height ?? width ?? fallback.height;
  final scale = rawWidth > rawHeight
      ? fallback.width / rawWidth
      : fallback.height / rawHeight;

  if (scale >= 1) {
    return Size(
      rawWidth.clamp(18, 64).toDouble(),
      rawHeight.clamp(18, 64).toDouble(),
    );
  }

  return Size(
    (rawWidth * scale).clamp(18, 64).toDouble(),
    (rawHeight * scale).clamp(18, 64).toDouble(),
  );
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
          '加载失败: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (comments.isEmpty) {
      return Center(
        child: Text('暂无评论', style: TextStyle(color: mutedTextColor)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '全部评论',
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
                BangumiCommentHtml(
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
                                    BangumiCommentHtml(
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
