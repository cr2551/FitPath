import 'package:flutter/material.dart';

import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class NutritionSummaryViewData {
  const NutritionSummaryViewData({
    required this.averageKcal,
    required this.targetKcal,
    required this.daysLogged,
    required this.overTarget,
  });

  /// "1,850"; null when nothing was logged in the last 7 days.
  final String? averageKcal;

  /// "2,100"; "—" without a target.
  final String targetKcal;

  /// "5 of 7"
  final String daysLogged;

  /// The average is above the target (shown in the warning color).
  final bool overTarget;
}

/// Pure layout for the Home nutrition summary card.
class NutritionSummaryCardView extends StatelessWidget {
  const NutritionSummaryCardView({
    super.key,
    required this.data,
    required this.onTap,
  });

  final NutritionSummaryViewData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    return SectionCard(
      onTap: onTap,
      header: const CardHeader(
        title: 'Nutrition summary',
        subtitle: TextSpan(text: 'Last 7 days'),
      ),
      child: d.averageKcal == null
          ? Text('Nothing logged in the last 7 days.', style: t.label)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  items: [
                    StatItem(
                      label: 'Average',
                      value: d.averageKcal!,
                      unit: 'kcal',
                    ),
                    StatItem(
                      label: 'Target',
                      value: d.targetKcal,
                      unit: 'kcal',
                    ),
                    StatItem(label: 'Days logged', value: d.daysLogged),
                  ],
                ),
                if (d.overTarget)
                  Text(
                    'Average is above your target',
                    style: t.label.copyWith(color: c.warning),
                  ),
              ],
            ),
    );
  }
}
