part of '../webview_captcha_job_runner.dart';

// Type definitions extracted from `webview_captcha_job_runner.dart`.
//
// Each enum / value class lives here so the orchestration, page-signal
// helpers, search-flow helpers, and detail-flow extension can share the
// same private symbols without polluting the entry file. All names keep
// the underscore prefix — they are still library-private.

/// Whether the WebView is currently showing the search results page or the
/// detail page it drilled into. Set by the detail-flow extension only.
enum _WebViewFlowStage { search, detail }

/// Outcome of a readiness poll. Used by the page-signal helpers and the
/// OCR retry loop to coordinate "captcha present", "success present",
/// "poll expired", "poll superseded by a newer load event", and "poll
/// cancelled by job cancel / complete".
enum _CaptchaPageSignal { captcha, success, timedOut, superseded, cancelled }

/// Result of an eager (mid-load) readiness probe. Distinguishes "page is
/// still loading" from "interactive but no captcha or success yet" from
/// the two ready states.
enum _EagerReadiness { loading, notReady, captchaReady, successReady }

/// Immutable scored candidate produced by the search-flow extraction.
class _SearchCandidate {
  final String title;
  final String url;
  final int score;

  const _SearchCandidate({
    required this.title,
    required this.url,
    required this.score,
  });
}

/// Immutable (title, url) record returned by the JS extraction before the
/// search-flow extension scores it.
class _ExtractedCandidate {
  final String title;
  final String url;

  const _ExtractedCandidate({required this.title, required this.url});
}

/// Parses a source's `searchConfigJson` into a small builder used by the
/// search-flow extension when extracting candidates from the loaded page
/// DOM. Self-contained — only depends on `dart:convert` (visible via the
/// part-of library imports).
class _SearchExtractionConfig {
  final String formatId;
  final String? selectLists;
  final String? selectNames;
  final String? selectLinks;

  const _SearchExtractionConfig({
    required this.formatId,
    this.selectLists,
    this.selectNames,
    this.selectLinks,
  });

  static _SearchExtractionConfig? tryParse(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final root = jsonDecode(jsonStr) as Map<String, dynamic>;
      final formatId = (root['subjectFormatId'] as String?) ?? 'indexed';
      final formatA = root['selectorSubjectFormatA'] as Map<String, dynamic>?;
      final formatIndexed =
          root['selectorSubjectFormatIndexed'] as Map<String, dynamic>?;
      return _SearchExtractionConfig(
        formatId: formatId,
        selectLists: formatA?['selectLists'] as String?,
        selectNames: formatIndexed?['selectNames'] as String?,
        selectLinks: formatIndexed?['selectLinks'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String buildExtractScript({required String? baseUrl}) {
    final baseUrlLiteral = jsonEncode(baseUrl ?? '');
    if (formatId == 'a' &&
        selectLists != null &&
        selectLists!.trim().isNotEmpty) {
      final listSelectorLiteral = jsonEncode(selectLists);
      return '''
(function() {
  var baseUrl = $baseUrlLiteral;
  var selector = $listSelectorLiteral;
  try {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(selector));
    var results = nodes.map(function(node) {
      var href = node.getAttribute('href') || '';
      try {
        if (href && baseUrl) {
          href = new URL(href, baseUrl).toString();
        }
      } catch (_) {}
      return {
        title: (node.textContent || '').trim(),
        url: href
      };
    }).filter(function(item) {
      return item.title && item.url;
    });
    return JSON.stringify(results);
  } catch (_) {
    return '[]';
  }
})()
''';
    }

    final nameSelectorLiteral = jsonEncode(selectNames ?? '');
    final linkSelectorLiteral = jsonEncode(selectLinks ?? '');
    return '''
(function() {
  var baseUrl = $baseUrlLiteral;
  var nameSelector = $nameSelectorLiteral;
  var linkSelector = $linkSelectorLiteral;
  try {
    var names = Array.prototype.slice.call(document.querySelectorAll(nameSelector));
    var links = Array.prototype.slice.call(document.querySelectorAll(linkSelector));
    var length = Math.min(names.length, links.length);
    var results = [];
    for (var i = 0; i < length; i++) {
      var href = links[i].getAttribute('href') || '';
      try {
        if (href && baseUrl) {
          href = new URL(href, baseUrl).toString();
        }
      } catch (_) {}
      results.push({
        title: (names[i].textContent || '').trim(),
        url: href
      });
    }
    return JSON.stringify(results.filter(function(item) {
      return item.title && item.url;
    }));
  } catch (_) {
    return '[]';
  }
})()
''';
  }
}
