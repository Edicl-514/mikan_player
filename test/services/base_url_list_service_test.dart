// DT-2A: BaseUrlListService pure helpers + SharedPreferences mutations.

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/services/base_url_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shared_prefs_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetSharedPreferences();
  });

  group('normalize', () {
    test('trims whitespace and strips trailing slashes', () {
      expect(
        BaseUrlListService.normalize('  https://example.com/path//  '),
        'https://example.com/path',
      );
      expect(BaseUrlListService.normalize('https://x.com'), 'https://x.com');
      expect(BaseUrlListService.normalize('   '), isEmpty);
    });
  });

  group('mergeUrls / isBuiltin', () {
    test('builtins always come first and drop custom duplicates', () {
      final merged = BaseUrlListService.mergeUrls(BaseUrlKind.bangumi, [
        'https://bangumi.tv/', // trailing slash duplicate of builtin
        'https://custom.example.com/',
        'https://custom.example.com', // same after normalize
        '',
        '   ',
      ]);

      expect(merged.first, 'https://bangumi.tv');
      expect(merged, contains('https://custom.example.com'));
      expect(merged.where((u) => u == 'https://custom.example.com').length, 1);
      expect(merged, isNot(contains('')));
    });

    test('isBuiltin is normalization-aware', () {
      expect(
        BaseUrlListService.isBuiltin(BaseUrlKind.mikan, 'https://mikanani.me/'),
        isTrue,
      );
      expect(
        BaseUrlListService.isBuiltin(BaseUrlKind.mikan, 'https://example.com'),
        isFalse,
      );
    });
  });

  group('selected URL', () {
    test('defaults to first builtin when unset', () async {
      final selected = await BaseUrlListService.getSelected(
        BaseUrlKind.bgmlist,
      );
      expect(
        selected,
        BaseUrlListService.builtinUrls[BaseUrlKind.bgmlist]!.first,
      );
    });

    test('setSelected normalizes and getSelected returns it', () async {
      await BaseUrlListService.setSelected(
        BaseUrlKind.bangumi,
        'https://bgm.tv/',
      );
      final selected = await BaseUrlListService.getSelected(
        BaseUrlKind.bangumi,
      );
      expect(selected, 'https://bgm.tv');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bangumi_url'), 'https://bgm.tv');
    });
  });

  group('custom list mutations', () {
    test('addCustomUrl rejects empty, non-http, and builtins', () async {
      final before = await BaseUrlListService.getAllUrls(BaseUrlKind.mikan);

      expect(
        await BaseUrlListService.addCustomUrl(BaseUrlKind.mikan, '   '),
        before,
      );
      expect(
        await BaseUrlListService.addCustomUrl(
          BaseUrlKind.mikan,
          'ftp://example.com',
        ),
        before,
      );
      expect(
        await BaseUrlListService.addCustomUrl(
          BaseUrlKind.mikan,
          'https://mikanani.me/',
        ),
        before,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('mikan_url_custom_list'), isNull);
    });

    test('addCustomUrl appends once and is idempotent', () async {
      final once = await BaseUrlListService.addCustomUrl(
        BaseUrlKind.bgmlist,
        'https://mirror.example.com/',
      );
      expect(once, contains('https://mirror.example.com'));

      final twice = await BaseUrlListService.addCustomUrl(
        BaseUrlKind.bgmlist,
        'https://mirror.example.com',
      );
      expect(twice.where((u) => u == 'https://mirror.example.com').length, 1);

      final custom = await BaseUrlListService.getCustomUrls(
        BaseUrlKind.bgmlist,
      );
      expect(custom, <String>['https://mirror.example.com']);
    });

    test('removeCustomUrl drops the entry and falls back selection', () async {
      await BaseUrlListService.addCustomUrl(
        BaseUrlKind.bangumi,
        'https://custom.bangumi.local',
      );
      await BaseUrlListService.setSelected(
        BaseUrlKind.bangumi,
        'https://custom.bangumi.local',
      );

      final remaining = await BaseUrlListService.removeCustomUrl(
        BaseUrlKind.bangumi,
        'https://custom.bangumi.local/',
      );
      expect(remaining, isNot(contains('https://custom.bangumi.local')));
      expect(
        await BaseUrlListService.getSelected(BaseUrlKind.bangumi),
        BaseUrlListService.builtinUrls[BaseUrlKind.bangumi]!.first,
      );
    });

    test('removeCustomUrl never removes a builtin', () async {
      final all = await BaseUrlListService.removeCustomUrl(
        BaseUrlKind.bangumi,
        'https://bgm.tv',
      );
      expect(all, contains('https://bgm.tv'));
    });

    test('kinds are isolated from each other', () async {
      await BaseUrlListService.addCustomUrl(
        BaseUrlKind.mikan,
        'https://mikan-only.example',
      );
      expect(
        await BaseUrlListService.getCustomUrls(BaseUrlKind.bangumi),
        isEmpty,
      );
      expect(
        await BaseUrlListService.getCustomUrls(BaseUrlKind.bgmlist),
        isEmpty,
      );
      expect(
        await BaseUrlListService.getCustomUrls(BaseUrlKind.mikan),
        <String>['https://mikan-only.example'],
      );
    });
  });
}
