import 'package:flutter/widgets.dart';

import '../../../../core/router/placeholder_screen.dart';

/// Personal records and estimated 1RM history for one exercise.
class ExerciseHistoryScreen extends StatelessWidget {
  const ExerciseHistoryScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Exercise history', issue: 110);
}
