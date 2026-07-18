part of '../webview_captcha_job_runner.dart';

// Detail-stage transition extracted from `_completeSuccess` in
// `webview_captcha_job_runner.dart`.
//
// The search→detail handoff is a small but tricky slice of the runner:
// when a source opts into `useWebViewForDetail`, the search page and the
// detail page are two separate WebView navigations that share the same
// captcha bypass session. `_maybeAdvanceToDetailStage` is called by
// `_completeSuccess` after every successful captcha bypass / detection
// round. When it returns true, the runner has navigated to the detail page
// and the caller must short-circuit `_completeSuccess` so the next
// `onLoadStop` re-runs it in the `detail` stage. When it returns false,
// the caller proceeds to assemble and emit the [CaptchaBypassResult].

extension _CaptchaRunnerDetailFlow on CaptchaJobRunner {
  /// Tries to advance the runner from the `search` stage to the `detail`
  /// stage by loading the best-scoring candidate extracted from the
  /// search page.
  ///
  /// Returns `true` when the runner has loaded a detail URL and the caller
  /// must short-circuit `_completeSuccess` (the detail page's `onLoadStop`
  /// will eventually rerun `_completeSuccess` and emit the result). Returns
  /// `false` when the source didn't opt into WebView detail mode, the
  /// detail-candidate extraction failed, or the runner is not in the
  /// search stage — in all of which cases the caller should proceed to
  /// build the final [CaptchaBypassResult].
  Future<bool> _maybeAdvanceToDetailStage(
    InAppWebViewController ctrl, {
    required int token,
    required String? effectiveUrl,
    required String? finalHtml,
  }) async {
    final job = _currentJob;
    final config = job?.captchaConfig;
    if (job == null || config == null) return false;
    if (!_isSearchEntryFlow ||
        !config.useWebViewForDetail ||
        _flowStage != _WebViewFlowStage.search) {
      return false;
    }

    _searchPageHtml = finalHtml;
    _searchPageUrl = effectiveUrl;

    final detailCandidate = await _selectBestSearchCandidate(
      ctrl,
      effectiveUrl,
    );
    if (detailCandidate == null) {
      _log('WebView detail mode enabled, but no detail candidate was found');
      return false;
    }

    _flowStage = _WebViewFlowStage.detail;
    _log(
      'Using WebView for detail page: "${detailCandidate.title}" '
      '(score=${detailCandidate.score}) -> ${detailCandidate.url}',
    );
    _refreshTimeout(token: token);
    await ctrl.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(detailCandidate.url),
        headers: CaptchaJobRunner._buildNavigationHeaders(
          detailCandidate.url,
          referer: effectiveUrl,
        ),
      ),
    );
    return true;
  }
}
