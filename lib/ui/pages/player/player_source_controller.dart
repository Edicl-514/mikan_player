import 'dart:collection';

import 'package:mikan_player/src/rust/api/dmhy.dart';
import 'package:mikan_player/src/rust/api/mikan.dart';

/// Phase 2 player-page responsibility split: the Mikan + DMHY source-loading
/// state object.
///
/// [PlayerSourceController] deliberately owns **state mutations only**,
/// mirroring the [PlayerEpisodeController] precedent
/// (`player_episode_controller.dart:7-64`): pure Dart, no
/// `flutter/widgets.dart`, no `BuildContext`, no WebView / player / prefs,
/// no async fetches. The loader method BODIES that perform the async fetches
/// stay on the page (`player_page.dart:991-1021` `_loadDmhySource`,
/// `:1023-1162` `_loadMikanSource`, `:3767-3795` `_reloadMikanResourcesForEpisode`):
/// those reach `widget.anime.*`, call `BangumiRequestModeService` /
/// `BangumiDataService.getMikanId` / `searchMikanAnime` / `getMikanResources`
/// / `fetchDmhyResources`, check `mounted`, and wrap the mutations in
/// `setState(() { ... })`. This controller only receives the resolved inputs
/// via mutators and exposes read-only views; the page drives it through the
/// mutator surface and reads the views for the source-panel UI state
/// (`player_page.dart:5368-5371` BT count, `:5517-5519` status,
/// `:6579-6585` BT list).
///
/// **Known asymmetries (preserve byte-for-byte):**
///   - [markMikanLoading] clears `mikanError` (`player_page.dart:1030-1034`)
///     while [markMikanReloadForEpisode] does NOT clear it
///     (`player_page.dart:3773-3776`): a previous error legitimately lingers
///     into the reload loading state. There is therefore NO invariant linking
///     `isLoadingMikan` and `mikanError` (see [validateInvariants]).
///   - [resetForSwitching] clears every transient field but does NOT clear
///     `mikanAnime` (`player_page.dart:4860-4867`): the anime binding survives
///     a source switch / episode change so `_reloadMikanResourcesForEpisode`
///     (`:3758`, `:4932`) can reuse it.
///   - [setMikanAnime] mutates `mikanAnime` but leaves `isLoadingMikan` as-is:
///     a successful anime resolve (`player_page.dart:1077-1080` fast path,
///     `:1126-1130` fallback) is followed by a separate `getMikanResources`
///     fetch whose result lands via [setMikanResources] / [markMikanIdle].
///
/// Consistent with [PlayerEpisodeController]'s read-view / mutator split, the
/// list views ([mikanResources], [dmhyResources]) return a fresh
/// [UnmodifiableListView] per call: subsequent [setMikanResources] /
/// [setDmhyResources] calls replace the backing list (they do not mutate in
/// place), so a caller that captured a snapshot view stays safe.

class PlayerSourceController {
  PlayerSourceController();

  bool _isLoadingMikan = false;
  String? _mikanError;
  MikanSearchResult? _mikanAnime;
  List<MikanEpisodeResource> _mikanResources = [];

  bool _isLoadingDmhy = false;
  String? _dmhyError;
  List<DmhyResource> _dmhyResources = [];

  // Each provider has its own monotonically increasing request token. A new
  // Mikan request must not cancel an in-flight DMHY request (and vice versa),
  // but an episode/anime switch invalidates both through
  // [invalidatePendingRequests]. The page owns the async work and checks the
  // relevant token after every await before it commits a result here.
  int _mikanRequestToken = 0;
  int _dmhyRequestToken = 0;

  // ── Read-only views for the page ──────────────────────────────────────────

  bool get isLoadingMikan => _isLoadingMikan;

  String? get mikanError => _mikanError;

  MikanSearchResult? get mikanAnime => _mikanAnime;

  /// Fresh [UnmodifiableListView] of the current Mikan resources. Mirrors the
  /// `playableEpisodes` precedent (`player_episode_controller.dart:133-134`):
  /// a fresh view per call so a [setMikanResources] that replaces the backing
  /// list cannot leak a view backed by the stale list.
  List<MikanEpisodeResource> get mikanResources =>
      UnmodifiableListView<MikanEpisodeResource>(_mikanResources);

  bool get isLoadingDmhy => _isLoadingDmhy;

  String? get dmhyError => _dmhyError;

  /// Fresh [UnmodifiableListView] of the current DMHY resources. Same
  /// snapshot semantics as [mikanResources].
  List<DmhyResource> get dmhyResources =>
      UnmodifiableListView<DmhyResource>(_dmhyResources);

  /// Convenience for the BT source-panel read sites that previously read
  /// `_isLoadingMikan || _isLoadingDmhy` (`player_page.dart:5517`, `:6584`).
  bool get isLoadingAny => isLoadingMikan || isLoadingDmhy;

  /// Convenience for the BT source-panel read sites that previously read
  /// `_mikanError != null || _dmhyError != null` (`player_page.dart:5518`,
  /// `:6585`).
  bool get hasErrorAny => mikanError != null || dmhyError != null;

  // ── Async request ownership ─────────────────────────────────────────────

  /// Starts a new Mikan source request and returns its ownership token.
  ///
  /// Callers must retain the returned token and only commit an asynchronous
  /// result while [isMikanRequestCurrent] remains true. Starting a newer
  /// Mikan request makes every earlier Mikan result stale without affecting
  /// an in-flight DMHY request.
  int beginMikanRequest() => ++_mikanRequestToken;

  /// Whether [token] still belongs to the latest Mikan request.
  bool isMikanRequestCurrent(int token) => token == _mikanRequestToken;

  /// Starts a new DMHY source request and returns its ownership token.
  ///
  /// This is intentionally independent of [beginMikanRequest], so the two
  /// providers can load in parallel.
  int beginDmhyRequest() => ++_dmhyRequestToken;

  /// Whether [token] still belongs to the latest DMHY request.
  bool isDmhyRequestCurrent(int token) => token == _dmhyRequestToken;

  /// Invalidates all in-flight provider requests without changing visible
  /// source state. Used as soon as the page's anime/episode context changes,
  /// including when the next source request is delayed by another async step.
  void invalidatePendingRequests() {
    _mikanRequestToken++;
    _dmhyRequestToken++;
  }

  // ── Mikan mutations ──────────────────────────────────────────────────────

  /// Marks the Mikan source as loading a fresh search. Sets `isLoadingMikan`
  /// true, clears `mikanError`, clears `mikanResources`. Does NOT touch
  /// `mikanAnime` (the anime binding is preserved across reloads — the
  /// reload paths [markMikanReloadForEpisode] / `_reloadMikanResourcesForEpisode`
  /// reuse it). Mirrors `player_page.dart:1030-1034`.
  void markMikanLoading() {
    _isLoadingMikan = true;
    _mikanError = null;
    _mikanResources = [];
  }

  /// Marks the Mikan source as reloading resources for an episode change.
  /// Sets `isLoadingMikan` true, clears `mikanResources`. Does NOT clear
  /// `mikanError`: **asymmetry** with [markMikanLoading] — a previous error
  /// legitimately lingers into the reload loading state
  /// (`player_page.dart:3773-3776`, which only assigns `_isLoadingMikan =
  /// true` and `_mikanResources = []`). Does NOT touch `mikanAnime`.
  void markMikanReloadForEpisode() {
    _isLoadingMikan = true;
    _mikanResources = [];
  }

  /// Records the resolved Mikan anime. Sets `mikanAnime = result` and leaves
  /// `isLoadingMikan` as-is: a successful anime resolve is followed by a
  /// separate `getMikanResources` fetch whose result lands via
  /// [setMikanResources] / [markMikanIdle]. Mirrors
  /// `player_page.dart:1077-1080` (fast path) and `:1126-1130` (fallback).
  void setMikanAnime(MikanSearchResult result) {
    _mikanAnime = result;
  }

  /// Records the fetched Mikan resources and ends the loading state. Sets
  /// `mikanResources = resources`, `isLoadingMikan = false`. Mirrors
  /// `player_page.dart:1091-1094` (fast path) and `:1142-1147` (fallback), as
  /// well as `:3784-3785` (`_reloadMikanResourcesForEpisode` success).
  void setMikanResources(List<MikanEpisodeResource> resources) {
    _mikanResources = resources;
    _isLoadingMikan = false;
  }

  /// Ends the Mikan loading state without recording any resources (the
  /// `episode.id == 0` no-resources-yet early-exit case). Sets
  /// `isLoadingMikan = false` only. Mirrors `player_page.dart:1098-1100`
  /// (fast path) and `:1149-1152` (fallback).
  void markMikanIdle() {
    _isLoadingMikan = false;
  }

  /// Records the Mikan not-found outcome. Sets `isLoadingMikan = false` and
  /// `mikanError` to the verbatim Chinese literals `"未找到番剧"`. Mirrors
  /// `player_page.dart:1113-1118` (fallback `searchMikanAnime` returned null).
  void setMikanNotFound() {
    _isLoadingMikan = false;
    _mikanError = "未找到番剧";
  }

  /// Records a Mikan error and ends the loading state. Sets `mikanError =
  /// message`, `isLoadingMikan = false`. Mirrors `player_page.dart:1158-1161`
  /// (`_loadMikanSource` catch) and `:3792-3793`
  /// (`_reloadMikanResourcesForEpisode` catch).
  void setMikanError(String message) {
    _mikanError = message;
    _isLoadingMikan = false;
  }

  // ── DMHY mutations ───────────────────────────────────────────────────────

  /// Marks the DMHY source as loading a fresh fetch. Sets `isLoadingDmhy`
  /// true, clears `dmhyError`, clears `dmhyResources`. Mirrors
  /// `player_page.dart:994-997`.
  void markDmhyLoading() {
    _isLoadingDmhy = true;
    _dmhyError = null;
    _dmhyResources = [];
  }

  /// Records the fetched DMHY resources and ends the loading state. Sets
  /// `dmhyResources = resources`, `isLoadingDmhy = false`. Mirrors
  /// `player_page.dart:1007-1010`.
  void setDmhyResources(List<DmhyResource> resources) {
    _dmhyResources = resources;
    _isLoadingDmhy = false;
  }

  /// Records a DMHY error and ends the loading state. Sets `dmhyError =
  /// message`, `isLoadingDmhy = false`. Mirrors `player_page.dart:1015-1018`.
  void setDmhyError(String message) {
    _dmhyError = message;
    _isLoadingDmhy = false;
  }

  // ── Switch reset ──────────────────────────────────────────────────────────

  /// Resets all transient source state for an episode / source switch. Sets
  /// `isLoadingMikan = false`, `mikanError = null`, `mikanResources = []`,
  /// `isLoadingDmhy = false`, `dmhyError = null`, `dmhyResources = []`.
  /// **Asymmetry:** does NOT clear `mikanAnime` (`player_page.dart:4860-4867`):
  /// the anime binding survives a source switch so
  /// `_reloadMikanResourcesForEpisode` (`:3758`, `:4932`) can reuse it.
  void resetForSwitching() {
    invalidatePendingRequests();

    _isLoadingMikan = false;
    _mikanError = null;
    _mikanResources = [];

    _isLoadingDmhy = false;
    _dmhyError = null;
    _dmhyResources = [];
  }

  // ── Dispose hook ──────────────────────────────────────────────────────────

  /// Invalidates in-flight requests during page disposal. Unlike
  /// [PlayerEpisodeController.clearForDispose] this controller owns no
  /// disposable notifier, but invalidating tokens makes late completions
  /// unambiguously stale before the page's `mounted` guard rejects them.
  void clearForDispose() {
    invalidatePendingRequests();
  }

  // ── Invariants ──────────────────────────────────────────────────────────

  /// Validates the controller's internal invariants. Returns a list of
  /// human-readable violation messages; an empty list means the controller is
  /// in a consistent state. Composition tests call this after each mutation
  /// to catch any drift early — mirroring [PlayerEpisodeController]'s
  /// `validateInvariants` hook.
  ///
  /// Unlike [PlayerEpisodeController.validateInvariants] (which anchors the
  /// notifier / slot / list triple), the source state has NO inter-field
  /// invariants: `isLoadingMikan` and `mikanError` are deliberately
  /// decoupled (see [markMikanReloadForEpisode]'s preserve-error asymmetry),
  /// `mikanAnime` may independently be null or set across loading / idle /
  /// error / not-found, and the resource lists are non-nullable by
  /// construction (the type system already enforces this). This method
  /// therefore returns an empty list and keeps the hook only for symmetry
  /// and future-proofing. Tests still call it after each mutation to assert
  /// it stays empty.
  List<String> validateInvariants() {
    return <String>[];
  }
}
