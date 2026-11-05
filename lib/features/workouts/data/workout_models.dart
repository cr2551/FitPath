import '../../../core/database/app_database.dart';
import '../domain/workout_math.dart';

/// A session with its exercises and sets, in order.
class SessionDetail {
  const SessionDetail({required this.session, required this.exercises});

  final WorkoutSession session;
  final List<SessionExercise> exercises;

  int get id => session.id;

  /// The shape the workout math works on.
  LoggedSession toLogged() => LoggedSession(
    id: session.id,
    startedAt: session.startedAt,
    completedAt: session.completedAt,
    status: session.status,
    exercises: [for (final e in exercises) e.toLogged()],
  );

  SessionSummary get summary => WorkoutMath.summarize(toLogged());
}

/// One exercise in a session. [exercise] is the catalog row (possibly soft
/// deleted); the name shown in history is [entry]'s snapshot.
class SessionExercise {
  const SessionExercise({
    required this.entry,
    required this.exercise,
    required this.sets,
  });

  final WorkoutExercise entry;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  int get id => entry.id;
  String get name => entry.exerciseNameSnapshot;
  bool get isBodyweight => exercise.isBodyweight;

  LoggedExercise toLogged() => LoggedExercise(
    exerciseId: entry.exerciseId,
    name: entry.exerciseNameSnapshot,
    isBodyweight: exercise.isBodyweight,
    sets: [
      for (final s in sets)
        LoggedSet(
          reps: s.repetitions,
          weightKg: s.weightKg,
          completed: s.completed,
        ),
    ],
  );
}

/// Fields for creating or editing a custom exercise.
class ExerciseDetails {
  const ExerciseDetails({
    required this.name,
    required this.muscleGroup,
    this.equipment,
    this.description,
    this.isBodyweight = false,
  });

  final String name;
  final String muscleGroup;
  final String? equipment;
  final String? description;
  final bool isBodyweight;
}

class InvalidExercise implements Exception {
  const InvalidExercise(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Only custom exercises can be edited or deleted.
class NotACustomExercise implements Exception {
  const NotACustomExercise(this.id);

  final int id;

  @override
  String toString() => 'Exercise $id is part of the built-in catalog.';
}

/// The operation needs an in-progress session.
class SessionNotInProgress implements Exception {
  const SessionNotInProgress(this.id);

  final int id;

  @override
  String toString() => 'Session $id is not in progress.';
}
