import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../charts/chart_helpers.dart';
import 'daily_calories_chart.dart';

class DaySummaryRow {
  const DaySummaryRow({
    required this.day,
    required this.date,
    required this.macros,
    required this.kcal,
    required this.overTarget,
  });

  final DateTime day;

  /// "Tue 3 Nov"
  final String date;

  /// "P 110 · C 180 · F 53 g"
  final String macros;

  /// "1,640 / 2,100"
  final String kcal;
  final bool overTarget;
}

class NutritionProgressData {
  const NutritionProgressData({
    required this.bars,
    required this.firstLabel,
    required this.lastLabel,
    required this.stats,
    required this.macroStats,
    required this.rows,
  });

  /// Oldest first; empty when nothing was logged in the range.
  final List<DayBar> bars;
  final String firstLabel;
  final String lastLabel;

  /// Average kcal and days logged.
  final List<StatItem> stats;

  /// Average protein, carbs and fat.
  final List<StatItem> macroStats;

  /// Logged days, newest first.
  final List<DaySummaryRow> rows;
}

/// Pure layout for Progress > Nutrition.
class NutritionProgressLayout extends StatelessWidget {
  const NutritionProgressLayout({
    super.key,
    required this.data,
    required this.onDay,
  });

  final NutritionProgressData data;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    if (d.rows.isEmpty) {
      return const SectionCard(
        header: CardHeader(title: 'Calories'),
        child: EmptyChart(message: 'Nothing logged in this range.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          header: const CardHeader(
            title: 'Calories',
            subtitle: TextSpan(text: 'Tap a day to open it'),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChartLegend(
                items: [
                  LegendItem('Protein', SeriesStyle.measured, color: c.protein),
                  LegendItem('Carbs', SeriesStyle.measured, color: c.carbs),
                  LegendItem('Fat', SeriesStyle.measured, color: c.fat),
                  const LegendItem('Target', SeriesStyle.target),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              StatRow(items: d.stats),
              const SizedBox(height: AppSpacing.md),
              StatRow(items: d.macroStats),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Daily calories chart, ${d.rows.length} days logged',
                child: DailyCaloriesChart(days: d.bars, onDay: onDay),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text(d.firstLabel, style: t.label),
                  const Spacer(),
                  Text(d.lastLabel, style: t.label),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: const CardHeader(title: 'Days'),
          child: Column(
            children: [
              for (var i = 0; i < d.rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListRow(
                  title: d.rows[i].date,
                  subtitle: d.rows[i].macros,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: d.rows[i].kcal,
                            style: t.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: d.rows[i].overTarget ? c.warning : c.ink,
                            ),
                            children: [TextSpan(text: ' kcal', style: t.label)],
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.inkMuted),
                    ],
                  ),
                  onTap: () => onDay(d.rows[i].day),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
