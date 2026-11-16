import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/reports/application/weekly_report_providers.dart';
import 'package:fitpath/features/reports/presentation/weekly_report_screen.dart';
import 'package:fitpath/features/reports/presentation/weekly_report_view.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

NutrientTotals _totals(double kcal, double protein) => NutrientTotals(
  kcal: kcal,
  proteinG: protein,
  carbsG: 0,
  fatG: 0,
  entryCount: 1,
  entriesMissingKcal: 0,
  entriesMissingMacros: 0,
);

/// Bench press 60 kg x 5 on 3 Nov and 65 kg x 5 on 10 Nov.
Future<List<SessionDetail>> _sessions(AppDatabase db) async {
  final bench = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
  );
  Future<void> session(DateTime at, double kg) async {
    var clock = at;
    final repo = WorkoutRepository(db.workoutDao, clock: () => clock);
    final s = await repo.startSession();
    final e = await repo.addExercise(s, bench);
    final set = await repo.addSet(e, reps: 5, weightKg: kg);
    await repo.updateSet(set, completed: const Value(true));
    clock = at.add(const Duration(hours: 1));
    await repo.completeSession(s);
  }

  await session(DateTime(2026, 11, 3, 18), 60);
  await session(DateTime(2026, 11, 10, 18), 65);
  return WorkoutRepository(db.workoutDao).watchCompletedSessions().first;
}

void main() {
  // Wednesday; last full week is 8-14 Nov, the one before 1-7 Nov.
  final now = DateTime(2026, 11, 18, 12);

  Future<ReportSources> sources() async {
    final db = createTestDatabase();
    addTearDown(db.close);
    return ReportSources(
      dailyTotals: {
        '2026-11-03': _totals(1800, 135),
        '2026-11-09': _totals(2000, 150),
        '2026-11-10': _totals(2200, 120),
      },
      targets: [
        NutritionTarget(
          id: 1,
          calories: 2100,
          proteinG: 150,
          effectiveFrom: '2026-11-01',
          source: TargetSource.user,
          createdAt: DateTime(2026, 11, 1),
        ),
      ],
      sessions: await _sessions(db),
      weights: [
        WeightEntry(id: 2, weightKg: 79.4, recordedAt: DateTime(2026, 11, 13)),
        WeightEntry(id: 1, weightKg: 80, recordedAt: DateTime(2026, 11, 2)),
      ],
    );
  }

  Map<String, ReportFigure> byLabel(List<ReportFigure> f) => {
    for (final x in f) x.label: x,
  };

  test(
    'figures match the aggregation and compare with the week before',
    () async {
      final d = weeklyReportViewData(
        await sources(),
        DateTime(2026, 11, 8),
        now,
        UnitSystem.metric,
      );
      expect(d.weekLabel, '8 – 14 Nov 2026');
      expect(d.canGoNext, isTrue);
      expect(d.isEmpty, isFalse);

      final n = byLabel(d.nutrition);
      expect(n['Average intake']!.value, '2,100');
      expect(n['Average intake']!.previous, 'Last week 1,800 kcal (+300)');
      expect(n['Average target']!.value, '2,100');
      expect(n['Days logged']!.value, '2 of 7');
      expect(n['Days logged']!.previous, 'Last week 1 of 7');
      expect(n['Protein vs target']!.value, '90%');
      expect(n['Protein vs target']!.previous, 'Last week 90% (0 pts)');
      // No carb target: says so instead of 0.
      expect(n['Carbs vs target']!.value, 'No target set');

      final t = byLabel(d.training);
      expect(t['Workouts']!.value, '1');
      expect(t['Volume']!.value, '325');
      expect(t['Volume']!.previous, 'Last week 300 kg (+25)');
      expect(t['New personal records']!.value, '3');
      expect(d.prs.map((p) => p.record), [
        'Heaviest load · 65 kg',
        'Best set volume · 325 kg',
        'Estimated 1RM · 75.8 kg',
      ]);
      expect(d.prs.first.exercise, 'Bench press');
      expect(d.prs.first.date, 'Tue 10 Nov');

      final w = byLabel(d.weight);
      expect(w['Last weigh-in']!.value, '79.4');
      expect(w['Last weigh-in']!.previous, 'Last week 80 kg (−0.6)');
      expect(w['Change over the week']!.value, '−0.6');
      expect(
        w['Change over the week']!.previous,
        'Last week: no earlier weight',
      );
    },
  );

  test('the current week cannot go forward; an empty week is empty', () async {
    final s = await sources();
    final current = weeklyReportViewData(s, now, now, UnitSystem.metric);
    expect(current.canGoNext, isFalse);
    expect(current.weekLabel, '15 – 21 Nov 2026 (so far)');

    final empty = weeklyReportViewData(
      s,
      DateTime(2026, 10, 20),
      now,
      UnitSystem.metric,
    );
    expect(empty.isEmpty, isTrue);
  });

  test('week labels across months and years', () {
    expect(weekLabel(DateTime(2026, 12, 1), now), '29 Nov – 5 Dec 2026');
    expect(weekLabel(DateTime(2025, 12, 30), now), '28 Dec 2025 – 3 Jan 2026');
  });

  testWidgets('an empty history shows the empty state and moves by week', (
    tester,
  ) async {
    final db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: WeeklyReportScreen(weekStart: DateTime(2026, 11, 10)),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('8 – 14 Nov 2026'), findsOneWidget);
    expect(find.textContaining('Nothing logged this week'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pump();
    expect(find.text('1 – 7 Nov 2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
