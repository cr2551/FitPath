import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/widgets.dart';
import '../../profile/domain/metabolic_calculator.dart';
import '../../profile/domain/metabolic_profile.dart';
import '../application/onboarding_controller.dart';
import 'estimates_view.dart';

/// Onboarding step 5: BMI, BMR and TDEE from the draft, and the starting
/// calorie and macro targets, pre-filled with the suggestion and editable.
/// Edited targets are saved as set by the user.
class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends ConsumerState<EstimatesScreen> {
  /// Bumped to reload the fields after "Use suggestion".
  var _resets = 0;
  var _finishing = false;
  var _caloriesValid = true;

  @override
  void initState() {
    super.initState();
    // Start from the suggestion the first time.
    final d = ref.read(onboardingControllerProvider);
    if (d.targets == null) {
      final s = suggestedTargets(d);
      if (s != null) {
        Future.microtask(
          () => ref.read(onboardingControllerProvider.notifier).setTargets(s),
        );
      }
    }
  }

  void _edit(DraftTargets Function(DraftTargets t) change) {
    final current =
        ref.read(onboardingControllerProvider).targets ??
        const DraftTargets(calories: 0, editedByUser: true);
    ref.read(onboardingControllerProvider.notifier).setTargets(change(current));
  }

  static DraftTargets _with(
    DraftTargets t, {
    int? calories,
    double? Function()? protein,
    double? Function()? carbs,
    double? Function()? fat,
  }) => DraftTargets(
    calories: calories ?? t.calories,
    proteinG: protein != null ? protein() : t.proteinG,
    carbsG: carbs != null ? carbs() : t.carbsG,
    fatG: fat != null ? fat() : t.fatG,
    editedByUser: true,
  );

  Future<void> _finish() async {
    setState(() => _finishing = true);
    // Persisting the draft is #21 (complete onboarding).
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(onboardingControllerProvider);
    final e = MetabolicCalculator.estimate(metabolicProfileOf(d));
    // Until initState's microtask stores it, show the suggestion directly.
    final t = d.targets ?? suggestedTargets(d);

    return EstimatesView(
      fieldsKey: ValueKey(_resets),
      data: EstimatesViewData(
        stats: [
          StatItem(
            label: 'BMI',
            value: e.bmi.value == null
                ? Formatters.unknownValue
                : e.bmi.value!.value.toStringAsFixed(1),
          ),
          StatItem(
            label: 'BMR',
            value: Formatters.integer(e.bmr.value),
            unit: 'kcal',
          ),
          StatItem(
            label: 'TDEE',
            value: Formatters.integer(e.tdee.value),
            unit: 'kcal',
          ),
        ],
        missing: [
          if (!e.tdee.isAvailable)
            'Missing ${e.tdee.missing.map(_inputLabel).join(', ')}: go '
                'back and add it for a calorie estimate.',
        ],
        notes: {...e.bmr.notes, ...e.calorieTarget.notes}.toList(),
        explanation:
            'BMR (the calories your body burns at rest) uses the Mifflin-St '
            'Jeor equation with your age, height, weight and sex. TDEE '
            'multiplies it by your activity level. Your calorie target '
            'adjusts TDEE for your main goal; protein is set per kg of body '
            'weight, fat at about a quarter of calories and carbs make up '
            'the rest.',
        calories: t?.calories.toDouble(),
        proteinG: t?.proteinG,
        carbsG: t?.carbsG,
        fatG: t?.fatG,
        edited: t?.editedByUser ?? false,
        canFinish: t != null && t.calories > 0 && _caloriesValid,
        finishing: _finishing,
      ),
      callbacks: EstimatesCallbacks(
        onCalories: (v) {
          setState(() => _caloriesValid = v != null);
          if (v != null) _edit((t) => _with(t, calories: v.round()));
        },
        onProtein: (v) => _edit((t) => _with(t, protein: () => v)),
        onCarbs: (v) => _edit((t) => _with(t, carbs: () => v)),
        onFat: (v) => _edit((t) => _with(t, fat: () => v)),
        onResetToSuggestion: () {
          ref
              .read(onboardingControllerProvider.notifier)
              .setTargets(suggestedTargets(d));
          setState(() {
            _resets++;
            _caloriesValid = true;
          });
        },
        onFinish: _finish,
      ),
    );
  }
}

MetabolicProfile metabolicProfileOf(OnboardingDraft d) => MetabolicProfile(
  ageYears: d.ageYears,
  heightCm: d.heightCm,
  weightKg: d.weightKg,
  sex: d.sex,
  activityLevel: d.activity,
  goal: d.primaryGoal,
);

/// The calculated targets for the draft, or null when an input is missing.
DraftTargets? suggestedTargets(OnboardingDraft d) {
  final e = MetabolicCalculator.estimate(metabolicProfileOf(d));
  final kcal = e.calorieTarget.value?.kcal;
  if (kcal == null) return null;
  final m = e.macros.value;
  return DraftTargets(
    calories: kcal,
    proteinG: m?.proteinG.toDouble(),
    carbsG: m?.carbsG.toDouble(),
    fatG: m?.fatG.toDouble(),
    editedByUser: false,
  );
}

String _inputLabel(MetabolicInput i) => switch (i) {
  MetabolicInput.age => 'age',
  MetabolicInput.height => 'height',
  MetabolicInput.weight => 'weight',
  MetabolicInput.activityLevel => 'activity level',
  MetabolicInput.goal => 'main goal',
};
