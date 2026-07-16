# PlayerSearchSession design note

Status: completion identity wired; reducer extraction still deferred (2026-07-16).
This document specifies a future pure state machine / command boundary. It is
**not** permission to extract a god controller or move WebView / Rust / player
execution off `PlayerPage`.

Related plan section: `docs/ai_refactor_test_plan.md` → "Next high-risk track:
Player search session".

## Why this exists

Online sample search still spans page-owned orchestration:

- generation identity (`PlayerSampleSourceController.sampleLoadToken`)
- Rust search streams (`_searchSubscriptions`)
- captcha preflight queue (`_pendingCaptchaTasks` / `_activeCaptchaTasks`)
- WebView pool pump + `PlayerWebViewScheduler`
- video extract → probe → playback (`PlayerPlaybackController`)
- process-wide `SourceRequestGate` cooldowns

Several pure seams already exist (scheduler, worker transitions, sample
controller, gate). What is **not** centralized is the cross-cutting "is this
async completion still allowed to mutate visible search state?" policy that
ties load token, dispose, replacement, and job keys together. That is the
`PlayerSearchSession` boundary.

## Current ownership (accepted seams)

| Concern | Owner today | Notes |
| --- | --- | --- |
| Sample lists / progress / load token | `PlayerSampleSourceController` | Mutators only; page owns async |
| Worker slots / active maps / video plan | `PlayerWebViewScheduler` | Pure planning + bookkeeping |
| Pump token / stagger | `WebViewPoolPumpCoordinator` | Tokened pump loops |
| Captcha idle stale clear | `shouldClearCaptchaSlotOnIdle` | Pure predicate |
| Late non-tier0 video after accept | `isVideoResultLateAfterCancel` | Pure predicate |
| Per-source start cooldown | `SourceRequestGate` | Process-wide; **outside** pure dispatch |
| Captcha DOM / OCR / refresh | `WebViewCaptchaJobRunner` | Platform WebView |
| Search start / cancel / finish | `PlayerPage` (`_loadSampleSource`, …) | Side effects |

## Identity model

Every asynchronous completion must carry enough identity to be rejected when
stale. Captcha/video runner result and idle callbacks now return the original
job object, including its captured generation; callers must never reconstruct
completion identity from current page state.

### Search generation

- **Name in code:** `sampleLoadToken` (`PlayerSampleSourceController`).
- **Bump points:**
  - `_loadSampleSource` start: `bumpLoadToken()` before cancel/reset.
  - `dispose`: `bumpLoadToken()` before cancelling subscriptions / clearing
    scheduler so late probe/captcha/video cannot re-arm UI.
- **Contract:** if `result.loadToken != sampleLoadToken`, drop visible mutation
  (progress, captcha apply, extraction probe registration, finish-search).

### Job / task keys

| Kind | Key | Where |
| --- | --- | --- |
| Captcha preflight | `taskKey` (e.g. `search:${sourceName}`) | `_CaptchaPreflightTask`, scheduler captcha map |
| Video extraction | `pageKey` (`SourceChannelKey`) | sample play pages, scheduler video map |
| Worker | `workerId` | `WebViewWorkerSlot` |

Worker slots also retain the dispatched generation while busy. A post-frame
idle event is applied only when `{workerId, kind, jobKey, generation}` still
matches, so an old worker cannot clear a same-key replacement job.

A completion is current only when **both** generation (load token) **and** the
job key still map to the active bookkeeping the page/scheduler expects.

### Source cooldown (explicit non-identity)

`SourceRequestGate` uses `sourceName` + wall-clock cooldown. It must stay
**outside** pure session dispatch planning: pure decisions may observe "may
start now?" as an injected fact, but must not own timers or `DateTime.now()`.

## Inputs (events)

Named for a future reducer; map 1:1 to page entry points.

| Input | Primary page / runner entry |
| --- | --- |
| `StartSearch({manual})` | `_loadSampleSource` |
| `CancelSubscriptions` | `_cancelSearchSubscriptions` |
| `ResetVisibleSearchState` | `setState` block after token bump (beginNewSearchReset + scheduler reset + clear maps) |
| `SourceProgress(progress, loadToken)` | search stream → `_handleSearchProgressUpdate` |
| `QueueCaptcha(task)` / `CaptchaResult(taskKey, result)` | `_queueCaptchaPreflightTask` / `_onCaptchaPreflightResult` |
| `QueueVideo(page)` / `VideoResult(pageKey, result)` | pump + `_onWebViewResult` |
| `WorkerIdle(workerId, kind)` | `_onCaptchaWorkerIdle` / video idle |
| `Timeout` / runner complete flags | captcha/video runner `timedOut` |
| `AcceptPlayable(pageKey)` | probe success path; sets `_acceptedSourcePageKey` |
| `Dispose` | `dispose` invalidation sequence |

## Outputs (commands only)

A future session object returns **immutable decisions**; the page executes:

- `DispatchCaptcha { taskKey, workerId }` / `DispatchVideo { pageKey, workerId }`
- `ReleaseCaptchaSlot` / `ReleaseVideoSlot` / `MarkSlotIdle` / `RemoveUnhealthySlot`
- `ApplySourceProgress` / `IgnoreStale`
- `ApplyCaptchaRuntimeOverride` / `MarkSourceFailed`
- `ProbeAndRegister` / `SuppressLateNonTier0`
- `SchedulePoolPump { immediate }`
- `FinishSearch { status }` (only when loading + no pending work)
- `Log` / stats hooks as opaque side-effect intents if needed

**Never** inside pure session logic:

- `InAppWebView` creation, `CookieManager`, OCR, Rust streams
- `setState`, notifiers, `SharedPreferences`, `Player.open`
- `SourceRequestGate` timer scheduling (page/gate keep ownership)

## Invariants

1. **No job start after dispose.** Dispose bumps load token, cancels
   subscriptions, clears active captcha/video bookkeeping, then
   `scheduler.clearForDispose()`. Late completions see stale token or empty maps.
2. **Cancel generation ⇒ no visible mutation.** Replacement search bumps token
   before destructive reset; old progress/captcha/extraction only update stats
   / release slots, not sample progress or playback arming.
3. **Source cooldown outside pure planning.** Pump path still consults
   `SourceRequestGate` with `sampleLoadToken` as waiter token (latest-wins).
4. **Warm captcha sessions survive transient reset.**
   `PlayerWebViewScheduler.resetForNewSearch` clears jobs and returns slots to
   idle with `preserveCaptchaSessionOnIdle` for captcha kind — it must **not**
   dispose workers or clear cookies. Full dispose / pool toggle may tear down.
5. **Stale idle notifications must not clear a reassigned worker.** If
   `slot.kind != null` when a post-frame idle arrives, ignore.
6. **Captcha refresh ≠ success.** After image refresh, briefly missing captcha
   DOM is not success unless the configured success selector is present
   (`WebViewCaptchaJobRunner` retry path).

## Characterization matrix

| Scenario | Expected contract | Where pinned today / next |
| --- | --- | --- |
| Start then immediate replacement | Old progress, captcha, extraction have no visible effect | Runner callbacks carry original generation; page rejects stale identity before mutation |
| Cancel then restart same source | New generation + job identity; old worker cannot claim or clear the new job | Job payload + scheduler slot store `{generation, jobKey}`; runner/scheduler tests |
| Captcha refresh | Briefly missing DOM is not captcha success | Runner comment + pure `shouldTreatMissingCaptchaAfterRefreshAsSuccess` |
| Last worker slot | Captcha/video priority and source-gate timing preserved | Scheduler selection tests + gate tests; session must not reorder |
| Dispose during search | Pending work cannot re-arm playback or UI | dispose token bump + `PlayerPlaybackController.clearForDispose` |

## Explicit non-goals for the next extraction

- Do not fold scheduler + sample controller + playback into one session god
  object.
- Do not move `SourceRequestGate` into the session reducer.
- Do not redesign captcha OCR or WebView cookie policy.
- Do not unify mobile/PC player chrome while this boundary is open.

## Suggested extraction sequence (later)

1. **Policy-only module**: pure accept/reject + captcha-refresh success rule.
2. **Completion identity wiring** (current checkpoint): job payloads, result
   callbacks, idle callbacks, and scheduler slots preserve generation + key.
3. Optional thin **command planner** for "may finish search?" / "may apply
   progress?" once matrix is green and stable.
4. Only then consider moving mutator sequences from `_loadSampleSource` into a
   small command-oriented controller that still leaves execution on the page.

## Primary code references

- `lib/ui/pages/player_page.dart` — `_loadSampleSource`, `_cancelSearchSubscriptions`,
  `_onCaptchaPreflightResult`, `_onCaptchaWorkerIdle`, `dispose`
- `lib/ui/pages/player/player_sample_source_controller.dart` — `sampleLoadToken`
- `lib/ui/pages/player/player_webview_scheduler.dart` — `resetForNewSearch`,
  `startCaptchaJob` / `startVideoJob`
- `lib/ui/pages/player/webview_worker_state_transitions.dart` — pure predicates
- `lib/services/source_request_gate.dart` — cooldown latest-wins
- `lib/services/webview_captcha_job_runner.dart` — captcha refresh / success guard
