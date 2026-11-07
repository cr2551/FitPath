import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

class GoalDetailsViewData {
  const GoalDetailsViewData({
    required this.showWeightTarget,
    required this.showTraining,
    required this.targetWeight,
    required this.weightUnit,
    required this.weightRange,
    required this.targetDateLabel,
    required this.activity,
    required this.experience,
    required this.trainingDays,
    required this.problem,
    required this.canContinue,
  });

  /// Lose weight: optional target weight and date.
  final bool showWeightTarget;

  /// Build muscle / improve strength: experience.
  final bool showTraining;

  /// In the display unit.
  final double? targetWeight;
  final String weightUnit;
  final ValueRange weightRange;

  /// Null when no date is set.
  final String? targetDateLabel;
  final ActivityLevel? activity;
  final TrainingExperience? experience;
  final int? trainingDays;

  /// Why the details can't be saved (e.g. too fast a loss); null when fine.
  final String? problem;
  final bool canContinue;
}

class GoalDetailsCallbacks {
  const GoalDetailsCallbacks({
    required this.onTargetWeight,
    required this.onPickDate,
    required this.onClearDate,
    required this.onActivity,
    required this.onExperience,
    required this.onTrainingDays,
    required this.onNext,
  });

  /// Display units; null while empty or invalid.
  final ValueChanged<double?> onTargetWeight;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<ActivityLevel?> onActivity;
  final ValueChanged<TrainingExperience?> onExperience;
  final ValueChanged<int?> onTrainingDays;
  final VoidCallback onNext;
}

/// Pure layout for the goal follow-up questions. Only the sections that
/// apply to the chosen goals are shown.
class GoalDetailsView extends StatelessWidget {
  const GoalDetailsView({
    super.key,
    required this.data,
    required this.activityLabels,
    required this.callbacks,
  });

  final GoalDetailsViewData data;
  final Map<ActivityLevel, String> activityLabels;
  final GoalDetailsCallbacks callbacks;

  static const _experience = {
    TrainingExperience.beginner: 'Beginner (under a year)',
    TrainingExperience.intermediate: 'Intermediate (1-3 years)',
    TrainingExperience.advanced: 'Advanced (3+ years)',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final c = context.fitColors;
    final d = data;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.lg);
    return Scaffold(
      appBar: AppBar(title: const Text('Configure goals')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            if (d.showWeightTarget) ...[
              Text('WEIGHT TARGET (OPTIONAL)', style: t.overline),
              const SizedBox(height: AppSpacing.sm),
              UnitNumberField(
                label: 'Target weight',
                unit: d.weightUnit,
                range: d.weightRange,
                isRequired: false,
                initialValue: d.targetWeight,
                onChanged: cb.onTargetWeight,
              ),
              const SizedBox(height: AppSpacing.sm),
              ListRow(
                title: 'Target date',
                value: d.targetDateLabel ?? 'Not set',
                onTap: cb.onPickDate,
              ),
              if (d.targetDateLabel != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: cb.onClearDate,
                    child: const Text('Clear date'),
                  ),
                ),
              Text(
                'A safe pace is up to about 1% of your body weight a week.',
                style: t.label,
              ),
              gap,
            ],
            if (d.showTraining) ...[
              AppDropdown<TrainingExperience>(
                label: 'Training experience',
                value: d.experience,
                options: [
                  for (final MapEntry(:key, :value) in _experience.entries)
                    DropdownOption(key, value),
                ],
                onChanged: cb.onExperience,
              ),
              gap,
            ],
            AppDropdown<int>(
              label: d.showTraining
                  ? 'Training days per week'
                  : 'Preferred workout days per week (optional)',
              value: d.trainingDays,
              options: [for (var i = 0; i <= 7; i++) DropdownOption(i, '$i')],
              onChanged: cb.onTrainingDays,
            ),
            gap,
            AppDropdown<ActivityLevel>(
              label: 'Confirm your activity level',
              value: d.activity,
              options: [
                for (final MapEntry(:key, :value) in activityLabels.entries)
                  DropdownOption(key, value),
              ],
              onChanged: cb.onActivity,
            ),
            if (d.problem != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(d.problem!, style: t.label.copyWith(color: c.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: d.canContinue ? cb.onNext : null,
              child: const Text('NEXT'),
            ),
          ],
        ),
      ),
    );
  }
}
