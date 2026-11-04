import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/profile_dao.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';

/// Persistence boundary for the local profile, goals, body weight, nutrition
/// targets and app preferences. Multi-row writes run in transactions.
class ProfileRepository {
  ProfileRepository(this._dao, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final ProfileDao _dao;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- profile

  Stream<UserProfileRow?> watchProfile() => _dao.watchProfile();

  /// Creates or updates the single profile. Throws [ArgumentError] for values
  /// outside the plausible ranges (they are never silently accepted).
  Future<void> saveProfile({
    int? ageYears,
    double? heightCm,
    Sex sex = Sex.unspecified,
    ActivityLevel? activityLevel,
    TrainingExperience? trainingExperience,
    int? trainingFrequencyPerWeek,
  }) {
    _checkRange('ageYears', ageYears, PlausibleRanges.ageYears);
    _checkRange('heightCm', heightCm, PlausibleRanges.heightCm);
    if (trainingFrequencyPerWeek != null &&
        (trainingFrequencyPerWeek < 0 || trainingFrequencyPerWeek > 14)) {
      throw ArgumentError.value(
        trainingFrequencyPerWeek,
        'trainingFrequencyPerWeek',
      );
    }
    return _dao.saveProfile(
      UserProfileCompanion(
        ageYears: Value(ageYears),
        heightCm: Value(heightCm),
        sex: Value(sex),
        activityLevel: Value(activityLevel),
        trainingExperience: Value(trainingExperience),
        trainingFrequencyPerWeek: Value(trainingFrequencyPerWeek),
      ),
    );
  }

  // ----------------------------------------------------------------- weight

  Future<int> logWeight(double kg, {DateTime? at, String? notes}) {
    _checkRange('kg', kg, PlausibleRanges.weightKg);
    return _dao.insertWeight(
      WeightEntriesCompanion.insert(
        weightKg: kg,
        recordedAt: at ?? _now(),
        notes: Value(notes),
      ),
    );
  }

  Future<bool> updateWeight(int id, {double? kg, DateTime? at, String? notes}) {
    if (kg != null) _checkRange('kg', kg, PlausibleRanges.weightKg);
    return _dao.updateWeight(
      id,
      WeightEntriesCompanion(
        weightKg: kg == null ? const Value.absent() : Value(kg),
        recordedAt: at == null ? const Value.absent() : Value(at),
        notes: notes == null ? const Value.absent() : Value(notes),
      ),
    );
  }

  Future<bool> deleteWeight(int id) => _dao.deleteWeight(id);

  /// Entries inside [range], newest first.
  Stream<List<WeightEntry>> watchWeights(DateRange range) =>
      _dao.watchWeights(from: range.start, to: range.end);

  /// Current weight is always derived from the latest entry (spec section 8).
  Stream<double?> watchCurrentWeightKg() =>
      _dao.watchLatestWeight().map((w) => w?.weightKg);

  // ------------------------------------------------------------------ goals

  Stream<List<FitnessGoal>> watchActiveGoals() => _dao.watchActiveGoals();

  /// Replaces the primary goal. The previous one is kept as inactive history.
  Future<void> setPrimaryGoal(
    GoalType goal, {
    double? targetWeightKg,
    DateTime? targetDate,
  }) {
    if (targetWeightKg != null) {
      _checkRange('targetWeightKg', targetWeightKg, PlausibleRanges.weightKg);
    }
    return _dao.replacePrimaryGoal(
      FitnessGoalsCompanion.insert(
        goalType: goal,
        isPrimary: true,
        targetWeightKg: Value(targetWeightKg),
        targetDate: Value(targetDate),
      ),
    );
  }

  Future<void> setSecondaryGoals(Set<GoalType> goals) =>
      _dao.replaceSecondaryGoals(goals);

  // ---------------------------------------------------------------- targets

  /// Records new nutrition targets effective from [effectiveFrom] (default
  /// today). Earlier days keep the targets that applied then.
  Future<void> setTargets({
    required int calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    required TargetSource source,
    DateTime? effectiveFrom,
  }) {
    if (calories <= 0 || calories > 10000) {
      throw ArgumentError.value(calories, 'calories');
    }
    return _dao.insertTargets(
      NutritionTargetsCompanion.insert(
        calories: calories,
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
        effectiveFrom: Dates.localDateKey(effectiveFrom ?? _now()),
        source: source,
      ),
    );
  }

  Stream<NutritionTarget?> watchTargetsOn(DateTime day) =>
      _dao.watchTargetsOn(Dates.localDateKey(day));

  Future<NutritionTarget?> targetsOn(DateTime day) =>
      _dao.targetsOn(Dates.localDateKey(day));

  // ------------------------------------------------------------ preferences

  Stream<UnitSystem> watchUnitSystem() =>
      _dao.watchSettings().map((s) => s.unitSystem);

  /// Display preference only: stored values stay metric.
  Future<void> setUnitSystem(UnitSystem system) =>
      _dao.updateSettings(AppSettingsCompanion(unitSystem: Value(system)));

  Stream<String> watchThemeMode() =>
      _dao.watchSettings().map((s) => s.themeMode);

  Future<void> setThemeMode(String mode) =>
      _dao.updateSettings(AppSettingsCompanion(themeMode: Value(mode)));

  Stream<bool> watchOnboardingCompleted() => _dao.watchOnboardingCompleted();

  Future<void> setOnboardingCompleted(bool completed) =>
      _dao.setOnboardingCompleted(completed);

  /// Runs [action] in one transaction (e.g. completing onboarding).
  Future<T> transaction<T>(Future<T> Function() action) =>
      _dao.transaction(action);

  static void _checkRange(String name, num? value, ValueRange range) {
    if (value != null && !range.contains(value)) {
      throw ArgumentError.value(
        value,
        name,
        'must be between ${range.min} and ${range.max}',
      );
    }
  }
}
