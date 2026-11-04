import '../../../shared/models/enums.dart';

/// The inputs the metabolic calculator needs, in canonical metric units.
///
/// Every field is optional because users can skip profile details during
/// onboarding; the calculator reports which inputs are missing instead of
/// guessing.
class MetabolicProfile {
  const MetabolicProfile({
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.sex = Sex.unspecified,
    this.activityLevel,
    this.goal,
  });

  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final Sex sex;
  final ActivityLevel? activityLevel;
  final GoalType? goal;
}

/// Inputs the calculator can report as missing.
enum MetabolicInput { age, height, weight, activityLevel, goal }
