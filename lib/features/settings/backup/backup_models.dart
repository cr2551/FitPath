import 'package:drift/drift.dart';

/// Identifies a FitPath backup file (`docs/backup-format.md`).
const backupFormatId = 'fitpath-backup';

/// Bumped when the backup layout changes incompatibly.
const backupFormatVersion = 1;

/// Dates are ISO 8601 strings, so files are readable and timezone-explicit.
const backupSerializer = ValueSerializer.defaults(
  serializeDateTimeValuesAsString: true,
);

/// Table keys in `tables`, in an order that satisfies foreign keys when
/// rows are inserted front to back.
abstract final class BackupTables {
  static const appSettings = 'app_settings';
  static const userProfile = 'user_profile';
  static const fitnessGoals = 'fitness_goals';
  static const weightEntries = 'weight_entries';
  static const nutritionTargets = 'nutrition_targets';
  static const foodItems = 'food_items';
  static const foodEntries = 'food_entries';
  static const exercises = 'exercises';
  static const workoutSessions = 'workout_sessions';
  static const workoutExercises = 'workout_exercises';
  static const workoutSets = 'workout_sets';
  static const dashboardCards = 'dashboard_cards';

  static const all = [
    appSettings,
    userProfile,
    fitnessGoals,
    weightEntries,
    nutritionTargets,
    foodItems,
    foodEntries,
    exercises,
    workoutSessions,
    workoutExercises,
    workoutSets,
    dashboardCards,
  ];
}

/// A parsed or freshly built backup.
class BackupDocument {
  const BackupDocument({
    required this.formatVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.tables,
  });

  final int formatVersion;
  final String appVersion;
  final DateTime exportedAt;

  /// Rows per table key ([BackupTables]), each row a Drift `toJson` map.
  final Map<String, List<Map<String, dynamic>>> tables;

  int get rowCount => tables.values.fold(0, (n, rows) => n + rows.length);

  Map<String, dynamic> toJson() => {
    'format': backupFormatId,
    'format_version': formatVersion,
    'app_version': appVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'tables': tables,
  };
}
