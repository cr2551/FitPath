import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #24, which owns this file.
class DayOverviewScreen extends StatelessWidget {
  const DayOverviewScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Nutrition', issue: 24);
}
