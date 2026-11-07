import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/seed/exercise_seed.dart';
import '../../../core/database/seed/food_seed.dart';
import '../../../shared/models/enums.dart';

/// Wipes everything the user created and returns the app to a fresh-install
/// state. Bundled food and exercise catalogs are kept (and re-activated);
/// custom and cached Open Food Facts foods and custom exercises are removed.
class ResetService {
  ResetService(this._db);

  final AppDatabase _db;

  Future<void> resetAll() async {
    final db = _db;
    await db.transaction(() async {
      // Children before parents (foreign keys are enforced).
      await db.delete(db.workoutSets).go();
      await db.delete(db.workoutExercises).go();
      await db.delete(db.workoutSessions).go();
      await db.delete(db.foodEntries).go();
      await db.delete(db.recipeIngredients).go();
      await db.delete(db.recipes).go();

      await (db.delete(
        db.foodItems,
      )..where((f) => f.source.equalsValue(FoodSource.bundled).not())).go();
      await db
          .update(db.foodItems)
          .write(const FoodItemsCompanion(isActive: Value(true)));
      await (db.delete(
        db.exercises,
      )..where((e) => e.isCustom.equals(true))).go();
      await db
          .update(db.exercises)
          .write(const ExercisesCompanion(deletedAt: Value(null)));

      await db.delete(db.userProfile).go();
      await db.delete(db.fitnessGoals).go();
      await db.delete(db.weightEntries).go();
      await db.delete(db.nutritionTargets).go();
      await db.delete(db.dashboardCards).go();

      // Default preferences and a cleared onboarding flag, as on first launch.
      await db.delete(db.appSettings).go();
      await db.into(db.appSettings).insert(AppSettingsCompanion.insert());
      await db.delete(db.appMetadata).go();
      await db.into(db.appMetadata).insert(AppMetadataCompanion.insert());
    });

    // Restores bundled catalogs if they were ever missing; no-op otherwise.
    if (db.seedCatalogs) {
      await seedFoods(db);
      await seedExercises(db);
    }
  }
}
