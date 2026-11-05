import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

/// Values shown on the setup form, in the display units.
class SetupViewData {
  const SetupViewData({
    required this.units,
    required this.ageYears,
    required this.height,
    required this.heightUnit,
    required this.heightRange,
    required this.weight,
    required this.weightUnit,
    required this.weightRange,
    required this.activity,
    required this.sex,
    required this.canContinue,
  });

  final UnitSystem units;
  final double? ageYears;
  final double? height;
  final String heightUnit;
  final ValueRange heightRange;
  final double? weight;
  final String weightUnit;
  final ValueRange weightRange;
  final ActivityLevel? activity;
  final Sex sex;
  final bool canContinue;
}

class SetupCallbacks {
  const SetupCallbacks({
    required this.onUnits,
    required this.onAge,
    required this.onHeight,
    required this.onWeight,
    required this.onActivity,
    required this.onSex,
    required this.onNext,
  });

  final ValueChanged<UnitSystem> onUnits;

  /// Null while the field is empty or invalid. Display units.
  final ValueChanged<double?> onAge;
  final ValueChanged<double?> onHeight;
  final ValueChanged<double?> onWeight;
  final ValueChanged<ActivityLevel?> onActivity;
  final ValueChanged<Sex> onSex;
  final VoidCallback onNext;
}

/// Pure layout for "Let's get you set up".
class SetupView extends StatelessWidget {
  const SetupView({super.key, required this.data, required this.callbacks});

  final SetupViewData data;
  final SetupCallbacks callbacks;

  static const activityLabels = {
    ActivityLevel.sedentary: 'Sedentary (little or no exercise)',
    ActivityLevel.light: 'Light (1-3 days a week)',
    ActivityLevel.moderate: 'Moderate (3-5 days a week)',
    ActivityLevel.active: 'Active (6-7 days a week)',
    ActivityLevel.veryActive: 'Very active (hard daily training)',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final d = data;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.lg);
    // Re-create the number fields when the units change, so they show the
    // converted values.
    final unitsKey = ValueKey(d.units);

    return Scaffold(
      appBar: AppBar(title: const Text("Let's get you set up")),
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
              'These give you a starting calorie estimate. You can change '
              'them later in Profile.',
              style: t.label,
            ),
            gap,
            Text('UNITS', style: t.overline),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text('METRIC (KG, CM)'),
                ),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('IMPERIAL (LB, IN)'),
                ),
              ],
              selected: {d.units},
              onSelectionChanged: (s) => cb.onUnits(s.single),
            ),
            gap,
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
              key: ValueKey(('height', unitsKey)),
              label: 'Height',
              unit: d.heightUnit,
              range: d.heightRange,
              initialValue: d.height,
              onChanged: cb.onHeight,
            ),
            gap,
            UnitNumberField(
              key: ValueKey(('weight', unitsKey)),
              label: 'Current weight',
              unit: d.weightUnit,
              range: d.weightRange,
              initialValue: d.weight,
              onChanged: cb.onWeight,
            ),
            gap,
            DropdownButtonFormField<ActivityLevel>(
              elevation: 0,
              dropdownColor: Theme.of(context).colorScheme.surface,
              initialValue: d.activity,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Activity level',
                helperText: 'Outside of planned workouts too',
              ),
              items: [
                for (final MapEntry(:key, :value) in activityLabels.entries)
                  DropdownMenuItem(value: key, child: Text(value)),
              ],
              onChanged: cb.onActivity,
            ),
            gap,
            Text('SEX (OPTIONAL)', style: t.overline),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<Sex>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Sex.male, label: Text('MALE')),
                ButtonSegment(value: Sex.female, label: Text('FEMALE')),
                ButtonSegment(value: Sex.unspecified, label: Text('SKIP')),
              ],
              selected: {d.sex},
              onSelectionChanged: (s) => cb.onSex(s.single),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Only used to estimate how many calories your body burns at '
              'rest. If you skip it, FitPath uses an average and tells you '
              'the estimate is less precise.',
              style: t.label,
            ),
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
