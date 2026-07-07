# record_trace.ps1 — one-shot Perfetto + logcat capture for the extraction jank.
#
# Why logcat separately: on this MIUI build perfetto's android.log reader returns
# 0 rows (android_log_num_total=0), so we grab logcat in parallel and align by
# wall-clock. Flutter debugPrint lands under tag "flutter" (profile build).
#
# PREREQUISITES (must all be true or the trace is useless):
#   1. App built/run in PROFILE mode:  flutter run --profile
#      (release strips dart:developer TimelineTask -> extraction.*/captcha.* markers vanish)
#   2. You will ACTUALLY TRIGGER an extraction during the 30s window
#      (open a new episode so onLoadStop -> getHtml fires; last trace missed this).
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\record_trace.ps1

$ErrorActionPreference = 'Stop'
$dev = (adb devices) -match "\tdevice$"
if (-not $dev) { Write-Error "no adb device"; exit 1 }

$pkg = "com.edicl.mikan_player"
$pid_ = "$(adb shell pidof $pkg)".Trim()
if (-not $pid_) {
  Write-Error "$pkg not running — launch it first (flutter run --profile) and bring it to the foreground, then re-run this script."
  exit 1
}
Write-Host "app pid = $pid_"

# 1) clear logcat so we only get this run
adb logcat -c
Write-Host "logcat cleared"

# 2) start logcat capture in the background (this PC), whole buffer, threadtime format
$logJob = Start-Job -ScriptBlock {
  adb logcat -v threadtime > "$using:PWD\mikan_logcat.txt"
}
Write-Host "logcat capture started (job $($logJob.Id)) -> mikan_logcat.txt"

# 3) push config + start perfetto (config via stdin — MIUI denies file read in perfetto domain)
adb push mikan_trace.cfg /data/local/tmp/mikan_trace.cfg | Out-Null
$perfPid = (adb shell "cat /data/local/tmp/mikan_trace.cfg | perfetto --background --txt -c - -o /data/misc/perfetto-traces/mikan.pftrace").Trim()
Write-Host "perfetto started (pid $perfPid), recording 30s"
Write-Host ""
Write-Host ">>> NOW: trigger the extraction in the app (open a new episode / play). <<<"
Write-Host ">>> Reproduce the jank. Recording auto-stops in 30s. <<<"
Write-Host ""

# 4) wait for perfetto to finish
while ("$(adb shell pidof perfetto)".Trim()) { Start-Sleep -Seconds 2 }
Write-Host "perfetto done"

# 5) stop logcat capture and pull the trace
Stop-Job $logJob; Receive-Job $logJob | Out-Null; Remove-Job $logJob
adb pull /data/misc/perfetto-traces/mikan.pftrace .\mikan.pftrace
Write-Host ""
Write-Host "DONE. Pulled:"
Write-Host "  mikan.pftrace   (perfetto trace)"
Write-Host "  mikan_logcat.txt (parallel logcat, align by wall-clock)"
