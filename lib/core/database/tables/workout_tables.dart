import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';

/// Exercise catalog. Custom exercises are soft-deleted via [deletedAt].
@DataClassName('Exercise')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get muscleGroup => text()();
  TextColumn get equipment => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isBodyweight => boolean().withDefault(const Constant(false))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Only `completed` sessions count toward summaries and history.
@DataClassName('WorkoutSession')
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => textEnum<WorkoutStatus>()();
}

/// An exercise within a session. The name is snapshotted so renaming or
/// deleting the catalog exercise never changes history.
@DataClassName('WorkoutExercise')
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  TextColumn get exerciseNameSnapshot => text()();
  IntColumn get orderIndex => integer()();
}

@DataClassName('WorkoutSet')
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get setNumber => integer()();
  IntColumn get repetitions => integer().nullable()();

  /// External load in kg; null for bodyweight sets.
  RealColumn get weightKg => real().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}
