import 'package:flutter/material.dart';

import '../../../../core/theme/fit_colors.dart';

/// Completed sessions per period (week or month) as ink bars, with the
/// count above each bar.
class WeeklySessionsChart extends StatelessWidget {
  const WeeklySessionsChart({
    super.key,
    required this.counts,
    this.height = 120,
  });

  /// One count per period, oldest first.
  final List<int> counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WeeksPainter(
        counts,
        bar: c.ink,
        line: c.line,
        label: context.textStyles.label,
      ),
    );
  }
}

class _WeeksPainter extends CustomPainter {
  _WeeksPainter(
    this.counts, {
    required this.bar,
    required this.line,
    required this.label,
  });

  final List<int> counts;
  final Color bar;
  final Color line;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = line,
    );
    if (counts.isEmpty) return;
    final top = counts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    const labelSpace = 16.0;
    final slot = size.width / counts.length;
    final gap = slot > 8 ? slot * 0.3 : 1.0;
    final showLabels = slot >= 18;
    for (var i = 0; i < counts.length; i++) {
      final h = (size.height - labelSpace) * counts[i] / top;
      final rect = Rect.fromLTRB(
        i * slot + gap / 2,
        size.height - h,
        (i + 1) * slot - gap / 2,
        size.height,
      );
      canvas.drawRect(rect, Paint()..color = bar);
      if (showLabels && counts[i] > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${counts[i]}', style: label),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(rect.center.dx - tp.width / 2, rect.top - tp.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeeksPainter old) => old.counts != counts;
}
