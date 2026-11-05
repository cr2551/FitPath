import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/features/workouts/presentation/session_detail/session_detail_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, AppDatabase db, int id) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SessionDetailScreen(sessionId: id),
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
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

/// "Push" on Mon 2 Nov 2026, 18:05–18:47: bench 2 x 5 x 100 kg (one not
/// done), dips 12 reps + 10 kg. Bench was renamed afterwards.
Future<int> _seed(AppDatabase db) async {
  var now = DateTime(2026, 11, 2, 18, 5);
  final repo = WorkoutRepository(db.workoutDao, clock: () => now);
  final bench = await repo.createCustomExercise(
    const ExerciseDetails(name: 'Bench press', muscleGroup: 'chest'),
  );
  final dips = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(
      name: 'Dips',
      muscleGroup: 'chest',
      isBodyweight: const Value(true),
    ),
  );
  final s = await repo.startSession(name: 'Push');
  final b = await repo.addExercise(s, bench);
  final s1 = await repo.addSet(b, reps: 5, weightKg: 100);
  await repo.updateSet(s1, completed: const Value(true));
  await repo.addSet(b, reps: 5, weightKg: 100);
  final d = await repo.addExercise(s, dips);
  final s3 = await repo.addSet(d, reps: 12, weightKg: 10);
  await repo.updateSet(s3, completed: const Value(true));
  now = DateTime(2026, 11, 2, 18, 47);
  await repo.completeSession(s);
  await repo.updateCustomExercise(
    bench,
    const ExerciseDetails(name: 'Flat bench', muscleGroup: 'chest'),
  );
  return s;
}

void main() {
  testWidgets('header, totals, snapshot names and sets', (tester) async {
    final db = createTestDatabase();
    final id = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db, id);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Mon 2 Nov 2026 · 18:05–18:47'), findsOneWidget);
    expect(find.text('42 min'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // completed sets
    expect(find.text('500 kg'), findsOneWidget); // bodyweight adds none

    expect(find.text('Bench press'), findsOneWidget); // not "Flat bench"
    expect(find.text('5 × 100 kg'), findsNWidgets(2));
    expect(find.text('not done'), findsOneWidget);
    expect(find.text('12 reps · +10 kg'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('delete asks first and cascades', (tester) async {
    final db = createTestDatabase();
    final id = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db, id);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Push'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('route /workouts'), findsOneWidget);
    final sets = await tester.runAsync(() => db.select(db.workoutSets).get());
    expect(sets, isEmpty);
    final sessions = await tester.runAsync(
      () => db.select(db.workoutSessions).get(),
    );
    expect(sessions, isEmpty);
    await _dispose(tester, db);
  });

  testWidgets('a missing session says so', (tester) async {
    final db = createTestDatabase();
    await _pump(tester, db, 99);
    expect(find.text('This session no longer exists.'), findsOneWidget);
    expect(find.byTooltip('Delete session'), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('imperial volume and loads', (tester) async {
    final db = createTestDatabase();
    final id = (await tester.runAsync(() async {
      final s = await _seed(db);
      await ProfileRepository(db.profileDao).setUnitSystem(UnitSystem.imperial);
      return s;
    }))!;
    await _pump(tester, db, id);
    expect(find.text('5 × 220.5 lb'), findsNWidgets(2));
    expect(find.text('1,102 lb'), findsOneWidget);
    await _dispose(tester, db);
  });
}
