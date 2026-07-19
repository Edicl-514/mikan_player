// DT-2B: UserManager persistence without touching the network.
//
// `login()` always hits the Rust FRB client, so these tests cover init /
// logout / corrupt payload recovery with `debugSkipAutoRefresh = true`.

import 'dart:convert';
import 'dart:ui' show VoidCallback;

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/models/user.dart';
import 'package:mikan_player/services/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shared_prefs_support.dart';

Map<String, Object?> _userJson({
  int id = 1,
  String username = 'alice',
  String nickname = 'Alice',
}) {
  return <String, Object?>{
    'id': id,
    'username': username,
    'nickname': nickname,
    'sign': 'hello',
    'url': 'https://bangumi.tv/user/alice',
    'avatar': <String, String>{
      'large': 'https://lain.bgm.tv/pic/user/l/1.jpg',
      'medium': 'https://lain.bgm.tv/pic/user/m/1.jpg',
      'small': 'https://lain.bgm.tv/pic/user/s/1.jpg',
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserManager manager;
  late int notifyCount;
  late VoidCallback listener;

  setUp(() async {
    await resetSharedPreferences();
    manager = UserManager()
      ..debugResetForTest()
      ..debugSkipAutoRefresh = true;
    notifyCount = 0;
    listener = () => notifyCount++;
    manager.addListener(listener);
  });

  tearDown(() {
    manager
      ..removeListener(listener)
      ..debugResetForTest();
  });

  group('defaults', () {
    test('starts logged out with a null user', () {
      expect(manager.user, isNull);
      expect(manager.isLoggedIn, isFalse);
    });
  });

  group('init', () {
    test('loads a valid cached user and notifies once', () async {
      await resetSharedPreferences(<String, Object>{
        'bangumi_user': jsonEncode(_userJson()),
      });
      manager
        ..debugResetForTest()
        ..debugSkipAutoRefresh = true;

      await manager.init();

      expect(manager.isLoggedIn, isTrue);
      expect(manager.user?.username, 'alice');
      expect(manager.user?.nickname, 'Alice');
      expect(manager.user?.id, 1);
      expect(manager.user?.avatar.large, isNotEmpty);
      expect(notifyCount, 1);
    });

    test('missing key leaves the manager logged out', () async {
      await manager.init();
      expect(manager.isLoggedIn, isFalse);
      expect(notifyCount, 0);
    });

    test('corrupt JSON logs the user out and removes the key', () async {
      await resetSharedPreferences(<String, Object>{
        'bangumi_user': '{not-json',
      });
      manager
        ..debugResetForTest()
        ..debugSkipAutoRefresh = true;

      await manager.init();

      expect(manager.isLoggedIn, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('bangumi_user'), isFalse);
    });

    test('partial JSON missing required fields logs the user out', () async {
      await resetSharedPreferences(<String, Object>{
        'bangumi_user': jsonEncode(<String, Object?>{'id': 1}),
      });
      manager
        ..debugResetForTest()
        ..debugSkipAutoRefresh = true;

      await manager.init();
      expect(manager.isLoggedIn, isFalse);
    });
  });

  group('logout', () {
    test('clears memory, preference key, and notifies', () async {
      // Seed via prefs + init so we do not need the network login path.
      await resetSharedPreferences(<String, Object>{
        'bangumi_user': jsonEncode(_userJson()),
      });
      manager
        ..debugResetForTest()
        ..debugSkipAutoRefresh = true;
      await manager.init();
      notifyCount = 0;

      await manager.logout();

      expect(manager.user, isNull);
      expect(manager.isLoggedIn, isFalse);
      expect(notifyCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('bangumi_user'), isFalse);
    });

    test('logout while already logged out is safe', () async {
      await manager.logout();
      expect(manager.isLoggedIn, isFalse);
      expect(notifyCount, 1);
    });
  });

  group('model round-trip used by persistence', () {
    test('User.toJson / fromJson survives the prefs path', () async {
      final original = User.fromJson(_userJson(id: 99, username: 'bob'));
      await seedSharedPreferences(<String, Object>{
        'bangumi_user': jsonEncode(original.toJson()),
      });
      manager
        ..debugResetForTest()
        ..debugSkipAutoRefresh = true;
      await manager.init();

      expect(manager.user?.id, 99);
      expect(manager.user?.username, 'bob');
      expect(manager.user?.toJson()['username'], 'bob');
    });
  });
}
