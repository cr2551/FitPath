import 'package:fitpath/features/workouts/domain/strength_stats.dart';
import 'package:fitpath/features/workouts/domain/workout_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const squat = 1, pullUp = 2;

LoggedSession session(
  int id,
  int day, {
  WorkoutStatus status = WorkoutStatus.completed,
  required List<LoggedExercise> exercises,
}) {
  final start = DateTime(2026, 11, day, 18);
  return LoggedSession(
    id: id,
    startedAt: start,
    completedAt: status == WorkoutStatus.completed
        ? start.add(const Duration(hours: 1))
        : null,
    status: status,
    exercises: exercises,
  );
}

LoggedExercise squats(List<(double, int)> sets) => LoggedExercise(
  exerciseId: squat,
  name: 'Squat',
  sets: [for (final (w, r) in sets) LoggedSet(weightKg: w, reps: r)],
);

LoggedExercise pullUps(List<int> reps) => LoggedExercise(
  exerciseId: pullUp,
  name: 'Pull-up',
  isBodyweight: true,
  sets: [for (final r in reps) LoggedSet(reps: r)],
);

void main() {
  group('1RM estimate', () {
    test('100 kg × 5: Epley 116.7 kg, Brzycki 112.5 kg', () {
      final e = StrengthStats.estimateOneRepMax(100, 5)!;
      expect(e.epleyKg, closeTo(116.67, 0.01));
      expect(e.brzyckiKg, closeTo(112.5, 0.001));
    });

    test('80 kg × 10 is the last estimated set', () {
      final e = StrengthStats.estimateOneRepMax(80, 10)!;
      expect(e.epleyKg, closeTo(106.67, 0.01)); // 80 × 4/3
      expect(e.brzyckiKg, closeTo(106.67, 0.01)); // 80 × 36/27
    });

    test('a single rep is the load itself for both', () {
      final e = StrengthStats.estimateOneRepMax(140, 1)!;
      expect(e.epleyKg, 140);
      expect(e.brzyckiKg, 140);
    });

    test('none above 10 reps, without a load, or without reps', () {
      expect(StrengthStats.estimateOneRepMax(60, 11), isNull);
      expect(StrengthStats.estimateOneRepMax(0, 5), isNull);
      expect(StrengthStats.estimateOneRepMax(null, 5), isNull);
      expect(StrengthStats.estimateOneRepMax(60, 0), isNull);
      expect(StrengthStats.estimateOneRepMax(60, null), isNull);
    });
  });

  group('records', () {
    final history = [
      session(
        1,
        2,
        exercises: [
          squats([(100, 5), (100, 6), (110, 2)]),
        ],
      ),
      session(
        2,
        4,
        exercises: [
          squats([(60, 15), (105, 5)]),
        ],
      ),
      // Discarded and in-progress sessions never count.
      session(
        3,
        5,
        status: WorkoutStatus.discarded,
        exercises: [
          squats([(200, 5)]),
        ],
      ),
      session(
        4,
        6,
        status: WorkoutStatus.inProgress,
        exercises: [
          squats([(150, 5)]),
        ],
      ),
    ];

    test('loaded exercise', () {
      final r = StrengthStats.records(squat, history);

      expect(r.heaviestLoad!.weightKg, 110);
      expect(r.heaviestLoad!.sessionId, 1);
      // 60 × 15 = 900 beats 105 × 5 = 525 and 100 × 6 = 600.
      expect(r.bestVolume!.volumeKg, 900);
      // 60 × 15 has no 1RM; Epley: 105 × 5 → 122.5, 100 × 6 → 120,
      // 110 × 2 → 117.3.
      expect(r.bestOneRepMax!.weightKg, 105);
      expect(r.bestOneRepMax!.oneRepMax!.epleyKg, closeTo(122.5, 0.001));
      expect(r.mostReps, isNull);
      expect(r.repsAtLoad.keys, [110, 105, 100, 60]);
      expect(r.repsAtLoad[100]!.reps, 6);
    });

    test('bodyweight exercise: reps only', () {
      final r = StrengthStats.records(pullUp, [
        session(
          1,
          2,
          exercises: [
            pullUps([8, 10, 7]),
          ],
        ),
        session(
          2,
          4,
          exercises: [
            pullUps([9]),
          ],
        ),
      ]);
      expect(r.mostReps!.reps, 10);
      expect(r.heaviestLoad, isNull);
      expect(r.bestVolume, isNull);
      expect(r.bestOneRepMax, isNull);
      expect(r.repsAtLoad, isEmpty);
    });

    test('a tie keeps the earlier set', () {
      final r = StrengthStats.records(squat, [
        session(
          2,
          4,
          exercises: [
            squats([(100, 5)]),
          ],
        ),
        session(
          1,
          2,
          exercises: [
            squats([(100, 5)]),
          ],
        ),
      ]);
      expect(r.heaviestLoad!.sessionId, 1);
      expect(r.repsAtLoad[100]!.sessionId, 1);
    });

    test('sets without load, reps or completion are ignored', () {
      final r = StrengthStats.records(squat, [
        session(
          1,
          2,
          exercises: [
            const LoggedExercise(
              exerciseId: squat,
              name: 'Squat',
              sets: [
                LoggedSet(reps: 5),
                LoggedSet(weightKg: 0, reps: 5),
                LoggedSet(weightKg: 120),
                LoggedSet(weightKg: 130, reps: 3, completed: false),
              ],
            ),
          ],
        ),
      ]);
      expect(r.isEmpty, isTrue);
    });

    test('no sessions, no records', () {
      expect(StrengthStats.records(squat, const []).isEmpty, isTrue);
    });
  });

  group('new PRs in a session', () {
    final earlier = [
      session(
        1,
        2,
        exercises: [
          squats([(100, 5)]),
          pullUps([8]),
        ],
      ),
    ];

    test('each beaten record is marked on the session\'s best set', () {
      final today = session(
        2,
        4,
        exercises: [
          squats([(100, 6), (105, 3), (60, 12)]),
          pullUps([8, 9]),
        ],
      );
      final prs = StrengthStats.newPrs(today, [...earlier, today]);

      String key(NewPr p) => '${p.exerciseIndex}/${p.setIndex} ${p.kind.name}';
      expect(prs.map(key), [
        // 100 × 6: more reps at 100 kg; 1RM 120 beats 116.7 (and 105 × 3 is
        // 115.5).
        '0/0 repsAtLoad',
        '0/0 oneRepMax',
        // 105 × 3: heaviest.
        '0/1 heaviestLoad',
        // 60 × 12 = 720 beats 500.
        '0/2 setVolume',
        // Pull-ups: 9 beats 8.
        '1/1 mostReps',
      ]);
    });

    test('a new load is not a reps-at-load PR; a tie is not a PR', () {
      final today = session(
        2,
        4,
        exercises: [
          squats([(100, 5), (90, 5)]),
        ],
      );
      expect(StrengthStats.newPrs(today, [...earlier, today]), isEmpty);
    });

    test('the first time an exercise is done is not a PR', () {
      final today = session(
        2,
        4,
        exercises: [
          squats([(100, 5)]),
        ],
      );
      expect(StrengthStats.newPrs(today, [today]), isEmpty);
    });

    test('only earlier completed sessions are compared', () {
      final today = session(
        2,
        4,
        exercises: [
          squats([(110, 5)]),
        ],
      );
      final later = session(
        3,
        6,
        exercises: [
          squats([(150, 5)]),
        ],
      );
      final discarded = session(
        4,
        3,
        status: WorkoutStatus.discarded,
        exercises: [
          squats([(200, 5)]),
        ],
      );
      final kinds = StrengthStats.newPrs(today, [
        ...earlier,
        today,
        later,
        discarded,
      ]).map((p) => p.kind);
      expect(kinds, containsAll([PrKind.heaviestLoad, PrKind.setVolume]));
    });

    test('a deleted earlier session no longer holds the record', () {
      final today = session(
        2,
        4,
        exercises: [
          squats([(90, 5)]),
        ],
      );
      expect(StrengthStats.newPrs(today, [...earlier, today]), isEmpty);
      // With session 1 deleted there is nothing to beat either.
      expect(StrengthStats.newPrs(today, [today]), isEmpty);

      final middle = session(
        5,
        3,
        exercises: [
          squats([(80, 5)]),
        ],
      );
      expect(StrengthStats.newPrs(today, [middle, today]).map((p) => p.kind), [
        PrKind.heaviestLoad,
        PrKind.setVolume,
        PrKind.oneRepMax,
      ]);
    });
  });

  test('1RM history: best Epley per session, oldest first', () {
    final points = StrengthStats.oneRepMaxHistory(squat, [
      session(
        2,
        4,
        exercises: [
          squats([(100, 3), (90, 8)]),
        ],
      ),
      session(
        1,
        2,
        exercises: [
          squats([(100, 5)]),
        ],
      ),
      session(
        3,
        6,
        exercises: [
          squats([(50, 20)]),
        ],
      ),
      session(
        4,
        7,
        exercises: [
          pullUps([12]),
        ],
      ),
    ]);
    expect(points.map((p) => p.sessionId), [1, 2]);
    expect(points.first.estimate.epleyKg, closeTo(116.67, 0.01));
    // 90 × 8 → 114 beats 100 × 3 → 110.
    expect(points.last.set.weightKg, 90);
    expect(points.last.estimate.brzyckiKg, closeTo(111.72, 0.01));
  });
}
