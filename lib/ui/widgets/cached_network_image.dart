import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mikan_player/services/cache/image_cache_service.dart';

/// 缓存图片 Widget
/// 自动从缓存中加载图片，如果没有缓存则显示网络图片并在后台缓存
class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final AlignmentGeometry? alignment;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _localPath = null;
    });

    try {
      final cache = ImageCacheService.instance;

      // 先检查是否已缓存
      final cachedPath = await cache.getCachedPath(widget.imageUrl);

      if (cachedPath != null && mounted) {
        setState(() {
          _localPath = cachedPath;
          _isLoading = false;
        });
        return;
      }

      // 没有缓存，后台下载并缓存
      // 同时先显示网络图片
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 后台缓存图片
      cache.cacheImage(widget.imageUrl).then((path) {
        if (mounted && path != null) {
          setState(() {
            _localPath = path;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_isLoading) {
      imageWidget = widget.placeholder ?? _buildPlaceholder();
    } else if (_hasError) {
      imageWidget = widget.errorWidget ?? _buildErrorWidget();
    } else if (_localPath != null) {
      // 从本地缓存加载
      imageWidget = Image.file(
        File(_localPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.cover,
        alignment: widget.alignment ?? Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildErrorWidget();
        },
      );
    } else {
      // 从网络加载
      imageWidget = Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit ?? BoxFit.cover,
        alignment: widget.alignment ?? Alignment.center,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.placeholder ?? _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ?? _buildErrorWidget();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[800],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[800],
      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
}
