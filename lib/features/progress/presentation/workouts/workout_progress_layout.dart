import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/widgets/widgets.dart';
import '../charts/chart_helpers.dart';
import '../weight/weight_chart.dart';
import 'weekly_sessions_chart.dart';

enum ExerciseMetric { load, reps, volume }

class ExerciseOption {
  const ExerciseOption(this.id, this.name);

  final int id;
  final String name;
}

/// Weeks in a row with at least one completed workout.
class StreakData {
  const StreakData({
    required this.current,
    required this.longest,
    required this.thisWeekDone,
  });

  final int current;
  final int longest;
  final bool thisWeekDone;
}

class WorkoutProgressData {
  const WorkoutProgressData({
    required this.range,
    required this.totals,
    required this.weekCounts,
    required this.firstWeekLabel,
    required this.lastWeekLabel,
    required this.monthCounts,
    required this.firstMonthLabel,
    required this.lastMonthLabel,
    required this.exercises,
    required this.selected,
    required this.isBodyweight,
    required this.metric,
    required this.points,
    required this.unit,
  });

  final RangePreset range;

  /// Sessions, sets, volume.
  final List<StatItem> totals;
  final List<int> weekCounts;
  final String firstWeekLabel;
  final String lastWeekLabel;

  /// Completed sessions per calendar month, oldest first.
  final List<int> monthCounts;
  final String firstMonthLabel;
  final String lastMonthLabel;

  /// Exercises done in the range, most frequent first.
  final List<ExerciseOption> exercises;
  final int? selected;

  /// Bodyweight exercises are charted by reps only.
  final bool isBodyweight;
  final ExerciseMetric metric;

  /// The selected exercise's values per session, oldest first.
  final List<ChartPoint> points;

  /// "kg", "lb" or "reps".
  final String unit;
}

/// Pure layout for Progress > Workouts.
class WorkoutProgressLayout extends StatelessWidget {
  const WorkoutProgressLayout({
    super.key,
    required this.data,
    required this.onExercise,
    required this.onMetric,
    this.streak,
    this.onHistory,
  });

  /// Null when there are no completed workouts in the range.
  final WorkoutProgressData? data;

  /// Null when there are no completed workouts at all.
  final StreakData? streak;
  final ValueChanged<int> onExercise;
  final ValueChanged<int>? onHistory;
  final ValueChanged<ExerciseMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final d = data;
    final streakCard = streak == null ? null : _StreakCard(streak: streak!);
    if (d == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (streakCard != null) ...[
            streakCard,
            const SizedBox(height: AppSpacing.md),
          ],
          const SectionCard(
            header: CardHeader(title: 'Workouts'),
            child: EmptyChart(message: 'No completed workouts in this range.'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (streakCard != null) ...[
          streakCard,
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          header: const CardHeader(title: 'Sessions per week'),
          footer: StatRow(items: d.totals),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label:
                    'Sessions per week, ${d.weekCounts.length} weeks, '
                    '${d.weekCounts.fold(0, (a, b) => a + b)} sessions',
                child: ExcludeSemantics(
                  child: WeeklySessionsChart(counts: d.weekCounts),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _AxisEnds(first: d.firstWeekLabel, last: d.lastWeekLabel),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: const CardHeader(title: 'Sessions per month'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label:
                    'Sessions per month, ${d.monthCounts.length} months, '
                    '${d.monthCounts.fold(0, (a, b) => a + b)} sessions',
                child: ExcludeSemantics(
                  child: WeeklySessionsChart(counts: d.monthCounts),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _AxisEnds(first: d.firstMonthLabel, last: d.lastMonthLabel),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: CardHeader(
            title: 'Exercise performance',
            trailing: d.selected == null || onHistory == null
                ? null
                : IconButton(
                    tooltip: 'View exercise history',
                    onPressed: () => onHistory!(d.selected!),
                    icon: const Icon(Icons.history),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown<int>(
                label: 'Exercise',
                value: d.selected,
                options: [
                  for (final e in d.exercises) DropdownOption(e.id, e.name),
                ],
                onChanged: onExercise,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!d.isBodyweight)
                SegmentedButton<ExerciseMetric>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ExerciseMetric.load,
                      label: Text('BEST LOAD'),
                    ),
                    ButtonSegment(
                      value: ExerciseMetric.reps,
                      label: Text('REPS'),
                    ),
                    ButtonSegment(
                      value: ExerciseMetric.volume,
                      label: Text('VOLUME'),
                    ),
                  ],
                  selected: {d.metric},
                  onSelectionChanged: (s) => onMetric(s.single),
                )
              else
                Text('Bodyweight exercise: best set by reps.', style: t.label),
              const SizedBox(height: AppSpacing.md),
              if (d.points.length < 2)
                const EmptyChart(
                  message: 'Do this exercise in two sessions to see a trend.',
                  height: 120,
                )
              else
                Semantics(
                  label:
                      '${d.points.length} sessions, latest '
                      '${ChartAxes.valueLabel(d.points.last.value)} ${d.unit}',
                  child: ExcludeSemantics(
                    child: WeightChart(points: d.points, range: d.range),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Volume is load × reps of completed sets. Compare it within '
                'one exercise only; bodyweight sets add reps but no volume.',
                style: t.label,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final StreakData streak;

  String get _note {
    if (streak.thisWeekDone) return 'This week already counts.';
    if (streak.current > 0) return 'Work out this week to keep it going.';
    return 'A week counts when it has at least one workout.';
  }

  @override
  Widget build(BuildContext context) {
    String weeks(int n) => n == 1 ? 'week' : 'weeks';
    return SectionCard(
      header: const CardHeader(title: 'Weekly streak'),
      footer: StatRow(
        items: [
          StatItem(
            label: 'Current',
            value: '${streak.current}',
            unit: weeks(streak.current),
          ),
          StatItem(
            label: 'Longest',
            value: '${streak.longest}',
            unit: weeks(streak.longest),
          ),
        ],
      ),
      child: Text(_note, style: context.textStyles.label),
    );
  }
}

/// The first and last labels under a bar chart; they wrap instead of
/// overflowing at large font sizes.
class _AxisEnds extends StatelessWidget {
  const _AxisEnds({required this.first, required this.last});

  final String first;
  final String last;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(first, style: t.label)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(last, style: t.label, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
