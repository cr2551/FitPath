import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';
import '../../core/utils/formatters.dart';
import 'progress_bar.dart';

/// Material icons used for the macros and calories (outlined style).
abstract final class FitIcons {
  static const protein = Icons.set_meal_outlined;
  static const carbs = Icons.bakery_dining_outlined;
  static const fat = Icons.water_drop_outlined;
  static const calories = Icons.local_fire_department_outlined;
}

/// One macro in the calorie legend: icon + name + share of calories, a bar
/// of grams vs target, and "110 g / 140 g". With no target it shows
/// "Set target" instead of a misleading zero.
class MacroLegendRow extends StatelessWidget {
  const MacroLegendRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.consumedG,
    required this.targetG,
    this.shareOfCalories,
  });

  final IconData icon;
  final String label;

  /// The macro's color (fills only; text stays ink).
  final Color color;
  final double consumedG;
  final double? targetG;

  /// 0..1 share of the day's calories, matching the ring segment.
  final double? shareOfCalories;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final hasTarget = targetG != null && targetG! > 0;
    return Semantics(
      container: true,
      label:
          '$label ${Formatters.grams(consumedG)}'
          '${hasTarget ? ' of ${Formatters.grams(targetG)}' : ', no target'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  label,
                  style: t.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (shareOfCalories != null)
                Text(Formatters.percent(shareOfCalories), style: t.label),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          FitProgressBar(
            fraction: hasTarget ? consumedG / targetG! : null,
            color: color,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              text: Formatters.grams(consumedG),
              style: t.body.copyWith(fontSize: 14),
              children: [
                TextSpan(
                  text: hasTarget
                      ? ' / ${Formatters.grams(targetG)}'
                      : '  Set target',
                  style: t.label.copyWith(
                    fontSize: 14,
                    color: hasTarget ? c.inkMuted : c.ink,
                    fontWeight: hasTarget ? null : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
