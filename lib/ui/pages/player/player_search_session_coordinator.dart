import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';
import 'package:mikan_player/ui/pages/player/player_search_session_policy.dart';
import 'package:mikan_player/ui/pages/player/sample_search_finish_policy.dart';

/// Phase 1.4: sample search session helpers + subscription bookkeeping.
///
/// Owns the list of in-flight [SourceSearchProgress] stream subscriptions and
/// pure partition / status helpers. Does **not** open media, pump WebViews, or
/// call `setState` — the page injects stream listen side effects via callbacks
/// on [PlayerSearchSessionCoordinator.launchStream].

/// Partition enabled sources into captcha-preflight vs direct-search cohorts.
/// Captcha sources are sorted by tier ascending (historic load order).
class SampleSourceCohorts {
  const SampleSourceCohorts({
    required this.captchaSources,
    required this.nonCaptchaSources,
  });

  final List<SourceState> captchaSources;
  final List<SourceState> nonCaptchaSources;
}

SampleSourceCohorts partitionEnabledSources(List<SourceState> enabledSources) {
  final captchaSources =
      enabledSources
          .where(
            (source) => CaptchaConfig.tryParse(source.captchaConfigJson) != null,
          )
          .toList()
        ..sort((a, b) => a.tier.compareTo(b.tier));
  final captchaNames = captchaSources.map((s) => s.name).toSet();
  final nonCaptchaSources = enabledSources
      .where((source) => !captchaNames.contains(source.name))
      .toList();
  return SampleSourceCohorts(
    captchaSources: captchaSources,
    nonCaptchaSources: nonCaptchaSources,
  );
}

/// Status line while captcha + search are in flight.
String sampleSearchProgressLabel({
  required int completedCount,
  required int enabledCount,
  required int activeCaptcha,
  required int pendingCaptcha,
}) {
  return '搜索进度: $completedCount/$enabledCount，'
      '验证码 $activeCaptcha 运行/$pendingCaptcha 排队';
}

/// Terminal idle status / error after [mayMarkSampleSearchIdle] is true.
class SampleSearchFinishMessage {
  const SampleSearchFinishMessage({this.error, this.status});

  final String? error;
  final String? status;
}

SampleSearchFinishMessage sampleSearchFinishMessage({
  required int playPageCount,
  required int successfulSourceCount,
}) {
  if (playPageCount == 0) {
    return const SampleSearchFinishMessage(error: '未在任何源中找到该动画');
  }
  if (successfulSourceCount == 0) {
    return const SampleSearchFinishMessage(error: '所有源都无法提取视频链接');
  }
  return SampleSearchFinishMessage(
    status: '搜索完成，共找到 $successfulSourceCount 个可用源',
  );
}

/// Count terminal (success/failed) entries in a progress map.
int completedSearchSourceCount(
  Map<String, SourceSearchProgress> sourceProgressMap,
) {
  return sourceProgressMap.values
      .where((p) => isSearchStepTerminal(p.step))
      .length;
}

/// Thin owner of search stream subscriptions for one player page lifetime.
class PlayerSearchSessionCoordinator {
  PlayerSearchSessionCoordinator();

  final List<StreamSubscription<SourceSearchProgress>> _subscriptions =
      <StreamSubscription<SourceSearchProgress>>[];

  List<StreamSubscription<SourceSearchProgress>> get subscriptions =>
      _subscriptions;

  bool get hasSubscriptions => _subscriptions.isNotEmpty;

  int get subscriptionCount => _subscriptions.length;

  /// Cancel every tracked subscription and clear the list.
  Future<void> cancelAll() async {
    if (_subscriptions.isEmpty) return;
    final pending = List<StreamSubscription<SourceSearchProgress>>.from(
      _subscriptions,
    );
    _subscriptions.clear();
    for (final subscription in pending) {
      try {
        await subscription.cancel();
      } catch (e) {
        debugPrint('[SampleSearch] cancel subscription failed: $e');
      }
    }
  }

  /// Drop tracking without awaiting cancel (used inside setState resets when
  /// [cancelAll] already ran, or when intentionally abandoning handles).
  void clearTracking() {
    _subscriptions.clear();
  }

  /// Listen to [stream], track the subscription, and wire generation-safe
  /// progress / error / done callbacks.
  void launchStream({
    required Stream<SourceSearchProgress> stream,
    required Set<String> targetSources,
    required int loadToken,
    required int Function() currentLoadToken,
    required bool Function() isDisposed,
    required void Function(SourceSearchProgress progress) onProgress,
    required void Function(Object error, Iterable<String> unfinishedSources)
    onStreamError,
    required void Function() onDoneOrMaybeFinish,
    required String streamTag,
  }) {
    if (targetSources.isEmpty) return;

    late final StreamSubscription<SourceSearchProgress> subscription;
    subscription = stream.listen(
      (progress) {
        if (!isSearchGenerationCurrent(
          resultLoadToken: loadToken,
          currentLoadToken: currentLoadToken(),
          isDisposed: isDisposed(),
        )) {
          return;
        }
        if (!targetSources.contains(progress.sourceName)) {
          return;
        }
        onProgress(progress);
      },
      onError: (Object error, StackTrace _) {
        debugPrint('[SampleSearch][$streamTag] stream error: $error');
        _subscriptions.remove(subscription);
        if (!isSearchGenerationCurrent(
          resultLoadToken: loadToken,
          currentLoadToken: currentLoadToken(),
          isDisposed: isDisposed(),
        )) {
          return;
        }
        onStreamError(error, targetSources);
      },
      onDone: () {
        _subscriptions.remove(subscription);
        if (!isSearchGenerationCurrent(
          resultLoadToken: loadToken,
          currentLoadToken: currentLoadToken(),
          isDisposed: isDisposed(),
        )) {
          return;
        }
        onDoneOrMaybeFinish();
      },
      cancelOnError: true,
    );

    _subscriptions.add(subscription);
  }

  void clearForDispose() {
    // Fire-and-forget: dispose path also awaits cancelAll separately when needed.
    unawaited(cancelAll());
  }
}
