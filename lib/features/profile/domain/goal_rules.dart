import '../../../shared/models/enums.dart';

/// Which goals can be combined.
abstract final class GoalRules {
  /// Goals that pull the other way from [goal]: losing weight and keeping
  /// it steady cannot both be pursued.
  static Set<GoalType> conflictsWith(GoalType? goal) => switch (goal) {
    GoalType.loseWeight => const {GoalType.maintainWeight},
    GoalType.maintainWeight => const {GoalType.loseWeight},
    _ => const {},
  };

  /// Goals that can be added next to the main goal [primary].
  static List<GoalType> secondaryOptions(GoalType? primary) => [
    for (final g in GoalType.values)
      if (g != primary && !conflictsWith(primary).contains(g)) g,
  ];
}
