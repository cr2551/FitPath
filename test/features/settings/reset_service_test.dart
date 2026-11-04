import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/data/reset_service.dart';
import 'package:fitpath/features/settings/presentation/reset_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

/// Fills every user-owned table, plus bundled catalog rows.
Future<void> _seed(AppDatabase db) async {
  final bundledFood = await db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          name: 'Apple',
          referenceBasis: ReferenceBasis.per100g,
          source: FoodSource.bundled,
          isActive: const Value(false), // hidden by the user
        ),
      );
  final foods = FoodRepository(db.foodDao);
  final custom = await foods.createCustomFood(
    const FoodDetails(
      name: 'Salad',
      basis: ReferenceBasis.per100g,
      nutrients: Nutrients(kcal: 50),
    ),
  );
  await foods.cacheExternalFood(
    '123',
    const FoodDetails(name: 'Bar', basis: ReferenceBasis.per100g),
  );
  for (final id in [bundledFood, custom]) {
    await foods.logFood(
      foodId: id,
      quantity: 100,
      unit: QuantityUnit.gram,
      meal: MealType.lunch,
    );
  }

  final bundledExercise = await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: 'Squat',
          muscleGroup: 'legs',
          deletedAt: Value(DateTime(2026)),
        ),
      );
  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: 'My curl',
          muscleGroup: 'arms',
          isCustom: const Value(true),
        ),
      );
  final session = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          startedAt: DateTime(2026, 11, 1),
          status: WorkoutStatus.completed,
        ),
      );
  final we = await db
      .into(db.workoutExercises)
      .insert(
        WorkoutExercisesCompanion.insert(
          sessionId: session,
          exerciseId: bundledExercise,
          exerciseNameSnapshot: 'Squat',
          orderIndex: 0,
        ),
      );
  await db
      .into(db.workoutSets)
      .insert(WorkoutSetsCompanion.insert(workoutExerciseId: we, setNumber: 1));

  final profile = ProfileRepository(db.profileDao);
  await profile.saveProfile(ageYears: 30, heightCm: 180);
  await profile.logWeight(80);
  await profile.setPrimaryGoal(GoalType.loseWeight);
  await profile.setTargets(calories: 2000, source: TargetSource.user);
  await profile.setUnitSystem(UnitSystem.imperial);
  await profile.setThemeMode('dark');
  await profile.setOnboardingCompleted(true);
  await DashboardRepository(db.dashboardDao).applyPreset(GoalType.loseWeight);
}

Future<int> _count(AppDatabase db, TableInfo<Table, Object?> table) async =>
    (await db.select(table).get()).length;

void main() {
  test('reset removes user data and keeps bundled catalogs', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await _seed(db);

    await ResetService(db).resetAll();

    final foods = await db.select(db.foodItems).get();
    expect(foods.map((f) => f.name), ['Apple']);
    expect(foods.single.isActive, isTrue);
    final exercises = await db.select(db.exercises).get();
    expect(exercises.map((e) => e.name), ['Squat']);
    expect(exercises.single.deletedAt, isNull);

    for (final table in <TableInfo<Table, Object?>>[
      db.foodEntries,
      db.workoutSessions,
      db.workoutExercises,
      db.workoutSets,
      db.userProfile,
      db.fitnessGoals,
      db.weightEntries,
      db.nutritionTargets,
      db.dashboardCards,
    ]) {
      expect(await _count(db, table), 0, reason: table.actualTableName);
    }

    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.unitSystem, UnitSystem.metric);
    expect(settings.themeMode, 'system');
    final meta = await db.select(db.appMetadata).getSingle();
    expect(meta.onboardingCompleted, isFalse);
  });

  testWidgets('the screen needs the typed word, then opens onboarding', (
    tester,
  ) async {
    final db = createTestDatabase();
    await tester.runAsync(() => _seed(db));
    final router = GoRouter(
      initialLocation: '/reset',
      routes: [GoRoute(path: '/reset', builder: (_, _) => const ResetScreen())],
      errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();

    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'RESET ALL DATA'),
    );
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'rese');
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'reset');
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.tap(find.text('RESET ALL DATA'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('route /onboarding/welcome'), findsOneWidget);
    expect(await tester.runAsync(() => _count(db, db.userProfile)), 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
