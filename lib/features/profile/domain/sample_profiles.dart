import '../../../shared/models/enums.dart';
import 'metabolic_profile.dart';

/// Fake profile data for development and tests.
///
/// Each persona fills the Profile screen sections ("Your details", "Goals")
/// and exercises a different path through the calculators: every goal, every
/// sex option, missing inputs, and the safety guardrails.
///
/// Not user data and never written to the database in release builds.
class SampleProfile {
  const SampleProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.metabolic,
    this.secondaryGoals = const [],
    this.targetWeightKg,
    this.targetDate,
    this.trainingExperience,
    this.trainingFrequencyPerWeek,
  });

  final String id;
  final String label;

  /// What this persona is useful for testing.
  final String description;

  final MetabolicProfile metabolic;
  final List<GoalType> secondaryGoals;
  final double? targetWeightKg;
  final DateTime? targetDate;
  final TrainingExperience? trainingExperience;
  final int? trainingFrequencyPerWeek;
}

abstract final class SampleProfiles {
  static final alex = SampleProfile(
    id: 'alex',
    label: 'Alex · lose weight',
    description: 'Typical weight-loss user; the full 500 kcal deficit applies.',
    metabolic: const MetabolicProfile(
      ageYears: 34,
      heightCm: 178,
      weightKg: 92,
      sex: Sex.male,
      activityLevel: ActivityLevel.light,
      goal: GoalType.loseWeight,
    ),
    secondaryGoals: const [GoalType.generalFitness],
    targetWeightKg: 84,
    targetDate: DateTime(2027, 6, 1),
  );

  static const maria = SampleProfile(
    id: 'maria',
    label: 'Maria · build muscle',
    description: 'Calorie surplus and high protein target.',
    metabolic: MetabolicProfile(
      ageYears: 27,
      heightCm: 165,
      weightKg: 58,
      sex: Sex.female,
      activityLevel: ActivityLevel.moderate,
      goal: GoalType.buildMuscle,
    ),
    secondaryGoals: [GoalType.improveStrength],
    targetWeightKg: 61,
    trainingExperience: TrainingExperience.intermediate,
    trainingFrequencyPerWeek: 4,
  );

  static const sam = SampleProfile(
    id: 'sam',
    label: 'Sam · maintain, sex not given',
    description: 'Sex unspecified: BMR uses the midpoint and is flagged.',
    metabolic: MetabolicProfile(
      ageYears: 45,
      heightCm: 172,
      weightKg: 70,
      activityLevel: ActivityLevel.sedentary,
      goal: GoalType.maintainWeight,
    ),
  );

  static const jordan = SampleProfile(
    id: 'jordan',
    label: 'Jordan · improve strength',
    description: 'Very active lifter; small surplus.',
    metabolic: MetabolicProfile(
      ageYears: 22,
      heightCm: 183,
      weightKg: 80,
      sex: Sex.male,
      activityLevel: ActivityLevel.veryActive,
      goal: GoalType.improveStrength,
    ),
    secondaryGoals: [GoalType.buildMuscle],
    trainingExperience: TrainingExperience.advanced,
    trainingFrequencyPerWeek: 5,
  );

  static const lee = SampleProfile(
    id: 'lee',
    label: 'Lee · general fitness, no height',
    description:
        'Skipped height in onboarding: BMI, BMR and targets are '
        'unavailable and the UI must explain what is missing.',
    metabolic: MetabolicProfile(
      ageYears: 60,
      weightKg: 68,
      sex: Sex.female,
      activityLevel: ActivityLevel.light,
      goal: GoalType.generalFitness,
    ),
    trainingFrequencyPerWeek: 3,
  );

  static final priya = SampleProfile(
    id: 'priya',
    label: 'Priya · lose weight, small frame',
    description:
        'Low TDEE: the deficit is capped and the 1,200 kcal floor '
        'guardrail applies.',
    metabolic: const MetabolicProfile(
      ageYears: 52,
      heightCm: 152,
      weightKg: 47,
      sex: Sex.female,
      activityLevel: ActivityLevel.sedentary,
      goal: GoalType.loseWeight,
    ),
    targetWeightKg: 45,
    targetDate: DateTime(2027, 3, 1),
  );

  static final List<SampleProfile> all = [alex, maria, sam, jordan, lee, priya];
}
