import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../progress/application/progress_range_provider.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import '../../../workouts/domain/activity_stats.dart';
import 'card_loading.dart';
import 'streak_card_view.dart';

/// Home "Streak": weeks in a row with a workout. Tapping opens
/// Progress > Workouts.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(completedWorkoutHistoryProvider);
    if (sessions.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your workouts.",
          onRetry: () => ref.invalidate(completedWorkoutHistoryProvider),
        ),
      );
    }
    if (!sessions.hasValue) return const CardLoading();
    return StreakCardView(
      data: streakCardData(sessions.requireValue, DateTime.now()),
      onTap: () {
        ref.read(progressTabProvider.notifier).select(ProgressTab.workouts);
        context.go(Routes.progress);
      },
    );
  }
}

/// The streak as of [now]; null before the first completed workout.
StreakCardData? streakCardData(List<SessionDetail> completed, DateTime now) {
  if (completed.isEmpty) return null;
  final s = ActivityStats.streak([
    for (final d in completed) d.toLogged(),
  ], today: now);
  return StreakCardData(
    current: s.current,
    longest: s.longest,
    thisWeek: s.thisWeekDone
        ? 'This week counts already.'
        : s.current > 0
        ? 'Work out this week to keep it going.'
        : 'A week counts when it has at least one workout.',
    thisWeekDone: s.thisWeekDone,
  );
}
