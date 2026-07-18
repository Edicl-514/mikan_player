import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_playback_controller.dart';

void main() {
  group('PlayerPlaybackController URL and selection planning', () {
    test('builds playback/probe headers without mutating source headers', () {
      final controller = PlayerPlaybackController();
      final source = _source(
        directUrl: 'https://cdn.example/video.m3u8',
        headers: <String, String>{
          'useragent': 'source-agent',
          'referer': 'https://source.example/watch',
          'X-Keep': 'yes',
        },
      );

      final playbackHeaders = PlayerPlaybackController.buildPlaybackHeaders(
        source,
      );
      final probeHeaders = PlayerPlaybackController.buildProbeHeaders(source);

      // Playback/download base headers keep the captured Referer; download
      // jobs walk a strategy fallback chain when a CDN ACL-denies it.
      expect(playbackHeaders, <String, String>{
        'useragent': 'source-agent',
        'referer': 'https://source.example/watch',
        'X-Keep': 'yes',
      });
      expect(probeHeaders['useragent'], 'source-agent');
      expect(
        probeHeaders['User-Agent'],
        PlayerPlaybackController.defaultUserAgent,
      );
      expect(probeHeaders, isNot(contains('referer')));
      expect(source.headers, <String, String>{
        'useragent': 'source-agent',
        'referer': 'https://source.example/watch',
        'X-Keep': 'yes',
      });

      var proxyCalls = 0;
      final directPlan = controller.planPlaybackUrl(
        source,
        proxyUrlBuilder: (_, _) {
          proxyCalls++;
          return 'unexpected';
        },
      );
      expect(directPlan, isNotNull);
      expect(directPlan!.usesHeaderProxy, isFalse);
      expect(directPlan.playbackUrl, source.directVideoUrl);
      expect(proxyCalls, 0);

      final proxied = controller.planPlaybackUrl(
        _source(directUrl: 'https://vbing.me/media.m3u8'),
        proxyUrlBuilder: (url, headers) {
          proxyCalls++;
          expect(headers['Referer'], 'https://play.example/watch');
          return 'http://127.0.0.1/proxy?url=$url';
        },
      );
      expect(proxied!.usesHeaderProxy, isTrue);
      expect(proxied.playbackUrl, contains('127.0.0.1/proxy'));
      expect(proxyCalls, 1);
    });

    test(
      'injects play-page Referer when missing; keeps captured Referer otherwise',
      () {
        final missing = PlayerPlaybackController.buildPlaybackHeaders(
          _source(
            directUrl: 'https://cdn.example/video.mp4',
            headers: const <String, String>{},
          ),
        );
        expect(missing['Referer'], 'https://play.example/watch');
        expect(
          missing['User-Agent'],
          PlayerPlaybackController.defaultUserAgent,
        );

        final captured = PlayerPlaybackController.buildPlaybackHeaders(
          _source(
            directUrl: 'https://v6.douyinvod.com/path/video.mp4?filename=1.mp4',
            headers: const <String, String>{
              'Referer': 'https://play.example/watch',
              'Origin': 'https://play.example',
            },
          ),
        );
        // Base headers keep Referer; download-side strategy fallback strips
        // it after a 403 without needing a host denylist.
        expect(captured['Referer'], 'https://play.example/watch');
        expect(captured['Origin'], 'https://play.example');
        expect(
          captured['User-Agent'],
          PlayerPlaybackController.defaultUserAgent,
        );
      },
    );

    test('selects only Tier-0 candidates and owns selected source index', () {
      final controller = PlayerPlaybackController();
      final tierOne = _source(name: 'tier-one', channel: 0, directUrl: 'u1');
      final failed = _source(name: 'failed', channel: 1, directUrl: 'u2');
      final playable = _source(name: 'playable', channel: 2, directUrl: 'u3');
      controller.recordFailedPlaybackSourceKey(
        PlayerPlaybackController.sourceKeyOf(failed),
      );

      final decision = controller.selectAutoPlayCandidate(
        <SearchPlayResult>[tierOne, failed, playable],
        sourceTiers: const <String, int>{
          'tier-one': 1,
          'failed': 0,
          'playable': 0,
        },
      );

      expect(decision.hasCandidate, isTrue);
      expect(decision.source, playable);
      expect(decision.selectedSourceIndex, 2);
      expect(controller.selectedSourceIndex, 2);
      expect(controller.isAutoPlayFallbackInProgress, isTrue);
      controller.cancelAutoPlayReservation(decision.reservationId!);
      controller.clampSelectedSourceIndex(1);
      expect(controller.selectedSourceIndex, 0);
      expect(controller.validateInvariants(), isEmpty);
    });

    test(
      'cancelled reservation restores eligibility and skips URL-less source',
      () {
        final controller = PlayerPlaybackController();
        final withoutUrl = _source(name: 'empty', channel: 0, directUrl: null);
        final playable = _source(name: 'playable', channel: 1, directUrl: 'u');

        final first = controller.selectAutoPlayCandidate(
          <SearchPlayResult>[withoutUrl, playable],
          sourceTiers: const <String, int>{'empty': 0, 'playable': 0},
        );
        expect(first.source, playable);
        expect(first.selectedSourceIndex, 1);
        expect(controller.hasAutoPlayed, isTrue);

        controller.cancelAutoPlayReservation(first.reservationId!);

        expect(controller.hasAutoPlayed, isFalse);
        expect(controller.isAutoPlayFallbackInProgress, isFalse);
        final retry = controller.selectAutoPlayCandidate(
          <SearchPlayResult>[withoutUrl, playable],
          sourceTiers: const <String, int>{'empty': 0, 'playable': 0},
        );
        expect(retry.source, playable);
        expect(controller.validateInvariants(), isEmpty);
      },
    );

    test('old reservation cannot overwrite a newer candidate latch', () async {
      final controller = PlayerPlaybackController();
      final player = _FakePlayer();
      final a = _source(name: 'a', channel: 0, directUrl: 'https://a');
      final b = _source(name: 'b', channel: 1, directUrl: 'https://b');
      final old = controller.selectAutoPlayCandidate(
        <SearchPlayResult>[a],
        sourceTiers: const <String, int>{'a': 0},
      );
      controller.resetForNewSearch();
      final current = controller.selectAutoPlayCandidate(
        <SearchPlayResult>[b],
        sourceTiers: const <String, int>{'b': 0},
      );

      final stale = await controller.openOnlineSource(
        a,
        autoFallback: true,
        autoPlayReservationId: old.reservationId,
        loadToken: 1,
        isLoadTokenCurrent: (_) => true,
        callbacks: _callbacks(player),
      );

      expect(stale.status, PlayerPlaybackOpenStatus.stale);
      expect(controller.isAutoPlayFallbackInProgress, isTrue);
      expect(controller.currentOnlineSource, isNull);
      expect(player.openCalls, isEmpty);
      controller.cancelAutoPlayReservation(current.reservationId!);
      expect(controller.validateInvariants(), isEmpty);
    });
  });

  group('PlayerPlaybackController watchdog and fallback', () {
    test(
      'manual startup timeout records terminal error without fallback',
      () async {
        final time = _FakeTime();
        final player = _FakePlayer();
        final fallbacks = <PlayerPlaybackFallbackRequest>[];
        final controller = PlayerPlaybackController(
          clock: time.now,
          timerFactory: time.createTimer,
        );
        final source = _source(name: 'manual', directUrl: 'https://a/video');

        final open = controller.openOnlineSource(
          source,
          autoFallback: false,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player, onFallback: fallbacks.add),
        );
        await _flush();
        expect(player.openCalls, <String>['https://a/video']);
        expect(
          controller.watchdogDeadline,
          time.now().add(const Duration(seconds: 10)),
        );

        time.fireLast();

        expect(controller.isLoadingVideo, isFalse);
        expect(
          controller.videoError?.kind,
          PlayerPlaybackErrorKind.startupTimeout,
        );
        expect(
          controller.failedPlaybackSourceKeys,
          contains(PlayerPlaybackController.sourceKeyOf(source)),
        );
        expect(fallbacks, isEmpty);
        expect(controller.validateInvariants(), isEmpty);

        player.completeOpen('https://a/video');
        expect((await open).status, PlayerPlaybackOpenStatus.stale);
        expect(
          controller.videoError?.kind,
          PlayerPlaybackErrorKind.startupTimeout,
        );
      },
    );

    test(
      'does not let a pre-open player event clear the current watchdog',
      () async {
        final time = _FakeTime();
        final player = _FakePlayer();
        final controller = PlayerPlaybackController(
          clock: time.now,
          timerFactory: time.createTimer,
        );
        final source = _source(name: 'pending', directUrl: 'https://pending');

        final open = controller.openOnlineSource(
          source,
          autoFallback: false,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player),
        );
        await _flush();
        expect(controller.notifyPlaybackStarted(), isFalse);
        expect(controller.pendingPlaySourceKey, isNotNull);

        player.completeOpen('https://pending');
        await open;
        player.hasStarted = true;
        expect(controller.notifyPlaybackStarted(), isTrue);
        expect(controller.pendingPlaySourceKey, isNull);
      },
    );

    test('auto timeout releases latch before requesting fallback', () async {
      final time = _FakeTime();
      final player = _FakePlayer();
      final fallbacks = <PlayerPlaybackFallbackRequest>[];
      final controller = PlayerPlaybackController(
        clock: time.now,
        timerFactory: time.createTimer,
      );
      final source = _source(name: 'a', directUrl: 'https://a/video');

      unawaited(
        controller.openOnlineSource(
          source,
          autoFallback: true,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player, onFallback: fallbacks.add),
        ),
      );
      await _flush();
      expect(controller.isAutoPlayFallbackInProgress, isTrue);

      time.fireLast();

      expect(fallbacks, hasLength(1));
      expect(
        fallbacks.single.reason,
        PlayerPlaybackFallbackReason.startupTimeout,
      );
      expect(controller.isAutoPlayFallbackInProgress, isFalse);
      expect(controller.isLoadingVideo, isFalse);
      expect(
        controller.videoError?.kind,
        PlayerPlaybackErrorKind.startupTimeout,
      );
    });

    test('auto open error releases latch before requesting fallback', () async {
      final time = _FakeTime();
      final player = _FakePlayer(failOpenFor: <String>{'https://a/video'});
      final fallbacks = <PlayerPlaybackFallbackRequest>[];
      final controller = PlayerPlaybackController(
        clock: time.now,
        timerFactory: time.createTimer,
      );
      final source = _source(name: 'a', directUrl: 'https://a/video');

      final result = await controller.openOnlineSource(
        source,
        autoFallback: true,
        loadToken: 1,
        isLoadTokenCurrent: (_) => true,
        callbacks: _callbacks(player, onFallback: fallbacks.add),
      );

      expect(result.status, PlayerPlaybackOpenStatus.failed);
      expect(fallbacks, hasLength(1));
      expect(fallbacks.single.reason, PlayerPlaybackFallbackReason.openError);
      expect(controller.isAutoPlayFallbackInProgress, isFalse);
      expect(controller.videoError?.kind, PlayerPlaybackErrorKind.openFailed);
      expect(
        controller.videoError?.detail,
        'Bad state: failed: https://a/video',
      );
    });

    test(
      'a stale first completion cannot release or overwrite replacement',
      () async {
        final time = _FakeTime();
        final player = _FakePlayer();
        final controller = PlayerPlaybackController(
          clock: time.now,
          timerFactory: time.createTimer,
        );
        final a = _source(name: 'a', directUrl: 'https://a/video');
        final b = _source(name: 'b', directUrl: 'https://b/video');
        Future<PlayerPlaybackOpenResult>? bOpen;

        late final PlayerPlaybackOpenCallbacks callbacks;
        callbacks = _callbacks(
          player,
          onFallback: (request) {
            final decision = controller.selectAutoPlayCandidate(
              <SearchPlayResult>[a, b],
              sourceTiers: const <String, int>{'a': 0, 'b': 0},
              excludedSourceKey: request.sourceKey,
              forceRetry: true,
            );
            bOpen = controller.openOnlineSource(
              decision.source!,
              autoFallback: true,
              autoPlayReservationId: decision.reservationId,
              loadToken: request.loadToken,
              isLoadTokenCurrent: (_) => true,
              callbacks: callbacks,
            );
          },
        );

        final aOpen = controller.openOnlineSource(
          a,
          autoFallback: true,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: callbacks,
        );
        await _flush();
        time.fireLast();
        await _flush();

        expect(player.openCalls, <String>[
          'https://a/video',
          'https://b/video',
        ]);
        expect(player.activeUrl, 'https://b/video');
        expect(controller.currentOnlineSource, b);
        expect(controller.isAutoPlayFallbackInProgress, isTrue);

        player.completeOpen('https://a/video');
        expect((await aOpen).status, PlayerPlaybackOpenStatus.stale);
        expect(player.activeUrl, 'https://b/video');
        expect(controller.currentOnlineSource, b);
        expect(controller.isAutoPlayFallbackInProgress, isTrue);

        player.completeOpen('https://b/video');
        expect((await bOpen!).status, PlayerPlaybackOpenStatus.opened);
        expect(controller.isAutoPlayFallbackInProgress, isFalse);
        expect(controller.currentOnlineSource, b);
      },
    );

    test('old cancelled watchdog cannot affect same-key replacement', () async {
      final time = _FakeTime();
      final player = _FakePlayer();
      final fallbacks = <PlayerPlaybackFallbackRequest>[];
      final controller = PlayerPlaybackController(
        clock: time.now,
        timerFactory: time.createTimer,
      );
      final source = _source(name: 'same', directUrl: 'https://same/video');

      unawaited(
        controller.openOnlineSource(
          source,
          autoFallback: true,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player, onFallback: fallbacks.add),
        ),
      );
      await _flush();
      final oldTimer = time.lastTimer;

      controller.resetForNewSearch();
      unawaited(
        controller.openOnlineSource(
          source,
          autoFallback: true,
          loadToken: 2,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player, onFallback: fallbacks.add),
        ),
      );
      await _flush();
      expect(controller.isAutoPlayFallbackInProgress, isTrue);

      oldTimer.fire(evenIfCancelled: true);

      expect(fallbacks, isEmpty);
      expect(
        controller.pendingPlaySourceKey,
        PlayerPlaybackController.sourceKeyOf(source),
      );
      expect(controller.isAutoPlayFallbackInProgress, isTrue);
    });

    test(
      'switch reset makes late stop completion stale with no watchdog',
      () async {
        final time = _FakeTime();
        final player = _FakePlayer(blockStop: true);
        final fallbacks = <PlayerPlaybackFallbackRequest>[];
        final controller = PlayerPlaybackController(
          clock: time.now,
          timerFactory: time.createTimer,
        );
        final source = _source(name: 'a', directUrl: 'https://a/video');

        final open = controller.openOnlineSource(
          source,
          autoFallback: true,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(player, onFallback: fallbacks.add),
        );
        await _flush();
        controller.resetForSwitching();
        player.completeStop();

        expect((await open).status, PlayerPlaybackOpenStatus.stale);
        expect(controller.currentStreamUrl, isNull);
        expect(controller.pendingPlaySourceKey, isNull);
        expect(fallbacks, isEmpty);
        expect(player.openCalls, isEmpty);
      },
    );

    test(
      'preserves stop-open-speed-position order for a current attempt',
      () async {
        final time = _FakeTime();
        final player = _FakePlayer(completeOpenImmediately: true);
        final calls = <String>[];
        final controller = PlayerPlaybackController(
          clock: time.now,
          timerFactory: time.createTimer,
        );

        final result = await controller.openOnlineSource(
          _source(name: 'ordered', directUrl: 'https://ordered/video'),
          autoFallback: false,
          loadToken: 1,
          isLoadTokenCurrent: (_) => true,
          callbacks: _callbacks(
            player,
            applySpeed: () async => calls.add('speed'),
            applyPosition: () async => calls.add('position'),
          ),
        );

        expect(result.status, PlayerPlaybackOpenStatus.opened);
        expect(player.callLog, <String>['stop', 'open:https://ordered/video']);
        expect(calls, <String>['speed', 'position']);
        expect(controller.isLoadingVideo, isFalse);
      },
    );
  });
}

SearchPlayResult _source({
  String name = 'source',
  int channel = 0,
  String? directUrl = 'https://play.example/video.m3u8',
  Map<String, String>? headers,
}) => SearchPlayResult(
  sourceName: name,
  playPageUrl: 'https://play.example/watch',
  videoRegex: 'regex',
  directVideoUrl: directUrl,
  headers: headers,
  channelIndex: BigInt.from(channel),
  enableNestedUrl: false,
);

PlayerPlaybackOpenCallbacks _callbacks(
  _FakePlayer player, {
  void Function(PlayerPlaybackFallbackRequest request)? onFallback,
  Future<void> Function()? applySpeed,
  Future<void> Function()? applyPosition,
}) => PlayerPlaybackOpenCallbacks(
  stopPlayer: player.stop,
  openUrl: player.open,
  hasPlaybackStarted: () => player.hasStarted,
  applyPlaybackSpeed: applySpeed,
  applyPendingStartPosition: applyPosition,
  onFallbackRequested: onFallback,
);

Future<void> _flush() async {
  await Future<void>.value();
  await Future<void>.value();
  await Future<void>.value();
}

class _FakeTime {
  DateTime _now = DateTime.utc(2026, 7, 15, 12);
  final List<_FakeTimer> timers = <_FakeTimer>[];

  DateTime now() => _now;

  Timer createTimer(Duration delay, void Function() callback) {
    final timer = _FakeTimer(delay, callback);
    timers.add(timer);
    return timer;
  }

  _FakeTimer get lastTimer => timers.last;

  void fireLast() {
    _now = _now.add(lastTimer.delay);
    lastTimer.fire();
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 1;

  @override
  void cancel() {
    _active = false;
  }

  void fire({bool evenIfCancelled = false}) {
    if (!_active && !evenIfCancelled) return;
    _active = false;
    _callback();
  }
}

class _FakePlayer {
  _FakePlayer({
    Set<String>? failOpenFor,
    this.completeOpenImmediately = false,
    this.blockStop = false,
  }) : _failOpenFor = failOpenFor ?? <String>{};

  final Set<String> _failOpenFor;
  final bool completeOpenImmediately;
  final bool blockStop;
  final List<String> callLog = <String>[];
  final List<String> openCalls = <String>[];
  final Map<String, Completer<void>> _openCompleters =
      <String, Completer<void>>{};
  Completer<void>? _stopCompleter;
  bool hasStarted = false;
  String? activeUrl;

  Future<void> stop() {
    callLog.add('stop');
    if (!blockStop) return Future<void>.value();
    return (_stopCompleter ??= Completer<void>()).future;
  }

  Future<void> open(String url) {
    callLog.add('open:$url');
    openCalls.add(url);
    activeUrl = url;
    if (_failOpenFor.contains(url)) {
      return Future<void>.error(StateError('failed: $url'));
    }
    if (completeOpenImmediately) return Future<void>.value();
    return (_openCompleters[url] ??= Completer<void>()).future;
  }

  void completeOpen(String url) {
    _openCompleters[url]!.complete();
  }

  void completeStop() {
    _stopCompleter!.complete();
  }
}
