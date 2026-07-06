# Local patches to flutter_inappwebview_android

- **Upstream package:** `flutter_inappwebview_android` (from pub.dev)
- **Upstream version:** 1.1.3
- **Source:** copied from local pub cache (`%LOCALAPPDATA%/Pub/Cache/hosted/pub.dev/flutter_inappwebview_android-1.1.3`) on 2026-07-06.

> Note: as of 2026-07-06, 1.1.3 is the latest version published on pub.dev, so vendoring is the correct approach (no upstream fix to bump to).

## Patches

**Status: APPLIED** on 2026-07-06 (Step 2.2 + 2.3 of the WebView cookie-jank elimination plan, see `docs/webview-cookie-jank-elimination-plan.md`). Each removed `flush()` call was replaced with an inline comment explaining why it was removed; no surrounding logic, `result.success(...)` calls, or callbacks were changed.

1. **APPLIED — Remove unconditional `CookieManager.getInstance().flush()` in `onPageFinished`** (Step 2.2)
   - Files + exact removal sites:
     - `android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebViewClient.java` — removed `CookieManager.getInstance().flush();` at line 235 (inside the `if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)` branch of `onPageFinished`); the preceding comment `// WebView not storing cookies reliable to local device storage` was also removed. The pre-LOLLIPOP `else { CookieSyncManager.getInstance().sync(); }` branch was left intact.
     - `android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/webview/in_app_webview/InAppWebViewClientCompat.java` — identical removal at line 235 (same method, same structure).
   - Replacement comment left at both sites: `// Removed unconditional CookieManager.flush() — causes main-thread jank. Cookies persist via Chromium's own scheduling.`
   - Reason: main-thread `CookieManager.flush()` jank — see Perfetto trace. Flushing on the UI thread blocks the platform message loop on every page finish.

2. **APPLIED — Remove immediate `flush()` calls after cookie write/delete operations** (Step 2.3)
   - File: `android/src/main/java/com/pichillilorenzo/flutter_inappwebview_android/MyCookieManager.java`
   - Exact removal sites (5 `cookieManager.flush();` statements):
     - Line 191 — in `setCookie`, immediately after the async `setCookie(url, ...)` call (inside the `Build.VERSION_CODES.LOLLIPOP` branch; `result.success` remains in the `ValueCallback`).
     - Line 309 — in `deleteCookie`, immediately after the async `setCookie(url, ...)` call (same structure; `result.success` remains in the callback).
     - Line 363 — in `deleteCookies`, the `else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) cookieManager.flush();` clause (braces were added to keep the now-empty branch valid Java; the `cookieSyncMngr != null` sync branch for pre-LOLLIPOP and the trailing `result.success(true)` are unchanged).
     - Line 382 — in `deleteAllCookies`, immediately after `removeAllCookies(...)` (`result.success` remains in the callback).
     - Line 411 — in `removeSessionCookies`, immediately after `removeSessionCookies(...)` (`result.success` remains in the callback).
   - Replacement comment left at each of the 5 sites: `// Removed flush() — Chromium persists cookies asynchronously; forcing main-thread flush caused jank.`
   - The `CookieManager cookieManager = CookieManager.getInstance();` declaration (via `getCookieManager()`) was kept — it is still required for the set/delete calls themselves.
   - Reason: same main-thread `CookieManager` flush jank as above. The Android `CookieManager` already persists cookies to disk asynchronously; an explicit synchronous `flush()` on the platform thread is unnecessary and causes UI stalls. Chromium's in-memory cookie store already reflects writes synchronously, so subsequent same-method reads are not affected.

## How to reapply when upgrading

1. Re-copy the new upstream version over this directory (exclude `.git`, `.dart_tool`, and `build/` artifacts):
   ```
   cp -r "%LOCALAPPDATA%/Pub/Cache/hosted/pub.dev/flutter_inappwebview_android-<NEW_VERSION>/"* third_party/flutter_inappwebview_android/
   rm -rf third_party/flutter_inappwebview_android/.dart_tool third_party/flutter_inappwebview_android/build third_party/flutter_inappwebview_android/.git
   ```
2. Re-apply the patches listed above (the line numbers may have shifted; locate the `flush()` calls by content).
3. Update the **Upstream version** field at the top of this file to the new version, and update the Source line's version suffix and date.
4. Run `flutter pub get` to confirm the local path override still resolves.

## Reason for vendoring

Avoid main-thread `CookieManager.flush()` jank that causes UI freezes up to ~2.3s during WebView video extraction (see `docs/webview-cookie-jank-elimination-plan.md`). The upstream package does not yet expose a way to disable these flushes, so a local patch is the only way to eliminate the jank without waiting for an upstream release.
