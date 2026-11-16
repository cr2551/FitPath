import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class WeeklyReportCardData {
  const WeeklyReportCardData({
    required this.week,
    required this.stats,
    required this.previous,
  });

  /// E.g. "8 – 14 Nov 2026".
  final String week;

  /// Average intake, workouts, weight change; empty when nothing was
  /// logged that week.
  final List<StatItem> stats;

  /// E.g. "Week before: 1,900 kcal · 2 workouts · −0.2 kg".
  final String? previous;

  bool get isEmpty => stats.isEmpty;
}

/// Pure layout for the "Last week's report" card.
class WeeklyReportCardView extends StatelessWidget {
  const WeeklyReportCardView({
    super.key,
    required this.data,
    required this.onTap,
  });

  final WeeklyReportCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final d = data;
    return SectionCard(
      onTap: onTap,
      header: CardHeader(
        title: "Last week's report",
        subtitle: TextSpan(text: d.week),
        icon: Icons.summarize_outlined,
      ),
      child: d.isEmpty
          ? Text('Nothing logged last week.', style: t.label)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatRow(items: d.stats),
                if (d.previous != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(d.previous!, style: t.label),
                ],
              ],
            ),
    );
  }
}
