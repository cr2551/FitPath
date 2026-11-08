import 'workout_math.dart';

/// Both 1RM estimates for one set, shown side by side and always labelled
/// as estimates.
class OneRepMax {
  const OneRepMax({required this.epleyKg, required this.brzyckiKg});

  /// `load × (1 + reps / 30)`.
  final double epleyKg;

  /// `load × 36 / (37 − reps)`.
  final double brzyckiKg;
}

/// The kinds of personal record (spec section 10, Phase 2 plan).
enum PrKind {
  /// Heaviest load lifted for at least one rep.
  heaviestLoad,

  /// Most reps at one specific load.
  repsAtLoad,

  /// Best single-set volume (load × reps).
  setVolume,

  /// Best estimated 1RM, ranked by Epley.
  oneRepMax,

  /// Most reps in one set. Bodyweight exercises only.
  mostReps,
}

/// A completed set that holds or sets a record.
class RecordSet {
  const RecordSet({
    required this.sessionId,
    required this.date,
    required this.reps,
    this.weightKg,
  });

  final int sessionId;

  /// The session's start.
  final DateTime date;
  final int reps;

  /// Null for bodyweight exercises.
  final double? weightKg;

  double? get volumeKg => weightKg == null ? null : weightKg! * reps;

  OneRepMax? get oneRepMax => StrengthStats.estimateOneRepMax(weightKg, reps);
}

/// The current records of one exercise. Loaded exercises have every record
/// except [mostReps]; bodyweight exercises only have [mostReps].
class ExerciseRecords {
  const ExerciseRecords({
    this.heaviestLoad,
    this.bestVolume,
    this.bestOneRepMax,
    this.mostReps,
    this.repsAtLoad = const {},
  });

  final RecordSet? heaviestLoad;
  final RecordSet? bestVolume;

  /// Null when no set had 1-10 reps.
  final RecordSet? bestOneRepMax;
  final RecordSet? mostReps;

  /// The best set at each load, heaviest load first.
  final Map<double, RecordSet> repsAtLoad;

  bool get isEmpty =>
      heaviestLoad == null &&
      bestVolume == null &&
      bestOneRepMax == null &&
      mostReps == null &&
      repsAtLoad.isEmpty;
}

/// A set in a session that beat the record from earlier sessions.
class NewPr {
  const NewPr({
    required this.exerciseId,
    required this.exerciseIndex,
    required this.setIndex,
    required this.kind,
    required this.set,
  });

  final int exerciseId;

  /// Position of the exercise in `LoggedSession.exercises`.
  final int exerciseIndex;

  /// Position of the set in `LoggedExercise.sets`.
  final int setIndex;
  final PrKind kind;
  final RecordSet set;
}

/// Best estimated 1RM of an exercise in one completed session.
class OneRepMaxPoint {
  const OneRepMaxPoint({
    required this.sessionId,
    required this.date,
    required this.set,
    required this.estimate,
  });

  final int sessionId;
  final DateTime date;
  final RecordSet set;
  final OneRepMax estimate;
}

/// Pure-Dart strength statistics: 1RM estimates and personal records.
///
/// - Only completed sets with reps of completed sessions count.
/// - Load-based records need a load above 0; bodyweight exercises only get
///   a reps record, because their volume is not comparable (spec section 10).
/// - A record is beaten only by a strictly better set; on a tie the earlier
///   set keeps it.
/// - The first time an exercise is done sets its records but is not a
///   "new PR": there is nothing to beat yet. The same applies to the first
///   set at a new load for [PrKind.repsAtLoad].
abstract final class StrengthStats {
  /// Above this many reps both formulas lose accuracy, so no estimate.
  static const maxRepsForOneRepMax = 10;

  /// Epley and Brzycki 1RM for [loadKg] × [reps], or null unless the set is
  /// loaded and has 1-[maxRepsForOneRepMax] reps. A single rep is the 1RM
  /// itself.
  static OneRepMax? estimateOneRepMax(double? loadKg, int? reps) {
    if (loadKg == null || reps == null) return null;
    if (loadKg <= 0 || reps < 1 || reps > maxRepsForOneRepMax) return null;
    if (reps == 1) return OneRepMax(epleyKg: loadKg, brzyckiKg: loadKg);
    return OneRepMax(
      epleyKg: loadKg * (1 + reps / 30),
      brzyckiKg: loadKg * 36 / (37 - reps),
    );
  }

  /// Current records of [exerciseId] over the completed [sessions].
  static ExerciseRecords records(
    int exerciseId,
    Iterable<LoggedSession> sessions,
  ) {
    final best = _Best();
    for (final session in _completedByDate(sessions)) {
      for (final (_, e) in _matching(session, exerciseId)) {
        for (final (_, set) in _recordSets(session, e)) {
          best.add(set, bodyweight: e.isBodyweight);
        }
      }
    }
    return best.toRecords();
  }

  /// Sets in [session] that beat the records of the completed sessions in
  /// [history] that started before it. At most one set per kind (per load
  /// for [PrKind.repsAtLoad]) and exercise: the session's best, the first on
  /// a tie. Ordered by exercise, then set.
  static List<NewPr> newPrs(
    LoggedSession session,
    Iterable<LoggedSession> history,
  ) {
    final earlier = _completedByDate(history).where(
      (s) => s.id != session.id && s.startedAt.isBefore(session.startedAt),
    );
    final result = <NewPr>[];
    for (final exerciseId in {
      for (final e in session.exercises) e.exerciseId,
    }) {
      final before = _Best();
      for (final s in earlier) {
        for (final (_, e) in _matching(s, exerciseId)) {
          for (final (_, set) in _recordSets(s, e)) {
            before.add(set, bodyweight: e.isBodyweight);
          }
        }
      }
      if (before.isEmpty) continue;

      // The session's own best per kind, remembering where each set is.
      final now = _Best();
      final where = <RecordSet, (int, int)>{};
      for (final (exerciseIndex, e) in _matching(session, exerciseId)) {
        for (final (setIndex, set) in _recordSets(session, e)) {
          where[set] = (exerciseIndex, setIndex);
          now.add(set, bodyweight: e.isBodyweight);
        }
      }

      void check(PrKind kind, RecordSet? current, RecordSet? previous) {
        if (current == null || previous == null) return;
        if (_value(kind, current) <= _value(kind, previous)) return;
        final (exerciseIndex, setIndex) = where[current]!;
        result.add(
          NewPr(
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            kind: kind,
            set: current,
          ),
        );
      }

      check(PrKind.heaviestLoad, now.heaviest, before.heaviest);
      for (final MapEntry(key: load, value: set) in now.atLoad.entries) {
        check(PrKind.repsAtLoad, set, before.atLoad[load]);
      }
      check(PrKind.setVolume, now.volume, before.volume);
      check(PrKind.oneRepMax, now.oneRepMax, before.oneRepMax);
      check(PrKind.mostReps, now.reps, before.reps);
    }
    result.sort(
      (a, b) => a.exerciseIndex != b.exerciseIndex
          ? a.exerciseIndex.compareTo(b.exerciseIndex)
          : a.setIndex.compareTo(b.setIndex),
    );
    return result;
  }

  /// The best estimated 1RM (by Epley) of [exerciseId] per completed
  /// session, oldest first. Sessions without a qualifying set are skipped.
  static List<OneRepMaxPoint> oneRepMaxHistory(
    int exerciseId,
    Iterable<LoggedSession> sessions,
  ) {
    final result = <OneRepMaxPoint>[];
    for (final session in _completedByDate(sessions)) {
      RecordSet? best;
      for (final (_, e) in _matching(session, exerciseId)) {
        if (e.isBodyweight) continue;
        for (final (_, set) in _recordSets(session, e)) {
          if (set.oneRepMax == null) continue;
          if (best == null ||
              set.oneRepMax!.epleyKg > best.oneRepMax!.epleyKg) {
            best = set;
          }
        }
      }
      if (best != null) {
        result.add(
          OneRepMaxPoint(
            sessionId: session.id,
            date: session.startedAt,
            set: best,
            estimate: best.oneRepMax!,
          ),
        );
      }
    }
    return result;
  }

  static List<LoggedSession> _completedByDate(
    Iterable<LoggedSession> sessions,
  ) =>
      sessions.where((s) => s.isCompleted).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  static Iterable<(int, LoggedExercise)> _matching(
    LoggedSession session,
    int exerciseId,
  ) sync* {
    for (var i = 0; i < session.exercises.length; i++) {
      final e = session.exercises[i];
      if (e.exerciseId == exerciseId) yield (i, e);
    }
  }

  /// Completed sets with reps, as record candidates with their index.
  static Iterable<(int, RecordSet)> _recordSets(
    LoggedSession session,
    LoggedExercise e,
  ) sync* {
    for (var i = 0; i < e.sets.length; i++) {
      final s = e.sets[i];
      final reps = s.reps;
      if (!s.completed || reps == null || reps <= 0) continue;
      final load = s.weightKg;
      yield (
        i,
        RecordSet(
          sessionId: session.id,
          date: session.startedAt,
          reps: reps,
          weightKg: e.isBodyweight || load == null || load <= 0 ? null : load,
        ),
      );
    }
  }

  static double _value(PrKind kind, RecordSet s) => switch (kind) {
    PrKind.heaviestLoad => s.weightKg!,
    PrKind.repsAtLoad || PrKind.mostReps => s.reps.toDouble(),
    PrKind.setVolume => s.volumeKg!,
    PrKind.oneRepMax => s.oneRepMax!.epleyKg,
  };
}

/// Running bests; a later set replaces a record only when strictly better.
class _Best {
  RecordSet? heaviest, volume, oneRepMax, reps;
  final atLoad = <double, RecordSet>{};

  bool get isEmpty =>
      heaviest == null && reps == null && volume == null && atLoad.isEmpty;

  void add(RecordSet s, {required bool bodyweight}) {
    if (bodyweight) {
      if (reps == null || s.reps > reps!.reps) reps = s;
      return;
    }
    final load = s.weightKg;
    if (load == null) return;
    if (heaviest == null || load > heaviest!.weightKg!) heaviest = s;
    final atThisLoad = atLoad[load];
    if (atThisLoad == null || s.reps > atThisLoad.reps) atLoad[load] = s;
    if (volume == null || s.volumeKg! > volume!.volumeKg!) volume = s;
    final orm = s.oneRepMax;
    if (orm != null &&
        (oneRepMax == null || orm.epleyKg > oneRepMax!.oneRepMax!.epleyKg)) {
      oneRepMax = s;
    }
  }

  ExerciseRecords toRecords() => ExerciseRecords(
    heaviestLoad: heaviest,
    bestVolume: volume,
    bestOneRepMax: oneRepMax,
    mostReps: reps,
    repsAtLoad: Map.fromEntries(
      atLoad.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    ),
  );
}
