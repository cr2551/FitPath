import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

const goalLabels = {
  GoalType.loseWeight: 'Lose weight',
  GoalType.buildMuscle: 'Build muscle',
  GoalType.maintainWeight: 'Maintain weight',
  GoalType.improveStrength: 'Improve strength',
  GoalType.generalFitness: 'General fitness',
};

class GoalsViewData {
  const GoalsViewData({
    required this.primary,
    required this.secondary,
    required this.secondaryOptions,
    required this.showTargetWeight,
    required this.targetWeight,
    required this.weightUnit,
    required this.weightRange,
    required this.targetDateLabel,
    required this.canSave,
    required this.saving,
  });

  final GoalType? primary;
  final Set<GoalType> secondary;

  /// Goals that can be combined with [primary].
  final List<GoalType> secondaryOptions;

  /// Weight goals ask for an optional target weight and date.
  final bool showTargetWeight;

  /// In the display unit.
  final double? targetWeight;
  final String weightUnit;
  final ValueRange weightRange;

  /// Null when no target date is set.
  final String? targetDateLabel;
  final bool canSave;
  final bool saving;
}

class GoalsCallbacks {
  const GoalsCallbacks({
    required this.onPrimary,
    required this.onToggleSecondary,
    required this.onTargetWeight,
    required this.onPickTargetDate,
    required this.onClearTargetDate,
    required this.onSave,
    required this.onRetry,
  });

  final ValueChanged<GoalType> onPrimary;
  final ValueChanged<GoalType> onToggleSecondary;

  /// Null while empty or invalid.
  final ValueChanged<double?> onTargetWeight;
  final VoidCallback onPickTargetDate;
  final VoidCallback onClearTargetDate;
  final VoidCallback onSave;
  final VoidCallback onRetry;
}

/// Pure layout for editing goals.
class GoalsView extends StatelessWidget {
  const GoalsView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  final GoalsViewData? data;
  final String? error;
  final GoalsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: SafeArea(
        child: error != null
            ? Padding(
                padding: AppSpacing.screenPadding,
                child: ErrorState(message: error!, onRetry: callbacks.onRetry),
              )
            : d == null
            ? const Center(child: CircularProgressIndicator())
            : _form(context, d),
      ),
    );
  }

  Widget _form(BuildContext context, GoalsViewData d) {
    final c = context.fitColors;
    final t = context.textStyles;
    final cb = callbacks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        Text('MAIN GOAL', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, goal) in GoalType.values.indexed) ...[
                if (i > 0) const Divider(height: 1),
                Semantics(
                  selected: d.primary == goal,
                  child: ListRow(
                    title: goalLabels[goal]!,
                    onTap: () => cb.onPrimary(goal),
                    trailing: Icon(
                      d.primary == goal ? Icons.check : null,
                      color: c.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (d.showTargetWeight) ...[
          const SizedBox(height: AppSpacing.lg),
          UnitNumberField(
            label: 'Target weight (optional)',
            unit: d.weightUnit,
            range: d.weightRange,
            isRequired: false,
            initialValue: d.targetWeight,
            onChanged: cb.onTargetWeight,
          ),
          const SizedBox(height: AppSpacing.sm),
          ListRow(
            title: 'Target date (optional)',
            value: d.targetDateLabel ?? 'Not set',
            onTap: cb.onPickTargetDate,
          ),
          if (d.targetDateLabel != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: cb.onClearTargetDate,
                child: const Text('Clear date'),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('ALSO WORKING ON', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final goal in d.secondaryOptions)
              FilterChip(
                label: Text(goalLabels[goal]!),
                selected: d.secondary.contains(goal),
                onSelected: (_) => cb.onToggleSecondary(goal),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Earlier goals are kept in your history. Your nutrition targets '
          'do not change until you update them.',
          style: t.label,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: d.canSave && !d.saving ? cb.onSave : null,
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
