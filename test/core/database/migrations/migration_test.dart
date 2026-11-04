import 'package:drift_dev/api/migrations_native.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

/// Guards the schema against unplanned changes (NFR-04).
///
/// When you change a table:
/// 1. bump `schemaVersion` in `app_database.dart` and add a migration step,
/// 2. run `dart run drift_dev make-migrations`, which dumps the new schema
///    into `drift_schemas/` and generates step-by-step migration tests here.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('a fresh database matches the committed v1 schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });
}
