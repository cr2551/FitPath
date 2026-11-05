import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../nutrition/application/diary_providers.dart';
import '../../../nutrition/domain/nutrition_math.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import 'workout_summary_card.dart' show dashboardSessionLimit;

/// Home "Activity overview": the last 7 days, marking days with a workout
/// and days with food logged.
class ActivityOverviewCard extends ConsumerWidget {
  const ActivityOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider(dashboardSessionLimit));
    final food = ref.watch(dailyTotalsProvider(RangePreset.days7));
    if (sessions.hasError || food.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your activity.",
          onRetry: () => ref
            ..invalidate(recentSessionsProvider(dashboardSessionLimit))
            ..invalidate(dailyTotalsProvider(RangePreset.days7)),
        ),
      );
    }
    if (!sessions.hasValue || !food.hasValue) {
      return const SectionCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ActivityOverviewCardView(
      days: activityDays(
        sessions.requireValue,
        food.requireValue,
        DateTime.now(),
      ),
    );
  }
}

class ActivityDay {
  const ActivityDay({
    required this.letter,
    required this.label,
    required this.workout,
    required this.food,
  });

  /// "M"
  final String letter;

  /// "Monday 2 November", for screen readers.
  final String label;
  final bool workout;
  final bool food;

  bool get active => workout || food;
}

/// The 7 days ending today, oldest first.
List<ActivityDay> activityDays(
  List<SessionDetail> sessions,
  Map<String, NutrientTotals> foodByDay,
  DateTime now,
) {
  final today = Dates.startOfDay(now);
  return [
    for (var i = 6; i >= 0; i--)
      _day(Dates.addDays(today, -i), sessions, foodByDay),
  ];
}

ActivityDay _day(
  DateTime day,
  List<SessionDetail> sessions,
  Map<String, NutrientTotals> foodByDay,
) => ActivityDay(
  letter: DateFormat('EEEEE').format(day),
  label: DateFormat('EEEE d MMMM').format(day),
  workout: sessions.any((s) => Dates.isSameDay(s.session.startedAt, day)),
  food: !(foodByDay[Dates.localDateKey(day)]?.isEmpty ?? true),
);

/// Pure layout: one column per day with a workout square (ink) and a food
/// square (carbs green), then a legend.
class ActivityOverviewCardView extends StatelessWidget {
  const ActivityOverviewCardView({super.key, required this.days});

  final List<ActivityDay> days;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final active = days.where((d) => d.active).length;
    Widget mark(bool on, Color color) =>
        Container(height: 14, color: on ? color : c.subtle);
    return SectionCard(
      header: CardHeader(
        title: 'Activity overview',
        trailing: Text('$active of 7 days active', style: t.label),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    label:
                        '${days[i].label}: '
                        '${days[i].workout ? 'workout' : 'no workout'}, '
                        '${days[i].food ? 'food logged' : 'no food logged'}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          mark(days[i].workout, c.ink),
                          const SizedBox(height: 2),
                          mark(days[i].food, c.carbs),
                          const SizedBox(height: AppSpacing.xs),
                          Text(days[i].letter, style: t.overline),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Key(color: c.ink, label: 'Workout'),
              const SizedBox(width: AppSpacing.lg),
              _Key(color: c.carbs, label: 'Food logged'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(dimension: 10, child: ColoredBox(color: color)),
      const SizedBox(width: AppSpacing.xs + 2),
      Text(label, style: context.textStyles.label),
    ],
  );
}
