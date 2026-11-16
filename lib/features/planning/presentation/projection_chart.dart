import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/fit_colors.dart';
import '../../progress/presentation/charts/chart_helpers.dart';
import '../../progress/presentation/weight/weight_chart.dart';

/// Measured weight as a solid ink line and the projection as a dashed one,
/// with an optional dashed target line. Values are in the display unit.
class ProjectionChart extends StatelessWidget {
  const ProjectionChart({
    super.key,
    required this.measured,
    required this.projected,
    this.target,
    this.height = 180,
  });

  /// Oldest first; may be empty.
  final List<ChartPoint> measured;

  /// Oldest first; at least two (today and a later day).
  final List<ChartPoint> projected;
  final double? target;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final all = [...measured, ...projected];
    final start = all.first.at;
    double x(DateTime at) => at.difference(start).inHours / 24;

    final values = [for (final p in all) p.value, ?target];
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV - minV < 2) {
      final mid = (minV + maxV) / 2;
      minV = mid - 1;
      maxV = mid + 1;
    }
    final step = niceStep((maxV - minV) / 3);
    final lo = (minV / step).floor() * step;
    final hi = (maxV / step).ceil() * step;
    final maxX = x(projected.last.at);
    final label = DateFormat('d MMM yy');

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
                reservedSize: 44,
                interval: step,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(ChartAxes.valueLabel(v), style: t.label),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: maxX <= 0 ? 1 : maxX,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    label.format(
                      start.add(Duration(minutes: (v * 24 * 60).round())),
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
                    ),
                  ],
                ),
          lineBarsData: [
            if (measured.isNotEmpty)
              LineChartBarData(
                spots: [for (final p in measured) FlSpot(x(p.at), p.value)],
                color: c.ink,
                barWidth: 2,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) =>
                      FlDotSquarePainter(size: 6, color: c.ink, strokeWidth: 0),
                ),
              ),
            LineChartBarData(
              spots: [for (final p in projected) FlSpot(x(p.at), p.value)],
              color: c.accent,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
