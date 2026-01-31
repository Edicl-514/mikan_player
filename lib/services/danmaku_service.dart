import 'package:flutter/foundation.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕设置数据类
class DanmakuSettings {
  final bool enabled;
  final double opacity;
  final double fontSize;
  final double speed; // 弹幕滚动速度 (秒)
  final double displayArea; // 显示区域 (0.0 - 1.0)
  final bool showScrolling; // 显示滚动弹幕
  final bool showTop; // 显示顶部弹幕
  final bool showBottom; // 显示底部弹幕
  final int maxCount; // 同屏最大弹幕数

  const DanmakuSettings({
    this.enabled = true,
    this.opacity = 0.8,
    this.fontSize = 24.0,
    this.speed = 8.0,
    this.displayArea = 0.75,
    this.showScrolling = true,
    this.showTop = true,
    this.showBottom = true,
    this.maxCount = 50,
  });

  DanmakuSettings copyWith({
    bool? enabled,
    double? opacity,
    double? fontSize,
    double? speed,
    double? displayArea,
    bool? showScrolling,
    bool? showTop,
    bool? showBottom,
    int? maxCount,
  }) {
    return DanmakuSettings(
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      speed: speed ?? this.speed,
      displayArea: displayArea ?? this.displayArea,
      showScrolling: showScrolling ?? this.showScrolling,
      showTop: showTop ?? this.showTop,
      showBottom: showBottom ?? this.showBottom,
      maxCount: maxCount ?? this.maxCount,
    );
  }
}

/// 弹幕服务 - 管理弹幕获取和设置
class DanmakuService extends ChangeNotifier {
  List<Danmaku> _danmakuList = [];
  DanmakuSettings _settings = const DanmakuSettings();
  bool _isLoading = false;
  String? _error;
  int? _currentEpisodeId;

  // 匹配信息
  List<DanmakuAnime> _searchResults = [];
  List<DanmakuEpisode> _episodes = [];
  DanmakuAnime? _selectedAnime;
  DanmakuEpisode? _selectedEpisode;

  List<Danmaku> get danmakuList => _danmakuList;
  DanmakuSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentEpisodeId => _currentEpisodeId;
  List<DanmakuAnime> get searchResults => _searchResults;
  List<DanmakuEpisode> get episodes => _episodes;
  DanmakuAnime? get selectedAnime => _selectedAnime;
  DanmakuEpisode? get selectedEpisode => _selectedEpisode;
  int get danmakuCount => _danmakuList.length;

  DanmakuService() {
    _loadSettings();
  }

  /// 从本地存储加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = DanmakuSettings(
        enabled: prefs.getBool('danmaku_enabled') ?? true,
        opacity: prefs.getDouble('danmaku_opacity') ?? 0.8,
        fontSize: prefs.getDouble('danmaku_fontSize') ?? 24.0,
        speed: prefs.getDouble('danmaku_speed') ?? 8.0,
        displayArea: prefs.getDouble('danmaku_displayArea') ?? 0.75,
        showScrolling: prefs.getBool('danmaku_showScrolling') ?? true,
        showTop: prefs.getBool('danmaku_showTop') ?? true,
        showBottom: prefs.getBool('danmaku_showBottom') ?? true,
        maxCount: prefs.getInt('danmaku_maxCount') ?? 50,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading danmaku settings: $e');
    }
  }

  /// 保存设置到本地存储
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('danmaku_enabled', _settings.enabled);
      await prefs.setDouble('danmaku_opacity', _settings.opacity);
      await prefs.setDouble('danmaku_fontSize', _settings.fontSize);
      await prefs.setDouble('danmaku_speed', _settings.speed);
      await prefs.setDouble('danmaku_displayArea', _settings.displayArea);
      await prefs.setBool('danmaku_showScrolling', _settings.showScrolling);
      await prefs.setBool('danmaku_showTop', _settings.showTop);
      await prefs.setBool('danmaku_showBottom', _settings.showBottom);
      await prefs.setInt('danmaku_maxCount', _settings.maxCount);
    } catch (e) {
      debugPrint('Error saving danmaku settings: $e');
    }
  }

  /// 更新设置
  void updateSettings(DanmakuSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  /// 切换弹幕开关
  void toggleEnabled() {
    _settings = _settings.copyWith(enabled: !_settings.enabled);
    _saveSettings();
    notifyListeners();
  }

  /// 通过标题和集数获取弹幕（便捷方法）
  Future<void> loadDanmakuByTitle(String animeTitle, String episodeNumber,
      {int? relativeEpisode}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading by title: $animeTitle, episode: $episodeNumber (rel: $relativeEpisode)',
      );
      final danmakuList = await danmakuGetByTitle(
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
        relativeEpisode: relativeEpisode,
      );

      _danmakuList = danmakuList;
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Error: $e');
      notifyListeners();
    }
  }

  /// 通过 Bangumi TV subject_id 和集数获取弹幕（便捷方法）
  Future<void> loadDanmakuByBangumiId(
    int subjectId,
    String episodeNumber, {
    int? relativeEpisode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading by Bangumi ID: $subjectId, episode: $episodeNumber (rel: $relativeEpisode)',
      );
      final danmakuList = await danmakuGetByBangumiId(
        subjectId: subjectId,
        episodeNumber: episodeNumber,
        relativeEpisode: relativeEpisode,
      );

      _danmakuList = danmakuList;
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Error: $e');
      notifyListeners();
    }
  }

  /// 搜索动画
  Future<void> searchAnime(String keyword) async {
    _isLoading = true;
    _error = null;
    _searchResults = [];
    _episodes = [];
    _selectedAnime = null;
    _selectedEpisode = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Searching anime: $keyword');
      _searchResults = await danmakuSearchAnime(keyword: keyword);
      _isLoading = false;
      debugPrint('[Danmaku] Found ${_searchResults.length} results');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Search error: $e');
      notifyListeners();
    }
  }

  /// 选择动画并获取剧集列表
  Future<void> selectAnime(DanmakuAnime anime) async {
    _selectedAnime = anime;
    _selectedEpisode = null;
    _episodes = [];
    _danmakuList = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Getting episodes for anime: ${anime.animeTitle}');
      _episodes = await danmakuGetEpisodes(animeId: anime.animeId);
      _isLoading = false;
      debugPrint('[Danmaku] Found ${_episodes.length} episodes');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Get episodes error: $e');
      notifyListeners();
    }
  }

  /// 选择剧集并获取弹幕
  Future<void> selectEpisode(DanmakuEpisode episode) async {
    _selectedEpisode = episode;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading danmaku for episode: ${episode.episodeTitle}',
      );
      _currentEpisodeId = episode.episodeId.toInt();
      _danmakuList = await danmakuGetComments(episodeId: episode.episodeId);
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Load danmaku error: $e');
      notifyListeners();
    }
  }

  /// 通过文件名匹配获取弹幕
  Future<void> matchAndLoadDanmaku(String fileName, {String? fileHash}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Matching file: $fileName');
      final matches = await danmakuMatchAnime(
        fileName: fileName,
        fileHash: fileHash,
      );

      if (matches.isNotEmpty) {
        // 使用第一个匹配结果
        final match = matches.first;
        debugPrint(
          '[Danmaku] Matched: ${match.animeTitle} - ${match.episodeTitle}',
        );

        _currentEpisodeId = match.episodeId.toInt();
        _danmakuList = await danmakuGetComments(episodeId: match.episodeId);
        _danmakuList.sort((a, b) => a.time.compareTo(b.time));
        debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      } else {
        debugPrint('[Danmaku] No match found');
        _danmakuList = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Match error: $e');
      notifyListeners();
    }
  }

  /// 清空弹幕
  void clearDanmaku() {
    _danmakuList = [];
    _currentEpisodeId = null;
    _selectedAnime = null;
    _selectedEpisode = null;
    _error = null;
    notifyListeners();
  }

  /// 获取指定时间范围内的弹幕
  List<Danmaku> getDanmakuInRange(double startTime, double endTime) {
    return _danmakuList
        .where((d) => d.time >= startTime && d.time < endTime)
        .toList();
  }

  /// 根据设置过滤弹幕
  List<Danmaku> filterDanmaku(List<Danmaku> danmakuList) {
    return danmakuList.where((d) {
      // 过滤弹幕类型
      if (d.danmakuType >= 1 &&
          d.danmakuType <= 3 &&
          !_settings.showScrolling) {
        return false;
      }
      if (d.danmakuType == 4 && !_settings.showBottom) {
        return false;
      }
      if (d.danmakuType == 5 && !_settings.showTop) {
        return false;
      }
      return true;
    }).toList();
  }
}
