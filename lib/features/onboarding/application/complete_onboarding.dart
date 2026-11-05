import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/enums.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/profile_repository.dart';
import 'onboarding_controller.dart';

final completeOnboardingProvider = Provider<CompleteOnboarding>(
  (ref) => CompleteOnboarding(
    ref.watch(profileRepositoryProvider),
    ref.watch(dashboardRepositoryProvider),
  ),
);

/// Saves the onboarding draft and marks onboarding as done, all in ONE
/// transaction: the profile, the first weight entry, the goals, the
/// nutrition targets, the unit preference, the dashboard preset for the
/// main goal, and the onboarding flag. If anything fails, nothing is saved.
class CompleteOnboarding {
  CompleteOnboarding(this._profile, this._dashboard);

  final ProfileRepository _profile;
  final DashboardRepository _dashboard;

  Future<void> call(OnboardingDraft d) {
    final primary = d.primaryGoal;
    final targets = d.targets;
    if (!d.detailsComplete || primary == null || targets == null) {
      throw StateError('Onboarding is not complete.');
    }
    return _profile.transaction(() async {
      await _profile.saveProfile(
        ageYears: d.ageYears,
        heightCm: d.heightCm,
        sex: d.sex,
        activityLevel: d.activity,
        trainingExperience: d.experience,
        trainingFrequencyPerWeek: d.trainingDaysPerWeek,
      );
      await _profile.logWeight(d.weightKg!);
      await _profile.setPrimaryGoal(
        primary,
        targetWeightKg: d.asksTargetWeight ? d.targetWeightKg : null,
        targetDate: d.asksTargetWeight ? d.targetDate : null,
      );
      await _profile.setSecondaryGoals(d.secondaryGoals);
      await _profile.setTargets(
        calories: targets.calories,
        proteinG: targets.proteinG,
        carbsG: targets.carbsG,
        fatG: targets.fatG,
        source: targets.editedByUser
            ? TargetSource.user
            : TargetSource.calculated,
      );
      await _profile.setUnitSystem(d.units);
      await _dashboard.applyPreset(primary);
      await _profile.setOnboardingCompleted(true);
    });
  }
}
