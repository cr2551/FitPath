import 'dart:math' as math;

import '../../../shared/models/enums.dart';
import 'metabolic_profile.dart';

/// A calculated value plus everything the UI needs to present it honestly:
/// which inputs were missing, and notes explaining limitations.
///
/// Every value produced here is an estimate (spec section 9), never medical
/// advice.
class Estimate<T> {
  const Estimate._(this.value, this.missing, this.notes);

  const Estimate.available(T value, {List<String> notes = const []})
    : this._(value, const {}, notes);

  const Estimate.unavailable(
    Set<MetabolicInput> missing, {
    List<String> notes = const [],
  }) : this._(null, missing, notes);

  /// Null when [missing] is not empty.
  final T? value;
  final Set<MetabolicInput> missing;
  final List<String> notes;

  bool get isAvailable => value != null;
}

enum BmiCategory { underweight, normal, overweight, obese }

class BmiResult {
  const BmiResult(this.value, this.category);

  final double value;
  final BmiCategory category;
}

class CalorieTarget {
  const CalorieTarget({
    required this.kcal,
    required this.adjustmentKcal,
    required this.guardrailApplied,
  });

  /// Suggested daily calories, rounded to the nearest 10 kcal.
  final int kcal;

  /// Difference from TDEE that the goal asked for (negative = deficit).
  final int adjustmentKcal;

  /// True when the target was clamped to a safe floor or maximum deficit.
  final bool guardrailApplied;
}

class MacroTargets {
  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;

  /// Calories implied by the grams (4 / 4 / 9 kcal per gram).
  int get kcal => proteinG * 4 + carbsG * 4 + fatG * 9;
}

/// Everything the Profile "Estimates" card and onboarding step 5 show.
class ProfileEstimates {
  const ProfileEstimates({
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.macros,
  });

  final Estimate<BmiResult> bmi;
  final Estimate<double> bmr;
  final Estimate<double> tdee;
  final Estimate<CalorieTarget> calorieTarget;
  final Estimate<MacroTargets> macros;
}

/// Pure-Dart metabolic estimates. No Flutter or database imports.
///
/// Formulas:
/// * BMI = weight (kg) / height (m)^2, with WHO adult categories.
/// * BMR: Mifflin-St Jeor (1990):
///   `10 x kg + 6.25 x cm - 5 x age + s`, where s = +5 (male), -161 (female).
///   When sex is unspecified the midpoint s = -78 is used and flagged.
/// * TDEE = BMR x activity factor.
/// * Calorie target = TDEE + goal adjustment, with guardrails.
/// * Macros: protein by g/kg for the goal, fat 25 % of calories, carbs the rest.
abstract final class MetabolicCalculator {
  static const double maleConstant = 5;
  static const double femaleConstant = -161;
  static const double unspecifiedConstant = (maleConstant + femaleConstant) / 2;

  /// Never suggest fewer calories than this (kcal/day).
  static const int minimumKcalFemale = 1200;
  static const int minimumKcalMale = 1500;
  static const int minimumKcalUnspecified = 1200;

  /// A weight-loss deficit never exceeds this share of TDEE.
  static const double maxDeficitShare = 0.25;

  static const double fatShareOfCalories = 0.25;

  static const String bmiNote =
      'BMI is a screening measure; it does not describe body composition.';
  static const String sexUnspecifiedNote =
      'Sex was not provided, so a midpoint of the male and female equations '
      'was used. This estimate is less precise.';
  static const String guardrailNote =
      'The suggestion was limited to stay within a safe, moderate range.';

  static double activityFactor(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };

  /// Daily calorie change applied to TDEE for each goal, before guardrails.
  static int goalAdjustmentKcal(GoalType goal) => switch (goal) {
    GoalType.loseWeight => -500,
    GoalType.buildMuscle => 250,
    GoalType.improveStrength => 150,
    GoalType.maintainWeight => 0,
    GoalType.generalFitness => 0,
  };

  /// Protein grams per kg of body weight for each goal.
  static double proteinPerKg(GoalType goal) => switch (goal) {
    GoalType.loseWeight => 1.8,
    GoalType.buildMuscle => 2.0,
    GoalType.improveStrength => 1.8,
    GoalType.maintainWeight => 1.6,
    GoalType.generalFitness => 1.4,
  };

  static BmiCategory bmiCategory(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25) return BmiCategory.normal;
    if (bmi < 30) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  static Estimate<BmiResult> bmi(MetabolicProfile p) {
    final missing = {
      if (p.heightCm == null) MetabolicInput.height,
      if (p.weightKg == null) MetabolicInput.weight,
    };
    if (missing.isNotEmpty) {
      return Estimate.unavailable(missing, notes: const [bmiNote]);
    }
    final meters = p.heightCm! / 100;
    final value = p.weightKg! / (meters * meters);
    return Estimate.available(
      BmiResult(value, bmiCategory(value)),
      notes: const [bmiNote],
    );
  }

  static Estimate<double> bmr(MetabolicProfile p) {
    final missing = {
      if (p.ageYears == null) MetabolicInput.age,
      if (p.heightCm == null) MetabolicInput.height,
      if (p.weightKg == null) MetabolicInput.weight,
    };
    if (missing.isNotEmpty) return Estimate.unavailable(missing);

    final s = switch (p.sex) {
      Sex.male => maleConstant,
      Sex.female => femaleConstant,
      Sex.unspecified => unspecifiedConstant,
    };
    final value = 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.ageYears! + s;
    return Estimate.available(
      value,
      notes: [if (p.sex == Sex.unspecified) sexUnspecifiedNote],
    );
  }

  static Estimate<double> tdee(MetabolicProfile p) {
    final base = bmr(p);
    final missing = {
      ...base.missing,
      if (p.activityLevel == null) MetabolicInput.activityLevel,
    };
    if (missing.isNotEmpty) {
      return Estimate.unavailable(missing, notes: base.notes);
    }
    return Estimate.available(
      base.value! * activityFactor(p.activityLevel!),
      notes: base.notes,
    );
  }

  static int minimumKcal(Sex sex) => switch (sex) {
    Sex.male => minimumKcalMale,
    Sex.female => minimumKcalFemale,
    Sex.unspecified => minimumKcalUnspecified,
  };

  static Estimate<CalorieTarget> calorieTarget(MetabolicProfile p) {
    final energy = tdee(p);
    final missing = {
      ...energy.missing,
      if (p.goal == null) MetabolicInput.goal,
    };
    if (missing.isNotEmpty) {
      return Estimate.unavailable(missing, notes: energy.notes);
    }

    final tdeeKcal = energy.value!;
    var adjustment = goalAdjustmentKcal(p.goal!).toDouble();
    var guardrail = false;

    final maxDeficit = tdeeKcal * maxDeficitShare;
    if (adjustment < -maxDeficit) {
      adjustment = -maxDeficit;
      guardrail = true;
    }

    var target = tdeeKcal + adjustment;
    final floor = minimumKcal(p.sex).toDouble();
    if (target < floor) {
      // Never push the target above maintenance just to reach the floor.
      target = math.min(floor, tdeeKcal);
      guardrail = true;
    }

    final rounded = _roundTo10(target);
    return Estimate.available(
      CalorieTarget(
        kcal: rounded,
        adjustmentKcal: rounded - _roundTo10(tdeeKcal),
        guardrailApplied: guardrail,
      ),
      notes: [...energy.notes, if (guardrail) guardrailNote],
    );
  }

  /// Suggested macros for [kcal] calories. Protein is capped so that protein
  /// and fat never exceed the calorie budget; carbs take the remainder.
  static MacroTargets macrosFor({
    required int kcal,
    required double weightKg,
    required GoalType goal,
  }) {
    final fatKcal = kcal * fatShareOfCalories;
    var proteinG = weightKg * proteinPerKg(goal);
    final maxProteinG = (kcal - fatKcal) / 4;
    proteinG = math.min(proteinG, maxProteinG);
    final carbsKcal = math.max(0, kcal - fatKcal - proteinG * 4);
    return MacroTargets(
      proteinG: proteinG.round(),
      carbsG: (carbsKcal / 4).round(),
      fatG: (fatKcal / 9).round(),
    );
  }

  static Estimate<MacroTargets> macros(MetabolicProfile p) {
    final target = calorieTarget(p);
    if (!target.isAvailable) {
      return Estimate.unavailable(target.missing, notes: target.notes);
    }
    return Estimate.available(
      macrosFor(kcal: target.value!.kcal, weightKg: p.weightKg!, goal: p.goal!),
      notes: target.notes,
    );
  }

  static ProfileEstimates estimate(MetabolicProfile p) => ProfileEstimates(
    bmi: bmi(p),
    bmr: bmr(p),
    tdee: tdee(p),
    calorieTarget: calorieTarget(p),
    macros: macros(p),
  );

  static int _roundTo10(double kcal) => (kcal / 10).round() * 10;
}
