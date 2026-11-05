import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/enums.dart';
import 'backup_models.dart';

/// Builds the JSON backup of every user-owned record (FR-14, NFR-07).
///
/// * Ids are kept, so relationships survive a restore.
/// * Custom and cached Open Food Facts foods are included; bundled foods
///   only when a diary entry references them. Same for exercises: custom
///   ones always, bundled ones only when a session uses them.
/// * Nothing secret is stored in the database, so nothing secret is
///   exported.
class ExportService {
  ExportService(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<BackupDocument> buildBackup({
    required String appVersion,
  }) => _db.transaction(() async {
    List<Map<String, dynamic>> rows(List<DataClass> list) => [
      for (final r in list) r.toJson(serializer: backupSerializer),
    ];

    final entries = await _db.select(_db.foodEntries).get();
    final usedFoods = {for (final e in entries) e.foodItemId};
    final foods =
        await (_db.select(_db.foodItems)
              ..where(
                (f) =>
                    f.source.equalsValue(FoodSource.bundled).not() |
                    f.id.isIn(usedFoods),
              )
              ..orderBy([(f) => OrderingTerm.asc(f.id)]))
            .get();

    final workoutExercises = await _db.select(_db.workoutExercises).get();
    final usedExercises = {for (final e in workoutExercises) e.exerciseId};
    final exercises =
        await (_db.select(_db.exercises)
              ..where((e) => e.isCustom.equals(true) | e.id.isIn(usedExercises))
              ..orderBy([(e) => OrderingTerm.asc(e.id)]))
            .get();

    return BackupDocument(
      formatVersion: backupFormatVersion,
      appVersion: appVersion,
      exportedAt: _now(),
      tables: {
        BackupTables.appSettings: rows(await _db.select(_db.appSettings).get()),
        BackupTables.userProfile: rows(await _db.select(_db.userProfile).get()),
        BackupTables.fitnessGoals: rows(
          await _db.select(_db.fitnessGoals).get(),
        ),
        BackupTables.weightEntries: rows(
          await _db.select(_db.weightEntries).get(),
        ),
        BackupTables.nutritionTargets: rows(
          await _db.select(_db.nutritionTargets).get(),
        ),
        BackupTables.foodItems: rows(foods),
        BackupTables.foodEntries: rows(entries),
        BackupTables.exercises: rows(exercises),
        BackupTables.workoutSessions: rows(
          await _db.select(_db.workoutSessions).get(),
        ),
        BackupTables.workoutExercises: rows(workoutExercises),
        BackupTables.workoutSets: rows(await _db.select(_db.workoutSets).get()),
        BackupTables.dashboardCards: rows(
          await _db.select(_db.dashboardCards).get(),
        ),
      },
    );
  });

  /// The backup as pretty-printed JSON.
  static String encode(BackupDocument doc) =>
      const JsonEncoder.withIndent('  ').convert(doc.toJson());

  /// "fitpath-backup-2026-11-04.json"
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'fitpath-backup-${at.year}-${two(at.month)}-${two(at.day)}.json';
  }
}
