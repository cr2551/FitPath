import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

/// Guards the schema against unplanned changes (NFR-04).
///
/// When you change a table:
/// 1. bump `schemaVersion` in `app_database.dart`,
/// 2. run `dart run drift_dev make-migrations`, which dumps the new schema
///    into `drift_schemas/`, regenerates `app_database.steps.dart` and the
///    schema helpers in `generated/`,
/// 3. write the `fromXToY` step and extend the data test below.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('a fresh database matches the committed latest schema', () async {
    final latest = GeneratedHelper.versions.last;
    final db = AppDatabase(await verifier.startAt(latest));
    addTearDown(db.close);
    expect(db.schemaVersion, latest);
    await verifier.migrateAndValidate(db, latest);
  });

  group('every upgrade path matches the committed schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('v$from to v$to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          addTearDown(db.close);
          await verifier.migrateAndValidate(db, to);
        });
      }
    }
  });

  test('v1 data survives the upgrade to v2, and recipes work', () async {
    final schema = await verifier.schemaAt(1);
    // Written with plain SQL against the v1 schema; drift stores DateTime as
    // unix seconds.
    final t = DateTime(2026, 11, 2, 12).millisecondsSinceEpoch ~/ 1000;
    for (final sql in [
      'INSERT INTO user_profile (id, age_years) VALUES (1, 31)',
      'INSERT INTO fitness_goals (goal_type, is_primary) '
          "VALUES ('loseWeight', 1)",
      'INSERT INTO weight_entries (weight_kg, recorded_at) VALUES (80.5, $t)',
      'INSERT INTO nutrition_targets (calories, effective_from, source) '
          "VALUES (2000, '2026-11-01', 'user')",
      'INSERT INTO food_items (id, name, reference_basis, source, kcal) '
          "VALUES (7, 'Oats', 'per100g', 'custom', 380)",
      'INSERT INTO food_entries (food_item_id, quantity, quantity_unit, '
          'meal_type, consumed_at, local_date, name_snapshot, kcal) '
          "VALUES (7, 50, 'g', 'breakfast', $t, '2026-11-02', 'Oats', 190)",
      'INSERT INTO exercises (id, name, muscle_group) '
          "VALUES (3, 'Squat', 'legs')",
      'INSERT INTO workout_sessions (id, started_at, status) '
          "VALUES (1, $t, 'completed')",
      'INSERT INTO workout_exercises (id, session_id, exercise_id, '
          "exercise_name_snapshot, order_index) VALUES (1, 1, 3, 'Squat', 0)",
      'INSERT INTO workout_sets (workout_exercise_id, set_number, '
          'repetitions, weight_kg) VALUES (1, 1, 5, 100)',
      'INSERT INTO dashboard_cards (card_type, position) '
          "VALUES ('weightTrend', 0)",
    ]) {
      schema.rawDatabase.execute(sql);
    }

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    expect((await db.select(db.userProfile).getSingle()).ageYears, 31);
    expect(await db.select(db.fitnessGoals).get(), hasLength(1));
    expect((await db.select(db.weightEntries).getSingle()).weightKg, 80.5);
    expect((await db.select(db.nutritionTargets).getSingle()).calories, 2000);
    final oats = (await db.foodDao.foodById(7))!;
    expect(
      (oats.name, oats.source, oats.kcal),
      ('Oats', FoodSource.custom, 380),
    );
    final entry = await db.select(db.foodEntries).getSingle();
    expect(
      (entry.quantity, entry.kcal, entry.localDate),
      (50, 190, '2026-11-02'),
    );
    expect(entry.consumedAt, DateTime(2026, 11, 2, 12));
    expect((await db.select(db.workoutSets).getSingle()).weightKg, 100);
    expect(
      (await db.select(db.dashboardCards).getSingle()).cardType,
      DashboardCardType.weightTrend,
    );

    // The new tables work on the upgraded database.
    final foodId = await db.foodDao.insertFood(
      const FoodItemsCompanion(
        name: Value('Porridge'),
        referenceBasis: Value(ReferenceBasis.perServing),
        source: Value(FoodSource.recipe),
      ),
    );
    final recipeId = await db.recipeDao.insertRecipe(
      RecipesCompanion.insert(foodItemId: foodId, servings: 2),
    );
    await db.recipeDao.replaceIngredients(recipeId, [
      RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodItemId: 7,
        quantity: 100,
        unit: 'g',
        position: 0,
      ),
    ]);
    final ingredients = await db.recipeDao.ingredients(recipeId);
    expect(ingredients.single.$2.name, 'Oats');
  });
}
