import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/progress_range_provider.dart';
import 'weight_chart.dart';
import 'weight_entry_dialog.dart';
import 'weight_progress_layout.dart';

/// Progress > Weight: chart, change and stats over the selected range, and
/// the entries, each editable. Values are stored in kg and shown in the
/// user's units.
class WeightProgressView extends ConsumerWidget {
  const WeightProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(progressRangeProvider);
    final entries = ref.watch(weightEntriesProvider(range));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final goals = ref.watch(activeGoalsProvider).value ?? const [];
    final target = goals.where((g) => g.isPrimary).firstOrNull?.targetWeightKg;
    final repo = ref.read(profileRepositoryProvider);

    if (entries.hasError) {
      return ErrorState(
        message: "Couldn't load your weight history.",
        onRetry: () => ref.invalidate(weightEntriesProvider(range)),
      );
    }
    if (!entries.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final list = entries.requireValue;

    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save the weight.")),
        );
      }
    }

    return WeightProgressLayout(
      data: weightProgressData(list, range, units, target),
      onLog: () async {
        final r = await showWeightEntryDialog(
          context,
          units: units,
          initialKg: list.firstOrNull?.weightKg,
        );
        if (r is SaveWeight) {
          await guard(() => repo.logWeight(r.kg, at: r.at, notes: r.notes));
        }
      },
      onEdit: (id) async {
        final e = list.firstWhere((x) => x.id == id);
        final r = await showWeightEntryDialog(
          context,
          units: units,
          initialKg: e.weightKg,
          initialAt: e.recordedAt,
          initialNotes: e.notes,
          editing: true,
        );
        switch (r) {
          case SaveWeight():
            await guard(
              () => repo.updateWeight(
                id,
                kg: r.kg,
                at: r.at,
                notes: r.notes ?? '',
              ),
            );
          case DeleteWeight():
            await guard(() => repo.deleteWeight(id));
          case null:
        }
      },
    );
  }
}

/// Maps entries in range (newest first) to the tab's data.
WeightProgressData weightProgressData(
  List<WeightEntry> newestFirst,
  RangePreset range,
  UnitSystem units,
  double? targetKg,
) {
  double show(double kg) => Units.weightForDisplay(kg, units);
  String fmt(double v) => v.toStringAsFixed(1);
  final unit = Units.weightUnit(units);
  final oldestFirst = newestFirst.reversed.toList();
  final values = [for (final e in oldestFirst) show(e.weightKg)];

  String? change;
  var down = false, toward = false;
  if (values.length >= 2) {
    final delta = values.last - values.first;
    change = '${fmt(delta.abs())} $unit';
    down = delta < 0;
    toward =
        targetKg != null &&
        delta != 0 &&
        (show(targetKg) - values.first).sign == delta.sign;
  }

  final time = DateFormat('HH:mm');
  return WeightProgressData(
    range: range,
    unit: unit,
    current: values.isEmpty ? null : fmt(values.last),
    change: change,
    changeDown: down,
    changeTowardGoal: toward,
    points: [
      for (var i = 0; i < oldestFirst.length; i++)
        ChartPoint(oldestFirst[i].recordedAt, values[i]),
    ],
    target: targetKg == null ? null : show(targetKg),
    targetLabel: targetKg == null
        ? null
        : 'Target ${fmt(show(targetKg))} $unit',
    stats: values.isEmpty
        ? const []
        : [
            StatItem(label: 'Start', value: fmt(values.first)),
            StatItem(
              label: 'Lowest',
              value: fmt(values.reduce((a, b) => a < b ? a : b)),
            ),
            StatItem(
              label: 'Average',
              value: fmt(values.reduce((a, b) => a + b) / values.length),
            ),
          ],
    rows: [
      for (final e in newestFirst)
        WeightRowData(
          id: e.id,
          date: DateFormat('EEE d MMM').format(e.recordedAt),
          detail: [
            time.format(e.recordedAt),
            if (e.notes != null && e.notes!.isNotEmpty) e.notes!,
          ].join(' · '),
          value: fmt(show(e.weightKg)),
        ),
    ],
  );
}
