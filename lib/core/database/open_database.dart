import 'dart:async';

import 'app_database.dart';
import 'seed/recipe_seed.dart';

/// Opens the database and runs a trivial query, so a missing storage
/// directory or a broken file fails here, at startup, instead of leaving
/// every screen waiting on queries that never complete.
Future<AppDatabase> openAppDatabase({
  AppDatabase Function() open = AppDatabase.open,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final db = open();
  try {
    await db.customSelect('SELECT 1').get().timeout(timeout);
    // This is a versioned re-seed for installations that already had schema
    // v2 before bundled recipes shipped. It needs Flutter's asset bundle, so
    // it belongs in the app startup path rather than the schema migration.
    if (db.seedCatalogs) await seedRecipes(db);
    return db;
  } on Object {
    unawaited(db.close().catchError((Object _) {}));
    rethrow;
  }
}
