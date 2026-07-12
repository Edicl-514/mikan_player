import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/models/bangumi_episode_filter.dart';
import 'package:mikan_player/src/rust/api/bangumi.dart';

/// Phase 2 player-page responsibility split: the episode-list / current-episode
/// state object.
///
/// [PlayerEpisodeController] deliberately owns **state mutations only**, mirroring
/// the [PlayerWebViewScheduler] precedent (`player_webview_scheduler.dart:10-34`).
/// It does NOT perform the side-effect fan-out that follows an episode change
/// (player stop / `_searchSubscriptions` cancel / the big `setState` resetting
/// ~30 playback+source fields / history save / danmaku clear+reload / comments
/// reload / BT-existing-download probe / `_loadMikanSource` / `_loadDmhySource` /
/// `_loadSampleSource`). Those stay on the page, which drives this controller
/// through [selectEpisode] / [resolveByOffset] / [reset] and reads the
/// read-only views ([playableEpisodes], [currentEpisode],
/// [currentEpisodeListenable], [currentEpisodeIndex], [currentEpisodeNumbers]).
///
/// Consistent with [PlayerWebViewScheduler]'s deliberately-no-side-effect stance,
/// the skip-next/previous family is split: [resolveByOffset] answers
/// "where would we go?" *without mutating*, while [selectEpisode] performs the
/// mutation. The page chooses the orchestration order so the side-effect fan-out
/// (player stop, search cancel, setState, history, danmaku, sources) can run in
/// its original sequence: the historic `_onSkipNext` (`player_page.dart:4819-4824`)
/// is rewritten to `resolveByOffset(1) -> _onEpisodeSelected(next)`, so the
/// side-effect body runs once, through the single `_onEpisodeSelected` entry
/// point — never twice.
///
/// **Known divergence (intentional, fixed in a later commit):** the controls
/// widget (`CustomVideoControls` / `EpisodeSidePanel`) keeps its own richer
/// `_resolvedCurrentEpisodeIndex` (`video_player_controls.dart:118-135`:
/// id→sort→indexOf fallback in the **full** `allEpisodes`) and resolves its own
/// `_onSkipPrevious` / `_onSkipNext` (`video_player_controls.dart:779-792`) /
/// panel highlight. That math is NOT unified here: this controller works in the
/// released-only working list via plain `indexOf`, matching the historical
/// `_onSkipNext`. Unifying the two index resolutions is a separate
/// behavior-change commit, NOT this behavior-preserving extraction. Do NOT
/// touch `video_player_controls.dart` in this checkpoint.
///
/// The page also keeps:
///   - `widget.allEpisodes` (the *parent*-supplied full list — passed into
///     [currentEpisodeNumbersAgainst] whenever the danmaku / source loaders
///     need a *relative* episode number; this controller stores its own
///     snapshot at construction but does not re-read the page's `widget`).
///   - `didUpdateWidget`'s episode-prop branching — unchanged beyond the
///     mechanical `_currentEpisode -> _episodeController.currentEpisode` rename.
///     The page does NOT call [reset] here: in-place episode prop changes flow
///     through `_handleWidgetEpisodeChanged` (re-runs source loaders without
///     mutating `_currentEpisode`).
///   - every side-effect method (`_checkAndPlayExistingBtDownload`,
///     `_savePlaybackHistory`, `_loadDanmaku` / `_loadComments` /
///     `_loadMikanSource` / `_loadDmhySource` / `_loadSampleSource` /
///     `_reloadMikanResourcesForEpisode`, `_handleWidgetEpisodeChanged`) —
///     byte-for-byte equivalent, only the `_currentEpisode` reads become
///     `_episodeController.currentEpisode`.
///
/// Pure Dart. Import surface: `dart:collection` (`UnmodifiableListView`),
/// `package:flutter/foundation.dart` ([ValueListenable] / [ValueNotifier]),
/// the `BangumiEpisode` model, and the `releasedEpisodes()` /
/// `latestReleasedEpisode()` / `isReleased()` extensions. NO
/// `flutter/widgets.dart`, NO `BuildContext`, NO `WidgetTester`, NO WebView /
/// player / prefs. Unit-testable in pure Dart.

/// Immutable result of a selection attempt. Mirrors the precedent of
/// [PlayerWebViewSchedulerAcquire] (`player_webview_scheduler.dart:48-58`): the
/// controller mutates only when `changed == true` and reports the previous/new
/// episode so the page can carry out its preservation / UI / source-reload side
/// effects without the controller orchestrating anything.
class EpisodeSelectionResult {
  const EpisodeSelectionResult({
    required this.previous,
    required this.next,
    required this.changed,
  });

  /// The episode the controller held before this call. Equal to [next] when
  /// [changed] is `false`.
  final BangumiEpisode previous;

  /// The episode the controller holds now. Equal to [previous] when [changed]
  /// is `false`.
  final BangumiEpisode next;

  /// `true` iff the controller mutated its current-episode slot and bumped
  /// [PlayerEpisodeController.currentEpisodeListenable] during this call.
  final bool changed;
}

/// Relative-vs-absolute episode-number pair for the page's danmaku/source
/// loaders. Mirrors the math at `player_page.dart:757-760`:
///   - [absolute] = `_episodeController.currentEpisode.sort.toInt()`
///   - [relative] = (1-based index of the current episode by `id` in the
///     supplied `allEpisodes` list) when found, else [absolute].
/// The two-argument [PlayerEpisodeController.currentEpisodeNumbersAgainst]
/// variant lets the page pass a *fresh* `widget.allEpisodes` snapshot (it may
/// differ from the list handed to the controller at construction, e.g. after a
/// parent rebuild).
class EpisodeNumbers {
  const EpisodeNumbers({required this.absolute, required this.relative});

  final int absolute;
  final int relative;
}

class PlayerEpisodeController {
  PlayerEpisodeController({
    required List<BangumiEpisode> allEpisodes,
    required BangumiEpisode initialEpisode,
  }) : _allEpisodes = allEpisodes,
       _originalInitialEpisode = initialEpisode {
    _playableEpisodes = _allEpisodes.releasedEpisodes();
    _currentEpisode = initialEpisode.isReleased()
        ? initialEpisode
        : (_playableEpisodes.latestReleasedEpisode() ?? initialEpisode);
    _currentEpisodeNotifier = ValueNotifier<BangumiEpisode>(_currentEpisode);
  }

  List<BangumiEpisode> _allEpisodes;
  late List<BangumiEpisode> _playableEpisodes;
  late BangumiEpisode _currentEpisode;
  final BangumiEpisode _originalInitialEpisode;
  late final ValueNotifier<BangumiEpisode> _currentEpisodeNotifier;

  // ── Read-only views for the page ──────────────────────────────────────────

  /// Unmodifiable view of the released-only working list
  /// (`_allEpisodes.releasedEpisodes()` at construction or the most recent
  /// [reset] call that supplied `newAllEpisodes`). A fresh [UnmodifiableListView]
  /// is returned per call so a [reset] that replaces `_playableEpisodes` cannot
  /// leak a view backed by the stale list.
  List<BangumiEpisode> get playableEpisodes =>
      UnmodifiableListView<BangumiEpisode>(_playableEpisodes);

  BangumiEpisode get currentEpisode => _currentEpisode;

  ValueListenable<BangumiEpisode> get currentEpisodeListenable =>
      _currentEpisodeNotifier;

  /// Index of [currentEpisode] in [playableEpisodes] using `List.indexOf`
  /// (the `BangumiEpisode.==` value-equality the type overrides). `-1` when
  /// not contained. Mirrors the page's `player_page.dart:4086` / `:4820`
  /// `indexOf` math.
  int get currentEpisodeIndex => _playableEpisodes.indexOf(_currentEpisode);

  int get episodesCount => _playableEpisodes.length;

  /// [EpisodeNumbers] computed against the `_allEpisodes` snapshot passed at
  /// construction (or the most recent [reset] that supplied `newAllEpisodes`).
  EpisodeNumbers get currentEpisodeNumbers =>
      _episodeNumbersAgainst(_allEpisodes);

  /// [EpisodeNumbers] computed against a *fresh* `allEpisodes` snapshot. The
  /// page always has `widget.allEpisodes` at hand and may pass it here even
  /// when it differs from the controller's own `_allEpisodes` (e.g. after a
  /// parent rebuild or a future `reset(newAllEpisodes: ...)`). This method does
  /// NOT cache: it recomputes from [allEpisodes] every call.
  EpisodeNumbers currentEpisodeNumbersAgainst(
    List<BangumiEpisode> allEpisodes,
  ) => _episodeNumbersAgainst(allEpisodes);

  EpisodeNumbers _episodeNumbersAgainst(List<BangumiEpisode> allEpisodes) {
    final absolute = _currentEpisode.sort.toInt();
    final epIndex = allEpisodes.indexWhere((e) => e.id == _currentEpisode.id);
    final relative = epIndex != -1 ? epIndex + 1 : absolute;
    return EpisodeNumbers(absolute: absolute, relative: relative);
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Attempts to set the current episode to [ep].
  ///
  /// Guard byte-for-byte with `player_page.dart:4827`:
  ///   `if (!ep.isReleased() || ep.id == _currentEpisode.id) return no-op;`
  /// On a guarded no-op, returns `{previous: currentEpisode, next:
  /// currentEpisode, changed: false}` and does NOT bump
  /// [currentEpisodeListenable].
  ///
  /// On a passing selection: captures `previous`; sets `_currentEpisode = ep`
  /// and `_currentEpisodeNotifier.value = ep` (the notifier fires through
  /// `ValueNotifier`'s `==`-guarded notify — and the `[id]`-keyed guard above
  /// guarantees `ep.id != previous.id`, so `BangumiEpisode.==` (full
  /// value-equality over all fields) always observes a difference and fires);
  /// returns `{previous, next: ep, changed: true}`. The page runs the remaining
  /// side effects (player stop, source reloads, danmaku, etc.) itself — this
  /// method does not orchestrate any of them.
  EpisodeSelectionResult selectEpisode(BangumiEpisode ep) {
    if (!ep.isReleased() || ep.id == _currentEpisode.id) {
      return EpisodeSelectionResult(
        previous: _currentEpisode,
        next: _currentEpisode,
        changed: false,
      );
    }
    final previous = _currentEpisode;
    _currentEpisode = ep;
    _currentEpisodeNotifier.value = ep;
    return EpisodeSelectionResult(previous: previous, next: ep, changed: true);
  }

  /// Pure resolve: returns the candidate episode `offset` slots away from
  /// [currentEpisode] in [playableEpisodes], WITHOUT mutating any controller
  /// state or firing [currentEpisodeListenable].
  ///
  /// Returns `null` when:
  ///   - [currentEpisode] is not in [playableEpisodes] (e.g. the unreleased +
  ///     no-released-fallback seeding case, where `indexOf == -1`); or
  ///   - the computed index `indexOf + offset` is out of range.
  ///
  /// The page wires its `_onSkipNext` to `resolveByOffset(1)` and forwards the
  /// non-null candidate to `_onEpisodeSelected`, which calls [selectEpisode]
  /// and runs the side-effect body only when `changed == true`. This preserves
  /// the historic `_onSkipNext` (`player_page.dart:4819-4824`) orchestration:
  /// the side-effect fan-out runs once through the single `_onEpisodeSelected`
  /// entry point — never twice — and `selectEpisode`'s same-id guard prevents
  /// a double-fire when `_onEpisodeSelected` reaches it (the candidate always
  /// carries a distinct `id`, so the guard passes exactly once).
  BangumiEpisode? resolveByOffset(int offset) {
    final idx = _playableEpisodes.indexOf(_currentEpisode);
    final newIdx = idx + offset;
    if (idx < 0 || newIdx < 0 || newIdx >= _playableEpisodes.length) {
      return null;
    }
    return _playableEpisodes[newIdx];
  }

  /// Resets the controller's working list / current episode.
  ///
  /// - If [newAllEpisodes] is non-null, the controller's `_allEpisodes` snapshot
  ///   is replaced and `_playableEpisodes` is recomputed via
  ///   `releasedEpisodes()`. When null, `_allEpisodes` and `_playableEpisodes`
  ///   are left untouched.
  /// - If [newInitial] is non-null, `_currentEpisode` is re-seeded using the
  ///   byte-for-byte init logic (`player_page.dart:285-287`):
  ///     `_currentEpisode = newInitial.isReleased() ? newInitial :
  ///         (_playableEpisodes.latestReleasedEpisode() ?? newInitial);`
  ///   and `_currentEpisodeNotifier.value` is updated (it fires through
  ///   `ValueNotifier`'s `==`-guarded notify — only when the value actually
  ///   changes). When a `newAllEpisodes` is also supplied, the re-seed reads the
  ///   freshly-recomputed `_playableEpisodes` (so the fallback reflects the new
  ///   corpus). [_originalInitialEpisode] is NOT updated by [reset] — it keeps
  ///   the construction-time value so [validateInvariants]'s check #2 stays
  ///   anchored to the page's original `initialEpisode`/`widget.currentEpisode`.
  ///
  /// **Strict no-op** when both arguments are null: no state change, the notifier
  /// does not fire, no recomputation. This mirrors
  /// [PlayerWebViewScheduler.clearForPoolToggle]'s stance that reset paths are
  /// explicit — a null-argument `reset` is a deliberate no-op rather than a
  /// silent re-derivation. The page does NOT currently call [reset] from
  /// `didUpdateWidget` (see the class doc): [reset] is reserved for a future
  /// checkpoint that proves `widget.allEpisodes` has meaningfully changed
  /// externally.
  void reset({
    BangumiEpisode? newInitial,
    List<BangumiEpisode>? newAllEpisodes,
  }) {
    if (newAllEpisodes == null && newInitial == null) {
      return;
    }
    if (newAllEpisodes != null) {
      _allEpisodes = newAllEpisodes;
      _playableEpisodes = _allEpisodes.releasedEpisodes();
    }
    if (newInitial != null) {
      final next = newInitial.isReleased()
          ? newInitial
          : (_playableEpisodes.latestReleasedEpisode() ?? newInitial);
      _currentEpisode = next;
      _currentEpisodeNotifier.value = next;
    }
  }

  /// Disposes the internal `ValueNotifier` and any owned resources. Called by
  /// the page's `dispose` in place of the historic
  /// `_currentEpisodeNotifier.dispose()` (`player_page.dart` dispose block).
  /// After this call, [currentEpisodeListenable] is a disposed notifier — do
  /// not add listeners or read `.value`.
  void clearForDispose() {
    _currentEpisodeNotifier.dispose();
  }

  // ── Invariants ────────────────────────────────────────────────────────────

  /// Validates the controller's internal invariants. Returns a list of
  /// human-readable violation messages; an empty list means the controller is
  /// in a consistent state. Composition tests call this after each mutation to
  /// catch any drift between `_currentEpisode`, the notifier, and the
  /// playable-list snapshot early — mirroring
  /// [PlayerWebViewScheduler.validateInvariants].
  ///
  /// Checks:
  ///   1. `_currentEpisodeNotifier.value.id == _currentEpisode.id` (the slot
  ///      and the notifier stay anchored to the same episode).
  ///   2. `_currentEpisode` is contained in `_playableEpisodes` by `id` OR is
  ///      the original construction-time `initialEpisode` by `id` (the
  ///      unreleased-initial + no-released-fallback case legitimately holds the
  ///      original unreleased `initialEpisode` outside `playableEpisodes`).
  ///   3. Every episode in `_playableEpisodes` is `isReleased()`.
  ///   4. `_playableEpisodes` has no duplicated `.id`s.
  ///   5. `_playableEpisodes` is consistent with
  ///      `_allEpisodes.releasedEpisodes()` (same order/elements by `.id`).
  ///
  /// Most failure branches are NOT reachable from the public surface alone
  /// (they require injected field mutation that this controller does not
  /// expose): checks #1, #3, #4, #5 hold invariant under the public API. The
  /// single reachable failure branch is check #2 — see
  /// `player_episode_controller_test.dart`'s "validateInvariants catches
  /// violations" group, which feeds the controller a released-but-phantom
  /// episode (filtered out of `playableEpisodes` by `withoutPhantomEpisodes()`)
  /// via [selectEpisode] and asserts check #2 fires.
  List<String> validateInvariants() {
    final errors = <String>[];

    // 1. notifier value matches _currentEpisode by id.
    if (_currentEpisodeNotifier.value.id != _currentEpisode.id) {
      errors.add(
        'currentEpisodeListenable.value (id=${_currentEpisodeNotifier.value.id}) '
        'id != currentEpisode (id=${_currentEpisode.id})',
      );
    }

    // 2. _currentEpisode is in _playableEpisodes by id OR is the original
    //    construction-time initialEpisode by id.
    final inPlayable = _playableEpisodes.any((e) => e.id == _currentEpisode.id);
    final isOriginalInitial = _currentEpisode.id == _originalInitialEpisode.id;
    if (!inPlayable && !isOriginalInitial) {
      errors.add(
        'currentEpisode (id=${_currentEpisode.id}) is neither in '
        'playableEpisodes (ids=${_playableEpisodes.map((e) => e.id).toList()}) '
        'nor equal to the original initialEpisode '
        '(id=${_originalInitialEpisode.id})',
      );
    }

    // 3. every playable episode is released.
    for (final ep in _playableEpisodes) {
      if (!ep.isReleased()) {
        errors.add(
          'playableEpisodes entry (id=${ep.id}, airdate=${ep.airdate}) '
          'is not released',
        );
      }
    }

    // 4. no duplicate ids in _playableEpisodes.
    final ids = _playableEpisodes.map((e) => e.id).toList();
    if (ids.toSet().length != ids.length) {
      errors.add('duplicate ids in playableEpisodes: $ids');
    }

    // 5. _playableEpisodes is consistent with _allEpisodes.releasedEpisodes()
    //    (same order/elements by id).
    final recomputed = _allEpisodes.releasedEpisodes();
    if (recomputed.length != _playableEpisodes.length ||
        !_sameIdsInOrder(recomputed, _playableEpisodes)) {
      errors.add(
        'playableEpisodes is out of sync with '
        'allEpisodes.releasedEpisodes(): '
        'controller=${_playableEpisodes.map((e) => e.id).toList()}, '
        'recomputed=${recomputed.map((e) => e.id).toList()}',
      );
    }

    return errors;
  }

  bool _sameIdsInOrder(List<BangumiEpisode> a, List<BangumiEpisode> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}
