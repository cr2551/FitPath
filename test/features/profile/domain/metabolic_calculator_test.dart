import 'package:fitpath/features/profile/domain/metabolic_calculator.dart';
import 'package:fitpath/features/profile/domain/metabolic_profile.dart';
import 'package:fitpath/features/profile/domain/sample_profiles.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expected values were computed independently (by hand / in a spreadsheet)
/// from the formulas documented on [MetabolicCalculator].
class _Expected {
  const _Expected({
    required this.bmi,
    required this.category,
    required this.bmr,
    required this.tdee,
    required this.kcal,
    required this.adjustment,
    required this.guardrail,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double bmi;
  final BmiCategory category;
  final double bmr;
  final double tdee;
  final int kcal;
  final int adjustment;
  final bool guardrail;
  final int protein;
  final int carbs;
  final int fat;
}

void main() {
  group('sample profiles produce the documented estimates', () {
    final expected = <SampleProfile, _Expected>{
      SampleProfiles.alex: const _Expected(
        bmi: 29.04,
        category: BmiCategory.overweight,
        bmr: 1867.5,
        tdee: 2567.8125,
        kcal: 2070,
        adjustment: -500,
        guardrail: false,
        protein: 166,
        carbs: 223,
        fat: 58,
      ),
      SampleProfiles.maria: const _Expected(
        bmi: 21.30,
        category: BmiCategory.normal,
        bmr: 1315.25,
        tdee: 2038.6375,
        kcal: 2290,
        adjustment: 250,
        guardrail: false,
        protein: 116,
        carbs: 313,
        fat: 64,
      ),
      SampleProfiles.sam: const _Expected(
        bmi: 23.66,
        category: BmiCategory.normal,
        bmr: 1472,
        tdee: 1766.4,
        kcal: 1770,
        adjustment: 0,
        guardrail: false,
        protein: 112,
        carbs: 220,
        fat: 49,
      ),
      SampleProfiles.jordan: const _Expected(
        bmi: 23.89,
        category: BmiCategory.normal,
        bmr: 1838.75,
        tdee: 3493.625,
        kcal: 3640,
        adjustment: 150,
        guardrail: false,
        protein: 144,
        carbs: 539,
        fat: 101,
      ),
      SampleProfiles.priya: const _Expected(
        bmi: 20.34,
        category: BmiCategory.normal,
        bmr: 999,
        tdee: 1198.8,
        kcal: 1200,
        adjustment: 0,
        guardrail: true,
        protein: 85,
        carbs: 140,
        fat: 33,
      ),
    };

    expected.forEach((profile, e) {
      test(profile.label, () {
        final r = MetabolicCalculator.estimate(profile.metabolic);

        expect(r.bmi.value!.value, closeTo(e.bmi, 0.01));
        expect(r.bmi.value!.category, e.category);
        expect(r.bmr.value, closeTo(e.bmr, 1e-9));
        expect(r.tdee.value, closeTo(e.tdee, 1e-9));
        expect(r.calorieTarget.value!.kcal, e.kcal);
        expect(r.calorieTarget.value!.adjustmentKcal, e.adjustment);
        expect(r.calorieTarget.value!.guardrailApplied, e.guardrail);
        expect(r.macros.value!.proteinG, e.protein);
        expect(r.macros.value!.carbsG, e.carbs);
        expect(r.macros.value!.fatG, e.fat);
      });
    });
  });

  group('missing inputs', () {
    test('Lee (no height) gets no BMI, BMR, TDEE or targets', () {
      final r = MetabolicCalculator.estimate(SampleProfiles.lee.metabolic);

      expect(r.bmi.isAvailable, isFalse);
      expect(r.bmi.missing, {MetabolicInput.height});
      expect(r.bmr.missing, {MetabolicInput.height});
      expect(r.tdee.missing, {MetabolicInput.height});
      expect(r.calorieTarget.missing, {MetabolicInput.height});
      expect(r.macros.isAvailable, isFalse);
    });

    test('an empty profile reports every missing input', () {
      final r = MetabolicCalculator.calorieTarget(const MetabolicProfile());

      expect(r.missing, {
        MetabolicInput.age,
        MetabolicInput.height,
        MetabolicInput.weight,
        MetabolicInput.activityLevel,
        MetabolicInput.goal,
      });
    });

    test('BMR is available without an activity level or goal', () {
      const p = MetabolicProfile(ageYears: 30, heightCm: 170, weightKg: 70);

      expect(MetabolicCalculator.bmr(p).isAvailable, isTrue);
      expect(MetabolicCalculator.tdee(p).missing, {
        MetabolicInput.activityLevel,
      });
    });
  });

  group('notes', () {
    test('unspecified sex is flagged as less precise', () {
      final r = MetabolicCalculator.bmr(SampleProfiles.sam.metabolic);

      expect(r.notes, contains(MetabolicCalculator.sexUnspecifiedNote));
    });

    test('known sex has no precision note', () {
      final r = MetabolicCalculator.bmr(SampleProfiles.alex.metabolic);

      expect(r.notes, isEmpty);
    });

    test('guardrail note is attached when a guardrail applies', () {
      final r = MetabolicCalculator.calorieTarget(
        SampleProfiles.priya.metabolic,
      );

      expect(r.notes, contains(MetabolicCalculator.guardrailNote));
    });

    test('BMI always carries the screening-measure note', () {
      final r = MetabolicCalculator.bmi(SampleProfiles.alex.metabolic);

      expect(r.notes, contains(MetabolicCalculator.bmiNote));
    });
  });

  group('BMI categories (WHO)', () {
    test('boundaries', () {
      expect(MetabolicCalculator.bmiCategory(18.49), BmiCategory.underweight);
      expect(MetabolicCalculator.bmiCategory(18.5), BmiCategory.normal);
      expect(MetabolicCalculator.bmiCategory(24.99), BmiCategory.normal);
      expect(MetabolicCalculator.bmiCategory(25), BmiCategory.overweight);
      expect(MetabolicCalculator.bmiCategory(29.99), BmiCategory.overweight);
      expect(MetabolicCalculator.bmiCategory(30), BmiCategory.obese);
    });
  });

  group('activity factors', () {
    test('increase with activity level', () {
      final factors = ActivityLevel.values
          .map(MetabolicCalculator.activityFactor)
          .toList();

      expect(factors, [1.2, 1.375, 1.55, 1.725, 1.9]);
    });
  });

  group('guardrails', () {
    test('weight-loss deficit is capped at 25% of TDEE', () {
      // BMR 1,500.25 -> TDEE 1,800.3; 25% = 450, smaller than the default 500.
      // 1,800.3 - 450.1 = 1,350.2 stays above the 1,200 floor.
      const p = MetabolicProfile(
        ageYears: 34,
        heightCm: 165,
        weightKg: 80,
        sex: Sex.female,
        activityLevel: ActivityLevel.sedentary,
        goal: GoalType.loseWeight,
      );
      final target = MetabolicCalculator.calorieTarget(p).value!;

      expect(target.kcal, 1350);
      expect(target.adjustmentKcal, -450);
      expect(target.guardrailApplied, isTrue);
    });

    test('target never drops below the floor unless TDEE itself is lower', () {
      for (final sex in Sex.values) {
        final p = MetabolicProfile(
          ageYears: 30,
          heightCm: 175,
          weightKg: 75,
          sex: sex,
          activityLevel: ActivityLevel.sedentary,
          goal: GoalType.loseWeight,
        );
        final target = MetabolicCalculator.calorieTarget(p).value!;

        expect(
          target.kcal,
          greaterThanOrEqualTo(MetabolicCalculator.minimumKcal(sex)),
        );
      }
    });

    test('a surplus goal is never reduced', () {
      final t = MetabolicCalculator.calorieTarget(
        SampleProfiles.maria.metabolic,
      ).value!;

      expect(t.adjustmentKcal, 250);
      expect(t.guardrailApplied, isFalse);
    });
  });

  group('macros', () {
    test('grams roughly add back up to the calorie target', () {
      for (final profile in SampleProfiles.all) {
        final r = MetabolicCalculator.estimate(profile.metabolic);
        if (!r.macros.isAvailable) continue;

        expect(
          r.macros.value!.kcal,
          closeTo(r.calorieTarget.value!.kcal, 15),
          reason: profile.label,
        );
      }
    });

    test('protein is capped so carbs never go negative', () {
      final m = MetabolicCalculator.macrosFor(
        kcal: 1200,
        weightKg: 200,
        goal: GoalType.buildMuscle,
      );

      expect(m.carbsG, 0);
      expect(m.proteinG, 225); // (1200 - 300) / 4
      expect(m.fatG, 33);
    });
  });
}
