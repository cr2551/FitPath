import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/enums.dart';
import 'backup_validator.dart';

/// Replaces everything the user created with a validated backup.
///
/// Runs in ONE transaction: if any insert fails, the database is rolled back
/// to exactly what it was. Drift streams then refresh every screen.
///
/// Bundled catalog rows are kept. The bundled foods and exercises a backup
/// references are written back under their backed-up ids (overwriting a
/// bundled row with the same id), so the restored diary and sessions point
/// at the right rows.
class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  Future<void> restore(ValidBackup b) {
    final db = _db;
    return db.transaction(() async {
      // Remove user data, children before parents.
      await db.delete(db.workoutSets).go();
      await db.delete(db.workoutExercises).go();
      await db.delete(db.workoutSessions).go();
      await db.delete(db.foodEntries).go();
      await db.delete(db.recipeIngredients).go();
      await db.delete(db.recipes).go();
      await (db.delete(
        db.foodItems,
      )..where((f) => f.source.equalsValue(FoodSource.bundled).not())).go();
      await (db.delete(
        db.exercises,
      )..where((e) => e.isCustom.equals(true))).go();
      await db.delete(db.userProfile).go();
      await db.delete(db.fitnessGoals).go();
      await db.delete(db.weightEntries).go();
      await db.delete(db.nutritionTargets).go();
      await db.delete(db.dashboardCards).go();

      await db.into(db.appSettings).insertOnConflictUpdate(b.settings);
      await db.batch((batch) {
        batch
          ..insertAll(db.userProfile, b.profiles)
          ..insertAll(db.fitnessGoals, b.goals)
          ..insertAll(db.weightEntries, b.weights)
          ..insertAll(db.nutritionTargets, b.targets)
          ..insertAllOnConflictUpdate(db.foodItems, b.foods)
          ..insertAll(db.foodEntries, b.entries)
          ..insertAllOnConflictUpdate(db.exercises, b.exercises)
          ..insertAll(db.workoutSessions, b.sessions)
          ..insertAll(db.workoutExercises, b.workoutExercises)
          ..insertAll(db.workoutSets, b.sets)
          ..insertAll(db.dashboardCards, b.dashboardCards);
      });

      // A restored install has been set up already.
      await db
          .update(db.appMetadata)
          .write(const AppMetadataCompanion(onboardingCompleted: Value(true)));
    });
  }
}
