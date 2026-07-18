import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/playback_history_episode_resolver.dart';
import 'package:mikan_player/services/playback_history_manager.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

BangumiEpisode _episode(int id) {
  return BangumiEpisode(
    id: id,
    name: 'EP$id',
    nameCn: 'EP$id',
    description: '',
    airdate: '',
    duration: '',
    sort: id.toDouble(),
  );
}

PlaybackHistoryItem _historyItem({
  String? bangumiId = '123',
  List<BangumiEpisode> episodes = const [],
}) {
  return PlaybackHistoryItem(
    key: 'bgm:${bangumiId ?? 'none'}',
    title: 'Test Anime',
    subTitle: null,
    bangumiId: bangumiId,
    mikanId: null,
    coverUrl: null,
    siteUrl: null,
    broadcastDay: null,
    broadcastTime: null,
    score: null,
    rank: null,
    tags: const [],
    fullJson: null,
    episodeId: episodes.isEmpty ? 0 : episodes.first.id,
    episodeSort: episodes.isEmpty ? 0 : episodes.first.sort,
    episodeName: episodes.isEmpty ? '' : episodes.first.name,
    episodeNameCn: episodes.isEmpty ? '' : episodes.first.nameCn,
    episodesJson: jsonEncode(
      episodes
          .map(
            (episode) => {
              'id': episode.id,
              'name': episode.name,
              'nameCn': episode.nameCn,
              'description': episode.description,
              'airdate': episode.airdate,
              'duration': episode.duration,
              'sort': episode.sort,
            },
          )
          .toList(),
    ),
    updatedAt: 0,
    lastPositionMs: 0,
  );
}

void main() {
  test(
    'prefers refreshed episodes over a non-empty history snapshot',
    () async {
      final snapshot = [_episode(1), _episode(2), _episode(3)];
      final refreshed = List.generate(12, (index) => _episode(index + 1));

      final result = await resolvePlaybackHistoryEpisodes(
        _historyItem(episodes: snapshot),
        loadEpisodes: (subjectId) async {
          expect(subjectId, 123);
          return refreshed;
        },
      );

      expect(result, hasLength(12));
      expect(result.last.id, 12);
    },
  );

  test('falls back to the history snapshot when refresh fails', () async {
    final snapshot = [_episode(1), _episode(2), _episode(3)];

    final result = await resolvePlaybackHistoryEpisodes(
      _historyItem(episodes: snapshot),
      loadEpisodes: (_) => Future.error(Exception('offline')),
    );

    expect(result.map((episode) => episode.id), [1, 2, 3]);
  });

  test(
    'falls back to the history snapshot when refresh returns empty',
    () async {
      final snapshot = [_episode(1), _episode(2), _episode(3)];

      final result = await resolvePlaybackHistoryEpisodes(
        _historyItem(episodes: snapshot),
        loadEpisodes: (_) async => [],
      );

      expect(result.map((episode) => episode.id), [1, 2, 3]);
    },
  );

  test('does not refresh history items without a valid Bangumi id', () async {
    final snapshot = [_episode(1)];
    var loaderCalled = false;

    final result = await resolvePlaybackHistoryEpisodes(
      _historyItem(bangumiId: null, episodes: snapshot),
      loadEpisodes: (_) async {
        loaderCalled = true;
        return [_episode(2)];
      },
    );

    expect(loaderCalled, isFalse);
    expect(result.single.id, 1);
  });
}
