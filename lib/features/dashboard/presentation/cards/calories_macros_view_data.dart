/// Everything the calories & macros card renders. Plain, formatted values.
class CaloriesMacrosViewData {
  const CaloriesMacrosViewData({
    required this.title,
    required this.status,
    required this.eatenKcal,
    required this.goalKcal,
    required this.eatenLabel,
    required this.segments,
    required this.macros,
    required this.unknown,
    required this.mealsLabel,
    required this.workoutsLabel,
    required this.semanticsLabel,
  });

  /// "Calorie goal: 2,100 kcal", or "Set a calorie goal".
  final String title;
  final CalorieStatus status;

  final double eatenKcal;

  /// Null when no calorie goal is in effect on the day.
  final double? goalKcal;

  /// The number in the ring, e.g. "1,640".
  final String eatenLabel;

  /// Ring segments in order: protein, carbs, fat, unknown.
  final RingKcal segments;

  /// Protein, carbs and fat, in ring order.
  final List<MacroLegendData> macros;

  /// The "Unknown" legend row; null when every calorie has a macro split.
  final UnknownLegendData? unknown;

  /// "3 meals": meals with entries on the day
  final String mealsLabel;

  /// "2 workouts this week"
  final String workoutsLabel;

  /// One sentence for screen readers.
  final String semanticsLabel;
}

/// The line under the title: an optional bold number, then text.
/// "**460** kcal remaining today", "**120** kcal over today",
/// "Log your first meal".
class CalorieStatus {
  const CalorieStatus({this.number, required this.text, this.over = false});

  final String? number;
  final String text;

  /// Shown in the warning color.
  final bool over;
}

class RingKcal {
  const RingKcal({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.unknown,
  });

  final double protein;
  final double carbs;
  final double fat;
  final double unknown;
}

enum MacroKind { protein, carbs, fat }

class MacroLegendData {
  const MacroLegendData({
    required this.kind,
    required this.label,
    required this.consumedG,
    required this.targetG,
    required this.share,
  });

  final MacroKind kind;
  final String label;
  final double consumedG;

  /// Null shows "Set target".
  final double? targetG;

  /// 0..1 share of the day's calories; null when nothing was eaten.
  final double? share;
}

class UnknownLegendData {
  const UnknownLegendData({required this.kcalLabel, required this.share});

  /// "210 kcal"
  final String kcalLabel;
  final double share;
}
