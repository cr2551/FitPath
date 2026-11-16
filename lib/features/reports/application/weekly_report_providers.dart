import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/dates.dart';
import '../../nutrition/application/diary_providers.dart';
import '../../nutrition/domain/nutrition_math.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/domain/weekly_report.dart';
import '../../workouts/application/workout_providers.dart';
import '../../workouts/data/workout_models.dart';
import '../../workouts/domain/strength_stats.dart';

/// The raw history a weekly report is built from.
class ReportSources {
  const ReportSources({
    required this.dailyTotals,
    required this.targets,
    required this.sessions,
    required this.weights,
  });

  /// Diary totals keyed by local date key.
  final Map<String, NutrientTotals> dailyTotals;

  /// Every target row, oldest first.
  final List<NutritionTarget> targets;

  /// Every completed session, newest first.
  final List<SessionDetail> sessions;

  /// Every weight entry, newest first.
  final List<WeightEntry> weights;
}

final _targetHistoryProvider =
    StreamProvider.autoDispose<List<NutritionTarget>>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return (db.select(db.nutritionTargets)..orderBy([
            (t) => OrderingTerm.asc(t.effectiveFrom),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();
    });

/// All history the weekly report reads. The aggregation picks the weeks it
/// needs; PRs need every earlier session anyway.
final reportSourcesProvider = Provider.autoDispose<AsyncValue<ReportSources>>((
  ref,
) {
  final totals = ref.watch(dailyTotalsProvider(RangePreset.all));
  final targets = ref.watch(_targetHistoryProvider);
  final sessions = ref.watch(completedWorkoutHistoryProvider);
  final weights = ref.watch(weightEntriesProvider(RangePreset.all));

  for (final v in <AsyncValue<Object?>>[totals, targets, sessions, weights]) {
    if (v.hasError) return AsyncValue.error(v.error!, v.stackTrace!);
  }
  if (!totals.hasValue ||
      !targets.hasValue ||
      !sessions.hasValue ||
      !weights.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    ReportSources(
      dailyTotals: totals.requireValue,
      targets: targets.requireValue,
      sessions: sessions.requireValue,
      weights: weights.requireValue,
    ),
  );
});

/// A new personal record set in the report's week.
class ReportPr {
  const ReportPr({required this.exerciseName, required this.pr});

  final String exerciseName;
  final NewPr pr;
}

/// The report for the week containing [day], and that week's new PRs in
/// the order they were set.
({WeeklyReport report, List<ReportPr> prs}) buildWeeklyReport(
  ReportSources s,
  DateTime day,
) {
  final weekStart = Dates.startOfWeek(day);
  final weekEnd = Dates.addDays(weekStart, 7);
  final twoWeeks = DateRange(start: Dates.addDays(weekStart, -7), end: weekEnd);
  final week = DateRange(start: weekStart, end: weekEnd);

  final logged = [for (final d in s.sessions) d.toLogged()];
  final prDates = <DateTime>[];
  final prs = <ReportPr>[];
  for (final session in logged.reversed) {
    if (!twoWeeks.contains(session.startedAt.toLocal())) continue;
    final found = StrengthStats.newPrs(session, logged);
    prDates.addAll([for (final _ in found) session.startedAt]);
    if (week.contains(session.startedAt.toLocal())) {
      prs.addAll([
        for (final pr in found)
          ReportPr(
            exerciseName: session.exercises[pr.exerciseIndex].name,
            pr: pr,
          ),
      ]);
    }
  }

  final input = WeeklyReportInput(
    dailyTotals: s.dailyTotals,
    targets: [
      for (final t in s.targets)
        TargetPeriod(
          effectiveFrom: t.effectiveFrom,
          kcal: t.calories.toDouble(),
          proteinG: t.proteinG,
          carbsG: t.carbsG,
          fatG: t.fatG,
        ),
    ],
    sessions: logged,
    prDates: prDates,
    weights: [for (final w in s.weights) WeightPoint(w.recordedAt, w.weightKg)],
  );
  return (report: WeeklyReportCalculator.build(input, weekStart), prs: prs);
}

/// Re-subscribes every source after a load error.
void retryReportSources(WidgetRef ref) => ref
  ..invalidate(dailyTotalsProvider(RangePreset.all))
  ..invalidate(_targetHistoryProvider)
  ..invalidate(completedWorkoutHistoryProvider)
  ..invalidate(weightEntriesProvider(RangePreset.all));
