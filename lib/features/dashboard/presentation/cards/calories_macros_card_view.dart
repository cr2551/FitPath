import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/widgets.dart';
import 'calories_macros_view_data.dart';

/// Pure layout for the calories & macros card (DESIGN/home.html): goal
/// header, ring with the macro legend, footer strip.
class CaloriesMacrosCardView extends StatelessWidget {
  const CaloriesMacrosCardView({
    super.key,
    required this.data,
    required this.onTap,
    this.onSetGoal,
  });

  final CaloriesMacrosViewData data;
  final VoidCallback onTap;

  /// Shown as a "Set goal" action when there is no calorie goal.
  final VoidCallback? onSetGoal;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    final status = d.status;
    final statusColor = status.over ? c.warning : c.inkMuted;

    return SectionCard(
      onTap: onTap,
      dividerBelowHeader: true,
      header: CardHeader(
        icon: FitIcons.calories,
        title: d.title,
        subtitle: TextSpan(
          style: TextStyle(color: statusColor),
          children: [
            if (status.number != null)
              TextSpan(
                text: '${status.number} ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: status.over ? c.warning : c.ink,
                ),
              ),
            TextSpan(text: status.text),
          ],
        ),
        trailing: onSetGoal == null
            ? null
            : TextButton(onPressed: onSetGoal, child: const Text('Set goal')),
      ),
      footer: CardFooterStrip(
        items: [
          FooterItem(icon: Icons.restaurant_outlined, label: d.mealsLabel),
          FooterItem(
            icon: Icons.fitness_center_outlined,
            label: d.workoutsLabel,
          ),
        ],
      ),
      child: Row(
        children: [
          MacroCalorieRing(
            eatenKcal: d.eatenKcal,
            goalKcal: d.goalKcal,
            segments: [
              RingSegment(color: c.protein, kcal: d.segments.protein),
              RingSegment(color: c.carbs, kcal: d.segments.carbs),
              RingSegment(color: c.fat, kcal: d.segments.fat),
              RingSegment(color: c.unknown, kcal: d.segments.unknown),
            ],
            semanticsLabel: d.semanticsLabel,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EATEN', style: t.overline),
                Text(d.eatenLabel, style: t.hero),
                Text('kcal', style: t.label),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < d.macros.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _legendRow(context, d.macros[i]),
                ],
                if (d.unknown != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _UnknownRow(data: d.unknown!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _legendRow(BuildContext context, MacroLegendData m) {
    final c = context.fitColors;
    final (icon, color) = switch (m.kind) {
      MacroKind.protein => (FitIcons.protein, c.protein),
      MacroKind.carbs => (FitIcons.carbs, c.carbs),
      MacroKind.fat => (FitIcons.fat, c.fat),
    };
    return MacroLegendRow(
      icon: icon,
      label: m.label,
      color: color,
      consumedG: m.consumedG,
      targetG: m.targetG,
      shareOfCalories: m.share,
    );
  }
}

/// Calories from entries without a macro split.
class _UnknownRow extends StatelessWidget {
  const _UnknownRow({required this.data});

  final UnknownLegendData data;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Unknown macros ${data.kcalLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: c.unknown),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(child: Text('Unknown', style: t.bodyStrong)),
              Text(Formatters.percent(data.share), style: t.label),
            ],
          ),
          Text(data.kcalLabel, style: t.body.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
