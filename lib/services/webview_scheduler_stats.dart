import 'package:flutter/foundation.dart';

import 'package:mikan_player/services/reusable_browser_worker.dart';

/// Phase 0 of `docs/tasks/webview-reuse-extraction-plan.md`.
///
/// 纯调试埋点：统计 WebView widget 创建/销毁次数、视频/验证码提取任务的
/// 开始/完成/超时/取消次数。本类 **绝不参与调度** —— 只累加计数并发出
/// 结构化日志，让后续 worker pool 重构能以这批数字作为可对比的基线指标。
///
/// 持有者（通常是 `_PlayerPageState`）每次新搜索开始时创建/`reset()` 一个
/// 实例，然后把同一实例通过 widget 的可选 `stats` / `jobKey` 参数传给 WebView
/// widget 构造函数。传入 `null` 的调用方（如 `subscription_debug_page.dart`）
/// 保持完全静默、行为不变。
class WebViewSchedulerStats {
  WebViewSchedulerStats();

  // widget 生命周期
  int videoWidgetCreations = 0;
  int videoWidgetDisposals = 0;
  int captchaWidgetCreations = 0;
  int captchaWidgetDisposals = 0;
  int browserWorkerCreations = 0;
  int browserWorkerDisposals = 0;
  int browserWorkerKindSwitches = 0;
  int browserWorkerSameWorkerCrossKindReuse = 0;

  // 视频提取 job 生命周期
  int videoJobStarted = 0;
  int videoJobCompletedTotal = 0;
  int videoJobSucceeded = 0;
  int videoJobFailed = 0;
  int videoJobTimedOut = 0;
  int videoJobCancelled = 0;
  int videoJobLateAfterCancel = 0;

  // 验证码 job 生命周期
  int captchaJobStarted = 0;
  int captchaJobCompletedTotal = 0;
  int captchaJobSucceeded = 0;
  int captchaJobFailed = 0;
  int captchaJobTimedOut = 0;
  int captchaJobCancelled = 0;
  int captchaJobCancelledWhilePending = 0;
  int captchaJobLateAfterCancel = 0;
  int captchaJobStaleResult = 0;

  static const String _tag = '[WebViewScheduler]';

  void reset() {
    videoWidgetCreations = 0;
    videoWidgetDisposals = 0;
    captchaWidgetCreations = 0;
    captchaWidgetDisposals = 0;
    browserWorkerCreations = 0;
    browserWorkerDisposals = 0;
    browserWorkerKindSwitches = 0;
    browserWorkerSameWorkerCrossKindReuse = 0;
    videoJobStarted = 0;
    videoJobCompletedTotal = 0;
    videoJobSucceeded = 0;
    videoJobFailed = 0;
    videoJobTimedOut = 0;
    videoJobCancelled = 0;
    videoJobLateAfterCancel = 0;
    captchaJobStarted = 0;
    captchaJobCompletedTotal = 0;
    captchaJobSucceeded = 0;
    captchaJobFailed = 0;
    captchaJobTimedOut = 0;
    captchaJobCancelled = 0;
    captchaJobCancelledWhilePending = 0;
    captchaJobLateAfterCancel = 0;
    captchaJobStaleResult = 0;
  }

  // ---------------- 视频 widget 生命周期 ----------------
  void onVideoWidgetCreated(String? jobKey) {
    videoWidgetCreations++;
    _log('VIDEO widget created (#$videoWidgetCreations) jobKey=$jobKey');
  }

  void onVideoWidgetDisposed(String? jobKey) {
    videoWidgetDisposals++;
    _log(
      'VIDEO widget disposed (#$videoWidgetDisposals) jobKey=$jobKey '
      'created=$videoWidgetCreations',
    );
  }

  // ---------------- 视频提取 job 生命周期 ----------------
  void onVideoJobStarted(String pageKey, String sourceName, BigInt? channel) {
    videoJobStarted++;
    _log(
      'VIDEO job started (#$videoJobStarted) '
      'pageKey=$pageKey source=$sourceName channel=$channel',
    );
  }

  void onVideoJobCompleted({
    required bool success,
    required bool timedOut,
    required String pageKey,
    required String sourceName,
  }) {
    videoJobCompletedTotal++;
    if (timedOut) {
      videoJobTimedOut++;
    } else if (success) {
      videoJobSucceeded++;
    } else {
      videoJobFailed++;
    }
    _log(
      'VIDEO job completed (#$videoJobCompletedTotal) '
      'pageKey=$pageKey source=$sourceName success=$success timedOut=$timedOut '
      '-> succeeded=$videoJobSucceeded failed=$videoJobFailed '
      'timedOut=$videoJobTimedOut',
    );
  }

  void onVideoJobCancelled(String pageKey, [String? sourceName]) {
    videoJobCancelled++;
    _log(
      'VIDEO job cancelled (#$videoJobCancelled) '
      'pageKey=$pageKey source=${sourceName ?? "?"}',
    );
  }

  void onVideoJobLateAfterCancel(String pageKey, String sourceName) {
    videoJobLateAfterCancel++;
    _log(
      'VIDEO late result after cancel (#$videoJobLateAfterCancel) '
      'pageKey=$pageKey source=$sourceName -- discarded, no probe',
    );
  }

  // ---------------- 验证码 widget 生命周期 ----------------
  void onCaptchaWidgetCreated(String? jobKey) {
    captchaWidgetCreations++;
    _log('CAPTCHA widget created (#$captchaWidgetCreations) jobKey=$jobKey');
  }

  void onCaptchaWidgetDisposed(String? jobKey) {
    captchaWidgetDisposals++;
    _log(
      'CAPTCHA widget disposed (#$captchaWidgetDisposals) jobKey=$jobKey '
      'created=$captchaWidgetCreations',
    );
  }

  // ---------------- 统一 Browser worker (5B step 2) ----------------
  void onBrowserWorkerCreated(String workerKey) {
    browserWorkerCreations++;
    _log('BROWSER worker created (#$browserWorkerCreations) key=$workerKey');
  }

  void onBrowserWorkerDisposed(String workerKey) {
    browserWorkerDisposals++;
    _log(
      'BROWSER worker disposed (#$browserWorkerDisposals) key=$workerKey '
      'created=$browserWorkerCreations',
    );
  }

  void onBrowserWorkerKindSwitched(int workerId, WebViewJobKind kind) {
    browserWorkerKindSwitches++;
    _log(
      'BROWSER worker=$workerId accepted $kind job '
      '(#$browserWorkerKindSwitches switches, '
      'cross-kind reuse #$browserWorkerSameWorkerCrossKindReuse)',
    );
  }

  void onBrowserWorkerSameWorkerCrossKindReuse(int workerId) {
    browserWorkerSameWorkerCrossKindReuse++;
    _log(
      'BROWSER worker=$workerId reused across job kinds (no InAppWebView '
      'rebuild) total=$browserWorkerSameWorkerCrossKindReuse',
    );
  }

  // ---------------- 验证码 job 生命周期 ----------------
  void onCaptchaJobStarted(String jobKey, String sourceName) {
    captchaJobStarted++;
    _log(
      'CAPTCHA job started (#$captchaJobStarted) '
      'jobKey=$jobKey source=$sourceName',
    );
  }

  void onCaptchaJobCompleted({
    required bool success,
    required bool timedOut,
    required String jobKey,
    required String sourceName,
  }) {
    captchaJobCompletedTotal++;
    if (timedOut) {
      captchaJobTimedOut++;
    } else if (success) {
      captchaJobSucceeded++;
    } else {
      captchaJobFailed++;
    }
    _log(
      'CAPTCHA job completed (#$captchaJobCompletedTotal) '
      'jobKey=$jobKey source=$sourceName success=$success timedOut=$timedOut '
      '-> succeeded=$captchaJobSucceeded failed=$captchaJobFailed '
      'timedOut=$captchaJobTimedOut',
    );
  }

  void onCaptchaJobCancelled(String jobKey, String sourceName) {
    captchaJobCancelled++;
    _log(
      'CAPTCHA active job cancelled (#$captchaJobCancelled) '
      'jobKey=$jobKey source=$sourceName',
    );
  }

  void onCaptchaJobCancelledWhilePending(String jobKey, String sourceName) {
    captchaJobCancelledWhilePending++;
    _log(
      'CAPTCHA pending job cancelled (#$captchaJobCancelledWhilePending) '
      'jobKey=$jobKey source=$sourceName',
    );
  }

  void onCaptchaJobLateAfterCancel(String jobKey) {
    captchaJobLateAfterCancel++;
    _log(
      'CAPTCHA late result after cancel (#$captchaJobLateAfterCancel) '
      'jobKey=$jobKey -- no callback invoked',
    );
  }

  void onCaptchaJobStaleResult(String jobKey) {
    captchaJobStaleResult++;
    _log(
      'CAPTCHA stale result (#$captchaJobStaleResult) '
      'jobKey=$jobKey loadToken mismatch -- discarded',
    );
  }

  /// 单行简短汇总，供调试面板与日志使用。
  String shortSummary() {
    return 'WV created=$videoWidgetCreations disposed=$videoWidgetDisposals | '
        'BR created=$browserWorkerCreations disposed=$browserWorkerDisposals '
        'switches=$browserWorkerKindSwitches '
        'crossKindReuse=$browserWorkerSameWorkerCrossKindReuse | '
        'video started=$videoJobStarted ok=$videoJobSucceeded '
        'fail=$videoJobFailed tmout=$videoJobTimedOut cxl=$videoJobCancelled | '
        'captcha started=$captchaJobStarted ok=$captchaJobSucceeded '
        'fail=$captchaJobFailed tmout=$captchaJobTimedOut '
        'cxl=$captchaJobCancelled';
  }

  void _log(String msg) => debugPrint('$_tag $msg');
}
