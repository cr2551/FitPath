import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The app's single database connection. Override with an in-memory database
/// in tests (see `test/helpers/test_database.dart`).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
