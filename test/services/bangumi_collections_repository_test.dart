import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/bangumi_collections_repository.dart';

void main() {
  test('normalizes tags without turning an empty list into a no-op sentinel', () {
    expect(normalizeBangumiTags([' sci-fi ', '', 'sci-fi', 'drama']), [
      'sci-fi',
      'drama',
    ]);
    expect(normalizeBangumiTags(const <String>[]), isEmpty);
  });

  test('rejects whitespace inside a single tag', () {
    expect(
      () => normalizeBangumiTags(['science fiction']),
      throwsA(isA<FormatException>()),
    );
  });
}
