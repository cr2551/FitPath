import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/enums.dart';

/// Everything entered during onboarding, in canonical metric units.
/// Nothing is written to the database until onboarding completes (#21).
class OnboardingDraft {
  const OnboardingDraft({
    required this.units,
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.activity,
    this.sex = Sex.unspecified,
    this.primaryGoal,
    this.secondaryGoals = const {},
    this.targetWeightKg,
    this.targetDate,
    this.experience,
    this.trainingDaysPerWeek,
  });

  final UnitSystem units;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activity;

  /// Optional; only used for the BMR estimate.
  final Sex sex;

  final GoalType? primaryGoal;

  /// Never contains [primaryGoal].
  final Set<GoalType> secondaryGoals;

  /// Optional, for weight-loss goals.
  final double? targetWeightKg;
  final DateTime? targetDate;

  /// For muscle and strength goals.
  final TrainingExperience? experience;
  final int? trainingDaysPerWeek;

  /// Age, height, weight and activity are required; sex is optional.
  bool get detailsComplete =>
      ageYears != null &&
      heightCm != null &&
      weightKg != null &&
      activity != null;

  Set<GoalType> get allGoals => {?primaryGoal, ...secondaryGoals};

  bool get asksTargetWeight => allGoals.contains(GoalType.loseWeight);

  bool get asksTraining =>
      allGoals.contains(GoalType.buildMuscle) ||
      allGoals.contains(GoalType.improveStrength);

  OnboardingDraft copyWith({
    UnitSystem? units,
    int? Function()? ageYears,
    double? Function()? heightCm,
    double? Function()? weightKg,
    ActivityLevel? Function()? activity,
    Sex? sex,
    GoalType? Function()? primaryGoal,
    Set<GoalType>? secondaryGoals,
    double? Function()? targetWeightKg,
    DateTime? Function()? targetDate,
    TrainingExperience? Function()? experience,
    int? Function()? trainingDaysPerWeek,
  }) => OnboardingDraft(
    units: units ?? this.units,
    ageYears: ageYears != null ? ageYears() : this.ageYears,
    heightCm: heightCm != null ? heightCm() : this.heightCm,
    weightKg: weightKg != null ? weightKg() : this.weightKg,
    activity: activity != null ? activity() : this.activity,
    sex: sex ?? this.sex,
    primaryGoal: primaryGoal != null ? primaryGoal() : this.primaryGoal,
    secondaryGoals: secondaryGoals ?? this.secondaryGoals,
    targetWeightKg: targetWeightKg != null
        ? targetWeightKg()
        : this.targetWeightKg,
    targetDate: targetDate != null ? targetDate() : this.targetDate,
    experience: experience != null ? experience() : this.experience,
    trainingDaysPerWeek: trainingDaysPerWeek != null
        ? trainingDaysPerWeek()
        : this.trainingDaysPerWeek,
  );
}

/// Faster than this share of body weight per week is not offered as a plan.
const maxWeeklyLossShare = 0.01;

/// What is wrong with the goal details, or null when they can be saved.
/// Checks the weight-loss target: below the current weight, a date in the
/// future, and no faster than 1% of body weight a week.
String? goalDetailsProblem(OnboardingDraft d, DateTime today) {
  if (!d.asksTargetWeight) return null;
  final target = d.targetWeightKg, current = d.weightKg, date = d.targetDate;
  if (target == null || current == null) return null;
  if (target >= current) {
    return 'To lose weight, the target must be below your current weight.';
  }
  if (date == null) return null;
  final days = date.difference(today).inDays;
  if (days <= 0) return 'Pick a target date in the future.';
  final perWeek = (current - target) / (days / 7);
  if (perWeek > current * maxWeeklyLossShare) {
    return 'That is more than 1% of your body weight a week. Pick a later '
        'date or a closer target.';
  }
  return null;
}

/// Imperial for the countries that use it day to day, metric elsewhere.
UnitSystem unitsForLocale(Locale locale) =>
    const {'US', 'LR', 'MM'}.contains(locale.countryCode)
    ? UnitSystem.imperial
    : UnitSystem.metric;

/// Holds the onboarding draft across the onboarding screens.
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => OnboardingDraft(
    units: unitsForLocale(PlatformDispatcher.instance.locale),
  );

  void setUnits(UnitSystem units) => state = state.copyWith(units: units);

  void setAge(int? years) => state = state.copyWith(ageYears: () => years);

  void setHeightCm(double? cm) => state = state.copyWith(heightCm: () => cm);

  void setWeightKg(double? kg) => state = state.copyWith(weightKg: () => kg);

  void setActivity(ActivityLevel? a) =>
      state = state.copyWith(activity: () => a);

  void setSex(Sex sex) => state = state.copyWith(sex: sex);

  /// Sets the main goal; it is removed from the secondary goals.
  void setPrimaryGoal(GoalType goal) => state = state.copyWith(
    primaryGoal: () => goal,
    secondaryGoals: {...state.secondaryGoals}..remove(goal),
  );

  void toggleSecondaryGoal(GoalType goal) {
    if (goal == state.primaryGoal) return;
    final next = {...state.secondaryGoals};
    if (!next.remove(goal)) next.add(goal);
    state = state.copyWith(secondaryGoals: next);
  }

  void setTargetWeightKg(double? kg) =>
      state = state.copyWith(targetWeightKg: () => kg);

  void setTargetDate(DateTime? date) =>
      state = state.copyWith(targetDate: () => date);

  void setExperience(TrainingExperience? e) =>
      state = state.copyWith(experience: () => e);

  void setTrainingDays(int? days) =>
      state = state.copyWith(trainingDaysPerWeek: () => days);
}
