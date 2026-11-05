import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/features/workouts/presentation/workouts_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const WorkoutsScreen())],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

/// A completed "Push" session (bench 2 x 5 x 100 kg) and returns its id.
Future<int> _completed(AppDatabase db) async {
  final repo = WorkoutRepository(
    db.workoutDao,
    clock: () => DateTime(2026, 11, 2, 18),
  );
  final bench = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
  );
  final s = await repo.startSession(name: 'Push');
  final e = await repo.addExercise(s, bench);
  for (var i = 0; i < 2; i++) {
    final set = await repo.addSet(e, reps: 5, weightKg: 100);
    await repo.updateSet(set, completed: const Value(true));
  }
  await WorkoutRepository(
    db.workoutDao,
    clock: () => DateTime(2026, 11, 2, 18, 42),
  ).completeSession(s);
  return s;
}

void main() {
  testWidgets('first time: empty state, then start a named workout', (
    tester,
  ) async {
    final db = createTestDatabase();
    await _pump(tester, db);
    expect(find.textContaining('No workouts yet'), findsOneWidget);

    await tester.tap(find.text('START WORKOUT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leg day');
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('route /workouts/session'), findsOneWidget);
    final sessions = await tester.runAsync(
      () => db.select(db.workoutSessions).get(),
    );
    expect(sessions!.single.name, 'Leg day');
    expect(sessions.single.status, WorkoutStatus.inProgress);
    await _dispose(tester, db);
  });

  testWidgets('recent sessions show totals and open the detail', (
    tester,
  ) async {
    final db = createTestDatabase();
    final id = (await tester.runAsync(() => _completed(db)))!;
    await _pump(tester, db);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Mon 2 Nov · 42 min · 1,000 kg'), findsOneWidget);
    expect(find.text('1 ex · 2 sets'), findsOneWidget);
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('route /workouts/history/$id'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('resume card: resume and discard', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() async {
      final repo = WorkoutRepository(db.workoutDao);
      final bench = await db.workoutDao.insertExercise(
        ExercisesCompanion.insert(name: 'Squat', muscleGroup: 'legs'),
      );
      final s = await repo.startSession(name: 'Legs');
      final e = await repo.addExercise(s, bench);
      final done = await repo.addSet(e, reps: 5);
      await repo.updateSet(done, completed: const Value(true));
      await repo.addSet(e, reps: 5);
    });
    await _pump(tester, db);

    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(
      find.textContaining('1 exercise · 1 of 2 sets done'),
      findsOneWidget,
    );
    expect(find.text('START NEW WORKOUT'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('IN PROGRESS'), findsNothing);
    final s = await tester.runAsync(() => db.select(db.workoutSessions).get());
    expect(s!.single.status, WorkoutStatus.discarded);
    await _dispose(tester, db);
  });

  testWidgets('starting while one is open asks to discard it first', (
    tester,
  ) async {
    final db = createTestDatabase();
    await tester.runAsync(
      () => WorkoutRepository(db.workoutDao).startSession(name: 'Old'),
    );
    await _pump(tester, db);

    await tester.tap(find.text('START NEW WORKOUT'));
    await tester.pumpAndSettle();
    expect(find.text('Discard the workout in progress?'), findsOneWidget);
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    await _settle(tester);
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    await _settle(tester);

    final s = await tester.runAsync(() => db.select(db.workoutSessions).get());
    expect(s!.map((x) => x.status), [
      WorkoutStatus.discarded,
      WorkoutStatus.inProgress,
    ]);
    expect(s.last.name, isNull);
    await _dispose(tester, db);
  });
}
