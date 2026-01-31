import 'package:flutter/material.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart' as danmaku;
import 'package:mikan_player/src/rust/api/danmaku.dart';
import 'package:mikan_player/services/danmaku_service.dart';

/// 弹幕渲染层组件 - 使用 canvas_danmaku 库实现高性能渲染
class DanmakuOverlay extends StatefulWidget {
  /// 当前视频播放时间（秒）
  final double currentTime;

  /// 弹幕列表
  final List<Danmaku> danmakuList;

  /// 弹幕设置
  final DanmakuSettings settings;

  /// 是否暂停
  final bool isPaused;

  /// 视频是否在播放中
  final bool isPlaying;

  const DanmakuOverlay({
    super.key,
    required this.currentTime,
    required this.danmakuList,
    required this.settings,
    this.isPaused = false,
    this.isPlaying = true,
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay> {
  danmaku.DanmakuController? _controller;
  double _lastTime = 0;
  int _lastProcessedIndex = 0;

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果时间跳跃（seek），重置弹幕
    if ((widget.currentTime - _lastTime).abs() > 2.0) {
      _resetDanmaku();
    }

    // 处理暂停/恢复
    if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _controller?.pause();
      } else {
        _controller?.resume();
      }
    }

    // 处理播放状态变化
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (!widget.isPlaying) {
        _controller?.pause();
      } else if (!widget.isPaused) {
        _controller?.resume();
      }
    }

    // 处理新的弹幕
    if (widget.isPlaying && !widget.isPaused) {
      _processDanmaku();
    }

    _lastTime = widget.currentTime;

    // 设置变化时，更新选项
    if (oldWidget.settings != widget.settings) {
      _updateOption();
    }

    // 如果弹幕列表变化（重新加载），重置
    if (oldWidget.danmakuList != widget.danmakuList) {
      _resetDanmaku();
    }
  }

  void _resetDanmaku() {
    _controller?.clear();
    _lastProcessedIndex = _findStartIndex(widget.currentTime);
  }

  int _findStartIndex(double time) {
    if (widget.danmakuList.isEmpty) return 0;

    // 二分查找
    int left = 0;
    int right = widget.danmakuList.length - 1;

    while (left < right) {
      int mid = (left + right) ~/ 2;
      if (widget.danmakuList[mid].time < time) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }

    return left;
  }

  void _processDanmaku() {
    if (!widget.settings.enabled) return;
    if (widget.danmakuList.isEmpty) return;
    if (_controller == null) return;

    final currentTime = widget.currentTime;

    // 处理当前时间窗口内的新弹幕
    while (_lastProcessedIndex < widget.danmakuList.length) {
      final danmakuItem = widget.danmakuList[_lastProcessedIndex];

      // 只处理在当前时间之后0.5秒内的弹幕
      if (danmakuItem.time > currentTime + 0.5) break;

      // 跳过已经过期的弹幕
      if (danmakuItem.time < currentTime - 0.5) {
        _lastProcessedIndex++;
        continue;
      }

      // 检查弹幕类型过滤
      final type = _getDanmakuType(danmakuItem.danmakuType);
      if (!_shouldShowType(type)) {
        _lastProcessedIndex++;
        continue;
      }

      // 添加弹幕到 canvas_danmaku
      _addDanmaku(danmakuItem);
      _lastProcessedIndex++;
    }
  }

  danmaku.DanmakuItemType _getDanmakuType(int type) {
    switch (type) {
      case 4:
        return danmaku.DanmakuItemType.bottom;
      case 5:
        return danmaku.DanmakuItemType.top;
      default:
        return danmaku.DanmakuItemType.scroll;
    }
  }

  bool _shouldShowType(danmaku.DanmakuItemType type) {
    switch (type) {
      case danmaku.DanmakuItemType.scroll:
        return widget.settings.showScrolling;
      case danmaku.DanmakuItemType.top:
        return widget.settings.showTop;
      case danmaku.DanmakuItemType.bottom:
        return widget.settings.showBottom;
      case danmaku.DanmakuItemType.special:
        return true; // 暂时总是显示特殊弹幕
    }
  }

  void _addDanmaku(Danmaku danmakuItem) {
    final r = (danmakuItem.color >> 16) & 0xFF;
    final g = (danmakuItem.color >> 8) & 0xFF;
    final b = danmakuItem.color & 0xFF;
    final color = Color.fromARGB(255, r, g, b);

    _controller?.addDanmaku(
      danmaku.DanmakuContentItem(
        danmakuItem.text,
        color: color,
        type: _getDanmakuType(danmakuItem.danmakuType),
      ),
    );
  }

  void _updateOption() {
    _controller?.updateOption(
      danmaku.DanmakuOption(
        fontSize: widget.settings.fontSize,
        area: widget.settings.displayArea,
        duration: widget.settings.speed,
        opacity: widget.settings.opacity,
        hideScroll: !widget.settings.showScrolling,
        hideTop: !widget.settings.showTop,
        hideBottom: !widget.settings.showBottom,
        strokeWidth: 1.5,
        safeArea: true,
      ),
    );
  }

  void _onControllerCreated(danmaku.DanmakuController controller) {
    _controller = controller;

    // 初始化时，如果已暂停则暂停控制器
    if (widget.isPaused || !widget.isPlaying) {
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.enabled) {
      return const SizedBox.shrink();
    }

    return danmaku.DanmakuScreen(
      createdController: _onControllerCreated,
      option: danmaku.DanmakuOption(
        fontSize: widget.settings.fontSize,
        area: widget.settings.displayArea,
        duration: widget.settings.speed,
        opacity: widget.settings.opacity,
        hideScroll: !widget.settings.showScrolling,
        hideTop: !widget.settings.showTop,
        hideBottom: !widget.settings.showBottom,
        strokeWidth: 1.5,
        safeArea: true,
      ),
    );
  }
}

/// 弹幕控制器 - 兼容旧接口
class DanmakuController extends ChangeNotifier {
  final DanmakuService _service;
  double _currentTime = 0;
  bool _isPaused = false;
  bool _isPlaying = false;

  DanmakuController(this._service);

  double get currentTime => _currentTime;
  bool get isPaused => _isPaused;
  bool get isPlaying => _isPlaying;
  DanmakuService get service => _service;
  List<Danmaku> get danmakuList => _service.danmakuList;
  DanmakuSettings get settings => _service.settings;

  void updateTime(double time) {
    _currentTime = time;
    notifyListeners();
  }

  void setPaused(bool paused) {
    _isPaused = paused;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void toggleEnabled() {
    _service.toggleEnabled();
    notifyListeners();
  }

  void updateSettings(DanmakuSettings settings) {
    _service.updateSettings(settings);
    notifyListeners();
  }
}
