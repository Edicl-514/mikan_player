import 'dart:collection';

import 'package:mikan_player/services/captcha_webview_bypasser.dart';
import 'package:mikan_player/src/rust/api/generic_scraper.dart';

/// Phase 1.3: captcha preflight task queue + runtime-override bookkeeping.
///
/// Owns the pending/active task maps and captcha runtime overrides. Does **not**
/// start WebView workers, touch [SourceRequestGate] timers, or call
/// `setState` — the page (or a thin host) still decides when a task may start
/// (gate cooldown + scheduler slot) and applies UI side effects.
///
/// Pure helpers for search-result → [SourceRuntimeOverride] conversion live as
/// top-level functions so they unit-test without Flutter.

class CaptchaPreflightTask {
  final String taskKey;
  final String label;
  final SourceState source;
  final String? searchKeyword;
  final String? initialUrl;
  final String? referer;
  final String? initialCookies;
  final CaptchaConfig captchaConfig;
  final int loadToken;
  final void Function(CaptchaPreflightTask task, CaptchaBypassResult result)
  onResult;

  const CaptchaPreflightTask({
    required this.taskKey,
    required this.label,
    required this.source,
    this.searchKeyword,
    this.initialUrl,
    this.referer,
    this.initialCookies,
    required this.captchaConfig,
    required this.loadToken,
    required this.onResult,
  });
}

/// Result of scanning the pending queue under a per-source [canStartNow] gate.
class CaptchaQueuePollResult {
  const CaptchaQueuePollResult({
    required this.ready,
    required this.stillPending,
    required this.coolingSources,
  });

  /// First pending task whose source may start now, or null if none are ready.
  final CaptchaPreflightTask? ready;

  /// Remaining pending tasks (including those still cooling), FIFO order.
  final List<CaptchaPreflightTask> stillPending;

  /// Source names that were skipped because [canStartNow] was false (unique).
  final List<String> coolingSources;
}

class PlayerCaptchaPreflightCoordinator {
  PlayerCaptchaPreflightCoordinator();

  final Queue<CaptchaPreflightTask> _pending = Queue<CaptchaPreflightTask>();
  final Map<String, CaptchaPreflightTask> _active =
      <String, CaptchaPreflightTask>{};
  final Map<String, SourceRuntimeOverride> _runtimeOverrides =
      <String, SourceRuntimeOverride>{};

  Queue<CaptchaPreflightTask> get pendingTasks => _pending;

  Map<String, CaptchaPreflightTask> get activeTasks => _active;

  Map<String, SourceRuntimeOverride> get runtimeOverrides => _runtimeOverrides;

  int get pendingCount => _pending.length;

  int get activeCount => _active.length;

  bool get hasPending => _pending.isNotEmpty;

  bool isActive(String taskKey) => _active.containsKey(taskKey);

  CaptchaPreflightTask? activeTask(String taskKey) => _active[taskKey];

  /// Enqueue a preflight task unless the same [taskKey] is already pending/active.
  ///
  /// Returns `true` when the task was added.
  bool queueTask({
    required String taskKey,
    required String label,
    required SourceState source,
    String? searchKeyword,
    String? initialUrl,
    String? referer,
    String? initialCookies,
    required int loadToken,
    required void Function(CaptchaPreflightTask task, CaptchaBypassResult result)
    onResult,
  }) {
    final captchaConfig = CaptchaConfig.tryParse(source.captchaConfigJson);
    if (captchaConfig == null) {
      return false;
    }

    final alreadyPending = _pending.any((task) => task.taskKey == taskKey);
    if (alreadyPending || _active.containsKey(taskKey)) {
      return false;
    }

    _pending.add(
      CaptchaPreflightTask(
        taskKey: taskKey,
        label: label,
        source: source,
        searchKeyword: searchKeyword,
        initialUrl: initialUrl,
        referer: referer,
        initialCookies: initialCookies,
        captchaConfig: captchaConfig,
        loadToken: loadToken,
        onResult: onResult,
      ),
    );
    return true;
  }

  /// Convenience for search-stream captcha preflight (`search:<source>` key).
  bool queueSearchTask({
    required SourceState source,
    required String searchKeyword,
    required int loadToken,
    required void Function(CaptchaPreflightTask task, CaptchaBypassResult result)
    onResult,
  }) {
    return queueTask(
      taskKey: 'search:${source.name}',
      label: source.name,
      source: source,
      searchKeyword: searchKeyword,
      loadToken: loadToken,
      onResult: onResult,
    );
  }

  /// Drain [_pending] once, pick the first task allowed by [canStartNow], and
  /// leave the rest in [CaptchaQueuePollResult.stillPending] (caller re-queues).
  ///
  /// Does not mutate active map; does not re-add still-pending (so the page can
  /// schedule gate callbacks before restoring the queue).
  CaptchaQueuePollResult pollNextReady({
    required bool Function(String sourceName, Duration interval) canStartNow,
    required Duration Function(CaptchaPreflightTask task) intervalFor,
  }) {
    if (_pending.isEmpty) {
      return const CaptchaQueuePollResult(
        ready: null,
        stillPending: <CaptchaPreflightTask>[],
        coolingSources: <String>[],
      );
    }

    final stillPending = <CaptchaPreflightTask>[];
    final coolingSources = <String>{};
    CaptchaPreflightTask? ready;
    while (_pending.isNotEmpty) {
      final candidate = _pending.removeFirst();
      final interval = intervalFor(candidate);
      final allowed = canStartNow(candidate.source.name, interval);
      if (ready == null && allowed) {
        ready = candidate;
        continue;
      }
      stillPending.add(candidate);
      if (!allowed) {
        coolingSources.add(candidate.source.name);
      }
    }
    return CaptchaQueuePollResult(
      ready: ready,
      stillPending: stillPending,
      coolingSources: coolingSources.toList(growable: false),
    );
  }

  /// Restore tasks into the pending queue (after [pollNextReady]).
  void restorePending(Iterable<CaptchaPreflightTask> tasks) {
    for (final task in tasks) {
      _pending.add(task);
    }
  }

  /// Put [task] back at the front of the pending queue (no slot available).
  void requeueFront(CaptchaPreflightTask task) {
    _pending.addFirst(task);
  }

  /// Remove pending tasks matching [test] (used by cancel-lower-priority).
  void removePendingWhere(bool Function(CaptchaPreflightTask task) test) {
    _pending.removeWhere(test);
  }

  /// Mark [task] as active (started).
  void markActive(CaptchaPreflightTask task) {
    _active[task.taskKey] = task;
  }

  /// Remove and return the active task for [taskKey], if any.
  CaptchaPreflightTask? removeActive(String taskKey) => _active.remove(taskKey);

  void setRuntimeOverride(String sourceName, SourceRuntimeOverride override) {
    _runtimeOverrides[sourceName] = override;
  }

  SourceRuntimeOverride? runtimeOverrideFor(String sourceName) =>
      _runtimeOverrides[sourceName];

  Map<String, SourceRuntimeOverride> takeRuntimeOverridesSnapshot() =>
      Map<String, SourceRuntimeOverride>.from(_runtimeOverrides);

  /// Clear all pending/active tasks (episode switch / new search).
  void clearTasks() {
    _active.clear();
    _pending.clear();
  }

  /// Clear tasks + runtime overrides (episode switch full reset).
  void resetForNewSearch() {
    clearTasks();
    _runtimeOverrides.clear();
  }

  void clearForDispose() {
    resetForNewSearch();
  }
}

/// Build the [SourceRuntimeOverride] fed into search after captcha preflight.
SourceRuntimeOverride buildSearchCaptchaRuntimeOverride({
  required SourceState source,
  required CaptchaBypassResult result,
}) {
  if (result.success) {
    return SourceRuntimeOverride(
      sourceName: source.name,
      cookies: result.cookies,
      searchPageHtml: result.searchPageHtml,
      searchPageUrl: result.searchPageUrl,
      detailPageHtml: result.detailPageHtml,
      detailPageUrl: result.detailPageUrl,
    );
  }
  return SourceRuntimeOverride(
    sourceName: source.name,
    skipSearchError: result.error ?? 'Captcha preflight failed',
  );
}
