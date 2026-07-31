class PlayerPlaybackHistoryGate {
  static const int minimumObservedPositionMs = 1000;

  bool _hasObservedProgress = false;

  bool get hasObservedProgress => _hasObservedProgress;

  bool observe(int positionMs) {
    if (positionMs >= minimumObservedPositionMs) {
      _hasObservedProgress = true;
    }
    return _hasObservedProgress;
  }

  void reset() {
    _hasObservedProgress = false;
  }
}
