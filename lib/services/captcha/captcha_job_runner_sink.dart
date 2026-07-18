import 'package:mikan_player/services/captcha_webview_bypasser.dart';

/// External callbacks the runner emits. Decoupled from the host widget so the
/// runner is portable across the current [ReusableCaptchaWebViewBypasser] and
/// the future [ReusableBrowserWorker].
///
/// Stateless — has no WebView / scheduler / token state, so it can live in
/// its own library file separate from the [CaptchaJobRunner] orchestration.
/// The runner entry re-exports this type (see
/// `lib/services/webview_captcha_job_runner.dart`) so existing importers do
/// not need to add a new package import.
class CaptchaJobRunnerSink {
  CaptchaJobRunnerSink({this.onResult, this.onIdle, this.onLog});

  final void Function(CaptchaPreflightJob job, CaptchaBypassResult result)?
  onResult;
  final void Function(int workerId, CaptchaPreflightJob job)? onIdle;
  final void Function(String message)? onLog;
}
