/// 5B step 3：统一的长期 WebView worker 调度状态（captcha + video 合并）。
///
/// 每个 slot 长期持有 [ReusableBrowserWorker]（widget key 为
/// `worker_$workerId`），由调度器通过 sealed [WebViewJob] 派发任务：
///
/// - `kind == null` 且 `jobKey == null` 时 slot idle，等待下次派活或被
///   trimIdleWebViewWorkerSlotsToBudget 移除。
/// - `kind == WebViewWorkerKind.video` 时 [pageKey] 指向
///   `_activeVideoJobs[pageKey] == workerId`；[jobKey] 等于 [pageKey]，
///   [taskKey] 为 null。
/// - `kind == WebViewWorkerKind.captcha` 时 [taskKey] 指向
///   `_activeCaptchaJobs[taskKey] == workerId`；[jobKey] 等于 [taskKey]，
///   [pageKey] 为 null。
///
/// 一旦 slot 处于 idle → video 派活路径，调度器只把 `kind` 改成 video、
/// 设置 [pageKey]，不需要重建 slot 实例，也不会从
/// [`_webViewWorkerSlots`] 移除再插入 → widget 树的
/// `ValueKey('worker_$workerId')` 不变，Flutter 不销毁 [InAppWebView]，
/// 上一任 captcha job 通过后同源 video 提取能真正复用同一个浏览器实例
///（job kind 切换的细节见 [ReusableBrowserWorker] / runner 的
/// `_lastAcceptedKind` 统计）。
///
/// 双向反查表（`_activeVideoJobs` / `_activeCaptchaJobs`）与
/// [pageKey] / [taskKey] 必须保持一致：任何 slot 字段修改都要同步更新
/// 对应反查表，否则 build 阶段 `_buildWebViewExtractorsPool` 与
/// `_handleSearchCaptchaPreflightResult` 等会失配。
///
/// 上一任 job 的源名缓存在 [lastSourceName]（job 完成/取消后保留），供
/// source-affinity 调度在空闲 worker 选取时优先命中同源 warm WebView。
class WebViewWorkerSlot {
  final int workerId;

  /// 当前 job 的 pageKey（kind==video 时非空，kind==captcha 时为 null）。
  String? pageKey;

  /// 当前 captcha job 的 taskKey（kind==captcha 时非空，kind==video 时为
  /// null）。两个字段并存的二选一，由 [kind] 决定。
  String? taskKey;

  /// 上一任 job 的 sourceName。job 完成/取消后不清空，供下一轮 affinity
  /// 选取使用。worker 首次创建时为 null。
  String? lastSourceName;
  WebViewWorkerHealth health = WebViewWorkerHealth.idle;
  int consecutiveFailures = 0;

  /// 当前 job 的类型，null 表示 slot idle。build 阶段会以此决定渲染哪个
  /// runner 的 job payload（CaptchaJob / VideoJob / null）。
  WebViewWorkerKind? kind;

  /// 新建 slot 时一律 [kind] = null（idle），由调度器派活时再设置。
  WebViewWorkerSlot({required this.workerId});

  /// 调度器记账 key（pageKey 或 taskKey，取决于 kind）。为空 ↔ idle。
  String? get jobKey => pageKey ?? taskKey;

  bool get isIdle => kind == null;
  bool get canAcceptJob => isIdle && health == WebViewWorkerHealth.idle;
  bool get canDisposeWhenIdle =>
      isIdle &&
      health != WebViewWorkerHealth.running &&
      health != WebViewWorkerHealth.cancelling;

  /// 重置为 idle 状态（保留 lastSourceName / health / consecutiveFailures，
  /// 仅清空当前 job 字段与 kind）。调度器收回 slot 时使用。
  void clearCurrentJob() {
    pageKey = null;
    taskKey = null;
    kind = null;
  }
}

/// 5B step 3：worker slot 当前承载的 job 类型。`null` 用 [`WebViewWorkerSlot.kind`]
/// 直接表达 idle，这里只声明两种业务 job 类型。
enum WebViewWorkerKind { video, captcha }

enum WebViewWorkerHealth { idle, running, cancelling, unhealthy }
