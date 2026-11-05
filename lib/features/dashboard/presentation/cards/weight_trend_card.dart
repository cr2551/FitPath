import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/presentation/log_weight_dialog.dart';
import 'weight_trend_card_view.dart';

/// Home weight card: latest weight, change over the last 30 days and a
/// sparkline, with a quick "Log" action.
class WeightTrendCard extends ConsumerWidget {
  const WeightTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightEntriesProvider(RangePreset.days30));
    final latest = ref.watch(currentWeightProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final goals = ref.watch(activeGoalsProvider).value ?? const [];
    final target = goals.where((g) => g.isPrimary).firstOrNull?.targetWeightKg;

    if (entries.hasError || latest.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your weight.",
          onRetry: () =>
              ref.invalidate(weightEntriesProvider(RangePreset.days30)),
        ),
      );
    }
    if (!entries.hasValue || !latest.hasValue) {
      return const SectionCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return WeightTrendCardView(
      data: weightTrendViewData(
        entries: entries.requireValue,
        latestKg: latest.requireValue,
        units: units,
        targetKg: target,
      ),
      onTap: () => context.go(Routes.progress),
      onLog: () async {
        final kg = await showLogWeightDialog(
          context,
          units: units,
          initialKg: latest.value,
        );
        if (kg != null) {
          await ref.read(profileRepositoryProvider).logWeight(kg);
        }
      },
    );
  }
}

/// Maps the last 30 days of entries (newest first) to the card's data.
WeightTrendViewData weightTrendViewData({
  required List<WeightEntry> entries,
  required double? latestKg,
  required UnitSystem units,
  required double? targetKg,
}) {
  String fmt(double kg) => Units.weightForDisplay(kg, units).toStringAsFixed(1);
  final unit = Units.weightUnit(units);
  final oldestFirst = entries.reversed.toList();

  WeightChange? change;
  if (oldestFirst.length >= 2) {
    final first = oldestFirst.first.weightKg, last = oldestFirst.last.weightKg;
    final delta = last - first;
    change = WeightChange(
      label: '${fmt(delta.abs())} $unit · last 30 days',
      down: delta < 0,
      towardGoal:
          targetKg != null &&
          delta != 0 &&
          (targetKg - first).sign == delta.sign,
    );
  }

  return WeightTrendViewData(
    value: latestKg == null ? null : fmt(latestKg),
    unit: unit,
    change: change,
    points: [
      for (final e in oldestFirst) Units.weightForDisplay(e.weightKg, units),
    ],
  );
}
