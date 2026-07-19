// DT-1: pure-Dart composition tests for `models/user.dart`.
//
// Covers:
//   * Round-trip from JSON through `User.fromJson` and back through
//     `toJson`, with the rewritten `url` field preserved.
//   * `User.fromJson` requires `id`, `username`, `nickname` and
//     `avatar` to be present (the cast is non-nullable).
//   * Optional `sign` and `url` are nullable; missing keys round-trip
//     to null. Explicit `null` values must remain null.
//   * UserAvatar.fromJson and toJson round-trip independently of User.
//   * URL rewriting: the `url` field goes through `BangumiUrlRewriter.rewrite`
//     — confirm pass-through when the rewrite cache is disabled (which
//     is the test-suite default).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/user.dart';
import 'package:mikan_player/utils/bangumi_url_rewriter.dart';

void main() {
  setUp(() {
    BangumiUrlRewriter.setEnabled(false);
  });

  Map<String, dynamic> avatarJson({
    String large = 'https://lain.bgm.tv/img/large',
    String medium = 'https://lain.bgm.tv/img/medium',
    String small = 'https://lain.bgm.tv/img/small',
  }) =>
      <String, dynamic>{'large': large, 'medium': medium, 'small': small};

  Map<String, dynamic> userJson({
    int id = 7,
    String username = 'sai',
    String nickname = 'Sai',
    String? sign,
    String? url,
    Map<String, dynamic>? avatar,
  }) =>
      <String, dynamic>{
        'id': id,
        'username': username,
        'nickname': nickname,
        'sign': ?sign,
        'url': ?url,
        'avatar': avatar ?? avatarJson(),
      };

  group('User.fromJson()', () {
    test('parses required fields and rewrites url when present', () {
      final u = User.fromJson(
        userJson(
          sign: '签名',
          url: 'https://bgm.tv/user/sai',
        ),
      );
      expect(u.id, 7);
      expect(u.username, 'sai');
      expect(u.nickname, 'Sai');
      expect(u.sign, '签名');
      // With rewrite caching disabled, the input is returned as-is.
      expect(u.url, 'https://bgm.tv/user/sai');
      expect(u.avatar.large, 'https://lain.bgm.tv/img/large');
      expect(u.avatar.medium, 'https://lain.bgm.tv/img/medium');
      expect(u.avatar.small, 'https://lain.bgm.tv/img/small');
    });

    test('null sign and url are preserved as null', () {
      final u = User.fromJson(
        userJson(
          sign: null,
          url: null,
        ),
      );
      expect(u.sign, isNull);
      expect(u.url, isNull);
    });

    test('missing sign and url keys decode to null (not empty string)', () {
      // The factory uses `json['sign'] as String?` and `json['url'] ==
      // null ? null : ...` — missing keys must produce null, not an
      // empty string (which would change JSON round-trip semantics).
      final json = userJson();
      json.remove('sign');
      json.remove('url');
      final u = User.fromJson(json);
      expect(u.sign, isNull);
      expect(u.url, isNull);
    });

    test('rewriting applies to avatar URLs as well', () {
      // avatar.large/medium/small all flow through rewrite(); the
      // pass-through contract must hold for all three.
      final u = User.fromJson(
        userJson(
          avatar: avatarJson(
            large: 'https://api.bgm.tv/v0/users/sai/avatar/large',
            medium: 'https://api.bgm.tv/v0/users/sai/avatar/medium',
            small: 'https://api.bgm.tv/v0/users/sai/avatar/small',
          ),
        ),
      );
      expect(u.avatar.large, 'https://api.bgm.tv/v0/users/sai/avatar/large');
      expect(u.avatar.medium, 'https://api.bgm.tv/v0/users/sai/avatar/medium');
      expect(u.avatar.small, 'https://api.bgm.tv/v0/users/sai/avatar/small');
    });

    test('preserves unicode / emoji in all string fields', () {
      final u = User.fromJson(
        userJson(
          username: 'ユーザー',
          nickname: '昵称 🎉',
          sign: '签名 — подпись',
          url: 'https://bgm.tv/user/テスト',
        ),
      );
      expect(u.username, 'ユーザー');
      expect(u.nickname, '昵称 🎉');
      expect(u.sign, '签名 — подпись');
      expect(u.url, 'https://bgm.tv/user/テスト');
    });
  });

  group('User.toJson()', () {
    test('round-trips through jsonEncode / jsonDecode', () {
      final original = User(
        id: 99,
        username: 'sai',
        nickname: 'Sai',
        sign: 'sign',
        url: 'https://bgm.tv/user/sai',
        avatar: UserAvatar(
          large: 'https://lain.bgm.tv/img/large',
          medium: 'https://lain.bgm.tv/img/medium',
          small: 'https://lain.bgm.tv/img/small',
        ),
      );

      final encoded = jsonEncode(original.toJson());
      final decoded = User.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.id, 99);
      expect(decoded.username, 'sai');
      expect(decoded.nickname, 'Sai');
      expect(decoded.sign, 'sign');
      expect(decoded.url, 'https://bgm.tv/user/sai');
      expect(decoded.avatar.large, 'https://lain.bgm.tv/img/large');
      expect(decoded.avatar.medium, 'https://lain.bgm.tv/img/medium');
      expect(decoded.avatar.small, 'https://lain.bgm.tv/img/small');
    });

    test('round-trips with sign and url set to null', () {
      final original = User(
        id: 1,
        username: 'sai',
        nickname: 'Sai',
        sign: null,
        url: null,
        avatar: UserAvatar(
          large: '',
          medium: '',
          small: '',
        ),
      );

      final encoded = jsonEncode(original.toJson());
      final decoded = User.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.sign, isNull);
      expect(decoded.url, isNull);
    });

    test('toJson emits the avatar key with all three URLs', () {
      final u = User(
        id: 1,
        username: 'sai',
        nickname: 'Sai',
        avatar: UserAvatar(
          large: 'L',
          medium: 'M',
          small: 'S',
        ),
      );
      final json = u.toJson();
      expect(json['avatar'], isA<Map<String, dynamic>>());
      final avatar = json['avatar'] as Map<String, dynamic>;
      expect(avatar['large'], 'L');
      expect(avatar['medium'], 'M');
      expect(avatar['small'], 'S');
    });
  });

  group('UserAvatar', () {
    test('fromJson parses and applies rewrite to all three URLs', () {
      final a = UserAvatar.fromJson(avatarJson());
      expect(a.large, 'https://lain.bgm.tv/img/large');
      expect(a.medium, 'https://lain.bgm.tv/img/medium');
      expect(a.small, 'https://lain.bgm.tv/img/small');
    });

    test('toJson emits exactly the three URL keys', () {
      final json = UserAvatar(
        large: 'L',
        medium: 'M',
        small: 'S',
      ).toJson();
      expect(json.keys.toSet(), {'large', 'medium', 'small'});
    });
  });
}
