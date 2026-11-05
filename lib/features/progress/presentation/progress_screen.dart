import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/progress_range_provider.dart';
import 'nutrition/nutrition_progress_view.dart';
import 'progress_view.dart';
import 'weight/weight_progress_view.dart';
import 'workouts/workout_progress_view.dart';

/// The Progress tab. The range is shared by all three datasets
/// (`progressRangeProvider`); each tab body reads its own data.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  var _tab = ProgressTab.weight;

  @override
  Widget build(BuildContext context) {
    return ProgressView(
      tab: _tab,
      range: ref.watch(progressRangeProvider),
      body: switch (_tab) {
        ProgressTab.weight => const WeightProgressView(),
        ProgressTab.nutrition => const NutritionProgressView(),
        ProgressTab.workouts => const WorkoutProgressView(),
      },
      onTabChanged: (t) => setState(() => _tab = t),
      onRangeChanged: ref.read(progressRangeProvider.notifier).select,
    );
  }
}
