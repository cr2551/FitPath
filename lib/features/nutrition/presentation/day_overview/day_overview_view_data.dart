import '../../../../shared/models/enums.dart';

/// Everything the Nutrition day overview renders. Plain values only.
class DayOverviewViewData {
  const DayOverviewViewData({
    required this.week,
    required this.selected,
    required this.today,
    required this.weekLabel,
    required this.canGoToNextWeek,
    required this.daysWithEntries,
    required this.body,
  });

  final List<DateTime> week;
  final DateTime selected;
  final DateTime today;

  /// E.g. "1 – 7 Nov".
  final String weekLabel;
  final bool canGoToNextWeek;

  /// Local date keys (yyyy-MM-dd) of days in [week] with entries.
  final Set<String> daysWithEntries;
  final DayBody body;
}

/// The part below the date strip, which depends on the selected day's data.
sealed class DayBody {
  const DayBody();
}

class DayLoading extends DayBody {
  const DayLoading();
}

class DayError extends DayBody {
  const DayError(this.message);

  final String message;
}

class DayLoaded extends DayBody {
  const DayLoaded({required this.summary, required this.meals});

  final DaySummaryViewData summary;
  final List<MealGroupViewData> meals;
}

enum MacroKind { protein, carbs, fat }

class MacroBarData {
  const MacroBarData({
    required this.kind,
    required this.label,
    required this.consumedG,
    required this.targetG,
  });

  final MacroKind kind;
  final String label;
  final double consumedG;

  /// Null when the user has not set this macro target.
  final double? targetG;
}

class DaySummaryViewData {
  const DaySummaryViewData({
    required this.eatenKcal,
    required this.goalKcal,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
    required this.unknownKcal,
    required this.macros,
    this.note,
  });

  final double eatenKcal;

  /// Null when no calorie target is in effect on the day.
  final double? goalKcal;

  /// Where the eaten calories came from (ring segments).
  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;
  final double unknownKcal;

  final List<MacroBarData> macros;

  /// E.g. "2 entries have incomplete macro data".
  final String? note;

  bool get hasGoal => goalKcal != null && goalKcal! > 0;
}

class MealGroupViewData {
  const MealGroupViewData({
    required this.meal,
    required this.title,
    required this.totalLabel,
    required this.entries,
  });

  final MealType meal;
  final String title;

  /// E.g. "441 kcal"; empty when nothing is logged.
  final String totalLabel;
  final List<EntryRowData> entries;
}

class EntryRowData {
  const EntryRowData({
    required this.id,
    required this.name,
    required this.detail,
    required this.kcal,
  });

  final int id;
  final String name;

  /// Quantity and brand, e.g. "200 g · Fage".
  final String detail;

  /// Formatted kcal number, "—" when unknown.
  final String kcal;
}
