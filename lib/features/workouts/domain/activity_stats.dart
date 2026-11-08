import '../../../core/utils/dates.dart';
import 'workout_math.dart';

/// Completed sessions in one calendar month.
class MonthCount {
  const MonthCount({required this.month, required this.sessions});

  /// The first day of the month, local time.
  final DateTime month;
  final int sessions;
}

/// Weeks in a row with at least one completed workout.
class WeeklyStreak {
  const WeeklyStreak({
    required this.current,
    required this.longest,
    required this.thisWeekDone,
  });

  /// Ends with this week when it has a workout, otherwise with last week.
  final int current;
  final int longest;

  /// Whether this week already has a completed workout.
  final bool thisWeekDone;
}

/// Pure-Dart activity statistics (Phase 2 plan, decision of 7 Nov).
///
/// - Only completed sessions count, by their local start date.
/// - A week (Sunday-Saturday, like the date strip) counts toward the streak
///   when it has at least one completed workout. The weekly training target
///   in the profile is not used.
/// - The current week never breaks a streak: until it has a workout the
///   streak ends with last week.
abstract final class ActivityStats {
  /// One entry per month from [from]'s month to [to]'s month, inclusive,
  /// with zero for months without workouts.
  static List<MonthCount> monthlyCounts(
    Iterable<LoggedSession> sessions, {
    required DateTime from,
    required DateTime to,
  }) {
    final counts = <DateTime, int>{};
    for (final s in sessions.where((s) => s.isCompleted)) {
      final month = _month(s.startedAt.toLocal());
      counts[month] = (counts[month] ?? 0) + 1;
    }
    final last = _month(to);
    return [
      for (
        var m = _month(from);
        !m.isAfter(last);
        m = DateTime(m.year, m.month + 1)
      )
        MonthCount(month: m, sessions: counts[m] ?? 0),
    ];
  }

  /// Current and longest streak as of [today]. Sessions after this week are
  /// ignored.
  static WeeklyStreak streak(
    Iterable<LoggedSession> sessions, {
    required DateTime today,
  }) {
    final thisWeek = Dates.startOfWeek(today);
    final weeks = <DateTime>{
      for (final s in sessions.where((s) => s.isCompleted))
        Dates.startOfWeek(s.startedAt.toLocal()),
    }..removeWhere((w) => w.isAfter(thisWeek));

    final thisWeekDone = weeks.contains(thisWeek);
    var current = 0;
    for (
      var w = thisWeekDone ? thisWeek : Dates.addDays(thisWeek, -7);
      weeks.contains(w);
      w = Dates.addDays(w, -7)
    ) {
      current++;
    }

    var longest = 0, run = 0;
    DateTime? previous;
    for (final w in weeks.toList()..sort()) {
      run = previous != null && Dates.addDays(previous, 7) == w ? run + 1 : 1;
      if (run > longest) longest = run;
      previous = w;
    }

    return WeeklyStreak(
      current: current,
      longest: longest,
      thisWeekDone: thisWeekDone,
    );
  }

  static DateTime _month(DateTime d) => DateTime(d.year, d.month);
}
