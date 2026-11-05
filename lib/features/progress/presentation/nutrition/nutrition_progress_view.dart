import 'dart:math' as math;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../nutrition/application/diary_providers.dart';
import '../../../nutrition/domain/nutrition_math.dart';
import '../../application/progress_range_provider.dart';
import 'daily_calories_chart.dart';
import 'nutrition_progress_layout.dart';

/// Every target row, oldest first, to find the target in effect on each
/// past day.
final _targetHistoryProvider = StreamProvider<List<NutritionTarget>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.nutritionTargets)..orderBy([
        (t) => OrderingTerm.asc(t.effectiveFrom),
        (t) => OrderingTerm.asc(t.id),
      ]))
      .watch();
});

/// Progress > Nutrition: daily calories stacked by macro against the target
/// in effect each day, averages over the logged days, and the logged days.
/// Tapping a day opens it in the Nutrition tab.
class NutritionProgressView extends ConsumerWidget {
  const NutritionProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(progressRangeProvider);
    final totals = ref.watch(dailyTotalsProvider(range));
    final targets = ref.watch(_targetHistoryProvider);

    if (totals.hasError || targets.hasError) {
      return ErrorState(
        message: "Couldn't load your nutrition history.",
        onRetry: () => ref
          ..invalidate(dailyTotalsProvider(range))
          ..invalidate(_targetHistoryProvider),
      );
    }
    if (!totals.hasValue || !targets.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return NutritionProgressLayout(
      data: nutritionProgressData(
        totals.requireValue,
        targets.requireValue,
        Dates.rangeFor(range, DateTime.now()),
      ),
      onDay: (day) => context.go(Routes.nutritionDay(day)),
    );
  }
}

/// The target row in effect on [dateKey]: the newest whose effectiveFrom is
/// on or before it. [history] is oldest first.
NutritionTarget? targetOn(List<NutritionTarget> history, String dateKey) {
  NutritionTarget? found;
  for (final t in history) {
    if (t.effectiveFrom.compareTo(dateKey) > 0) break;
    found = t;
  }
  return found;
}

/// Maps logged daily totals (keyed by date) and the target history to the
/// tab's data. Days run from the range start (or the first logged day for
/// "All") to the range end.
NutritionProgressData nutritionProgressData(
  Map<String, NutrientTotals> byDay,
  List<NutritionTarget> targetHistory,
  DateRange range,
) {
  final logged = byDay.entries.where((e) => !e.value.isEmpty).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (logged.isEmpty) {
    return const NutritionProgressData(
      bars: [],
      firstLabel: '',
      lastLabel: '',
      stats: [],
      macroStats: [],
      rows: [],
    );
  }

  final first = range.start ?? Dates.fromLocalDateKey(logged.first.key);
  final last = Dates.addDays(range.end, -1);
  final days = <DateTime>[
    for (
      var d = Dates.startOfDay(first);
      !d.isAfter(last);
      d = Dates.addDays(d, 1)
    )
      d,
  ];

  DayBar bar(DateTime day) {
    final key = Dates.localDateKey(day);
    final t = byDay[key];
    final target = targetOn(targetHistory, key)?.calories.toDouble();
    if (t == null || t.isEmpty) {
      return DayBar(
        day: day,
        proteinKcal: 0,
        carbsKcal: 0,
        fatKcal: 0,
        unknownKcal: 0,
        targetKcal: target,
      );
    }
    final p = t.proteinG * KcalPerGram.protein;
    final c = t.carbsG * KcalPerGram.carbs;
    final f = t.fatG * KcalPerGram.fat;
    return DayBar(
      day: day,
      proteinKcal: p,
      carbsKcal: c,
      fatKcal: f,
      unknownKcal: math.max(0, t.kcal - (p + c + f)),
      targetKcal: target,
    );
  }

  double avg(double Function(NutrientTotals t) f) =>
      logged.fold<double>(0, (s, e) => s + f(e.value)) / logged.length;
  final label = DateFormat('d MMM');

  return NutritionProgressData(
    bars: [for (final d in days) bar(d)],
    firstLabel: label.format(days.first),
    lastLabel: label.format(days.last),
    stats: [
      StatItem(
        label: 'Average',
        value: Formatters.integer(avg((t) => t.kcal)),
        unit: 'kcal',
      ),
      StatItem(
        label: 'Days logged',
        value: '${logged.length} of ${days.length}',
      ),
    ],
    macroStats: [
      StatItem(
        label: 'Protein',
        value: Formatters.integer(avg((t) => t.proteinG)),
        unit: 'g',
      ),
      StatItem(
        label: 'Carbs',
        value: Formatters.integer(avg((t) => t.carbsG)),
        unit: 'g',
      ),
      StatItem(
        label: 'Fat',
        value: Formatters.integer(avg((t) => t.fatG)),
        unit: 'g',
      ),
    ],
    rows: [
      for (final e in logged.reversed)
        _row(e.key, e.value, targetOn(targetHistory, e.key)?.calories),
    ],
  );
}

DaySummaryRow _row(String key, NutrientTotals t, int? target) {
  final day = Dates.fromLocalDateKey(key);
  final kcal = Formatters.integer(t.kcal);
  return DaySummaryRow(
    day: day,
    date: DateFormat('EEE d MMM').format(day),
    macros:
        'P ${Formatters.integer(t.proteinG)} · '
        'C ${Formatters.integer(t.carbsG)} · '
        'F ${Formatters.integer(t.fatG)} g',
    kcal: target == null ? kcal : '$kcal / ${Formatters.integer(target)}',
    overTarget: target != null && t.kcal > target,
  );
}
