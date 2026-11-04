import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/workout_tables.dart';

part 'workout_dao.g.dart';

/// Exercise catalog and workout queries. Owned by #15 (Workout repository).
@DriftAccessor(
  tables: [Exercises, WorkoutSessions, WorkoutExercises, WorkoutSets],
)
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(super.attachedDatabase);
}
