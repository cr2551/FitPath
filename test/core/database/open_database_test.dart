import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/open_database.dart';
import 'package:fitpath/core/startup/startup_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('a working database opens', () async {
    final db = await openAppDatabase(
      open: () => AppDatabase(NativeDatabase.memory(), seedCatalogs: false),
    );
    addTearDown(db.close);
    expect(await db.select(db.appSettings).get(), hasLength(1));
  });

  test('a storage failure is reported, not left hanging', () async {
    await expectLater(
      openAppDatabase(
        open: () => AppDatabase(
          LazyDatabase(() async => throw StateError('no documents dir')),
        ),
      ),
      throwsStateError,
    );
  });

  test('a database that never opens times out', () async {
    await expectLater(
      openAppDatabase(
        open: () =>
            AppDatabase(LazyDatabase(() => Completer<QueryExecutor>().future)),
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  testWidgets('the startup error offers a retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      StartupErrorApp(details: 'boom', onRetry: () => retries++),
    );
    expect(find.text("FitPath couldn't open its data"), findsOneWidget);
    await tester.tap(find.text('TRY AGAIN'));
    expect(retries, 1);
  });
}
