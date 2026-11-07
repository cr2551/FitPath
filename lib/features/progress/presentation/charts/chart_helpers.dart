import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/dates.dart';

/// Axis labels and range wording shared by the Progress charts.
abstract final class ChartAxes {
  /// Bottom-axis date label: "3 Nov" for ranges up to 90 days, "Nov 26"
  /// for a year or all time.
  static String dateLabel(DateTime d, RangePreset range) => switch (range) {
    RangePreset.year || RangePreset.all => DateFormat('MMM yy').format(d),
    _ => DateFormat('d MMM').format(d),
  };

  /// Side-axis value label with at most [decimals] decimals and no trailing
  /// zeros: 74, 74.5.
  static String valueLabel(double v, {int decimals = 1}) {
    final s = v.toStringAsFixed(decimals);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  /// "over 30 days", "over the last year", "over all time".
  static String rangePhrase(RangePreset range) => switch (range) {
    RangePreset.days7 => 'over 7 days',
    RangePreset.days30 => 'over 30 days',
    RangePreset.days90 => 'over 90 days',
    RangePreset.year => 'over the last year',
    RangePreset.all => 'over all time',
  };

  /// Button label: 7D, 30D, 90D, 1Y, All.
  static String rangeLabel(RangePreset range) => switch (range) {
    RangePreset.days7 => '7D',
    RangePreset.days30 => '30D',
    RangePreset.days90 => '90D',
    RangePreset.year => '1Y',
    RangePreset.all => 'All',
  };
}

/// Chart placeholder when the range has no data: at least as tall as a
/// chart, one muted line and an optional action.
class EmptyChart extends StatelessWidget {
  const EmptyChart({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.height = 168,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    // At least [height]; taller when large text needs the room.
    return Container(
      constraints: BoxConstraints(minHeight: height),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: AppRadii.smAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: context.textStyles.label,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// How a series is drawn: measured values are solid ink, targets and
/// estimates are dashed.
enum SeriesStyle { measured, target, estimate }

class LegendItem {
  const LegendItem(this.label, this.style, {this.color});

  final String label;
  final SeriesStyle style;

  /// Defaults to ink for measured and success for targets/estimates.
  final Color? color;
}

/// The legend under a chart, distinguishing measured from estimated values.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<LegendItem> items;

  static Color colorOf(BuildContext context, LegendItem item) =>
      item.color ??
      switch (item.style) {
        SeriesStyle.measured => context.fitColors.ink,
        SeriesStyle.target || SeriesStyle.estimate => context.fitColors.success,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(14, 2),
                painter: _LineSample(
                  colorOf(context, item),
                  dashed: item.style != SeriesStyle.measured,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(item.label, style: context.textStyles.label),
            ],
          ),
      ],
    );
  }
}

class _LineSample extends CustomPainter {
  _LineSample(this.color, {required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 2;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LineSample old) =>
      old.color != color || old.dashed != dashed;
}
