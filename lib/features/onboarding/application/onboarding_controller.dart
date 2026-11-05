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
  });

  final UnitSystem units;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activity;

  /// Optional; only used for the BMR estimate.
  final Sex sex;

  /// Age, height, weight and activity are required; sex is optional.
  bool get detailsComplete =>
      ageYears != null &&
      heightCm != null &&
      weightKg != null &&
      activity != null;

  OnboardingDraft copyWith({
    UnitSystem? units,
    int? Function()? ageYears,
    double? Function()? heightCm,
    double? Function()? weightKg,
    ActivityLevel? Function()? activity,
    Sex? sex,
  }) => OnboardingDraft(
    units: units ?? this.units,
    ageYears: ageYears != null ? ageYears() : this.ageYears,
    heightCm: heightCm != null ? heightCm() : this.heightCm,
    weightKg: weightKg != null ? weightKg() : this.weightKg,
    activity: activity != null ? activity() : this.activity,
    sex: sex ?? this.sex,
  );
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
}
