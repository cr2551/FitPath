import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';
import '../app_database.dart';
import '../tables/app_tables.dart';
import '../tables/profile_tables.dart';

part 'profile_dao.g.dart';

/// Profile, goals, weight, targets, settings and metadata queries.
@DriftAccessor(
  tables: [
    UserProfile,
    FitnessGoals,
    WeightEntries,
    NutritionTargets,
    AppSettings,
    AppMetadata,
  ],
)
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.attachedDatabase);

  // ---------------------------------------------------------------- profile

  Stream<UserProfileRow?> watchProfile() =>
      (select(userProfile)..limit(1)).watchSingleOrNull();

  Future<UserProfileRow?> getProfile() =>
      (select(userProfile)..limit(1)).getSingleOrNull();

  /// Inserts the single profile row, or updates it if it already exists.
  Future<void> saveProfile(UserProfileCompanion data) => transaction(() async {
    final existing = await getProfile();
    if (existing == null) {
      await into(userProfile).insert(data);
    } else {
      await (update(userProfile)..where((p) => p.id.equals(existing.id))).write(
        data.copyWith(updatedAt: Value(DateTime.now())),
      );
    }
  });

  // ----------------------------------------------------------------- weight

  Future<int> insertWeight(WeightEntriesCompanion entry) =>
      into(weightEntries).insert(entry);

  Future<bool> updateWeight(int id, WeightEntriesCompanion entry) async =>
      await (update(
        weightEntries,
      )..where((w) => w.id.equals(id))).write(entry) ==
      1;

  Future<bool> deleteWeight(int id) async =>
      await (delete(weightEntries)..where((w) => w.id.equals(id))).go() == 1;

  /// Entries in `[from, to)`, newest first. Null bounds are open.
  Stream<List<WeightEntry>> watchWeights({DateTime? from, DateTime? to}) {
    final q = select(weightEntries)
      ..orderBy([(w) => OrderingTerm.desc(w.recordedAt)]);
    if (from != null) q.where((w) => w.recordedAt.isBiggerOrEqualValue(from));
    if (to != null) q.where((w) => w.recordedAt.isSmallerThanValue(to));
    return q.watch();
  }

  Stream<WeightEntry?> watchLatestWeight() =>
      (select(weightEntries)
            ..orderBy([
              (w) => OrderingTerm.desc(w.recordedAt),
              (w) => OrderingTerm.desc(w.id),
            ])
            ..limit(1))
          .watchSingleOrNull();

  // ------------------------------------------------------------------ goals

  Stream<List<FitnessGoal>> watchActiveGoals() =>
      (select(fitnessGoals)
            ..where((g) => g.isActive.equals(true))
            ..orderBy([
              (g) => OrderingTerm.desc(g.isPrimary),
              (g) => OrderingTerm.asc(g.id),
            ]))
          .watch();

  Future<List<FitnessGoal>> allGoals() =>
      (select(fitnessGoals)..orderBy([(g) => OrderingTerm.asc(g.id)])).get();

  /// Deactivates the current primary goal (keeping it as history) and makes
  /// [goal] the active primary goal.
  Future<int> replacePrimaryGoal(FitnessGoalsCompanion goal) => transaction(
    () async {
      await (update(fitnessGoals)
            ..where((g) => g.isActive.equals(true) & g.isPrimary.equals(true)))
          .write(const FitnessGoalsCompanion(isActive: Value(false)));
      return into(fitnessGoals)
          .insert(goal.copyWith(isPrimary: const Value(true)));
    },
  );

  /// Makes exactly [types] the active secondary goals. Removed ones are
  /// deactivated (kept as history); existing ones are left untouched.
  Future<void> replaceSecondaryGoals(
    Set<GoalType> types,
  ) => transaction(() async {
    final active = await (select(
      fitnessGoals,
    )..where((g) => g.isActive.equals(true) & g.isPrimary.equals(false))).get();
    final keep = <GoalType>{};
    for (final g in active) {
      if (types.contains(g.goalType)) {
        keep.add(g.goalType);
      } else {
        await (update(fitnessGoals)..where((x) => x.id.equals(g.id))).write(
          const FitnessGoalsCompanion(isActive: Value(false)),
        );
      }
    }
    for (final t in types.difference(keep)) {
      await into(fitnessGoals)
          .insert(FitnessGoalsCompanion.insert(goalType: t, isPrimary: false));
    }
  });

  // ---------------------------------------------------------------- targets

  Future<int> insertTargets(NutritionTargetsCompanion targets) =>
      into(nutritionTargets).insert(targets);

  /// The targets in effect on [dateKey] (yyyy-MM-dd): the newest row whose
  /// `effective_from` is on or before that day.
  SimpleSelectStatement<$NutritionTargetsTable, NutritionTarget> _targetsOn(
    String dateKey,
  ) => select(nutritionTargets)
    ..where((t) => t.effectiveFrom.isSmallerOrEqualValue(dateKey))
    ..orderBy([
      (t) => OrderingTerm.desc(t.effectiveFrom),
      (t) => OrderingTerm.desc(t.id),
    ])
    ..limit(1);

  Future<NutritionTarget?> targetsOn(String dateKey) =>
      _targetsOn(dateKey).getSingleOrNull();

  Stream<NutritionTarget?> watchTargetsOn(String dateKey) =>
      _targetsOn(dateKey).watchSingleOrNull();

  // ------------------------------------------------------ settings, metadata

  Stream<AppSettingsRow> watchSettings() => select(appSettings).watchSingle();

  Future<void> updateSettings(AppSettingsCompanion data) =>
      (update(appSettings)..where((s) => s.id.equals(1))).write(data);

  Stream<bool> watchOnboardingCompleted() =>
      select(appMetadata).watchSingle().map((m) => m.onboardingCompleted);

  Future<void> setOnboardingCompleted(bool completed) =>
      (update(appMetadata)..where((m) => m.id.equals(1))).write(
        AppMetadataCompanion(onboardingCompleted: Value(completed)),
      );
}
