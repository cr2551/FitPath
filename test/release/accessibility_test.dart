import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/router/app_router.dart';
import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/onboarding/application/onboarding_status_provider.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/profile/data/sample_profile_seeder.dart';
import 'package:fitpath/features/profile/domain/sample_profiles.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

/// Ids of the seeded rows the routes below open.
late int _foodId, _entryId, _sessionId, _exerciseId, _recipeId;

/// A realistic database: Alex's profile, weights, goals and targets, the
/// "lose weight" dashboard, a custom food logged today, a recipe made from
/// it and a completed workout with a custom exercise.
Future<AppDatabase> _seed() async {
  final db = createTestDatabase();
  final now = DateTime.now();
  final profile = ProfileRepository(db.profileDao);
  await seedSampleProfile(profile, SampleProfiles.alex, today: now);
  await DashboardRepository(db.dashboardDao).applyPreset(GoalType.loseWeight);

  final foods = FoodRepository(db.foodDao);
  _foodId = await foods.createCustomFood(
    const FoodDetails(
      name: 'Greek yogurt with honey and toasted granola, large bowl',
      brand: 'Homemade breakfast company',
      basis: ReferenceBasis.per100g,
      nutrients: Nutrients(kcal: 150, proteinG: 9, carbsG: 18, fatG: 4),
      servingSize: 250,
      servingUnit: QuantityUnit.gram,
      servingDescription: '1 bowl',
    ),
  );
  _entryId = await foods.logFood(
    foodId: _foodId,
    quantity: 250,
    unit: QuantityUnit.gram,
    meal: MealType.breakfast,
  );
  _recipeId = await RecipeRepository(db.recipeDao, db.foodDao).create(
    RecipeInput(
      name: 'Overnight yogurt pots for the whole week, with extra granola',
      servings: 6,
      ingredients: [
        IngredientInput(
          foodId: _foodId,
          quantity: 3,
          unit: QuantityUnit.serving,
        ),
      ],
    ),
  );

  _exerciseId = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(
      name: 'Barbell back squat, high bar, paused',
      muscleGroup: 'legs',
      isCustom: const Value(true),
    ),
  );
  final workouts = WorkoutRepository(db.workoutDao);
  _sessionId = await workouts.startSession();
  final we = await workouts.addExercise(_sessionId, _exerciseId);
  for (final kg in [100.0, 102.5, 105.0]) {
    final set = await workouts.addSet(we, reps: 5, weightKg: kg);
    await workouts.updateSet(set, completed: const Value(true));
  }
  await workouts.completeSession(_sessionId);
  return db;
}

/// Small phone (360 dp wide) at 200% text. The container (and its database
/// streams) is disposed before the database closes.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  AppDatabase db, {
  bool onboardingDone = true,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      onboardingCompletedProvider.overrideWithValue(onboardingDone),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// The first line of an error and the widget that caused it.
String _describe(FlutterErrorDetails d) {
  final cause = RegExp(
    r'relevant error-causing widget was:\s*\n\s*(.*)\n\s*(.*)',
  ).firstMatch(d.toString());
  final first = d.exceptionAsString().split('\n').first;
  return cause == null ? first : '$first (${cause[1]} ${cause[2]})';
}

void main() {
  // Every screen with realistic data, on a small phone at 200% text: no
  // overflow, 48 dp tap targets, and a label on every tappable control.
  // Text contrast is checked on the theme colors in contrast_test.dart.
  testWidgets('every screen at 200% text on a 360 dp phone', (tester) async {
    final db = (await tester.runAsync(_seed))!;
    addTearDown(db.close);

    final problems = <String>[];
    var screen = '';
    Future<void> check() async {
      for (final g in [androidTapTargetGuideline, labeledTapTargetGuideline]) {
        final r = await g.evaluate(tester);
        if (!r.passed) problems.add('$screen: ${r.reason}');
      }
    }

    final original = FlutterError.onError;
    FlutterError.onError = (d) => problems.add('$screen: ${_describe(d)}');
    try {
      final container = await _pump(tester, db);
      final router = container.read(appRouterProvider);
      for (final location in [
        Routes.home,
        Routes.nutrition,
        Routes.foodSearch(meal: MealType.lunch),
        Routes.foodDetails(_foodId),
        Routes.newEntry(foodId: _foodId, meal: MealType.lunch),
        Routes.editEntry(_entryId),
        Routes.newCustomFood,
        Routes.editCustomFood(_foodId),
        Routes.newRecipe,
        Routes.editRecipe(_recipeId),
        Routes.workouts,
        Routes.exercisePicker,
        Routes.newCustomExercise,
        Routes.editCustomExercise(_exerciseId),
        Routes.sessionDetail(_sessionId),
        Routes.progress,
        Routes.profile,
        Routes.profileDetails,
        Routes.goals,
        Routes.targets,
        Routes.backup,
        Routes.reset,
        Routes.about,
      ]) {
        screen = location;
        router.go(location);
        await _settle(tester);
        await check();
      }

      // The other Progress tabs.
      router.go(Routes.progress);
      await _settle(tester);
      for (final tab in ['NUTRITION', 'WORKOUTS']) {
        screen = 'progress $tab';
        await tester.tap(find.text(tab).first);
        await _settle(tester);
        await check();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    } finally {
      FlutterError.onError = original;
      for (final p in problems) {
        debugPrint('PROBLEM $p');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
