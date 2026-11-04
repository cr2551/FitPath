import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/profile/application/profile_providers.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/profile/data/sample_profile_seeder.dart';
import 'package:fitpath/features/profile/domain/metabolic_calculator.dart';
import 'package:fitpath/features/profile/domain/metabolic_profile.dart';
import 'package:fitpath/features/profile/domain/sample_profiles.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  final today = DateTime(2026, 11, 3, 12);
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = ProfileRepository(db.profileDao, clock: () => today);
  });
  tearDown(() => db.close());

  group('profile', () {
    test('saving twice keeps a single row and updates it', () async {
      await repo.saveProfile(ageYears: 30, heightCm: 170, sex: Sex.female);
      await repo.saveProfile(
        ageYears: 31,
        heightCm: 170,
        sex: Sex.female,
        activityLevel: ActivityLevel.active,
      );

      final rows = await db.select(db.userProfile).get();
      expect(rows, hasLength(1));
      expect(rows.single.ageYears, 31);
      expect(rows.single.activityLevel, ActivityLevel.active);
    });

    test('implausible values are rejected, not stored', () async {
      expect(() => repo.saveProfile(ageYears: 7), throwsArgumentError);
      expect(() => repo.saveProfile(heightCm: 300), throwsArgumentError);
      expect(() => repo.logWeight(10), throwsArgumentError);
      expect(await db.select(db.userProfile).get(), isEmpty);
    });
  });

  group('weight', () {
    test(
      'current weight is the latest entry by date, not insert order',
      () async {
        await repo.logWeight(74.2, at: DateTime(2026, 11, 3));
        await repo.logWeight(75.0, at: DateTime(2026, 10, 1));

        expect(await repo.watchCurrentWeightKg().first, 74.2);
      },
    );

    test('no entries means no current weight', () async {
      expect(await repo.watchCurrentWeightKg().first, isNull);
    });

    test('range filter and newest-first order', () async {
      await repo.logWeight(76, at: DateTime(2026, 9, 1));
      await repo.logWeight(75, at: DateTime(2026, 10, 30));
      await repo.logWeight(74.5, at: DateTime(2026, 11, 2));

      final last7 = await repo
          .watchWeights(Dates.rangeFor(RangePreset.days7, today))
          .first;
      expect(last7.map((w) => w.weightKg), [74.5, 75]);
    });

    test('update and delete', () async {
      final id = await repo.logWeight(80, at: DateTime(2026, 11, 1));

      expect(await repo.updateWeight(id, kg: 79.5, notes: 'after run'), isTrue);
      final row = (await db.select(db.weightEntries).get()).single;
      expect((row.weightKg, row.notes), (79.5, 'after run'));
      expect(row.recordedAt, DateTime(2026, 11, 1));

      expect(await repo.deleteWeight(id), isTrue);
      expect(await db.select(db.weightEntries).get(), isEmpty);
      expect(await repo.deleteWeight(id), isFalse);
    });
  });

  group('goals', () {
    test('changing the primary goal keeps history', () async {
      await repo.setPrimaryGoal(GoalType.loseWeight, targetWeightKg: 80);
      await repo.setPrimaryGoal(GoalType.maintainWeight);

      final active = await repo.watchActiveGoals().first;
      expect(active.map((g) => g.goalType), [GoalType.maintainWeight]);

      final all = await db.profileDao.allGoals();
      expect(all, hasLength(2));
      expect(all.first.isActive, isFalse);
      expect(all.first.targetWeightKg, 80);
    });

    test('secondary goals are replaced without touching the primary', () async {
      await repo.setPrimaryGoal(GoalType.buildMuscle);
      await repo.setSecondaryGoals({
        GoalType.improveStrength,
        GoalType.generalFitness,
      });
      await repo.setSecondaryGoals({GoalType.improveStrength});

      final active = await repo.watchActiveGoals().first;
      expect(active.first.isPrimary, isTrue);
      expect(active.map((g) => g.goalType), [
        GoalType.buildMuscle,
        GoalType.improveStrength,
      ]);
      expect(await db.profileDao.allGoals(), hasLength(3));
    });
  });

  group('nutrition targets', () {
    test('past days keep the targets that applied then', () async {
      await repo.setTargets(
        calories: 2300,
        proteinG: 120,
        source: TargetSource.calculated,
        effectiveFrom: DateTime(2026, 10, 1),
      );
      await repo.setTargets(
        calories: 2100,
        proteinG: 140,
        source: TargetSource.user,
        effectiveFrom: DateTime(2026, 11, 1),
      );

      expect((await repo.targetsOn(DateTime(2026, 9, 30))), isNull);
      expect((await repo.targetsOn(DateTime(2026, 10, 31)))!.calories, 2300);
      expect((await repo.targetsOn(DateTime(2026, 11, 1)))!.calories, 2100);
      final now = (await repo.targetsOn(today))!;
      expect((now.calories, now.source), (2100, TargetSource.user));
    });

    test('a second change on the same day wins', () async {
      await repo.setTargets(calories: 2000, source: TargetSource.calculated);
      await repo.setTargets(calories: 1900, source: TargetSource.user);

      expect((await repo.targetsOn(today))!.calories, 1900);
    });
  });

  group('preferences', () {
    test('unit system is a display preference only', () async {
      await repo.logWeight(80, at: today);
      await repo.setUnitSystem(UnitSystem.imperial);

      expect(await repo.watchUnitSystem().first, UnitSystem.imperial);
      expect(await repo.watchCurrentWeightKg().first, 80);
    });

    test('onboarding flag and theme mode', () async {
      expect(await repo.watchOnboardingCompleted().first, isFalse);
      await repo.setOnboardingCompleted(true);
      await repo.setThemeMode('dark');

      expect(await repo.watchOnboardingCompleted().first, isTrue);
      expect(await repo.watchThemeMode().first, 'dark');
    });
  });

  group('sample profiles (fake data)', () {
    Future<ProviderContainer> containerFor(SampleProfile sample) async {
      await seedSampleProfile(repo, sample, today: today);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      // Riverpod 3 pauses providers nobody listens to, so keep the
      // estimates (and everything they depend on) active, then wait for the
      // streams behind them to emit.
      container.listen(profileEstimatesProvider, (_, _) {});
      await container.read(profileProvider.future);
      await container.read(currentWeightProvider.future);
      await container.read(activeGoalsProvider.future);
      return container;
    }

    for (final sample in SampleProfiles.all) {
      test('${sample.label}: stored data gives the same estimates', () async {
        final container = await containerFor(sample);

        final stored = container.read(metabolicProfileProvider).requireValue;
        final expected = MetabolicCalculator.estimate(sample.metabolic);
        final actual = container.read(profileEstimatesProvider).requireValue;

        expect(stored.weightKg, sample.metabolic.weightKg);
        expect(stored.goal, sample.metabolic.goal);
        expect(actual.bmr.value, expected.bmr.value);
        expect(
          actual.calorieTarget.value?.kcal,
          expected.calorieTarget.value?.kcal,
        );
        expect(actual.calorieTarget.missing, expected.calorieTarget.missing);
      });
    }

    test('Alex: weight history trends down to the current weight', () async {
      await seedSampleProfile(repo, SampleProfiles.alex, today: today);

      final weights = await repo
          .watchWeights(Dates.rangeFor(RangePreset.days90, today))
          .first;
      expect(weights, hasLength(9));
      expect(weights.first.weightKg, 92);
      expect(weights.last.weightKg, 94.4);
    });

    test(
      'Alex: calculated targets are stored and onboarding is done',
      () async {
        await seedSampleProfile(repo, SampleProfiles.alex, today: today);

        final t = (await repo.targetsOn(today))!;
        expect(
          (t.calories, t.proteinG, t.carbsG, t.fatG),
          (2070, 166, 223, 58),
        );
        expect(t.source, TargetSource.calculated);
        expect(await repo.watchOnboardingCompleted().first, isTrue);
      },
    );

    test(
      'Lee (no height): no targets are stored and height is reported missing',
      () async {
        final container = await containerFor(SampleProfiles.lee);

        expect(await repo.targetsOn(today), isNull);
        expect(
          container.read(profileEstimatesProvider).requireValue.bmi.missing,
          {MetabolicInput.height},
        );
      },
    );
  });
}
