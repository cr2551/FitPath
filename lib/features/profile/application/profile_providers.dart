import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/models/enums.dart';
import '../data/profile_repository.dart';
import '../domain/metabolic_calculator.dart';
import '../domain/metabolic_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider).profileDao),
);

final profileProvider = StreamProvider<UserProfileRow?>(
  (ref) => ref.watch(profileRepositoryProvider).watchProfile(),
);

/// Latest weight entry in kg, or null before the first entry.
final currentWeightProvider = StreamProvider<double?>(
  (ref) => ref.watch(profileRepositoryProvider).watchCurrentWeightKg(),
);

/// Active goals, primary first.
final activeGoalsProvider = StreamProvider<List<FitnessGoal>>(
  (ref) => ref.watch(profileRepositoryProvider).watchActiveGoals(),
);

/// The stored theme preference ('system' | 'light' | 'dark').
final themeModeProvider = StreamProvider<ThemeMode>(
  (ref) => ref
      .watch(profileRepositoryProvider)
      .watchThemeMode()
      .map(
        (mode) => switch (mode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      ),
);

final unitSystemProvider = StreamProvider<UnitSystem>(
  (ref) => ref.watch(profileRepositoryProvider).watchUnitSystem(),
);

/// Weight entries for a progress range, newest first.
final weightEntriesProvider =
    StreamProvider.family<List<WeightEntry>, RangePreset>(
      (ref, preset) => ref
          .watch(profileRepositoryProvider)
          .watchWeights(Dates.rangeFor(preset, DateTime.now())),
    );

/// Targets in effect on a day, keyed by local date key (yyyy-MM-dd) so equal
/// days share one subscription.
final targetsForDateProvider = StreamProvider.family<NutritionTarget?, String>(
  (ref, dateKey) => ref
      .watch(profileRepositoryProvider)
      .watchTargetsOn(Dates.fromLocalDateKey(dateKey)),
);

final currentTargetsProvider = Provider<AsyncValue<NutritionTarget?>>(
  (ref) =>
      ref.watch(targetsForDateProvider(Dates.localDateKey(DateTime.now()))),
);

/// The calculator inputs assembled from the stored profile, the latest weight
/// and the active primary goal.
final metabolicProfileProvider = Provider<AsyncValue<MetabolicProfile>>((ref) {
  final profile = ref.watch(profileProvider);
  final weight = ref.watch(currentWeightProvider);
  final goals = ref.watch(activeGoalsProvider);

  for (final v in <AsyncValue<Object?>>[profile, weight, goals]) {
    if (v.hasError) return AsyncValue.error(v.error!, v.stackTrace!);
  }
  if (!profile.hasValue || !weight.hasValue || !goals.hasValue) {
    return const AsyncValue.loading();
  }

  final p = profile.requireValue;
  final primary = goals.requireValue.where((g) => g.isPrimary).firstOrNull;
  return AsyncValue.data(
    MetabolicProfile(
      ageYears: p?.ageYears,
      heightCm: p?.heightCm,
      weightKg: weight.requireValue,
      sex: p?.sex ?? Sex.unspecified,
      activityLevel: p?.activityLevel,
      goal: primary?.goalType,
    ),
  );
});

/// BMI, BMR, TDEE and suggested targets for the stored profile.
final profileEstimatesProvider = Provider<AsyncValue<ProfileEstimates>>(
  (ref) => ref
      .watch(metabolicProfileProvider)
      .whenData(MetabolicCalculator.estimate),
);
