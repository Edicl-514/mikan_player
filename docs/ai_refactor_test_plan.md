# AI Refactor And Test Plan

This document is a working plan for AI agents that will refactor the Dart side
and add tests. Treat it as the source of truth for task boundaries, validation,
sequencing, and current progress.

Status date: 2026-07-13 (updated after the BT stream stabilization review).
Counts via `rg -c '^'` / `wc -l`. Latest checkpoint:

**Phase 3 BT stream stabilization** — fixes the review findings from the
initial `BtStreamCapability` checkpoint. New pure-Dart
`bt_stream_restore_coordinator.dart` registers jobs before starting them,
deduplicates by hash, invalidates stale work with generation tokens, retains
cancelled jobs for deterministic awaiting, and blocks work after dispose.
`DownloadManager` cancels an old restore before stream reattach/activation and
injects a controllable restore sleeper for tests. `LibtorrentBtBackend`
aggregates `BtBackend` + `BtStreamCapability`, so the manager no longer requires
the concrete `LibtorrentBackend`. Five coordinator tests plus five new manager
tests cover zero-delay early return, duplicate scheduling, cancel→replacement,
rapid deactivate→reattach→deactivate, abstract fake injection, and dispose.
The prior 40ms wall-clock race tests now use explicit delay gates. Manager
2391→2428; coordinator 104 lines. Test count: 670→680 across 40 test files.

Prior checkpoint:

**Phase 3 BtStreamCapability** — narrow injectable
libtorrent HTTP-streaming surface. New
`lib/services/download/bt_stream_capability.dart` (`BtStreamCapability`:
`streamIdForHash` / `fileIdxForHash` / `fileSizeForHash` /
`stopStreamForHash` / `restoreBackgroundDownload`). `LibtorrentBackend`
now `implements BtBackend, BtStreamCapability` (existing helpers become
interface overrides; no behavior change). Manager keeps playback policy
(`_activeStreamHashes`, delayed restore, pause/remove guards) but exposes
deterministic test seams: injectable `streamRestoreDelay` (prod 300ms,
tests default 0), `_pendingStreamRestores` await map,
`setBackendKindForTesting` / `getOrCreateStreamUrlForTesting` /
`isActiveStreamForTesting` / `waitPendingStreamRestoresForTesting`. New
`download_manager_bt_stream_test.dart` (9 tests): create-stream /
no-stream background / reattach-after-stop / stop→restore priorities /
deactivate-all / pause-during-restore race / remove-during-restore race /
stats+fileSize merge / capability surface. Manager 2347→2391 (+44 for
seams). Test count: 661→670 across 39 test files.

Prior same-day:

**Stabilization checkpoint (2026-07-13)** — fixes review findings before the
next architectural extraction: HLS stops at task-removal boundaries; shutdown
dispatches every active libtorrent resume-data save before awaiting; libtorrent
prefers its live file selection during background restore; rqbit's fake matches
its stream-URL contract; and Mikan/DMHY loads use provider-local request tokens
to reject stale results after a source context change. Regression tests cover
each seam. Test count: 652→661 across 38 test files.

Prior committed checkpoint:

**Phase 3 BT Commit 3 of 3** (`2d1f725`) — `DownloadManager` BT core ops
dispatch through `RqbitBackend` / `LibtorrentBackend`. Manager drops
`_nativeSession` + id/stream/file maps (−318 LOC: 2660→2342). Streaming
helpers added on `LibtorrentBackend` (`stopStreamForHash` /
`restoreBackgroundDownload` / stream+file accessors). New
`download_manager_bt_test.dart` (5 characterization tests). Full
`BtStreamBackend` still deferred; manager keeps playback/stream policy
(`_activeStreamHashes`, restore orchestration). Test count: 647→652.

Prior same-day: Sample controller (`1fc8f90`), BT Commit 2 impls (`a10a1c9`),
Source controller (`45a457a`), BtBackend interface (`86c37d0`).

The immediately-prior checkpoint (2026-07-12) added: (1) fixed three latent
m3u8 parse quirks (METHOD token parse, BANDWIDTH vs AVERAGE-BANDWIDTH boundary,
colon-delimited EXT tag match); (2) physically extracted plain-HTTP
orchestration into `http_download_job.dart` (`runHttpFileDownload` +
`ActiveHttpDownload`); (3) extracted HLS resolve+segment download into
`m3u8_downloader.dart` (`resolveHlsSegments` + `runM3u8Download`), with
per-segment bytes going through the existing `HttpFileDownloadPort` (no
separate M3u8DownloadPort needed). Manager keeps slots / task map /
persistence / notifyListeners / pause-cancel registry. `download_manager.dart`
was 2660 lines (−304 from prior 2964); unchanged this checkpoint.

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
with `rg -c '^'` at this checkpoint. Responsibility ownership and testability
remain the primary completion criteria; line count is only a secondary signal.

| File | Initial | Current | Change | Main remaining issue |
| --- | ---: | ---: | ---: | --- |
| `lib/ui/pages/player_page.dart` | 8318 | 6879 | -1439 | Playback + WebView/scheduler/captcha orchestration remain on page; display trees extracted; **controllers #1–#3** own episode / Mikan+DMHY / sample-search **state mutations** only. Playback controller, scheduler dispatch planning still page-owned. |
| `lib/services/download_manager.dart` | 3285 | 2428 | -857 | HTTP + HLS extracted; BT core ops use backend ports; `BtStreamRestoreCoordinator` now owns delayed-job bookkeeping/generations. Manager keeps slots/tasks/persistence + playback policy and the actual background-restore state mutation. |
| `lib/ui/widgets/video_player_controls.dart` | 3103 | 1121 | -1982 | Fully decomposed: SettingsPanel + MobileGestureAndLockLayer + MobileFloatingLockButton + SystemTimeDisplay + EpisodeSidePanel + SourceListPanel are now separate files. No remaining coherent controls boundary. |
| `↳ lib/ui/widgets/video_player_controls/settings_panel.dart` | 1141 | 939 | -202 | Source list extracted as `SourceListPanel`; panel keeps reactive source listener state for the menu subtitle. |
| `lib/ui/pages/bangumi_details_page.dart` | 3096 | 2732 | -364 | Data loading, favorite state, and the mobile inline comment rendering remain on the page; relations, sites, and the wide-layout comments section are extracted. |

## Progress Snapshot

Current validation baseline:

- `flutter analyze`: 0 issues.
- `flutter test`: 680 tests passing across 40 test files.
- Current checkpoint adds (over the 2026-07-11 source-list / sites /
  comments / bt-resource-list leaf-widget checkpoint): the comment-HTML
  rendering helpers `normalizeBangumiImageSrc` / `isBangumiSmileUrl` /
  `bangumiSmileSize` promoted from private static methods on
  `PlayerComments` to top-level functions in `player_comments.dart`
  (behavior-preserving; `_commentSmileSize`'s `dynamic element` glue was
  refactored to take `String?` width/height attributes so it is unit-
  testable without a `flutter_widget_from_html` DOM node). Two new
  `PlayerComments` widget tests cover the `text_mask` body
  (`BangumiMaskText` on the rendered tree) and the Bangumi smile `<img>`
  route (asserts the first-frame `CachedNetworkImage.imageUrl` and the
  BoxFit/size wiring; `_maybeStartLoading`'s post-frame
  `ImageCacheService.initialize()` `MissingPluginException` is caught
  inside the widget and never reaches the test Zone). One new
  `CommentsSection` widget test covers `text_mask` on the wide-layout
  card. Twenty-one pure-helper unit tests cover the host-rewrite,
  smile-URL classification, and `Size` math (fallback, scale>=1,
  landscape/portrait, both clamp branches, single-attr fallbacks).
  **Same checkpoint adds the Package B HTTP download job characterization
  seam:** new files
  `lib/services/download/http_file_download_port.dart`
  (`HttpFileDownloadPort` abstract interface + `HttpFileDownloadHandle`
  + prod `IoHttpFileDownloadPort` backed by `dart:io.HttpClient`) and
  `test/services/download/http_file_download_port_test.dart` (8 contract
  + fake tests) and `test/services/download/download_manager_http_test.dart`
  (15 manager-side characterization tests). `download_manager.dart` now
  routes the HTTP file-download path through `_httpPort.start(...)`; the
  manager keeps the throttle / speed / notifyListeners / cancel-flag
  check before `sink.add`, plus the file IOSink — so the original
  byte-for-byte behavior (non-2xx throws before file creation, partial
  file retained on cancel with no new chunks written, error-while-cancel-
  flagged treated as paused, content-length fallback to
  `outputFile.lengthSync()`, `resumeTask` deletes partial + restarts with
  NO Range request) is preserved and now locked down by tests. m3u8 / HLS
  / BT / libtorrent / rqbit paths intentionally untouched. Added
  `DownloadManager.forTesting({HttpFileDownloadPort? httpPort})` and a
  small `...ForTesting` API surface (`setDownloadDirForTesting`,
  `setDownloadLimitMbpsForTesting`, `seedHttpTaskForTesting`,
  `removeHttpTaskForTesting`, `downloadHttpFileForTesting`,
  `throttleHttpChunkForTesting`);
  all `@visibleForTesting` and `-ForTesting`-named to flag any accidental
  production use during review.
- **Same checkpoint adds the HTTP throttle clock-injection and the
  m3u8/HLS playlist-resolution seam.** Throttle: `DownloadManager.forTesting`
  now takes optional `clock` / `sleep` overrides (default `DateTime.now` /
  `Future.delayed`); `_throttleHttpChunk` reads `_now()` / `_sleep(...)` so
  the budget-exhaustion `Future.delayed` branch is deterministically
  testable. New `resetHttpThrottleForTesting()` re-pins the window start to
  the fake clock. 3 manager-side tests (`download_manager_http_test.dart`)
  cover sleep-once-on-exhaustion, no-sleep-when-elapsed>=1000ms, and
  `resetHttpThrottleForTesting` re-pinning. m3u8 seam: new
  `lib/services/download/m3u8_playlist_port.dart` ships (a) pure
  `parseM3u8Playlist(content, playlistUri)` returning a sealed
  `M3u8Playlist` (`M3u8MasterPlaylist.variants` sorted BANDWIDTH-desc /
  `M3u8MediaPlaylist.segments`, throwing `'暂不支持下载加密HLS流'` on an
  encrypted `#EXT-X-KEY` and `'未找到可下载的HLS分片'` on an empty media
  playlist), and (b)
  `M3u8PlaylistPort` abstract + `IoM3u8PlaylistPort` prod (a fresh
  `HttpClient` per `fetchText`, replicating `_fetchHttpText` wire behavior
  including the non-2xx `Exception('HTTP <code>')` throw). `_resolveHlsSegments`
  now fetches through `_m3u8Port` and delegates the parse to `parseM3u8Playlist`;
  the recursion, `depth > 4` throw, and highest-BANDWIDTH selection stay in the
  manager (depth-naive parser). `_downloadM3u8File`'s per-segment loop is
  intentionally NOT touched; the now-orphaned `_fetchHttpText` was deleted
  (so `dart:convert` is no longer imported by the manager). New tests:
  `test/services/download/m3u8_playlist_port_test.dart` (21 pure-parser +
  port-contract tests incl. a `FakeM3u8PlaylistPort`) and
  `test/services/download/download_manager_m3u8_test.dart` (7 manager-side
  `_resolveHlsSegments` characterization tests via
  `resolveHlsSegmentsForTesting(...)` + the fake port: single media playlist,
  master→variant recursion, `depth > 4`, encrypted-key, empty segments,
  headers+cookies forwarding). Three latent parser defects in the original
  implementation (`METHOD=NONE` substring check / `BANDWIDTH=` matching the
  suffix of `AVERAGE-BANDWIDTH` / `startsWith` without a colon delimiter) were
  **fixed as an explicit, approved behavior correction** and are locked down by
  parser tests; they are not behavior-preserving extraction semantics.
- **Episode controller checkpoint (2026-07-12, `2089446`) added Phase 2
  controller #1** — see prior plan text / commit message. 374-line pure-Dart
  state object + 27 composition tests. Manual episode-switch smoke still
  pending.
- **Source controller Sub-commit A (2026-07-13, `45a457a`) adds Phase 2
  controller #2 (Mikan+DMHY only).** New files
  `lib/ui/pages/player/player_source_controller.dart` (273 lines) +
  `test/ui/pages/player/player_source_controller_test.dart` (452 lines, 25
  composition tests). Seven private page fields moved
  (`_isLoadingMikan` / `_mikanError` / `_mikanAnime` / `_mikanResources` /
  `_isLoadingDmhy` / `_dmhyError` / `_dmhyResources`). Page drives via
  mutators (`markMikanLoading` / `markMikanReloadForEpisode` / `setMikanAnime`
  / `setMikanResources` / `markMikanIdle` / `setMikanNotFound` /
  `setMikanError` / `markDmhyLoading` / `setDmhyResources` / `setDmhyError` /
  `resetForSwitching`) and reads unmodifiable views. Loader method BODIES
  stay on the page (they reach `widget.anime.*`, call Rust APIs, check
  `mounted` plus the provider-local request token, wrap in `setState`).
  Preserved asymmetries:
  `markMikanReloadForEpisode` does NOT clear `mikanError` (unlike
  `markMikanLoading`); `resetForSwitching` preserves `mikanAnime` so
  `_reloadMikanResourcesForEpisode` can reuse the binding. Sample-source
  state deferred to Sub-commit B. `player_page.dart` 6849→6848 (−1).
  Grep confirms zero remaining bare-field reads of the 7 moved fields.
  **Manual smoke required:** Mikan/DMHY source load on enter; episode change
  → reload-for-episode path; source-panel loading/error/count UI; leave /
  re-enter.
- **BT Commit 1 of 3 (2026-07-13, `86c37d0`) adds Phase 3 interface seam.**
  New files `lib/services/download/bt_backend.dart` (725 lines) +
  `test/services/download/bt_backend_test.dart` (705 lines, 46 contract
  tests). PURELY ADDITIVE — `download_manager.dart` untouched (still 2660).
  `abstract interface class BtBackend` captures core ops
  (`ensureInitialized` / `addTorrent` / `pauseTorrent` / `resumeTorrent` /
  `removeTorrent` / `getStats` / `isTorrentManaged` / `setFilePriorities` /
  `saveResumeData` / `applySpeedLimits`) with DTOs `BtTorrentHandle` /
  `BtTorrentStats` / `BtFileInfo`. `FakeBtBackend` tracks torrents by
  lowercased info-hash, records `callLog`, injects per-method exceptions.
  Streaming control deferred to follow-up `BtStreamBackend` (reattach /
  stop-only / warmup / restore-background / setActiveStream / reader
  teardown). Key commit-3 adaptation: `LibtorrentBackend` absorbs
  `_ltTorrentIdsByHash` translation so manager stops tracking native ids.
- **Real player smoke run completed (2026-07-11)** after the
  episode-panel and download-cleanup checkpoints. Episode-controller +
  Source-controller + BT-interface checkpoints are behavior-preserving
  extractions; characterization / composition tests cover the new seams,
  but manual smoke (episode switch, Mikan/DMHY reload, HTTP/HLS/BT
  download) is still recommended before the next architectural checkpoint
  that depends on those seams.
- No generated Drift/Flutter Rust Bridge files were refactored by this
  plan.

Phase status:

| Phase | Status | Completed | Main remaining work |
| --- | --- | --- | --- |
| Phase 0 | Complete | Analyzer/test baseline and worktree checks; **real player/WebView smoke run recorded 2026-07-11** (source search, captcha-to-video, cancel, source/episode switch, leave/re-enter). | Re-record after the next architectural checkpoint that touches WebView/playback/platform. **Episode-controller (2026-07-12) + Source-controller (2026-07-13) touch episode switching / source reload** — both smokes pending. |
| Phase 1 | Partial | System time, mobile lock/gesture cluster, SettingsPanel, pure Bangumi helpers, **EpisodeSidePanel**, **PlayerRecommendations**, **PlayerComments**, **RelationsSection**, **SourceListPanel**, **SitesSection**, **CommentsSection**, **BtResource view-model + BtResourceList**, pure BT-tag helpers, and **comment HTML rendering helpers (`normalizeBangumiImageSrc` / `isBangumiSmileUrl` / `bangumiSmileSize`) promoted to top-level + 23 widget/helper tests** — each with `testWidgets`/unit coverage. | Player data models/enums; mobile inline comment rendering unification (redesign, deferred). |
| Phase 2 | Stabilizing | Scheduler B1-B6; display widgets; **`PlayerEpisodeController` (#1)** + **`PlayerSourceController` (#2 Mikan+DMHY, stale-request tokens)** + **`PlayerSampleSourceController` (#3 sample search, 331 lines, 15 tests)**. | Prop-update semantics, dispatch planning/affinity, playback controller, integration smoke. |
| Phase 3 | Stabilizing | Task/queue/cleanup/store; HTTP + m3u8 boundaries; BT backend ports; `BtStreamCapability`; **generation-safe `BtStreamRestoreCoordinator` + 19 coordinator/manager stream tests** (manager 2428 LOC). | Manual rqbit/libtorrent background → playback → leave/rapid re-enter smoke is required. Do not extract more stream policy until this passes. |
| Phase 4 | Partial | Pure parsing/sorting helpers and tests; **`RelationsSection` display widget + widget tests**; **`SitesSection` display widget + widget tests**; **`CommentsSection` display widget (wide layout) + widget tests (incl. `text_mask` rendering)**. | Details controller; mobile inline comment rendering; header/characters/episodes section widgets. | |
| Phase 5 | Not started | None. | Start only after controller/widget boundaries are stable. |

## Target Dart Shape

Use this structure as a direction, not a requirement to complete in one change.
It is a **target shape**, not a literal inventory: the current facade files
remain at `lib/services/download_manager.dart`,
`lib/ui/widgets/video_player_controls.dart`, and
`lib/ui/pages/bangumi_details_page.dart`. Do not move a facade solely to make
this diagram true.

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
  bt_stream_capability.dart
  bt_stream_restore_coordinator.dart
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

Status: complete. The current checkpoint is 0 analyzer issues and 680 passing
tests across 40 test files. Re-run the baseline after dependency, Flutter SDK,
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
- Comment HTML rendering helpers (`normalizeBangumiImageSrc` /
  `isBangumiSmileUrl` / `bangumiSmileSize`) promoted from private static
  methods on `PlayerComments` to top-level functions in
  `lib/ui/pages/player/widgets/player_comments.dart`. Behavior is
  preserved; only `_commentSmileSize`'s `dynamic element` glue was
  refactored to take `String?` width/height attrs (the DOM-element call
  site still does `element.attributes['width']`). 2 widget tests cover
  `text_mask` (`BangumiMaskText` on the rendered tree) and the Bangumi
  smile `<img>` route (first-frame `CachedNetworkImage.imageUrl` + size/
  fit wiring; `_maybeStartLoading`'s post-frame
  `ImageCacheService.initialize()` `MissingPluginException` is swallowed
  inside the widget); 1 `CommentsSection` wide-layout `text_mask` widget
  test; 21 pure-helper unit tests cover host rewriting, smile-URL
  classification, and `Size` math (fallback, scale>=1, landscape/portrait,
  both clamp branches, single-attr fallbacks).

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
workers, ownership, and token ordering. **`PlayerEpisodeController`
(Phase 2 controller #1, this checkpoint)** owns episode-state mutations
(`currentEpisode` / `playableEpisodes` / `currentEpisodeListenable` /
`currentEpisodeNumbers`); the page drives it via `selectEpisode` /
`resolveByOffset` / `reset` / `clearForDispose` and reads back the read-only
views. The page keeps all episode-change side-effects (player stop, search-
subscription cancel, the big `setState` resetting ~30 playback/source fields,
history save, danmaku+comments reload, BT-existing-download probe, source-
loader cascade). 27 pure-Dart composition tests; manual episode-switch smoke
is pending (see Progress Snapshot above).

Still page-owned:

- Pending `SearchPlayResult` collection and source-tier/enqueue metadata.
- Source-affinity job choice and the pump loop that invokes page side effects.
- Captcha/video result business handling, probe/register, logging, and UI text.
- Source loading, playback, comments, recommendations, and the BT resource
  list remain page-owned for behavior; episode-change **side-effects** remain
  page-owned but the **mutated state** for `currentEpisode`/`playableEpisodes`
  lives in `PlayerEpisodeController`; display trees for recommendations /
  comments / `BtResourceList` are extracted widgets wired back via callbacks.

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
4. ✅ Extract `PlayerEpisodeController` as the lowest-risk controller — done in
   the Episode-controller checkpoint (2026-07-12). Pure-Dart state object
   (`lib/ui/pages/player/player_episode_controller.dart`, 374 lines) mirrors
   the `PlayerWebViewScheduler` precedent. Page drives it via `selectEpisode`
   (returns `EpisodeSelectionResult{previous; next; changed}` DTO) /
   `resolveByOffset` (non-mutating pure resolver) / `reset` / `clearForDispose`,
   reads back immutable views. Page keeps ALL side-effects. 27 composition
   tests in `test/ui/pages/player/player_episode_controller_test.dart` (595
   lines); max risk is the `_onSkipNext` wiring (`resolveByOffset(1) ->
   _onEpisodeSelected(next)`) — manual episode-switch smoke required before
   the next Phase 2 architectural checkpoint. The Episode controller was the
   one identified latent finding: `BangumiEpisode ==` already overrides `==`
   with full value-equality (`lib/src/rust/api/bangumi.dart:256-267`), and
   both the controller guard and the `validateInvariants` notifier-equality
   check stay `.id`-based (byte-for-byte with `player_page.dart:4827`),
   which is strictly finer than `==` — preserved, not changed.
  5. ✅ Extract Mikan+DMHY source-loading state into `PlayerSourceController`
    (Sub-commit A, 2026-07-13, commit `45a457a`). Pure-Dart state object
    (`lib/ui/pages/player/player_source_controller.dart`, 236 lines) mirrors
    the Episode-controller precedent. 7 private fields moved; page keeps all
    loader bodies / `widget.anime.*` / `mounted` / `setState` / Rust API calls.
    Mutators: `markMikanLoading` / `markMikanReloadForEpisode` / `setMikanAnime`
    / `setMikanResources` / `markMikanIdle` / `setMikanNotFound` / `setMikanError`
    / `markDmhyLoading` / `setDmhyResources` / `setDmhyError` /
    `resetForSwitching`. Preserved asymmetries: reload-for-episode does NOT
    clear `mikanError`; `resetForSwitching` preserves `mikanAnime`. 22
    composition tests. Sample-source state (`_isLoadingSample` /
    `_sampleError` / `_samplePlayPages` / `_sampleSuccessfulSources` /
    `_pageEnqueueSeq` / …) deferred to **Sub-commit B**.
  5b. ✅ Extract sample-source state into sibling `PlayerSampleSourceController`
    (2026-07-13, `1fc8f90`). 331 lines + 15 composition tests. 11 fields
    moved; page keeps WebView/scheduler/captcha/stream side-effects.
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

Status: stabilizing. Task/store/queue/cleanup, HTTP/HLS jobs, BT backend ports,
and stream-restore coordination are extracted and tested. Native playback and
download smoke is the required gate before any further stream-policy move.

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
  3. ✅ Package B + physical HTTP job: `HttpFileDownloadPort` +
     `http_download_job.dart` (`runHttpFileDownload` / `ActiveHttpDownload`).
     Manager thin-wraps slots + cancel registry + persist/notify.
  4. ✅ m3u8: playlist port + pure parser (quirks fixed) +
     `m3u8_downloader.dart` (`resolveHlsSegments` + `runM3u8Download`).
     Segments reuse `HttpFileDownloadPort` (no separate segment port).
  5. ✅ BT Commit 1 of 3 (2026-07-13, commit `86c37d0`): pure `BtBackend`
     interface + DTOs (`BtTorrentHandle` / `BtTorrentStats` / `BtFileInfo`) +
     `FakeBtBackend` + 46 contract tests in `bt_backend.dart` (725 lines) /
     `bt_backend_test.dart` (705 lines). PURELY ADDITIVE — manager untouched.
     Core ops: `ensureInitialized` / `addTorrent` / `pauseTorrent` /
     `resumeTorrent` / `removeTorrent` / `getStats` / `isTorrentManaged` /
     `setFilePriorities` / `saveResumeData` / `applySpeedLimits`. Streaming
     control deferred to a follow-up `BtStreamBackend`.
  6. ✅ BT Commit 2 of 3 (2026-07-13, `a10a1c9`): `RqbitBackend` (178) +
     `LibtorrentBackend` (598) with injectable seams; `addTorrent` gained
     optional `seedMode`/`resumePath`. Manager still inlines until Commit 3.
  7. ✅ BT Commit 3 of 3 (2026-07-13, `2d1f725`): manager rewrites BT core
     through `_backendFor` → `RqbitBackend`/`LibtorrentBackend`. Drops native
     session maps (−318 LOC). Streaming helpers on `LibtorrentBackend`. 5
     manager BT tests.
  8. ✅ BT stream stabilization (2026-07-13): `LibtorrentBtBackend` aggregate
     injection + pure `BtStreamRestoreCoordinator`. Fixes the zero-delay
     register/remove race and cancels stale delayed restores on reattach /
     reactivation / dispose. Wall-clock race tests replaced with explicit
     delay gates. Further stream-policy extraction is blocked on native smoke.

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

Current baseline: 680 tests across 40 test files.

Covered areas:

- Reusable captcha/video runners without a real `InAppWebView`.
- Scheduler statistics, worker selection, bookkeeping, pump decisions,
  state transitions, pump coordinator, and composed scheduler invariants.
- Player source/BT/tag helper behavior.
- **`PlayerEpisodeController` composition tests** (pure Dart, `flutter_test`):
  seeding (released-initial preserved; unreleased-initial + released fallback;
  unreleased-initial + no released fallback), `selectEpisode` guards +
  notifier-fires-once contract, `resolveByOffset` is side-effect-free
  (notifier-listener counter stays at 0 across all resolve calls including both
  clause boundaries), `EpisodeNumbers` math (id-found-in-list → relative=idx+1;
  id-not-found → relative==absolute; fresh-`allEpisodes` snapshot proves no
  caching), `reset({newAllEpisodes,newInitial})` recomputes + re-seeds, `reset()`
  no-op, `validateInvariants` empty across the public-surface exercise + the
  one reachable failure branch (selecting a released-but-phantom episode).
- **`PlayerSourceController` composition tests** (25 tests, pure Dart):
  construction defaults; mikan load lifecycle (loading → anime → resources);
  not-found path (`"未找到番剧"`); error path; episode.id==0 idle path;
  reload-for-episode preserves error (asymmetry); reload-for-episode preserves
  anime; dmhy lifecycle + error; `resetForSwitching` clears transient state but
  preserves `mikanAnime`; provider-local request tokens invalidate stale
  Mikan/DMHY completions on replacement, context switch, and disposal;
  unmodifiable list views; `isLoadingAny` / `hasErrorAny` convenience getters.
- **`BtBackend` contract tests** (46 tests): `FakeBtBackend` init / add /
  pause / resume / remove / stats / isManaged / setFilePriorities /
  saveResumeData / applySpeedLimits; exception injection per method; callLog
  ordering; DTO field presence; `FakeBtBackend is BtBackend` conformance.
- **`PlayerSampleSourceController` composition tests** (15 tests): defaults,
  load-token bump/isCurrent, beginNewSearchReset, appendPlayPage enqueue seq,
  progress map, successful sources, sort-by-tier, resetForSwitching,
  unmodifiable views, validateInvariants.
- **`RqbitBackend` / `LibtorrentBackend` unit tests** (~25 tests): injectable
  seams; init idempotency; add/pause/resume/remove; stats mapping; no-ops for
  rqbit priorities/resume/speed; libtorrent priorities + resumePath remove.
- **`DownloadManager` BT characterization** (`download_manager_bt_test.dart`,
  5 tests): forTesting injects Fake/backends; start/pause/resume/remove/stats
  dispatch through `BtBackend` without real FFI.
- **`BtStreamCapability` / stream lifecycle**
  (`download_manager_bt_stream_test.dart`, 14 tests):
  `startDownload(forPlayback:true|false)`; `getOrCreateStreamUrl` reuse +
  recreate after stop; `setActiveStream(false|null)` stop→background restore
  (priorities + resume); pause/remove races abort pending restore body;
  zero-delay early-return cleanup; aggregate fake injection; rapid reattach
  cancellation + replacement generation; dispose cancellation; `updateStats`
  file-size merge; capability surface on `LibtorrentBackend`. Injectable delay
  gates + `waitPendingStreamRestoresForTesting` keep races deterministic.
- **`BtStreamRestoreCoordinator`** (5 pure-Dart tests): zero-delay cleanup,
  duplicate dedupe, cancel→replacement, awaiting logically cancelled jobs,
  and dispose invalidation.
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
- `PlayerComments` widget: loading, error, empty, populated, sort-button,
  `text_mask`→`BangumiMaskText`, and Bangumi smile `<img>`→`CachedNetworkImage`
  URL/size/fit wiring; pure-helper unit tests for
  `normalizeBangumiImageSrc` / `isBangumiSmileUrl` / `bangumiSmileSize`.
  `RelationsSection`: loading, empty, populated, dark-mode, and
  relation-tap forwarding.
- `SourceListPanel` widget: empty, populated, selection highlight, tap
  callback, `ValueListenable` reactivity; plus pure-helper unit tests
  (`sourceDisplayLabel` / `clampSourceIndex` / `resolveActiveOnlineSourceIndex`).
- `SitesSection` widget: empty, populated, kind-badge labels, tap-to-launch
  forwarding, dark-bg, Scrollbar wiring.
- `CommentsSection` widget (wide layout): loading, empty, populated, rate
  stars, load-more spinner on/off, dark-bg, HtmlWidget no-throw smoke,
  `text_mask`→`BangumiMaskText`.
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
- HTTP download port + manager-side characterization (`http_file_download_port_test.dart`
  + `download_manager_http_test.dart`): 2xx / 404 / 500 (start throws before
  `openWrite` so **no file created** on error); headers + cookies captured
  verbatim (`Range`/`User-Agent`/`Referer`/`Cookie`); `pauseTask` retains
  partial bytes; post-cancel chunk NOT written (`cancelClosesStream:false`
  bridge drives the original `await-for` break); mid-stream error →
  status=error; error while cancel-flag-set → paused (not error);
  unknown `Content-Length` falls back to `outputFile.lengthSync()`;
  throttle no-delay branches (limit==0, within-budget); `resumeTask` deletes
  existing partial file BEFORE restarting with NO `Range` header; factory
  `DownloadManager()` still `same()`-idempotent (zero-arg unchanged).

Important uncovered areas:

- No meaningful `testWidgets` coverage for PlayerPage, BangumiDetailsPage, or
  CustomVideoControls.
- No integration-test directory or real WebView/media lifecycle coverage.
- No production-wiring test around `SharedPreferences`; persistence tests use
  the intended injected key-value interface.
- ~~No HTTP/m3u8/backend lifecycle tests.~~ HTTP file-download lifecycle
  is now covered by Package B (2xx / 404 / 500 / headers+cookies /
  cancel-keeps-partial / mid-stream error / cancel-flag-treats-as-paused /
  content-length fallback / throttle no-delay / resume-deletes-partial), the
  throttle's budget-exhaustion `Future.delayed` branch is covered by the
  injectable clock/sleeper seam (sleep-once-on-exhaustion,
  no-sleep-when-elapsed>=1000ms, `resetHttpThrottleForTesting` re-pinning),
  and m3u8/HLS **playlist resolution** is covered by the
  `M3u8PlaylistPort` + `parseM3u8Playlist` seam (master→variant recursion,
  BANDWIDTH-desc selection, `depth > 4`, encrypted-key, empty-segments,
  headers+cookies forwarding). m3u8 **per-segment download** now covers
  ordered concatenation plus pause/remove at the segment boundary (a removed
  task cannot request or write a later segment). BT/libtorrent/rqbit lifecycle
  coverage remains deliberately narrower than the production stream lifecycle.
- ~~Comment HTML custom-widget rendering (masked text and Bangumi smile
  images) had no focused widget coverage after its move into
  `PlayerComments`.~~ Covered as of the comment-HTML-rendering-helper
  checkpoint: the `text_mask` body renders `BangumiMaskText`, the Bangumi
  smile `<img>` route yields a `CachedNetworkImage` with the rewritten
  smile URL, and the pure `normalizeBangumiImageSrc` /
  `isBangumiSmileUrl` / `bangumiSmileSize` host classify + size math are
  unit-tested directly. The avatar `CachedNetworkImage` first-frame
  decode path and the smile `<img>`'s network/cached-image byte fetch
  remain explicitly uncovered (platform-channel-driven).

High-value new tests:

| Area | Test file | Coverage |
| --- | --- | --- |
| Download task serialization | `test/services/download/download_task_test.dart` | JSON compatibility, defaults, old records without `taskType`, backend parsing. |
| Download queue | `test/services/download/download_queue_test.dart` | Slot acquisition, max concurrency, release, transfer, cancellation. |
| Download path safety | `test/services/download/download_file_cleanup_test.dart` | Under-download-dir checks, relative path resolution, Windows separators, empty parent cleanup with temp dirs. |
| Magnet helpers | `test/services/download/magnet_test.dart` | Tracker injection dedupe, info-hash extraction from magnet and stream URLs. |
| Player scheduler | `test/ui/pages/player/player_webview_scheduler_test.dart` | Worker selection, source affinity, unhealthy workers, captcha/video active job maps. |
| Player episode controller (NEW) | `test/ui/pages/player/player_episode_controller_test.dart` | Pure-Dart composition tests mirroring the scheduler test pattern. Seeding (`released-initial` preserved; `unreleased-initial` + released fallback; `unreleased-initial` + no released fallback). `selectEpisode` guards (unreleased → no-op; same-`.id` → no-op; identical → no-op; different-released → mutates + notifier fires exactly once). `resolveByOffset` is **side-effect-free** (sub-test: notifier-listener counter stays at 0 across every resolve call AND at both clause boundaries — last→null and first→null). `EpisodeNumbers` math (`id`-found-in-list → `relative`=idx+1; `id`-not-found → `relative==absolute`; fresh-`allEpisodes` snapshot to `currentEpisodeNumbersAgainst` proves no caching). `reset({newAllEpisodes, newInitial})` recomputes `playableEpisodes` and re-seeds `currentEpisode` with notifier fire; `reset()` no-op. `validateInvariants` empty across the public-surface exercise; one reachable failure branch (check #2: selecting a released-but-phantom episode filtered out by `withoutPhantomEpisodes()`) is locked by an explicit test; the other four checks are unreachable via the public surface and regression-guarded by the surface-exercise test (no `@visibleForTesting` mutators added, per the scheduler precedent). |
| Player source helpers | `test/ui/pages/player/player_source_helpers_test.dart` | BT-resource dedup/sorting, view-model dispatch, resource-content routing, recommendation tag normalization. |
| Video controls helpers | `test/ui/widgets/video_player_controls/episode_side_panel_test.dart`, `source_list_panel_test.dart` | Episode selection and source-list behavior where extracted. |
| Bangumi details helpers | `test/ui/pages/bangumi/bangumi_details_helpers_test.dart` | Summary parsing, infobox summarization, site sorting, person matching. |
| Source-list panel | `test/ui/widgets/video_player_controls/source_list_panel_test.dart` | Empty, populated, selection highlight, tap callback, `ValueListenable` reactivity, pure-helper dispatch. |
| Bangumi sites section | `test/ui/pages/bangumi_details/widgets/sites_section_test.dart` | Empty, populated, kind-badge labels, tap-to-launch forwarding, dark-bg, Scrollbar wiring. |
| Bangumi comments section | `test/ui/pages/bangumi_details/widgets/comments_section_test.dart` | Loading, empty, populated, rate stars, load-more spinner on/off, dark-bg, HtmlWidget no-throw, `text_mask` → `BangumiMaskText`. |
| Player comments | `test/ui/pages/player/widgets/player_comments_test.dart` | Loading / error / empty / populated / sort-button; `text_mask` → `BangumiMaskText`; Bangumi smile `<img>` → `CachedNetworkImage` smile URL + size/fit wiring; pure helpers `normalizeBangumiImageSrc` / `isBangumiSmileUrl` / `bangumiSmileSize` (fallback, scale>=1, landscape/portrait, both clamp branches, single-attr fallbacks). |
| BT-resource tag helpers | `test/ui/pages/player/widgets/bt_resource_tags_test.dart` | Resolution/codec/subLang/subType/raw precedence, combination priority, HEVC-over-AVC, soft-over-hard sub, empty, realistic VCB-Studio title, `buildBtTagsRow` rendering. |
| BtResourceList display | `test/ui/pages/player/widgets/player_resource_list_test.dart` | Collapsed gate, loader-in-tab guard, empty + retry, empty + error status, populated, per-card loading spinner, play-disabled, copy/download/play callback forwarding, dark-theme, R1 tag chips. |
| HTTP download port | `test/services/download/http_file_download_port_test.dart` | Contract: handle shape (chunks stream, `contentLength` null-or-int, cancel, close), `FakeHttpFileDownloadPort` capture contract (url/headers/cookies in order), `startException` rethrow before any handle is returned, chunk ordering, cancel closes stream, emitError surfaces on stream, close is idempotent. |
| HTTP download manager | `test/services/download/download_manager_http_test.dart` | 2xx single/multi-chunk → status=completed+progress=100; unknown content-length reads `outputFile.lengthSync()`; 404 / 500 → status=error, **no file created** (start throws before `openWrite`); headers+cookies captured verbatim (`Range`/`User-Agent`/`Referer`/`Cookie`); pauseTask retains partial with no post-cancel chunks written; mid-stream error → status=error; error while cancel-flag-set → paused (not error); throttle no-delay branches; **throttle budget-exhaustion delay (injectable `clock`/`sleep`: sleep-once-on-exhaustion, no-sleep-when-elapsed>=1000ms, `resetHttpThrottleForTesting` re-pinning)**; `resumeTask` deletes existing partial BEFORE restart with NO `Range` header; `factory DownloadManager()` zero-arg still `same()`-idempotent. |
| m3u8 playlist port + parser | `test/services/download/m3u8_playlist_port_test.dart` | `parseM3u8Playlist` pure-parser: master variant extraction + BANDWIDTH-desc sort + tie-stability + relative/absolute URI resolution; media playlist segment extraction + order + resolved URIs; master-with-no-segments-but-variants → variants; media with no segments → `'未找到可下载的HLS分片'`; encrypted-key (`METHOD=AES-128` / `METHOD=EXAMPLE`) → `'暂不支持下载加密HLS流'`; `METHOD=NONE` not encrypted; bad-BANDWIDTH → 0; blank/`#`/whitespace tolerance; `#EXT-X-STREAM-INF` followed by empty-or-`#` candidate scanning. Port contract: `FakeM3u8PlaylistPort` call order + headers/cookies passthrough. |
| m3u8 download manager | `test/services/download/download_manager_m3u8_test.dart` | `_resolveHlsSegments` characterization via `resolveHlsSegmentsForTesting` + `FakeM3u8PlaylistPort`: single media playlist → segments in order; master → highest-BANDWIDTH variant recursion → media playlist → segments; `depth > 4` → `'m3u8层级过深，无法解析'`; encrypted-key in any reachable playlist → `'暂不支持下载加密HLS流'`; empty media playlist → `'未找到可下载的HLS分片'`; headers + cookies forwarded verbatim into the fake fetch call. |

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
2. ✅ (2026-07-12 checkpoint) Focused `PlayerComments` and Bangumi
   `CommentsSection` HTML-rendering tests are now in place: `text_mask`
   spans render `BangumiMaskText`, the Bangumi smile `<img>` route yields
   a `CachedNetworkImage` at the rewritten smile URL (with size/fit
   wiring asserted), and the pure
   `normalizeBangumiImageSrc` / `isBangumiSmileUrl` / `bangumiSmileSize`
   helpers are unit-tested (host-rewrite, classify, size math). No
   platform-channels exist in the page-grade tests; the smile `<img>`
   network/cached-image byte fetch and the avatar `CachedNetworkImage`
   decode path remain intentionally uncovered. Manual smoke (load one
   populated comments view in the player and details page) is still
   recommended before the next architectural checkpoint that touches
   comments rendering.
3. ✅ Stabilize `BtStreamCapability` lifecycle: aggregate backend injection,
   generation-safe delayed restore coordinator, zero-delay cleanup, rapid
   reattach cancellation, pause/remove/dispose guards, and explicit delay-gate
   tests. Manager retains playback policy and task mutation.
4. **Required stabilization gate before the next controller:** record manual
   smoke for rapid episode switch (Mikan/DMHY/Sample), HLS pause/remove, and
   rqbit/libtorrent background download → playback → leave/re-enter. The
   latest unit tests guard seams; they do not start WebView, media, or native
   FFI.
5. Then move scheduler dispatch planning into command-returning methods.
   Require immutable input/output DTOs and tests for tier/enqueue order,
   affinity, soft limits, captcha/video competition, and no-work results. Do
   not move WebView construction or page side effects in this step.
6. Only after those gates, extract `PlayerPlaybackController`: inject
   `clock`/`timer`/`player` callbacks and characterize watchdog, fallback, and
   stale-callback behavior. Stop for review after this controller.
7. Keep `BangumiDetailsController` and styling/token work deferred until the
   player and download lifecycle boundaries are stable.

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

5. **A widget can route through `CachedNetworkImage` in widget tests if
   you only assert the first-frame tree.** (2026-07-12.) The
   comment-HTML-rendering tests need to assert that a Bangumi smile
   `<img>` produces a `CachedNetworkImage` with the rewritten smile URL,
   but every previous widget test in the repo went out of its way to feed
   empty `image`/`avatar` so `CachedNetworkImage` was never constructed
   (its `initState` schedules `_maybeStartLoading` via
   `addPostFrameCallback`, which awaits `ImageCacheService.initialize()`
   → `path_provider` → `MissingPluginException` on a Flutter test host).
   It turns out that failure path is fully caught inside the widget's own
   `try { await cache.initialize(); } catch (e) { setState(...); }`, so
   the exception never reaches the test Zone. The pattern that works:
   `pumpWidget` once, then assert on
   `tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage))`
   using its `.imageUrl` / `.width` / `.height` / `.fit` props. Do NOT
   `pump()` again or call `tester.takeException()` without intent — the
   post-frame callback will have already fired during the initial
   `pumpWidget` frame, and any further pumps can drive a second
   `_loadImage` cycle. Prefer pure-helper promotion for the actual URL
   classification and size math (no `HtmlWidget`, no
    `CachedNetworkImage`); reserve the widget pump for the one assertion
    that the routing and the constructed widget props are correct.

6. **Resolve "MAY keep" vs "remove unused after each extraction" in favour
   of deletion when the body is fully replicated elsewhere.** (2026-07-12.)
   The m3u8 seam task told the sub-agent "MAY keep `_fetchHttpText` on the
   manager" and "do NOT touch `_fetchHttpText`"; the sub-agent carried that
   literally and left the now-orphaned helper with a `// ignore: unused_element`
   suppression. But the General Agent Rules say "Keep imports explicit and
   remove unused imports after each extraction", and the helper's wire
   behavior was byte-for-byte replicated in `IoM3u8PlaylistPort.fetchText` —
   so the dead code + the suppression were the wrong call. The reviewer
   deleted both the helper and the now-unused `dart:convert` import. Lesson:
   when a task says "MAY keep X" but X is fully subsumed by the new seam and
   has zero remaining callers, delete it and drop the now-unused import —
   the "MAY keep" license is not a mandate to keep dead code, and a
   `// ignore: unused_element` suppression is a code smell that a reviewer
   will flag. "Do NOT touch" protects *behavior-bearing* code (public APIs,
   persisted keys, sibling render paths); it does not protect a private
   helper whose only caller was the line you just rewired.
