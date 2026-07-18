// In-memory Drift helpers.
//
// The production [AppDatabase] (`lib/services/cache/database/app_database.dart`)
// is a singleton that opens a file-backed [NativeDatabase] under
// `AppDirectories.getUnifiedAppDataDirectory()`. Tests must not touch that
// path: they would create files under the user's `AppData` directory and would
// race with the singleton cache.
//
// Instead:
//   1. Add a `@visibleForTesting AppDatabase.forTesting(QueryExecutor e)`
//      constructor to [AppDatabase] as part of the work package that needs it
//      (DT-2 in the plan). F-0 deliberately does NOT modify [AppDatabase].
//   2. Pass the result of [driftInMemoryExecutor] (or
//      [driftInMemoryConnection]) to that constructor.
//
// Closing the executor drops the data — no on-disk artifacts remain.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Returns a synchronous in-memory [QueryExecutor].
///
/// Preferring the synchronous executor keeps tests deterministic — queries do
/// not hop across isolates and the executor can be closed from `tearDown`
/// without waiting on a background task.
QueryExecutor driftInMemoryExecutor() => NativeDatabase.memory();

/// Returns a [DatabaseConnection] backed by the in-memory executor.
///
/// Helper for production code paths that take a `DatabaseConnection` directly
/// rather than a raw `QueryExecutor`.
DatabaseConnection driftInMemoryConnection() =>
    DatabaseConnection(driftInMemoryExecutor());
