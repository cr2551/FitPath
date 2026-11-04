import 'dart:io';

import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/seed/exercise_seed.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  final json = File(exerciseCatalogAsset).readAsStringSync();

  group('catalog data', () {
    final exercises = parseExerciseCatalog(json);

    test('about 80 exercises with unique names', () {
      expect(exercises.length, greaterThanOrEqualTo(75));
      final names = exercises.map((e) => e.name.value.toLowerCase()).toSet();
      expect(names, hasLength(exercises.length));
    });

    test('every muscle group is covered', () {
      final groups = exercises.map((e) => e.muscleGroup.value).toSet();
      expect(groups, muscleGroups.toSet());
    });

    test('bodyweight exercises are flagged', () {
      final byName = {for (final e in exercises) e.name.value: e};
      expect(byName['Pull-up']!.isBodyweight.value, isTrue);
      expect(byName['Push-up']!.isBodyweight.value, isTrue);
      expect(byName['Bench press']!.isBodyweight.value, isFalse);
    });

    test('rejects unknown muscle groups', () {
      expect(
        () => parseExerciseCatalog(
          '{"version": 1, "exercises": [{"name": "X", "muscleGroup": "toes"}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('seeding', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('inserts the catalog once, never as custom', () async {
      await seedExercises(db, bundle: _FileBundle());
      await seedExercises(db, bundle: _FileBundle());

      final rows = await db.select(db.exercises).get();
      expect(rows, hasLength(parseExerciseCatalog(json).length));
      expect(rows.any((r) => r.isCustom), isFalse);
    });
  });
}
