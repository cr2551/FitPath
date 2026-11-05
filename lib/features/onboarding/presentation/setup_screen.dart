import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../application/onboarding_controller.dart';
import 'setup_view.dart';

/// "Let's get you set up": units, age, height, weight, activity and an
/// optional sex. The draft keeps metric values; the form shows the chosen
/// units.
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(onboardingControllerProvider);
    final c = ref.read(onboardingControllerProvider.notifier);
    final imperial = d.units == UnitSystem.imperial;
    final cm = d.heightCm, kg = d.weightKg;

    return SetupView(
      data: SetupViewData(
        units: d.units,
        ageYears: d.ageYears?.toDouble(),
        height: cm == null ? null : (imperial ? Units.cmToInches(cm) : cm),
        heightUnit: imperial ? 'in' : 'cm',
        heightRange: imperial
            ? ValueRange(
                Units.cmToInches(PlausibleRanges.heightCm.min),
                Units.cmToInches(PlausibleRanges.heightCm.max),
              )
            : PlausibleRanges.heightCm,
        weight: kg == null ? null : Units.weightForDisplay(kg, d.units),
        weightUnit: Units.weightUnit(d.units),
        weightRange: imperial
            ? ValueRange(
                Units.kgToLb(PlausibleRanges.weightKg.min),
                Units.kgToLb(PlausibleRanges.weightKg.max),
              )
            : PlausibleRanges.weightKg,
        activity: d.activity,
        sex: d.sex,
        canContinue: d.detailsComplete,
      ),
      callbacks: SetupCallbacks(
        onUnits: c.setUnits,
        onAge: (v) => c.setAge(v?.round()),
        onHeight: (v) => c.setHeightCm(
          v == null ? null : (imperial ? Units.inchesToCm(v) : v),
        ),
        onWeight: (v) =>
            c.setWeightKg(v == null ? null : Units.weightFromInput(v, d.units)),
        onActivity: c.setActivity,
        onSex: c.setSex,
        onNext: () => context.push(Routes.onboardingGoals),
      ),
    );
  }
}
