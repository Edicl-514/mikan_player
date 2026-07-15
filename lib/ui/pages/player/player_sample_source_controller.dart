import 'dart:collection';

import 'package:mikan_player/src/rust/api/generic_scraper.dart';

/// Phase 2 player-page responsibility split: the sample-source **search state**
/// object (Sub-commit B).
///
/// [PlayerSampleSourceController] deliberately owns **state mutations only**,
/// mirroring [PlayerSourceController] (`player_source_controller.dart`) and
/// [PlayerEpisodeController] (`player_episode_controller.dart`): pure Dart, no
/// `flutter/widgets.dart`, no `BuildContext`, no WebView / scheduler / captcha
/// / player / prefs, no async fetches. The loader method BODIES that perform
/// WebView pool pumping, captcha preflight, stream launch, BT stream probe,
/// prefs, `mounted` checks, and `setState` wrappers stay on the page
/// (`player_page.dart` `_loadSampleSource`, `_handleSearchProgressUpdate`,
/// `_maybeFinishSampleSearch`, `_addPlayableSource`, episode-switch reset).
/// This controller only receives the resolved inputs via mutators and exposes
/// read-only views; the page drives it through the mutator surface and reads
/// the views for the sample-source panel UI and scheduler input DTOs.
///
/// **Sibling of [PlayerSourceController] (not a merge):** sample state is
/// larger and scheduler-adjacent (enqueue seq, progress map, tier map). Keeping
/// a sibling boundary avoids bloating the Mikan+DMHY controller.
///
/// **Known asymmetries (preserve byte-for-byte):**
///   - [beginNewSearchReset] clears only controller-owned sample fields. The
///     page still clears scheduler / WebView / captcha / playable-key /
///     autoplay / status-notifier fields in the same `setState`
///     (`player_page.dart` `_loadSampleSource` big reset block).
///   - [resetForSwitching] mirrors the episode-change sample field clears
///     (`player_page.dart` `_onEpisodeSelected` sample block) and does NOT
///     touch page-owned WebView/scheduler state.
///   - [markSampleLoading] / [markSampleIdle] / [setSampleError] do NOT couple
///     loading and error: finish paths may set error while ending load, and
///     the auto-search-disabled early exit sets idle without an error message
///     on the controller (status string lives on the page notifier).
///   - [appendPlayPage] assigns a monotonic enqueue seq keyed by [pageKey]
///     (page builds the key via `SourceChannelKey`); subsequent
///     [sortPlayPagesByTier] reorders the list without rewriting enqueue seq.
///   - [addSuccessfulSource] is an unconditional append; duplicate policy
///     (`_playableSourceKeys` + `_containsPlayableSource`) stays on the page.
///
/// List / map views return a fresh [UnmodifiableListView] /
/// [UnmodifiableMapView] per call so a mutator that replaces the backing
/// collection cannot leak a view backed by the stale collection.
class PlayerSampleSourceController {
  PlayerSampleSourceController();

  bool _isLoadingSample = false;
  String? _sampleError;
  List<SearchPlayResult> _samplePlayPages = [];
  List<SearchPlayResult> _sampleSuccessfulSources = [];
  int _sampleLoadToken = 0;
  final Map<String, int> _pageEnqueueSeq = {};
  int _nextPageEnqueueSeq = 0;
  Map<String, SourceSearchProgress> _sourceProgressMap = {};
  List<String> _enabledSourceNames = [];
  Map<String, int> _sourceTiers = {};

  // ── Read-only views for the page ──────────────────────────────────────────

  bool get isLoadingSample => _isLoadingSample;

  String? get sampleError => _sampleError;

  /// Fresh [UnmodifiableListView] of discovered play pages.
  List<SearchPlayResult> get samplePlayPages =>
      UnmodifiableListView<SearchPlayResult>(_samplePlayPages);

  /// Fresh [UnmodifiableListView] of sources that successfully yielded a
  /// playable video URL (probe-accepted).
  List<SearchPlayResult> get sampleSuccessfulSources =>
      UnmodifiableListView<SearchPlayResult>(_sampleSuccessfulSources);

  int get sampleLoadToken => _sampleLoadToken;

  /// Fresh unmodifiable view of enabled source names for the current search.
  List<String> get enabledSourceNames =>
      UnmodifiableListView<String>(_enabledSourceNames);

  /// Fresh unmodifiable view of sourceName → tier for the current search.
  Map<String, int> get sourceTiers =>
      UnmodifiableMapView<String, int>(_sourceTiers);

  /// Fresh unmodifiable view of sourceName → search progress.
  Map<String, SourceSearchProgress> get sourceProgressMap =>
      UnmodifiableMapView<String, SourceSearchProgress>(_sourceProgressMap);

  /// Fresh unmodifiable view of pageKey → enqueue sequence number.
  Map<String, int> get pageEnqueueSeq =>
      UnmodifiableMapView<String, int>(_pageEnqueueSeq);

  int get nextPageEnqueueSeq => _nextPageEnqueueSeq;

  // ── Load token ────────────────────────────────────────────────────────────

  /// Increments the sample load token and returns the new value. Mirrors
  /// `player_page.dart` `_loadSampleSource` `final loadToken = ++_sampleLoadToken`.
  int bumpLoadToken() {
    _sampleLoadToken++;
    return _sampleLoadToken;
  }

  /// `true` iff [token] still matches the current load token (stale-async guard).
  bool isCurrentLoadToken(int token) => token == _sampleLoadToken;

  // ── Loading / error ───────────────────────────────────────────────────────

  /// Sets `isLoadingSample = true` and clears `sampleError`. Does NOT clear
  /// play pages / progress (use [beginNewSearchReset] for a full search start).
  void markSampleLoading() {
    _isLoadingSample = true;
    _sampleError = null;
  }

  /// Sets `isLoadingSample = false` without touching `sampleError`.
  void markSampleIdle() {
    _isLoadingSample = false;
  }

  /// Sets `sampleError = message`. Does NOT force idle unless the caller also
  /// calls [markSampleIdle] (finish / catch paths combine both).
  void setSampleError(String? message) {
    _sampleError = message;
  }

  /// Convenience: ends loading and records [message] (catch / empty-sources
  /// early exit). Mirrors `_sampleError = …; _isLoadingSample = false`.
  void setSampleErrorAndIdle(String? message) {
    _sampleError = message;
    _isLoadingSample = false;
  }

  // ── Search lifecycle ──────────────────────────────────────────────────────

  /// Clears controller-owned sample fields for a brand-new search, then marks
  /// loading. Does NOT touch page-owned WebView / scheduler / captcha /
  /// playable-key / autoplay / status-notifier state.
  ///
  /// Mirrors the controller-owned subset of `player_page.dart` `_loadSampleSource`
  /// big `setState` reset:
  ///   isLoadingSample=true, sampleError=null, samplePlayPages=[],
  ///   sampleSuccessfulSources=[], pageEnqueueSeq clear + next=0,
  ///   sourceProgressMap={}, enabledSourceNames=[], sourceTiers={}.
  void beginNewSearchReset() {
    _isLoadingSample = true;
    _sampleError = null;
    _samplePlayPages = [];
    _sampleSuccessfulSources = [];
    _pageEnqueueSeq.clear();
    _nextPageEnqueueSeq = 0;
    _sourceProgressMap = {};
    _enabledSourceNames = [];
    _sourceTiers = {};
  }

  /// Records the enabled source roster and tier map for the current search.
  /// Does NOT init progress entries — call [initPendingProgressForEnabled] or
  /// [setSourceProgress] separately (matches the page's two-step setState).
  void setEnabledSources({
    required List<String> names,
    required Map<String, int> tiers,
  }) {
    _enabledSourceNames = List<String>.from(names);
    _sourceTiers = Map<String, int>.from(tiers);
  }

  /// Initializes every enabled source name to [SearchStep.pending] progress.
  /// Mirrors the `_loadSampleSource` pending-init loop.
  void initPendingProgressForEnabled() {
    for (final name in _enabledSourceNames) {
      _sourceProgressMap[name] = SourceSearchProgress(
        sourceName: name,
        step: SearchStep.pending,
        error: null,
        playPageUrl: null,
        videoRegex: null,
        directVideoUrl: null,
        cookies: null,
        headers: null,
        enableNestedUrl: false,
      );
    }
  }

  /// Replaces (or inserts) progress for [sourceName].
  void setSourceProgress(String sourceName, SourceSearchProgress progress) {
    _sourceProgressMap[sourceName] = progress;
  }

  // ── Play pages ────────────────────────────────────────────────────────────

  /// Appends [page] and assigns a monotonic enqueue seq under [pageKey].
  /// Mirrors `_addSamplePlayPage` controller-owned half (warm-worker logging
  /// stays on the page).
  void appendPlayPage(SearchPlayResult page, {required String pageKey}) {
    _samplePlayPages.add(page);
    _pageEnqueueSeq[pageKey] = _nextPageEnqueueSeq++;
  }

  /// In-place replace at [index]. Used when a channel resolve updates an
  /// existing page entry.
  void replacePlayPageAt(int index, SearchPlayResult page) {
    _samplePlayPages[index] = page;
  }

  /// Sorts play pages by source tier ascending (missing tier → 999).
  /// Mirrors the three in-page `sort` sites after multi-channel / channel-resolve.
  void sortPlayPagesByTier() {
    _samplePlayPages.sort((a, b) {
      final tierA = _sourceTiers[a.sourceName] ?? 999;
      final tierB = _sourceTiers[b.sourceName] ?? 999;
      return tierA.compareTo(tierB);
    });
  }

  // ── Successful sources ────────────────────────────────────────────────────

  /// Unconditional append of a probe-accepted source. Duplicate guards
  /// (`_playableSourceKeys` / page-key equality) stay on the page.
  void addSuccessfulSource(SearchPlayResult source) {
    _sampleSuccessfulSources.add(source);
  }

  /// Whether any successful source matches [test].
  bool anySuccessfulSource(bool Function(SearchPlayResult) test) {
    return _sampleSuccessfulSources.any(test);
  }

  // ── Switch / dispose ──────────────────────────────────────────────────────

  /// Clears sample transient state on episode switch. Mirrors the sample-field
  /// subset of `player_page.dart` `_onEpisodeSelected` setState:
  ///   isLoadingSample=false, sampleError=null, play pages / successful empty,
  ///   enqueue reset, progress/enabled/tiers cleared.
  void resetForSwitching() {
    _isLoadingSample = false;
    _sampleError = null;
    _samplePlayPages = [];
    _sampleSuccessfulSources = [];
    _pageEnqueueSeq.clear();
    _nextPageEnqueueSeq = 0;
    _sourceProgressMap = {};
    _enabledSourceNames = [];
    _sourceTiers = {};
  }

  /// Disposes any owned resources. Currently a no-op (plain scalar / list /
  /// map fields only). Reserved for symmetry with sibling controllers.
  void clearForDispose() {
    // Intentionally empty — see doc comment.
  }

  // ── Invariants ────────────────────────────────────────────────────────────

  /// Light consistency checks. Returns human-readable violation messages
  /// (empty = consistent). Composition tests call this after mutations.
  ///
  /// Checks:
  ///   1. Every pageEnqueueSeq value is `>= 0` and `< nextPageEnqueueSeq`.
  ///   2. enabledSourceNames has no duplicate names.
  List<String> validateInvariants() {
    final errors = <String>[];

    for (final entry in _pageEnqueueSeq.entries) {
      if (entry.value < 0 || entry.value >= _nextPageEnqueueSeq) {
        errors.add(
          'pageEnqueueSeq[${entry.key}]=${entry.value} not in '
          '[0, nextPageEnqueueSeq=$_nextPageEnqueueSeq)',
        );
      }
    }

    final names = _enabledSourceNames;
    if (names.toSet().length != names.length) {
      errors.add('duplicate names in enabledSourceNames: $names');
    }

    return errors;
  }
}
