import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../shared/models/enums.dart';
import 'app_database.steps.dart';
import 'daos/dashboard_dao.dart';
import 'daos/food_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/recipe_dao.dart';
import 'daos/workout_dao.dart';
import 'seed/exercise_seed.dart';
import 'seed/food_seed.dart';
import 'tables/app_tables.dart';
import 'tables/food_tables.dart';
import 'tables/profile_tables.dart';
import 'tables/recipe_tables.dart';
import 'tables/workout_tables.dart';

part 'app_database.g.dart';

/// The local SQLite database (spec section 8).
///
/// FROZEN after #4: features add queries in their own DAO
/// (`daos/*_dao.dart`) and never edit this file. Schema changes need a new
/// [schemaVersion], a migration step and a migration test (NFR-04).
@DriftDatabase(
  tables: [
    UserProfile,
    FitnessGoals,
    WeightEntries,
    NutritionTargets,
    FoodItems,
    FoodEntries,
    Exercises,
    WorkoutSessions,
    WorkoutExercises,
    WorkoutSets,
    DashboardCards,
    AppSettings,
    AppMetadata,
    Recipes,
    RecipeIngredients,
  ],
  daos: [ProfileDao, FoodDao, WorkoutDao, DashboardDao, RecipeDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.seedCatalogs = true});

  /// The on-device database file.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'fitpath'));

  /// Whether `onCreate` inserts the bundled food and exercise catalogs.
  /// Tests turn this off so they start from an empty catalog.
  final bool seedCatalogs;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettings).insert(
        AppSettingsCompanion.insert(unitSystem: const Value(UnitSystem.metric)),
      );
      await into(appMetadata).insert(AppMetadataCompanion.insert());
      if (seedCatalogs) {
        await seedFoods(this);
        await seedExercises(this);
      }
    },
    // Steps between committed schemas (`drift_schemas/`); regenerate
    // `app_database.steps.dart` with `dart run drift_dev make-migrations`.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // Phase 2: recipes.
        await m.createTable(schema.recipes);
        await m.createTable(schema.recipeIngredients);
        await m.createIndex(schema.recipeIngredientsRecipe);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
