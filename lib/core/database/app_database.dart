import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../shared/models/enums.dart';
import 'daos/dashboard_dao.dart';
import 'daos/food_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/workout_dao.dart';
import 'seed/exercise_seed.dart';
import 'seed/food_seed.dart';
import 'tables/app_tables.dart';
import 'tables/food_tables.dart';
import 'tables/profile_tables.dart';
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
  ],
  daos: [ProfileDao, FoodDao, WorkoutDao, DashboardDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.seedCatalogs = true});

  /// The on-device database file. In a browser, drift runs SQLite as
  /// WebAssembly (`web/sqlite3.wasm`, `web/drift_worker.js`) and stores the
  /// database in the browser's storage.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'fitpath',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  /// Whether `onCreate` inserts the bundled food and exercise catalogs.
  /// Tests turn this off so they start from an empty catalog.
  final bool seedCatalogs;

  @override
  int get schemaVersion => 1;

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
    // onUpgrade: add steps here when schemaVersion increases.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
