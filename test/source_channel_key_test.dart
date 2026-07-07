import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/utils/source_channel_key.dart';

void main() {
  group('SourceChannelKey', () {
    test('round-trips with channel index', () {
      final key = SourceChannelKey(
        sourceName: 'source-a',
        channelIndex: BigInt.from(7),
      );
      final encoded = key.toPageKey();
      final decoded = SourceChannelKey.fromPageKey(encoded);
      expect(decoded.sourceName, 'source-a');
      expect(decoded.channelIndex, BigInt.from(7));
    });

    test('round-trips without channel index (null sentinel)', () {
      final key = SourceChannelKey(sourceName: 'source-b');
      final encoded = key.toPageKey();
      final decoded = SourceChannelKey.fromPageKey(encoded);
      expect(decoded.sourceName, 'source-b');
      expect(decoded.channelIndex, isNull);
    });

    test('preserves source names that contain underscores', () {
      // Important regression: source name with underscores must survive
      // round-trip when channelIndex is set, otherwise the schedule lookup
      // goes wrong. The implementation uses a NUL separator (`\x00`) between
      // sourceName and channelIndex to avoid the underscore ambiguity in the
      // legacy `_` separator path.
      final key = SourceChannelKey(
        sourceName: 'source_with_underscores',
        channelIndex: BigInt.from(3),
      );
      final encoded = key.toPageKey();
      final decoded = SourceChannelKey.fromPageKey(encoded);
      expect(decoded.sourceName, 'source_with_underscores');
      expect(decoded.channelIndex, BigInt.from(3));
    });

    test('legacy underscore-separated key still parses (backward compat)',
        () {
      // `_` separator path: source ends at the last `_`, last segment is the
      // channel index (or `-1` sentinel for null).
      const nullKey = 'source_with_underscores_-1';
      final decoded = SourceChannelKey.fromPageKey(nullKey);
      expect(decoded.sourceName, 'source_with_underscores');
      expect(decoded.channelIndex, isNull);

      final numeric = SourceChannelKey.fromPageKey('source_a_5');
      expect(numeric.sourceName, 'source_a');
      expect(numeric.channelIndex, BigInt.from(5));
    });

    test('equality / hashCode', () {
      final a = SourceChannelKey(
        sourceName: 'src',
        channelIndex: BigInt.from(1),
      );
      final b = SourceChannelKey(
        sourceName: 'src',
        channelIndex: BigInt.from(1),
      );
      final c = SourceChannelKey(
        sourceName: 'src',
        channelIndex: BigInt.from(2),
      );
      final d = SourceChannelKey(sourceName: 'other');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });
}
