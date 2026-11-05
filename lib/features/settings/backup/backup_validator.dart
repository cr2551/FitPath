import 'dart:convert';

import '../../../core/database/app_database.dart';
import 'backup_models.dart';

/// Why a file can't be restored. [message] is shown to the user.
class InvalidBackup implements Exception {
  const InvalidBackup(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A backup that passed every check, with typed rows ready to insert.
class ValidBackup {
  const ValidBackup({
    required this.exportedAt,
    required this.appVersion,
    required this.settings,
    required this.profiles,
    required this.goals,
    required this.weights,
    required this.targets,
    required this.foods,
    required this.entries,
    required this.exercises,
    required this.sessions,
    required this.workoutExercises,
    required this.sets,
    required this.dashboardCards,
  });

  final DateTime exportedAt;
  final String appVersion;
  final AppSettingsRow settings;
  final List<UserProfileRow> profiles;
  final List<FitnessGoal> goals;
  final List<WeightEntry> weights;
  final List<NutritionTarget> targets;
  final List<FoodItem> foods;
  final List<FoodEntry> entries;
  final List<Exercise> exercises;
  final List<WorkoutSession> sessions;
  final List<WorkoutExercise> workoutExercises;
  final List<WorkoutSet> sets;
  final List<DashboardCard> dashboardCards;
}

/// Checks a backup file completely before anything touches the database:
/// format and version, every table and row (types and required fields),
/// unique ids and every reference between tables.
abstract final class BackupValidator {
  static ValidBackup parse(String text) {
    final Object? doc;
    try {
      doc = jsonDecode(text);
    } on FormatException {
      throw const InvalidBackup('This file is not valid JSON.');
    }
    if (doc is! Map<String, dynamic> || doc['format'] != backupFormatId) {
      throw const InvalidBackup('This is not a FitPath backup file.');
    }
    final version = doc['format_version'];
    if (version is! int) {
      throw const InvalidBackup('The backup has no format version.');
    }
    if (version > backupFormatVersion) {
      throw const InvalidBackup(
        'This backup was made by a newer version of FitPath. Update the app '
        'and try again.',
      );
    }
    if (version < 1) {
      throw const InvalidBackup('Unknown backup format version.');
    }
    final exportedAt = DateTime.tryParse('${doc['exported_at']}');
    if (exportedAt == null) {
      throw const InvalidBackup('The backup has no export date.');
    }
    final tables = doc['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const InvalidBackup('The backup has no data.');
    }

    List<T> rows<T>(String table, T Function(Map<String, dynamic>) parse) {
      final list = tables[table];
      if (list is! List) {
        throw InvalidBackup('The backup is missing "$table".');
      }
      return [
        for (var i = 0; i < list.length; i++)
          () {
            final raw = list[i];
            if (raw is! Map<String, dynamic>) {
              throw InvalidBackup('Row ${i + 1} of "$table" is not a record.');
            }
            try {
              return parse(raw);
            } on Object {
              throw InvalidBackup(
                'Row ${i + 1} of "$table" has missing or invalid values.',
              );
            }
          }(),
      ];
    }

    const s = backupSerializer;
    final settings = rows(
      BackupTables.appSettings,
      (j) => AppSettingsRow.fromJson(j, serializer: s),
    );
    if (settings.length != 1) {
      throw const InvalidBackup('The backup must contain one settings row.');
    }
    final backup = ValidBackup(
      exportedAt: exportedAt,
      appVersion: '${doc['app_version'] ?? ''}',
      settings: settings.single,
      profiles: rows(
        BackupTables.userProfile,
        (j) => UserProfileRow.fromJson(j, serializer: s),
      ),
      goals: rows(
        BackupTables.fitnessGoals,
        (j) => FitnessGoal.fromJson(j, serializer: s),
      ),
      weights: rows(
        BackupTables.weightEntries,
        (j) => WeightEntry.fromJson(j, serializer: s),
      ),
      targets: rows(
        BackupTables.nutritionTargets,
        (j) => NutritionTarget.fromJson(j, serializer: s),
      ),
      foods: rows(
        BackupTables.foodItems,
        (j) => FoodItem.fromJson(j, serializer: s),
      ),
      entries: rows(
        BackupTables.foodEntries,
        (j) => FoodEntry.fromJson(j, serializer: s),
      ),
      exercises: rows(
        BackupTables.exercises,
        (j) => Exercise.fromJson(j, serializer: s),
      ),
      sessions: rows(
        BackupTables.workoutSessions,
        (j) => WorkoutSession.fromJson(j, serializer: s),
      ),
      workoutExercises: rows(
        BackupTables.workoutExercises,
        (j) => WorkoutExercise.fromJson(j, serializer: s),
      ),
      sets: rows(
        BackupTables.workoutSets,
        (j) => WorkoutSet.fromJson(j, serializer: s),
      ),
      dashboardCards: rows(
        BackupTables.dashboardCards,
        (j) => DashboardCard.fromJson(j, serializer: s),
      ),
    );
    _checkReferences(backup);
    return backup;
  }

  static void _checkReferences(ValidBackup b) {
    Set<int> ids(String table, Iterable<int> values) {
      final set = <int>{};
      for (final id in values) {
        if (!set.add(id)) {
          throw InvalidBackup('"$table" contains the id $id twice.');
        }
      }
      return set;
    }

    void refs(String table, Iterable<int> values, Set<int> targets) {
      for (final v in values) {
        if (!targets.contains(v)) {
          throw InvalidBackup(
            '"$table" refers to a record ($v) that is not in the backup.',
          );
        }
      }
    }

    final foods = ids(BackupTables.foodItems, b.foods.map((f) => f.id));
    final exercises = ids(BackupTables.exercises, b.exercises.map((e) => e.id));
    final sessions = ids(
      BackupTables.workoutSessions,
      b.sessions.map((s) => s.id),
    );
    final workoutExercises = ids(
      BackupTables.workoutExercises,
      b.workoutExercises.map((e) => e.id),
    );
    ids(BackupTables.foodEntries, b.entries.map((e) => e.id));
    ids(BackupTables.workoutSets, b.sets.map((s) => s.id));
    ids(BackupTables.userProfile, b.profiles.map((p) => p.id));
    ids(BackupTables.fitnessGoals, b.goals.map((g) => g.id));
    ids(BackupTables.weightEntries, b.weights.map((w) => w.id));
    ids(BackupTables.nutritionTargets, b.targets.map((t) => t.id));
    ids(BackupTables.dashboardCards, b.dashboardCards.map((c) => c.id));

    refs(BackupTables.foodEntries, b.entries.map((e) => e.foodItemId), foods);
    refs(
      BackupTables.workoutExercises,
      b.workoutExercises.map((e) => e.sessionId),
      sessions,
    );
    refs(
      BackupTables.workoutExercises,
      b.workoutExercises.map((e) => e.exerciseId),
      exercises,
    );
    refs(
      BackupTables.workoutSets,
      b.sets.map((s) => s.workoutExerciseId),
      workoutExercises,
    );
  }
}
