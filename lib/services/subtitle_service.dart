import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字幕显示设置
class SubtitleSettings {
  /// 是否启用字幕
  final bool enabled;

  /// 字体大小
  final double fontSize;

  /// 字体颜色
  final Color fontColor;

  /// 背景颜色
  final Color backgroundColor;

  /// 背景透明度 (0-1)
  final double backgroundOpacity;

  /// 描边颜色
  final Color outlineColor;

  /// 描边宽度
  final double outlineWidth;

  /// 底部边距
  final double bottomPadding;

  /// 字体粗细
  final FontWeight fontWeight;

  const SubtitleSettings({
    this.enabled = true,
    this.fontSize = 24.0,
    this.fontColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.backgroundOpacity = 0.5,
    this.outlineColor = Colors.black,
    this.outlineWidth = 1.5,
    this.bottomPadding = 48.0,
    this.fontWeight = FontWeight.w500,
  });

  SubtitleSettings copyWith({
    bool? enabled,
    double? fontSize,
    Color? fontColor,
    Color? backgroundColor,
    double? backgroundOpacity,
    Color? outlineColor,
    double? outlineWidth,
    double? bottomPadding,
    FontWeight? fontWeight,
  }) {
    return SubtitleSettings(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      bottomPadding: bottomPadding ?? this.bottomPadding,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  /// 获取字幕文本样式
  TextStyle toTextStyle() {
    return TextStyle(
      fontSize: fontSize,
      color: fontColor,
      fontWeight: fontWeight,
      backgroundColor: backgroundColor.withValues(alpha: backgroundOpacity),
      shadows: outlineWidth > 0
          ? [
              Shadow(
                blurRadius: outlineWidth,
                color: outlineColor,
                offset: const Offset(1, 1),
              ),
              Shadow(
                blurRadius: outlineWidth,
                color: outlineColor,
                offset: const Offset(-1, -1),
              ),
              Shadow(
                blurRadius: outlineWidth,
                color: outlineColor,
                offset: const Offset(1, -1),
              ),
              Shadow(
                blurRadius: outlineWidth,
                color: outlineColor,
                offset: const Offset(-1, 1),
              ),
            ]
          : null,
    );
  }
}

/// 字幕服务 - 管理字幕轨道和设置
class SubtitleService extends ChangeNotifier {
  Player? _player;
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _trackSubscription;
  StreamSubscription? _subtitleSubscription;
  bool _disposed = false;
  late final Future<void> _settingsLoaded;

  /// 当前设置
  SubtitleSettings _settings = const SubtitleSettings();
  SubtitleSettings get settings => _settings;

  /// 可用的字幕轨道列表
  List<SubtitleTrack> _availableTracks = [];
  List<SubtitleTrack> get availableTracks => _availableTracks;

  /// 当前选中的字幕轨道
  SubtitleTrack? _currentTrack;
  SubtitleTrack? get currentTrack => _currentTrack;

  /// 当前显示的字幕文本
  List<String> _currentSubtitleText = ['', ''];
  List<String> get currentSubtitleText => _currentSubtitleText;

  /// 是否有可用字幕
  bool get hasSubtitles =>
      _availableTracks.where((t) => t.id != 'auto' && t.id != 'no').isNotEmpty;

  /// 实际的字幕轨道（排除 auto 和 no）
  List<SubtitleTrack> get actualSubtitleTracks =>
      _availableTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();

  /// 是否正在显示字幕
  bool get isSubtitleVisible =>
      _settings.enabled && _currentTrack != null && _currentTrack!.id != 'no';

  /// 将 media_kit 的 auto/no 轨道解析成设置面板中可勾选的实际轨道。
  ///
  /// 播放器默认常报告 id=`auto`，而轨道列表里是 `1`/`2`…，直接比 id 会导致
  /// “有字幕却没有任何一项被选中”。
  SubtitleTrack? get resolvedSelectedTrack {
    final current = _currentTrack;
    if (current == null || current.id == 'no' || !_settings.enabled) {
      return null;
    }
    if (current.id != 'auto') {
      for (final track in actualSubtitleTracks) {
        if (track.id == current.id) return track;
      }
      return current;
    }
    // auto：优先默认轨，否则第一轨
    for (final track in actualSubtitleTracks) {
      if (track.isDefault == true) return track;
    }
    if (actualSubtitleTracks.isNotEmpty) {
      return actualSubtitleTracks.first;
    }
    return current;
  }

  /// 判断设置面板中某一轨道是否应显示为选中。
  bool isTrackSelected(SubtitleTrack track) {
    final selected = resolvedSelectedTrack;
    if (selected == null) return false;
    return selected.id == track.id;
  }

  SubtitleService() {
    _settingsLoaded = _loadSettings();
  }

  @visibleForTesting
  Future<void> get debugSettingsLoaded => _settingsLoaded;

  /// 绑定播放器
  void bindPlayer(Player player) {
    _player = player;

    // 监听可用轨道变化
    _tracksSubscription = player.stream.tracks.listen((tracks) {
      _availableTracks = tracks.subtitle;
      debugPrint('[Subtitle] 发现 ${actualSubtitleTracks.length} 个字幕轨道');
      for (final track in actualSubtitleTracks) {
        debugPrint(
          '[Subtitle]   - ${track.id}: ${track.title ?? "无标题"} (${track.language ?? "未知语言"})',
        );
      }
      // 设置里关闭了字幕时，主动把播放器轨切到 no，避免仅靠 visible 隐藏
      // 导致“看起来关了、轨却还在 auto”的状态不一致。
      if (!_settings.enabled &&
          _currentTrack != null &&
          _currentTrack!.id != 'no') {
        unawaited(_player?.setSubtitleTrack(SubtitleTrack.no()));
      }
      if (_disposed) return;
      notifyListeners();
    });

    // 监听当前轨道变化
    _trackSubscription = player.stream.track.listen((track) {
      _currentTrack = track.subtitle;
      debugPrint(
        '[Subtitle] 当前字幕轨道: ${_currentTrack?.id} - ${_currentTrack?.title}',
      );
      if (_disposed) return;
      notifyListeners();
    });

    // 监听字幕文本变化：供应用侧 SubtitleOverlay 实时渲染
    _subtitleSubscription = player.stream.subtitle.listen((subtitle) {
      _currentSubtitleText = subtitle;
      if (_disposed) return;
      notifyListeners();
    });
  }

  /// 解绑播放器
  void unbindPlayer() {
    _tracksSubscription?.cancel();
    _tracksSubscription = null;
    _trackSubscription?.cancel();
    _trackSubscription = null;
    _subtitleSubscription?.cancel();
    _subtitleSubscription = null;
    _player = null;
    _availableTracks = [];
    _currentTrack = null;
    _currentSubtitleText = ['', ''];
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// 切换字幕开关
  void toggleEnabled() {
    setEnabled(!_settings.enabled);
  }

  /// 设置启用状态
  void setEnabled(bool enabled) {
    if (_settings.enabled == enabled) return;
    if (enabled) {
      // 开启字幕：优先恢复已解析的实际轨，避免重复 set auto 无效
      final preferred = resolvedSelectedTrack;
      if (preferred != null && preferred.id != 'auto' && preferred.id != 'no') {
        unawaited(_player?.setSubtitleTrack(preferred));
        _currentTrack = preferred;
      } else if (actualSubtitleTracks.isNotEmpty) {
        final first = actualSubtitleTracks.first;
        unawaited(_player?.setSubtitleTrack(first));
        _currentTrack = first;
      } else {
        unawaited(_player?.setSubtitleTrack(SubtitleTrack.auto()));
        _currentTrack = SubtitleTrack.auto();
      }
    } else {
      unawaited(_player?.setSubtitleTrack(SubtitleTrack.no()));
      _currentTrack = SubtitleTrack.no();
    }
    _settings = _settings.copyWith(enabled: enabled);
    _saveSettings();
    notifyListeners();
  }

  /// 选择字幕轨道
  Future<void> selectTrack(SubtitleTrack track) async {
    if (_player == null) return;
    await _player!.setSubtitleTrack(track);
    _currentTrack = track;
    if (track.id != 'no' && !_settings.enabled) {
      _settings = _settings.copyWith(enabled: true);
    }
    _saveSettings();
    notifyListeners();
  }

  /// 关闭字幕
  Future<void> disableSubtitle() async {
    if (_player == null) return;
    await _player!.setSubtitleTrack(SubtitleTrack.no());
    _currentTrack = SubtitleTrack.no();
    _settings = _settings.copyWith(enabled: false);
    _saveSettings();
    notifyListeners();
  }

  /// 更新字幕设置
  void updateSettings(SubtitleSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  /// 设置字体大小
  void setFontSize(double size) {
    _settings = _settings.copyWith(fontSize: size.clamp(12.0, 64.0));
    _saveSettings();
    notifyListeners();
  }

  /// 设置字体颜色
  void setFontColor(Color color) {
    _settings = _settings.copyWith(fontColor: color);
    _saveSettings();
    notifyListeners();
  }

  /// 设置背景透明度
  void setBackgroundOpacity(double opacity) {
    _settings = _settings.copyWith(backgroundOpacity: opacity.clamp(0.0, 1.0));
    _saveSettings();
    notifyListeners();
  }

  /// 设置底部边距
  void setBottomPadding(double padding) {
    _settings = _settings.copyWith(bottomPadding: padding.clamp(0.0, 200.0));
    _saveSettings();
    notifyListeners();
  }

  /// 设置描边宽度
  void setOutlineWidth(double width) {
    _settings = _settings.copyWith(outlineWidth: width.clamp(0.0, 5.0));
    _saveSettings();
    notifyListeners();
  }

  /// 获取轨道显示名称
  String getTrackDisplayName(SubtitleTrack track) {
    if (track.id == 'auto') return '自动';
    if (track.id == 'no') return '关闭';

    final title = track.title;
    final language = track.language;

    if (title != null && title.isNotEmpty) {
      if (language != null && language.isNotEmpty) {
        return '$title (${_getLanguageName(language)})';
      }
      return title;
    }

    if (language != null && language.isNotEmpty) {
      return _getLanguageName(language);
    }

    // 使用轨道索引
    final index = actualSubtitleTracks.indexOf(track);
    return '字幕 ${index + 1}';
  }

  /// 获取语言友好名称
  String _getLanguageName(String code) {
    const languageMap = {
      'chi': '中文',
      'zho': '中文',
      'zh': '中文',
      'chs': '简体中文',
      'cht': '繁体中文',
      'eng': '英文',
      'en': '英文',
      'jpn': '日文',
      'ja': '日文',
      'kor': '韩文',
      'ko': '韩文',
      'fre': '法文',
      'fr': '法文',
      'ger': '德文',
      'de': '德文',
      'spa': '西班牙文',
      'es': '西班牙文',
      'rus': '俄文',
      'ru': '俄文',
      'ita': '意大利文',
      'it': '意大利文',
      'por': '葡萄牙文',
      'pt': '葡萄牙文',
      'ara': '阿拉伯文',
      'ar': '阿拉伯文',
      'und': '未知',
    };
    return languageMap[code.toLowerCase()] ?? code.toUpperCase();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = SubtitleSettings(
        enabled: prefs.getBool('subtitle_enabled') ?? true,
        fontSize: prefs.getDouble('subtitle_font_size') ?? 24.0,
        fontColor: Color(prefs.getInt('subtitle_font_color') ?? 0xFFFFFFFF),
        backgroundColor: Color(prefs.getInt('subtitle_bg_color') ?? 0xFF000000),
        backgroundOpacity: prefs.getDouble('subtitle_bg_opacity') ?? 0.5,
        outlineWidth: prefs.getDouble('subtitle_outline_width') ?? 1.5,
        bottomPadding: prefs.getDouble('subtitle_bottom_padding') ?? 48.0,
      );
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Subtitle] 加载设置失败: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('subtitle_enabled', _settings.enabled);
      await prefs.setDouble('subtitle_font_size', _settings.fontSize);
      await prefs.setInt('subtitle_font_color', _settings.fontColor.toARGB32());
      await prefs.setInt(
        'subtitle_bg_color',
        _settings.backgroundColor.toARGB32(),
      );
      await prefs.setDouble('subtitle_bg_opacity', _settings.backgroundOpacity);
      await prefs.setDouble('subtitle_outline_width', _settings.outlineWidth);
      await prefs.setDouble('subtitle_bottom_padding', _settings.bottomPadding);
    } catch (e) {
      debugPrint('[Subtitle] 保存设置失败: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unbindPlayer();
    super.dispose();
  }

  /// 仅用于单元测试注入轨道状态，避免依赖真实 Player 流。
  @visibleForTesting
  void debugSetTracksForTest({
    required List<SubtitleTrack> available,
    required SubtitleTrack? current,
    required bool enabled,
  }) {
    _availableTracks = available;
    _currentTrack = current;
    _settings = _settings.copyWith(enabled: enabled);
  }

  /// 仅用于单元测试注入当前字幕文本。
  @visibleForTesting
  void debugSetSubtitleTextForTest(List<String> lines) {
    _currentSubtitleText = lines;
  }
}

/// 预设颜色选项
class SubtitleColorPresets {
  static const List<Color> fontColors = [
    Colors.white,
    Color(0xFFFFFF00), // 黄色
    Color(0xFF00FF00), // 绿色
    Color(0xFF00FFFF), // 青色
    Color(0xFFFF69B4), // 粉色
    Color(0xFFFFA500), // 橙色
  ];

  static const List<Color> backgroundColors = [
    Colors.black,
    Color(0xFF1A1A1A),
    Color(0xFF333333),
    Color(0xFF000080), // 深蓝
    Color(0xFF800000), // 深红
  ];
}
