import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:mikan_player/src/rust/api/danmaku.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DanmakuApi {
  Future<List<Danmaku>> getByTitle({
    required String animeTitle,
    required String episodeNumber,
    int? relativeEpisode,
  });

  Future<List<Danmaku>> getByBangumiId({
    required int subjectId,
    required String episodeNumber,
    int? relativeEpisode,
  });

  Future<List<DanmakuAnime>> searchAnime({required String keyword});

  Future<List<DanmakuEpisode>> getEpisodes({required PlatformInt64 animeId});

  Future<List<Danmaku>> getComments({required PlatformInt64 episodeId});

  Future<List<DanmakuMatch>> matchAnime({
    required String fileName,
    String? fileHash,
  });
}

class RustDanmakuApi implements DanmakuApi {
  const RustDanmakuApi();

  @override
  Future<List<Danmaku>> getByTitle({
    required String animeTitle,
    required String episodeNumber,
    int? relativeEpisode,
  }) => danmakuGetByTitle(
    animeTitle: animeTitle,
    episodeNumber: episodeNumber,
    relativeEpisode: relativeEpisode,
  );

  @override
  Future<List<Danmaku>> getByBangumiId({
    required int subjectId,
    required String episodeNumber,
    int? relativeEpisode,
  }) => danmakuGetByBangumiId(
    subjectId: subjectId,
    episodeNumber: episodeNumber,
    relativeEpisode: relativeEpisode,
  );

  @override
  Future<List<DanmakuAnime>> searchAnime({required String keyword}) =>
      danmakuSearchAnime(keyword: keyword);

  @override
  Future<List<DanmakuEpisode>> getEpisodes({required PlatformInt64 animeId}) =>
      danmakuGetEpisodes(animeId: animeId);

  @override
  Future<List<Danmaku>> getComments({required PlatformInt64 episodeId}) =>
      danmakuGetComments(episodeId: episodeId);

  @override
  Future<List<DanmakuMatch>> matchAnime({
    required String fileName,
    String? fileHash,
  }) => danmakuMatchAnime(fileName: fileName, fileHash: fileHash);
}

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
  final int fontWeight; // 字体粗细 (0-8, 对应 w100-w900)
  final double strokeWidth; // 描边宽度

  const DanmakuSettings({
    this.enabled = true,
    this.opacity = 0.8,
    this.fontSize = 22.0,
    this.speed = 10.0,
    this.displayArea = 0.75,
    this.showScrolling = true,
    this.showTop = true,
    this.showBottom = true,
    this.fontWeight = 4, // 默认 w500 (normal)
    this.strokeWidth = 2.5,
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
    int? fontWeight,
    double? strokeWidth,
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
      fontWeight: fontWeight ?? this.fontWeight,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}

/// 弹幕服务 - 管理弹幕获取和设置
class DanmakuService extends ChangeNotifier {
  final DanmakuApi _api;
  late final Future<void> _settingsLoaded;
  int _requestGeneration = 0;
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

  DanmakuService({DanmakuApi api = const RustDanmakuApi()}) : _api = api {
    _settingsLoaded = _loadSettings();
  }

  @visibleForTesting
  Future<void> get debugSettingsLoaded => _settingsLoaded;

  int _beginRequest() => ++_requestGeneration;

  bool _isCurrentRequest(int generation) => generation == _requestGeneration;

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
        fontWeight: prefs.getInt('danmaku_fontWeight') ?? 4,
        strokeWidth: prefs.getDouble('danmaku_strokeWidth') ?? 1.5,
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
      await prefs.setInt('danmaku_fontWeight', _settings.fontWeight);
      await prefs.setDouble('danmaku_strokeWidth', _settings.strokeWidth);
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
  Future<void> loadDanmakuByTitle(
    String animeTitle,
    String episodeNumber, {
    int? relativeEpisode,
  }) async {
    final generation = _beginRequest();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading by title: $animeTitle, episode: $episodeNumber (rel: $relativeEpisode)',
      );
      final danmakuList = await _api.getByTitle(
        animeTitle: animeTitle,
        episodeNumber: episodeNumber,
        relativeEpisode: relativeEpisode,
      );

      if (!_isCurrentRequest(generation)) return;

      _danmakuList = List<Danmaku>.of(danmakuList);
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Error: $e');
      notifyListeners();
    }
  }

  /// 通过 Bangumi TV subject_id 和集数获取弹幕（便捷方法）
  /// 失败时会自动使用动漫名称+集号重试
  Future<void> loadDanmakuByBangumiId(
    int subjectId,
    String episodeNumber, {
    int? relativeEpisode,
    String? animeTitle, // 用于失败重试
  }) async {
    final generation = _beginRequest();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading by Bangumi ID: $subjectId, episode: $episodeNumber (rel: $relativeEpisode)',
      );
      final danmakuList = await _api.getByBangumiId(
        subjectId: subjectId,
        episodeNumber: episodeNumber,
        relativeEpisode: relativeEpisode,
      );

      if (!_isCurrentRequest(generation)) return;

      _danmakuList = danmakuList;
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      debugPrint('[Danmaku] Bangumi ID fetch failed: $e');

      // 如果提供了动漫名称，尝试使用标题+集号重试
      if (animeTitle != null && animeTitle.isNotEmpty) {
        debugPrint('[Danmaku] Retrying with title-based search: $animeTitle');
        try {
          final danmakuList = await _api.getByTitle(
            animeTitle: animeTitle,
            episodeNumber: episodeNumber,
            relativeEpisode: relativeEpisode,
          );

          if (!_isCurrentRequest(generation)) return;

          _danmakuList = List<Danmaku>.of(danmakuList);
          _danmakuList.sort((a, b) => a.time.compareTo(b.time));
          _isLoading = false;
          debugPrint(
            '[Danmaku] Retry successful, loaded ${_danmakuList.length} danmaku',
          );
          notifyListeners();
          return;
        } catch (retryError) {
          if (!_isCurrentRequest(generation)) return;
          debugPrint('[Danmaku] Title-based retry also failed: $retryError');
          _error = '使用 Bangumi ID 和标题重试均失败: $retryError';
        }
      } else {
        _error = e.toString();
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  /// 搜索动画
  Future<void> searchAnime(String keyword) async {
    final generation = _beginRequest();
    _isLoading = true;
    _error = null;
    _searchResults = [];
    _episodes = [];
    _selectedAnime = null;
    _selectedEpisode = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Searching anime: $keyword');
      final results = await _api.searchAnime(keyword: keyword);
      if (!_isCurrentRequest(generation)) return;
      _searchResults = results;
      _isLoading = false;
      debugPrint('[Danmaku] Found ${_searchResults.length} results');
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Search error: $e');
      notifyListeners();
    }
  }

  /// 选择动画并获取剧集列表
  Future<void> selectAnime(DanmakuAnime anime) async {
    final generation = _beginRequest();
    _selectedAnime = anime;
    _selectedEpisode = null;
    _episodes = [];
    _danmakuList = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Getting episodes for anime: ${anime.animeTitle}');
      final episodes = await _api.getEpisodes(animeId: anime.animeId);
      if (!_isCurrentRequest(generation)) return;
      _episodes = episodes;
      _isLoading = false;
      debugPrint('[Danmaku] Found ${_episodes.length} episodes');
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Get episodes error: $e');
      notifyListeners();
    }
  }

  /// 选择剧集并获取弹幕
  Future<void> selectEpisode(DanmakuEpisode episode) async {
    final generation = _beginRequest();
    _selectedEpisode = episode;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        '[Danmaku] Loading danmaku for episode: ${episode.episodeTitle}',
      );
      _currentEpisodeId = episode.episodeId.toInt();
      final danmakuList = await _api.getComments(episodeId: episode.episodeId);
      if (!_isCurrentRequest(generation)) return;
      _danmakuList = List<Danmaku>.of(danmakuList);
      _danmakuList.sort((a, b) => a.time.compareTo(b.time));
      _isLoading = false;
      debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Load danmaku error: $e');
      notifyListeners();
    }
  }

  /// 通过文件名匹配获取弹幕
  Future<void> matchAndLoadDanmaku(String fileName, {String? fileHash}) async {
    final generation = _beginRequest();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[Danmaku] Matching file: $fileName');
      final matches = await _api.matchAnime(
        fileName: fileName,
        fileHash: fileHash,
      );

      if (!_isCurrentRequest(generation)) return;

      if (matches.isNotEmpty) {
        // 使用第一个匹配结果
        final match = matches.first;
        debugPrint(
          '[Danmaku] Matched: ${match.animeTitle} - ${match.episodeTitle}',
        );

        _currentEpisodeId = match.episodeId.toInt();
        final danmakuList = await _api.getComments(episodeId: match.episodeId);
        if (!_isCurrentRequest(generation)) return;
        _danmakuList = List<Danmaku>.of(danmakuList);
        _danmakuList.sort((a, b) => a.time.compareTo(b.time));
        debugPrint('[Danmaku] Loaded ${_danmakuList.length} danmaku');
      } else {
        debugPrint('[Danmaku] No match found');
        _danmakuList = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRequest(generation)) return;
      _isLoading = false;
      _error = e.toString();
      debugPrint('[Danmaku] Match error: $e');
      notifyListeners();
    }
  }

  /// 清空弹幕
  void clearDanmaku() {
    _requestGeneration++;
    _isLoading = false;
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
