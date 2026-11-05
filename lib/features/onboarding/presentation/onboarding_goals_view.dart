import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

/// One line under each goal in the list.
const goalDescriptions = {
  GoalType.loseWeight: 'Eat a little under your needs and track the trend',
  GoalType.buildMuscle: 'Train progressively and eat enough protein',
  GoalType.maintainWeight: 'Keep your weight steady',
  GoalType.improveStrength: 'Lift heavier over time',
  GoalType.generalFitness: 'Move regularly and eat well',
};

/// Pure layout for choosing one main goal and any secondary goals.
class OnboardingGoalsView extends StatelessWidget {
  const OnboardingGoalsView({
    super.key,
    required this.labels,
    required this.primary,
    required this.secondary,
    required this.secondaryOptions,
    required this.onPrimary,
    required this.onToggleSecondary,
    required this.onNext,
  });

  final Map<GoalType, String> labels;
  final GoalType? primary;
  final Set<GoalType> secondary;

  /// Goals that can be combined with [primary].
  final List<GoalType> secondaryOptions;
  final ValueChanged<GoalType> onPrimary;
  final ValueChanged<GoalType> onToggleSecondary;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your goals')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Your main goal shapes your calorie target and your Home '
              'dashboard. You can change it later.',
              style: t.label,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('MAIN GOAL', style: t.overline),
            const SizedBox(height: AppSpacing.xs),
            SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (final (i, goal) in GoalType.values.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    Semantics(
                      selected: primary == goal,
                      child: ListRow(
                        title: labels[goal]!,
                        subtitle: goalDescriptions[goal],
                        onTap: () => onPrimary(goal),
                        trailing: Icon(
                          primary == goal ? Icons.check : null,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('ALSO WORKING ON (OPTIONAL)', style: t.overline),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final goal in secondaryOptions)
                  FilterChip(
                    label: Text(labels[goal]!),
                    selected: secondary.contains(goal),
                    onSelected: (_) => onToggleSecondary(goal),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: primary == null ? null : onNext,
              child: const Text('NEXT'),
            ),
          ],
        ),
      ),
    );
  }
}
