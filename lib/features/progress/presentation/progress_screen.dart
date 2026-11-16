import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../application/progress_range_provider.dart';
import 'nutrition/nutrition_progress_view.dart';
import 'progress_view.dart';
import 'weight/weight_progress_view.dart';
import 'workouts/workout_progress_view.dart';

/// The Progress tab. The range (`progressRangeProvider`) is shared by all
/// three datasets and the dataset is `progressTabProvider`; each tab body
/// reads its own data.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(progressTabProvider);
    return ProgressView(
      tab: tab,
      range: ref.watch(progressRangeProvider),
      body: switch (tab) {
        ProgressTab.weight => const WeightProgressView(),
        ProgressTab.nutrition => const NutritionProgressView(),
        ProgressTab.workouts => const WorkoutProgressView(),
      },
      onTabChanged: ref.read(progressTabProvider.notifier).select,
      onRangeChanged: ref.read(progressRangeProvider.notifier).select,
      onWeeklyReport: () => context.push(Routes.weeklyReport()),
    );
  }
}
