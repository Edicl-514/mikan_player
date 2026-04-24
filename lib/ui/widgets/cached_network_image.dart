import 'dart:async';
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
  final bool deferOffscreenLoad;
  final double preloadExtent;

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
    this.deferOffscreenLoad = true,
    this.preloadExtent = 800,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  String? _localPath;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasStartedLoading = false;
  Timer? _deferredLoadTimer;
  ScrollPosition? _scrollPosition;
  int _loadGeneration = 0;

  Map<String, String> _buildHeaders(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': '${uri.scheme}://${uri.host}/',
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartLoading());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == nextPosition) return;

    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_scheduleVisibilityCheck);
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _deferredLoadTimer?.cancel();
      _loadGeneration++;
      _hasStartedLoading = false;
      setState(() {
        _isLoading = true;
        _hasError = false;
        _localPath = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartLoading());
    }
  }

  @override
  void dispose() {
    _deferredLoadTimer?.cancel();
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    super.dispose();
  }

  void _scheduleVisibilityCheck() {
    if (_hasStartedLoading || _deferredLoadTimer?.isActive == true) return;
    _deferredLoadTimer = Timer(const Duration(milliseconds: 80), () {
      _deferredLoadTimer = null;
      _maybeStartLoading();
    });
  }

  void _maybeStartLoading() {
    if (!mounted || _hasStartedLoading) return;

    if (widget.deferOffscreenLoad && !_isNearViewport()) {
      _scheduleDeferredVisibilityCheck();
      return;
    }

    _hasStartedLoading = true;
    _loadImage(_loadGeneration);
  }

  void _scheduleDeferredVisibilityCheck() {
    if (_deferredLoadTimer?.isActive == true) return;
    _deferredLoadTimer = Timer(const Duration(milliseconds: 300), () {
      _deferredLoadTimer = null;
      _maybeStartLoading();
    });
  }

  bool _isNearViewport() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return true;
    }

    final viewportSize = MediaQuery.maybeSizeOf(context);
    if (viewportSize == null) {
      return true;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    final viewport = Rect.fromLTWH(
      -widget.preloadExtent,
      -widget.preloadExtent,
      viewportSize.width + widget.preloadExtent * 2,
      viewportSize.height + widget.preloadExtent * 2,
    );
    return rect.overlaps(viewport);
  }

  Future<void> _loadImage(int generation) async {
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
      if (!cache.isInitialized) {
        await cache.initialize();
      }

      if (!mounted || generation != _loadGeneration) return;

      // 先检查是否已缓存
      final cachedPath = await cache.getCachedPath(widget.imageUrl);

      if (cachedPath != null && mounted && generation == _loadGeneration) {
        setState(() {
          _localPath = cachedPath;
          _isLoading = false;
        });
        return;
      }

      // 没有缓存，后台下载并缓存，同时先显示网络图片作为备用
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
        });
      }

      // 后台缓存图片，完成后切换到本地文件（更可靠）
      cache.cacheImage(widget.imageUrl).then((path) {
        if (mounted && generation == _loadGeneration && path != null) {
          setState(() {
            _localPath = path;
            _hasError = false;
          });
        } else if (mounted &&
            generation == _loadGeneration &&
            path == null &&
            _localPath == null) {
          // cacheImage failed; keep Image.network displayed (already set above)
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
        headers: _buildHeaders(widget.imageUrl),
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
