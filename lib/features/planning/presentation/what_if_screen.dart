import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/metabolic_calculator.dart';
import '../../profile/domain/metabolic_profile.dart';
import '../../profile/domain/weight_projection.dart';
import '../../progress/presentation/weight/weight_chart.dart';
import '../../settings/presentation/settings_screen.dart' show activityLabel;
import 'what_if_view.dart';

/// What-if fitness calculator: projected weight for a chosen intake, and
/// "apply as my targets" (a new target row effective today).
class WhatIfScreen extends ConsumerStatefulWidget {
  const WhatIfScreen({super.key});

  @override
  ConsumerState<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends ConsumerState<WhatIfScreen> {
  bool _initialized = false;
  double? _kcal;
  ActivityLevel? _activity;

  /// In kg.
  double? _targetKg;
  bool _saving = false;

  Future<void> _apply(MetabolicProfile profile) async {
    final kcal = _kcal!.round();
    final macros = profile.weightKg == null || profile.goal == null
        ? null
        : MetabolicCalculator.macrosFor(
            kcal: kcal,
            weightKg: profile.weightKg!,
            goal: profile.goal!,
          );
    final ok = await showConfirmDialog(
      context,
      title: 'Apply ${Formatters.energy(kcal)} a day?',
      message:
          'This becomes your calorie target from today'
          '${macros == null ? '' : ', with matching protein, carbs and fat'}. '
          'Past days keep the targets that applied then.',
      confirmLabel: 'Apply',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .setTargets(
            calories: kcal,
            proteinG: macros?.proteinG.toDouble(),
            carbsG: macros?.carbsG.toDouble(),
            fatG: macros?.fatG.toDouble(),
            source: TargetSource.user,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Targets updated.')));
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your targets.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(metabolicProfileProvider);
    final targets = ref.watch(currentTargetsProvider);
    final goals = ref.watch(activeGoalsProvider);
    final weights = ref.watch(weightEntriesProvider(RangePreset.days90));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final all = <AsyncValue<Object?>>[profile, targets, goals, weights];

    WhatIfViewData? data;
    String? error;
    if (all.any((v) => v.hasError)) {
      error = "Couldn't load your profile.";
    } else if (all.every((v) => v.hasValue)) {
      final p = profile.requireValue;
      if (!_initialized) {
        _initialized = true;
        _kcal = targets.requireValue?.calories.toDouble();
        _activity = p.activityLevel;
        _targetKg = goals.requireValue
            .where((g) => g.targetWeightKg != null)
            .firstOrNull
            ?.targetWeightKg;
      }
      data = whatIfViewData(
        profile: p,
        kcal: _kcal?.round(),
        activity: _activity,
        targetKg: _targetKg,
        weights: weights.requireValue,
        today: DateTime.now(),
        units: units,
        saving: _saving,
      );
    }

    return WhatIfView(
      data: data,
      error: error,
      callbacks: WhatIfCallbacks(
        onKcal: (v) => setState(() => _kcal = v),
        onActivity: (a) => setState(() => _activity = a),
        onTarget: (v) => setState(
          () => _targetKg = v == null ? null : Units.weightFromInput(v, units),
        ),
        onApply: () => _apply(profile.requireValue),
        onEditDetails: () => context.push(Routes.profileDetails),
        onRetry: () => ref
          ..invalidate(profileProvider)
          ..invalidate(activeGoalsProvider)
          ..invalidate(weightEntriesProvider(RangePreset.days90)),
      ),
    );
  }
}

/// Maps the profile and the screen's inputs to the view. [weights] are the
/// recent weigh-ins, newest first.
WhatIfViewData whatIfViewData({
  required MetabolicProfile profile,
  required int? kcal,
  required ActivityLevel? activity,
  required double? targetKg,
  required List<WeightEntry> weights,
  required DateTime today,
  required UnitSystem units,
  bool saving = false,
}) {
  final unit = Units.weightUnit(units);
  double display(double kg) => Units.weightForDisplay(kg, units);
  final withActivity = MetabolicProfile(
    ageYears: profile.ageYears,
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
    sex: profile.sex,
    activityLevel: activity,
    goal: profile.goal,
  );
  final missing = MetabolicCalculator.bmr(withActivity).missing;

  WhatIfResult? result;
  if (missing.isEmpty && kcal != null && activity != null) {
    final estimate = WeightProjectionCalculator.project(
      profile: withActivity,
      intakeKcal: kcal,
      start: today,
      targetWeightKg: targetKg,
    );
    final p = estimate.value!;
    final days = p.days;
    final pace = display(p.weeklyPaceKg);
    final paceText = pace.abs() < 0.05
        ? '0 $unit'
        : '${pace > 0 ? '+' : '−'}${pace.abs().toStringAsFixed(1)} $unit';
    final since = Dates.addDays(today, -90);
    result = WhatIfResult(
      measured: [
        for (final w in weights.reversed)
          if (!w.recordedAt.isBefore(since))
            ChartPoint(w.recordedAt, display(w.weightKg)),
      ],
      // Weekly points keep the chart light; the last day is always kept.
      projected: [
        for (var i = 0; i < days.length; i++)
          if (i % 7 == 0 || i == days.length - 1)
            ChartPoint(days[i].date, display(days[i].weightKg)),
      ],
      target: targetKg == null ? null : display(targetKg),
      estimatedDate: targetKg == null
          ? 'No target set'
          : p.targetReachedOn == null
          ? 'Not within a year'
          : DateFormat('d MMM y').format(p.targetReachedOn!),
      weeklyPace: '$paceText a week',
      warnings: [
        if (p.fastPace) WeightProjectionCalculator.fastPaceNote,
        if (p.belowCalorieFloor) WeightProjectionCalculator.belowFloorNote,
        if (targetKg != null && p.targetReachedOn == null)
          WeightProjectionCalculator.notReachedNote,
      ],
      disclaimer: WeightProjectionCalculator.estimateNote,
      explanation:
          'Your energy needs (TDEE) start at about '
          '${Formatters.energy(p.startTdeeKcal)} a day, from your age, '
          'height, sex, weight and activity level (Mifflin-St Jeor). They are '
          'recalculated every day from the projected weight, so the pace '
          'slows as you get closer to the weight this intake maintains. Each '
          '${Formatters.integer(WeightProjectionCalculator.kcalPerKg)} kcal '
          'eaten above or below your needs counts as about 1 kg.',
      notes: [
        for (final n in estimate.notes)
          if (n != WeightProjectionCalculator.estimateNote) n,
      ],
    );
  }

  return WhatIfViewData(
    initialKcal: kcal?.toDouble(),
    activity: activity,
    activityOptions: [
      for (final a in ActivityLevel.values) DropdownOption(a, activityLabel(a)),
    ],
    initialTarget: targetKg == null ? null : display(targetKg),
    weightUnit: unit,
    targetRange: ValueRange(
      display(PlausibleRanges.weightKg.min),
      display(PlausibleRanges.weightKg.max),
    ),
    missingDetails: missing.isEmpty ? null : _missingText(missing),
    result: result,
    canApply: kcal != null && whatIfKcalRange.contains(kcal),
    saving: saving,
  );
}

/// "Add your age and height to see a projection."
String _missingText(Set<MetabolicInput> missing) {
  final names = [
    if (missing.contains(MetabolicInput.age)) 'age',
    if (missing.contains(MetabolicInput.height)) 'height',
    if (missing.contains(MetabolicInput.weight)) 'current weight',
  ];
  final list = names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return 'Add your $list in Your details to see a projection.';
}
