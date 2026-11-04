import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/fit_colors.dart';

/// One colored part of the ring: [kcal] calories drawn in [color].
class RingSegment {
  const RingSegment({required this.color, required this.kcal});

  final Color color;
  final double kcal;
}

/// A drawable arc, in radians clockwise from 12 o'clock.
class RingArc {
  const RingArc({
    required this.start,
    required this.sweep,
    required this.color,
    this.isTrack = false,
  });

  final double start;
  final double sweep;
  final Color color;
  final bool isTrack;
}

/// Geometry of the macro calorie ring (DESIGN/README.md section 4).
///
/// * The colored part covers `eaten / goal` of the circle (all of it when
///   over the goal, or when there is no goal but something was eaten).
/// * It is split into [segments] in proportion to their kcal.
/// * The rest is the empty track.
/// * [gap] radians separate every boundary; each arc gives up half a gap at
///   each end, so proportions stay exact. Arcs too small to show are dropped.
List<RingArc> computeRingArcs({
  required double eatenKcal,
  required double? goalKcal,
  required List<RingSegment> segments,
  required Color trackColor,
  required double gap,
}) {
  const full = 2 * math.pi;
  final parts = segments.where((s) => s.kcal > 0).toList();
  final total = parts.fold<double>(0, (sum, s) => sum + s.kcal);

  final double fill;
  if (total <= 0 || eatenKcal <= 0) {
    fill = 0;
  } else if (goalKcal == null || goalKcal <= 0) {
    fill = 1;
  } else {
    fill = (eatenKcal / goalKcal).clamp(0.0, 1.0);
  }

  if (fill == 0) {
    return [RingArc(start: 0, sweep: full, color: trackColor, isTrack: true)];
  }

  final raw = <RingArc>[];
  var cursor = 0.0;
  for (final s in parts) {
    final sweep = full * fill * s.kcal / total;
    raw.add(RingArc(start: cursor, sweep: sweep, color: s.color));
    cursor += sweep;
  }
  if (fill < 1) {
    raw.add(
      RingArc(
        start: cursor,
        sweep: full - cursor,
        color: trackColor,
        isTrack: true,
      ),
    );
  }

  // A single arc covering the whole circle has no boundaries.
  if (raw.length == 1) return raw;

  return [
    for (final a in raw)
      if (a.sweep > gap)
        RingArc(
          start: a.start + gap / 2,
          sweep: a.sweep - gap,
          color: a.color,
          isTrack: a.isTrack,
        ),
  ];
}

/// The macro-segmented calorie ring. Pure layout: it receives calories and
/// colored segments and does no nutrition math itself.
class MacroCalorieRing extends StatelessWidget {
  const MacroCalorieRing({
    super.key,
    required this.eatenKcal,
    required this.goalKcal,
    required this.segments,
    this.size = 166,
    this.strokeWidth = 18,
    this.gap = 10,
    this.center,
    this.semanticsLabel,
  });

  final double eatenKcal;
  final double? goalKcal;
  final List<RingSegment> segments;
  final double size;
  final double strokeWidth;

  /// Gap between arcs, in logical pixels along the ring.
  final double gap;

  /// Shown in the middle (e.g. the eaten kcal).
  final Widget? center;

  /// One sentence summarizing the ring for screen readers.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final radius = (size - strokeWidth) / 2;
    final arcs = computeRingArcs(
      eatenKcal: eatenKcal,
      goalKcal: goalKcal,
      segments: segments,
      trackColor: context.fitColors.line,
      gap: gap / radius,
    );
    return Semantics(
      label: semanticsLabel,
      container: true,
      excludeSemantics: semanticsLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(arcs, strokeWidth),
          child: center == null
              ? null
              : Center(
                  child: Padding(
                    padding: EdgeInsets.all(strokeWidth * 1.2),
                    child: FittedBox(fit: BoxFit.scaleDown, child: center),
                  ),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.arcs, this.strokeWidth);

  final List<RingArc> arcs;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    for (final a in arcs) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = a.color;
      canvas.drawArc(rect, -math.pi / 2 + a.start, a.sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.strokeWidth != strokeWidth || !_sameArcs(old.arcs, arcs);

  static bool _sameArcs(List<RingArc> a, List<RingArc> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start ||
          a[i].sweep != b[i].sweep ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }
}
