# AI Refactor and Test Plan

## How to use this document

This is the current, executable plan for refactoring hand-written Dart and
adding tests. It deliberately contains current decisions, acceptance criteria,
and known gaps only. Do not treat an old checkpoint, a line-count delta, or a
directory diagram as a task by itself.

Historical implementation detail belongs in Git history. Start a task by
reading the files it will touch, this plan's relevant phase, and the existing
tests beside those files.

Status date: 2026-07-17 (current refactor checkpoint complete; P1/P3/P6 smoke
reported passing).

## Verified baseline

The following was re-verified on the status date:

- flutter analyze: 0 issues.
- flutter test: 788 passing tests after the HLS fallback/cancellation follow-up.
- cargo test: 56 passing tests; 1 live-network test intentionally ignored.
- Search result/idle callbacks preserve their dispatched generation and job
  key through pool and legacy paths; final validation is listed below.
- HLS playlist and segment header fallback, winning-header reuse, and pause
  during automatic retry backoff are characterized without real network IO.

Hotspot counts below use line counts. They are an inventory, not a completion
metric.

| File | Initial LOC | Current LOC | Primary remaining responsibility |
| --- | ---: | ---: | --- |
| lib/ui/pages/player_page.dart | 8318 | 7007 | WebView search-session orchestration, captcha/result handling, and page-owned Flutter/media side effects. |
| lib/services/download_manager.dart | 3285 | 2635 | Task persistence, queue/polling, retry policy, playback policy, and background BT restore mutation. |
| lib/ui/widgets/video_player_controls.dart | 3103 | 1151 | No currently justified extraction boundary. |
| lib/ui/widgets/video_player_controls/settings_panel.dart | 1141 | 977 | Reactive menu state; leave local styles in place unless a new semantic boundary appears. |
| lib/ui/pages/bangumi_details_page.dart | 3096 | 2475 | Layout, scroll, navigation, dialogs/SnackBars; data request state owned by BangumiDetailsController. |
| lib/ui/pages/bangumi_details/bangumi_details_controller.dart | — | 576 | Cache/network details, comment paging, favorite status, generation tokens. |

## Goals

- Reduce maintenance cost by giving state, decisions, and side effects clear
  owners.
- Make concurrency, cancellation, stale-callback, and persistence behaviour
  deterministic enough to test.
- Preserve public behaviour while extracting. Changes that intentionally fix a
  proven defect must be explicit and independently reviewable.
- Keep each change small enough to validate and revert independently.

## Non-goals

- Do not refactor generated files:
  - lib/gen/**
  - lib/src/rust/frb_generated*
  - lib/services/cache/database/*.g.dart
- Do not refactor vendored or third-party code:
  - third_party/**
  - native/mikan_libtorrent/include/httplib.h
- Do not change Rust APIs, Flutter Rust Bridge bindings, database schemas,
  persisted task JSON, or asset layout without a separately approved task.
- Do not introduce a state-management framework in this pass.
- Do not move a facade or extract models/enums merely to match a proposed
  directory tree or reduce a line count.
- Do not begin styling-token work while feature boundaries are still moving.

## Current architecture decisions

The existing controller and port extractions are accepted and should be
treated as stable seams:

- PlayerEpisodeController owns episode selection state. The page owns episode
  change side effects.
- PlayerSourceController and PlayerSampleSourceController own their respective
  state, not Rust/WebView/UI execution.
- PlayerWebViewScheduler owns worker bookkeeping and pure dispatch planning.
  The page still creates WebViews and commits resulting commands.
- PlayerPlaybackController owns online-source selection, URL/header planning,
  startup watchdog, fallback reservation, and stale-attempt guards. The page
  owns Player/Video objects, header-proxy registration, and Flutter state.
- DownloadManager uses task/queue/store, HTTP, HLS, BT-backend, and BT-stream
  seams. It remains the public facade and owns cross-cutting task policy.
- SubtitleOverlay is app-owned; media_kit's built-in SubtitleView remains
  disabled for this path so fullscreen settings update the same overlay.

Keep facade locations stable. A future module must be introduced for an owned
responsibility and an explicit public boundary, never only to satisfy a
directory layout.

## Phase status and order

| Phase | Status | Decision |
| --- | --- | --- |
| 0: baseline and smoke | Complete | Repeat only the affected manual cases after a WebView, playback, download, or platform change. |
| 1: display-only extractions | Closed for now | Existing leaf widgets have focused widget tests. Do not extract more display code without a clear boundary. |
| 2: player responsibility split | Complete for this pass | Completion identity spans job payloads, runner callbacks, scheduler slots, and page guards; P1 smoke passed. Reopen only for a demonstrated ownership defect. |
| 3: download split | Complete for this pass | Recovery, cancellation, aliases, HTTP/HLS retry, and header fallback are characterized; P3 smoke passed. Keep the facade stable. |
| 4: Bangumi details split | Complete for this pass | Controller ordering/identity and comment rendering are characterized; P6 smoke passed. |
| 5: styling consistency | Deferred / not required | Reconsider only if repeated semantic values are demonstrated in future feature work. |

## Completed checkpoint: BangumiDetailsController

Landed under `lib/ui/pages/bangumi_details/bangumi_details_controller.dart`
with tests in `test/ui/pages/bangumi_details/bangumi_details_controller_test.dart`.

Accepted ownership:

- Request state for cached/network Bangumi data, comment paging, and
  favorite-status requests.
- Injected `BangumiDetailsDataPort` / `BangumiDetailsFavoritesPort` plus
  generation tokens so late results cannot update a disposed or replaced
  instance.
- Read-only unmodifiable list/map views; optional `onStateChanged` for the
  page `setState` bridge.
- Page retains BuildContext, ScrollControllers, layout, navigation, dialogs,
  and SnackBars.
- `didUpdateWidget` resets and reloads the controller when anime identity
  changes, invalidating delayed page-owned comment scheduling.

Characterization coverage:

- Cache-first/network-first completion order, empty-network merge,
  replacement, and dispose late completions.
- Concurrent load-more dedupe; terminal page; error retry.
- Favorite success and stale completion after dispose/reset.
- Existing relations/sites/comments widget tests unchanged.

Do not combine further details work with mobile inline comment rendering
unification. That is a UI redesign and remains deferred.

## Next high-risk track: Player search session

The largest remaining PlayerPage risk is the search/WebView/captcha event
region. Preparatory checkpoint (not full extraction):

- Design note: `docs/player_search_session_design.md`
- Pure policy: `lib/ui/pages/player/player_search_session_policy.dart`
- Characterization: `test/ui/pages/player/player_search_session_policy_test.dart`

The state machine / policy must define:

- Inputs: start/reset, cancel/dispose, source progress, captcha result,
  extraction result, timeout, and worker-idle events.
- Identity: search generation (`sampleLoadToken`) plus stable job/task key.
  Every asynchronous completion must be rejected when either is stale.
- Outputs: immutable dispatch/cleanup/status decisions only. The page keeps
  InAppWebView creation, Rust stream subscription, logging, setState, probe,
  playback, and callback execution.
- Invariants: no job starts after dispose; cancelling a generation prevents
  its later result from mutating visible state; source cooldown timing remains
  outside pure dispatch planning; warm captcha sessions are not cleared by a
  transient reset.

Required characterization matrix:

| Scenario | Expected contract | Status |
| --- | --- | --- |
| Start then immediate replacement | Old progress, captcha, and extraction results have no visible effect. | Original job generation returned by runner; page rejects before mutation |
| Cancel then restart same source | A new generation/job identity is used; the old worker cannot claim or clear the new job. | Job payload + scheduler slot identity tests |
| Captcha refresh | Briefly missing DOM is not considered captcha success. | Pure `shouldTreatMissingCaptchaAfterRefreshAsSuccess` |
| Last worker slot | Existing captcha/video priority and source-gate timing are preserved. | Existing scheduler/gate tests; policy defers reordering |
| Dispose during search | Pending subscriptions, timers, and workers cannot re-arm playback or UI state. | Pure dispose reject + idle reassignment guard |

The matrix is deterministic and P1 smoke has passed. A controller/reducer is
not required for this pass. Reopen that option only if a future defect shows a
cross-cutting state/command owner that the current policy, scheduler, and page
guards cannot express cleanly.

**Wire checkpoint (2026-07-17):** `PlayerPage` routes search-scoped stale
guards through `player_search_session_policy.dart`. Captcha/video job payloads,
runner result callbacks, runner idle callbacks, and scheduler slots carry the
original generation plus stable job key; the page rejects that identity before
mutating active maps, failed keys, probes, or UI. Finish-idle policy lives in
`sample_search_finish_policy.dart` (`mayMarkSampleSearchIdle`, terminal source
checks). `SourceRequestGate` cooldown timing, WebView creation, and captcha
runner DOM refresh remain outside those modules. P1 smoke passed; a full
session reducer is intentionally not part of the completed checkpoint.

## Test strategy

Use the smallest test type that can assert the contract:

- Pure Dart composition tests for state, selection, timers, queues, parsers,
  and decision objects.
- Widget tests for stable loading/empty/error/populated states, selection, and
  callback forwarding.
- Inject thin ports/callbacks for files, clocks, sleepers, HTTP, BT backends,
  and platform-facing services.
- Use temp directories for file-system behaviour.
- Do not start real network, WebView, media playback, or platform channels in
  unit/widget tests.

Current strong coverage includes scheduler decisions, player controllers,
download HTTP/HLS/BT seams, persistence/path safety, subtitle ownership, and
extracted leaf widgets. The intentional gaps are end-to-end WebView/media
behaviour, production SharedPreferences wiring, and full PlayerPage/
BangumiDetailsPage widget construction. Manual smoke is therefore a required
complement for affected changes, not a substitute for deterministic tests.

### Defect triage rule

Default extraction work preserves observable behaviour. If a new test exposes
a defect:

1. Write a minimal reproducing test and state why the old result is wrong.
2. Make the correction explicit in the task/commit summary and acceptance
   criteria.
3. Keep the behavioural correction isolated from unrelated relocation or
   cleanup where practical.
4. Run the affected manual smoke case when the defect touches platform,
   playback, WebView, download, or persisted data.

This allows real bugs to be fixed without silently changing semantics during a
mechanical refactor.

## Manual smoke protocol

Use docs/ai_refactor_manual_smoke.md for the repeatable cases and result
format. The 2026-07-17 user-reported P1/P3/P6 run covers the latest search
identity, HTTP/HLS resilience, and Bangumi comment-rendering changes. No manual
case remains pending for this checkpoint.

Repeat relevant cases before merging when a task changes:

- WebView scheduling, captcha, source search, episode switching, or autoplay.
- Player open/fallback, subtitle rendering/settings, or playback lifecycle.
- HTTP/HLS/BT download, streaming, pause/remove/resume, or app lifecycle.
- Player/details comment rendering.

## Agent rules

1. Read the target implementation and nearby tests before editing.
2. Name new files by the responsibility they own, not by vague categories.
3. Keep Flutter widgets, BuildContext, real WebViews, and media players out of
   decision/state controllers.
4. Preserve public APIs and persisted values unless the task explicitly
   approves a compatibility change.
5. Add tests at the new seam; do not add production-only test hooks when an
   injected dependency or pure DTO will do.
6. Delete fully subsumed private code and unused imports. Do not retain a
   suppression for known dead code.
7. Format only touched Dart files. Do not run a write-mode whole-repository
   format as part of a normal extraction.
8. Report changed files, validation results, manual smoke result when needed,
   and known risks.

## Validation

For every Dart change, run:

    dart format <touched Dart files>
    dart format --output=none --set-exit-if-changed <touched Dart files>
    flutter analyze
    flutter test
    git diff --check

For Rust changes, format and check only the touched hand-written Rust files so
generated bindings remain untouched, then run:

    rustfmt --edition 2021 <touched hand-written Rust files>
    rustfmt --check --edition 2021 <touched hand-written Rust files>
    cd rust
    cargo test

## Review and stop conditions

Every review checks:

- ownership boundary is clear and public/persisted contracts are preserved;
- tests prove the extracted behaviour and stale/cancellation behaviour when
  asynchronous work is involved;
- analyzer, test suite, and diff whitespace check pass;
- required manual smoke is recorded with the standard protocol.

Stop and request review when a task needs a new dependency; generated/binding
changes; persisted JSON/schema changes; a real network/WebView/media test in
the normal suite; broad cross-module edits; or a controller that cannot be
expressed as state/commands without widget/platform objects.

## Historical references

The accepted checkpoints immediately preceding this plan are:

- f2e9976: resilient HTTP/HLS retries and header fallback.
- b79dad1: Bangumi comment mask/smile rendering follow-up.
- cb0c5ed: search completion identity enforcement.
- 5510942: BangumiDetailsController extraction.
- bb609c4: app-owned fullscreen subtitle overlay and playback smoke fix.
- 1cc5feb: PlayerPlaybackController extraction and fallback race fix.
- 5c16696: immutable scheduler video dispatch decisions.
- e1207f7: lifecycle stabilization and SourceRequestGate.

Use Git history for implementation detail, not as a source of new work.
