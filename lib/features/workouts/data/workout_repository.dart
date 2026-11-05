import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/workout_dao.dart';
import '../../../shared/models/enums.dart';
import '../domain/workout_math.dart';
import 'workout_models.dart';

/// Exercise catalog, workout sessions and history (FR-09, FR-10).
///
/// * Only one session is in progress at a time; starting again resumes it.
/// * Exercise names are snapshotted into the session, so renaming or
///   deleting a catalog exercise never changes history.
/// * Exercises and sets can only change while their session is in progress.
/// * Only completed sessions count toward history and summaries.
class WorkoutRepository {
  WorkoutRepository(this._dao, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final WorkoutDao _dao;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- catalog

  Stream<List<Exercise>> watchExercises({
    String query = '',
    String? muscleGroup,
  }) => _dao.watchExercises(query: query, muscleGroup: muscleGroup);

  Future<Exercise?> exerciseById(int id) => _dao.exerciseById(id);

  Future<int> createCustomExercise(ExerciseDetails details) {
    _validate(details);
    return _dao.insertExercise(
      ExercisesCompanion.insert(
        name: details.name.trim(),
        muscleGroup: details.muscleGroup,
        equipment: Value(_blankToNull(details.equipment)),
        description: Value(_blankToNull(details.description)),
        isBodyweight: Value(details.isBodyweight),
        isCustom: const Value(true),
      ),
    );
  }

  /// Edits a custom exercise. Past sessions keep their name snapshot.
  Future<void> updateCustomExercise(int id, ExerciseDetails details) async {
    _validate(details);
    await _requireCustom(id);
    await _dao.updateExercise(
      id,
      ExercisesCompanion(
        name: Value(details.name.trim()),
        muscleGroup: Value(details.muscleGroup),
        equipment: Value(_blankToNull(details.equipment)),
        description: Value(_blankToNull(details.description)),
        isBodyweight: Value(details.isBodyweight),
      ),
    );
  }

  /// Soft delete: hidden from the catalog, kept for history.
  Future<void> deleteCustomExercise(int id) async {
    await _requireCustom(id);
    await _dao.updateExercise(id, ExercisesCompanion(deletedAt: Value(_now())));
  }

  // --------------------------------------------------------------- sessions

  /// The in-progress session, which survives app restarts.
  Stream<SessionDetail?> watchActiveSession() =>
      _watchDetails((s) => s.status.equalsValue(WorkoutStatus.inProgress))
          .map((list) => list.firstOrNull);

  Stream<SessionDetail?> watchSession(int id) =>
      _watchDetails((s) => s.id.equals(id)).map((list) => list.firstOrNull);

  /// Starts a session, or returns the one already in progress.
  Future<int> startSession({String? name}) => _dao.transaction(() async {
    final active = await _dao.activeSession();
    if (active != null) return active.id;
    return _dao.insertSession(
      WorkoutSessionsCompanion.insert(
        startedAt: _now(),
        status: WorkoutStatus.inProgress,
        name: Value(_blankToNull(name)),
      ),
    );
  });

  Future<void> renameSession(int id, String? name) => _dao.updateSession(
    id,
    WorkoutSessionsCompanion(name: Value(_blankToNull(name))),
  );

  Future<void> setSessionNotes(int id, String? notes) => _dao.updateSession(
    id,
    WorkoutSessionsCompanion(notes: Value(_blankToNull(notes))),
  );

  /// Adds [exerciseId] at the end of the session. Returns the new
  /// workout-exercise id.
  Future<int> addExercise(int sessionId, int exerciseId) =>
      _dao.transaction(() async {
        await _requireInProgress(sessionId);
        final exercise = await _dao.exerciseById(exerciseId);
        if (exercise == null) throw StateError('No exercise $exerciseId');
        final existing = await _dao.exercisesOfSession(sessionId);
        return _dao.insertWorkoutExercise(
          WorkoutExercisesCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            exerciseNameSnapshot: exercise.name,
            orderIndex: existing.isEmpty ? 0 : existing.last.orderIndex + 1,
          ),
        );
      });

  /// Removes an exercise and its sets from an in-progress session.
  Future<void> removeExercise(int workoutExerciseId) =>
      _dao.transaction(() async {
        final entry = await _requireEntry(workoutExerciseId);
        await _requireInProgress(entry.sessionId);
        await _dao.deleteWorkoutExercise(workoutExerciseId);
      });

  /// Rewrites the order so [workoutExerciseIds] come in that order.
  Future<void> reorderExercises(int sessionId, List<int> workoutExerciseIds) =>
      _dao.transaction(() async {
        await _requireInProgress(sessionId);
        for (var i = 0; i < workoutExerciseIds.length; i++) {
          await _dao.setExerciseOrder(workoutExerciseIds[i], i);
        }
      });

  /// Appends a set. Returns the new set id.
  Future<int> addSet(int workoutExerciseId, {int? reps, double? weightKg}) =>
      _dao.transaction(() async {
        final entry = await _requireEntry(workoutExerciseId);
        await _requireInProgress(entry.sessionId);
        _validateSet(reps, weightKg);
        final sets = await _dao.setsOf(workoutExerciseId);
        return _dao.insertSet(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: workoutExerciseId,
            setNumber: sets.isEmpty ? 1 : sets.last.setNumber + 1,
            repetitions: Value(reps),
            weightKg: Value(weightKg),
          ),
        );
      });

  /// Changes the given fields of a set; absent values stay as they are.
  Future<void> updateSet(
    int setId, {
    Value<int?> reps = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<bool> completed = const Value.absent(),
  }) => _dao.transaction(() async {
    final set = await _dao.setById(setId);
    if (set == null) throw StateError('No set $setId');
    final entry = await _requireEntry(set.workoutExerciseId);
    await _requireInProgress(entry.sessionId);
    _validateSet(
      reps.present ? reps.value : null,
      weightKg.present ? weightKg.value : null,
    );
    await _dao.updateSet(
      setId,
      WorkoutSetsCompanion(
        repetitions: reps,
        weightKg: weightKg,
        completed: completed,
      ),
    );
  });

  /// Removes a set and renumbers the rest from 1.
  Future<void> removeSet(int setId) => _dao.transaction(() async {
    final set = await _dao.setById(setId);
    if (set == null) return;
    final entry = await _requireEntry(set.workoutExerciseId);
    await _requireInProgress(entry.sessionId);
    await _dao.deleteSet(setId);
    final rest = await _dao.setsOf(set.workoutExerciseId);
    for (var i = 0; i < rest.length; i++) {
      if (rest[i].setNumber != i + 1) {
        await _dao.updateSet(
          rest[i].id,
          WorkoutSetsCompanion(setNumber: Value(i + 1)),
        );
      }
    }
  });

  /// Finishes the session: it moves to history.
  Future<void> completeSession(int id) => _dao.transaction(() async {
    await _requireInProgress(id);
    await _dao.updateSession(
      id,
      WorkoutSessionsCompanion(
        status: const Value(WorkoutStatus.completed),
        completedAt: Value(_now()),
      ),
    );
  });

  /// Abandons the session. It never counts toward history.
  Future<void> discardSession(int id) => _dao.transaction(() async {
    await _requireInProgress(id);
    await _dao.updateSession(
      id,
      const WorkoutSessionsCompanion(status: Value(WorkoutStatus.discarded)),
    );
  });

  /// Deletes a session with its exercises and sets.
  Future<void> deleteSession(int id) => _dao.deleteSession(id);

  // ---------------------------------------------------------------- history

  /// Completed sessions, newest first. [limit] pages the list; [from] and
  /// [to] bound the start time (`[from, to)`).
  Stream<List<SessionDetail>> watchCompletedSessions({
    int? limit,
    DateTime? from,
    DateTime? to,
  }) => _watchDetails(
    (s) => s.id.isInQuery(
      _dao.completedSessionIds(from: from, to: to, limit: limit),
    ),
  );

  /// Number of completed sessions started in `[from, to)`, e.g. a week.
  Stream<int> watchCompletedCount(DateTime from, DateTime to) =>
      _dao.watchCompletedCount(from, to);

  /// How [exerciseId] went in every completed session, oldest first.
  Stream<List<ExercisePerformance>> watchExerciseHistory(int exerciseId) =>
      _watchDetails(
        (s) =>
            s.status.equalsValue(WorkoutStatus.completed) &
            s.id.isInQuery(
              _dao.selectOnly(_dao.workoutExercises)
                ..addColumns([_dao.workoutExercises.sessionId])
                ..where(_dao.workoutExercises.exerciseId.equals(exerciseId)),
            ),
      ).map(
        (sessions) => WorkoutMath.exerciseHistory(exerciseId, [
          for (final s in sessions) s.toLogged(),
        ]),
      );

  // ---------------------------------------------------------------- helpers

  Stream<List<SessionDetail>> _watchDetails(
    Expression<bool> Function($WorkoutSessionsTable s) filter,
  ) => _dao.watchSessionRows(filter).map(_group);

  List<SessionDetail> _group(List<TypedResult> rows) {
    final sessions = <int, WorkoutSession>{};
    final exercises = <int, List<SessionExercise>>{};
    final byEntry = <int, SessionExercise>{};
    for (final row in rows) {
      final session = row.readTable(_dao.workoutSessions);
      sessions.putIfAbsent(session.id, () => session);
      final list = exercises.putIfAbsent(session.id, () => []);
      final entry = row.readTableOrNull(_dao.workoutExercises);
      if (entry == null) continue;
      final exercise = byEntry.putIfAbsent(entry.id, () {
        final e = SessionExercise(
          entry: entry,
          exercise: row.readTable(_dao.exercises),
          sets: [],
        );
        list.add(e);
        return e;
      });
      final set = row.readTableOrNull(_dao.workoutSets);
      if (set != null) exercise.sets.add(set);
    }
    return [
      for (final s in sessions.values)
        SessionDetail(session: s, exercises: exercises[s.id]!),
    ];
  }

  Future<void> _requireInProgress(int sessionId) async {
    final s = await _dao.sessionById(sessionId);
    if (s == null || s.status != WorkoutStatus.inProgress) {
      throw SessionNotInProgress(sessionId);
    }
  }

  Future<WorkoutExercise> _requireEntry(int id) async {
    final entry = await _dao.workoutExerciseById(id);
    if (entry == null) throw StateError('No workout exercise $id');
    return entry;
  }

  Future<void> _requireCustom(int id) async {
    final e = await _dao.exerciseById(id);
    if (e == null || !e.isCustom) throw NotACustomExercise(id);
  }

  static void _validate(ExerciseDetails d) {
    final name = d.name.trim();
    if (name.isEmpty) throw const InvalidExercise('Enter a name.');
    if (name.length > 120) {
      throw const InvalidExercise('Use at most 120 characters.');
    }
    if (d.muscleGroup.trim().isEmpty) {
      throw const InvalidExercise('Choose a muscle group.');
    }
  }

  static void _validateSet(int? reps, double? weightKg) {
    if (reps != null && (reps < 0 || reps > 1000)) {
      throw ArgumentError.value(reps, 'reps', 'must be 0-1000');
    }
    if (weightKg != null && (weightKg < 0 || weightKg > 1000)) {
      throw ArgumentError.value(weightKg, 'weightKg', 'must be 0-1000 kg');
    }
  }

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();
}
