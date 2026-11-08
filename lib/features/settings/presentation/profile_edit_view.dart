import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

/// Initial values and display units for the profile form.
class ProfileEditViewData {
  const ProfileEditViewData({
    required this.ageYears,
    required this.height,
    required this.heightUnit,
    required this.heightRange,
    required this.sex,
    required this.activity,
    required this.experience,
    required this.frequency,
    required this.canSave,
    required this.saving,
  });

  final double? ageYears;

  /// In the display unit ([heightUnit]).
  final double? height;
  final String heightUnit;
  final ValueRange heightRange;
  final Sex sex;
  final ActivityLevel? activity;
  final TrainingExperience? experience;
  final int? frequency;
  final bool canSave;
  final bool saving;
}

class ProfileEditCallbacks {
  const ProfileEditCallbacks({
    required this.onAge,
    required this.onHeight,
    required this.onSex,
    required this.onActivity,
    required this.onExperience,
    required this.onFrequency,
    required this.onSave,
    required this.onRetry,
  });

  /// Null while the field is empty or invalid.
  final ValueChanged<double?> onAge;
  final ValueChanged<double?> onHeight;
  final ValueChanged<Sex> onSex;
  final ValueChanged<ActivityLevel?> onActivity;
  final ValueChanged<TrainingExperience?> onExperience;
  final ValueChanged<int?> onFrequency;
  final VoidCallback onSave;
  final VoidCallback onRetry;
}

/// Pure layout for editing the profile ("Your details").
class ProfileEditView extends StatelessWidget {
  const ProfileEditView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  /// Null while loading.
  final ProfileEditViewData? data;
  final String? error;
  final ProfileEditCallbacks callbacks;

  static const _activity = {
    ActivityLevel.sedentary: 'Sedentary (little or no exercise)',
    ActivityLevel.light: 'Light (1-3 days a week)',
    ActivityLevel.moderate: 'Moderate (3-5 days a week)',
    ActivityLevel.active: 'Active (6-7 days a week)',
    ActivityLevel.veryActive: 'Very active (hard daily training)',
  };

  static const _experience = {
    TrainingExperience.beginner: 'Beginner',
    TrainingExperience.intermediate: 'Intermediate',
    TrainingExperience.advanced: 'Advanced',
  };

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
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

  Widget _form(BuildContext context, ProfileEditViewData d) {
    final t = context.textStyles;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.lg);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        UnitNumberField(
          label: 'Age',
          unit: 'years',
          range: PlausibleRanges.ageYears,
          decimals: 0,
          initialValue: d.ageYears,
          onChanged: cb.onAge,
        ),
        gap,
        UnitNumberField(
          label: 'Height',
          unit: d.heightUnit,
          range: d.heightRange,
          initialValue: d.height,
          onChanged: cb.onHeight,
        ),
        gap,
        Text('SEX (FOR CALORIE ESTIMATES)', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<Sex>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Sex.male, label: Text('Male')),
            ButtonSegment(value: Sex.female, label: Text('Female')),
            ButtonSegment(value: Sex.unspecified, label: Text('Not given')),
          ],
          selected: {d.sex},
          onSelectionChanged: (s) => cb.onSex(s.single),
        ),
        gap,
        AppDropdown<ActivityLevel?>(
          label: 'Activity level',
          value: d.activity,
          options: [
            const DropdownOption(null, 'Not set'),
            for (final MapEntry(:key, :value) in _activity.entries)
              DropdownOption(key, value),
          ],
          onChanged: cb.onActivity,
        ),
        gap,
        AppDropdown<TrainingExperience?>(
          label: 'Training experience',
          value: d.experience,
          options: [
            const DropdownOption(null, 'Not set'),
            for (final MapEntry(:key, :value) in _experience.entries)
              DropdownOption(key, value),
          ],
          onChanged: cb.onExperience,
        ),
        gap,
        AppDropdown<int?>(
          label: 'Training days per week',
          value: d.frequency,
          options: [
            const DropdownOption(null, 'Not set'),
            for (var i = 0; i <= 14; i++) DropdownOption(i, '$i'),
          ],
          onChanged: cb.onFrequency,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Log your weight from the Progress tab. Editing your details never '
          'changes your diary or workout history.',
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
