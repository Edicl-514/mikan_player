import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/local_favorite.dart';

void main() {
  test('LocalFavorite.create fills required fields', () {
    final favorite = LocalFavorite.create(
      bangumiId: 1,
      title: 'Example',
      coverUrl: 'https://example.com/cover.jpg',
      score: 8.5,
    );

    expect(favorite.bangumiId, 1);
    expect(favorite.title, 'Example');
    expect(favorite.coverUrl, 'https://example.com/cover.jpg');
    expect(favorite.score, 8.5);
    expect(favorite.type, 1);
    expect(favorite.createdAt, greaterThan(0));
  });
}
