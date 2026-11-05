import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';
import '../charts/chart_helpers.dart';

/// One measured value.
class ChartPoint {
  const ChartPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

/// Weight over time (app chart convention): measured values as a solid ink
/// line with square points, the latest point as a larger açaí square, and
/// an optional dashed target line. Values are in the display unit.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.points,
    required this.range,
    this.target,
    this.targetLabel,
    this.height = 168,
  });

  /// Oldest first; at least one.
  final List<ChartPoint> points;
  final RangePreset range;
  final double? target;

  /// "Target 72 kg"
  final String? targetLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final start = Dates.startOfDay(points.first.at);
    double x(DateTime at) => at.difference(start).inMinutes / (60 * 24);

    final values = [for (final p in points) p.value, ?target];
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // Round bounds to a step so the axis labels land on gridlines.
    final step = niceStep((maxV - minV) / 3);
    final lo = (minV / step).floor() * step - (minV % step == 0 ? step : 0);
    final hi = (maxV / step).ceil() * step + (maxV % step == 0 ? step : 0);
    final maxX = x(points.last.at).clamp(1.0, double.infinity);
    final last = points.length - 1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: lo,
          maxY: hi,
          lineTouchData: const LineTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.line, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: step,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(ChartAxes.valueLabel(v), style: t.label),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: maxX / 2,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    ChartAxes.dateLabel(
                      start.add(Duration(minutes: (v * 24 * 60).round())),
                      range,
                    ),
                    style: t.label,
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: target == null
              ? null
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target!,
                      color: c.success,
                      strokeWidth: 1.5,
                      dashArray: const [5, 4],
                      label: HorizontalLineLabel(
                        show: targetLabel != null,
                        style: t.label.copyWith(color: c.success),
                        labelResolver: (_) => targetLabel ?? '',
                      ),
                    ),
                  ],
                ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final p in points) FlSpot(x(p.at), p.value)],
              color: c.ink,
              barWidth: 2,
              isStrokeCapRound: false,
              dotData: FlDotData(
                getDotPainter: (spot, _, _, i) => FlDotSquarePainter(
                  size: i == last ? 10 : 6,
                  color: i == last ? c.accent : c.ink,
                  strokeWidth: 0,
                ),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// The smallest of 0.1, 0.2, 0.5, 1, 2, 5, 10, ... that is at least [raw].
double niceStep(double raw) {
  var base = 0.1;
  while (true) {
    for (final m in const [1, 2, 5]) {
      if (base * m >= raw) return base * m;
    }
    base *= 10;
  }
}
