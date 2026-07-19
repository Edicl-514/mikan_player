import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mikan_player/ui/pages/controllers/async_page_controllers.dart';

void main() {
  group('RequestGenerationGuard', () {
    test('only the latest generation remains current', () {
      final guard = RequestGenerationGuard();
      final first = guard.begin();
      final second = guard.begin();

      expect(guard.isCurrent(first), isFalse);
      expect(guard.isCurrent(second), isTrue);
    });

    test('invalidate and dispose reject previous completions', () {
      final guard = RequestGenerationGuard();
      final first = guard.begin();
      guard.invalidate();
      expect(guard.isCurrent(first), isFalse);

      final second = guard.begin();
      guard.dispose();
      expect(guard.isCurrent(second), isFalse);
    });
  });

  group('PagedRequestController', () {
    test('initial -> loading -> success and empty states', () async {
      final completer = Completer<List<int>>();
      final controller = PagedRequestController<String, int>(
        fetchPage: (_, _) => completer.future,
      );

      expect(controller.items, isEmpty);
      final future = controller.refresh('query');
      expect(controller.isLoading, isTrue);
      expect(controller.error, isNull);

      completer.complete([1, 2]);
      expect((await future).succeeded, isTrue);
      expect(controller.items, [1, 2]);
      expect(controller.page, 1);
      expect(controller.hasMore, isTrue);

      final empty = PagedRequestController<String, int>(
        fetchPage: (_, _) async => <int>[],
      );
      await empty.refresh('empty');
      expect(empty.items, isEmpty);
      expect(empty.hasMore, isFalse);
    });

    test('error is visible and retry can recover', () async {
      var attempts = 0;
      final controller = PagedRequestController<String, int>(
        fetchPage: (_, _) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return [7];
        },
      );

      final failed = await controller.refresh('query');
      expect(failed.error, isA<StateError>());
      expect(controller.error, isA<StateError>());
      expect(controller.isLoading, isFalse);

      final retried = await controller.refresh('query');
      expect(retried.succeeded, isTrue);
      expect(controller.error, isNull);
      expect(controller.items, [7]);
    });

    test('late old query cannot overwrite the latest query', () async {
      final oldRequest = Completer<List<String>>();
      final newRequest = Completer<List<String>>();
      final controller = PagedRequestController<String, String>(
        fetchPage: (query, _) =>
            query == 'old' ? oldRequest.future : newRequest.future,
      );

      final oldFuture = controller.refresh('old');
      final newFuture = controller.refresh('new');
      newRequest.complete(['new result']);
      expect((await newFuture).succeeded, isTrue);

      oldRequest.complete(['old result']);
      expect((await oldFuture).committed, isFalse);
      expect(controller.items, ['new result']);
      expect(controller.query, 'new');
    });

    test('load more appends, empty page ends paging, and dedupes', () async {
      final pageTwo = Completer<List<int>>();
      var pageTwoCalls = 0;
      final controller = PagedRequestController<String, int>(
        fetchPage: (_, page) {
          if (page == 1) return Future.value([1]);
          pageTwoCalls++;
          return pageTwo.future;
        },
      );
      await controller.refresh('q');

      final first = controller.loadMore();
      final duplicate = controller.loadMore();
      expect(controller.isLoadingMore, isTrue);
      expect((await duplicate).committed, isFalse);
      expect(pageTwoCalls, 1);

      pageTwo.complete([2]);
      expect((await first).succeeded, isTrue);
      expect(controller.items, [1, 2]);
      expect(controller.page, 2);

      final ending = PagedRequestController<String, int>(
        fetchPage: (_, page) async => page == 1 ? [1] : <int>[],
      );
      await ending.refresh('q');
      await ending.loadMore();
      expect(ending.hasMore, isFalse);
      expect(ending.page, 1);
    });

    test('load-more error clears busy state and permits retry', () async {
      var pageTwoAttempts = 0;
      final controller = PagedRequestController<String, int>(
        fetchPage: (_, page) async {
          if (page == 1) return [1];
          pageTwoAttempts++;
          if (pageTwoAttempts == 1) throw StateError('temporary');
          return [2];
        },
      );
      await controller.refresh('q');

      expect((await controller.loadMore()).error, isA<StateError>());
      expect(controller.isLoadingMore, isFalse);
      expect(controller.hasMore, isTrue);

      expect((await controller.loadMore()).succeeded, isTrue);
      expect(controller.items, [1, 2]);
    });

    test('refresh invalidates in-flight load more', () async {
      final oldPageTwo = Completer<List<String>>();
      final controller = PagedRequestController<String, String>(
        fetchPage: (query, page) {
          if (query == 'old' && page == 1) return Future.value(['old 1']);
          if (query == 'old') return oldPageTwo.future;
          return Future.value(['new 1']);
        },
      );
      await controller.refresh('old');
      final loadMore = controller.loadMore();
      await controller.refresh('new');
      oldPageTwo.complete(['old 2']);

      expect((await loadMore).committed, isFalse);
      expect(controller.items, ['new 1']);
      expect(controller.isLoadingMore, isFalse);
    });

    test(
      'dispose ignores late completion and emits no late notification',
      () async {
        final completer = Completer<List<int>>();
        var notifications = 0;
        final controller = PagedRequestController<String, int>(
          fetchPage: (_, _) => completer.future,
        )..addListener(() => notifications++);
        final future = controller.refresh('q');
        expect(notifications, 1);

        controller.dispose();
        completer.complete([1]);
        expect((await future).committed, isFalse);
        expect(notifications, 1);
      },
    );
  });

  group('EntityDetailsController', () {
    test(
      'loads three sections independently and exposes empty success',
      () async {
        final details = Completer<String>();
        final subjects = Completer<List<int>>();
        final related = Completer<List<String>>();
        final controller = EntityDetailsController<int, String, int, String>(
          fetchDetails: (_) => details.future,
          fetchSubjects: (_) => subjects.future,
          fetchRelated: (_) => related.future,
        );

        final load = controller.load(1);
        expect(controller.isLoadingDetails, isTrue);
        expect(controller.isLoadingSubjects, isTrue);
        expect(controller.isLoadingRelated, isTrue);

        details.complete('details');
        await Future<void>.delayed(Duration.zero);
        expect(controller.details, 'details');
        expect(controller.isLoadingDetails, isFalse);
        expect(controller.isLoadingSubjects, isTrue);

        subjects.complete(<int>[]);
        related.complete(['role']);
        await load;
        expect(controller.subjects, isEmpty);
        expect(controller.related, ['role']);
      },
    );

    test('section error does not discard other successful sections', () async {
      final controller = EntityDetailsController<int, String, int, String>(
        fetchDetails: (_) async => throw StateError('details failed'),
        fetchSubjects: (_) async => [1],
        fetchRelated: (_) async => ['role'],
      );

      await controller.load(1);
      expect(controller.detailsError, isA<StateError>());
      expect(controller.isLoadingDetails, isFalse);
      expect(controller.subjects, [1]);
      expect(controller.related, ['role']);
    });

    test('retry clears old errors and can recover', () async {
      var attempts = 0;
      final controller = EntityDetailsController<int, String, int, Object>(
        fetchDetails: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('failed');
          return 'ok';
        },
        fetchSubjects: (_) async => <int>[],
      );

      await controller.load(1);
      expect(controller.detailsError, isNotNull);
      await controller.load(1);
      expect(controller.detailsError, isNull);
      expect(controller.details, 'ok');
    });

    test('late previous entity cannot overwrite replacement', () async {
      final oldDetails = Completer<String>();
      final oldSubjects = Completer<List<int>>();
      final controller = EntityDetailsController<int, String, int, Object>(
        fetchDetails: (id) =>
            id == 1 ? oldDetails.future : Future.value('new details'),
        fetchSubjects: (id) => id == 1 ? oldSubjects.future : Future.value([2]),
      );

      final oldLoad = controller.load(1);
      await controller.load(2);
      oldDetails.complete('old details');
      oldSubjects.complete([1]);
      await oldLoad;

      expect(controller.details, 'new details');
      expect(controller.subjects, [2]);
    });

    test('dispose ignores all late section completions', () async {
      final details = Completer<String>();
      final subjects = Completer<List<int>>();
      final controller = EntityDetailsController<int, String, int, Object>(
        fetchDetails: (_) => details.future,
        fetchSubjects: (_) => subjects.future,
      );
      final load = controller.load(1);
      controller.dispose();
      details.complete('late');
      subjects.complete([1]);
      await load;

      expect(controller.details, isNull);
      expect(controller.subjects, isEmpty);
    });
  });
}
