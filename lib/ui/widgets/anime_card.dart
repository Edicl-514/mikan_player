import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class AnimeCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? tag;
  final String? coverUrl;
  final double? score;
  final VoidCallback? onTap;
  final String? heroTag;
  final int? cacheWidth;
  final bool deferOffscreenLoad;

  const AnimeCard({
    super.key,
    required this.title,
    this.subtitle,
    this.tag,
    this.coverUrl,
    this.score,
    this.onTap,
    this.heroTag,
    this.cacheWidth,
    this.deferOffscreenLoad = true,
  });

  static const _cardRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              heroTag != null
                  ? Hero(tag: heroTag!, child: _buildCover())
                  : _buildCover(),
              Positioned(
                left: -1,
                right: -1,
                bottom: -2,
                height: 92,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.62),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0, 0.34, 0.72, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (tag != null && tag!.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (score != null && score! > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      score!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(_cardRadius),
                    splashColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    highlightColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    hoverColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    mouseCursor: SystemMouseCursors.click,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    return coverUrl != null
        ? CachedNetworkImage(
            imageUrl: coverUrl!,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            deferOffscreenLoad: deferOffscreenLoad,
            errorWidget: Image.asset(
              'assets/images/cover.png',
              fit: BoxFit.cover,
            ),
          )
        : Image.asset('assets/images/cover.png', fit: BoxFit.cover);
  }
}
