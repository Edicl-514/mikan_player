import 'dart:async';
import 'dart:collection';

import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/utils/source_channel_key.dart';

enum PlayerPlaybackErrorKind { raw, openFailed, startupTimeout }

class PlayerPlaybackError {
  const PlayerPlaybackError._(this.kind, this.detail);

  const PlayerPlaybackError.raw(String detail)
    : this._(PlayerPlaybackErrorKind.raw, detail);

  const PlayerPlaybackError.openFailed(String detail)
    : this._(PlayerPlaybackErrorKind.openFailed, detail);

  const PlayerPlaybackError.startupTimeout()
    : this._(PlayerPlaybackErrorKind.startupTimeout, null);

  final PlayerPlaybackErrorKind kind;
  final String? detail;
}

/// Injectable wall clock used only to expose a watchdog deadline to the page
/// and to deterministic tests. Playback correctness never relies on a clock
/// comparison; the timer is the authority that fires the timeout.
typedef PlayerPlaybackClock = DateTime Function();

/// Injectable one-shot timer factory. Keeping this as a function instead of a
/// media-kit or Flutter abstraction lets the controller stay pure Dart while
/// tests drive watchdog callbacks synchronously.
typedef PlayerPlaybackTimerFactory =
    Timer Function(Duration delay, void Function() callback);

/// Registers a URL with the host's header-injection mechanism and returns the
/// URL which should actually be handed to the media player.
typedef PlayerPlaybackProxyUrlBuilder =
    String Function(String originalUrl, Map<String, String> headers);

/// Minimal player operations needed by [PlayerPlaybackController].
///
/// The page adapts its `media_kit.Player` to these callbacks. Keeping the
/// media player out of this file makes watchdog, fallback, and stale-completion
/// behavior unit-testable without a platform player.
class PlayerPlaybackOpenCallbacks {
  const PlayerPlaybackOpenCallbacks({
    required this.stopPlayer,
    required this.openUrl,
    required this.hasPlaybackStarted,
    this.applyPlaybackSpeed,
    this.applyPendingStartPosition,
    this.onStateChanged,
    this.onFallbackRequested,
  });

  /// Stops the currently active media before opening the next URL.
  final Future<void> Function() stopPlayer;

  /// Opens [url] with playback enabled.
  ///
  /// The adapter must provide *last-issued-open wins* semantics. The
  /// controller can make an old completion stale and suppress its state/post-
  /// open callbacks, but it cannot cancel a media command that was already
  /// submitted to a platform player. The production adapter delegates calls in
  /// their issuance order; alternative players must serialize or supersede
  /// older opens themselves. The production adapter passes calls through in
  /// issuance order; the required manual smoke gate validates the platform
  /// player's last-write behavior under a timeout→fallback race.
  final Future<void> Function(String url) openUrl;

  /// Whether the latest opened media has emitted enough state to count as
  /// started. The controller ignores this signal until its own current
  /// [openUrl] Future has completed, so a pre-open event from an older medium
  /// cannot clear a newly scheduled watchdog.
  final bool Function() hasPlaybackStarted;

  /// Applies the page-owned playback-rate preference after a media open. It
  /// stays a callback because preferences and media-kit belong to the page,
  /// while attempt ordering belongs to this controller.
  final Future<void> Function()? applyPlaybackSpeed;

  /// Applies the page-owned resume position after a media open.
  final Future<void> Function()? applyPendingStartPosition;

  /// Called after controller-owned visible playback state changes. The page
  /// bridges this to `setState` and its source-label notifier; the controller
  /// deliberately does not import Flutter just to notify a widget tree.
  final void Function()? onStateChanged;

  /// Called only after this controller has released its auto-play fallback
  /// latch. The host normally asks [selectAutoPlayCandidate] for a replacement
  /// and starts the returned source.
  final void Function(PlayerPlaybackFallbackRequest request)?
  onFallbackRequested;
}

/// Immutable description of the URL and headers selected for an online source.
///
/// [playbackUrl] is either [directVideoUrl] or the output of the injected
/// proxy builder. [headers] is a defensive, unmodifiable snapshot, so a caller
/// cannot mutate controller-owned planning data or the source's original map.
class PlayerPlaybackUrlPlan {
  PlayerPlaybackUrlPlan._({
    required this.source,
    required this.sourceKey,
    required this.directVideoUrl,
    required this.playbackUrl,
    required Map<String, String> headers,
    required this.usesHeaderProxy,
  }) : headers = UnmodifiableMapView<String, String>(
         Map<String, String>.from(headers),
       );

  final SearchPlayResult source;
  final String sourceKey;
  final String directVideoUrl;
  final String playbackUrl;
  final Map<String, String> headers;
  final bool usesHeaderProxy;
}

/// Why the controller asked the page to try another auto-play source.
enum PlayerPlaybackFallbackReason { startupTimeout, openError }

/// Immutable fallback callback payload.
class PlayerPlaybackFallbackRequest {
  const PlayerPlaybackFallbackRequest({
    required this.source,
    required this.sourceKey,
    required this.attemptId,
    required this.loadToken,
    required this.reason,
    this.error,
  });

  final SearchPlayResult source;
  final String sourceKey;
  final int attemptId;
  final int loadToken;
  final PlayerPlaybackFallbackReason reason;
  final Object? error;
}

/// Reasons no source was reserved by [selectAutoPlayCandidate].
enum PlayerPlaybackAutoPlayBlockReason {
  alreadyPlaying,
  fallbackInProgress,
  noTierZeroCandidate,
}

/// Result of one auto-play candidate selection pass.
///
/// A successful decision reserves the fallback latch immediately. Pass
/// [reservationId] to [openOnlineSource] so the asynchronous open owns that
/// reservation; call [cancelAutoPlayReservation] if the host elects not to
/// open the selected source.
class PlayerPlaybackAutoPlayDecision {
  const PlayerPlaybackAutoPlayDecision._candidate({
    required this.source,
    required this.sourceKey,
    required this.selectedSourceIndex,
    required this.reservationId,
  }) : blockReason = null;

  const PlayerPlaybackAutoPlayDecision._blocked(this.blockReason)
    : source = null,
      sourceKey = null,
      selectedSourceIndex = null,
      reservationId = null;

  final SearchPlayResult? source;
  final String? sourceKey;
  final int? selectedSourceIndex;
  final int? reservationId;
  final PlayerPlaybackAutoPlayBlockReason? blockReason;

  bool get hasCandidate => source != null;
}

/// Terminal outcome of [openOnlineSource].
enum PlayerPlaybackOpenStatus { opened, stale, rejected, failed }

/// Immutable result returned when an online-open Future completes.
class PlayerPlaybackOpenResult {
  const PlayerPlaybackOpenResult({
    required this.status,
    required this.attemptId,
    required this.plan,
    this.error,
  });

  final PlayerPlaybackOpenStatus status;
  final int? attemptId;
  final PlayerPlaybackUrlPlan? plan;
  final Object? error;
}

/// Phase 2 player-page responsibility split: online playback state and
/// watchdog/fallback control.
///
/// This controller deliberately has no Flutter, Widget, BuildContext, or
/// media-kit dependency. The page remains responsible for `setState`, player
/// construction, applying speed/resume position, proxy lifecycle, download/BT
/// side effects, and UI notifier publication. It supplies tiny callbacks only
/// when [openOnlineSource] needs to stop/open a player or request a fallback.
///
/// The controller owns the state which previously travelled together through
/// online playback paths: selected/current source, raw and proxy stream URLs,
/// loading/error/label values, auto-play latch, failed keys, selected index,
/// URL/header planning, and a startup watchdog. Every asynchronous callback is
/// guarded by both a monotonic attempt id and the caller-owned sample load
/// token, so an old timer or old player Future cannot overwrite a newer play.
class PlayerPlaybackController {
  PlayerPlaybackController({
    PlayerPlaybackClock? clock,
    PlayerPlaybackTimerFactory? timerFactory,
    this.startupTimeout = const Duration(seconds: 10),
  }) : _clock = clock ?? DateTime.now,
       _timerFactory = timerFactory ?? _defaultTimerFactory;

  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Set<String> _refererRequiredDomainFragments = <String>{
    'vbing.me',
    'libvio',
    'v.cdnlz',
  };

  static Timer _defaultTimerFactory(Duration delay, void Function() callback) =>
      Timer(delay, callback);

  final PlayerPlaybackClock _clock;
  final PlayerPlaybackTimerFactory _timerFactory;

  /// Kept configurable for deterministic focused tests. Production keeps the
  /// historic ten-second timeout.
  final Duration startupTimeout;

  SearchPlayResult? _currentOnlineSource;
  String? _currentStreamUrl;
  String? _sampleVideoUrl;
  bool _isLoadingVideo = false;
  PlayerPlaybackError? _videoError;
  // i18n-ignore: protocol sentinel for empty source state; UI maps via displayPlayerSourceLabel
  String _playingSourceLabel = '未播放';
  bool _hasAutoPlayed = false;
  int _selectedSourceIndex = 0;
  final Set<String> _failedPlaybackSourceKeys = <String>{};

  int _nextAttemptId = 0;
  int? _activeAttemptId;
  bool _activeAttemptOpenCompleted = false;
  bool _disposed = false;

  Timer? _startupWatchdogTimer;
  int? _watchdogAttemptId;
  String? _pendingPlaySourceKey;
  DateTime? _watchdogDeadline;

  int _nextAutoPlayReservationId = 0;
  int? _autoPlayReservationId;
  int? _autoPlayReservationAttemptId;
  bool? _autoPlayReservationPreviousHasAutoPlayed;

  // ── Read-only state ───────────────────────────────────────────────────────

  SearchPlayResult? get currentOnlineSource => _currentOnlineSource;
  String? get currentStreamUrl => _currentStreamUrl;
  String? get sampleVideoUrl => _sampleVideoUrl;
  bool get isLoadingVideo => _isLoadingVideo;
  PlayerPlaybackError? get videoError => _videoError;
  String get playingSourceLabel => _playingSourceLabel;
  bool get hasAutoPlayed => _hasAutoPlayed;
  int get selectedSourceIndex => _selectedSourceIndex;
  int? get activeAttemptId => _activeAttemptId;
  String? get pendingPlaySourceKey => _pendingPlaySourceKey;
  DateTime? get watchdogDeadline => _watchdogDeadline;
  bool get isAutoPlayFallbackInProgress => _autoPlayReservationId != null;

  /// A fresh unmodifiable view. Failed keys are controller-owned because they
  /// participate in fallback selection and must not be mutated by the page.
  Set<String> get failedPlaybackSourceKeys =>
      UnmodifiableSetView<String>(_failedPlaybackSourceKeys);

  // ── URL/header planning ───────────────────────────────────────────────────

  /// Builds the browser-context headers historically used for online playback
  /// and downloading. It never mutates [source.headers].
  ///
  /// Always supplies a fallback UA and, when missing, the play-page Referer.
  /// Download jobs additionally walk a header-strategy fallback chain (see
  /// `http_header_strategies.dart`) so CDNs that ACL-deny a foreign Referer
  /// still succeed without a host denylist.
  static Map<String, String> buildPlaybackHeaders(SearchPlayResult source) {
    final headers = <String, String>{
      if (source.headers != null) ...source.headers!,
    };
    final hasUserAgent = headers.entries.any(
      (entry) =>
          (entry.key.trim().toLowerCase() == 'user-agent' ||
              entry.key.trim().toLowerCase() == 'useragent') &&
          entry.value.trim().isNotEmpty,
    );
    if (!hasUserAgent) {
      headers['User-Agent'] = defaultUserAgent;
    }
    final hasReferer = headers.entries.any(
      (entry) =>
          entry.key.trim().toLowerCase() == 'referer' &&
          entry.value.trim().isNotEmpty,
    );
    if (!hasReferer) {
      headers['Referer'] = source.playPageUrl;
    }
    return headers;
  }

  /// Browser-context headers used by the URL probe. This intentionally keeps
  /// the page's historic case-sensitive `putIfAbsent('User-Agent', ...)`
  /// behavior: a lower-case `user-agent` does not suppress the added canonical
  /// header, while Referer/referer are both stripped.
  static Map<String, String> buildProbeHeaders(SearchPlayResult source) {
    final headers = <String, String>{
      if (source.headers != null) ...source.headers!,
    };
    final url = source.directVideoUrl ?? source.playPageUrl;
    if (!needsRefererHeader(url)) {
      headers.remove('Referer');
      headers.remove('referer');
    } else if (!headers.containsKey('Referer') &&
        !headers.containsKey('referer')) {
      final referer = buildPlaybackHeaders(source)['Referer'];
      if (referer != null) {
        headers['Referer'] = referer;
      }
    }
    headers.putIfAbsent('User-Agent', () => defaultUserAgent);
    return headers;
  }

  /// Mirrors the page's intentionally small, substring-based referer policy.
  static bool needsRefererHeader(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return _refererRequiredDomainFragments.any(host.contains);
  }

  /// Uses the same source/channel namespace as the scheduler and page.
  static String sourceKeyOf(SearchPlayResult source) => SourceChannelKey(
    sourceName: source.sourceName,
    channelIndex: source.channelIndex,
  ).toPageKey();

  /// Returns `null` when [source] has no direct video URL. Otherwise creates a
  /// pure plan, invoking [proxyUrlBuilder] only for a referer-required host.
  PlayerPlaybackUrlPlan? planPlaybackUrl(
    SearchPlayResult source, {
    PlayerPlaybackProxyUrlBuilder? proxyUrlBuilder,
  }) {
    final directVideoUrl = source.directVideoUrl;
    if (directVideoUrl == null || directVideoUrl.isEmpty) return null;

    final headers = buildPlaybackHeaders(source);
    final usesHeaderProxy = needsRefererHeader(directVideoUrl);
    final playbackUrl = usesHeaderProxy && proxyUrlBuilder != null
        ? proxyUrlBuilder(directVideoUrl, Map<String, String>.from(headers))
        : directVideoUrl;
    return PlayerPlaybackUrlPlan._(
      source: source,
      sourceKey: sourceKeyOf(source),
      directVideoUrl: directVideoUrl,
      playbackUrl: playbackUrl,
      headers: headers,
      usesHeaderProxy: usesHeaderProxy,
    );
  }

  // ── Selection and non-online state ────────────────────────────────────────

  /// Mirrors the page's source-list tap: select a playable source and expose
  /// its raw URL/short label, but do not open a player or change stream URL.
  bool selectSource(int index, SearchPlayResult source) {
    final directVideoUrl = source.directVideoUrl;
    if (_disposed ||
        index < 0 ||
        directVideoUrl == null ||
        directVideoUrl.isEmpty) {
      return false;
    }
    _selectedSourceIndex = index;
    _sampleVideoUrl = directVideoUrl;
    _playingSourceLabel = source.sourceName;
    return true;
  }

  /// Sets selection to [source]'s current list position, or `0` if it is no
  /// longer present. This is the old `_playSource` display-index repair, moved
  /// here with the rest of playback selection state.
  void selectSourceOrZero(
    Iterable<SearchPlayResult> sources,
    SearchPlayResult source,
  ) {
    if (_disposed) return;
    final index = sources.toList(growable: false).indexOf(source);
    _selectedSourceIndex = index == -1 ? 0 : index;
  }

  /// Clamps the selected list index after a source-list update (empty → 0).
  void clampSelectedSourceIndex(int sourceCount) {
    if (_disposed) return;
    if (sourceCount <= 0) {
      _selectedSourceIndex = 0;
      return;
    }
    _selectedSourceIndex = _selectedSourceIndex.clamp(0, sourceCount - 1);
  }

  /// Records an already-open local/BT stream. This intentionally invalidates
  /// any pending online attempt so an old online Future cannot reclaim the
  /// player-facing state after local playback wins.
  void markLocalPlayback(
    String streamUrl, {
    required String label,
    bool clearCurrentOnlineSource = true,
  }) {
    if (_disposed) return;
    _invalidateActiveAttempt();
    _currentStreamUrl = streamUrl;
    _sampleVideoUrl = streamUrl;
    if (clearCurrentOnlineSource) {
      _currentOnlineSource = null;
    }
    _hasAutoPlayed = true;
    _isLoadingVideo = false;
    _videoError = null;
    _playingSourceLabel = label;
  }

  /// Page-owned BT/download paths use these narrow setters while retaining
  /// their existing player and DownloadManager side effects. Keeping the
  /// fields private prevents any second owner from mutating raw state.
  void setVideoError(String? error) {
    if (_disposed) return;
    _videoError = error == null ? null : PlayerPlaybackError.raw(error);
  }

  void setLoadingVideo(bool value) {
    if (_disposed) return;
    _isLoadingVideo = value;
  }

  void setCurrentStreamUrl(String? url) {
    if (_disposed) return;
    _currentStreamUrl = url;
  }

  void setPlayingSourceLabel(String label) {
    if (_disposed) return;
    _playingSourceLabel = label;
  }

  /// Explicitly records a failed key (for example, a page-owned probe failure)
  /// so future auto-play selection skips it.
  void recordFailedPlaybackSourceKey(String sourceKey) {
    if (_disposed) return;
    _failedPlaybackSourceKeys.add(sourceKey);
  }

  bool isPlaybackSourceFailed(String sourceKey) =>
      _failedPlaybackSourceKeys.contains(sourceKey);

  // ── Auto-play selection ───────────────────────────────────────────────────

  /// Selects the first historic Tier-0 candidate in caller order and reserves
  /// the fallback latch atomically. Missing tiers are `999`; failed and
  /// [excludedSourceKey] candidates are skipped.
  ///
  /// `forceRetry` deliberately bypasses the "already playing" guard but not
  /// the re-entrancy latch, matching the page's watchdog/error retry policy.
  PlayerPlaybackAutoPlayDecision selectAutoPlayCandidate(
    Iterable<SearchPlayResult> sources, {
    required Map<String, int> sourceTiers,
    String? excludedSourceKey,
    bool forceRetry = false,
  }) {
    if (_disposed) {
      return const PlayerPlaybackAutoPlayDecision._blocked(
        PlayerPlaybackAutoPlayBlockReason.noTierZeroCandidate,
      );
    }
    if (!forceRetry &&
        (_hasAutoPlayed ||
            _sampleVideoUrl != null ||
            _currentStreamUrl != null)) {
      return const PlayerPlaybackAutoPlayDecision._blocked(
        PlayerPlaybackAutoPlayBlockReason.alreadyPlaying,
      );
    }
    if (isAutoPlayFallbackInProgress) {
      return const PlayerPlaybackAutoPlayDecision._blocked(
        PlayerPlaybackAutoPlayBlockReason.fallbackInProgress,
      );
    }

    final candidates = sources.toList(growable: false);
    for (var index = 0; index < candidates.length; index++) {
      final source = candidates[index];
      final sourceKey = sourceKeyOf(source);
      if ((sourceTiers[source.sourceName] ?? 999) != 0 ||
          source.directVideoUrl == null ||
          source.directVideoUrl!.isEmpty ||
          sourceKey == excludedSourceKey ||
          _failedPlaybackSourceKeys.contains(sourceKey)) {
        continue;
      }

      final previousHasAutoPlayed = _hasAutoPlayed;
      _hasAutoPlayed = true;
      _selectedSourceIndex = index;
      final reservationId = ++_nextAutoPlayReservationId;
      _autoPlayReservationId = reservationId;
      _autoPlayReservationAttemptId = null;
      _autoPlayReservationPreviousHasAutoPlayed = previousHasAutoPlayed;
      return PlayerPlaybackAutoPlayDecision._candidate(
        source: source,
        sourceKey: sourceKey,
        selectedSourceIndex: index,
        reservationId: reservationId,
      );
    }

    return const PlayerPlaybackAutoPlayDecision._blocked(
      PlayerPlaybackAutoPlayBlockReason.noTierZeroCandidate,
    );
  }

  /// Releases a reservation made by [selectAutoPlayCandidate] when the host
  /// decides not to start that candidate after all.
  void cancelAutoPlayReservation(int reservationId) {
    _releaseAutoPlayFallbackLatch(
      reservationId: reservationId,
      rollbackUnstartedReservation: true,
    );
  }

  /// Clears only the watchdog in response to the page's player position/playing
  /// stream. The active attempt remains current; a later new attempt or reset
  /// will invalidate it.
  bool notifyPlaybackStarted() {
    final attemptId = _activeAttemptId;
    if (attemptId == null || !_activeAttemptOpenCompleted) return false;
    return _clearStartupWatchdogForAttempt(attemptId);
  }

  // ── Online open + watchdog ────────────────────────────────────────────────

  /// Stops the injected player, schedules a startup watchdog, then opens the
  /// planned online URL. [isLoadTokenCurrent] is intentionally caller-owned:
  /// `PlayerSampleSourceController` remains the canonical search-generation
  /// owner, while this controller adds a narrower playback-attempt guard.
  ///
  /// A stale timer/completion returns [PlayerPlaybackOpenStatus.stale] and does
  /// not mutate the newer attempt's state. On timeout/open error the controller
  /// releases its fallback latch *before* [PlayerPlaybackOpenCallbacks]
  /// receives a fallback callback, preventing the old latch from blocking the
  /// replacement source.
  Future<PlayerPlaybackOpenResult> openOnlineSource(
    SearchPlayResult source, {
    required bool autoFallback,
    required int loadToken,
    required bool Function(int token) isLoadTokenCurrent,
    required PlayerPlaybackOpenCallbacks callbacks,
    PlayerPlaybackProxyUrlBuilder? proxyUrlBuilder,
    int? autoPlayReservationId,
  }) async {
    if (_disposed) {
      return PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.rejected,
        attemptId: null,
        plan: null,
      );
    }
    if (!isLoadTokenCurrent(loadToken)) {
      if (autoPlayReservationId != null) {
        cancelAutoPlayReservation(autoPlayReservationId);
      }
      return PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.stale,
        attemptId: null,
        plan: null,
      );
    }
    if (autoFallback &&
        _autoPlayReservationId != null &&
        autoPlayReservationId != _autoPlayReservationId) {
      // A caller that carries an old reservation must never replace a newer
      // candidate's latch. This is possible when a page callback arrives after
      // timeout fallback has already reserved its replacement.
      return const PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.stale,
        attemptId: null,
        plan: null,
      );
    }

    final plan = planPlaybackUrl(source, proxyUrlBuilder: proxyUrlBuilder);
    if (plan == null) {
      if (autoPlayReservationId != null) {
        cancelAutoPlayReservation(autoPlayReservationId);
      }
      return PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.rejected,
        attemptId: null,
        plan: null,
      );
    }

    final reservationId = _beginAutoPlayReservation(
      autoFallback: autoFallback,
      requestedReservationId: autoPlayReservationId,
    );
    _invalidateActiveAttempt();
    final attemptId = ++_nextAttemptId;
    _activeAttemptId = attemptId;
    _activeAttemptOpenCompleted = false;
    if (reservationId != null) {
      _autoPlayReservationAttemptId = attemptId;
    }

    _currentOnlineSource = source;
    _currentStreamUrl = plan.playbackUrl;
    _sampleVideoUrl = plan.directVideoUrl;
    _playingSourceLabel = source.channelName != null
        ? '${source.sourceName}(${source.channelName})'
        : source.sourceName;
    _isLoadingVideo = true;
    _videoError = null;
    callbacks.onStateChanged?.call();

    try {
      await callbacks.stopPlayer();
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent)) {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        return _staleOpenResult(attemptId, plan);
      }

      _scheduleStartupWatchdog(
        attemptId: attemptId,
        loadToken: loadToken,
        source: source,
        plan: plan,
        autoFallback: autoFallback,
        isLoadTokenCurrent: isLoadTokenCurrent,
        callbacks: callbacks,
      );

      await callbacks.openUrl(plan.playbackUrl);
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent)) {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        return _staleOpenResult(attemptId, plan);
      }
      _activeAttemptOpenCompleted = true;
      if (callbacks.hasPlaybackStarted()) {
        _clearStartupWatchdogForAttempt(attemptId);
      }

      await callbacks.applyPlaybackSpeed?.call();
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent)) {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        return _staleOpenResult(attemptId, plan);
      }

      // Preserve the existing page behavior: a successful `open` ends the
      // loading overlay but leaves the watchdog armed until position/playing
      // proves startup actually happened.
      _isLoadingVideo = false;
      callbacks.onStateChanged?.call();

      await callbacks.applyPendingStartPosition?.call();
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent)) {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        return _staleOpenResult(attemptId, plan);
      }

      _releaseAutoPlayFallbackLatch(attemptId: attemptId);
      return PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.opened,
        attemptId: attemptId,
        plan: plan,
      );
    } catch (error) {
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent)) {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        return _staleOpenResult(attemptId, plan);
      }

      _clearStartupWatchdogForAttempt(attemptId);
      _failedPlaybackSourceKeys.add(plan.sourceKey);
      _isLoadingVideo = false;
      _videoError = PlayerPlaybackError.openFailed('$error');
      _activeAttemptId = null;
      _activeAttemptOpenCompleted = false;
      callbacks.onStateChanged?.call();

      if (autoFallback) {
        // This ordering is deliberate. The historic page called back while the
        // latch was still true, so `_attemptAutoPlay` immediately returned.
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        callbacks.onFallbackRequested?.call(
          PlayerPlaybackFallbackRequest(
            source: source,
            sourceKey: plan.sourceKey,
            attemptId: attemptId,
            loadToken: loadToken,
            reason: PlayerPlaybackFallbackReason.openError,
            error: error,
          ),
        );
      } else {
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
      }

      return PlayerPlaybackOpenResult(
        status: PlayerPlaybackOpenStatus.failed,
        attemptId: attemptId,
        plan: plan,
        error: error,
      );
    }
  }

  void _scheduleStartupWatchdog({
    required int attemptId,
    required int loadToken,
    required SearchPlayResult source,
    required PlayerPlaybackUrlPlan plan,
    required bool autoFallback,
    required bool Function(int token) isLoadTokenCurrent,
    required PlayerPlaybackOpenCallbacks callbacks,
  }) {
    _clearStartupWatchdog();
    _watchdogAttemptId = attemptId;
    _pendingPlaySourceKey = plan.sourceKey;
    _watchdogDeadline = _clock().add(startupTimeout);
    _startupWatchdogTimer = _timerFactory(startupTimeout, () {
      if (!_isAttemptCurrent(attemptId, loadToken, isLoadTokenCurrent) ||
          _watchdogAttemptId != attemptId ||
          _pendingPlaySourceKey != plan.sourceKey) {
        return;
      }

      if (_activeAttemptOpenCompleted && callbacks.hasPlaybackStarted()) {
        _clearStartupWatchdogForAttempt(attemptId);
        return;
      }

      _clearStartupWatchdogForAttempt(attemptId);
      _failedPlaybackSourceKeys.add(plan.sourceKey);
      // Invalidate before invoking the host. If the old `openUrl` Future later
      // completes, it must return stale instead of updating this state.
      _activeAttemptId = null;
      _activeAttemptOpenCompleted = false;

      _isLoadingVideo = false;
      _videoError = const PlayerPlaybackError.startupTimeout();
      callbacks.onStateChanged?.call();

      if (autoFallback) {
        // Release first so the callback may synchronously reserve/open a
        // replacement source without hitting the re-entrancy latch.
        _releaseAutoPlayFallbackLatch(attemptId: attemptId);
        callbacks.onFallbackRequested?.call(
          PlayerPlaybackFallbackRequest(
            source: source,
            sourceKey: plan.sourceKey,
            attemptId: attemptId,
            loadToken: loadToken,
            reason: PlayerPlaybackFallbackReason.startupTimeout,
          ),
        );
        return;
      }

      _releaseAutoPlayFallbackLatch(attemptId: attemptId);
    });
  }

  bool _isAttemptCurrent(
    int attemptId,
    int loadToken,
    bool Function(int token) isLoadTokenCurrent,
  ) =>
      !_disposed &&
      _activeAttemptId == attemptId &&
      isLoadTokenCurrent(loadToken);

  PlayerPlaybackOpenResult _staleOpenResult(
    int attemptId,
    PlayerPlaybackUrlPlan plan,
  ) => PlayerPlaybackOpenResult(
    status: PlayerPlaybackOpenStatus.stale,
    attemptId: attemptId,
    plan: plan,
  );

  int? _beginAutoPlayReservation({
    required bool autoFallback,
    required int? requestedReservationId,
  }) {
    if (!autoFallback) {
      _releaseAutoPlayFallbackLatch();
      return null;
    }

    final requestedIsCurrent =
        requestedReservationId != null &&
        requestedReservationId == _autoPlayReservationId;
    if (requestedIsCurrent) return requestedReservationId;

    final reservationId = ++_nextAutoPlayReservationId;
    _autoPlayReservationId = reservationId;
    _autoPlayReservationAttemptId = null;
    _autoPlayReservationPreviousHasAutoPlayed = _hasAutoPlayed;
    _hasAutoPlayed = true;
    return reservationId;
  }

  void _invalidateActiveAttempt() {
    final activeAttemptId = _activeAttemptId;
    if (activeAttemptId != null) {
      _clearStartupWatchdogForAttempt(activeAttemptId);
      _releaseAutoPlayFallbackLatch(attemptId: activeAttemptId);
    }
    _activeAttemptId = null;
    _activeAttemptOpenCompleted = false;
  }

  bool _clearStartupWatchdogForAttempt(int attemptId) {
    if (_watchdogAttemptId != attemptId) return false;
    _clearStartupWatchdog();
    return true;
  }

  void _clearStartupWatchdog() {
    _startupWatchdogTimer?.cancel();
    _startupWatchdogTimer = null;
    _watchdogAttemptId = null;
    _pendingPlaySourceKey = null;
    _watchdogDeadline = null;
  }

  void _releaseAutoPlayFallbackLatch({
    int? reservationId,
    int? attemptId,
    bool rollbackUnstartedReservation = false,
  }) {
    if (reservationId != null && _autoPlayReservationId != reservationId) {
      return;
    }
    if (attemptId != null && _autoPlayReservationAttemptId != attemptId) {
      return;
    }
    final wasUnstartedReservation = _autoPlayReservationAttemptId == null;
    final previousHasAutoPlayed = _autoPlayReservationPreviousHasAutoPlayed;
    _autoPlayReservationId = null;
    _autoPlayReservationAttemptId = null;
    _autoPlayReservationPreviousHasAutoPlayed = null;
    if (rollbackUnstartedReservation &&
        wasUnstartedReservation &&
        previousHasAutoPlayed != null) {
      _hasAutoPlayed = previousHasAutoPlayed;
    }
  }

  // ── Reset / dispose ───────────────────────────────────────────────────────

  /// Mirrors a new online-source search: invalidate old playback work, clear
  /// retry bookkeeping and selection, but preserve an already-playing local/BT
  /// stream and its visible URL.
  void resetForNewSearch() {
    if (_disposed) return;
    _invalidateActiveAttempt();
    _clearStartupWatchdog();
    _releaseAutoPlayFallbackLatch();
    _failedPlaybackSourceKeys.clear();
    _selectedSourceIndex = 0;
    _hasAutoPlayed = false;
  }

  /// Mirrors an episode switch: in addition to [resetForNewSearch], clear all
  /// visible playback state. The label is configurable because the existing
  /// page uses `Switching...` during its reset fan-out.
  void resetForSwitching({String label = 'Switching...'}) {
    if (_disposed) return;
    resetForNewSearch();
    _currentOnlineSource = null;
    _currentStreamUrl = null;
    _sampleVideoUrl = null;
    _isLoadingVideo = false;
    _videoError = null;
    _playingSourceLabel = label;
  }

  /// Cancels the only owned resource (the watchdog) and makes every pending
  /// timer/Future stale. State is intentionally retained for page disposal
  /// ordering, e.g. a host may still inspect [currentStreamUrl] to deactivate a
  /// BT stream before releasing its player.
  void clearForDispose() {
    if (_disposed) return;
    _disposed = true;
    _clearStartupWatchdog();
    _activeAttemptId = null;
    _activeAttemptOpenCompleted = false;
    _releaseAutoPlayFallbackLatch();
  }

  // ── Invariants ────────────────────────────────────────────────────────────

  /// Returns human-readable consistency failures; empty means consistent.
  /// Focused composition tests call this after meaningful state transitions.
  List<String> validateInvariants() {
    final errors = <String>[];
    final watchdogFields = <bool>[
      _startupWatchdogTimer != null,
      _watchdogAttemptId != null,
      _pendingPlaySourceKey != null,
      _watchdogDeadline != null,
    ];
    if (watchdogFields.any((value) => value) &&
        watchdogFields.any((value) => !value)) {
      errors.add(
        'watchdog timer/attempt/key/deadline must be all set or all null: '
        '$watchdogFields',
      );
    }
    if (_autoPlayReservationAttemptId != null &&
        _autoPlayReservationId == null) {
      errors.add(
        'auto-play reservation attempt exists without a reservation id',
      );
    }
    if (_autoPlayReservationId == null &&
        _autoPlayReservationPreviousHasAutoPlayed != null) {
      errors.add('auto-play previous state exists without a reservation id');
    }
    if (_selectedSourceIndex < 0) {
      errors.add('selectedSourceIndex=$_selectedSourceIndex is negative');
    }
    if (_activeAttemptId == null && _activeAttemptOpenCompleted) {
      errors.add('open-completed flag exists without an active attempt');
    }
    return errors;
  }
}
