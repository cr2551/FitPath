import 'package:flutter/material.dart';

import '../../../../core/theme/fit_colors.dart';

/// One day in the chart. Days without entries have all zeros.
class DayBar {
  const DayBar({
    required this.day,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
    required this.unknownKcal,
    required this.targetKcal,
  });

  final DateTime day;
  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;
  final double unknownKcal;

  /// The target in effect that day; null without one.
  final double? targetKcal;

  double get total => proteinKcal + carbsKcal + fatKcal + unknownKcal;
}

/// Daily calories as bars stacked by macro (protein, carbs, fat, unknown,
/// bottom to top), with the target in effect each day as a dashed step line.
/// Tapping a day reports it.
class DailyCaloriesChart extends StatelessWidget {
  const DailyCaloriesChart({
    super.key,
    required this.days,
    required this.onDay,
    this.height = 168,
  });

  /// Oldest first.
  final List<DayBar> days;
  final ValueChanged<DateTime> onDay;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (days.isEmpty) return;
          final i =
              (details.localPosition.dx / constraints.maxWidth * days.length)
                  .floor()
                  .clamp(0, days.length - 1);
          onDay(days[i].day);
        },
        child: CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _BarsPainter(
            days,
            protein: c.protein,
            carbs: c.carbs,
            fat: c.fat,
            unknown: c.unknown,
            target: c.success,
            grid: c.line,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(
    this.days, {
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.unknown,
    required this.target,
    required this.grid,
  });

  final List<DayBar> days;
  final Color protein, carbs, fat, unknown, target, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final maxValue = days
        .map(
          (d) => [d.total, d.targetKcal ?? 0].reduce((a, b) => a > b ? a : b),
        )
        .reduce((a, b) => a > b ? a : b);
    final top = maxValue <= 0 ? 1 : maxValue * 1.1;
    double y(double v) => size.height - size.height * v / top;
    final slot = size.width / days.length;
    final gap = slot > 6 ? slot * 0.25 : 0.0;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = grid,
    );

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      var base = 0.0;
      for (final (kcal, color) in [
        (d.proteinKcal, protein),
        (d.carbsKcal, carbs),
        (d.fatKcal, fat),
        (d.unknownKcal, unknown),
      ]) {
        if (kcal <= 0) continue;
        canvas.drawRect(
          Rect.fromLTRB(
            i * slot + gap / 2,
            y(base + kcal),
            (i + 1) * slot - gap / 2,
            y(base),
          ),
          Paint()..color = color,
        );
        base += kcal;
      }
    }

    // Target as a dashed step line across each day's slot.
    final dash = Paint()
      ..color = target
      ..strokeWidth = 1.5;
    for (var i = 0; i < days.length; i++) {
      final t = days[i].targetKcal;
      if (t == null) continue;
      final ty = y(t);
      for (var x = i * slot; x < (i + 1) * slot; x += 8) {
        final end = x + 5 < (i + 1) * slot ? x + 5 : (i + 1) * slot;
        canvas.drawLine(Offset(x, ty), Offset(end, ty), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.days != days;
}
