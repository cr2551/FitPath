import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_tables.dart';
import '../tables/profile_tables.dart';

part 'profile_dao.g.dart';

/// Profile, goals, weight, targets, settings and metadata queries.
/// Owned by #10 (Profile repository).
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
}
