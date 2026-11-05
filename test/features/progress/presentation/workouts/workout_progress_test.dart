import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/progress/presentation/weight/weight_chart.dart';
import 'package:fitpath/features/progress/presentation/workouts/workout_progress_layout.dart';
import 'package:fitpath/features/progress/presentation/workouts/workout_progress_view.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

/// Three completed sessions in the last two weeks before [now]:
/// bench 60 → 62.5 → 65 kg x 5 (one set each) and pull-ups 8, 10 reps.
Future<List<SessionDetail>> _seed(AppDatabase db, DateTime now) async {
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
  Future<void> session(int daysAgo, double kg, int? pullReps) async {
    final at = Dates.addDays(now, -daysAgo);
    var clock = at;
    final repo = WorkoutRepository(db.workoutDao, clock: () => clock);
    final s = await repo.startSession();
    final b = await repo.addExercise(s, bench);
    final set = await repo.addSet(b, reps: 5, weightKg: kg);
    await repo.updateSet(set, completed: const Value(true));
    if (pullReps != null) {
      final p = await repo.addExercise(s, pullUp);
      final ps = await repo.addSet(p, reps: pullReps);
      await repo.updateSet(ps, completed: const Value(true));
    }
    clock = at.add(const Duration(hours: 1));
    await repo.completeSession(s);
  }

  await session(10, 60, 8);
  await session(5, 62.5, null);
  await session(1, 65, 10);
  return WorkoutRepository(db.workoutDao).watchCompletedSessions().first;
}

void main() {
  final now = DateTime(2026, 11, 4, 12);

  test('totals, weekly counts and exercise metrics', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final sessions = await _seed(db, now);

    final d = workoutProgressData(
      sessions,
      RangePreset.days30,
      now,
      UnitSystem.metric,
    )!;
    expect(d.totals.map((s) => s.value), ['3', '5', '938']);
    expect(d.weekCounts.fold(0, (a, b) => a + b), 3);
    expect(d.weekCounts.last, 1); // 3 Nov, this week
    expect(d.exercises.map((e) => e.name), ['Bench press', 'Pull-up']);
    expect(d.selected, d.exercises.first.id);
    expect(d.points.map((p) => p.value), [60, 62.5, 65]);
    expect(d.unit, 'kg');

    final volume = workoutProgressData(
      sessions,
      RangePreset.days30,
      now,
      UnitSystem.metric,
      metric: ExerciseMetric.volume,
    )!;
    expect(volume.points.map((p) => p.value), [300, 312.5, 325]);

    // Bodyweight: always reps.
    final pull = workoutProgressData(
      sessions,
      RangePreset.days30,
      now,
      UnitSystem.metric,
      exerciseId: d.exercises.last.id,
    )!;
    expect(pull.isBodyweight, isTrue);
    expect(pull.metric, ExerciseMetric.reps);
    expect(pull.points.map((p) => p.value), [8, 10]);
    expect(pull.unit, 'reps');
  });

  test('imperial and an empty range', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final sessions = await _seed(db, now);
    final d = workoutProgressData(
      sessions,
      RangePreset.days30,
      now,
      UnitSystem.imperial,
    )!;
    expect(d.points.last.value, closeTo(143.3, 0.1));
    expect(
      workoutProgressData(const [], RangePreset.days7, now, UnitSystem.metric),
      isNull,
    );
  });

  testWidgets('switches exercise and metric', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() => _seed(db, DateTime.now()));
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(children: const [WorkoutProgressView()]),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Sessions per week'), findsOneWidget);
    expect(find.byType(WeightChart), findsOneWidget);
    expect(find.text('BEST LOAD'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<ExerciseMetric>),
        matching: find.text('VOLUME'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WeightChart), findsOneWidget);

    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pull-up').last);
    await tester.pumpAndSettle();
    expect(find.text('BEST LOAD'), findsNothing);
    expect(find.text('Bodyweight exercise: best set by reps.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('empty range', (tester) async {
    final db = createTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(children: const [WorkoutProgressView()]),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('No completed workouts in this range.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
