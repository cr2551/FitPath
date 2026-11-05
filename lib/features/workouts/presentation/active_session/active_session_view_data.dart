/// Everything the active session screen renders. Loads are in the user's
/// display unit.
class ActiveSessionViewData {
  const ActiveSessionViewData({
    required this.sessionId,
    required this.name,
    required this.notes,
    required this.elapsed,
    required this.loadUnit,
    required this.maxLoad,
    required this.exercises,
    required this.completedSets,
    required this.totalSets,
  });

  final int sessionId;
  final String name;
  final String notes;

  /// "42:10" or "1:05:30"
  final String elapsed;

  /// "kg" or "lb"
  final String loadUnit;

  /// 1000 kg in the display unit.
  final double maxLoad;
  final List<ExerciseBlockData> exercises;
  final int completedSets;
  final int totalSets;
}

class ExerciseBlockData {
  const ExerciseBlockData({
    required this.id,
    required this.name,
    required this.isBodyweight,
    required this.sets,
  });

  /// The workout-exercise id.
  final int id;
  final String name;

  /// Load is optional ("+kg" for added weight) for bodyweight exercises.
  final bool isBodyweight;
  final List<SetRowData> sets;
}

class SetRowData {
  const SetRowData({
    required this.id,
    required this.number,
    required this.reps,
    required this.load,
    required this.completed,
  });

  final int id;
  final int number;
  final int? reps;

  /// In the display unit.
  final double? load;
  final bool completed;
}
