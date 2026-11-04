import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fitpath/core/database/app_database.dart';

/// A fresh in-memory [AppDatabase] for repository tests. Runs the real
/// `onCreate` (singleton rows and seed hooks) and enables foreign keys.
///
/// Close it in `tearDown`: `addTearDown(db.close)`.
AppDatabase createTestDatabase() {
  // Several test databases may be open at once; that is fine in tests.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
