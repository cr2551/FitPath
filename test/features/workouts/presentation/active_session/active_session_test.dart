import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/features/workouts/presentation/active_session/active_session_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

/// Lets streams deliver and animations finish. The elapsed-time ticker
/// never settles, so this pumps fixed steps instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

late int _dips;

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.activeSession,
    routes: [
      GoRoute(
        path: Routes.activeSession,
        builder: (_, _) => const ActiveSessionScreen(),
      ),
      // Stands in for the picker: returns Dips.
      GoRoute(
        path: Routes.exercisePicker,
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop(_dips),
            child: const Text('pick dips'),
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
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

/// An open "Push" session with Bench press: one set of 8 x 60 kg.
Future<({int session, int bench, int set})> _seed(AppDatabase db) async {
  final repo = WorkoutRepository(db.workoutDao);
  final bench = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(name: 'Bench press', muscleGroup: 'chest'),
  );
  _dips = await db.workoutDao.insertExercise(
    ExercisesCompanion.insert(
      name: 'Dips',
      muscleGroup: 'chest',
      isBodyweight: const Value(true),
    ),
  );
  final s = await repo.startSession(name: 'Push');
  final e = await repo.addExercise(s, bench);
  final set = await repo.addSet(e, reps: 8, weightKg: 60);
  return (session: s, bench: e, set: set);
}

Future<List<WorkoutSet>> _sets(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.workoutSets).get()))!;

Finder _field(String label) => find.bySemanticsLabel(label);

void main() {
  test('elapsed time format', () {
    expect(formatElapsed(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(formatElapsed(const Duration(minutes: 42, seconds: 10)), '42:10');
    expect(
      formatElapsed(const Duration(hours: 1, minutes: 5, seconds: 30)),
      '1:05:30',
    );
  });

  testWidgets('no session in progress', (tester) async {
    final db = createTestDatabase();
    await _pump(tester, db);
    expect(find.text('No workout in progress.'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('edit sets: values, done, add, duplicate, remove, validation', (
    tester,
  ) async {
    final db = createTestDatabase();
    final ids = (await tester.runAsync(() => _seed(db)))!;
    final semantics = tester.ensureSemantics();
    await _pump(tester, db);

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('0 of 1 sets done'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);

    await tester.enterText(_field('Bench press set 1 reps'), '10');
    await _settle(tester);
    expect((await _sets(tester, db)).single.repetitions, 10);

    // Out of range: not saved.
    await tester.enterText(_field('Bench press set 1 reps'), '2000');
    await _settle(tester);
    expect((await _sets(tester, db)).single.repetitions, 10);
    await tester.enterText(_field('Bench press set 1 reps'), '10');
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('Set 1 done'));
    await _settle(tester);
    expect((await _sets(tester, db)).single.completed, isTrue);
    expect(find.text('1 of 1 sets done'), findsOneWidget);

    // Add set copies the last set's values.
    await tester.tap(find.text('Add set'));
    await _settle(tester);
    var sets = await _sets(tester, db);
    expect(sets, hasLength(2));
    expect(sets.last.repetitions, 10);
    expect(sets.last.weightKg, 60);
    expect(sets.last.completed, isFalse);

    await tester.tap(find.byTooltip('Set 2 options'));
    await _settle(tester);
    await tester.tap(find.text('Duplicate set'));
    await _settle(tester);
    expect(await _sets(tester, db), hasLength(3));

    await tester.tap(find.byTooltip('Set 1 options'));
    await _settle(tester);
    await tester.tap(find.text('Remove set'));
    await _settle(tester);
    sets = await _sets(tester, db);
    expect(sets.map((x) => x.setNumber), [1, 2]);
    expect(sets.any((x) => x.id == ids.set), isFalse);

    semantics.dispose();
    await _dispose(tester, db);
  });

  testWidgets('add a bodyweight exercise from the picker, move and remove', (
    tester,
  ) async {
    final db = createTestDatabase();
    await tester.runAsync(() => _seed(db));
    await _pump(tester, db);

    await tester.tap(find.text('ADD EXERCISE'));
    await _settle(tester);
    await tester.tap(find.text('pick dips'));
    await _settle(tester);
    expect(find.text('Dips'), findsOneWidget);
    expect(find.text('+KG'), findsOneWidget); // optional added load
    final entries = await tester.runAsync(
      () => db.select(db.workoutExercises).get(),
    );
    expect(entries!.map((e) => e.exerciseNameSnapshot), [
      'Bench press',
      'Dips',
    ]);
    expect(await _sets(tester, db), hasLength(2)); // Dips starts with a set

    await tester.tap(find.byTooltip('Exercise options').last);
    await _settle(tester);
    await tester.tap(find.text('Move up'));
    await _settle(tester);
    expect(
      tester.getTopLeft(find.text('Dips')).dy,
      lessThan(tester.getTopLeft(find.text('Bench press')).dy),
    );

    await tester.tap(find.byTooltip('Exercise options').first);
    await _settle(tester);
    await tester.tap(find.text('Remove exercise'));
    await _settle(tester);
    expect(find.text('Dips'), findsNothing);
    await _dispose(tester, db);
  });

  testWidgets('finishing without done sets warns, then completes', (
    tester,
  ) async {
    final db = createTestDatabase();
    final ids = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db);

    await tester.tap(find.text('FINISH WORKOUT'));
    await _settle(tester);
    expect(find.text('No sets are marked done'), findsOneWidget);
    await tester.tap(find.text('FINISH'));
    await _settle(tester);

    final s = await tester.runAsync(
      () => db.workoutDao.sessionById(ids.session),
    );
    expect(s!.status, WorkoutStatus.completed);
    expect(find.text('route /workouts/history/${ids.session}'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('discard asks first', (tester) async {
    final db = createTestDatabase();
    final ids = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db);

    await tester.tap(find.text('Discard workout'));
    await _settle(tester);
    await tester.tap(find.text('DISCARD'));
    await _settle(tester);
    final s = await tester.runAsync(
      () => db.workoutDao.sessionById(ids.session),
    );
    expect(s!.status, WorkoutStatus.discarded);
    expect(find.text('route /workouts'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('imperial loads are shown in lb and stored in kg', (
    tester,
  ) async {
    final db = createTestDatabase();
    await tester.runAsync(() async {
      await _seed(db);
      await ProfileRepository(db.profileDao).setUnitSystem(UnitSystem.imperial);
    });
    final semantics = tester.ensureSemantics();
    await _pump(tester, db);

    expect(find.text('LB'), findsOneWidget);
    expect(find.text('132.3'), findsOneWidget); // 60 kg
    await tester.enterText(_field('Bench press set 1 load'), '135');
    await _settle(tester);
    expect((await _sets(tester, db)).single.weightKg, closeTo(61.235, 0.001));
    semantics.dispose();
    await _dispose(tester, db);
  });
}
