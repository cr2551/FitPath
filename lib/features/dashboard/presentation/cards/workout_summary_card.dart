import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';

/// Enough completed sessions for every workout card (a week, the last
/// sessions, progression).
const dashboardSessionLimit = 30;

/// Home "Workouts this week": training days, sessions (against the weekly
/// training days from the profile, when set), completed sets and volume.
class WorkoutSummaryCard extends ConsumerWidget {
  const WorkoutSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider(dashboardSessionLimit));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final perWeek = ref.watch(profileProvider).value?.trainingFrequencyPerWeek;
    if (sessions.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your workouts.",
          onRetry: () =>
              ref.invalidate(recentSessionsProvider(dashboardSessionLimit)),
        ),
      );
    }
    if (!sessions.hasValue) return const _LoadingCard();
    return WorkoutSummaryCardView(
      data: workoutSummaryData(
        sessions.requireValue,
        DateTime.now(),
        units,
        perWeek,
      ),
      onTap: () => context.go(Routes.workouts),
    );
  }
}

class WorkoutSummaryData {
  const WorkoutSummaryData({
    required this.headline,
    required this.dayLetters,
    required this.trained,
    required this.todayIndex,
    required this.stats,
  });

  /// "3 of 4 sessions" or "3 sessions".
  final String headline;
  final List<String> dayLetters;

  /// Per day of the week, whether a session was completed.
  final List<bool> trained;
  final int todayIndex;

  /// Sessions, sets, volume.
  final List<StatItem> stats;
}

WorkoutSummaryData workoutSummaryData(
  List<SessionDetail> sessions,
  DateTime now,
  UnitSystem units,
  int? perWeekTarget,
) {
  final week = Dates.weekOf(now);
  final end = Dates.addDays(week.first, 7);
  final inWeek = [
    for (final s in sessions)
      if (!s.session.startedAt.isBefore(week.first) &&
          s.session.startedAt.isBefore(end))
        s,
  ];
  final summaries = [for (final s in inWeek) s.summary];
  final sets = summaries.fold(0, (n, s) => n + s.completedSets);
  final volume = summaries.fold(0.0, (n, s) => n + s.totalVolumeKg);
  final n = inWeek.length;
  return WorkoutSummaryData(
    headline: perWeekTarget != null && perWeekTarget > 0
        ? '$n of $perWeekTarget sessions'
        : '$n ${n == 1 ? 'session' : 'sessions'}',
    dayLetters: [for (final d in week) DateFormat('EEEEE').format(d)],
    trained: [
      for (final d in week)
        inWeek.any((s) => Dates.isSameDay(s.session.startedAt, d)),
    ],
    todayIndex: week.indexWhere((d) => Dates.isSameDay(d, now)),
    stats: [
      StatItem(label: 'Sessions', value: '$n'),
      StatItem(label: 'Sets', value: '$sets'),
      StatItem(
        label: 'Volume',
        value: Formatters.integer(Units.weightForDisplay(volume, units)),
        unit: Units.weightUnit(units),
      ),
    ],
  );
}

/// Pure layout for the "Workouts this week" card (DESIGN/home.html).
class WorkoutSummaryCardView extends StatelessWidget {
  const WorkoutSummaryCardView({
    super.key,
    required this.data,
    required this.onTap,
  });

  final WorkoutSummaryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    return SectionCard(
      onTap: onTap,
      header: CardHeader(
        title: 'Workouts this week',
        icon: Icons.fitness_center_outlined,
        trailing: Text(d.headline, style: t.label),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'Trained on ${d.trained.where((x) => x).length} days this week',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: d.trained[i]
                                  ? c.ink
                                  : (i == d.todayIndex ? c.surface : c.subtle),
                              border: i == d.todayIndex && !d.trained[i]
                                  ? Border.all(color: c.ink, width: 2)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            d.dayLetters[i],
                            style: t.overline.copyWith(
                              color: i == d.todayIndex ? c.ink : c.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: AppSpacing.xl),
          StatRow(items: d.stats),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: SizedBox(
      height: 64,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
