import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikan_player/src/rust/api/bangumi.dart';
import 'package:mikan_player/src/rust/api/crawler.dart';

class PlaybackHistoryItem {
  final String key;
  final String title;
  final String? subTitle;
  final String? bangumiId;
  final String? mikanId;
  final String? coverUrl;
  final String? siteUrl;
  final String? broadcastDay;
  final String? broadcastTime;
  final double? score;
  final int? rank;
  final List<String> tags;
  final String? fullJson;

  final int episodeId;
  final double episodeSort;
  final String episodeName;
  final String episodeNameCn;
  final String episodesJson;
  final int updatedAt;
  final int lastPositionMs; // last watched position in milliseconds

  const PlaybackHistoryItem({
    required this.key,
    required this.title,
    required this.subTitle,
    required this.bangumiId,
    required this.mikanId,
    required this.coverUrl,
    required this.siteUrl,
    required this.broadcastDay,
    required this.broadcastTime,
    required this.score,
    required this.rank,
    required this.tags,
    required this.fullJson,
    required this.episodeId,
    required this.episodeSort,
    required this.episodeName,
    required this.episodeNameCn,
    required this.episodesJson,
    required this.updatedAt,
    required this.lastPositionMs,
  });

  factory PlaybackHistoryItem.fromJson(Map<String, dynamic> json) {
    return PlaybackHistoryItem(
      key: json['key'] as String,
      title: json['title'] as String,
      subTitle: json['subTitle'] as String?,
      bangumiId: json['bangumiId'] as String?,
      mikanId: json['mikanId'] as String?,
      coverUrl: json['coverUrl'] as String?,
      siteUrl: json['siteUrl'] as String?,
      broadcastDay: json['broadcastDay'] as String?,
      broadcastTime: json['broadcastTime'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      fullJson: json['fullJson'] as String?,
      episodeId: json['episodeId'] as int,
      episodeSort: (json['episodeSort'] as num).toDouble(),
      episodeName: json['episodeName'] as String,
      episodeNameCn: json['episodeNameCn'] as String,
      episodesJson: json['episodesJson'] as String? ?? '[]',
      updatedAt: json['updatedAt'] as int,
      lastPositionMs: json['lastPositionMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'subTitle': subTitle,
      'bangumiId': bangumiId,
      'mikanId': mikanId,
      'coverUrl': coverUrl,
      'siteUrl': siteUrl,
      'broadcastDay': broadcastDay,
      'broadcastTime': broadcastTime,
      'score': score,
      'rank': rank,
      'tags': tags,
      'fullJson': fullJson,
      'episodeId': episodeId,
      'episodeSort': episodeSort,
      'episodeName': episodeName,
      'episodeNameCn': episodeNameCn,
      'episodesJson': episodesJson,
      'updatedAt': updatedAt,
      'lastPositionMs': lastPositionMs,
    };
  }

  AnimeInfo toAnimeInfo() {
    return AnimeInfo(
      title: title,
      subTitle: subTitle,
      bangumiId: bangumiId,
      mikanId: mikanId,
      coverUrl: coverUrl,
      siteUrl: siteUrl,
      broadcastDay: broadcastDay,
      broadcastTime: broadcastTime,
      score: score,
      rank: rank,
      tags: tags,
      fullJson: fullJson,
    );
  }

  List<BangumiEpisode> toEpisodes() {
    try {
      final list = jsonDecode(episodesJson) as List<dynamic>;
      return list.map((item) {
        final data = item as Map<String, dynamic>;
        return BangumiEpisode(
          id: data['id'] as int,
          name: data['name'] as String,
          nameCn: data['nameCn'] as String,
          description: data['description'] as String,
          airdate: data['airdate'] as String,
          duration: data['duration'] as String,
          sort: (data['sort'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return <BangumiEpisode>[];
    }
  }
}

class PlaybackHistoryManager {
  static final PlaybackHistoryManager _instance =
      PlaybackHistoryManager._internal();
  factory PlaybackHistoryManager() => _instance;
  PlaybackHistoryManager._internal();

  static const String _storageKey = 'playback_history_v1';
  static const int _maxItems = 200;

  String _buildKey(AnimeInfo anime) {
    if (anime.bangumiId != null && anime.bangumiId!.isNotEmpty) {
      return 'bgm:${anime.bangumiId}';
    }
    if (anime.mikanId != null && anime.mikanId!.isNotEmpty) {
      return 'mikan:${anime.mikanId}';
    }
    return 'title:${anime.title}';
  }

  String _encodeEpisodes(List<BangumiEpisode> episodes) {
    final list = episodes
        .map((e) => {
              'id': e.id,
              'name': e.name,
              'nameCn': e.nameCn,
              'description': e.description,
              'airdate': e.airdate,
              'duration': e.duration,
              'sort': e.sort,
            })
        .toList();
    return jsonEncode(list);
  }

  Future<List<PlaybackHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <PlaybackHistoryItem>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PlaybackHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <PlaybackHistoryItem>[];
    }
  }

  Future<void> addOrUpdate({
    required AnimeInfo anime,
    required BangumiEpisode currentEpisode,
    required List<BangumiEpisode> allEpisodes,
    int? lastPositionMs,
  }) async {
    final history = await getHistory();
    final key = _buildKey(anime);
    history.removeWhere((item) => item.key == key);

    final item = PlaybackHistoryItem(
      key: key,
      title: anime.title,
      subTitle: anime.subTitle,
      bangumiId: anime.bangumiId,
      mikanId: anime.mikanId,
      coverUrl: anime.coverUrl,
      siteUrl: anime.siteUrl,
      broadcastDay: anime.broadcastDay,
      broadcastTime: anime.broadcastTime,
      score: anime.score,
      rank: anime.rank,
      tags: anime.tags,
      fullJson: anime.fullJson,
      episodeId: currentEpisode.id,
      episodeSort: currentEpisode.sort,
      episodeName: currentEpisode.name,
      episodeNameCn: currentEpisode.nameCn,
      episodesJson: _encodeEpisodes(allEpisodes),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      lastPositionMs: lastPositionMs ?? 0,
    );

    history.insert(0, item);
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String key) async {
    final history = await getHistory();
    history.removeWhere((item) => item.key == key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  /// Update only the playback position for an existing history item
  Future<void> updatePosition(String key, int positionMs) async {
    final history = await getHistory();
    final idx = history.indexWhere((i) => i.key == key);
    if (idx == -1) return;
    final item = history[idx];
    final updated = PlaybackHistoryItem(
      key: item.key,
      title: item.title,
      subTitle: item.subTitle,
      bangumiId: item.bangumiId,
      mikanId: item.mikanId,
      coverUrl: item.coverUrl,
      siteUrl: item.siteUrl,
      broadcastDay: item.broadcastDay,
      broadcastTime: item.broadcastTime,
      score: item.score,
      rank: item.rank,
      tags: item.tags,
      fullJson: item.fullJson,
      episodeId: item.episodeId,
      episodeSort: item.episodeSort,
      episodeName: item.episodeName,
      episodeNameCn: item.episodeNameCn,
      episodesJson: item.episodesJson,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      lastPositionMs: positionMs,
    );

    history.removeAt(idx);
    history.insert(0, updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}