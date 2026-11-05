import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';
import '../app_database.dart';
import '../tables/workout_tables.dart';

part 'workout_dao.g.dart';

/// Exercise catalog and workout queries. Owned by #15 (Workout repository).
@DriftAccessor(
  tables: [Exercises, WorkoutSessions, WorkoutExercises, WorkoutSets],
)
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(super.attachedDatabase);

  // ---------------------------------------------------------------- catalog

  /// Exercises not soft-deleted, by name. [query] matches the name
  /// (case-insensitive); [muscleGroup] filters exactly.
  Stream<List<Exercise>> watchExercises({
    String query = '',
    String? muscleGroup,
  }) {
    final pattern = '%${_escapeLike(query.trim().toLowerCase())}%';
    return (select(exercises)
          ..where((e) {
            var where =
                e.deletedAt.isNull() &
                e.name.lower().like(pattern, escapeChar: r'\');
            if (muscleGroup != null) {
              where = where & e.muscleGroup.equals(muscleGroup);
            }
            return where;
          })
          ..orderBy([(e) => OrderingTerm.asc(e.name.lower())]))
        .watch();
  }

  Future<Exercise?> exerciseById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertExercise(ExercisesCompanion e) => into(exercises).insert(e);

  Future<void> updateExercise(int id, ExercisesCompanion e) =>
      (update(exercises)..where((x) => x.id.equals(id))).write(e);

  // --------------------------------------------------------------- sessions

  Future<WorkoutSession?> sessionById(int id) => (select(
    workoutSessions,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  /// The most recently started in-progress session, if any.
  Future<WorkoutSession?> activeSession() =>
      (select(workoutSessions)
            ..where((s) => s.status.equalsValue(WorkoutStatus.inProgress))
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertSession(WorkoutSessionsCompanion s) =>
      into(workoutSessions).insert(s);

  Future<void> updateSession(int id, WorkoutSessionsCompanion s) =>
      (update(workoutSessions)..where((x) => x.id.equals(id))).write(s);

  /// Deletes the session; its exercises and sets cascade.
  Future<void> deleteSession(int id) =>
      (delete(workoutSessions)..where((s) => s.id.equals(id))).go();

  /// Sessions with their exercises (and catalog rows) and sets, newest
  /// first, exercises and sets in order. One row per set (or per exercise
  /// without sets, or per empty session).
  Stream<List<TypedResult>> watchSessionRows(
    Expression<bool> Function($WorkoutSessionsTable s) filter,
  ) {
    final query =
        select(workoutSessions).join([
            leftOuterJoin(
              workoutExercises,
              workoutExercises.sessionId.equalsExp(workoutSessions.id),
            ),
            leftOuterJoin(
              exercises,
              exercises.id.equalsExp(workoutExercises.exerciseId),
            ),
            leftOuterJoin(
              workoutSets,
              workoutSets.workoutExerciseId.equalsExp(workoutExercises.id),
            ),
          ])
          ..where(filter(workoutSessions))
          ..orderBy([
            OrderingTerm.desc(workoutSessions.startedAt),
            OrderingTerm.desc(workoutSessions.id),
            OrderingTerm.asc(workoutExercises.orderIndex),
            OrderingTerm.asc(workoutSets.setNumber),
          ]);
    return query.watch();
  }

  /// A one-column query of the newest [limit] completed session ids started
  /// in `[from, to)`, for `isInQuery`.
  JoinedSelectStatement<WorkoutSessions, WorkoutSession> completedSessionIds({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final s = workoutSessions;
    var where = s.status.equalsValue(WorkoutStatus.completed);
    if (from != null) where = where & s.startedAt.isBiggerOrEqualValue(from);
    if (to != null) where = where & s.startedAt.isSmallerThanValue(to);
    final query = selectOnly(s)
      ..addColumns([s.id])
      ..where(where)
      ..orderBy([OrderingTerm.desc(s.startedAt), OrderingTerm.desc(s.id)]);
    if (limit != null) query.limit(limit);
    return query;
  }

  /// Number of completed sessions started in `[from, to)`.
  Stream<int> watchCompletedCount(DateTime from, DateTime to) {
    final s = workoutSessions;
    final count = s.id.count();
    final query = selectOnly(s)
      ..addColumns([count])
      ..where(
        s.status.equalsValue(WorkoutStatus.completed) &
            s.startedAt.isBiggerOrEqualValue(from) &
            s.startedAt.isSmallerThanValue(to),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  // -------------------------------------------------------------- exercises

  Future<WorkoutExercise?> workoutExerciseById(int id) => (select(
    workoutExercises,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<List<WorkoutExercise>> exercisesOfSession(int sessionId) =>
      (select(workoutExercises)
            ..where((e) => e.sessionId.equals(sessionId))
            ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
          .get();

  Future<int> insertWorkoutExercise(WorkoutExercisesCompanion e) =>
      into(workoutExercises).insert(e);

  Future<void> setExerciseOrder(int id, int orderIndex) =>
      (update(workoutExercises)..where((e) => e.id.equals(id))).write(
        WorkoutExercisesCompanion(orderIndex: Value(orderIndex)),
      );

  Future<void> deleteWorkoutExercise(int id) =>
      (delete(workoutExercises)..where((e) => e.id.equals(id))).go();

  // ------------------------------------------------------------------- sets

  Future<WorkoutSet?> setById(int id) =>
      (select(workoutSets)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<WorkoutSet>> setsOf(int workoutExerciseId) =>
      (select(workoutSets)
            ..where((s) => s.workoutExerciseId.equals(workoutExerciseId))
            ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
          .get();

  Future<int> insertSet(WorkoutSetsCompanion s) => into(workoutSets).insert(s);

  Future<void> updateSet(int id, WorkoutSetsCompanion s) =>
      (update(workoutSets)..where((x) => x.id.equals(id))).write(s);

  Future<void> deleteSet(int id) =>
      (delete(workoutSets)..where((s) => s.id.equals(id))).go();

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
