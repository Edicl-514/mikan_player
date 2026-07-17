import 'package:mikan_player/utils/source_channel_key.dart';

/// Phase 1.6: pure helpers for autoplay accept + cancel-lower-priority policy.
///
/// The player-page autoplay host still owns scheduler cancel / stats / WebView
/// bookkeeping. These helpers answer "which captcha task keys / webview page
/// keys are cancellable once [acceptedPageKey] is playing?"

/// Whether a source may be cancelled after a Tier-0 (or accepted) source starts.
///
/// Historic rule: never cancel the accepted source name; never cancel tier==0;
/// missing tier defaults to 999 (cancellable).
bool isCancellableSourceAfterAccept({
  required String sourceName,
  required String acceptedPageKey,
  required Map<String, int> sourceTiers,
}) {
  if (sourceName == SourceChannelKey.fromPageKey(acceptedPageKey).sourceName) {
    return false;
  }
  return (sourceTiers[sourceName] ?? 999) != 0;
}

/// Whether a WebView extraction [pageKey] may be cancelled after accept.
bool isCancellableWebViewPageKeyAfterAccept({
  required String pageKey,
  required String acceptedPageKey,
  required Map<String, int> sourceTiers,
}) {
  if (pageKey == acceptedPageKey) return false;
  return isCancellableSourceAfterAccept(
    sourceName: SourceChannelKey.fromPageKey(pageKey).sourceName,
    acceptedPageKey: acceptedPageKey,
    sourceTiers: sourceTiers,
  );
}

/// Filter captcha task keys that should be cancelled after accept.
List<String> captchaTaskKeysToCancelAfterAccept({
  required Map<String, String> activeTaskKeyToSourceName,
  required String acceptedPageKey,
  required Map<String, int> sourceTiers,
}) {
  return activeTaskKeyToSourceName.entries
      .where(
        (e) => isCancellableSourceAfterAccept(
          sourceName: e.value,
          acceptedPageKey: acceptedPageKey,
          sourceTiers: sourceTiers,
        ),
      )
      .map((e) => e.key)
      .toList();
}

/// Filter video page keys that should be cancelled after accept.
List<String> videoPageKeysToCancelAfterAccept({
  required Iterable<String> activeVideoPageKeys,
  required String acceptedPageKey,
  required Map<String, int> sourceTiers,
}) {
  return activeVideoPageKeys
      .where(
        (pageKey) => isCancellableWebViewPageKeyAfterAccept(
          pageKey: pageKey,
          acceptedPageKey: acceptedPageKey,
          sourceTiers: sourceTiers,
        ),
      )
      .toList();
}
