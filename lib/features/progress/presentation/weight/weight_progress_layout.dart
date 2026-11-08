import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/extensions/text_scale.dart';
import '../../../../shared/widgets/widgets.dart';
import '../charts/chart_helpers.dart';
import 'weight_chart.dart';

class WeightRowData {
  const WeightRowData({
    required this.id,
    required this.date,
    required this.detail,
    required this.value,
  });

  final int id;

  /// "Tue 3 Nov"
  final String date;

  /// "07:12 · after run"
  final String detail;

  /// "74.2"
  final String value;
}

class WeightProgressData {
  const WeightProgressData({
    required this.range,
    required this.unit,
    required this.current,
    required this.change,
    required this.changeDown,
    required this.changeTowardGoal,
    required this.points,
    required this.target,
    required this.targetLabel,
    required this.stats,
    required this.rows,
  });

  final RangePreset range;
  final String unit;

  /// Latest value in range; null when the range has no entries.
  final String? current;

  /// "1.3 kg"; null with fewer than two entries.
  final String? change;
  final bool changeDown;
  final bool changeTowardGoal;
  final List<ChartPoint> points;
  final double? target;
  final String? targetLabel;

  /// Start, lowest, average.
  final List<StatItem> stats;

  /// Newest first.
  final List<WeightRowData> rows;
}

/// Pure layout for the Progress > Weight tab.
class WeightProgressLayout extends StatelessWidget {
  const WeightProgressLayout({
    super.key,
    required this.data,
    required this.onLog,
    required this.onEdit,
  });

  final WeightProgressData data;
  final VoidCallback onLog;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    final logButton = TextButton.icon(
      onPressed: onLog,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Log weight'),
    );

    if (d.points.isEmpty) {
      return SectionCard(
        header: CardHeader(title: 'Weight', trailing: logButton),
        child: EmptyChart(
          message: 'No weight entries in this range.',
          actionLabel: 'Log weight',
          onAction: onLog,
        ),
      );
    }

    final large = context.hasLargeText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          // At large font sizes the change goes under the current weight.
          header: Flex(
            direction: large ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: large
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Flexible(
                // flex 0 when stacked: the column's height is unbounded.
                flex: large ? 0 : 1,
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT', style: t.overline),
                    Text.rich(
                      TextSpan(
                        text: d.current,
                        style: t.display,
                        children: [
                          TextSpan(text: ' ${d.unit}', style: t.label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (d.change != null)
                Column(
                  crossAxisAlignment: large
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.changeDown ? Icons.south : Icons.north,
                          size: 14,
                          color: d.changeTowardGoal ? c.success : c.ink,
                        ),
                        Text(
                          ' ${d.change}',
                          style: t.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: d.changeTowardGoal ? c.success : c.ink,
                          ),
                        ),
                      ],
                    ),
                    Text(ChartAxes.rangePhrase(d.range), style: t.label),
                  ],
                ),
            ],
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChartLegend(
                items: [
                  const LegendItem('Measured', SeriesStyle.measured),
                  if (d.target != null)
                    const LegendItem('Target', SeriesStyle.target),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              StatRow(items: d.stats),
            ],
          ),
          child: Semantics(
            label:
                'Weight chart, ${d.points.length} entries, latest '
                '${d.current} ${d.unit}',
            child: ExcludeSemantics(
              child: WeightChart(
                points: d.points,
                range: d.range,
                target: d.target,
                targetLabel: d.targetLabel,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: CardHeader(
            title: 'Entries',
            subtitle: TextSpan(text: '${d.rows.length} in range'),
            trailing: logButton,
          ),
          child: Column(
            children: [
              for (var i = 0; i < d.rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListRow(
                  title: d.rows[i].date,
                  subtitle: d.rows[i].detail,
                  value: d.rows[i].value,
                  unit: d.unit,
                  onTap: () => onEdit(d.rows[i].id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
