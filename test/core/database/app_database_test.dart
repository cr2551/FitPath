import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show SqliteException;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<int> insertFood({String name = 'Oats'}) => db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          name: name,
          referenceBasis: ReferenceBasis.per100g,
          source: FoodSource.bundled,
          kcal: const Value(380),
        ),
      );

  Future<int> insertEntry(int foodId) => db
      .into(db.foodEntries)
      .insert(
        FoodEntriesCompanion.insert(
          foodItemId: foodId,
          quantity: 50,
          quantityUnit: 'g',
          mealType: MealType.breakfast,
          consumedAt: DateTime(2026, 11, 3, 8),
          localDate: '2026-11-03',
          nameSnapshot: 'Oats',
          kcal: const Value(190),
        ),
      );

  test('creates the settings and metadata singleton rows', () async {
    final settings = await db.select(db.appSettings).getSingle();
    final meta = await db.select(db.appMetadata).getSingle();

    expect(settings.unitSystem, UnitSystem.metric);
    expect(settings.themeMode, 'system');
    expect(meta.onboardingCompleted, isFalse);
    expect(meta.dataFormatVersion, 1);
  });

  test('foreign keys are enforced', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data.values.single, 1);

    await expectLater(insertEntry(999), throwsA(isA<SqliteException>()));
  });

  test('a food item referenced by the diary cannot be deleted', () async {
    final foodId = await insertFood();
    await insertEntry(foodId);

    await expectLater(
      (db.delete(db.foodItems)..where((f) => f.id.equals(foodId))).go(),
      throwsA(isA<SqliteException>()),
    );
  });

  test('editing a food item does not change the diary snapshot', () async {
    final foodId = await insertFood();
    final entryId = await insertEntry(foodId);

    await (db.update(db.foodItems)..where((f) => f.id.equals(foodId))).write(
      const FoodItemsCompanion(kcal: Value(999), name: Value('Renamed')),
    );

    final entry = await (db.select(
      db.foodEntries,
    )..where((e) => e.id.equals(entryId))).getSingle();
    expect(entry.kcal, 190);
    expect(entry.nameSnapshot, 'Oats');
  });

  test('deleting a session cascades to its exercises and sets', () async {
    final exerciseId = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Squat', muscleGroup: 'legs'));
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startedAt: DateTime(2026, 11, 3, 18),
            status: WorkoutStatus.completed,
          ),
        );
    final weId = await db
        .into(db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            exerciseNameSnapshot: 'Squat',
            orderIndex: 0,
          ),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: weId,
            setNumber: 1,
            repetitions: const Value(5),
            weightKg: const Value(100),
          ),
        );

    await (db.delete(
      db.workoutSessions,
    )..where((s) => s.id.equals(sessionId))).go();

    expect(await db.select(db.workoutExercises).get(), isEmpty);
    expect(await db.select(db.workoutSets).get(), isEmpty);
    expect(await db.select(db.exercises).get(), hasLength(1));
  });

  test('an exercise used in history cannot be hard-deleted', () async {
    final exerciseId = await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
        );
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            startedAt: DateTime(2026, 11, 3),
            status: WorkoutStatus.completed,
          ),
        );
    await db
        .into(db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            exerciseNameSnapshot: 'Bench press',
            orderIndex: 0,
          ),
        );

    await expectLater(
      (db.delete(db.exercises)..where((e) => e.id.equals(exerciseId))).go(),
      throwsA(isA<SqliteException>()),
    );
  });

  test('check constraints reject invalid units and extra singletons', () async {
    final foodId = await insertFood();

    await expectLater(
      db
          .into(db.foodEntries)
          .insert(
            FoodEntriesCompanion.insert(
              foodItemId: foodId,
              quantity: 1,
              quantityUnit: 'cups',
              mealType: MealType.snack,
              consumedAt: DateTime(2026),
              localDate: '2026-01-01',
              nameSnapshot: 'Oats',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db
          .into(db.appSettings)
          .insert(AppSettingsCompanion.insert(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );
  });

  test('external ids are unique so OFF products are cached once', () async {
    Future<int> cache() => db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            name: 'Protein bar',
            referenceBasis: ReferenceBasis.per100g,
            source: FoodSource.openFoodFacts,
            externalId: const Value('5000112637922'),
          ),
        );

    await cache();
    await expectLater(cache(), throwsA(isA<SqliteException>()));
  });

  test('every DAO is reachable from the database', () {
    expect(db.profileDao, isNotNull);
    expect(db.foodDao, isNotNull);
    expect(db.workoutDao, isNotNull);
    expect(db.dashboardDao, isNotNull);
  });
}
