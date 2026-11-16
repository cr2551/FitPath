import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/presentation/cards/personal_records_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/personal_records_card_view.dart';
import 'package:fitpath/features/dashboard/presentation/cards/streak_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/streak_card_view.dart';
import 'package:fitpath/features/dashboard/presentation/cards/weekly_report_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/weekly_report_card_view.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/reports/application/weekly_report_providers.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

/// Bench 60 kg x 5 and pull-ups x 8 on 3 Nov; bench 65 kg x 5 and
/// pull-ups x 10 on 10 Nov. Newest first.
Future<List<SessionDetail>> _sessions() async {
  final db = createTestDatabase();
  addTearDown(db.close);
  final bench = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
  );
  final pullUp = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(
      name: 'Pull-up',
      muscleGroup: 'back',
      isBodyweight: const Value(true),
    ),
  );
  Future<void> session(DateTime at, double kg, int pullReps) async {
    var clock = at;
    final repo = WorkoutRepository(db.workoutDao, clock: () => clock);
    final s = await repo.startSession();
    final b = await repo.addExercise(s, bench);
    final bs = await repo.addSet(b, reps: 5, weightKg: kg);
    await repo.updateSet(bs, completed: const Value(true));
    final p = await repo.addExercise(s, pullUp);
    final ps = await repo.addSet(p, reps: pullReps);
    await repo.updateSet(ps, completed: const Value(true));
    clock = at.add(const Duration(hours: 1));
    await repo.completeSession(s);
  }

  await session(DateTime(2026, 11, 3, 18), 60, 8);
  await session(DateTime(2026, 11, 10, 18), 65, 10);
  return WorkoutRepository(db.workoutDao).watchCompletedSessions().first;
}

NutrientTotals _kcal(double kcal) => NutrientTotals(
  kcal: kcal,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  entryCount: 1,
  entriesMissingKcal: 0,
  entriesMissingMacros: 0,
);

void main() {
  // Wednesday; last full week is 8-14 Nov.
  final now = DateTime(2026, 11, 18, 12);

  test(
    'personal records: newest first, one per exercise and session',
    () async {
      final sessions = await _sessions();
      final rows = latestPrRows(sessions, UnitSystem.metric);
      expect(rows.map((r) => (r.exercise, r.record, r.date)), [
        ('Bench press', 'Heaviest load · 65 kg', '10 Nov'),
        ('Pull-up', 'Most reps · 10', '10 Nov'),
      ]);
      expect(latestPrRows(sessions, UnitSystem.metric, limit: 1), hasLength(1));
      // The first session has nothing to beat.
      expect(latestPrRows([sessions.last], UnitSystem.metric), isEmpty);
    },
  );

  test('streak: current, longest and this week', () async {
    final s = streakCardData(await _sessions(), now)!;
    expect((s.current, s.longest, s.thisWeekDone), (2, 2, false));
    expect(s.thisWeek, 'Work out this week to keep it going.');
    expect(streakCardData(const [], now), isNull);
  });

  test("last week's report vs the week before", () async {
    final sources = ReportSources(
      dailyTotals: {
        '2026-11-03': _kcal(1800),
        '2026-11-09': _kcal(2000),
        '2026-11-10': _kcal(2200),
      },
      targets: const [],
      sessions: await _sessions(),
      weights: [
        WeightEntry(id: 2, weightKg: 79.4, recordedAt: DateTime(2026, 11, 13)),
        WeightEntry(id: 1, weightKg: 80, recordedAt: DateTime(2026, 11, 2)),
      ],
    );
    final d = weeklyReportCardData(sources, now, UnitSystem.metric);
    expect(d.week, '8 – 14 Nov 2026');
    expect(d.stats.map((s) => (s.value, s.unit)), [
      ('2,100', 'kcal'),
      ('1', null),
      ('−0.6', 'kg'),
    ]);
    expect(
      d.previous,
      'Week before: 1,800 kcal · 1 workout · no weight change',
    );

    final empty = weeklyReportCardData(
      sources,
      DateTime(2026, 10, 28),
      UnitSystem.metric,
    );
    expect(empty.isEmpty, isTrue);
  });

  testWidgets('the views render and report taps', (tester) async {
    int? exercise;
    var streakTaps = 0, reportTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              PersonalRecordsCardView(
                rows: const [
                  PrCardRow(
                    exerciseId: 7,
                    exercise: 'Bench press',
                    record: 'Heaviest load · 65 kg',
                    date: '10 Nov',
                  ),
                ],
                onExercise: (id) => exercise = id,
              ),
              StreakCardView(
                data: const StreakCardData(
                  current: 2,
                  longest: 3,
                  thisWeek: 'This week counts already.',
                  thisWeekDone: true,
                ),
                onTap: () => streakTaps++,
              ),
              WeeklyReportCardView(
                data: const WeeklyReportCardData(
                  week: '8 – 14 Nov 2026',
                  stats: [],
                  previous: null,
                ),
                onTap: () => reportTaps++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bench press'));
    expect(exercise, 7);
    await tester.tap(find.text('This week counts already.'));
    expect(streakTaps, 1);
    await tester.tap(find.text('Nothing logged last week.'));
    expect(reportTaps, 1);
  });
}
