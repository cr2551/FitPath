import '../../../core/utils/dates.dart';
import '../../../shared/models/enums.dart';
import '../domain/metabolic_calculator.dart';
import '../domain/sample_profiles.dart';
import 'profile_repository.dart';

/// Writes a [SampleProfile] into the database as if the user had completed
/// onboarding: profile details, a weight history, goals and calculated
/// nutrition targets. For development and tests only, so the Profile screen
/// and the calculators can be exercised with realistic data.
///
/// Weight history: [weightEntries] entries, one every [daysBetween] days,
/// ending today at the sample's current weight and starting
/// [startingOffsetKg] away from it (heavier for weight loss, lighter for
/// gaining goals).
Future<void> seedSampleProfile(
  ProfileRepository repo,
  SampleProfile sample, {
  DateTime? today,
  int weightEntries = 9,
  int daysBetween = 7,
  double startingOffsetKg = 2.4,
}) {
  final now = today ?? DateTime.now();
  final m = sample.metabolic;

  return repo.transaction(() async {
    await repo.saveProfile(
      ageYears: m.ageYears,
      heightCm: m.heightCm,
      sex: m.sex,
      activityLevel: m.activityLevel,
      trainingExperience: sample.trainingExperience,
      trainingFrequencyPerWeek: sample.trainingFrequencyPerWeek,
    );

    final current = m.weightKg;
    if (current != null && weightEntries > 0) {
      final gaining =
          m.goal == GoalType.buildMuscle || m.goal == GoalType.improveStrength;
      final start = current + (gaining ? -startingOffsetKg : startingOffsetKg);
      for (var i = 0; i < weightEntries; i++) {
        final progress = weightEntries == 1 ? 1.0 : i / (weightEntries - 1);
        final kg = start + (current - start) * progress;
        await repo.logWeight(
          double.parse(kg.toStringAsFixed(1)),
          at: DateTime(
            now.year,
            now.month,
            now.day - (weightEntries - 1 - i) * daysBetween,
            7,
          ),
        );
      }
    }

    if (m.goal != null) {
      await repo.setPrimaryGoal(
        m.goal!,
        targetWeightKg: sample.targetWeightKg,
        targetDate: sample.targetDate,
      );
    }
    await repo.setSecondaryGoals(sample.secondaryGoals.toSet());

    final estimates = MetabolicCalculator.estimate(m);
    final target = estimates.calorieTarget.value;
    final macros = estimates.macros.value;
    if (target != null && macros != null) {
      await repo.setTargets(
        calories: target.kcal,
        proteinG: macros.proteinG.toDouble(),
        carbsG: macros.carbsG.toDouble(),
        fatG: macros.fatG.toDouble(),
        source: TargetSource.calculated,
        effectiveFrom: Dates.addDays(now, -(weightEntries * daysBetween)),
      );
    }

    await repo.setOnboardingCompleted(true);
  });
}
