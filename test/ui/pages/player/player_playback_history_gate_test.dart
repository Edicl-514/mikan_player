import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/player/player_playback_history_gate.dart';

void main() {
  test(
    'requires one second of observed playback before history can be saved',
    () {
      final gate = PlayerPlaybackHistoryGate();

      expect(gate.observe(0), isFalse);
      expect(gate.observe(999), isFalse);
      expect(gate.observe(1000), isTrue);
    },
  );

  test('stays open across transient zero ticks until the episode resets', () {
    final gate = PlayerPlaybackHistoryGate();

    expect(gate.observe(5000), isTrue);
    expect(gate.observe(0), isTrue);

    gate.reset();
    expect(gate.hasObservedProgress, isFalse);
    expect(gate.observe(0), isFalse);
  });
}
