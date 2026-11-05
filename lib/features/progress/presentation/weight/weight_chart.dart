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
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    // A flat series (e.g. a single entry) still gets a readable axis: at
    // least 2 units tall, centred on the values.
    if (maxV - minV < 2) {
      final mid = (minV + maxV) / 2;
      minV = mid - 1;
      maxV = mid + 1;
    }
    // Round bounds to a step so the axis labels land on gridlines.
    final step = niceStep((maxV - minV) / 3);
    final lo = (minV / step).floor() * step - (minV % step == 0 ? step : 0);
    final hi = (maxV / step).ceil() * step + (maxV % step == 0 ? step : 0);
    // Entries within one day: show them on a three-day axis (the day
    // before to the day after) instead of stretching a few hours across
    // the chart. Whole-day bounds put every tick on a midnight.
    final span = x(points.last.at);
    final oneDay = span < 1;
    final minX = oneDay ? -1.0 : 0.0;
    final maxX = oneDay ? 2.0 : span;
    final last = points.length - 1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
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
                interval: oneDay ? 1 : (maxX - minX) / 2,
                getTitlesWidget: (v, meta) {
                  String label(double at) => ChartAxes.dateLabel(
                    start.add(Duration(minutes: (at * 24 * 60).round())),
                    range,
                  );
                  // Skip a tick that would repeat the previous date.
                  if (v > meta.min &&
                      label(v) == label(v - meta.appliedInterval)) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child: Text(label(v), style: t.label),
                  );
                },
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
