import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/progress/domain/weekly_report.dart';
import 'package:fitpath/features/workouts/domain/workout_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

// The week of Sunday 1 Nov 2026 to Saturday 7 Nov; the previous week starts
// on 25 Oct.
final wednesday = DateTime(2026, 11, 4, 12);

NutrientTotals eaten(double kcal, {double p = 0, double c = 0, double f = 0}) =>
    NutrientTotals.of([Nutrients(kcal: kcal, proteinG: p, carbsG: c, fatG: f)]);

LoggedSession workout(int id, DateTime start, double load, {int reps = 10}) =>
    LoggedSession(
      id: id,
      startedAt: start,
      completedAt: start.add(const Duration(hours: 1)),
      status: WorkoutStatus.completed,
      exercises: [
        LoggedExercise(
          exerciseId: 1,
          name: 'Squat',
          sets: [LoggedSet(weightKg: load, reps: reps)],
        ),
      ],
    );

void main() {
  test('a week with no data reports gaps, and zero only for training', () {
    final r = WeeklyReportCalculator.build(
      const WeeklyReportInput(),
      wednesday,
    );

    expect(r.week.weekStart, DateTime(2026, 11));
    expect(r.previous.weekStart, DateTime(2026, 10, 25));

    final n = r.week.nutrition;
    expect(n.daysLogged, 0);
    for (final f in [
      n.averageKcal,
      n.averageTargetKcal,
      n.proteinAdherence,
      n.carbsAdherence,
      n.fatAdherence,
    ]) {
      expect(f.isMissing, isTrue);
      expect(f.gap, ReportGap.noFoodLogged);
    }
    expect(r.week.training.sessions, 0);
    expect(r.week.training.volumeKg, 0);
    expect(r.week.training.newPrs, 0);
    expect(r.week.weight.lastKg.gap, ReportGap.noWeightThisWeek);
    expect(r.week.weight.changeKg.gap, ReportGap.noWeightThisWeek);
  });

  group('nutrition', () {
    test('a mid-week target change uses each day\'s own target', () {
      final input = WeeklyReportInput(
        dailyTotals: {
          '2026-11-02': eaten(1800, p: 120),
          '2026-11-03': eaten(2200, p: 150),
          '2026-11-05': eaten(2000, p: 160),
          '2026-11-06': NutrientTotals.zero, // no entries: not logged
          '2026-10-31': eaten(2500), // previous week
        },
        targets: const [
          // Listed out of order on purpose.
          TargetPeriod(effectiveFrom: '2026-11-04', kcal: 1800, proteinG: 160),
          TargetPeriod(effectiveFrom: '2026-10-01', kcal: 2000, proteinG: 150),
        ],
      );
      final r = WeeklyReportCalculator.build(input, wednesday);
      final n = r.week.nutrition;

      expect(n.daysLogged, 3);
      expect(n.averageKcal.value, 2000); // (1800 + 2200 + 2000) / 3
      // Mon and Tue: 2000; Thu: 1800.
      expect(n.averageTargetKcal.value, closeTo(1933.33, 0.01));
      // (120/150 + 150/150 + 160/160) / 3
      expect(n.proteinAdherence.value, closeTo(0.9333, 0.0001));
      // No carb or fat targets on those days.
      expect(n.carbsAdherence.gap, ReportGap.noTarget);
      expect(n.fatAdherence.gap, ReportGap.noTarget);

      expect(r.previous.nutrition.daysLogged, 1);
      expect(r.previous.nutrition.averageKcal.value, 2500);
      expect(n.averageKcal.changeFrom(r.previous.nutrition.averageKcal), -500);
    });

    test('food logged before any target existed', () {
      final r = WeeklyReportCalculator.build(
        WeeklyReportInput(
          dailyTotals: {'2026-11-02': eaten(1800)},
          targets: const [
            TargetPeriod(effectiveFrom: '2026-11-03', kcal: 2000),
          ],
        ),
        wednesday,
      );
      expect(r.week.nutrition.averageKcal.value, 1800);
      expect(r.week.nutrition.averageTargetKcal.gap, ReportGap.noTarget);
      expect(
        r.week.nutrition.averageKcal.changeFrom(
          r.previous.nutrition.averageKcal,
        ),
        isNull,
      );
    });
  });

  test('training: completed sessions, volume and new PRs per week', () {
    final discarded = LoggedSession(
      id: 9,
      startedAt: DateTime(2026, 11, 3),
      status: WorkoutStatus.discarded,
      exercises: const [],
    );
    final input = WeeklyReportInput(
      sessions: [
        workout(1, DateTime(2026, 11, 1, 7), 100), // Sunday: 1000 kg
        workout(2, DateTime(2026, 11, 7, 22), 80, reps: 5), // Saturday: 400
        workout(3, DateTime(2026, 11, 8, 7), 200), // next week
        workout(4, DateTime(2026, 10, 30), 60), // previous week: 600
        discarded,
      ],
      prDates: [DateTime(2026, 11, 7, 22), DateTime(2026, 11, 7, 22)],
    );
    final r = WeeklyReportCalculator.build(input, wednesday);

    expect(r.week.training.sessions, 2);
    expect(r.week.training.volumeKg, 1400);
    expect(r.week.training.newPrs, 2);
    expect(r.previous.training.sessions, 1);
    expect(r.previous.training.volumeKg, 600);
    expect(r.previous.training.newPrs, 0);
  });

  group('weight', () {
    test('change from the last entry before the week to the last in it', () {
      final r = WeeklyReportCalculator.build(
        WeeklyReportInput(
          weights: [
            WeightPoint(DateTime(2026, 11, 6), 79.4),
            WeightPoint(DateTime(2026, 10, 20), 81),
            WeightPoint(DateTime(2026, 10, 31, 23), 80.2),
            WeightPoint(DateTime(2026, 11, 2), 80),
            WeightPoint(DateTime(2026, 11, 9), 79),
          ],
        ),
        wednesday,
      );
      expect(r.week.weight.lastKg.value, 79.4);
      expect(r.week.weight.changeKg.value, closeTo(-0.8, 1e-9));
      expect(r.previous.weight.lastKg.value, 80.2);
      expect(r.previous.weight.changeKg.value, closeTo(-0.8, 1e-9));
    });

    test('the first weight entry has nothing to compare with', () {
      final r = WeeklyReportCalculator.build(
        WeeklyReportInput(weights: [WeightPoint(DateTime(2026, 11, 3), 80)]),
        wednesday,
      );
      expect(r.week.weight.lastKg.value, 80);
      expect(r.week.weight.changeKg.gap, ReportGap.noEarlierWeight);
      expect(r.previous.weight.lastKg.gap, ReportGap.noWeightThisWeek);
    });
  });
}
