import 'package:fitpath/features/workouts/domain/workout_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const squat = 1, pullUp = 2;

LoggedSession session(
  int id,
  DateTime start, {
  WorkoutStatus status = WorkoutStatus.completed,
  required List<LoggedExercise> exercises,
  Duration length = const Duration(minutes: 45),
}) => LoggedSession(
  id: id,
  startedAt: start,
  completedAt: status == WorkoutStatus.completed ? start.add(length) : null,
  status: status,
  exercises: exercises,
);

LoggedExercise squats(List<LoggedSet> sets) =>
    LoggedExercise(exerciseId: squat, name: 'Squat', sets: sets);

LoggedExercise pullUps(List<LoggedSet> sets) => LoggedExercise(
  exerciseId: pullUp,
  name: 'Pull-up',
  isBodyweight: true,
  sets: sets,
);

void main() {
  group('set volume', () {
    test('load x reps for completed weighted sets', () {
      expect(
        WorkoutMath.setVolume(const LoggedSet(reps: 5, weightKg: 100)),
        500,
      );
    });

    test('not meaningful for bodyweight, missing values or open sets', () {
      expect(
        WorkoutMath.setVolume(
          const LoggedSet(reps: 10, weightKg: 20),
          isBodyweight: true,
        ),
        isNull,
      );
      expect(WorkoutMath.setVolume(const LoggedSet(reps: 5)), isNull);
      expect(WorkoutMath.setVolume(const LoggedSet(weightKg: 60)), isNull);
      expect(
        WorkoutMath.setVolume(
          const LoggedSet(reps: 5, weightKg: 100, completed: false),
        ),
        isNull,
      );
    });
  });

  group('session summary', () {
    test('counts completed sets only; bodyweight adds reps, not volume', () {
      final s = session(
        1,
        DateTime(2026, 11, 3, 18),
        length: const Duration(minutes: 42),
        exercises: [
          squats(const [
            LoggedSet(reps: 5, weightKg: 100),
            LoggedSet(reps: 5, weightKg: 100),
            LoggedSet(reps: 5, weightKg: 110, completed: false),
          ]),
          pullUps(const [LoggedSet(reps: 8), LoggedSet(reps: 6)]),
        ],
      );

      final r = WorkoutMath.summarize(s);
      expect(r.exerciseCount, 2);
      expect(r.completedSets, 4);
      expect(r.totalReps, 24);
      expect(r.totalVolumeKg, 1000);
      expect(r.duration, const Duration(minutes: 42));
    });

    test('in-progress sessions have no duration', () {
      final s = session(
        1,
        DateTime(2026, 11, 3),
        status: WorkoutStatus.inProgress,
        exercises: const [],
      );
      expect(WorkoutMath.summarize(s).duration, isNull);
    });
  });

  group('best set', () {
    test('heaviest load, then most reps', () {
      final b = WorkoutMath.bestSet(
        squats(const [
          LoggedSet(reps: 8, weightKg: 90),
          LoggedSet(reps: 3, weightKg: 110),
          LoggedSet(reps: 5, weightKg: 110),
          LoggedSet(reps: 1, weightKg: 130, completed: false),
        ]),
      )!;
      expect((b.weightKg, b.reps), (110.0, 5));
    });

    test('bodyweight exercises compare reps only', () {
      final b = WorkoutMath.bestSet(
        pullUps(const [LoggedSet(reps: 8), LoggedSet(reps: 10, weightKg: 5)]),
      )!;
      expect((b.weightKg, b.reps), (null, 10));
    });

    test('no completed sets means no best set', () {
      expect(
        WorkoutMath.bestSet(
          squats(const [LoggedSet(reps: 5, weightKg: 100, completed: false)]),
        ),
        isNull,
      );
    });
  });

  group('exercise history and progression', () {
    final sessions = [
      session(
        3,
        DateTime(2026, 11, 2),
        exercises: [
          squats(const [
            LoggedSet(reps: 5, weightKg: 105),
            LoggedSet(reps: 5, weightKg: 105),
          ]),
        ],
      ),
      session(
        1,
        DateTime(2026, 10, 26),
        exercises: [
          squats(const [
            LoggedSet(reps: 5, weightKg: 100),
            LoggedSet(reps: 6, weightKg: 100),
          ]),
        ],
      ),
      session(
        2,
        DateTime(2026, 10, 29),
        status: WorkoutStatus.discarded,
        exercises: [
          squats(const [LoggedSet(reps: 5, weightKg: 200)]),
        ],
      ),
      session(
        4,
        DateTime(2026, 11, 1),
        exercises: [
          pullUps(const [LoggedSet(reps: 8)]),
        ],
      ),
    ];

    test('completed sessions only, oldest first', () {
      final h = WorkoutMath.exerciseHistory(squat, sessions);
      expect(h.map((p) => p.sessionId), [1, 3]);
      expect(h.first.volumeKg, 1100);
      expect(h.last.bestSet!.weightKg, 105);
    });

    test('compare with the previous session', () {
      final h = WorkoutMath.exerciseHistory(squat, sessions);
      final c = WorkoutMath.compare(h[0], h[1])!;
      expect(c.bestWeightKg, 5);
      expect(c.bestReps, -1);
      expect(c.volumeKg, -50);
    });

    test('bodyweight comparisons have no load delta', () {
      final a = ExercisePerformance(
        sessionId: 1,
        date: DateTime(2026),
        bestSet: const BestSet(reps: 8),
        totalReps: 8,
        volumeKg: 0,
      );
      final b = ExercisePerformance(
        sessionId: 2,
        date: DateTime(2026, 1, 3),
        bestSet: const BestSet(reps: 10),
        totalReps: 10,
        volumeKg: 0,
      );
      final c = WorkoutMath.compare(a, b)!;
      expect(c.bestWeightKg, isNull);
      expect(c.bestReps, 2);
    });

    test('completed sessions in a range', () {
      expect(
        WorkoutMath.completedSessionsBetween(
          sessions,
          DateTime(2026, 10, 26),
          DateTime(2026, 11, 2),
        ),
        2,
      );
    });
  });
}
