import '../../../core/utils/dates.dart';
import '../../nutrition/domain/nutrition_math.dart';
import '../../workouts/domain/workout_math.dart';

/// Why a figure has no value. Missing data is never reported as zero.
enum ReportGap {
  /// No food was logged in the week.
  noFoodLogged,

  /// Food was logged, but no target was in effect on those days.
  noTarget,

  /// No weight entry in the week.
  noWeightThisWeek,

  /// No weight entry before the week to compare with.
  noEarlierWeight,
}

/// A value, or the reason it is missing.
class Figure {
  const Figure(double this.value) : gap = null;
  const Figure.missing(ReportGap this.gap) : value = null;

  final double? value;
  final ReportGap? gap;

  bool get isMissing => value == null;

  /// `this − previous`, or null when either is missing.
  double? changeFrom(Figure previous) =>
      value == null || previous.value == null ? null : value! - previous.value!;
}

/// Nutrition targets effective from a local date key (`2026-11-03`) until the
/// next row's date.
class TargetPeriod {
  const TargetPeriod({
    required this.effectiveFrom,
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final String effectiveFrom;
  final double kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
}

class WeightPoint {
  const WeightPoint(this.recordedAt, this.weightKg);

  final DateTime recordedAt;
  final double weightKg;
}

/// Everything a weekly report is built from. Inputs may cover more than the
/// two weeks; the aggregation picks what it needs.
class WeeklyReportInput {
  const WeeklyReportInput({
    this.dailyTotals = const {},
    this.targets = const [],
    this.sessions = const [],
    this.prDates = const [],
    this.weights = const [],
  });

  /// Diary totals keyed by local date key.
  final Map<String, NutrientTotals> dailyTotals;

  /// Target history, in any order.
  final List<TargetPeriod> targets;
  final List<LoggedSession> sessions;

  /// The session start of each new PR (from `StrengthStats.newPrs`).
  final List<DateTime> prDates;
  final List<WeightPoint> weights;
}

class WeekNutrition {
  const WeekNutrition({
    required this.daysLogged,
    required this.averageKcal,
    required this.averageTargetKcal,
    required this.proteinAdherence,
    required this.carbsAdherence,
    required this.fatAdherence,
  });

  /// Days with at least one diary entry.
  final int daysLogged;

  /// Average over logged days.
  final Figure averageKcal;

  /// Average of each logged day's own target, so a mid-week change counts
  /// on the days it was in effect.
  final Figure averageTargetKcal;

  /// Average of eaten ÷ target over logged days with that macro target
  /// (1.0 = on target).
  final Figure proteinAdherence;
  final Figure carbsAdherence;
  final Figure fatAdherence;
}

class WeekTraining {
  const WeekTraining({
    required this.sessions,
    required this.volumeKg,
    required this.newPrs,
  });

  /// Completed sessions. Zero is a real value here, not missing data.
  final int sessions;
  final double volumeKg;
  final int newPrs;
}

class WeekWeight {
  const WeekWeight({required this.lastKg, required this.changeKg});

  /// The last entry in the week.
  final Figure lastKg;

  /// From the last entry before the week to the last entry in it.
  final Figure changeKg;
}

class WeekSummary {
  const WeekSummary({
    required this.weekStart,
    required this.nutrition,
    required this.training,
    required this.weight,
  });

  /// Sunday, local time.
  final DateTime weekStart;
  final WeekNutrition nutrition;
  final WeekTraining training;
  final WeekWeight weight;
}

/// A week and the week before it, for side-by-side comparison.
class WeeklyReport {
  const WeeklyReport({required this.week, required this.previous});

  final WeekSummary week;
  final WeekSummary previous;
}

/// Pure-Dart weekly report aggregation (Phase 2 plan). Weeks run Sunday to
/// Saturday, like the date strip.
abstract final class WeeklyReportCalculator {
  /// The report for the week containing [day], with the week before it.
  static WeeklyReport build(WeeklyReportInput input, DateTime day) {
    final start = Dates.startOfWeek(day);
    return WeeklyReport(
      week: summarize(input, start),
      previous: summarize(input, Dates.addDays(start, -7)),
    );
  }

  /// One week, starting on the Sunday of [day]'s week.
  static WeekSummary summarize(WeeklyReportInput input, DateTime day) {
    final start = Dates.startOfWeek(day);
    final end = Dates.addDays(start, 7);
    final range = DateRange(start: start, end: end);
    return WeekSummary(
      weekStart: start,
      nutrition: _nutrition(input, start),
      training: _training(input, range),
      weight: _weight(input.weights, range),
    );
  }

  static WeekNutrition _nutrition(WeeklyReportInput input, DateTime start) {
    final history = [...input.targets]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    final logged = <(NutrientTotals, TargetPeriod?)>[
      for (var i = 0; i < 7; i++)
        if (input.dailyTotals[Dates.localDateKey(Dates.addDays(start, i))]
            case final t? when !t.isEmpty)
          (t, _targetOn(history, Dates.localDateKey(Dates.addDays(start, i)))),
    ];
    if (logged.isEmpty) {
      const none = Figure.missing(ReportGap.noFoodLogged);
      return const WeekNutrition(
        daysLogged: 0,
        averageKcal: none,
        averageTargetKcal: none,
        proteinAdherence: none,
        carbsAdherence: none,
        fatAdherence: none,
      );
    }

    Figure average(Iterable<double> values) {
      final list = values.toList();
      return list.isEmpty
          ? const Figure.missing(ReportGap.noTarget)
          : Figure(list.reduce((a, b) => a + b) / list.length);
    }

    Figure adherence(
      double Function(NutrientTotals) eaten,
      double? Function(TargetPeriod) target,
    ) => average([
      for (final (totals, t) in logged)
        if (t != null && (target(t) ?? 0) > 0) eaten(totals) / target(t)!,
    ]);

    return WeekNutrition(
      daysLogged: logged.length,
      averageKcal: Figure(
        logged.map((d) => d.$1.kcal).reduce((a, b) => a + b) / logged.length,
      ),
      averageTargetKcal: average([
        for (final (_, t) in logged)
          if (t != null) t.kcal,
      ]),
      proteinAdherence: adherence((n) => n.proteinG, (t) => t.proteinG),
      carbsAdherence: adherence((n) => n.carbsG, (t) => t.carbsG),
      fatAdherence: adherence((n) => n.fatG, (t) => t.fatG),
    );
  }

  static WeekTraining _training(WeeklyReportInput input, DateRange range) {
    final sessions = input.sessions.where(
      (s) => s.isCompleted && range.contains(s.startedAt.toLocal()),
    );
    var volume = 0.0;
    for (final s in sessions) {
      volume += WorkoutMath.summarize(s).totalVolumeKg;
    }
    return WeekTraining(
      sessions: sessions.length,
      volumeKg: volume,
      newPrs: input.prDates.where((d) => range.contains(d.toLocal())).length,
    );
  }

  static WeekWeight _weight(List<WeightPoint> weights, DateRange range) {
    final sorted = [...weights]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    WeightPoint? before, last;
    for (final w in sorted) {
      final t = w.recordedAt.toLocal();
      if (t.isBefore(range.start!)) before = w;
      if (range.contains(t)) last = w;
    }
    if (last == null) {
      const none = Figure.missing(ReportGap.noWeightThisWeek);
      return const WeekWeight(lastKg: none, changeKg: none);
    }
    return WeekWeight(
      lastKg: Figure(last.weightKg),
      changeKg: before == null
          ? const Figure.missing(ReportGap.noEarlierWeight)
          : Figure(last.weightKg - before.weightKg),
    );
  }

  /// The newest period effective on or before [dateKey]; [history] is
  /// oldest first.
  static TargetPeriod? _targetOn(List<TargetPeriod> history, String dateKey) {
    TargetPeriod? found;
    for (final t in history) {
      if (t.effectiveFrom.compareTo(dateKey) > 0) break;
      found = t;
    }
    return found;
  }
}
