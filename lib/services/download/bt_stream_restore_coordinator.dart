import 'dart:async';

typedef BtStreamRestoreOperation =
    Future<void> Function(bool Function() isCurrent);
typedef BtStreamRestoreErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// Serializes delayed stream-to-background restore jobs per info-hash.
///
/// A generation token invalidates an older job when playback reattaches or a
/// replacement stream is created. All jobs remain awaitable until their delay
/// and cleanup finish, including jobs that have been cancelled logically.
class BtStreamRestoreCoordinator {
  BtStreamRestoreCoordinator({
    Future<void> Function(Duration)? sleep,
    BtStreamRestoreErrorHandler? onError,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _onError = onError;

  final Future<void> Function(Duration) _sleep;
  final BtStreamRestoreErrorHandler? _onError;
  final Map<String, Future<void>> _currentJobs = {};
  final Set<Future<void>> _allJobs = {};
  final Map<String, int> _generations = {};
  bool _disposed = false;

  Future<void> schedule(
    String infoHash, {
    required Duration delay,
    required BtStreamRestoreOperation operation,
  }) {
    final hashLower = infoHash.toLowerCase();
    final existing = _currentJobs[hashLower];
    if (existing != null) return existing;

    final generation = _generations[hashLower] ?? 0;
    final completer = Completer<void>();
    final future = completer.future;

    // Register before starting the worker. A zero-delay operation may return
    // before its first await, so registering afterwards can leave a completed
    // Future stuck in the map forever.
    _currentJobs[hashLower] = future;
    _allJobs.add(future);
    unawaited(
      _run(
        hashLower,
        generation: generation,
        delay: delay,
        operation: operation,
        future: future,
        completer: completer,
      ),
    );
    return future;
  }

  void cancel(String infoHash) {
    final hashLower = infoHash.toLowerCase();
    _generations[hashLower] = (_generations[hashLower] ?? 0) + 1;
    _currentJobs.remove(hashLower);
  }

  Future<void> waitForIdle() async {
    while (_allJobs.isNotEmpty) {
      await Future.wait(_allJobs.toList(growable: false));
    }
  }

  void dispose() {
    _disposed = true;
    _currentJobs.clear();
  }

  Future<void> _run(
    String hashLower, {
    required int generation,
    required Duration delay,
    required BtStreamRestoreOperation operation,
    required Future<void> future,
    required Completer<void> completer,
  }) async {
    bool isCurrent() =>
        !_disposed && (_generations[hashLower] ?? 0) == generation;

    try {
      if (delay > Duration.zero) {
        await _sleep(delay);
      }
      if (!isCurrent()) return;
      await operation(isCurrent);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    } finally {
      if (identical(_currentJobs[hashLower], future)) {
        _currentJobs.remove(hashLower);
      }
      _allJobs.remove(future);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}
