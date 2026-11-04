import '../../../shared/models/enums.dart';

/// One logged set. [weightKg] is the external load; null for bodyweight sets
/// or when the user did not enter it.
class LoggedSet {
  const LoggedSet({this.reps, this.weightKg, this.completed = true});

  final int? reps;
  final double? weightKg;
  final bool completed;
}

/// An exercise within a session, with its sets in order.
class LoggedExercise {
  const LoggedExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.isBodyweight = false,
  });

  final int exerciseId;
  final String name;
  final bool isBodyweight;
  final List<LoggedSet> sets;
}

class LoggedSession {
  const LoggedSession({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.exercises,
    this.completedAt,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final WorkoutStatus status;
  final List<LoggedExercise> exercises;

  bool get isCompleted => status == WorkoutStatus.completed;
}

class SessionSummary {
  const SessionSummary({
    required this.exerciseCount,
    required this.completedSets,
    required this.totalReps,
    required this.totalVolumeKg,
    required this.duration,
  });

  final int exerciseCount;
  final int completedSets;
  final int totalReps;

  /// Sum of load x reps over completed weighted sets. Bodyweight sets add
  /// reps but no volume.
  final double totalVolumeKg;

  /// Null while the session is not finished.
  final Duration? duration;
}

/// Best set of an exercise in one session.
class BestSet {
  const BestSet({required this.reps, this.weightKg});

  final int reps;

  /// Null for bodyweight exercises (compared by reps only).
  final double? weightKg;
}

/// How one exercise went in one completed session.
class ExercisePerformance {
  const ExercisePerformance({
    required this.sessionId,
    required this.date,
    required this.bestSet,
    required this.totalReps,
    required this.volumeKg,
  });

  final int sessionId;
  final DateTime date;
  final BestSet? bestSet;
  final int totalReps;
  final double volumeKg;
}

/// Change versus the previous completed session for the same exercise.
class PerformanceChange {
  const PerformanceChange({
    required this.bestWeightKg,
    required this.bestReps,
    required this.volumeKg,
  });

  /// Null when either session has no loaded best set.
  final double? bestWeightKg;
  final int bestReps;
  final double volumeKg;
}

/// Pure-Dart workout calculations (spec section 10). Only completed sets of
/// completed sessions count; volume is not comparable across exercise types,
/// so bodyweight exercises are compared by reps.
abstract final class WorkoutMath {
  /// load x reps, or null when it is not meaningful (bodyweight exercise,
  /// missing load or reps, or a set not completed).
  static double? setVolume(LoggedSet set, {bool isBodyweight = false}) {
    if (!set.completed || isBodyweight) return null;
    final reps = set.reps, load = set.weightKg;
    if (reps == null || load == null || reps <= 0 || load <= 0) return null;
    return reps * load;
  }

  static SessionSummary summarize(LoggedSession session) {
    var sets = 0, reps = 0;
    var volume = 0.0;
    for (final e in session.exercises) {
      for (final s in e.sets.where((s) => s.completed)) {
        sets++;
        reps += s.reps ?? 0;
        volume += setVolume(s, isBodyweight: e.isBodyweight) ?? 0;
      }
    }
    final end = session.completedAt;
    return SessionSummary(
      exerciseCount: session.exercises.length,
      completedSets: sets,
      totalReps: reps,
      totalVolumeKg: volume,
      duration: end?.difference(session.startedAt),
    );
  }

  /// Heaviest completed set, ties broken by most reps. For bodyweight
  /// exercises: the set with most reps. Null when no set qualifies.
  static BestSet? bestSet(LoggedExercise exercise) {
    BestSet? best;
    for (final s in exercise.sets) {
      final reps = s.reps;
      if (!s.completed || reps == null || reps <= 0) continue;
      final load = exercise.isBodyweight ? null : s.weightKg;
      final candidate = BestSet(reps: reps, weightKg: load);
      if (best == null || _better(candidate, best)) best = candidate;
    }
    return best;
  }

  static bool _better(BestSet a, BestSet b) {
    final wa = a.weightKg ?? 0, wb = b.weightKg ?? 0;
    if (wa != wb) return wa > wb;
    return a.reps > b.reps;
  }

  /// One entry per completed session containing [exerciseId], oldest first.
  static List<ExercisePerformance> exerciseHistory(
    int exerciseId,
    Iterable<LoggedSession> sessions,
  ) {
    final result = <ExercisePerformance>[];
    final ordered = sessions.where((s) => s.isCompleted).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (final session in ordered) {
      final matches = session.exercises.where(
        (e) => e.exerciseId == exerciseId,
      );
      if (matches.isEmpty) continue;
      var reps = 0;
      var volume = 0.0;
      BestSet? best;
      for (final e in matches) {
        for (final s in e.sets.where((s) => s.completed)) {
          reps += s.reps ?? 0;
          volume += setVolume(s, isBodyweight: e.isBodyweight) ?? 0;
        }
        final b = bestSet(e);
        if (b != null && (best == null || _better(b, best))) best = b;
      }
      result.add(
        ExercisePerformance(
          sessionId: session.id,
          date: session.startedAt,
          bestSet: best,
          totalReps: reps,
          volumeKg: volume,
        ),
      );
    }
    return result;
  }

  /// Change from [previous] to [current]; null if either has no best set.
  static PerformanceChange? compare(
    ExercisePerformance previous,
    ExercisePerformance current,
  ) {
    final a = previous.bestSet, b = current.bestSet;
    if (a == null || b == null) return null;
    return PerformanceChange(
      bestWeightKg: a.weightKg == null || b.weightKg == null
          ? null
          : b.weightKg! - a.weightKg!,
      bestReps: b.reps - a.reps,
      volumeKg: current.volumeKg - previous.volumeKg,
    );
  }

  /// Completed sessions whose start falls in `[from, to)`.
  static int completedSessionsBetween(
    Iterable<LoggedSession> sessions,
    DateTime from,
    DateTime to,
  ) => sessions
      .where(
        (s) =>
            s.isCompleted &&
            !s.startedAt.isBefore(from) &&
            s.startedAt.isBefore(to),
      )
      .length;
}
