part of '../webview_captcha_job_runner.dart';

// Search-stage helpers extracted from `webview_captcha_job_runner.dart`.
//
// Pure normalization / scoring helpers live at file scope as
// library-private free functions; the state-touching candidate selection
// and initial URL resolution live as a private extension on
// [CaptchaJobRunner] so they can read `_currentJob` / `_log`.

// --------------------- Pure string / scoring helpers ---------------------

String? _preprocessSearchKeyword(String? keyword) {
  final trimmed = keyword?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final core = _extractCoreName(trimmed);
  return core.isNotEmpty ? core : trimmed;
}

String _extractCoreName(String name) {
  var value = name.trim();
  final seasonPatterns = [
    RegExp(r'第[一二三四五六七八九十\d]+\s*季', caseSensitive: false),
    RegExp(r'part\s*\d+', caseSensitive: false),
    RegExp(r'\bseason\s*\d+\b', caseSensitive: false),
    RegExp(r'\b\d+(st|nd|rd|th)\s*season\b', caseSensitive: false),
  ];
  for (final pattern in seasonPatterns) {
    value = value.replaceAll(pattern, ' ');
  }
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _calculateMatchScore(String title, String query, String core) {
  final titleNorm = _normalizeForMatch(title);
  final queryNorm = _normalizeForMatch(query);
  final coreNorm = _normalizeForMatch(core);
  final titleCoreNorm = _normalizeForMatch(_extractCoreName(title));

  if (titleNorm.isEmpty) return 0;
  if (queryNorm.isNotEmpty && titleNorm == queryNorm) return 100;
  if (coreNorm.isNotEmpty && titleCoreNorm == coreNorm) return 95;
  if (queryNorm.isNotEmpty && titleNorm.contains(queryNorm)) return 70;
  if (coreNorm.isNotEmpty && titleCoreNorm.contains(coreNorm)) return 57;
  return 0;
}

String _normalizeForMatch(String value) {
  return value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    '',
  );
}

// --------------------- State-touching selection / resolution ---------------------

extension _CaptchaRunnerSearchFlow on CaptchaJobRunner {
  /// Selects the best detail candidate from the WebView search page by
  /// running [_SearchExtractionConfig]'s extract script and scoring the
  /// candidates against the job's search keyword.
  Future<_SearchCandidate?> _selectBestSearchCandidate(
    InAppWebViewController ctrl,
    String? currentUrl,
  ) async {
    final job = _currentJob;
    if (job == null) return null;
    final config = _SearchExtractionConfig.tryParse(
      job.source.searchConfigJson,
    );
    if (config == null) {
      _log('Unable to parse searchConfigJson for WebView detail mode');
      return null;
    }

    final candidates = await _extractSearchCandidates(
      ctrl,
      config: config,
      currentUrl: currentUrl,
    );
    if (candidates.isEmpty) {
      _log('No search candidates extracted from WebView search page');
      return null;
    }

    final query = _preprocessSearchKeyword(job.searchKeyword) ?? '';
    if (query.isEmpty) {
      final first = candidates.first;
      return _SearchCandidate(title: first.title, url: first.url, score: 0);
    }
    final core = _extractCoreName(query);

    _SearchCandidate? best;
    for (final item in candidates) {
      final score = _calculateMatchScore(item.title, query, core);
      if (score >= CaptchaJobRunner._matchScoreThreshold &&
          (best == null || score > best.score)) {
        best = _SearchCandidate(title: item.title, url: item.url, score: score);
      }
    }

    if (best == null && candidates.isNotEmpty) {
      _log(
        'No candidate meets score≥${CaptchaJobRunner._matchScoreThreshold} '
        '(best was ${candidates.map((c) => _calculateMatchScore(c.title, query, core)).reduce(math.max)})',
      );
    }

    return best;
  }

  /// Computes the initial URL the runner should load when [acceptJob]
  /// begins a job: prefers the job's explicit `initialUrl`, falls back to
  /// the source `searchUrl` template with the keyword interpolated in.
  String? _resolveInitialUrl() {
    final job = _currentJob;
    if (job == null) return null;
    final customInitial = job.initialUrl?.trim();
    if (customInitial != null && customInitial.isNotEmpty) {
      return customInitial;
    }

    final searchTemplate = job.source.searchUrl.trim();
    if (searchTemplate.isEmpty) {
      return null;
    }

    final keyword = _preprocessSearchKeyword(job.searchKeyword);
    if (keyword != null && keyword.isNotEmpty) {
      return searchTemplate.replaceAll('{keyword}', keyword);
    }

    if (!searchTemplate.contains('{keyword}')) {
      return searchTemplate;
    }

    return null;
  }

  /// Runs the configured extract script and splits the JSON response into
  /// scored candidates. Empty / parse-failed runs yield an empty list.
  Future<List<_ExtractedCandidate>> _extractSearchCandidates(
    InAppWebViewController ctrl, {
    required _SearchExtractionConfig config,
    required String? currentUrl,
  }) async {
    final script = config.buildExtractScript(baseUrl: currentUrl);
    try {
      final raw = await ctrl.evaluateJavascript(source: script);
      if (raw is! String || raw.isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _ExtractedCandidate(
              title: (item['title'] ?? '').toString().trim(),
              url: (item['url'] ?? '').toString().trim(),
            ),
          )
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList();
    } catch (e) {
      _log('Failed to extract search candidates in WebView: $e');
      return const [];
    }
  }
}
