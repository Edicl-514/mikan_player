import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';
import 'package:mikan_player/services/danmaku_service.dart';

/// 活跃弹幕项
class ActiveDanmaku {
  final Danmaku danmaku;
  final double startTime; // 视频时间（秒）
  final int track; // 轨道编号
  final GlobalKey key;
  double? measuredWidth; // 测量后的宽度
  bool isVisible;

  ActiveDanmaku({
    required this.danmaku,
    required this.startTime,
    required this.track,
  })  : key = GlobalKey(),
        isVisible = true;

  // 计算弹幕颜色
  Color get color {
    final r = (danmaku.color >> 16) & 0xFF;
    final g = (danmaku.color >> 8) & 0xFF;
    final b = danmaku.color & 0xFF;
    return Color.fromARGB(255, r, g, b);
  }

  // 弹幕类型
  DanmakuType get type {
    switch (danmaku.danmakuType) {
      case 4:
        return DanmakuType.bottom;
      case 5:
        return DanmakuType.top;
      default:
        return DanmakuType.scroll;
    }
  }
}

enum DanmakuType { scroll, top, bottom }

/// 弹幕渲染层组件
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

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final List<ActiveDanmaku> _activeDanmaku = [];
  int _lastProcessedIndex = 0;
  double _lastTime = 0;
  Timer? _updateTimer;

  // 轨道管理
  late List<double> _scrollTrackEndTimes; // 每个滚动轨道的结束时间
  late List<double> _topTrackEndTimes;
  late List<double> _bottomTrackEndTimes;

  @override
  void initState() {
    super.initState();
    _initTracks();
    _startUpdateTimer();
  }

  void _initTracks() {
    const maxTracks = 15;
    _scrollTrackEndTimes = List.filled(maxTracks, 0.0);
    _topTrackEndTimes = List.filled(maxTracks, 0.0);
    _bottomTrackEndTimes = List.filled(maxTracks, 0.0);
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && !widget.isPaused) {
        _cleanupExpiredDanmaku();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果时间跳跃（seek），重置弹幕
    if ((widget.currentTime - _lastTime).abs() > 2.0) {
      _resetDanmaku();
    }

    // 处理新的弹幕
    if (widget.isPlaying && !widget.isPaused) {
      _processDanmaku();
    }

    _lastTime = widget.currentTime;

    // 设置变化时，可能需要重新过滤
    if (oldWidget.settings != widget.settings) {
      _filterActiveDanmaku();
    }
  }

  void _resetDanmaku() {
    _activeDanmaku.clear();
    _lastProcessedIndex = _findStartIndex(widget.currentTime);
    _initTracks();
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

    final currentTime = widget.currentTime;
    final screenWidth = MediaQuery.of(context).size.width;
    final displayDuration = widget.settings.speed;

    // 处理当前时间窗口内的新弹幕
    while (_lastProcessedIndex < widget.danmakuList.length) {
      final danmaku = widget.danmakuList[_lastProcessedIndex];

      // 只处理在当前时间之后0.5秒内的弹幕
      if (danmaku.time > currentTime + 0.5) break;

      // 跳过已经过期的弹幕
      if (danmaku.time < currentTime - 0.5) {
        _lastProcessedIndex++;
        continue;
      }

      // 检查同屏数量限制
      if (_activeDanmaku.length >= widget.settings.maxCount) {
        _lastProcessedIndex++;
        continue;
      }

      // 检查弹幕类型过滤
      final type = _getDanmakuType(danmaku.danmakuType);
      if (!_shouldShowType(type)) {
        _lastProcessedIndex++;
        continue;
      }

      // 分配轨道
      final track = _assignTrack(type, currentTime, displayDuration);
      if (track >= 0) {
        final active = ActiveDanmaku(
          danmaku: danmaku,
          startTime: danmaku.time,
          track: track,
        );
        _activeDanmaku.add(active);
      }

      _lastProcessedIndex++;
    }
  }

  DanmakuType _getDanmakuType(int type) {
    switch (type) {
      case 4:
        return DanmakuType.bottom;
      case 5:
        return DanmakuType.top;
      default:
        return DanmakuType.scroll;
    }
  }

  bool _shouldShowType(DanmakuType type) {
    switch (type) {
      case DanmakuType.scroll:
        return widget.settings.showScrolling;
      case DanmakuType.top:
        return widget.settings.showTop;
      case DanmakuType.bottom:
        return widget.settings.showBottom;
    }
  }

  int _assignTrack(DanmakuType type, double currentTime, double duration) {
    final trackList = switch (type) {
      DanmakuType.scroll => _scrollTrackEndTimes,
      DanmakuType.top => _topTrackEndTimes,
      DanmakuType.bottom => _bottomTrackEndTimes,
    };

    // 根据显示区域计算可用轨道数
    final maxTrack = (trackList.length * widget.settings.displayArea).toInt();

    // 查找可用轨道
    for (int i = 0; i < maxTrack; i++) {
      if (trackList[i] <= currentTime) {
        // 标记轨道占用
        if (type == DanmakuType.scroll) {
          // 滚动弹幕需要留出间隔避免重叠
          trackList[i] = currentTime + duration * 0.3;
        } else {
          // 固定弹幕
          trackList[i] = currentTime + 4.0; // 固定显示4秒
        }
        return i;
      }
    }

    return -1; // 无可用轨道
  }

  void _cleanupExpiredDanmaku() {
    final currentTime = widget.currentTime;
    final duration = widget.settings.speed;

    _activeDanmaku.removeWhere((d) {
      if (d.type == DanmakuType.scroll) {
        return currentTime > d.startTime + duration;
      } else {
        return currentTime > d.startTime + 4.0;
      }
    });
  }

  void _filterActiveDanmaku() {
    _activeDanmaku.removeWhere((d) => !_shouldShowType(d.type));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.enabled) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final trackHeight = widget.settings.fontSize + 6;
    final currentTime = widget.currentTime;
    final duration = widget.settings.speed;

    return ClipRect(
      child: Opacity(
        opacity: widget.settings.opacity,
        child: Stack(
          children: _activeDanmaku.map((d) {
            return _buildDanmakuWidget(
              d,
              size,
              trackHeight,
              currentTime,
              duration,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDanmakuWidget(
    ActiveDanmaku d,
    Size size,
    double trackHeight,
    double currentTime,
    double duration,
  ) {
    final top = d.track * trackHeight;

    switch (d.type) {
      case DanmakuType.scroll:
        return _buildScrollDanmaku(d, size, top, currentTime, duration);
      case DanmakuType.top:
        return _buildTopDanmaku(d, size, top);
      case DanmakuType.bottom:
        return _buildBottomDanmaku(d, size, trackHeight);
    }
  }

  Widget _buildScrollDanmaku(
    ActiveDanmaku d,
    Size size,
    double top,
    double currentTime,
    double duration,
  ) {
    // 计算进度 (0.0 - 1.0)
    final progress = (currentTime - d.startTime) / duration;
    // 从右往左滚动
    final left = size.width - progress * (size.width + 300);

    return Positioned(
      top: top,
      left: left,
      child: _DanmakuText(
        key: d.key,
        text: d.danmaku.text,
        color: d.color,
        fontSize: widget.settings.fontSize,
      ),
    );
  }

  Widget _buildTopDanmaku(
    ActiveDanmaku d,
    Size size,
    double top,
  ) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: _DanmakuText(
          key: d.key,
          text: d.danmaku.text,
          color: d.color,
          fontSize: widget.settings.fontSize,
        ),
      ),
    );
  }

  Widget _buildBottomDanmaku(
    ActiveDanmaku d,
    Size size,
    double trackHeight,
  ) {
    // 底部弹幕从底部往上排列
    final bottom = d.track * trackHeight + 40; // 留出控制栏空间

    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      child: Center(
        child: _DanmakuText(
          key: d.key,
          text: d.danmaku.text,
          color: d.color,
          fontSize: widget.settings.fontSize,
        ),
      ),
    );
  }
}

/// 弹幕文本组件
class _DanmakuText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const _DanmakuText({
    super.key,
    required this.text,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(offset: Offset(1, 1), color: Colors.black, blurRadius: 2),
          Shadow(offset: Offset(-1, -1), color: Colors.black, blurRadius: 2),
          Shadow(offset: Offset(1, -1), color: Colors.black, blurRadius: 2),
          Shadow(offset: Offset(-1, 1), color: Colors.black, blurRadius: 2),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.visible,
    );
  }
}

/// 弹幕控制器
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
