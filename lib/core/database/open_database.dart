import 'dart:async';

import 'app_database.dart';

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
    return db;
  } on Object {
    unawaited(db.close().catchError((Object _) {}));
    rethrow;
  }
}
