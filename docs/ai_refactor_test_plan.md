# AI Refactor And Test Plan

This document is a working plan for AI agents that will refactor the Dart side
and add tests. Treat it as the source of truth for task boundaries, validation,
sequencing, and current progress.

Status date: 2026-07-12 (updated after the source-list / sites / comments /
bt-resource-list leaf-widget extraction checkpoint). Counts below are
physical line counts via `wc -l`; the earlier checkpoint's row was measured
with a tool that undercounted, so "Current" is not directly comparable to
the prior "Current" across files. Trends are correct.

## Goals

- Reduce the maintenance cost of the largest hand-written Dart files.
- Separate feature logic, page orchestration, UI widgets, and shared styling
  without rewriting the app.
- Add focused tests around behavior that is currently embedded inside large
  pages or managers.
- Keep every step behavior-preserving unless a task explicitly says otherwise.
- Make each change small enough to review independently.

## Non-Goals

- Do not refactor generated files:
  - `lib/gen/**`
  - `lib/src/rust/frb_generated*`
  - `lib/services/cache/database/*.g.dart`
- Do not refactor vendored or third-party code:
  - `third_party/**`
  - `native/mikan_libtorrent/include/httplib.h`
- Do not change Rust APIs, Flutter Rust Bridge bindings, database schemas, or
  asset layout unless a later task explicitly requires it.
- Do not introduce a new state-management framework as part of the first pass.
- Do not split every `TextStyle`, `Padding`, or color into constants. Extract
  style only when it is repeated, semantic, or blocks a clean widget boundary.

## Current Hotspots

The initial snapshot is retained for comparison. Current counts are measured
with `wc -l` at this checkpoint; the immediately-prior checkpoint added the
episode-panel, download-cleanup, download-task-store, recommendations,
relations, comments, and POSIX path containment-parity work.

| File | Initial | Current | Change | Main remaining issue |
| --- | ---: | ---: | ---: | --- |
| `lib/ui/pages/player_page.dart` | 8318 | 6835 | -1483 | Source loading, playback, episode changes, WebView dispatch orchestration remain mixed together; recommendations, comments, and the BT resource list are extracted. |
| `lib/services/download_manager.dart` | 3285 | 2862 | -423 | HTTP/m3u8/BT backends still live in one service; persistence and path/file cleanup are extracted with Windows mixed-separator and POSIX literal-backslash safety tests. |
| `lib/ui/widgets/video_player_controls.dart` | 3103 | 1121 | -1982 | Fully decomposed: SettingsPanel + MobileGestureAndLockLayer + MobileFloatingLockButton + SystemTimeDisplay + EpisodeSidePanel + SourceListPanel are now separate files. No remaining coherent controls boundary. |
| `↳ lib/ui/widgets/video_player_controls/settings_panel.dart` | 1141 | 939 | -202 | Source list extracted as `SourceListPanel`; panel keeps reactive source listener state for the menu subtitle. |
| `lib/ui/pages/bangumi_details_page.dart` | 3096 | 2732 | -364 | Data loading, favorite state, and the mobile inline comment rendering remain on the page; relations, sites, and the wide-layout comments section are extracted. |

## Progress Snapshot

Current validation baseline:

- `flutter analyze`: 0 issues.
- `flutter test`: 428 tests passing across 26 test files.
- Current checkpoint adds (over the 2026-07-11 checkpoint): the extracted
  `SourceListPanel` widget from `settings_panel.dart` (with pure helpers
  `sourceDisplayLabel` / `clampSourceIndex` / `resolveActiveOnlineSourceIndex`),
  the extracted `SitesSection` widget, the extracted `CommentsSection`
  display widget (wide layout; the mobile layout keeps its own inline
  rendering and `_buildCommentCard`), the extracted pure BT-tag helpers
  (`parseBtTags` / `buildBtTag` / `buildBtTagsRow` in `bt_resource_tags.dart`),
  and the extracted `BtResourceList` display widget with an immutable
  `BtResource` view-model plus dispatch adapters (`timeOf` / `episodeOf` /
  `toBtResource` / `toBtResourceViewModels`). All play/download/clipboard
  side effects stay on `PlayerPage` as `BtResourceList` callbacks; the
  `onPlay` body is byte-identical to the original inline closure.
- **Real player smoke run completed (2026-07-11)** after the
  episode-panel and download-cleanup checkpoints: source search,
  captcha-to-video reuse, cancellation, source switching, episode
  switching, and leave/re-enter all verified on-device with no
  regressions. This clears the Phase 0 "record real runtime smoke"
  item for the current checkpoint.
- No generated Drift/Flutter Rust Bridge files were refactored by this
  plan.

Phase status:

| Phase | Status | Completed | Main remaining work |
| --- | --- | --- | --- |
| Phase 0 | Complete | Analyzer/test baseline and worktree checks; **real player/WebView smoke run recorded 2026-07-11** (source search, captcha-to-video, cancel, source/episode switch, leave/re-enter). | Re-record after the next architectural checkpoint that touches WebView/playback/platform. |
| Phase 1 | Partial | System time, mobile lock/gesture cluster, SettingsPanel, pure Bangumi helpers, **EpisodeSidePanel**, **PlayerRecommendations**, **PlayerComments**, **RelationsSection**, **SourceListPanel**, **SitesSection**, **CommentsSection**, **BtResource view-model + BtResourceList**, and pure BT-tag helpers — each with `testWidgets`/unit coverage. | Player data models/enums; mobile inline comment rendering unification (redesign, deferred). |
| Phase 2 | Partial | Player helpers; WebView scheduler B1-B6 state, selection, bookkeeping, pump coordinator, ownership guards, and tests; **`PlayerRecommendations` display widget + widget tests**; **`PlayerComments` display widget + widget tests**; **`BtResourceList` display widget + `BtResource` view-model + dispatch adapters + tests** (play/download/clipboard callbacks stay on page). | Dispatch planning/affinity ownership, source controller, episode controller, playback controller, integration smoke. |
| Phase 3 | Partial | DownloadTask/enums, magnet helpers, DownloadQueue, **DownloadFileCleanup + Windows/POSIX path-safety tests**, **DownloadTaskStore behind injected prefs interface + round-trip tests**, and unit tests. | HTTP/m3u8 jobs, then BT adapters. |
| Phase 4 | Partial | Pure parsing/sorting helpers and tests; **`RelationsSection` display widget + widget tests**; **`SitesSection` display widget + widget tests**; **`CommentsSection` display widget (wide layout) + widget tests**. | Details controller; mobile inline comment rendering; header/characters/episodes section widgets. | |
| Phase 5 | Not started | None. | Start only after controller/widget boundaries are stable. |

## Target Dart Shape

Use this structure as a direction, not a requirement to complete in one change.

```text
lib/ui/pages/player/
  player_page.dart
  player_controller.dart
  player_source_controller.dart
  player_webview_scheduler.dart
  player_models.dart
  widgets/
    player_video_area.dart
    player_source_panel.dart
    player_resource_list.dart
    player_comments_tab.dart
    player_recommendations.dart
```

```text
lib/services/download/
  download_manager.dart
  download_task.dart
  download_task_store.dart
  download_queue.dart
  http_download_job.dart
  m3u8_downloader.dart
  bt_backend.dart
  rqbit_backend.dart
  libtorrent_backend.dart
  download_file_cleanup.dart
```

```text
lib/ui/widgets/video_player_controls/
  video_player_controls.dart
  controls_models.dart
  settings_panel.dart
  mobile_gesture_layer.dart
  mobile_lock_button.dart
  episode_side_panel.dart
  source_list_panel.dart
  system_time_display.dart
```

```text
lib/ui/pages/bangumi_details/
  bangumi_details_page.dart
  bangumi_details_controller.dart
  bangumi_details_models.dart
  widgets/
    details_header.dart
    summary_section.dart
    tags_section.dart
    character_section.dart
    episodes_section.dart
    relations_section.dart
    sites_section.dart
    comments_section.dart
```

Shared visual primitives can stay in:

```text
lib/ui/theme/app_theme.dart
lib/ui/theme/app_spacing.dart
lib/ui/theme/app_colors.dart
```

Only add `app_spacing.dart` or `app_colors.dart` after finding repeated values
across multiple files.

## General Agent Rules

1. Start each task by reading the files it touches.
2. Preserve public behavior first; extraction before redesign.
3. Prefer moving code with minimal edits over rewriting code.
4. Keep imports explicit and remove unused imports after each extraction.
5. Avoid touching unrelated files.
6. Keep private implementation private unless a test or extracted module needs a
   public API.
7. Add tests close to the behavior being extracted.
8. Run validation before handing off.
9. Leave a short summary of changed files, tests run, and known risks.

## Validation Commands

Format only the files touched by the current task. Do not run a write-mode
whole-repository format during an ordinary extraction; the repository has
previously produced unrelated formatting churn from that command.

```powershell
dart format <touched Dart files>
dart format --output=none --set-exit-if-changed <touched Dart files>
flutter analyze
flutter test
git diff --check
```

Run a whole-repository format only as a dedicated formatting task with its own
reviewable commit.

For changes involving WebView scheduling, playback startup/fallback, episode
switching, or platform-backed downloads, automated validation is necessary but
not sufficient. Record the relevant manual smoke steps before merging the
checkpoint.

If a task touches generated Drift or Flutter Rust Bridge files, stop and explain
why before proceeding. This plan should not normally touch them.

For Rust-only follow-up tasks, use:

```powershell
cd rust
cargo fmt
cargo test
```

## Phase 0: Safety Baseline

Owner: baseline agent

Status: complete. The current checkpoint is 0 analyzer issues and 428 passing
tests across 26 test files. Re-run the baseline after dependency, Flutter SDK,
or platform changes.

Tasks:

- Run `flutter analyze` and `flutter test`.
- Record current failures, if any, in the task summary.
- Do not fix unrelated failures in this phase unless they block all later work.
- Identify files with user changes before editing:

```powershell
git status --short
```

Done when:

- Baseline analyzer/test status is known.
- Later agents know whether failures are pre-existing.

## Phase 1: Low-Risk Pure Extractions

Owner: extraction agents

Status: partial.

Completed:

- `SystemTimeDisplay`.
- Mobile floating lock button.
- Mobile gesture/lock/multi-tap cluster.
- `SettingsPanel`.
- Pure Bangumi details parsing/sorting helpers.
- `EpisodeSidePanel` widget (`lib/ui/widgets/video_player_controls/episode_side_panel.dart`),
  extracted from `video_player_controls.dart`, with the project's first
  `testWidgets` coverage (`test/ui/widgets/video_player_controls/episode_side_panel_test.dart`).
- `PlayerRecommendations` and `PlayerComments` display widgets, each with
  focused widget tests.
- `RelationsSection` display widget with loading, empty, populated, dark, and
  tap-forwarding widget tests.
- `SourceListPanel` widget (`lib/ui/widgets/video_player_controls/source_list_panel.dart`)
  extracted from `settings_panel.dart`'s `_buildSourceList`; pure helpers
  `sourceDisplayLabel` / `clampSourceIndex` / `resolveActiveOnlineSourceIndex`
  promoted to top-level; 9 widget/unit tests.
- `SitesSection` display widget (`lib/ui/pages/bangumi_details/widgets/sites_section.dart`)
  extracted from `bangumi_details_page.dart`; page keeps `_sortSites`, the
  scroll controller, and the `launchBangumiSiteUrl` callback; 6 widget tests.
- `CommentsSection` display widget (`lib/ui/pages/bangumi_details/widgets/comments_section.dart`)
  extracted from the wide-layout `_buildCommentsSection`; the fetch side
  effect (`unawaited(_ensureCommentsLoaded())`) and all pagination/state stay
  on the page's thin wrapper; the mobile layout keeps its own inline
  rendering and `_buildCommentCard`; 9 widget tests.
- Pure BT-tag helpers (`lib/ui/pages/player/widgets/bt_resource_tags.dart`):
  `parseBtTags` / `buildBtTag` / `buildBtTagsRow`, relocated verbatim from
  `player_page.dart`; 25 unit + widget tests.
- `BtResourceList` display widget (`lib/ui/pages/player/widgets/player_resource_list.dart`)
  with immutable `BtResource` view-model (`bt_resource.dart`) and dispatch
  adapters `timeOf` / `episodeOf` / `toBtResource` / `toBtResourceViewModels`
  added to `player_source_helpers.dart`; the page keeps all
  play/download/clipboard side effects as `BtResourceList` callbacks; 10
  widget tests + 17 dispatch/adapter/content-routing tests.

Remaining:

- Player data models/enums that do not belong to a controller.
- (Deferred redesign) Unify the mobile inline comment rendering with the
  wide-layout `CommentsSection` — the mobile branch inlines its own
  ListView + "加载中..."/"暂无评论" text and calls `_buildCommentCard`
  directly; unifying would redraw mobile and is out of scope for a
  behavior-preserving leaf-widget pass.

Purpose: shrink large files by moving clearly independent declarations and
private widgets into new files with minimal behavior changes.

Rules:

- Do not change logic.
- Do not rename behavior-bearing fields or methods unless necessary.
- Prefer extracting one cluster per task.
- If using `part` files, treat that as an intermediate step only. Convert to
  normal imports later when dependencies are clean.

Suggested tasks:

1. `video_player_controls.dart`: extract `_SystemTimeDisplay`.
2. `video_player_controls.dart`: extract mobile lock button and lock layer.
3. `video_player_controls.dart`: extract mobile multi-tap/gesture layer.
4. `video_player_controls.dart`: extract settings panel.
5. `bangumi_details_page.dart`: extract comments section widget (remaining).
6. `bangumi_details_page.dart`: extract sites section widget (remaining).
7. `bangumi_details_page.dart`: extract relations section widget (complete).
8. `player_page.dart`: extract small data classes/enums near the top into
   `player_models.dart`.
9. `player_page.dart`: extract recommendation list widgets (complete).
10. `player_page.dart`: extract comments tab widgets (complete).

Recommended verification after each task:

```powershell
dart format <touched Dart files>
dart format --output=none --set-exit-if-changed <touched Dart files>
flutter analyze
flutter test
git diff --check
```

## Phase 2: Player Page Responsibility Split

Owner: player architecture agent

Status: partial. `PlayerWebViewScheduler` now owns worker slots, reverse maps,
worker ids, health/bookkeeping transitions, budget allocation, and the pump
coordinator. It exposes immutable page-facing slot views and has composition
tests for cross-kind lifecycle, cancellation, stale callbacks, unhealthy
workers, ownership, and token ordering.

Still page-owned:

- Pending `SearchPlayResult` collection and source-tier/enqueue metadata.
- Source-affinity job choice and the pump loop that invokes page side effects.
- Captcha/video result business handling, probe/register, logging, and UI text.
- Source loading, playback, episode changes, comments, recommendations, and
  resource list remain page-owned for behavior, but their display trees are
  now extracted widgets (`PlayerRecommendations`, `PlayerComments`,
  `BtResourceList`) wired back via callbacks.

Purpose: make `PlayerPage` a page shell plus orchestration layer, then move
long-running behavior into testable controllers.

Target boundaries:

- `PlayerPage`
  - Owns Flutter lifecycle.
  - Builds mobile/desktop layouts.
  - Wires controller state into widgets.
- `PlayerSourceController`
  - Builds search aliases.
  - Starts and cancels Mikan/DMHY/generic source loading.
  - Tracks pending source extraction results.
  - Exposes source status for UI.
- `PlayerWebViewScheduler`
  - Owns worker slots, active job maps, source affinity, pump scheduling, and
    worker health transitions.
  - Does not build widgets.
- `PlayerPlaybackController`
  - Owns selected source, playback headers, startup watchdog, fallback, and
    playback URL selection.
- `PlayerEpisodeController`
  - Owns current episode, playable episode list, skip next/previous, and episode
    selection.

Original helper/state sequence is complete through scheduler B6. Continue with
the revised sequence below:

1. Record a real player/WebView smoke baseline for the current scheduler.
2. Move only dispatch planning into scheduler input/output DTOs. The scheduler
   should return commands; the page should still execute widget and side
   effects.
3. Recommendations and comments are complete. Extract only the resource list
   or source panel as the next display-only player widget, one per commit.
4. Extract `PlayerEpisodeController` as the lowest-risk controller.
5. Extract source loading state into `PlayerSourceController` using injected
   loaders/streams and cancellation tests.
6. Extract `PlayerPlaybackController` last, with injected clock/timer/player
   callbacks for watchdog and fallback tests.
7. Keep page wiring on existing Flutter primitives unless a local abstraction
   is already established.

Avoid:

- Moving all 8000 lines in one change.
- Combining refactor with UI redesign.
- Making `BuildContext` available inside business controllers.
- Letting controller tests instantiate `InAppWebView` or real media players.
- Moving widget building, probe/playback side effects, and scheduler state in
  the same commit.

## Phase 3: Download Manager Split

Owner: download architecture agent

Status: partial. `DownloadTask`, related enums, magnet helpers, and
`DownloadQueue` are extracted and tested. Path safety and persistence are the
next priorities before network/backend extraction.

Purpose: separate persistence, queueing, backend operations, and file operations
so each piece can be tested without a full app runtime.

Target boundaries:

- `DownloadTask`
  - Data model and JSON serialization.
- `DownloadTaskStore`
  - Reads/writes task JSON to `SharedPreferences`.
- `DownloadQueue`
  - Concurrency slots and waiters.
- `HttpDownloader`
  - Plain file download and speed throttling.
- `M3u8Downloader`
  - Playlist parsing and segment download.
- `BtBackend`
  - Interface for torrent operations.
- `RqbitBackend`
  - Existing Rust API backend behavior.
- `LibtorrentBackend`
  - Native libtorrent behavior.
- `DownloadFileCleanup`
  - Path validation, orphan detection, delete-empty-parent logic.

Suggested sequence:

1. Extract `DownloadTask`, `DownloadTaskType`, `DownloadTaskStatus`, and
   `BtBackendKind`.
2. Add JSON round-trip tests for `DownloadTask`.
3. Extract magnet tracker injection and info-hash parsing helpers.
4. Add tests for magnet tracker injection and info-hash parsing.
5. Extract `DownloadQueue` slot acquisition/release logic.
6. Add queue tests for max concurrency, cancellation, and transfer.
7. Extract path helpers into `DownloadFileCleanup`.
8. Add path safety tests. Include Windows path cases.
9. Extract HTTP and m3u8 download jobs only after helpers are tested.
10. Extract BT backend adapters last.

Revised immediate order:

1. ~~`DownloadFileCleanup` with Windows and temp-directory containment tests.~~
   Done (2026-07-11). Surfaced and fixed a real Windows mixed-separator
   defect in `isPathUnderDownloadDir`: `.absolute.path` on the host mixes
   `\\` and `/`, so the unnormalised `startsWith(baseWithSeparator)`
   false-negatives on real child paths. Both affected functions now
   normalise to `/` before comparing.
2. ~~`DownloadTaskStore` behind an injected key-value preference interface.~~
   Done (2026-07-11). `lib/services/download/download_task_store.dart`
   exposes `DownloadTaskKeyValueStore` (interface) +
   `SharedPreferencesDownloadTaskKeyValueStore` (prod impl) +
   `DownloadTaskStore` (load/save), with the persisted key
   `'bt_download_tasks_v1'` re-exported as a const so it stays in one
   place. The manager keeps ALL domain logic (validation, status
   transitions, resume queue, paused-id tracking, cold-start throttle);
   only raw encode/decode/string-IO moved out.
3. HTTP job extraction.
4. m3u8 parsing/download extraction.
5. Rqbit/libtorrent adapters last.

Avoid:

- Changing persisted JSON keys.
- Changing default backend selection.
- Changing download directory resolution semantics.
- Deleting files in tests. Use temp directories and explicit containment checks.

## Phase 4: Bangumi Details Page Split

Owner: details page agent

Status: partial. Pure summary/infobox/site/person helpers are extracted and
tested. `RelationsSection`, `SitesSection`, and the wide-layout
`CommentsSection` display widgets are extracted with `testWidgets` coverage.
Controller state and the mobile inline comment rendering remain on the page.

Purpose: make the details page a composition of sections with isolated parsing
helpers.

Target boundaries:

- Controller/data:
  - initial cache prime
  - data fetch
  - comment pagination
  - favorite toggle
- Pure parsing:
  - summary parsing
  - tag extraction
  - infobox summarization
  - person text matching
  - site sorting/labels
- Widgets:
  - header
  - rating/stat card
  - summary/tags
  - info box
  - characters
  - episodes
  - relations
  - sites
  - comments

Suggested tests:

- Summary parser handles translated/original summaries.
- Infobox summarizer handles strings, arrays, maps, empty values.
- Site sort priority is stable.
- Person text matcher finds expected names without overlapping matches.

## Phase 5: Styling And UI Consistency

Owner: UI cleanup agent

Status: not started. Do not start while the large page/controller boundaries
above are still moving.

Purpose: extract style only after widget boundaries are clearer.

Extract style when:

- A color/spacing/text style appears in at least three places.
- A semantic token improves readability, such as `AppSpacing.sectionGap`.
- A widget boundary needs a small style object to avoid giant constructors.

Do not extract style when:

- The value is local to one widget.
- The abstraction name is vague, such as `bigPadding` or `blueColor`.
- It forces readers to jump files for a one-off value.

Suggested additions:

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}
```

Only add this after confirming the project benefits from it.

## Test Plan

Current baseline: 428 tests across 26 test files.

Covered areas:

- Reusable captcha/video runners without a real `InAppWebView`.
- Scheduler statistics, worker selection, bookkeeping, pump decisions,
  state transitions, pump coordinator, and composed scheduler invariants.
- Player source/BT/tag helper behavior.
- DownloadTask JSON compatibility, magnet helpers, DownloadQueue.
- Download path safety (`download_file_cleanup_test.dart`): under-root
  containment, similar-prefix sibling rejection, traversal/`:` rejection,
  child-path resolution, empty-parent cleanup up to (not including) the
  root, Windows mixed-separator handling, `findUniqueDownloadedFileCandidate`
  size + fuzzy-basename disambiguation, and POSIX literal-backslash siblings.
  The POSIX cases prove both containment and empty-parent cleanup do not
  classify or delete a sibling named `download\\outside`.
- DownloadTaskStore (`download_task_store_test.dart`): round-trip, empty
  store, overwrite, corrupt/invalid JSON handling, `saveTasks(const [])`
  writes `"[]"`, default storage key const enforcement — all via an
  in-memory `DownloadTaskKeyValueStore` fake (no SharedPreferences /
  platform channels).
- Bangumi details parsing/sorting helpers.
- `EpisodeSidePanel` widget: cell rendering, selected-cell styling,
  tap-select-and-navigator-pop, empty list, `ValueListenable` reactive
  update — the project's first `testWidgets` coverage.
- `PlayerRecommendations` widget: loading / empty / populated vertical /
  populated horizontal in a `SingleChildScrollView`, tap callback
  forwarding.
- `PlayerComments` widget: loading, error, empty, populated, and sort-button
  states; `RelationsSection`: loading, empty, populated, dark-mode, and
  relation-tap forwarding.
- `SourceListPanel` widget: empty, populated, selection highlight, tap
  callback, `ValueListenable` reactivity; plus pure-helper unit tests
  (`sourceDisplayLabel` / `clampSourceIndex` / `resolveActiveOnlineSourceIndex`).
- `SitesSection` widget: empty, populated, kind-badge labels, tap-to-launch
  forwarding, dark-bg, Scrollbar wiring.
- `CommentsSection` widget (wide layout): loading, empty, populated, rate
  stars, load-more spinner on/off, dark-bg, HtmlWidget no-throw smoke.
- BT-tag helpers (`bt_resource_tags_test.dart`): resolution / codec /
  subLang / subType / raw precedence, combination-language priority,
  soft-over-hard sub, empty title, realistic VCB-Studio title,
  `buildBtTagsRow` rendering + SizedBox.shrink-on-empty + pre-parsed-tags path.
- `BtResourceList` display widget + `BtResource` view-model: collapsed gate,
  loader-in-tab guard, empty + retry, empty + error status, populated,
  per-card `loadingMagnet` spinner, play-disabled, copy/download/play
  callback forwarding, dark-theme, R1 tag chips; plus resource-content routing
  (collapsed precedence and BT/subscription selection) and dispatch adapters
  (`timeOf` / `episodeOf` / `toBtResource` / `toBtResourceViewModels`).

Important uncovered areas:

- No meaningful `testWidgets` coverage for PlayerPage, BangumiDetailsPage, or
  CustomVideoControls.
- No integration-test directory or real WebView/media lifecycle coverage.
- No production-wiring test around `SharedPreferences`; persistence tests use
  the intended injected key-value interface.
- No HTTP/m3u8/backend lifecycle tests.
- Comment HTML custom-widget rendering (masked text and Bangumi smile images)
  has no focused widget coverage after its move into `PlayerComments`.

High-value new tests:

| Area | Test file | Coverage |
| --- | --- | --- |
| Download task serialization | `test/services/download/download_task_test.dart` | JSON compatibility, defaults, old records without `taskType`, backend parsing. |
| Download queue | `test/services/download/download_queue_test.dart` | Slot acquisition, max concurrency, release, transfer, cancellation. |
| Download path safety | `test/services/download/download_file_cleanup_test.dart` | Under-download-dir checks, relative path resolution, Windows separators, empty parent cleanup with temp dirs. |
| Magnet helpers | `test/services/download/magnet_test.dart` | Tracker injection dedupe, info-hash extraction from magnet and stream URLs. |
| Player scheduler | `test/ui/pages/player/player_webview_scheduler_test.dart` | Worker selection, source affinity, unhealthy workers, captcha/video active job maps. |
| Player source helpers | `test/ui/pages/player/player_source_helpers_test.dart` | BT-resource dedup/sorting, view-model dispatch, resource-content routing, recommendation tag normalization. |
| Video controls helpers | `test/ui/widgets/video_player_controls/video_controls_test.dart` | Episode selection, source labels, playback speed formatting where extracted. |
| Bangumi details helpers | `test/ui/pages/bangumi_details/bangumi_details_helpers_test.dart` | Summary parsing, infobox summarization, site sorting, person matching. |
| Source-list panel | `test/ui/widgets/video_player_controls/source_list_panel_test.dart` | Empty, populated, selection highlight, tap callback, `ValueListenable` reactivity, pure-helper dispatch. |
| Bangumi sites section | `test/ui/pages/bangumi_details/widgets/sites_section_test.dart` | Empty, populated, kind-badge labels, tap-to-launch forwarding, dark-bg, Scrollbar wiring. |
| Bangumi comments section | `test/ui/pages/bangumi_details/widgets/comments_section_test.dart` | Loading, empty, populated, rate stars, load-more spinner on/off, dark-bg, HtmlWidget no-throw. |
| BT-resource tag helpers | `test/ui/pages/player/widgets/bt_resource_tags_test.dart` | Resolution/codec/subLang/subType/raw precedence, combination priority, HEVC-over-AVC, soft-over-hard sub, empty, realistic VCB-Studio title, `buildBtTagsRow` rendering. |
| BtResourceList display | `test/ui/pages/player/widgets/player_resource_list_test.dart` | Collapsed gate, loader-in-tab guard, empty + retry, empty + error status, populated, per-card loading spinner, play-disabled, copy/download/play callback forwarding, dark-theme, R1 tag chips. |

Add basic widget tests with each display-only extraction. Prefer stable state
and callback assertions over pixel-perfect goldens:

- Loading, empty, error, and populated states.
- Selection/callback forwarding.
- Mobile/wide branch smoke where the widget has materially different layouts.
- No network, WebView, media player, or platform-channel startup.

Testing guidance:

- Prefer pure Dart unit tests for extracted helpers.
- Use widget tests only for stable UI behavior that is easy to assert.
- Avoid tests that require real network, real WebView, real media playback, or
  platform channels.
- For platform-channel-heavy services, inject thin interfaces or callbacks.
- Use temp directories for file operations.

## Suggested Sub-Agent Work Packages

### Package A: Remaining Video Controls Boundary (✅ complete — `SourceListPanel`)

Prompt:

```text
Extract the source-list panel from `lib/ui/widgets/video_player_controls.dart`
into one focused widget file. The episode panel is already extracted. Keep the
public `CustomVideoControls` API unchanged. Pass state and callbacks through
the constructor. Add focused helper/widget tests for selection and callback
forwarding. Format touched files, then run analyzer and the full test suite.
```

Acceptance:

- File size is reduced.
- Public `CustomVideoControls` API is unchanged.
- Analyzer and tests pass or pre-existing failures are documented.

### Package B: HTTP Download Job Characterization

Prompt:

```text
Before extracting HTTP download code from `download_manager.dart`, identify a
small injected HTTP/file interface that permits characterization tests for
headers, cancellation, partial-file cleanup, resume/range behavior, and error
transitions. Keep production behavior unchanged and do not move m3u8 or BT
code in the same commit. Format touched files, then run analyzer and the full
test suite.
```

Acceptance:

- HTTP behavior is covered without real network traffic.
- Cancellation and failed-transfer cleanup have explicit tests.
- Existing manager behavior and public API remain unchanged.

### Package C: Player Scheduler Dispatch Planning

Prompt:

```text
Extend `PlayerWebViewScheduler` with immutable pending-job input DTOs and a
dispatch decision/command result. Move source-affinity job choice into the
scheduler without moving widget creation, setState, logging, probe/playback, or
result callbacks. The page executes returned commands. Add composition tests
for tier ordering, enqueue ordering, per-source soft limits, captcha/video
competition, and no-work results.
```

Acceptance:

- Scheduler remains pure Dart and has no Flutter/widget imports.
- Page-side effects and WebView construction remain on PlayerPage.
- Existing scheduler and runner tests still pass.

### Package D: Bangumi Details Section Widget (✅ complete — `SitesSection` + `CommentsSection`)

Prompt:

```text
Extract one display-only section from `lib/ui/pages/bangumi_details_page.dart`,
starting with sites or comments (`RelationsSection` is already complete), into
`lib/ui/pages/bangumi_details/widgets/`. Pass data and callbacks explicitly.
Do not move fetching, pagination, favorite state, or navigation ownership in
the same commit. Add loading/empty/populated widget tests where practical.
```

Acceptance:

- Extracted widget has no hidden service/global state.
- Page output and callbacks are preserved.
- Analyzer and full tests pass.

### Package E: Player Page Widget Sections (✅ complete — `BtResourceList` + `BtResource`)

Prompt:

```text
Extract the resource list from `lib/ui/pages/player_page.dart` into a widget
under `lib/ui/pages/player/widgets/`; recommendations and comments are already
complete. The widget should receive all required data and callbacks through its
constructor. Do not move source loading or playback logic in this package.
```

Acceptance:

- Extracted widget has no hidden global state.
- `PlayerPage` remains the owner of behavior for this step.
- Analyzer and tests pass.

## Review Checklist

Use this checklist for every automated refactor:

- Does the change avoid generated and third-party files?
- Are persisted keys and public APIs preserved?
- Are new files named by responsibility rather than by vague categories?
- Did the agent avoid mixing behavior changes with extraction?
- Are tests added for newly testable logic?
- Were only touched files formatted in write mode?
- Did the touched-file `--set-exit-if-changed` check pass?
- Did `flutter analyze` run?
- Did `flutter test` run?
- Did `git diff --check` run?
- If WebView/playback/platform behavior was touched, was the manual smoke result
  recorded?
- Are any failures clearly marked as pre-existing?
- Is the final summary short and specific?

## Stop Conditions

An agent should stop and ask for review if:

- A refactor requires changing persisted task JSON.
- A refactor requires changing Flutter Rust Bridge generated bindings.
- A task needs a new dependency.
- Tests require real network/WebView/media playback.
- The same extraction causes cascading edits across many unrelated modules.
- Analyzer errors appear unrelated to the files touched and were not present in
  the baseline.
- A task needs simultaneous architectural edits in `player_page.dart` and
  unrelated download/details modules.
- A scheduler/controller change cannot be expressed as testable state or
  commands without importing widget/platform objects.

## Recommended Next Steps

The download containment parity fix is complete: separator spelling and case
are normalized only on Windows, and POSIX temp-directory tests cover both
containment and empty-parent cleanup of literal-backslash siblings.

1. ✅ Complete low-risk leaf widgets in isolated commits: source-list panel,
   Bangumi sites, Bangumi comments, and the player resource list — all
   extracted this checkpoint with state/callback widget tests and no
   controller work. Next leaf candidates: player data models/enums and the
   deferred mobile-comment-rendering unification (a redesign, not an
   extraction).
   **Smoke caveat:** the `BtResourceList` extraction is display-only, but its
   `onPlay` callback on the page drives the playback-startup path
   (`_downloadManager.startDownload(forPlayback:true)` → `_player.open(Media)`).
   The `onPlay` body is byte-identical to the original inline closure, so
   risk is low — but a real player/WebView smoke run (source search → play
   a BT source → confirm playback + leave/re-enter) should be recorded
   before the next architectural checkpoint, per the Phase 2 manual-smoke
   rule.
2. Add focused `PlayerComments` (and Bangumi `CommentsSection`) HTML-rendering
   tests for a mask and a Bangumi smile image, then manually check one
   populated comments view. The current tests cover states and callbacks but
   intentionally use empty HTML.
3. Keep the current scheduler checkpoint frozen until the next architectural
   step. Its real player/WebView smoke run has passed (2026-07-11); repeat
   that smoke before and after any dispatch, source, episode, or playback
   controller checkpoint, and after the `BtResourceList` `onPlay` rewiring
   noted above.
4. Move scheduler dispatch planning into command-returning methods. Require
   immutable input/output DTOs and tests for tier/enqueue order, affinity,
   soft limits, captcha/video competition, and no-work results. Do not move
   WebView construction or page side effects in this step.
5. Extract controllers in risk order: Episode, Bangumi Details, Source,
   Playback. Stop for review after each controller rather than running this
   sequence unattended.
6. Characterize HTTP/m3u8 behavior behind injected
   network/filesystem seams before extracting jobs; leave BT adapters last.
7. Start styling/token work only after the structural phases stop moving.

Use a new branch/checkpoint for each architectural stage. Do not measure
completion by hotspot line count alone; require an owned responsibility,
tests for its behavior, and a page/service boundary that no longer mutates the
extracted state directly.

## Lessons For Sub-Agents (2026-07-11 checkpoint)

Two operational rules confirmed during the episode-panel and
download-cleanup extractions:

1. **Run unattended OpenCode in `--auto`/YOLO mode, not plain background.**
   A background `opencode run` (no `--auto`) hangs silently the moment a
   tool call wants interactive permission approval — the approval dialog
   cannot surface in a non-interactive background run, and the agent
   appears stuck while actually waiting on a prompt nobody can answer.
   The pkgA agent hung for several minutes on exactly this (a `dart run`
   diagnostic that needed an external-directory permission). For any
   fire-and-forget refactor, pass `--auto` so tool permissions are
   auto-approved and the stall never happens. Reserve plain
   `opencode run` forForeground interactive calls where a human is watching.

2. **Do not treat the original code as a load-bearing contract.** Extraction
   is not "relocate verbatim and preserve every quirk." The point of adding
   tests around extracted behavior is to *find* latent defects — when a
   new test surfaces one, confirm it is real, fix it at the helper, and
   cover the fix with a test. The `isPathUnderDownloadDir` Windows
   mixed-separator bug is a concrete example: the original
   `startsWith(baseWithSeparator)` silently false-negatived on real child
   paths on this host, and only the extracted Windows tests exposed it.
   Fixing it was in-scope, not scope creep. Apply judgment: behavior
   the *plan* preserves (persisted JSON keys, public APIs, download-dir
   resolution) stays frozen; behavior that is plainly buggy is fair game
   once a test confirms it.

3. **A display-section extraction can hit a divergent sibling render path
   and force a partial extraction.** (2026-07-12.) When extracting the
   Bangumi comments section, the page's `_buildCommentsSection` (wide
   layout) and the mobile layout's inline rendering turned out to be
   *materially different*: the mobile branch builds its own ListView with
   "加载中..." / "暂无评论" text and calls `_buildCommentCard` directly,
   while only the wide layout routes through `_buildCommentsSection`.
   Deleting `_buildCommentCard` would have redrawn mobile and was a
   forbidden UI change. The behavior-preserving move was to extract the
   wide-layout widget *and leave* `_buildCommentCard` on the page (the card
   tree now exists in two places). Unifying the two render paths is a
   redesign, deferred. Lesson: before deleting a helper as "moved", grep all
   call sites and confirm there is a single caller; if two divergent render
   paths share a helper, extraction is partial by design, and that is fine.

4. **Use `wc -l` as the single source of truth for hotspot line counts.**
   (2026-07-12.) The prior checkpoint's hotspot table was measured with a
   tool that undercounted several files by ~500 lines versus `wc -l`, so
   the "Current" column was not directly comparable across files and the
   "Change" delta appeared inflated. Always measure with `wc -l` (or
   `grep -c '^'`, which agrees) and restate the tool in the table caption
   so the next agent compares apples to apples.
