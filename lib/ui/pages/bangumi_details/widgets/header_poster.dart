import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:mikan_player/ui/widgets/cached_network_image.dart';
import 'package:mikan_player/ui/widgets/workspace_chrome_tint.dart';

/// Poster card used in the wide layout's left panel.
///
/// Stateless presentational widget extracted from `_buildPoster` in
/// `bangumi_details_page.dart`. Wraps the image in a [Hero] animation using
/// the supplied [heroTag] (falling back to a stable composite key from
/// [heroIdFallback]).
class BangumiPoster extends StatelessWidget {
  final String? imageUrl;
  final String? heroTag;
  final String heroIdFallback;
  final double radius;

  const BangumiPoster({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.heroIdFallback,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Center(
          child: Icon(Icons.movie, size: 64, color: Colors.white54),
        ),
      );
    }
    return Hero(
      tag: heroTag ?? heroIdFallback,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 400,
          ),
        ),
      ),
    );
  }
}

/// Full-screen blurred wallpaper used behind the wide layout.
class BlurredBackground extends StatelessWidget {
  final String? imageUrl;

  /// Whether to extract a dominant color from the cover and publish it as the
  /// window-chrome tint for the current tab. The desktop detail page enables
  /// this so its wallpaper bleeds into the title bar; embedded uses (hero
  /// cards) leave it off.
  final bool publishTint;

  const BlurredBackground({
    super.key,
    required this.imageUrl,
    this.publishTint = false,
  });

  @override
  Widget build(BuildContext context) {
    final wallpaper = imageUrl == null
        ? Container(color: Colors.black87)
        : Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: Container(color: Colors.black87),
              ),
              RepaintBoundary(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),
            ],
          );

    if (!publishTint) return wallpaper;
    return WorkspaceChromeTintPublisher(imageUrl: imageUrl, child: wallpaper);
  }
}
