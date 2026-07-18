// Self-tests for the F-0 in-memory Drift helpers.
//
// We do not construct an actual `AppDatabase` here because the production
// class is a private-constructor singleton — adding a `@visibleForTesting`
// constructor is the responsibility of the consuming work package (DT-2
// per the plan). These tests only lock in the lifecycle contract of the
// helpers so future refactors do not silently change the executor type or
// remove the convenience constructors.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift_in_memory.dart';

void main() {
  group('driftInMemoryExecutor', () {
    test('returns a NativeDatabase instance', () async {
      final executor = driftInMemoryExecutor();
      addTearDown(() => (executor as NativeDatabase).close());

      expect(executor, isA<NativeDatabase>());
      expect(executor, isA<QueryExecutor>());
    });

    test('each call opens an independent in-memory store', () {
      // Two consecutive calls must return executors backed by disjoint
      // in-memory stores. We only check the executor identity here (rather
      // than executing SQL, which goes through generated Database classes)
      // because the SQL helper surface lives on `GeneratedDatabase`, not on
      // `QueryExecutor` itself.
      final a = driftInMemoryExecutor();
      final b = driftInMemoryExecutor();
      addTearDown(() async {
        await (a as NativeDatabase).close();
        await (b as NativeDatabase).close();
      });

      expect(identical(a, b), isFalse);
    });

    test('closing the executor twice does not throw', () async {
      final executor = driftInMemoryExecutor() as NativeDatabase;
      await executor.close();
      // A second close must be a no-op so test teardown can call it twice
      // without masking the original failure.
      await expectLater(executor.close(), completes);
    });
  });

  group('driftInMemoryConnection', () {
    test('wraps the executor in a DatabaseConnection', () {
      final conn = driftInMemoryConnection();
      addTearDown(() => conn.executor.close());

      expect(conn, isA<DatabaseConnection>());
      expect(conn.executor, isA<NativeDatabase>());
    });
  });
}
