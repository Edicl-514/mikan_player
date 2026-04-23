import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class BlurredCoverBackground extends StatelessWidget {
  final String imageUrl;
  final BorderRadius borderRadius;
  final double blurSigma;
  final double blurOpacity;
  final double baseImageOpacity;
  final double scale;
  final double overlayOpacity;
  final double highlightOpacity;
  final double borderOpacity;

  const BlurredCoverBackground({
    super.key,
    required this.imageUrl,
    required this.borderRadius,
    this.blurSigma = 12,
    this.blurOpacity = 1,
    this.baseImageOpacity = 0.14,
    this.scale = 1.08,
    this.overlayOpacity = 0.14,
    this.highlightOpacity = 0.12,
    this.borderOpacity = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: Colors.grey[800]);

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: baseImageOpacity,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: fallback,
            ),
          ),
          IgnorePointer(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.94,
                0,
                0,
                0,
                8,
                0,
                0.94,
                0,
                0,
                8,
                0,
                0,
                0.94,
                0,
                8,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Opacity(
                opacity: blurOpacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: fallback,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: overlayOpacity),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlightOpacity),
                    Colors.white.withValues(alpha: highlightOpacity * 0.35),
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.38, 1],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: borderOpacity),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
