import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import '../domain/workout_math.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(appDatabaseProvider).workoutDao),
);

/// The in-progress session (null when none). Survives app restarts because
/// it is read from the database.
final activeSessionProvider = StreamProvider<SessionDetail?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchActiveSession(),
);

final sessionProvider = StreamProvider.family<SessionDetail?, int>(
  (ref, id) => ref.watch(workoutRepositoryProvider).watchSession(id),
);

/// The newest completed sessions; the argument is the page size.
final recentSessionsProvider = StreamProvider.family<List<SessionDetail>, int>(
  (ref, limit) =>
      ref.watch(workoutRepositoryProvider).watchCompletedSessions(limit: limit),
);

/// Catalog exercises matching a search text and optional muscle group.
final exercisesProvider =
    StreamProvider.family<
      List<Exercise>,
      ({String query, String? muscleGroup})
    >(
      (ref, filter) => ref
          .watch(workoutRepositoryProvider)
          .watchExercises(query: filter.query, muscleGroup: filter.muscleGroup),
    );

final exerciseHistoryProvider =
    StreamProvider.family<List<ExercisePerformance>, int>(
      (ref, exerciseId) =>
          ref.watch(workoutRepositoryProvider).watchExerciseHistory(exerciseId),
    );

final completedWorkoutHistoryProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(workoutRepositoryProvider).watchCompletedSessions(),
);
