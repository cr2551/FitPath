import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fitpath/core/database/app_database.dart';

/// A fresh in-memory [AppDatabase] for repository tests. Runs the real
/// `onCreate` (singleton rows) and enables foreign keys. The bundled
/// catalogs are NOT seeded unless [seedCatalogs] is true, so tests start from
/// an empty catalog.
///
/// Close it in `tearDown`: `addTearDown(db.close)`.
AppDatabase createTestDatabase({bool seedCatalogs = false}) {
  // Several test databases may be open at once; that is fine in tests.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory(), seedCatalogs: seedCatalogs);
}
