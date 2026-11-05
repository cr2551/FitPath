import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../application/onboarding_controller.dart';
import 'goal_details_view.dart';
import 'setup_view.dart';

/// Onboarding: the follow-up questions for the chosen goals. Weight loss
/// asks for an optional target weight and date (no faster than 1% of body
/// weight a week); muscle and strength goals ask for experience and
/// training days; everyone confirms their activity level.
class GoalDetailsScreen extends ConsumerWidget {
  const GoalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(onboardingControllerProvider);
    final c = ref.read(onboardingControllerProvider.notifier);
    final today = Dates.startOfDay(DateTime.now());
    final imperial = d.units == UnitSystem.imperial;
    final problem = goalDetailsProblem(d, today);
    final target = d.targetWeightKg;

    return GoalDetailsView(
      activityLabels: SetupView.activityLabels,
      data: GoalDetailsViewData(
        showWeightTarget: d.asksTargetWeight,
        showTraining: d.asksTraining,
        targetWeight: target == null
            ? null
            : Units.weightForDisplay(target, d.units),
        weightUnit: Units.weightUnit(d.units),
        weightRange: imperial
            ? ValueRange(
                Units.kgToLb(PlausibleRanges.weightKg.min),
                Units.kgToLb(PlausibleRanges.weightKg.max),
              )
            : PlausibleRanges.weightKg,
        targetDateLabel: d.targetDate == null
            ? null
            : DateFormat('d MMM y').format(d.targetDate!),
        activity: d.activity,
        experience: d.experience,
        trainingDays: d.trainingDaysPerWeek,
        problem: problem,
        canContinue:
            problem == null &&
            d.activity != null &&
            (!d.asksTraining ||
                (d.experience != null && d.trainingDaysPerWeek != null)),
      ),
      callbacks: GoalDetailsCallbacks(
        onTargetWeight: (v) => c.setTargetWeightKg(
          v == null ? null : Units.weightFromInput(v, d.units),
        ),
        onPickDate: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: d.targetDate ?? Dates.addDays(today, 90),
            firstDate: Dates.addDays(today, 1),
            lastDate: DateTime(today.year + 5, today.month, today.day),
          );
          if (picked != null) c.setTargetDate(picked);
        },
        onClearDate: () => c.setTargetDate(null),
        onActivity: c.setActivity,
        onExperience: c.setExperience,
        onTrainingDays: c.setTrainingDays,
        onNext: () => context.push(Routes.estimates),
      ),
    );
  }
}
