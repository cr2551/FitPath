import 'package:fitpath/features/workouts/domain/activity_stats.dart';
import 'package:fitpath/features/workouts/domain/workout_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

var _id = 0;

LoggedSession at(
  int year,
  int month,
  int day, {
  int hour = 18,
  WorkoutStatus status = WorkoutStatus.completed,
}) => LoggedSession(
  id: ++_id,
  startedAt: DateTime(year, month, day, hour),
  status: status,
  exercises: const [],
);

// 2026-11-01 is a Sunday (and the end of US daylight saving time).
final today = DateTime(2026, 11, 18, 9); // Wednesday

void main() {
  group('monthly counts', () {
    test('completed sessions per month, zeros included', () {
      final counts = ActivityStats.monthlyCounts(
        [
          at(2026, 9, 1),
          at(2026, 9, 30, hour: 23),
          at(2026, 11, 1, hour: 0),
          at(2026, 11, 2, status: WorkoutStatus.discarded),
          at(2026, 11, 3, status: WorkoutStatus.inProgress),
        ],
        from: DateTime(2026, 8, 15),
        to: today,
      );
      expect(
        [for (final c in counts) '${c.month.month}:${c.sessions}'],
        ['8:0', '9:2', '10:0', '11:1'],
      );
      expect(counts.first.month, DateTime(2026, 8));
    });

    test('across a year boundary', () {
      final counts = ActivityStats.monthlyCounts(
        [at(2026, 12, 31), at(2027, 1, 1)],
        from: DateTime(2026, 12),
        to: DateTime(2027, 1, 20),
      );
      expect(
        [for (final c in counts) c.month],
        [DateTime(2026, 12), DateTime(2027)],
      );
      expect([for (final c in counts) c.sessions], [1, 1]);
    });
  });

  group('weekly streak', () {
    test('no workouts', () {
      final s = ActivityStats.streak(const [], today: today);
      expect((s.current, s.longest, s.thisWeekDone), (0, 0, false));
    });

    test('this week without a workout does not break the streak', () {
      final s = ActivityStats.streak([
        at(2026, 11, 2), // week of 1 Nov
        at(2026, 11, 14), // week of 8 Nov (Saturday)
      ], today: today);
      expect((s.current, s.longest, s.thisWeekDone), (2, 2, false));
    });

    test('a workout this week extends it', () {
      final s = ActivityStats.streak([
        at(2026, 11, 2),
        at(2026, 11, 8), // Sunday
        at(2026, 11, 15), // Sunday of this week
      ], today: today);
      expect((s.current, s.longest, s.thisWeekDone), (3, 3, true));
    });

    test('a missed week breaks it; several workouts in a week count once', () {
      final s = ActivityStats.streak([
        at(2026, 10, 5),
        at(2026, 10, 6),
        at(2026, 10, 7),
        at(2026, 10, 12),
        at(2026, 10, 19),
        // Week of 26 Oct missed.
        at(2026, 11, 3),
        at(2026, 11, 10),
      ], today: today);
      expect((s.current, s.longest), (2, 3));
    });

    test('last week missed: the current streak is over', () {
      final s = ActivityStats.streak([at(2026, 11, 3)], today: today);
      expect((s.current, s.longest), (0, 1));
    });

    test('discarded and in-progress sessions never count', () {
      final s = ActivityStats.streak([
        at(2026, 11, 10, status: WorkoutStatus.discarded),
        at(2026, 11, 16, status: WorkoutStatus.inProgress),
      ], today: today);
      expect((s.current, s.longest, s.thisWeekDone), (0, 0, false));
    });

    test('across the year boundary', () {
      final s = ActivityStats.streak([
        at(2026, 12, 21), // week of 20 Dec
        at(2027, 1, 2), // Saturday, week of 27 Dec 2026
        at(2027, 1, 4), // week of 3 Jan
      ], today: DateTime(2027, 1, 12));
      expect((s.current, s.longest, s.thisWeekDone), (3, 3, false));
    });

    test('across a daylight saving change', () {
      final s = ActivityStats.streak([
        at(2026, 10, 31, hour: 23), // Saturday before the change
        at(2026, 11, 1, hour: 1), // Sunday, during the change
        at(2026, 3, 7), // Saturday before the March change
        at(2026, 3, 8, hour: 3), // Sunday of the March change
      ], today: DateTime(2026, 11, 2));
      expect((s.current, s.longest, s.thisWeekDone), (2, 2, true));
    });

    test('sessions after this week are ignored', () {
      final s = ActivityStats.streak([at(2026, 11, 25)], today: today);
      expect((s.current, s.longest), (0, 0));
    });
  });
}
