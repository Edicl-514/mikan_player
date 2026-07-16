# AI Refactor Manual Smoke Protocol

## Purpose

This protocol covers behaviour that cannot be deterministically exercised by
the normal unit and widget test suite: real WebView, media playback, platform
download lifecycle, and fullscreen routes. Run only the cases relevant to the
change, but record enough context that a later reviewer can repeat them.

Do not put credentials, private URLs, or personally identifying account data
in a record.

## Record template

Copy this block into the pull request, commit note, or task handoff:

    Date:
    Build / platform / device:
    Commit:
    Cases run:
    Source type used (generic only):
    Result: pass / fail
    Failure details and logs:

## Cases

### P1: source search, episode switch, and lifecycle

Run after changes to source search, WebView scheduling, captcha, episode
selection, autoplay, or disposal.

1. Open a player page and start a source search that exercises the worker pool.
2. Switch episodes rapidly, including the mobile episode selector when
   applicable.
3. Leave the player and re-enter while work is pending.
4. Confirm that current-generation results render, old-generation results do
   not overwrite them, no captcha view is blanked by a cancel/restart storm,
   and autoplay does not become permanently blocked.

### P2: online playback and fallback

Run after changes to PlayerPlaybackController, URL/header planning, probes,
media opening, or fallback.

1. Start an online source.
2. Verify playback opens with the expected source label.
3. Where a safe test source exists, exercise a failed/timeout source followed
   by fallback.
4. Change source or leave/re-enter during startup.
5. Confirm a stale completion cannot reopen the old stream or reset speed and
   resume position on the new attempt.

### P3: HTTP/HLS download

Run after changes to HTTP, HLS, queue, task persistence, or app lifecycle.

1. Start one HTTP/MP4 and one HLS download when available.
2. Pause, resume, and remove at least one active download.
3. Restart the app or leave/re-enter the download view if the changed path
   affects persistence/lifecycle.
4. Confirm task status, bytes, output-file handling, and queue progress are
   consistent with the action.

### P4: BT download and stream playback

Run after changes to BT backend, stream restore, playback policy, or task
lifecycle.

1. Start a BT download.
2. Play it as a stream, then leave/re-enter the player.
3. Return the task to background download, and exercise pause/remove when the
   changed path includes them.
4. Confirm the active stream stops or restores as intended and no stale delayed
   restore mutates a removed/replaced task.

### P5: fullscreen subtitles

Run after changes to subtitle service, controls, fullscreen, or media-kit
configuration.

1. Play media with an embedded subtitle track and enter fullscreen.
2. Toggle subtitles, switch tracks, and change font size, color, and bottom
   padding.
3. Confirm each setting applies immediately in fullscreen and after returning
   to embedded playback; verify only one subtitle layer is visible.

### P6: comments and leaf UI

Run after changes to comment HTML rendering or extracted player/details
widgets.

1. Open populated player and details comments where available.
2. Verify masked text and Bangumi smile images render without a crash.
3. Verify loading, error, empty, and populated UI paths relevant to the change.

## Recorded baseline

| Date | Cases | Result |
| --- | --- | --- |
| 2026-07-14 | P1, P3, P4, P6 | Pass: rapid episode switch/re-entry, HTTP/HLS download lifecycle, BT stream, and comments/leaf UI. |
| 2026-07-16 | P2, P5 | Pass: playback smoke and Android fullscreen BT MKV embedded-subtitle settings. |

## Pending verification

- P1 and P6 must be repeated after the 2026-07-16 search completion-identity
  and Bangumi cache-ordering fixes. They require a real WebView/device session
  and were not claimed by the automated test run.
