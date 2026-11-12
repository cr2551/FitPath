import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/workout_providers.dart';
import '../../domain/strength_stats.dart';
import '../../domain/workout_math.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise history')),
      body: SafeArea(
        child: AsyncValueView(
          value: ref.watch(completedWorkoutHistoryProvider),
          onRetry: () => ref.invalidate(completedWorkoutHistoryProvider),
          errorMessage: 'Could not load exercise history.',
          data: (history) {
            final sessions = history.map((s) => s.toLogged()).toList();
            final recent = [
              for (final session in sessions)
                for (final exercise in session.exercises)
                  if (exercise.exerciseId == exerciseId)
                    for (final set in exercise.sets)
                      if (set.completed)
                        (date: session.startedAt, exercise: exercise, set: set),
            ];
            return ExerciseHistoryView(
              records: StrengthStats.records(exerciseId, sessions),
              estimates: StrengthStats.oneRepMaxHistory(exerciseId, sessions),
              recent: recent.take(20).toList(),
              units: units,
            );
          },
        ),
      ),
    );
  }
}

class ExerciseHistoryView extends StatelessWidget {
  const ExerciseHistoryView({
    super.key,
    required this.records,
    required this.estimates,
    required this.recent,
    required this.units,
  });

  final ExerciseRecords records;
  final List<OneRepMaxPoint> estimates;
  final List<({DateTime date, LoggedExercise exercise, LoggedSet set})> recent;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final colors = context.fitColors;
    final exercise = recent.firstOrNull?.exercise;
    double display(double kg) => Units.weightForDisplay(kg, units);
    String weight(double kg) =>
        '${display(kg).toStringAsFixed(1)} ${Units.weightUnit(units)}';
    String date(DateTime date) => DateFormat.yMMMd().format(date.toLocal());
    Widget record(String label, RecordSet set, String value) => ListTile(
      title: Text(label),
      subtitle: Text('$value · ${date(set.date)}'),
    );
    LineChartBarData series(
      double Function(OneRepMax) value,
      Color color,
      List<int> dash,
    ) => LineChartBarData(
      spots: [
        for (final point in estimates)
          FlSpot(
            point.date.difference(estimates.first.date).inMinutes / 1440,
            display(value(point.estimate)),
          ),
      ],
      color: color,
      dashArray: dash,
      barWidth: 2,
    );

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        if (exercise != null) ScreenHeader(title: exercise.name),
        SectionCard(
          header: const CardHeader(title: 'Personal records'),
          child: Column(
            children: [
              if (records.isEmpty)
                const EmptyState(message: 'No personal records yet.'),
              if (records.heaviestLoad case final set?)
                record('Heaviest load', set, weight(set.weightKg!)),
              if (records.bestVolume case final set?)
                record('Best set volume', set, weight(set.volumeKg!)),
              if (records.bestOneRepMax case final set?)
                record(
                  'Best estimated 1RM',
                  set,
                  'Epley ${weight(set.oneRepMax!.epleyKg)} · Brzycki ${weight(set.oneRepMax!.brzyckiKg)}',
                ),
              if (records.mostReps case final set?)
                record('Most reps', set, '${set.reps} reps'),
              for (final entry in records.repsAtLoad.entries)
                record(
                  'Most reps at ${weight(entry.key)}',
                  entry.value,
                  '${entry.value.reps} reps',
                ),
            ],
          ),
        ),
        SectionCard(
          header: const CardHeader(title: 'Estimated one-rep max'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (estimates.isEmpty)
                EmptyState(
                  message: exercise?.isBodyweight == true
                      ? 'Bodyweight exercises track rep records because there is no comparable lifting load.'
                      : 'Log a loaded set with 1–10 reps to see both estimates.',
                )
              else ...[
                const Text('Epley (long dashes) · Brzycki (short dashes)'),
                Semantics(
                  label: 'Estimated one-rep max over time. Values for both formulas are listed below.',
                  child: SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          series((e) => e.epleyKg, colors.ink, [8, 4]),
                          series((e) => e.brzyckiKg, colors.accent, [3, 4]),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final point in estimates.reversed.take(5))
                  ListTile(
                    title: Text(date(point.date)),
                    subtitle: Text(
                      'Epley ${weight(point.estimate.epleyKg)} · Brzycki ${weight(point.estimate.brzyckiKg)}',
                    ),
                  ),
              ],
            ],
          ),
        ),
        SectionCard(
          header: const CardHeader(title: 'Recent sets'),
          child: Column(
            children: [
              if (recent.isEmpty)
                const EmptyState(message: 'No completed sets yet.'),
              for (final row in recent)
                ListTile(
                  title: Text(
                    '${row.set.reps ?? '–'} reps${row.set.weightKg == null ? '' : ' · ${weight(row.set.weightKg!)}'}',
                  ),
                  subtitle: Text(date(row.date)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
