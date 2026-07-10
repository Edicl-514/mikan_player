// Slot-based concurrency queue for downloads.
//
// Pure counter/state, no Flutter or network dependencies. Caller decides
// whether a task is currently eligible to acquire a slot (via
// [isTaskEligible]) — that keeps the queue reusable for HTTP, BT, and any
// future backend without baking in status knowledge.

import 'dart:async';
import 'dart:collection';

/// Callback used by [DownloadQueue] to ask the owner whether [taskId] is
/// still allowed to acquire or hold a slot. Returning `false` while the task
/// is waiting causes its wait to complete with `false` (cancellation).
typedef IsTaskEligible = bool Function(String taskId);

class _SlotWaiter {
  final String taskId;
  final Completer<bool> completer = Completer<bool>();

  _SlotWaiter(this.taskId);
}

/// Max-concurrency download slot coordinator.
///
/// Behavior matches the slot logic that previously lived inside
/// `DownloadManager`:
/// - At most [maxConcurrent] tasks hold a slot at once.
/// - Additional tasks wait in FIFO order and are granted a slot the moment
///   one is released or the cap is raised.
/// - Releasing a slot drains the queue.
/// - If a task becomes ineligible (paused, removed, terminal status) while
///   waiting, its waiter is completed with `false`.
/// - Transfer lets a slot holder be renamed (used when a fallback id is
///   replaced by the real info-hash after torrent metadata arrives).
class DownloadQueue {
  DownloadQueue({int maxConcurrent = 3, IsTaskEligible? isTaskEligible})
    : _maxConcurrent = maxConcurrent,
      _isTaskEligible = isTaskEligible ?? _alwaysEligible;

  int _maxConcurrent;

  /// Maximum number of tasks that may hold a slot simultaneously.
  int get maxConcurrent => _maxConcurrent;

  /// Maximum number of tasks that may hold a slot simultaneously.
  ///
  /// Changing this value mid-flight triggers an immediate drain — waiters
  /// that fit in the new cap are granted a slot.
  set maxConcurrent(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'maxConcurrent', 'must be >= 1');
    }
    _maxConcurrent = value;
    drain();
  }

  IsTaskEligible _isTaskEligible;
  set isTaskEligible(IsTaskEligible value) {
    _isTaskEligible = value;
  }

  static bool _alwaysEligible(String _) => true;

  final Queue<_SlotWaiter> _queue = Queue();
  final Set<String> _holders = {};

  /// Number of tasks currently holding a slot.
  int get activeSlotCount => _holders.length;

  /// True when the queue is empty and a free slot is available.
  bool get hasAvailableSlot =>
      _queue.isEmpty && _holders.length < _maxConcurrent;

  /// True when [taskId] is one of the current slot holders.
  bool isHolder(String taskId) => _holders.contains(taskId);

  /// Acquire a download slot for [taskId], waiting if the limit is reached.
  ///
  /// Returns `true` once a slot is held. Returns `false` if the task is not
  /// eligible to acquire (paused/removed/terminal) at acquire time, or while
  /// waiting.
  Future<bool> acquire(String taskId) async {
    _reconcile();
    if (!_isTaskEligible(taskId)) return false;
    if (_holders.contains(taskId)) return true;

    if (_queue.isEmpty && _holders.length < _maxConcurrent) {
      _holders.add(taskId);
      return true;
    }

    final waiter = _SlotWaiter(taskId);
    _queue.add(waiter);
    _drain();
    return waiter.completer.future;
  }

  /// Release a download slot held by [taskId]. No-op if the task doesn't
  /// currently hold a slot. Always triggers a drain so the next waiter can
  /// claim the freed slot.
  void release(String taskId) {
    if (_holders.remove(taskId)) {
      _drain();
    }
  }

  /// Transfer the slot from [oldTaskId] to [newTaskId]. Used when a task
  /// placeholder is replaced by the real id (e.g. info-hash from metadata).
  ///
  /// If [oldTaskId] doesn't currently hold a slot this is a no-op.
  void transfer(String oldTaskId, String newTaskId) {
    if (oldTaskId == newTaskId) return;
    if (_holders.remove(oldTaskId)) {
      _holders.add(newTaskId);
    }
    _reconcile();
  }

  /// Try to grant slots to as many waiters as the current cap allows. Public
  /// so the owner can call this after a config change (e.g. raising
  /// `maxConcurrent`).
  void drain() => _drain();

  void _drain() {
    _reconcile();
    while (_queue.isNotEmpty && _holders.length < _maxConcurrent) {
      final next = _queue.removeFirst();
      if (next.completer.isCompleted) continue;
      if (!_isTaskEligible(next.taskId)) {
        next.completer.complete(false);
        continue;
      }
      if (_holders.contains(next.taskId)) {
        next.completer.complete(true);
        continue;
      }
      _holders.add(next.taskId);
      next.completer.complete(true);
    }
  }

  /// Drop holders that are no longer eligible (e.g. paused, removed,
  /// terminal status). Slot count is derived from [_holders] so it can never
  /// drift from the holder set.
  void _reconcile() {
    final stale = _holders
        .where((taskId) => !_isTaskEligible(taskId))
        .toList(growable: false);
    for (final taskId in stale) {
      _holders.remove(taskId);
    }
  }
}
