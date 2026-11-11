import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/dashboard/presentation/cards/activity_overview_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/recent_sessions_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/strength_progression_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/workout_summary_card.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

/// Completed sessions in [db], newest first:
/// - Tue 3 Nov 18:00, "Push": bench 2 x 5 x 102.5 kg, dips 12 reps
/// - Mon 2 Nov 18:00: bench 1 x 5 x 100 kg, dips 10 reps
/// - Mon 26 Oct (previous week): bench 1 x 5 x 95 kg
Future<List<SessionDetail>> _seed(AppDatabase db) async {
  final bench = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
  );
  final dips = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(
      name: 'Dips',
      muscleGroup: 'chest',
      isBodyweight: const Value(true),
    ),
  );
  Future<void> session(
    DateTime at,
    String? name,
    List<(int, int, double?, int)> work,
  ) async {
    var now = at;
    final repo = WorkoutRepository(db.workoutDao, clock: () => now);
    final s = await repo.startSession(name: name);
    final entries = <int, int>{};
    for (final (exercise, reps, kg, count) in work) {
      final e = entries[exercise] ??= await repo.addExercise(s, exercise);
      for (var i = 0; i < count; i++) {
        final set = await repo.addSet(e, reps: reps, weightKg: kg);
        await repo.updateSet(set, completed: const Value(true));
      }
    }
    now = at.add(const Duration(minutes: 45));
    await repo.completeSession(s);
  }

  await session(DateTime(2026, 10, 26, 18), null, [(bench, 5, 95, 1)]);
  await session(DateTime(2026, 11, 2, 18), null, [
    (bench, 5, 100, 1),
    (dips, 10, null, 1),
  ]);
  await session(DateTime(2026, 11, 3, 18), 'Push', [
    (bench, 5, 102.5, 2),
    (dips, 12, null, 1),
  ]);
  return WorkoutRepository(db.workoutDao).watchCompletedSessions().first;
}

NutrientTotals _food() => const NutrientTotals(
  kcal: 500,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  entryCount: 1,
  entriesMissingKcal: 0,
  entriesMissingMacros: 0,
);

void main() {
  late AppDatabase db;
  late List<SessionDetail> sessions;
  final now = DateTime(2026, 11, 4, 12); // a Wednesday

  setUp(() async {
    db = createTestDatabase();
    sessions = await _seed(db);
  });
  tearDown(() => db.close());

  test('this week: sessions, sets, volume and trained days', () {
    final d = workoutSummaryData(sessions, now, UnitSystem.metric, 4);
    expect(d.headline, '2 of 4 sessions');
    expect(d.stats.map((s) => s.value), ['2', '5', '1,525']);
    expect(d.trained, [false, true, true, false, false, false, false]);
    expect(d.todayIndex, 3);
    expect(d.dayLetters.first, 'S');
    expect(
      workoutSummaryData(sessions, now, UnitSystem.metric, null).headline,
      '2 sessions',
    );
  });

  test('recent sessions: newest three', () {
    final rows = recentSessionRows(sessions);
    expect(rows.map((r) => r.title), ['Push', 'Workout', 'Workout']);
    expect(rows.first.subtitle, 'Tue 3 Nov · 45 min');
    expect(rows.first.detail, '2 ex · 3 sets');
  });

  test('strength progression compares the last two sessions', () {
    final rows = strengthRows(sessions, UnitSystem.metric);
    expect(rows.map((r) => r.name), ['Bench press', 'Dips']);
    expect(rows.first.best, '102.5 kg × 5');
    expect(rows.first.change, '+2.5 kg');
    expect(rows.first.trend, Trend.up);
    expect(rows.last.best, '12 reps');
    expect(rows.last.change, '+2 reps');
    expect(strengthRows(sessions.take(1).toList(), UnitSystem.metric), isEmpty);
  });

  test('activity: workouts and food over the last 7 days', () {
    final days = activityDays(sessions, {
      Dates.localDateKey(DateTime(2026, 11, 4)): _food(),
      Dates.localDateKey(DateTime(2026, 11, 2)): _food(),
    }, now);
    expect(days, hasLength(7));
    expect(days.map((d) => d.workout), [
      false, false, false, false, true, true, false, // 29 Oct .. 4 Nov
    ]);
    expect(days.map((d) => d.food), [
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ]);
    expect(days.where((d) => d.active), hasLength(3));
  });

  testWidgets('the cards render from the database', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(
              children: const [
                WorkoutSummaryCard(),
                RecentSessionsCard(),
                StrengthProgressionCard(),
                ActivityOverviewCard(),
              ],
            ),
          ),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Workouts this week'), findsOneWidget);
    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Strength progression'), findsOneWidget);
    expect(find.text('+2.5 kg'), findsOneWidget);
    expect(find.text('Activity overview'), findsOneWidget);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.textContaining('route /workouts/history/'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('empty states', (tester) async {
    final empty = createTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(empty)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: const [RecentSessionsCard(), StrengthProgressionCard()],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('No workouts yet.'), findsOneWidget);
    expect(find.textContaining('Do the same exercise'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(empty.close);
  });
}
