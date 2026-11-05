import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/database_provider.dart';
import 'core/database/open_database.dart';
import 'core/startup/startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

/// Opens the database first; if that fails, shows an error with a retry
/// instead of screens that wait forever.
Future<void> _start() async {
  try {
    final db = await openAppDatabase();
    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitPathApp(),
      ),
    );
  } on Object catch (e) {
    runApp(StartupErrorApp(details: '$e', onRetry: _start));
  }
}
