import 'package:flutter/widgets.dart';

import '../../../core/router/placeholder_screen.dart';

/// The report for one Sunday-Saturday week, compared with the week before.
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key, this.weekStart});

  /// Any day of the week to show; null means last week.
  final DateTime? weekStart;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Weekly report', issue: 113);
}
