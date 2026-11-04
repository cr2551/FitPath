import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #30, which owns this file.
class CustomExerciseScreen extends StatelessWidget {
  const CustomExerciseScreen({super.key, this.exerciseId});

  final int? exerciseId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Custom exercise', issue: 30);
}
