import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../profile/domain/goal_rules.dart';
import '../../settings/presentation/goals_view.dart' show goalLabels;
import '../application/onboarding_controller.dart';
import 'onboarding_goals_view.dart';

/// Onboarding: one main goal and any secondary goals.
class OnboardingGoalsScreen extends ConsumerWidget {
  const OnboardingGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(onboardingControllerProvider);
    final c = ref.read(onboardingControllerProvider.notifier);
    return OnboardingGoalsView(
      labels: goalLabels,
      primary: d.primaryGoal,
      secondary: d.secondaryGoals,
      secondaryOptions: GoalRules.secondaryOptions(d.primaryGoal),
      onPrimary: c.setPrimaryGoal,
      onToggleSecondary: c.toggleSecondaryGoal,
      onNext: () => context.push(Routes.goalDetails),
    );
  }
}
