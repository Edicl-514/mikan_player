# AI Refactor And Test Plan

This document is a working plan for AI agents that will refactor the Dart side
and add tests. Treat it as the source of truth for task boundaries, validation,
and sequencing.

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

Snapshot from the repository at the time this plan was created:

| File | Approx lines | Main issue |
| --- | ---: | --- |
| `lib/ui/pages/player_page.dart` | 8318 | Page UI, playback orchestration, source search, WebView worker scheduling, comments, recommendations, BT resources, and history are all mixed together. |
| `lib/services/download_manager.dart` | 3285 | Task model, persistence, concurrency, HTTP download, m3u8 download, BT backends, libtorrent/rqbit glue, stats, and cleanup live in one service. |
| `lib/ui/widgets/video_player_controls.dart` | 3103 | Video controls, settings panel, mobile gesture layer, lock UI, episode panel, source list, subtitle controls, and time display live in one widget file. |
| `lib/ui/pages/bangumi_details_page.dart` | 3096 | Data loading, parsing helpers, mobile/wide layouts, header, stats, tags, characters, episodes, relations, sites, and comments are mixed together. |

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

Run these after Dart refactor tasks:

```powershell
dart format lib test
flutter analyze
flutter test
```

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
5. `bangumi_details_page.dart`: extract comments section widget.
6. `bangumi_details_page.dart`: extract sites section widget.
7. `bangumi_details_page.dart`: extract relations section widget.
8. `player_page.dart`: extract small data classes/enums near the top into
   `player_models.dart`.
9. `player_page.dart`: extract recommendation list widgets.
10. `player_page.dart`: extract comments tab widgets.

Recommended verification after each task:

```powershell
dart format lib test
flutter analyze
flutter test
```

## Phase 2: Player Page Responsibility Split

Owner: player architecture agent

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

Suggested sequence:

1. Extract pure helper functions first:
   - source channel key building
   - source label formatting
   - recommendation tag normalization
   - BT resource sort/dedup helpers
   - Bangumi comment HTML normalization
2. Add unit tests for extracted helpers.
3. Extract `PlayerWebViewScheduler` state model without moving widget building.
4. Move scheduling decisions into methods that return commands/events.
5. Add unit tests for scheduler decisions.
6. Extract source loading state into `PlayerSourceController`.
7. Wire page to controller with `ChangeNotifier`, `ValueNotifier`, or existing
   Flutter primitives.

Avoid:

- Moving all 8000 lines in one change.
- Combining refactor with UI redesign.
- Making `BuildContext` available inside business controllers.
- Letting controller tests instantiate `InAppWebView` or real media players.

## Phase 3: Download Manager Split

Owner: download architecture agent

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

Avoid:

- Changing persisted JSON keys.
- Changing default backend selection.
- Changing download directory resolution semantics.
- Deleting files in tests. Use temp directories and explicit containment checks.

## Phase 4: Bangumi Details Page Split

Owner: details page agent

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

Existing tests:

- `test/reusable_browser_worker_test.dart`
- `test/source_channel_key_test.dart`
- `test/webview_scheduler_stats_test.dart`
- `test/widget_test.dart`

High-value new tests:

| Area | Test file | Coverage |
| --- | --- | --- |
| Download task serialization | `test/services/download/download_task_test.dart` | JSON compatibility, defaults, old records without `taskType`, backend parsing. |
| Download queue | `test/services/download/download_queue_test.dart` | Slot acquisition, max concurrency, release, transfer, cancellation. |
| Download path safety | `test/services/download/download_file_cleanup_test.dart` | Under-download-dir checks, relative path resolution, Windows separators, empty parent cleanup with temp dirs. |
| Magnet helpers | `test/services/download/magnet_test.dart` | Tracker injection dedupe, info-hash extraction from magnet and stream URLs. |
| Player scheduler | `test/ui/pages/player/player_webview_scheduler_test.dart` | Worker selection, source affinity, unhealthy workers, captcha/video active job maps. |
| Player source helpers | `test/ui/pages/player/player_source_helpers_test.dart` | Alias extraction, recommendation tag normalization, source key generation. |
| Video controls helpers | `test/ui/widgets/video_player_controls/video_controls_test.dart` | Episode selection, source labels, playback speed formatting where extracted. |
| Bangumi details helpers | `test/ui/pages/bangumi_details/bangumi_details_helpers_test.dart` | Summary parsing, infobox summarization, site sorting, person matching. |

Testing guidance:

- Prefer pure Dart unit tests for extracted helpers.
- Use widget tests only for stable UI behavior that is easy to assert.
- Avoid tests that require real network, real WebView, real media playback, or
  platform channels.
- For platform-channel-heavy services, inject thin interfaces or callbacks.
- Use temp directories for file operations.

## Suggested Sub-Agent Work Packages

### Package A: Video Controls Extraction

Prompt:

```text
Refactor `lib/ui/widgets/video_player_controls.dart` by extracting one cohesive
private widget/helper cluster into a new file under
`lib/ui/widgets/video_player_controls/`. Keep behavior unchanged. Add tests only
for pure helpers that become testable. Run `dart format lib test`,
`flutter analyze`, and `flutter test`.
```

Acceptance:

- File size is reduced.
- Public `CustomVideoControls` API is unchanged.
- Analyzer and tests pass or pre-existing failures are documented.

### Package B: Download Model And Queue

Prompt:

```text
Extract `DownloadTask`, related enums, JSON serialization, magnet helper logic,
and queue slot logic from `lib/services/download_manager.dart` into focused
files under `lib/services/download/`. Preserve persisted JSON keys and runtime
behavior. Add unit tests for serialization, magnet helpers, and queue behavior.
Run formatting, analyzer, and tests.
```

Acceptance:

- Existing imports compile.
- JSON round-trip tests pass.
- Queue behavior is covered without starting real downloads.

### Package C: Player WebView Scheduler

Prompt:

```text
Extract WebView worker slot state and scheduling decisions from
`lib/ui/pages/player_page.dart` into a testable scheduler module. The scheduler
must not import Flutter widget classes or build UI. Keep widget creation in the
page for now. Add unit tests for worker selection, active job bookkeeping,
source affinity, and unhealthy worker handling.
```

Acceptance:

- Scheduler can be tested without WebView.
- `PlayerPage` behavior remains unchanged.
- Existing worker stats tests still pass.

### Package D: Bangumi Details Helpers

Prompt:

```text
Extract pure parsing/sorting helpers from `lib/ui/pages/bangumi_details_page.dart`
into `lib/ui/pages/bangumi_details/bangumi_details_helpers.dart`. Add unit tests
for summary parsing, infobox summarization, site sorting, and person matching.
Do not redesign the UI.
```

Acceptance:

- Helpers are covered by tests.
- Page output behavior is unchanged.
- Analyzer and tests pass.

### Package E: Player Page Widget Sections

Prompt:

```text
Extract one display-only section from `lib/ui/pages/player_page.dart` into a
widget under `lib/ui/pages/player/widgets/`. The extracted widget should receive
all required data and callbacks through its constructor. Do not move source
loading or playback logic in this package.
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
- Did `dart format lib test` run?
- Did `flutter analyze` run?
- Did `flutter test` run?
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

## Recommended First Three Changes

1. Extract `DownloadTask` and its enum types from `download_manager.dart`, then
   add JSON compatibility tests.
2. Extract `_SystemTimeDisplay` and mobile lock UI from
   `video_player_controls.dart`.
3. Extract pure helper functions from `bangumi_details_page.dart` and add tests.

These are good first changes because they reduce large files without forcing a
major app architecture decision.
