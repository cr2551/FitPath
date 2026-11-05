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

class WorkoutProgressData {
  const WorkoutProgressData({
    required this.range,
    required this.totals,
    required this.weekCounts,
    required this.firstWeekLabel,
    required this.lastWeekLabel,
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
  });

  final WorkoutProgressData? data;
  final ValueChanged<int> onExercise;
  final ValueChanged<ExerciseMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final d = data;
    if (d == null) {
      return const SectionCard(
        header: CardHeader(title: 'Workouts'),
        child: EmptyChart(message: 'No completed workouts in this range.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              Row(
                children: [
                  Text(d.firstWeekLabel, style: t.label),
                  const Spacer(),
                  Text(d.lastWeekLabel, style: t.label),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: const CardHeader(title: 'Exercise performance'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                elevation: 0,
                dropdownColor: Theme.of(context).colorScheme.surface,
                initialValue: d.selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Exercise'),
                items: [
                  for (final e in d.exercises)
                    DropdownMenuItem(value: e.id, child: Text(e.name)),
                ],
                onChanged: (id) {
                  if (id != null) onExercise(id);
                },
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
