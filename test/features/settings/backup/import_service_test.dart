import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/backup/backup_validator.dart';
import 'package:fitpath/features/settings/backup/export_service.dart';
import 'package:fitpath/features/settings/backup/import_service.dart';
import 'package:fitpath/features/settings/presentation/backup_restore_section.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Profile, goal, weight, target, settings, a bundled and a custom food with
/// a diary entry, a session with an exercise and a set, a dashboard.
Future<void> _fill(AppDatabase db) async {
  final profile = ProfileRepository(db.profileDao);
  await profile.saveProfile(ageYears: 30, heightCm: 180);
  await profile.setPrimaryGoal(GoalType.buildMuscle);
  await profile.logWeight(80, notes: 'morning');
  await profile.setTargets(
    calories: 2600,
    proteinG: 160,
    source: TargetSource.user,
  );
  await profile.setUnitSystem(UnitSystem.imperial);

  final apple = await db.foodDao.insertFood(
    FoodItemsCompanion.insert(
      name: 'Apple',
      referenceBasis: ReferenceBasis.per100g,
      source: FoodSource.bundled,
      kcal: const Value(52),
    ),
  );
  final recipeOnlyFood = await db.foodDao.insertFood(
    FoodItemsCompanion.insert(
      name: 'Oats',
      referenceBasis: ReferenceBasis.per100g,
      source: FoodSource.bundled,
      kcal: const Value(389),
    ),
  );
  final foods = FoodRepository(db.foodDao);
  final granola = await foods.createCustomFood(
    const FoodDetails(
      name: 'Granola',
      basis: ReferenceBasis.per100g,
      nutrients: Nutrients(kcal: 450, proteinG: 10),
    ),
  );
  final recipeFood = await db.foodDao.insertFood(
    FoodItemsCompanion.insert(
      name: 'Apple granola bowl',
      referenceBasis: ReferenceBasis.perServing,
      source: FoodSource.recipe,
      kcal: const Value(502),
    ),
  );
  final recipe = await db
      .into(db.recipes)
      .insert(RecipesCompanion.insert(foodItemId: recipeFood, servings: 2));
  await db
      .into(db.recipeIngredients)
      .insert(
        RecipeIngredientsCompanion.insert(
          recipeId: recipe,
          foodItemId: recipeOnlyFood,
          quantity: 100,
          unit: 'g',
          position: 0,
        ),
      );
  for (final id in [apple, granola, recipeFood]) {
    await foods.logFood(
      foodId: id,
      quantity: id == recipeFood ? 1 : 100,
      unit: id == recipeFood ? QuantityUnit.serving : QuantityUnit.gram,
      meal: MealType.breakfast,
    );
  }

  final squat = await db
      .into(db.exercises)
      .insert(ExercisesCompanion.insert(name: 'Squat', muscleGroup: 'legs'));
  final s = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          startedAt: DateTime(2026, 11, 3, 18),
          completedAt: Value(DateTime(2026, 11, 3, 19)),
          status: WorkoutStatus.completed,
        ),
      );
  final we = await db
      .into(db.workoutExercises)
      .insert(
        WorkoutExercisesCompanion.insert(
          sessionId: s,
          exerciseId: squat,
          exerciseNameSnapshot: 'Squat',
          orderIndex: 0,
        ),
      );
  await db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          workoutExerciseId: we,
          setNumber: 1,
          repetitions: const Value(5),
          weightKg: const Value(120),
          completed: const Value(true),
        ),
      );
  await DashboardRepository(db.dashboardDao).applyPreset(GoalType.buildMuscle);
}

Future<String> _export(AppDatabase db) async => ExportService.encode(
  await ExportService(db).buildBackup(appVersion: '0.1.0+1'),
);

/// Every user table, for comparing two databases.
Future<Map<String, List<Object>>> _snapshot(AppDatabase db) async => {
  'settings': await db.select(db.appSettings).get(),
  'profile': await db.select(db.userProfile).get(),
  'goals': await db.select(db.fitnessGoals).get(),
  'weights': await db.select(db.weightEntries).get(),
  'targets': await db.select(db.nutritionTargets).get(),
  'foods': await db.select(db.foodItems).get(),
  'recipes': await db.select(db.recipes).get(),
  'recipeIngredients': await db.select(db.recipeIngredients).get(),
  'entries': await db.select(db.foodEntries).get(),
  'exercises': await db.select(db.exercises).get(),
  'sessions': await db.select(db.workoutSessions).get(),
  'workoutExercises': await db.select(db.workoutExercises).get(),
  'sets': await db.select(db.workoutSets).get(),
  'cards': await db.select(db.dashboardCards).get(),
};

/// Edits the exported JSON before validating it.
String _tamper(String json, void Function(Map<String, dynamic> doc) edit) {
  final doc = jsonDecode(json) as Map<String, dynamic>;
  edit(doc);
  return jsonEncode(doc);
}

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    source = createTestDatabase();
    target = createTestDatabase();
    await _fill(source);
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  test(
    'export, then import into another database: identical records',
    () async {
      // The target has data of its own, which the restore replaces.
      await ProfileRepository(target.profileDao).logWeight(99);
      await FoodRepository(target.foodDao).createCustomFood(
        const FoodDetails(name: 'Old food', basis: ReferenceBasis.per100g),
      );

      final backup = BackupValidator.parse(await _export(source));
      await ImportService(target).restore(backup);

      expect(await _snapshot(target), await _snapshot(source));
      final meta = await target.select(target.appMetadata).getSingle();
      expect(meta.onboardingCompleted, isTrue);
    },
  );

  test('restored relationships still join', () async {
    await ImportService(target)
        .restore(BackupValidator.parse(await _export(source)));
    final entries = await target.select(target.foodEntries).get();
    for (final e in entries) {
      expect(await target.foodDao.foodById(e.foodItemId), isNotNull);
    }
    final recipe = await target.select(target.recipes).getSingle();
    final ingredient = await target
        .select(target.recipeIngredients)
        .getSingle();
    expect(ingredient.recipeId, recipe.id);
    expect(ingredient.foodItemId, isNot(recipe.foodItemId));
    expect(
      (await target.foodDao.foodById(ingredient.foodItemId))?.name,
      'Oats',
    );
    final set = await target.select(target.workoutSets).getSingle();
    final we = await (target.select(
      target.workoutExercises,
    )..where((x) => x.id.equals(set.workoutExerciseId))).getSingle();
    expect(we.exerciseNameSnapshot, 'Squat');
  });

  group('invalid files are rejected before any change', () {
    late String json;
    setUp(() async => json = await _export(source));

    void rejects(String text, String messagePart) => expect(
      () => BackupValidator.parse(text),
      throwsA(
        isA<InvalidBackup>().having(
          (e) => e.message,
          'message',
          contains(messagePart),
        ),
      ),
    );

    test('not JSON, not a FitPath backup', () {
      rejects('{oops', 'not valid JSON');
      rejects('{"format": "other"}', 'not a FitPath backup');
    });

    test('newer or missing version', () {
      rejects(_tamper(json, (d) => d['format_version'] = 3), 'newer version');
      rejects(
        _tamper(json, (d) => d.remove('format_version')),
        'format version',
      );
    });

    test('missing table or field, wrong type', () {
      rejects(
        _tamper(json, (d) => (d['tables'] as Map).remove('food_entries')),
        'missing "food_entries"',
      );
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['food_entries'] as List;
          (rows.first as Map).remove('mealType');
        }),
        'Row 1 of "food_entries"',
      );
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['weight_entries'] as List;
          (rows.first as Map)['weightKg'] = 'heavy';
        }),
        'Row 1 of "weight_entries"',
      );
    });

    test('broken references and duplicate ids', () {
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['recipe_ingredients'] as List;
          (rows.first as Map)['foodItemId'] = 999;
        }),
        '"recipe_ingredients" refers',
      );
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['food_entries'] as List;
          (rows.first as Map)['foodItemId'] = 999;
        }),
        'refers to a record (999)',
      );
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['workout_sets'] as List;
          (rows.first as Map)['workoutExerciseId'] = 999;
        }),
        '"workout_sets" refers',
      );
      rejects(
        _tamper(json, (d) {
          final rows = (d['tables'] as Map)['weight_entries'] as List;
          rows.add(rows.first);
        }),
        'twice',
      );
    });
  });

  test('v1 backup restores into a v2 database without recipes', () async {
    final v1 = _tamper(await _export(source), (d) {
      d['format_version'] = 1;
      final tables = d['tables'] as Map;
      tables.remove('recipes');
      tables.remove('recipe_ingredients');
      (tables['food_items'] as List).removeWhere(
        (food) => (food as Map)['source'] == 'recipe',
      );
      (tables['food_entries'] as List).removeWhere(
        (entry) => (entry as Map)['nameSnapshot'] == 'Apple granola bowl',
      );
    });
    final before = BackupValidator.parse(v1);
    expect(before.recipes, isEmpty);
    await ImportService(target).restore(before);
    expect(await target.select(target.recipes).get(), isEmpty);
    expect(await target.select(target.foodEntries).get(), hasLength(2));
  });

  test('invalid v2 recipe reference leaves existing data unchanged', () async {
    await ProfileRepository(target.profileDao).logWeight(99);
    final before = await _snapshot(target);
    final invalid = _tamper(await _export(source), (d) {
      final ingredients = (d['tables'] as Map)['recipe_ingredients'] as List;
      (ingredients.single as Map)['recipeId'] = 999;
    });
    expect(() => BackupValidator.parse(invalid), throwsA(isA<InvalidBackup>()));
    expect(await _snapshot(target), before);
  });

  test('a failing restore rolls back everything', () async {
    await ProfileRepository(target.profileDao).logWeight(99);
    final before = await _snapshot(target);

    // Two foods with the same barcode pass validation but break the unique
    // constraint halfway through the inserts.
    final json = _tamper(await _export(source), (d) {
      final foods = (d['tables'] as Map)['food_items'] as List;
      for (var i = 0; i < foods.length; i++) {
        (foods[i] as Map)['externalId'] = 'same';
      }
    });
    final backup = BackupValidator.parse(json);
    await expectLater(ImportService(target).restore(backup), throwsA(anything));
    expect(await _snapshot(target), before);
  });

  testWidgets('restore section: invalid file, then a confirmed restore', (
    tester,
  ) async {
    final valid = (await tester.runAsync(() => _export(source)))!;
    String? next;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(target),
          backupFilePickerProvider.overrideWithValue(() async => next),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BackupRestoreSection(onExportFirst: () async {}),
          ),
        ),
      ),
    );

    next = '{"format": "other"}';
    await tester.tap(find.text('CHOOSE BACKUP FILE'));
    await tester.pumpAndSettle();
    expect(find.text("Can't restore this file"), findsOneWidget);
    expect(find.textContaining('Nothing was changed.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    next = valid;
    await tester.tap(find.text('CHOOSE BACKUP FILE'));
    await tester.pumpAndSettle();
    expect(find.text('Replace your data?'), findsOneWidget);
    expect(find.textContaining('3 diary entries, 1 workout'), findsOneWidget);
    await tester.tap(find.text('RESTORE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Backup restored.'), findsOneWidget);
    final entries = await tester.runAsync(
      () => target.select(target.foodEntries).get(),
    );
    expect(entries, hasLength(3));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
