import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../../profile/application/profile_providers.dart';
import 'settings_view.dart';

final _themeModeProvider = StreamProvider<String>(
  (ref) => ref.watch(profileRepositoryProvider).watchThemeMode(),
);

/// The Profile & Settings tab.
///
/// Units are a display preference only: switching them never rewrites
/// stored values, which stay metric. The theme mode is persisted in
/// `app_settings.theme_mode` ('system' | 'light' | 'dark').
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final weight = ref.watch(currentWeightProvider);
    final goals = ref.watch(activeGoalsProvider);
    final targets = ref.watch(currentTargetsProvider);
    final units = ref.watch(unitSystemProvider);
    final theme = ref.watch(_themeModeProvider);
    final estimates = ref.watch(profileEstimatesProvider);
    final all = <AsyncValue<Object?>>[
      profile,
      weight,
      goals,
      targets,
      units,
      theme,
      estimates,
    ];

    SettingsViewData? data;
    String? error;
    if (all.any((v) => v.hasError)) {
      error = "Couldn't load your profile.";
    } else if (all.every((v) => v.hasValue)) {
      final system = units.requireValue;
      final p = profile.requireValue;
      final e = estimates.requireValue;
      final t = targets.requireValue;
      final goalList = goals.requireValue;
      data = SettingsViewData(
        age: p?.ageYears?.toString() ?? Formatters.unknownValue,
        height: Formatters.height(p?.heightCm, system),
        weight: Formatters.weight(weight.requireValue, system),
        activity: p?.activityLevel == null
            ? Formatters.unknownValue
            : activityLabel(p!.activityLevel!),
        bmi: e.bmi.value == null
            ? Formatters.unknownValue
            : e.bmi.value!.value.toStringAsFixed(1),
        bmr: Formatters.integer(e.bmr.value),
        tdee: Formatters.integer(e.tdee.value),
        estimateExplanation:
            'BMR uses the Mifflin-St Jeor equation with your age, height, '
            'weight and sex. TDEE multiplies it by your activity level. '
            'These are estimates, not medical advice.',
        estimateNotes: {...e.bmr.notes, ...e.tdee.notes}.toList(),
        goalsSummary: goalList.isEmpty
            ? 'No goal set'
            : goalList.map((g) => goalLabel(g.goalType)).join(' · '),
        targetsSummary: t == null
            ? 'Not set'
            : [
                Formatters.energy(t.calories),
                if (t.proteinG != null) 'P ${Formatters.integer(t.proteinG)}',
                if (t.carbsG != null) 'C ${Formatters.integer(t.carbsG)}',
                if (t.fatG != null) 'F ${Formatters.integer(t.fatG)} g',
                t.source == TargetSource.user ? 'set by you' : 'calculated',
              ].join(' · '),
        units: system,
        theme: switch (theme.requireValue) {
          'light' => ThemeChoice.light,
          'dark' => ThemeChoice.dark,
          _ => ThemeChoice.system,
        },
      );
    }

    final repo = ref.read(profileRepositoryProvider);
    return SettingsView(
      data: data,
      error: error,
      callbacks: SettingsCallbacks(
        onEditDetails: () => context.push(Routes.profileDetails),
        onGoals: () => context.push(Routes.goals),
        onTargets: () => context.push(Routes.targets),
        onUnitsChanged: repo.setUnitSystem,
        onThemeChanged: (t) => repo.setThemeMode(t.name),
        onDashboard: () => context.go(Routes.home),
        onBackup: () => context.push(Routes.backup),
        onReset: () => context.push(Routes.reset),
        onAbout: () => context.push(Routes.about),
        onRetry: () => ref
          ..invalidate(profileProvider)
          ..invalidate(_themeModeProvider),
      ),
    );
  }
}

String activityLabel(ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => 'Sedentary',
  ActivityLevel.light => 'Light',
  ActivityLevel.moderate => 'Moderate',
  ActivityLevel.active => 'Active',
  ActivityLevel.veryActive => 'Very active',
};

String goalLabel(GoalType g) => switch (g) {
  GoalType.loseWeight => 'Lose weight',
  GoalType.buildMuscle => 'Build muscle',
  GoalType.maintainWeight => 'Maintain weight',
  GoalType.improveStrength => 'Improve strength',
  GoalType.generalFitness => 'General fitness',
};
