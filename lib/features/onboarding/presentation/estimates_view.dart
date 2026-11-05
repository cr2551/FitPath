import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/widgets/widgets.dart';

class EstimatesViewData {
  const EstimatesViewData({
    required this.stats,
    required this.missing,
    required this.notes,
    required this.explanation,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.edited,
    required this.canFinish,
    required this.finishing,
  });

  /// BMI, BMR, TDEE ("—" when unavailable).
  final List<StatItem> stats;

  /// E.g. "Add your age to estimate BMR."; empty when nothing is missing.
  final List<String> missing;

  /// Caveats from the calculator (sex not given, guardrail applied).
  final List<String> notes;

  /// How the numbers are calculated, for the estimate sheet.
  final String explanation;

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// The targets differ from the suggestion.
  final bool edited;
  final bool canFinish;
  final bool finishing;
}

class EstimatesCallbacks {
  const EstimatesCallbacks({
    required this.onCalories,
    required this.onProtein,
    required this.onCarbs,
    required this.onFat,
    required this.onResetToSuggestion,
    required this.onFinish,
  });

  /// Null while empty or invalid.
  final ValueChanged<double?> onCalories;
  final ValueChanged<double?> onProtein;
  final ValueChanged<double?> onCarbs;
  final ValueChanged<double?> onFat;
  final VoidCallback onResetToSuggestion;
  final VoidCallback onFinish;
}

/// Pure layout for the last onboarding step: estimates and the editable
/// starting targets.
class EstimatesView extends StatelessWidget {
  const EstimatesView({
    super.key,
    required this.data,
    required this.callbacks,
    required this.fieldsKey,
  });

  final EstimatesViewData data;
  final EstimatesCallbacks callbacks;

  /// Changes when the targets are reset, so the fields reload.
  final Key fieldsKey;

  static const kcalRange = ValueRange(800, 10000);
  static const gramsRange = ValueRange(0, 1000);

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final c = context.fitColors;
    final d = data;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(title: const Text('Initial estimates')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              header: CardHeader(
                title: 'Your estimates',
                trailing: EstimateBadge(
                  onTap: () => showEstimateSheet(
                    context,
                    title: 'How these are calculated',
                    explanation: d.explanation,
                    notes: d.notes,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatRow(items: d.stats),
                  for (final line in [...d.missing, ...d.notes]) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(line, style: t.label.copyWith(color: c.warning)),
                  ],
                ],
              ),
            ),
            gap,
            SectionCard(
              header: CardHeader(
                title: 'Daily targets',
                subtitle: TextSpan(
                  text: d.edited ? 'Set by you' : 'Suggested for your goal',
                ),
                trailing: d.edited
                    ? TextButton(
                        onPressed: cb.onResetToSuggestion,
                        child: const Text('Use suggestion'),
                      )
                    : null,
              ),
              child: Column(
                key: fieldsKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UnitNumberField(
                    label: 'Calories',
                    unit: 'kcal',
                    range: kcalRange,
                    decimals: 0,
                    initialValue: d.calories,
                    onChanged: cb.onCalories,
                  ),
                  gap,
                  UnitNumberField(
                    label: 'Protein',
                    unit: 'g',
                    range: gramsRange,
                    decimals: 0,
                    isRequired: false,
                    initialValue: d.proteinG,
                    onChanged: cb.onProtein,
                  ),
                  gap,
                  UnitNumberField(
                    label: 'Carbs',
                    unit: 'g',
                    range: gramsRange,
                    decimals: 0,
                    isRequired: false,
                    initialValue: d.carbsG,
                    onChanged: cb.onCarbs,
                  ),
                  gap,
                  UnitNumberField(
                    label: 'Fat',
                    unit: 'g',
                    range: gramsRange,
                    decimals: 0,
                    isRequired: false,
                    initialValue: d.fatG,
                    onChanged: cb.onFat,
                  ),
                ],
              ),
            ),
            gap,
            Text(
              'These are estimates from standard formulas, not medical '
              'advice. Talk to a doctor or registered dietitian before big '
              'changes, especially if you are pregnant, under 18 or have a '
              'medical condition. You can change your targets any time in '
              'Profile.',
              style: t.label,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: AppTheme.accentButton(context),
              onPressed: d.canFinish && !d.finishing ? cb.onFinish : null,
              child: const Text('FINISH SETUP'),
            ),
          ],
        ),
      ),
    );
  }
}
