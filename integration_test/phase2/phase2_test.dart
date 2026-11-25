import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/backup/backup_validator.dart';
import 'package:fitpath/features/settings/backup/export_service.dart';
import 'package:fitpath/features/settings/backup/import_service.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:fitpath/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';

import 'harness.dart';

// End-to-end tests for Phase 2 and for upgrades from v1.0 data. Like the
// REL-3 suite they need a device, an emulator or the desktop:
//
//   flutter test integration_test -d <device id>

Future<Exercise> _exercise(AppDatabase db, String name) =>
    (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle();

Future<FoodItem> _food(AppDatabase db, String name) => (db.select(
  db.foodItems,
)..where((f) => f.name.equals(name) & f.isActive.equals(true))).getSingle();

String _day(DateTime d) => DateFormat('EEE d MMM').format(d);

/// A completed session of one exercise, started at [at].
Future<void> _seedSession(
  AppDatabase db,
  DateTime at,
  String exercise,
  List<(int reps, double kg)> sets,
) async {
  final repo = WorkoutRepository(db.workoutDao, clock: () => at);
  final session = await repo.startSession();
  final entry = await repo.addExercise(
    session,
    (await _exercise(db, exercise)).id,
  );
  for (final (reps, kg) in sets) {
    final set = await repo.addSet(entry, reps: reps, weightKg: kg);
    await repo.updateSet(set, completed: const Value(true));
  }
  await repo.completeSession(session);
}

/// Turns a v2 database file back into what v1.0 left on disk: no recipe
/// tables, no recipe foods, schema version 1.
Future<void> _downgradeToV1(File file) async {
  final db = AppDatabase(NativeDatabase(file), seedCatalogs: false);
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement('DROP TABLE recipe_ingredients');
  await db.customStatement('DROP TABLE recipes');
  await db.customStatement("DELETE FROM food_items WHERE source = 'recipe'");
  await db.customStatement('PRAGMA user_version = 1');
  await db.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Device device;
  setUp(() => device = Device());
  tearDown(() => device.dispose());

  testWidgets('logging workouts: new PR, both 1RM estimates and the weekly '
      'streak', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    // Last week: a lighter bench press, so today's is a record and the
    // streak spans two weeks.
    await _seedSession(
      device.db!,
      Dates.addDays(DateTime.now(), -7),
      'Bench press',
      [(5, 50)],
    );

    await tab(tester, 'Workouts');
    await tapText(tester, 'START WORKOUT');
    await tapText(tester, 'START');
    await tapText(tester, 'ADD EXERCISE');
    await enter(tester, find.byType(TextField).first, 'Bench press');
    await tap(tester, find.text('Bench press').last);
    await enter(
      tester,
      find.bySemanticsLabel(RegExp('^Bench press set 1 load')),
      '60',
    );
    await enter(
      tester,
      find.bySemanticsLabel(RegExp('^Bench press set 1 reps')),
      '5',
    );
    await tap(tester, find.byType(Checkbox).first);
    await tapText(tester, 'FINISH WORKOUT');
    await tapText(tester, 'FINISH');

    expect(screenTitle('Session'), findsOneWidget);
    expect(find.textContaining('New PR'), findsWidgets);

    await tap(tester, find.byTooltip('View exercise history for Bench press'));
    // 60 kg x 5: Epley 70, Brzycki 67.5.
    expect(find.textContaining('Epley 70'), findsWidgets);
    expect(find.textContaining('Brzycki 67.5'), findsWidgets);

    await tab(tester, 'Progress');
    await tapText(tester, 'WORKOUTS');
    await tap(tester, find.text('Weekly streak'));
    expect(find.bySemanticsLabel(RegExp(r'^Current 2 weeks')), findsOneWidget);
  });

  testWidgets('what-if: applying targets changes today on, not past days', (
    tester,
  ) async {
    await launch(tester, device);
    await onboard(tester);
    final profile = ProfileRepository(device.db!.profileDao);
    final today = DateTime.now();
    final yesterday = Dates.addDays(today, -1);
    await profile.setTargets(
      calories: 1800,
      source: TargetSource.user,
      effectiveFrom: Dates.addDays(today, -10),
    );

    await tab(tester, 'Profile');
    await tapText(tester, 'What if');
    await enter(tester, field('Daily calories'), '2100');
    await tapText(tester, 'APPLY AS MY TARGETS');
    await tapText(tester, 'APPLY');

    expect((await profile.targetsOn(today))!.calories, 2100);
    expect((await profile.targetsOn(yesterday))!.calories, 1800);

    await tab(tester, 'Nutrition');
    expect(find.textContaining('2,100', findRichText: true), findsWidgets);
    await tap(tester, find.byTooltip('Previous week'));
    // Any day of last week used the older target.
    await tap(tester, find.text('${Dates.addDays(today, -7).day}'));
    expect(find.textContaining('1,800', findRichText: true), findsWidgets);
  });

  testWidgets('weekly report for a seeded week', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    final db = device.db!;
    final lastWeek = Dates.addDays(Dates.startOfWeek(DateTime.now()), -7);
    final monday = Dates.addDays(lastWeek, 1).add(const Duration(hours: 12));
    final wednesday = Dates.addDays(monday, 2);

    final banana = await _food(db, 'Banana, raw');
    for (final day in [monday, wednesday]) {
      await FoodRepository(db.foodDao).logFood(
        foodId: banana.id,
        quantity: 200,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: day,
      );
    }
    await _seedSession(db, monday, 'Back squat', [(5, 100), (5, 100)]);
    await _seedSession(db, wednesday, 'Back squat', [(5, 105)]);
    final profile = ProfileRepository(db.profileDao);
    await profile.logWeight(89.6, at: monday);
    await profile.logWeight(89.2, at: wednesday);

    await tab(tester, 'Progress');
    await tap(tester, find.byTooltip('Weekly report'));
    expect(screenTitle('Weekly report'), findsOneWidget);
    // Two days of food, two workouts.
    await reveal(tester, find.text('2 of 7'));
    await reveal(tester, find.text('Last week 0 (+2)'));
    // 2 x 5 x 100 + 5 x 105.
    await reveal(tester, find.textContaining('1,525 kg', findRichText: true));
    await reveal(
      tester,
      find.text('Heaviest load · 105 kg · ${_day(wednesday)}'),
    );
    await reveal(tester, find.text('Last weigh-in'));
    expect(find.textContaining('89.2', findRichText: true), findsWidgets);
  });

  testWidgets('recipe: build, swap an ingredient, log it, edit it; the '
      'logged entry is unchanged', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    final db = device.db!;

    await tab(tester, 'Nutrition');
    await tap(tester, find.widgetWithText(TextField, 'Search foods'));
    await tapText(tester, 'Create recipe');
    await enter(tester, field('Name'), 'Honey oat bars');
    await enter(tester, field('Servings'), '4');
    for (final (query, name) in [
      ('sugar', 'Sugar, white'),
      ('rolled oats', 'Rolled oats, dry'),
    ]) {
      await tapText(tester, 'Add ingredient');
      await enter(tester, find.byType(TextField).first, query);
      await tap(tester, find.text(name));
    }
    await tap(tester, find.byTooltip('Ingredient options').first);
    await tapText(tester, 'Swap');
    expect(
      find.textContaining('Wikibooks Cookbook contributors'),
      findsOneWidget,
    );
    await tapText(tester, 'Honey');
    expect(find.text('Swapped Sugar, white for Honey'), findsOneWidget);
    // The snackbar covers the button.
    await reveal(tester, find.text('CREATE RECIPE'));
    ScaffoldMessenger.of(tester.element(find.text('CREATE RECIPE')))
        .hideCurrentSnackBar();
    await settle(tester);
    await tapText(tester, 'CREATE RECIPE');

    final recipeFood = await _food(db, 'Honey oat bars');
    final details = (await RecipeRepository(
      db.recipeDao,
      db.foodDao,
    ).byFoodId(recipeFood.id))!;
    expect(
      [for (final i in details.ingredients) i.food.name],
      ['Honey', 'Rolled oats, dry'],
    );

    // Back on search: log one serving.
    await enter(tester, find.byType(TextField).first, 'honey oat');
    await tapText(tester, 'Honey oat bars');
    await tapText(tester, 'ADD TO DIARY');
    await tapText(tester, 'LOG FOOD');
    final entry = await db.select(db.foodEntries).getSingle();
    expect(entry.kcal, closeTo(recipeFood.kcal!, 0.001));

    // Edit: one serving instead of four.
    await tap(tester, find.widgetWithText(TextField, 'Search foods'));
    await enter(tester, find.byType(TextField).first, 'honey oat');
    await tapText(tester, 'Honey oat bars');
    await tapText(tester, 'EDIT RECIPE');
    await enter(tester, field('Servings'), '1');
    await tapText(tester, 'SAVE');

    final edited = await _food(db, 'Honey oat bars');
    expect(edited.kcal, closeTo(recipeFood.kcal! * 4, 0.01));
    expect(await db.select(db.foodEntries).getSingle(), entry);
  });

  testWidgets('recipe ideas work offline', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    final db = device.db!;
    expect(await db.select(db.recipes).get(), isNotEmpty);

    await tab(tester, 'Nutrition');
    await tapText(tester, 'Recipe ideas');
    expect(screenTitle('Recipe ideas'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^[\d,]+ kcal left$')), findsOneWidget);
    await reveal(tester, find.textContaining('UniTools'));
    await tap(tester, find.byType(ListRow).last);
    expect(screenTitle('Recipe ideas'), findsNothing); // the entry screen
    await tapText(tester, 'LOG FOOD');

    final entry = await db.select(db.foodEntries).getSingle();
    final food = (await db.foodDao.foodById(entry.foodItemId))!;
    expect(food.source, FoodSource.recipe);
    expect(entry.quantity, 1);
  });

  testWidgets('a v1 database file upgrades to v2 and keeps all data', (
    tester,
  ) async {
    await launch(tester, device);
    await onboard(tester);
    final db = device.db!;
    await FoodRepository(db.foodDao).logFood(
      foodId: (await _food(db, 'Banana, raw')).id,
      quantity: 120,
      unit: QuantityUnit.gram,
      meal: MealType.snack,
    );
    await _seedSession(db, DateTime.now(), 'Back squat', [(5, 100)]);
    Future<List<Object>> userData(AppDatabase db) async => [
      ...await db.select(db.userProfile).get(),
      ...await db.select(db.fitnessGoals).get(),
      ...await db.select(db.weightEntries).get(),
      ...await db.select(db.nutritionTargets).get(),
      ...await db.select(db.foodEntries).get(),
      ...await db.select(db.workoutSessions).get(),
      ...await db.select(db.workoutSets).get(),
      ...await db.select(db.dashboardCards).get(),
    ];
    final before = await userData(db);

    await tester.pumpWidget(const SizedBox());
    await device.close();
    await _downgradeToV1(device.file);

    await launch(tester, device);
    final upgraded = device.db!;
    expect(header('Today'), findsOneWidget); // no onboarding again
    expect(await userData(upgraded), before);
    // The startup re-seed brings the bundled recipes.
    expect(await upgraded.select(upgraded.recipes).get(), isNotEmpty);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 2);
  });

  testWidgets('a v1 backup restores into v1.1', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    final json = File('test/fixtures/v1/backup_v1.json').readAsStringSync();
    final backup = BackupValidator.parse(json);
    await ImportService(device.db!).restore(backup);

    await launch(tester, device);
    final db = device.db!;
    expect((await db.select(db.userProfile).getSingle()).heightCm, 172);
    final entry = await db.select(db.foodEntries).getSingle();
    expect(entry.nameSnapshot, 'Lentil soup (v1 fixture)');
    expect((await db.select(db.workoutSets).getSingle()).weightKg, 24);
    // The bundled recipes come back on the next start.
    expect(await db.select(db.recipes).get(), isNotEmpty);
    expect(header('Today'), findsOneWidget);
  });

  testWidgets('a v2 backup with recipes round-trips', (tester) async {
    await launch(tester, device);
    await onboard(tester);
    final db = device.db!;
    final recipes = RecipeRepository(db.recipeDao, db.foodDao);
    final oats = await _food(db, 'Rolled oats, dry');
    final milk = await _food(db, 'Whole milk');
    final porridge = await recipes.create(
      RecipeInput(
        name: 'Porridge',
        servings: 2,
        ingredients: [
          IngredientInput(
            foodId: oats.id,
            quantity: 80,
            unit: QuantityUnit.gram,
          ),
          IngredientInput(
            foodId: milk.id,
            quantity: 300,
            unit: QuantityUnit.milliliter,
          ),
        ],
      ),
    );
    await FoodRepository(db.foodDao).logFood(
      foodId: porridge,
      quantity: 1,
      unit: QuantityUnit.serving,
      meal: MealType.breakfast,
    );
    Future<List<Object>> snapshot() async => [
      ...await db.select(db.recipes).get(),
      ...await db.select(db.recipeIngredients).get(),
      ...await db.select(db.foodEntries).get(),
      (await db.foodDao.foodById(porridge))!,
    ];
    final before = await snapshot();
    final backup = jsonEncode(
      (await ExportService(db).buildBackup(appVersion: 'test')).toJson(),
    );

    await recipes.delete(porridge);
    await ImportService(db).restore(BackupValidator.parse(backup));
    expect(await snapshot(), before);
  });
}
