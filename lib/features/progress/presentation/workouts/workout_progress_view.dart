import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import '../../../workouts/domain/activity_stats.dart';
import '../../../workouts/domain/workout_math.dart';
import '../../application/progress_range_provider.dart';
import '../weight/weight_chart.dart';
import 'workout_progress_layout.dart';

/// Completed sessions started in the range, newest first.
final _sessionsInRangeProvider =
    StreamProvider.family<List<SessionDetail>, RangePreset>((ref, preset) {
      final range = Dates.rangeFor(preset, DateTime.now());
      return ref
          .watch(workoutRepositoryProvider)
          .watchCompletedSessions(from: range.start, to: range.end);
    });

/// Every completed session, for the streak (which ignores the range).
final _allSessionsProvider = StreamProvider<List<SessionDetail>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchCompletedSessions(),
);

/// Progress > Workouts: the weekly streak, sessions per week and per month
/// and totals over the range, and the best set, reps or volume of one
/// exercise per session.
class WorkoutProgressView extends ConsumerStatefulWidget {
  const WorkoutProgressView({super.key});

  @override
  ConsumerState<WorkoutProgressView> createState() =>
      _WorkoutProgressViewState();
}

class _WorkoutProgressViewState extends ConsumerState<WorkoutProgressView> {
  int? _exercise;
  var _metric = ExerciseMetric.load;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(progressRangeProvider);
    final sessions = ref.watch(_sessionsInRangeProvider(range));
    final all = ref.watch(_allSessionsProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;

    if (sessions.hasError || all.hasError) {
      return ErrorState(
        message: "Couldn't load your workouts.",
        onRetry: () {
          ref.invalidate(_sessionsInRangeProvider(range));
          ref.invalidate(_allSessionsProvider);
        },
      );
    }
    if (!sessions.hasValue || !all.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return WorkoutProgressLayout(
      streak: streakData(all.requireValue, DateTime.now()),
      data: workoutProgressData(
        sessions.requireValue,
        range,
        DateTime.now(),
        units,
        exerciseId: _exercise,
        metric: _metric,
      ),
      onExercise: (id) => setState(() => _exercise = id),
      onMetric: (m) => setState(() => _metric = m),
    );
  }
}

/// The weekly streak as of [now]; null without any completed session.
StreakData? streakData(List<SessionDetail> completed, DateTime now) {
  if (completed.isEmpty) return null;
  final s = ActivityStats.streak([
    for (final d in completed) d.toLogged(),
  ], today: now);
  return StreakData(
    current: s.current,
    longest: s.longest,
    thisWeekDone: s.thisWeekDone,
  );
}

/// Maps the sessions in the range (newest first) to the tab's data; null
/// when there are none. [exerciseId] defaults to the most frequent one.
WorkoutProgressData? workoutProgressData(
  List<SessionDetail> newestFirst,
  RangePreset preset,
  DateTime now,
  UnitSystem units, {
  int? exerciseId,
  ExerciseMetric metric = ExerciseMetric.load,
}) {
  if (newestFirst.isEmpty) return null;
  final sessions = newestFirst.reversed.toList();
  final range = Dates.rangeFor(preset, now);

  // Weeks (Sun-Sat) from the range start, or the first session, to now.
  final firstWeek = Dates.startOfWeek(
    range.start ?? sessions.first.session.startedAt,
  );
  final counts = <int>[];
  for (var w = firstWeek; !w.isAfter(now); w = Dates.addDays(w, 7)) {
    final end = Dates.addDays(w, 7);
    counts.add(
      sessions
          .where(
            (s) =>
                !s.session.startedAt.isBefore(w) &&
                s.session.startedAt.isBefore(end),
          )
          .length,
    );
  }
  final summaries = [for (final s in sessions) s.summary];
  final volume = summaries.fold(0.0, (v, s) => v + s.totalVolumeKg);
  final logged = [for (final s in sessions) s.toLogged()];

  // Calendar months from the range start, or the first session, to now.
  final months = ActivityStats.monthlyCounts(
    logged,
    from: range.start ?? sessions.first.session.startedAt,
    to: now,
  );

  // Exercises by how many sessions include them.
  final count = <int, int>{};
  final names = <int, String>{};
  final bodyweight = <int, bool>{};
  for (final s in logged) {
    for (final e in s.exercises) {
      names[e.exerciseId] = e.name; // oldest to newest: latest name wins
      bodyweight[e.exerciseId] = e.isBodyweight;
    }
    for (final id in {for (final e in s.exercises) e.exerciseId}) {
      count[id] = (count[id] ?? 0) + 1;
    }
  }
  final options =
      (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => ExerciseOption(e.key, names[e.key]!))
          .toList();
  final selected = options.any((o) => o.id == exerciseId)
      ? exerciseId
      : options.firstOrNull?.id;
  final isBodyweight = bodyweight[selected] ?? false;
  final m = isBodyweight ? ExerciseMetric.reps : metric;

  final points = <ChartPoint>[];
  if (selected != null) {
    for (final p in WorkoutMath.exerciseHistory(selected, logged)) {
      final best = p.bestSet;
      final double? v = switch (m) {
        ExerciseMetric.load =>
          best?.weightKg == null
              ? null
              : Units.weightForDisplay(best!.weightKg!, units),
        ExerciseMetric.reps => best?.reps.toDouble(),
        ExerciseMetric.volume => Units.weightForDisplay(p.volumeKg, units),
      };
      if (v != null) points.add(ChartPoint(p.date, v));
    }
  }

  final label = DateFormat('d MMM');
  final monthLabel = DateFormat('MMM yyyy');
  final unit = Units.weightUnit(units);
  return WorkoutProgressData(
    range: preset,
    totals: [
      StatItem(label: 'Sessions', value: '${sessions.length}'),
      StatItem(
        label: 'Sets',
        value: '${summaries.fold(0, (n, s) => n + s.completedSets)}',
      ),
      StatItem(
        label: 'Volume',
        value: Formatters.integer(Units.weightForDisplay(volume, units)),
        unit: unit,
      ),
    ],
    weekCounts: counts,
    firstWeekLabel: label.format(firstWeek),
    lastWeekLabel: label.format(Dates.startOfWeek(now)),
    monthCounts: [for (final m in months) m.sessions],
    firstMonthLabel: monthLabel.format(months.first.month),
    lastMonthLabel: monthLabel.format(months.last.month),
    exercises: options,
    selected: selected,
    isBodyweight: isBodyweight,
    metric: m,
    points: points,
    unit: m == ExerciseMetric.reps ? 'reps' : unit,
  );
}
