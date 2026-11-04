import 'package:flutter/material.dart';

import '../../core/theme/fit_colors.dart';

/// A flat, square-ended progress bar on a `line`-colored track.
class FitProgressBar extends StatelessWidget {
  const FitProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
  });

  /// 0..1; null draws an empty track.
  final double? fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = (fraction ?? 0).clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: context.fitColors.line,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: f,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}
