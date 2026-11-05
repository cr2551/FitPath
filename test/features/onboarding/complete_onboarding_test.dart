import 'package:fitpath/app.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/features/onboarding/application/complete_onboarding.dart';
import 'package:fitpath/features/onboarding/application/onboarding_controller.dart';
import 'package:fitpath/features/onboarding/application/onboarding_status_provider.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

const _draft = OnboardingDraft(
  units: UnitSystem.imperial,
  ageYears: 30,
  heightCm: 180,
  weightKg: 90,
  activity: ActivityLevel.moderate,
  sex: Sex.female,
  primaryGoal: GoalType.loseWeight,
  secondaryGoals: {GoalType.improveStrength},
  targetWeightKg: 82,
  experience: TrainingExperience.beginner,
  trainingDaysPerWeek: 3,
  targets: DraftTargets(
    calories: 1900,
    proteinG: 150,
    carbsG: 180,
    fatG: 60,
    editedByUser: true,
  ),
);

/// Launches the real app on [db] and lets the stored flag load.
Future<void> _launch(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const FitPathApp(),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _header(String title) =>
    find.byWidgetPredicate((w) => w is ScreenHeader && w.title == title);

void main() {
  test('saves everything and sets the flag in one go', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(completeOnboardingProvider).call(_draft);

    final profile = (await db.profileDao.getProfile())!;
    expect(profile.ageYears, 30);
    expect(profile.sex, Sex.female);
    expect(profile.trainingExperience, TrainingExperience.beginner);
    expect(profile.trainingFrequencyPerWeek, 3);
    final weights = await db.select(db.weightEntries).get();
    expect(weights.single.weightKg, 90);
    final goals = await db.select(db.fitnessGoals).get();
    final primary = goals.singleWhere((g) => g.isPrimary);
    expect(primary.goalType, GoalType.loseWeight);
    expect(primary.targetWeightKg, 82);
    expect(
      goals.where((g) => !g.isPrimary).single.goalType,
      GoalType.improveStrength,
    );
    final target = (await db.select(db.nutritionTargets).get()).single;
    expect(target.calories, 1900);
    expect(target.source, TargetSource.user);
    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.unitSystem, UnitSystem.imperial);
    final cards = await db.select(db.dashboardCards).get();
    expect(cards.first.cardType, DashboardCardType.caloriesMacros);
    expect(
      (await db.select(db.appMetadata).getSingle()).onboardingCompleted,
      isTrue,
    );
  });

  test('suggested targets are saved as calculated', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container
        .read(completeOnboardingProvider)
        .call(
          const OnboardingDraft(
            units: UnitSystem.metric,
            ageYears: 30,
            heightCm: 180,
            weightKg: 90,
            activity: ActivityLevel.light,
            primaryGoal: GoalType.maintainWeight,
            targets: DraftTargets(calories: 2400, editedByUser: false),
          ),
        );
    final target = (await db.select(db.nutritionTargets).get()).single;
    expect(target.source, TargetSource.calculated);
    expect(target.proteinG, isNull);
  });

  test('an incomplete draft saves nothing', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    expect(
      () => container
          .read(completeOnboardingProvider)
          .call(const OnboardingDraft(units: UnitSystem.metric, ageYears: 30)),
      throwsStateError,
    );
    expect(await db.profileDao.getProfile(), isNull);
    expect(
      (await db.select(db.appMetadata).getSingle()).onboardingCompleted,
      isFalse,
    );
  });

  test('the flag is loaded from the database', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(onboardingCompletedProvider, (_, _) {});
    addTearDown(sub.close);
    expect(container.read(onboardingCompletedProvider), isNull); // loading
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(onboardingCompletedProvider), isFalse);
    await db.profileDao.setOnboardingCompleted(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(onboardingCompletedProvider), isTrue);
  });

  testWidgets('first launch opens onboarding; after completing, Home', (
    tester,
  ) async {
    final db = createTestDatabase();
    await _launch(tester, db);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Complete onboarding, then "restart" the app on the same database.
    await tester.runAsync(() async {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      await c.read(completeOnboardingProvider).call(_draft);
      c.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, db);
    expect(_header('Today'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Lose weight · 181 lb'), findsOneWidget); // goal line

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
