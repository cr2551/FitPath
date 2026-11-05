import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

/// Change over the period, already formatted.
class WeightChange {
  const WeightChange({
    required this.label,
    required this.down,
    required this.towardGoal,
  });

  /// "1.3 kg · last 30 days"
  final String label;
  final bool down;

  /// Moving toward the target weight (shown in the success color).
  final bool towardGoal;
}

class WeightTrendViewData {
  const WeightTrendViewData({
    required this.value,
    required this.unit,
    required this.change,
    required this.points,
  });

  /// "74.2"; null before the first entry (empty state).
  final String? value;
  final String unit;
  final WeightChange? change;

  /// Weights over the period, oldest first, for the sparkline.
  final List<double> points;
}

/// Pure layout for the Home weight card (DESIGN/home.html).
class WeightTrendCardView extends StatelessWidget {
  const WeightTrendCardView({
    super.key,
    required this.data,
    required this.onLog,
    required this.onTap,
  });

  final WeightTrendViewData data;
  final VoidCallback onLog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    final change = d.change;
    return SectionCard(
      onTap: onTap,
      header: CardHeader(
        title: 'Weight',
        trailing: TextButton.icon(
          onPressed: onLog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Log'),
        ),
      ),
      child: d.value == null
          ? Text('No weight logged yet.', style: t.label)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: d.value,
                          style: t.display,
                          children: [
                            TextSpan(text: ' ${d.unit}', style: t.label),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        change == null
                            ? 'Log again to see your trend'
                            : '${change.down ? '▼' : '▲'} ${change.label}',
                        style: t.label.copyWith(
                          fontWeight: change == null ? null : FontWeight.w600,
                          color: change != null && change.towardGoal
                              ? c.success
                              : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (d.points.length >= 2)
                  ExcludeSemantics(
                    child: CustomPaint(
                      size: const Size(120, 44),
                      painter: _Sparkline(
                        d.points,
                        line: c.ink,
                        latest: c.accent,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A small line of the values with a square on the latest one.
class _Sparkline extends CustomPainter {
  _Sparkline(this.points, {required this.line, required this.latest});

  final List<double> points;
  final Color line;
  final Color latest;

  @override
  void paint(Canvas canvas, Size size) {
    const marker = 8.0;
    final lo = points.reduce((a, b) => a < b ? a : b);
    final hi = points.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final w = size.width - marker, h = size.height - marker;
    Offset at(int i) => Offset(
      marker / 2 + w * i / (points.length - 1),
      marker / 2 + h * (1 - (points[i] - lo) / span),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: at(points.length - 1),
        width: marker,
        height: marker,
      ),
      Paint()..color = latest,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.points != points;
}
