// Prints the metabolic estimates for every sample profile, so the calculators
// can be checked by eye before any screen exists.
//
//   dart run tool/sample_estimates.dart
//
// ignore_for_file: avoid_print

import 'package:fitpath/features/profile/domain/metabolic_calculator.dart';
import 'package:fitpath/features/profile/domain/sample_profiles.dart';

void main() {
  for (final profile in SampleProfiles.all) {
    final p = profile.metabolic;
    final r = MetabolicCalculator.estimate(p);

    print('== ${profile.label}');
    print('   ${profile.description}');
    print(
      '   details: age ${p.ageYears ?? '-'}, height ${p.heightCm ?? '-'} cm, '
      'weight ${p.weightKg ?? '-'} kg, sex ${p.sex.name}, '
      'activity ${p.activityLevel?.name ?? '-'}, goal ${p.goal?.name ?? '-'}',
    );

    final bmi = r.bmi.value;
    print(
      '   BMI   ${bmi == null ? 'n/a' : '${bmi.value.toStringAsFixed(1)} (${bmi.category.name})'}',
    );
    print('   BMR   ${_kcal(r.bmr.value)}');
    print('   TDEE  ${_kcal(r.tdee.value)}');

    final target = r.calorieTarget.value;
    if (target != null) {
      final sign = target.adjustmentKcal >= 0 ? '+' : '';
      print(
        '   goal  ${target.kcal} kcal ($sign${target.adjustmentKcal} vs TDEE)'
        '${target.guardrailApplied ? '  [guardrail]' : ''}',
      );
    }
    final m = r.macros.value;
    if (m != null) {
      print(
        '   macros P ${m.proteinG} g · C ${m.carbsG} g · F ${m.fatG} g '
        '(${m.kcal} kcal)',
      );
    }

    final missing = r.calorieTarget.missing;
    if (missing.isNotEmpty) {
      print('   missing: ${missing.map((e) => e.name).join(', ')}');
    }
    final notes = {...r.bmr.notes, ...r.calorieTarget.notes};
    for (final note in notes) {
      print('   note: $note');
    }
    print('');
  }
}

String _kcal(double? v) => v == null ? 'n/a' : '${v.round()} kcal';
