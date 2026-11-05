import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/features/workouts/data/workout_models.dart';
import 'package:fitpath/features/workouts/data/workout_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;
  var now = DateTime(2026, 11, 3, 18);

  Future<int> catalogExercise(String name, {bool bodyweight = false}) =>
      db.workoutDao.insertExercise(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: 'chest',
          isBodyweight: Value(bodyweight),
        ),
      );

  setUp(() {
    db = createTestDatabase();
    now = DateTime(2026, 11, 3, 18);
    repo = WorkoutRepository(db.workoutDao, clock: () => now);
  });
  tearDown(() => db.close());

  group('catalog', () {
    test('search, filter by muscle group, hide soft-deleted', () async {
      await catalogExercise('Bench press');
      await db.workoutDao.insertExercise(
        ExercisesCompanion.insert(name: 'Squat', muscleGroup: 'legs'),
      );
      final custom = await repo.createCustomExercise(
        const ExerciseDetails(name: ' Cable fly ', muscleGroup: 'chest'),
      );

      final chest = await repo.watchExercises(muscleGroup: 'chest').first;
      expect(chest.map((e) => e.name), ['Bench press', 'Cable fly']);
      expect(
        (await repo.watchExercises(query: 'SQU').first).single.name,
        'Squat',
      );

      await repo.deleteCustomExercise(custom);
      final all = await repo.watchExercises().first;
      expect(all.map((e) => e.name), ['Bench press', 'Squat']);
      expect((await repo.exerciseById(custom))!.deletedAt, now);
    });

    test('validates and only edits custom exercises', () async {
      expect(
        () => repo.createCustomExercise(
          const ExerciseDetails(name: '  ', muscleGroup: 'chest'),
        ),
        throwsA(isA<InvalidExercise>()),
      );
      final builtIn = await catalogExercise('Bench press');
      expect(
        () => repo.updateCustomExercise(
          builtIn,
          const ExerciseDetails(name: 'X', muscleGroup: 'chest'),
        ),
        throwsA(isA<NotACustomExercise>()),
      );
      expect(
        () => repo.deleteCustomExercise(builtIn),
        throwsA(isA<NotACustomExercise>()),
      );
    });

    test('renaming a custom exercise keeps the name in history', () async {
      final id = await repo.createCustomExercise(
        const ExerciseDetails(name: 'Fly', muscleGroup: 'chest'),
      );
      final session = await repo.startSession();
      await repo.addExercise(session, id);
      await repo.updateCustomExercise(
        id,
        const ExerciseDetails(name: 'Cable fly', muscleGroup: 'chest'),
      );
      final detail = (await repo.watchSession(session).first)!;
      expect(detail.exercises.single.name, 'Fly');
      expect(detail.exercises.single.exercise.name, 'Cable fly');
    });
  });

  group('sessions', () {
    test('start resumes the session already in progress', () async {
      expect(await repo.watchActiveSession().first, isNull);
      final a = await repo.startSession(name: 'Push');
      final b = await repo.startSession();
      expect(b, a);

      // A new repository on the same database (an app restart) resumes it.
      final again = WorkoutRepository(db.workoutDao);
      final active = (await again.watchActiveSession().first)!;
      expect(active.id, a);
      expect(active.session.name, 'Push');
      expect(active.session.status, WorkoutStatus.inProgress);
    });

    test('exercises: snapshot name, order, reorder and remove', () async {
      final bench = await catalogExercise('Bench press');
      final dips = await catalogExercise('Dips', bodyweight: true);
      final s = await repo.startSession();
      final e1 = await repo.addExercise(s, bench);
      final e2 = await repo.addExercise(s, dips);

      var detail = (await repo.watchSession(s).first)!;
      expect(detail.exercises.map((e) => e.name), ['Bench press', 'Dips']);
      expect(detail.exercises.last.isBodyweight, isTrue);

      await repo.reorderExercises(s, [e2, e1]);
      detail = (await repo.watchSession(s).first)!;
      expect(detail.exercises.map((e) => e.id), [e2, e1]);

      await repo.removeExercise(e2);
      detail = (await repo.watchSession(s).first)!;
      expect(detail.exercises.map((e) => e.id), [e1]);
    });

    test('sets: add, edit, complete, remove and renumber', () async {
      final bench = await catalogExercise('Bench press');
      final s = await repo.startSession();
      final e = await repo.addExercise(s, bench);
      final s1 = await repo.addSet(e, reps: 8, weightKg: 60);
      final s2 = await repo.addSet(e, reps: 8, weightKg: 60);
      final s3 = await repo.addSet(e);

      await repo.updateSet(
        s2,
        reps: const Value(6),
        weightKg: const Value(65),
        completed: const Value(true),
      );
      await repo.removeSet(s1);

      final sets = (await repo.watchSession(s).first)!.exercises.single.sets;
      expect(sets.map((x) => x.id), [s2, s3]);
      expect(sets.map((x) => x.setNumber), [1, 2]);
      expect(sets.first.repetitions, 6);
      expect(sets.first.weightKg, 65);
      expect(sets.first.completed, isTrue);
      expect(sets.last.repetitions, isNull);

      expect(() => repo.addSet(e, reps: -1), throwsA(isA<ArgumentError>()));
    });

    test('complete moves the session to history', () async {
      final bench = await catalogExercise('Bench press');
      final s = await repo.startSession();
      final e = await repo.addExercise(s, bench);
      final set = await repo.addSet(e, reps: 5, weightKg: 100);
      await repo.updateSet(set, completed: const Value(true));
      now = DateTime(2026, 11, 3, 19);
      await repo.completeSession(s);

      expect(await repo.watchActiveSession().first, isNull);
      final done = (await repo.watchCompletedSessions().first).single;
      expect(done.session.status, WorkoutStatus.completed);
      expect(done.session.completedAt, now);
      expect(done.summary.totalVolumeKg, 500);
      expect(done.summary.duration, const Duration(hours: 1));

      // History can't be edited.
      expect(() => repo.addSet(e), throwsA(isA<SessionNotInProgress>()));
      expect(
        () => repo.completeSession(s),
        throwsA(isA<SessionNotInProgress>()),
      );
    });

    test('discard never counts toward history', () async {
      final s = await repo.startSession();
      await repo.discardSession(s);
      expect(await repo.watchActiveSession().first, isNull);
      expect(await repo.watchCompletedSessions().first, isEmpty);
      expect(
        (await db.workoutDao.sessionById(s))!.status,
        WorkoutStatus.discarded,
      );
    });

    test('delete cascades to exercises and sets', () async {
      final bench = await catalogExercise('Bench press');
      final s = await repo.startSession();
      final e = await repo.addExercise(s, bench);
      await repo.addSet(e, reps: 5);
      await repo.completeSession(s);

      await repo.deleteSession(s);
      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.workoutExercises).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
      // The catalog exercise stays.
      expect(await repo.exerciseById(bench), isNotNull);
    });
  });

  group('history', () {
    Future<int> completed(
      DateTime start,
      int exerciseId,
      double kg,
      int reps,
    ) async {
      now = start;
      final s = await repo.startSession();
      final e = await repo.addExercise(s, exerciseId);
      final set = await repo.addSet(e, reps: reps, weightKg: kg);
      await repo.updateSet(set, completed: const Value(true));
      now = start.add(const Duration(hours: 1));
      await repo.completeSession(s);
      return s;
    }

    test('pages newest first, filters by range and counts per week', () async {
      final bench = await catalogExercise('Bench press');
      final a = await completed(DateTime(2026, 10, 27, 18), bench, 60, 8);
      final b = await completed(DateTime(2026, 11, 2, 18), bench, 62.5, 8);
      final c = await completed(DateTime(2026, 11, 3, 18), bench, 65, 6);

      expect((await repo.watchCompletedSessions().first).map((s) => s.id), [
        c,
        b,
        a,
      ]);
      expect(
        (await repo.watchCompletedSessions(limit: 2).first).map((s) => s.id),
        [c, b],
      );
      expect(
        (await repo
                .watchCompletedSessions(
                  from: DateTime(2026, 11, 1),
                  to: DateTime(2026, 11, 8),
                )
                .first)
            .map((s) => s.id),
        [c, b],
      );
      expect(
        await repo
            .watchCompletedCount(DateTime(2026, 11, 1), DateTime(2026, 11, 8))
            .first,
        2,
      );
    });

    test('exercise history for progression', () async {
      final bench = await catalogExercise('Bench press');
      final squat = await catalogExercise('Squat');
      await completed(DateTime(2026, 10, 27, 18), bench, 60, 8);
      await completed(DateTime(2026, 10, 29, 18), squat, 100, 5);
      await completed(DateTime(2026, 11, 2, 18), bench, 62.5, 8);
      final open = await repo.startSession(); // in progress: excluded
      await repo.addExercise(open, bench);

      final history = await repo.watchExerciseHistory(bench).first;
      expect(history.map((h) => h.bestSet!.weightKg), [60, 62.5]);
      expect(history.last.volumeKg, 500);
    });
  });
}
