import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// PLACEHOLDER created by #36 (Progress shell). Replaced by #39, which owns
/// this file. Reads `progressRangeProvider` for the selected range.
class WorkoutProgressView extends StatelessWidget {
  const WorkoutProgressView({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    header: CardHeader(title: 'Workouts'),
    child: EmptyState(message: 'Coming in #39'),
  );
}
