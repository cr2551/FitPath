import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../nutrition/application/diary_providers.dart';
import '../../../nutrition/domain/nutrition_math.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/home_selected_date_provider.dart';
import 'calories_macros_card_view.dart';
import 'calories_macros_view_data.dart';

/// Completed workouts in the week starting on the keyed day.
///
/// Queries the table directly until the workout repository (#15) offers a
/// count for a date range.
final _completedWorkoutsInWeekProvider = StreamProvider.family<int, String>((
  ref,
  weekStartKey,
) {
  final db = ref.watch(appDatabaseProvider);
  final start = Dates.fromLocalDateKey(weekStartKey);
  final s = db.workoutSessions;
  final count = s.id.count();
  final query = db.selectOnly(s)
    ..addColumns([count])
    ..where(
      s.status.equalsValue(WorkoutStatus.completed) &
          s.completedAt.isBiggerOrEqualValue(start) &
          s.completedAt.isSmallerThanValue(Dates.addDays(start, 7)),
    );
  return query.map((row) => row.read(count) ?? 0).watchSingle();
});

/// The main Home card: calories eaten on the Home selected day against the
/// goal in effect that day, split by macro.
class CaloriesMacrosCard extends ConsumerWidget {
  const CaloriesMacrosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(homeSelectedDateProvider);
    final key = Dates.localDateKey(day);
    final weekKey = Dates.localDateKey(Dates.startOfWeek(day));
    final summary = ref.watch(dailySummaryProvider(key));
    final target = ref.watch(targetsForDateProvider(key));
    final workouts = ref.watch(_completedWorkoutsInWeekProvider(weekKey));
    final all = <AsyncValue<Object?>>[summary, target, workouts];

    if (all.any((v) => v.hasError)) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load calories.",
          onRetry: () => ref
            ..invalidate(dailySummaryProvider(key))
            ..invalidate(targetsForDateProvider(key))
            ..invalidate(_completedWorkoutsInWeekProvider(weekKey)),
        ),
      );
    }
    if (!all.every((v) => v.hasValue)) {
      return const SectionCard(
        child: SizedBox(
          height: 166,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final data = caloriesMacrosViewData(
      summary: summary.requireValue,
      target: target.requireValue,
      day: day,
      today: DateTime.now(),
      workoutsInWeek: workouts.requireValue,
    );
    return CaloriesMacrosCardView(
      data: data,
      onTap: () => context.go(Routes.nutritionDay(day)),
      onSetGoal: data.goalKcal == null
          ? () => context.go(Routes.targets)
          : null,
    );
  }
}

/// Maps one day's diary summary and targets to the card's view data.
CaloriesMacrosViewData caloriesMacrosViewData({
  required DailyNutritionSummary summary,
  required NutritionTarget? target,
  required DateTime day,
  required DateTime today,
  required int workoutsInWeek,
}) {
  final total = summary.total;
  final split = summary.split;
  final progress = CalorieProgress(
    eatenKcal: total.kcal,
    targetKcal: target?.calories.toDouble(),
  );
  final goal = progress.hasTarget ? progress.targetKcal : null;
  final isToday = Dates.isSameDay(day, today);
  final onDay = isToday ? 'today' : 'on ${DateFormat('EEE d MMM').format(day)}';
  final hasSplit = split.total > 0;

  final CalorieStatus status;
  if (total.isEmpty) {
    status = CalorieStatus(
      text: isToday ? 'Log your first meal' : 'Nothing logged $onDay',
    );
  } else if (goal == null) {
    status = CalorieStatus(
      number: Formatters.integer(total.kcal),
      text: 'kcal eaten $onDay',
    );
  } else if (progress.state == CalorieState.over) {
    status = CalorieStatus(
      number: Formatters.integer(progress.overKcal),
      text: 'kcal over $onDay',
      over: true,
    );
  } else {
    status = CalorieStatus(
      number: Formatters.integer(progress.remainingKcal),
      text: 'kcal remaining $onDay',
    );
  }

  final eaten = Formatters.integer(total.kcal);
  final String calories;
  if (goal == null) {
    calories = '$eaten calories eaten, no calorie goal.';
  } else if (progress.state == CalorieState.over) {
    calories =
        '$eaten of ${Formatters.integer(goal)} calories eaten, '
        '${Formatters.integer(progress.overKcal)} over.';
  } else {
    calories =
        '$eaten of ${Formatters.integer(goal)} calories eaten, '
        '${Formatters.integer(progress.remainingKcal)} left.';
  }
  String pct(double share) => '${(share * 100).round()} percent';
  final shares = hasSplit
      ? ' Protein ${pct(split.proteinShare)}, carbs ${pct(split.carbsShare)}, '
            'fat ${pct(split.fatShare)}'
            '${split.unknownKcal > 0 ? ', unknown ${pct(split.unknownShare)}' : ''}.'
      : '';

  final meals = summary.mealsLogged;
  final week = Dates.isSameDay(Dates.startOfWeek(day), Dates.startOfWeek(today))
      ? 'this week'
      : 'that week';

  return CaloriesMacrosViewData(
    title: goal == null
        ? 'Set a calorie goal'
        : 'Calorie goal: ${Formatters.energy(goal)}',
    status: status,
    eatenKcal: total.kcal,
    goalKcal: goal,
    eatenLabel: eaten,
    segments: RingKcal(
      protein: split.proteinKcal,
      carbs: split.carbsKcal,
      fat: split.fatKcal,
      unknown: split.unknownKcal,
    ),
    macros: [
      MacroLegendData(
        kind: MacroKind.protein,
        label: 'Protein',
        consumedG: total.proteinG,
        targetG: target?.proteinG,
        share: hasSplit ? split.proteinShare : null,
      ),
      MacroLegendData(
        kind: MacroKind.carbs,
        label: 'Carbs',
        consumedG: total.carbsG,
        targetG: target?.carbsG,
        share: hasSplit ? split.carbsShare : null,
      ),
      MacroLegendData(
        kind: MacroKind.fat,
        label: 'Fat',
        consumedG: total.fatG,
        targetG: target?.fatG,
        share: hasSplit ? split.fatShare : null,
      ),
    ],
    unknown: split.unknownKcal > 0
        ? UnknownLegendData(
            kcalLabel: Formatters.energy(split.unknownKcal),
            share: split.unknownShare,
          )
        : null,
    mealsLabel: switch (meals) {
      0 => 'No meals',
      1 => '1 meal',
      _ => '$meals meals',
    },
    workoutsLabel: switch (workoutsInWeek) {
      0 => 'No workouts $week',
      1 => '1 workout $week',
      _ => '$workoutsInWeek workouts $week',
    },
    semanticsLabel: '$calories$shares',
  );
}
