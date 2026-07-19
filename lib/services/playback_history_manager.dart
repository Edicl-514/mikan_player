import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// In-memory snapshot so dispose/pause can update progress even if the
  /// SharedPreferences write has not completed yet.
  List<PlaybackHistoryItem>? _cache;

  /// Serializes load/mutate/persist so concurrent position ticks cannot clobber
  /// each other (last-write-wins with stale getHistory() reads).
  Future<void> _writeChain = Future<void>.value();

  /// Drops the in-memory snapshot so the next read reloads from disk.
  ///
  /// Used by tests that seed SharedPreferences directly and need the singleton
  /// to observe those values.
  @visibleForTesting
  void debugResetCacheForTest() {
    _cache = null;
    _writeChain = Future<void>.value();
  }

  String buildKey(AnimeInfo anime) {
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
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'nameCn': e.nameCn,
            'description': e.description,
            'airdate': e.airdate,
            'duration': e.duration,
            'sort': e.sort,
          },
        )
        .toList();
    return jsonEncode(list);
  }

  Future<List<PlaybackHistoryItem>> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <PlaybackHistoryItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PlaybackHistoryItem>[];

      // Keep well-formed entries even when a single corrupt row exists. A
      // whole-list wipe on the first cast/parse failure used to discard the
      // user's entire history after one bad write or partial upgrade.
      final items = <PlaybackHistoryItem>[];
      for (final entry in decoded) {
        try {
          if (entry is Map<String, dynamic>) {
            items.add(PlaybackHistoryItem.fromJson(entry));
          } else if (entry is Map) {
            items.add(
              PlaybackHistoryItem.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            );
          }
        } catch (_) {
          // Skip the bad row and continue.
        }
      }
      return items;
    } catch (_) {
      return <PlaybackHistoryItem>[];
    }
  }

  Future<List<PlaybackHistoryItem>> _ensureCache() async {
    final existing = _cache;
    if (existing != null) return List<PlaybackHistoryItem>.from(existing);
    final loaded = await _loadFromDisk();
    _cache = loaded;
    return List<PlaybackHistoryItem>.from(loaded);
  }

  Future<void> _persist(List<PlaybackHistoryItem> history) async {
    _cache = List<PlaybackHistoryItem>.from(history);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeChain = _writeChain
        .catchError((_) {})
        .then((_) => action())
        .then((value) {
          if (!completer.isCompleted) completer.complete(value);
        })
        .catchError((Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        });
    return completer.future;
  }

  Future<List<PlaybackHistoryItem>> getHistory() {
    return _runSerialized(() async {
      return _ensureCache();
    });
  }

  Future<PlaybackHistoryItem?> findByAnime(AnimeInfo anime) async {
    final key = buildKey(anime);
    final history = await getHistory();
    for (final item in history) {
      if (item.key == key) return item;
    }
    return null;
  }

  /// Returns a resume position for [episode] when history matches that episode.
  Future<int?> resumePositionMsFor({
    required AnimeInfo anime,
    required BangumiEpisode episode,
  }) async {
    final item = await findByAnime(anime);
    if (item == null) return null;
    final sameEpisode =
        item.episodeId == episode.id ||
        (item.episodeId == 0 && item.episodeSort == episode.sort) ||
        item.episodeSort == episode.sort;
    if (!sameEpisode) return null;
    if (item.lastPositionMs <= 0) return null;
    return item.lastPositionMs;
  }

  /// Upsert the anime's history entry.
  ///
  /// When [lastPositionMs] is null, the previous position is preserved if the
  /// entry still refers to the same episode; otherwise position resets to 0.
  /// Pass an explicit 0 when switching to a new episode.
  Future<void> addOrUpdate({
    required AnimeInfo anime,
    required BangumiEpisode currentEpisode,
    required List<BangumiEpisode> allEpisodes,
    int? lastPositionMs,
  }) {
    return _runSerialized(() async {
      final history = await _ensureCache();
      final key = buildKey(anime);
      final existingIdx = history.indexWhere((item) => item.key == key);
      final existing = existingIdx == -1 ? null : history[existingIdx];

      final sameEpisode =
          existing != null &&
          (existing.episodeId == currentEpisode.id ||
              existing.episodeSort == currentEpisode.sort);

      final resolvedPosition = lastPositionMs ??
          (sameEpisode ? existing.lastPositionMs : 0);

      if (existingIdx != -1) {
        history.removeAt(existingIdx);
      }

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
        lastPositionMs: resolvedPosition < 0 ? 0 : resolvedPosition,
      );

      history.insert(0, item);
      if (history.length > _maxItems) {
        history.removeRange(_maxItems, history.length);
      }

      await _persist(history);
    });
  }

  Future<void> remove(String key) {
    return _runSerialized(() async {
      final history = await _ensureCache();
      history.removeWhere((item) => item.key == key);
      await _persist(history);
    });
  }

  /// Update only the playback position for an existing history item.
  Future<void> updatePosition(String key, int positionMs) {
    return _runSerialized(() async {
      final history = await _ensureCache();
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
        lastPositionMs: positionMs < 0 ? 0 : positionMs,
      );

      history.removeAt(idx);
      history.insert(0, updated);
      await _persist(history);
    });
  }

  Future<void> clear() {
    return _runSerialized(() async {
      _cache = <PlaybackHistoryItem>[];
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    });
  }
}
