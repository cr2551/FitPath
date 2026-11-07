import 'package:fitpath/features/profile/domain/metabolic_profile.dart';
import 'package:fitpath/features/profile/domain/weight_projection.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

// BMR = 10 × 90 + 6.25 × 180 − 5 × 30 + 5 = 1880; TDEE = 1880 × 1.55 = 2914.
const profile = MetabolicProfile(
  ageYears: 30,
  heightCm: 180,
  weightKg: 90,
  sex: Sex.male,
  activityLevel: ActivityLevel.moderate,
);

final start = DateTime(2026, 11, 7, 15, 30);

WeightProjection run(int intake, {double? target, MetabolicProfile? p}) =>
    WeightProjectionCalculator.project(
      profile: p ?? profile,
      intakeKcal: intake,
      start: start,
      targetWeightKg: target,
    ).value!;

void main() {
  test('matches a hand-computed first week', () {
    final p = run(2414); // a 500 kcal deficit on day 1
    expect(p.startTdeeKcal, closeTo(2914, 1e-9));
    expect(p.days.first.date, DateTime(2026, 11, 7));
    expect(p.days.first.weightKg, 90);

    // Day 1: 90 − 500 / 7700.
    expect(p.days[1].weightKg, closeTo(89.935065, 1e-6));
    // Each day TDEE falls by 15.5 kcal per kg lost, so the deficit shrinks:
    // d(n) = 500 × (1 − 15.5 / 7700)^n; after 7 days 90 − Σd / 7700.
    expect(p.days[7].weightKg, closeTo(89.548190, 1e-6));
    expect(p.days[7].date, DateTime(2026, 11, 14));
    expect(p.weeklyPaceKg, closeTo(-0.451810, 1e-6));
    expect(p.fastPace, isFalse);
    expect(p.belowCalorieFloor, isFalse);
  });

  test('maintenance intake stays flat', () {
    final p = run(2914);
    expect(p.days, hasLength(WeightProjectionCalculator.horizonDays + 1));
    expect(p.finalWeightKg, closeTo(90, 1e-9));
    expect(p.weeklyPaceKg, closeTo(0, 1e-9));
  });

  test('the projection slows near the target', () {
    final p = run(2414, target: 80);
    final firstDayLoss = p.days[0].weightKg - p.days[1].weightKg;
    final n = p.days.length;
    final lastDayLoss = p.days[n - 2].weightKg - p.days[n - 1].weightKg;
    expect(lastDayLoss, lessThan(firstDayLoss * 0.9));

    // A straight 500 kcal/day line would take 10 × 7700 / 500 = 154 days.
    expect(p.targetReachedOn, isNotNull);
    expect(p.finalWeightKg, lessThanOrEqualTo(80));
    expect(p.days[n - 2].weightKg, greaterThan(80));
    expect(n - 1, greaterThan(154));
    expect(p.targetReachedOn, p.days.last.date);
  });

  test('a target below the balance weight is not reached in a year', () {
    // TDEE equals 2414 kcal at about 57.7 kg.
    final result = WeightProjectionCalculator.project(
      profile: profile,
      intakeKcal: 2414,
      start: start,
      targetWeightKg: 50,
    );
    final p = result.value!;
    expect(p.targetReachedOn, isNull);
    expect(p.days, hasLength(366));
    expect(p.days.last.date, DateTime(2027, 11, 7));
    expect(p.finalWeightKg, greaterThan(57.7));
    expect(result.notes, contains(WeightProjectionCalculator.notReachedNote));
  });

  test('gaining toward a higher target', () {
    final p = run(3214, target: 91);
    expect(p.weeklyPaceKg, greaterThan(0));
    expect(p.targetReachedOn, isNotNull);
    expect(p.finalWeightKg, greaterThanOrEqualTo(91));
  });

  test('a target already reached ends on day 0', () {
    final p = run(2414, target: 90);
    expect(p.targetReachedOn, DateTime(2026, 11, 7));
    expect(p.days, hasLength(1));
    expect(p.weeklyPaceKg, 0);
  });

  test('guardrails: calorie floor and a fast pace', () {
    final result = WeightProjectionCalculator.project(
      profile: profile,
      intakeKcal: 1400,
      start: start,
    );
    final p = result.value!;
    // About 1514 kcal/day below TDEE: over 1.3 kg in the first week, more
    // than 1% of 90 kg.
    expect(p.weeklyPaceKg, lessThan(-0.9));
    expect(p.fastPace, isTrue);
    expect(p.belowCalorieFloor, isTrue); // 1500 kcal for men
    expect(result.notes, [
      WeightProjectionCalculator.estimateNote,
      WeightProjectionCalculator.fastPaceNote,
      WeightProjectionCalculator.belowFloorNote,
    ]);
  });

  test('missing inputs make it unavailable', () {
    final result = WeightProjectionCalculator.project(
      profile: const MetabolicProfile(heightCm: 170, sex: Sex.female),
      intakeKcal: 2000,
      start: start,
    );
    expect(result.isAvailable, isFalse);
    expect(result.missing, {
      MetabolicInput.age,
      MetabolicInput.weight,
      MetabolicInput.activityLevel,
    });
  });

  test('unspecified sex carries the precision note', () {
    final result = WeightProjectionCalculator.project(
      profile: const MetabolicProfile(
        ageYears: 30,
        heightCm: 170,
        weightKg: 70,
        activityLevel: ActivityLevel.light,
      ),
      intakeKcal: 2000,
      start: start,
    );
    expect(result.notes, hasLength(2));
    expect(result.notes.first, WeightProjectionCalculator.estimateNote);
  });
}
