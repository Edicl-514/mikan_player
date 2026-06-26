import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/cached_network_image.dart';

class NetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallback,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: url.isEmpty
          ? fallback
          : ClipOval(
              child: SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  deferOffscreenLoad: false,
                  networkFallbackWhileCaching: false,
                  errorWidget: fallback,
                ),
              ),
            ),
    );
  }
}
