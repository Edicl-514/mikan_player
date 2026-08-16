import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

const _maskIdAttribute = 'data-mikan-mask-id';

final _textMaskSpanPattern = RegExp(
  r'<span\b([^>]*\btext_mask\b[^>]*)>',
  caseSensitive: false,
);

/// HtmlWidget wrapper for Bangumi comment bodies.
///
/// Renders `[mask]` / `.text_mask` as soft-wrapping [TextSpan]s (background
/// paint + hover/tap reveal) so long spoilers can break mid-mask instead of
/// jumping to the next line as a rigid [InlineCustomWidget] box. Smile images
/// and other custom widgets still go through [customWidgetBuilder].
class BangumiCommentHtml extends StatefulWidget {
  final String html;
  final TextStyle? textStyle;
  final RenderMode renderMode;
  final CustomStylesBuilder? customStylesBuilder;
  final CustomWidgetBuilder? customWidgetBuilder;
  final Future<bool> Function(String url)? onTapUrl;

  const BangumiCommentHtml({
    super.key,
    required this.html,
    this.textStyle,
    this.renderMode = RenderMode.column,
    this.customStylesBuilder,
    this.customWidgetBuilder,
    this.onTapUrl,
  });

  @override
  State<BangumiCommentHtml> createState() => _BangumiCommentHtmlState();
}

/// Strip inline `style="..."` from `.text_mask` tags.
///
/// Bangumi markup emits `style="background-color:#555;color:#555;border:..."`.
/// `flutter_widget_from_html` applies element style attributes *after*
/// [HtmlWidget.customStylesBuilder], so those attributes would otherwise win
/// and keep a non-soft-wrapping border box. Removing them lets our reveal
/// styles (background paint only) take effect.
@visibleForTesting
String stripTextMaskInlineStyles(String html) {
  if (!_textMaskSpanPattern.hasMatch(html)) return html;
  return html.replaceAllMapped(_textMaskSpanPattern, (match) {
    final attrs = match
        .group(1)!
        .replaceAll(
          RegExp(r'''\sstyle\s*=\s*("[^"]*"|'[^']*')''', caseSensitive: false),
          '',
        );
    return '<span$attrs>';
  });
}

/// Add a deterministic, per-element identifier to each `.text_mask` span.
///
/// Text content cannot be used as identity because a comment may contain the
/// same spoiler more than once. The ordinal remains stable every time the same
/// HTML is parsed, so reveal state survives fwfh cache rebuilds without linking
/// duplicate masks together.
@visibleForTesting
String annotateTextMaskIds(String html) {
  if (!_textMaskSpanPattern.hasMatch(html)) return html;

  var index = 0;
  return html.replaceAllMapped(_textMaskSpanPattern, (match) {
    final attrs = match
        .group(1)!
        .replaceAll(
          RegExp(
            r'''\sdata-mikan-mask-id\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''',
            caseSensitive: false,
          ),
          '',
        );
    return '<span $_maskIdAttribute="${index++}"$attrs>';
  });
}

String _maskKey(dynamic element) {
  final annotatedId = element.attributes[_maskIdAttribute] as String?;
  if (annotatedId != null && annotatedId.isNotEmpty) {
    return 'id:$annotatedId';
  }

  final text = (element.text as String? ?? '').trim();
  if (text.isNotEmpty) return 'text:$text';
  return 'html:${element.outerHtml}';
}

class _BangumiCommentHtmlState extends State<BangumiCommentHtml> {
  final Set<String> _revealed = <String>{};
  final Set<String> _hovered = <String>{};
  final Map<String, Timer> _hoverExitTimers = <String, Timer>{};

  late final _BangumiMaskWidgetFactory _factory = _BangumiMaskWidgetFactory(
    onToggle: _toggle,
    onEnter: _enter,
    onExit: _exit,
  );

  int _revision = 0;
  int _preparedRevision = -1;

  void _toggle(String key) {
    setState(() {
      if (!_revealed.add(key)) {
        _revealed.remove(key);
      }
      _revision++;
    });
  }

  void _enter(String key) {
    _hoverExitTimers.remove(key)?.cancel();
    if (_hovered.contains(key)) return;

    setState(() {
      _hovered.add(key);
      _revision++;
    });
  }

  void _exit(String key) {
    _hoverExitTimers.remove(key)?.cancel();
    // Rebuilding a TextSpan replaces its mouse annotation, which can emit a
    // transient exit followed immediately by a new enter. Delay hiding just
    // enough for that replacement enter to cancel the timer.
    _hoverExitTimers[key] = Timer(const Duration(milliseconds: 30), () {
      _hoverExitTimers.remove(key);
      if (!mounted || !_hovered.contains(key)) return;
      setState(() {
        _hovered.remove(key);
        _revision++;
      });
    });
  }

  void _clearHoverTimers() {
    for (final timer in _hoverExitTimers.values) {
      timer.cancel();
    }
    _hoverExitTimers.clear();
  }

  @override
  void didUpdateWidget(BangumiCommentHtml oldWidget) {
    super.didUpdateWidget(oldWidget);

    final htmlChanged = oldWidget.html != widget.html;
    if (htmlChanged) {
      _clearHoverTimers();
      _revealed.clear();
      _hovered.clear();
    }

    if (htmlChanged || oldWidget.textStyle != widget.textStyle) {
      _revision++;
    }
  }

  @override
  void dispose() {
    _clearHoverTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_preparedRevision != _revision) {
      // HtmlWidget keeps its WidgetFactory across cache rebuilds. Reset it
      // before invalidating the cache so recognizers from the old span tree are
      // disposed instead of accumulating after every toggle/hover transition.
      _factory.prepareForRebuild();
      _preparedRevision = _revision;
    }

    final html = annotateTextMaskIds(stripTextMaskInlineStyles(widget.html));
    return HtmlWidget(
      html,
      textStyle: widget.textStyle,
      renderMode: widget.renderMode,
      onTapUrl: (url) async {
        if (url.startsWith('#')) return false;
        if (!isSafeBangumiExternalUrl(url)) return true;
        return widget.onTapUrl?.call(url) ?? false;
      },
      // Bust fwfh's widget cache when reveal state changes.
      rebuildTriggers: <Object?>[_revision],
      customStylesBuilder: (element) {
        final defaultStyles = defaultBangumiCommentHtmlStyles(element);
        final userStyles = widget.customStylesBuilder?.call(element);
        final base = userStyles != null
            ? <String, String>{...?defaultStyles, ...userStyles}
            : defaultStyles;

        if (element.localName == 'img') {
          if (element.classes.contains('smile-dynamic') ||
              element.classes.contains('smile-blake') ||
              element.classes.contains('smile-musume')) {
            return <String, String>{
              ...?base,
              'max-height': '64px',
              'max-width': '96px',
              'object-fit': 'contain',
              'vertical-align': 'middle',
            };
          } else if (element.classes.contains('smile')) {
            return <String, String>{
              ...?base,
              'max-height': '24px',
              'vertical-align': 'middle',
            };
          }
        }
        if (!element.classes.contains('text_mask')) {
          return base;
        }

        final key = _maskKey(element);
        final visible = _revealed.contains(key) || _hovered.contains(key);
        // Soft-wrapping TextStyle background paint; no border (borders force
        // a rigid box that cannot break mid-mask).
        if (visible) {
          return <String, String>{
            ...?base,
            'border': 'none',
            'background-color': 'transparent',
          };
        }
        return <String, String>{
          ...?base,
          'border': 'none',
          'background-color': '#555555',
          'color': '#555555',
        };
      },
      customWidgetBuilder: (element) {
        // Never replace `.text_mask` with a Widget — that creates a non-
        // breaking placeholder. Let the factory attach a span + recognizer.
        if (element.classes.contains('text_mask')) {
          return null;
        }

        final custom = widget.customWidgetBuilder?.call(element);
        if (custom != null) {
          return custom;
        }

        if (element.localName == 'img') {
          return _buildBangumiCommentImage(element);
        }

        return null;
      },
      factoryBuilder: () => _factory,
    );
  }

  Widget? _buildBangumiCommentImage(dynamic element) {
    final rawSrc = element.attributes['src'] ?? '';
    if (rawSrc.trim().isEmpty) return null;
    final src = normalizeBangumiImageSrc(rawSrc);
    if (src.isEmpty) return null;

    final isSmile =
        isBangumiSmileUrl(src) ||
        element.classes.contains('smile') ||
        element.classes.contains('smile-dynamic') ||
        element.classes.contains('smile-blake') ||
        element.classes.contains('smile-musume') ||
        element.attributes.containsKey('smileid');

    if (isSmile) {
      final isLarge =
          isLargeBangumiSmileUrl(src) ||
          element.classes.contains('smile-dynamic') ||
          element.classes.contains('smile-blake') ||
          element.classes.contains('smile-musume');

      final size = bangumiSmileSize(
        widthAttr: element.attributes['width'],
        heightAttr: element.attributes['height'],
        isLarge: isLarge,
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

    final imageHeight = bangumiCommentImageHeight(
      widthAttr: element.attributes['width'],
      heightAttr: element.attributes['height'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : null;
            return SizedBox(
              width: width,
              height: imageHeight,
              child: CachedNetworkImage(
                imageUrl: src,
                width: width,
                height: imageHeight,
                fit: BoxFit.contain,
                deferOffscreenLoad: false,
                networkFallbackWhileCaching: false,
                // Keep loading, loaded and failed states in the same slot.
                placeholder: SizedBox(
                  width: width,
                  height: imageHeight,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: SizedBox(
                  width: width,
                  height: imageHeight,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.broken_image,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Returns the reserved slot height for a regular comment image.
///
/// HTML dimensions are used when available; otherwise a conservative fixed
/// slot prevents a late image decode from shifting the surrounding comment.
@visibleForTesting
double bangumiCommentImageHeight({String? widthAttr, String? heightAttr}) {
  final height = _parseBangumiImageDimension(heightAttr);
  if (height != null) {
    return height.clamp(1.0, 350.0).toDouble();
  }

  // A width without a matching height does not provide an aspect ratio. Keep
  // the same fallback slot used by older markup while still constraining the
  // loaded and failed states.
  return 200.0;
}

double? _parseBangumiImageDimension(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized.endsWith('%')) return null;
  final parsed = double.tryParse(
    normalized.endsWith('px')
        ? normalized.substring(0, normalized.length - 2).trim()
        : normalized,
  );
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

/// Renders a p1 comment while respecting Bangumi moderation state.
///
/// p1 uses state 8 for folded content. States 1, 2, 5, 6 and 7 are not
/// viewable; the upstream API normally blanks their content, but we enforce
/// that rule here as a second boundary before rendering HTML.
class BangumiCommentBody extends StatefulWidget {
  final int state;
  final String html;
  final TextStyle? textStyle;
  final CustomStylesBuilder? customStylesBuilder;
  final CustomWidgetBuilder? customWidgetBuilder;

  const BangumiCommentBody({
    super.key,
    required this.state,
    required this.html,
    this.textStyle,
    this.customStylesBuilder,
    this.customWidgetBuilder,
  });

  @override
  State<BangumiCommentBody> createState() => _BangumiCommentBodyState();
}

class _BangumiCommentBodyState extends State<BangumiCommentBody> {
  bool _showFoldedContent = false;

  @override
  void didUpdateWidget(covariant BangumiCommentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state || oldWidget.html != widget.html) {
      _showFoldedContent = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = widget.textStyle ?? DefaultTextStyle.of(context).style;

    if (bangumiCommentStateHidesContent(widget.state)) {
      return Text(l10n.bangumiCommentUnavailable, style: style);
    }

    if (widget.state == 8 && !_showFoldedContent) {
      return Row(
        children: [
          Expanded(child: Text(l10n.bangumiCommentFolded, style: style)),
          TextButton(
            onPressed: () => setState(() => _showFoldedContent = true),
            child: Text(l10n.bangumiCommentShowFolded),
          ),
        ],
      );
    }

    return BangumiCommentHtml(
      html: widget.html,
      textStyle: widget.textStyle,
      customStylesBuilder: widget.customStylesBuilder,
      customWidgetBuilder: widget.customWidgetBuilder,
    );
  }
}

/// CSS-ish default styles for Bangumi comment HTML, shared across all comment views.
/// Keeps quote blocks visually distinct from body text.
Map<String, String>? defaultBangumiCommentHtmlStyles(dynamic element) {
  final name = element.localName as String?;
  if (name == 'img') {
    return {'max-width': '100%', 'max-height': '350px'};
  }
  if ((name == 'div' && element.classes.contains('quote')) ||
      name == 'blockquote') {
    return {
      'margin': '4px 0 8px 0',
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
    // Nested inside `.quote` or standalone quote text; drop browser default
    // italic/quotes so the parent block styles carry the visual weight.
    return {'quotes': 'none', 'font-style': 'normal', 'color': 'inherit'};
  }
  return null;
}

/// Normalizes image URLs from Bangumi HTML markup so they work cleanly under
/// ECH / reverse proxy configurations.
String normalizeBangumiImageSrc(String src) {
  final trimmed = src.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('//')) {
    return BangumiUrlRewriter.rewrite(_preferLainSmileHost('https:$trimmed'));
  }
  if (trimmed.startsWith('/img/smiles/')) {
    return BangumiUrlRewriter.rewrite('https://lain.bgm.tv$trimmed');
  }
  if (trimmed.startsWith('/img/')) {
    return BangumiUrlRewriter.rewrite('https://bangumi.tv$trimmed');
  }
  return BangumiUrlRewriter.rewrite(_preferLainSmileHost(trimmed));
}

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

bool isLargeBangumiSmileUrl(String src) {
  final lower = src.toLowerCase();
  return lower.contains('/img/smiles/musume/') ||
      lower.contains('/img/smiles/blake/') ||
      lower.contains('/img/smiles/tv_500/');
}

Size bangumiSmileSize({
  String? widthAttr,
  String? heightAttr,
  bool isLarge = false,
}) {
  final targetMax = isLarge ? 42.0 : 24.0;
  final fallback = Size.square(targetMax);

  final width = double.tryParse(widthAttr ?? '');
  final height = double.tryParse(heightAttr ?? '');

  if (width == null && height == null) {
    return fallback;
  }

  final w = width ?? height!;
  final h = height ?? width!;
  final maxDim = w > h ? w : h;

  if (maxDim <= 0) return fallback;

  final scale = maxDim > targetMax ? targetMax / maxDim : 1.0;
  final minClamp = isLarge ? 18.0 : 14.0;
  final maxClamp = isLarge ? 64.0 : 28.0;

  final scaledW = (w * scale).clamp(minClamp, maxClamp);
  final scaledH = (h * scale).clamp(minClamp, maxClamp);
  return Size(scaledW, scaledH);
}

bool bangumiCommentStateHidesContent(int state) => switch (state) {
  1 || 2 || 5 || 6 || 7 => true,
  _ => false,
};

@visibleForTesting
bool isSafeBangumiExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      (uri.scheme.toLowerCase() == 'http' ||
          uri.scheme.toLowerCase() == 'https') &&
      uri.host.isNotEmpty;
}

/// Registers a [BuildOp] so `.text_mask` spans get tap and hover handling while
/// remaining normal soft-wrapping text bits.
class _BangumiMaskWidgetFactory extends WidgetFactory {
  final void Function(String key) onToggle;
  final void Function(String key) onEnter;
  final void Function(String key) onExit;
  final Map<GestureRecognizer, _MaskHoverHandlers> _hoverHandlers = {};

  State? _htmlWidgetState;

  _BangumiMaskWidgetFactory({
    required this.onToggle,
    required this.onEnter,
    required this.onExit,
  });

  void prepareForRebuild() {
    final state = _htmlWidgetState;
    if (state != null) {
      reset(state);
    }
  }

  @override
  void reset(State state) {
    _hoverHandlers.clear();
    _htmlWidgetState = state;
    super.reset(state);
  }

  @override
  void dispose() {
    _hoverHandlers.clear();
    _htmlWidgetState = null;
    super.dispose();
  }

  @override
  void parse(BuildTree tree) {
    super.parse(tree);
    if (!tree.element.classes.contains('text_mask')) {
      return;
    }

    tree.register(
      BuildOp(
        alwaysRenderBlock: false,
        debugLabel: 'bangumi.text_mask',
        onParsed: (maskTree) {
          final key = _maskKey(maskTree.element);
          final recognizer = buildGestureRecognizer(
            maskTree,
            onTap: () => onToggle(key),
          );
          if (recognizer == null) {
            return maskTree;
          }
          _hoverHandlers[recognizer] = _MaskHoverHandlers(
            onEnter: () => onEnter(key),
            onExit: () => onExit(key),
          );
          // Same pattern as TagA: inherit the recognizer onto inline spans.
          return maskTree..inherit(_attachRecognizer, recognizer);
        },
      ),
    );
  }

  static InheritedProperties _attachRecognizer(
    InheritedProperties resolving,
    GestureRecognizer recognizer,
  ) => resolving.copyWith<GestureRecognizer>(value: recognizer);

  @override
  InlineSpan? buildTextSpan({
    List<InlineSpan>? children,
    GestureRecognizer? recognizer,
    TextStyle? style,
    String? text,
  }) {
    final handlers = recognizer == null ? null : _hoverHandlers[recognizer];
    if (handlers == null) {
      return super.buildTextSpan(
        children: children,
        recognizer: recognizer,
        style: style,
        text: text,
      );
    }

    if (text?.isEmpty == true) {
      if (children == null) return null;
      if (children.length == 1) return children.first;
    }

    return TextSpan(
      children: children,
      mouseCursor: SystemMouseCursors.click,
      onEnter: (_) => handlers.onEnter(),
      onExit: (_) => handlers.onExit(),
      recognizer: recognizer,
      style: style,
      text: text,
    );
  }
}

class _MaskHoverHandlers {
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const _MaskHoverHandlers({required this.onEnter, required this.onExit});
}
