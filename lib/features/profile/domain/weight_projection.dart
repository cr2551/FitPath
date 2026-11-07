import '../../../core/utils/dates.dart';
import 'metabolic_calculator.dart';
import 'metabolic_profile.dart';

/// Projected weight at the end of one day.
class ProjectedDay {
  const ProjectedDay(this.date, this.weightKg);

  final DateTime date;
  final double weightKg;
}

/// The result of a what-if projection. Always an estimate, never a promise.
class WeightProjection {
  const WeightProjection({
    required this.days,
    required this.targetReachedOn,
    required this.weeklyPaceKg,
    required this.fastPace,
    required this.belowCalorieFloor,
    required this.startTdeeKcal,
  });

  /// Day 0 is the start date at the current weight; one entry per day after
  /// it, until the target is reached or the horizon ends.
  final List<ProjectedDay> days;

  /// Null when the target is not reached within the horizon, or no target
  /// was given.
  final DateTime? targetReachedOn;

  /// Change over the first week (negative = loss). The pace slows later,
  /// because energy needs fall with the projected weight.
  final double weeklyPaceKg;

  /// The first week's pace is over [WeightProjectionCalculator.maxSafeWeeklyShare]
  /// of body weight.
  final bool fastPace;

  /// The intake is below the CALC-1 calorie floor for the user's sex.
  final bool belowCalorieFloor;

  /// Estimated energy needs on day 0.
  final double startTdeeKcal;

  double get finalWeightKg => days.last.weightKg;
}

/// Pure-Dart what-if projection (Phase 2 plan, decision of 7 Nov).
///
/// Day by day, BMR and TDEE are recalculated from that day's projected
/// weight with [MetabolicCalculator] (Mifflin-St Jeor), and the day's
/// balance `intake − TDEE` changes weight at [kcalPerKg]. So the projection
/// slows as weight approaches the level where TDEE equals the intake,
/// instead of following a straight line.
abstract final class WeightProjectionCalculator {
  /// Approximate energy in one kg of body weight change.
  static const double kcalPerKg = 7700;

  /// The projection never runs longer than this.
  static const int horizonDays = 365;

  /// A weekly change above this share of body weight is flagged.
  static const double maxSafeWeeklyShare = 0.01;

  static const String estimateNote =
      'This projection is an estimate. Real weight changes vary with water, '
      'muscle, and how closely you follow the plan.';
  static const String fastPaceNote =
      'This pace is faster than 1% of your body weight a week, which is '
      'hard to sustain.';
  static const String belowFloorNote =
      'This intake is below the minimum the app suggests. Talk to a health '
      'professional before eating this little.';
  static const String notReachedNote =
      'At this intake the target is not reached within a year.';

  /// Projects weight from [start] eating [intakeKcal] a day at the profile's
  /// activity level. [profile] needs age, height, current weight and
  /// activity level; otherwise the result is unavailable with the missing
  /// inputs. Without [targetWeightKg] the projection runs to the horizon.
  static Estimate<WeightProjection> project({
    required MetabolicProfile profile,
    required int intakeKcal,
    required DateTime start,
    double? targetWeightKg,
  }) {
    final startTdee = MetabolicCalculator.tdee(profile);
    if (!startTdee.isAvailable) {
      return Estimate.unavailable(startTdee.missing, notes: startTdee.notes);
    }

    final first = Dates.startOfDay(start);
    final startWeight = profile.weightKg!;
    final losing = targetWeightKg != null && targetWeightKg < startWeight;
    bool reached(double w) =>
        targetWeightKg != null &&
        (losing ? w <= targetWeightKg : w >= targetWeightKg);

    final days = [ProjectedDay(first, startWeight)];
    DateTime? reachedOn = reached(startWeight) ? first : null;
    var weight = startWeight;
    for (var i = 1; i <= horizonDays && reachedOn == null; i++) {
      final tdee = MetabolicCalculator.tdee(_withWeight(profile, weight));
      weight += (intakeKcal - tdee.value!) / kcalPerKg;
      final date = Dates.addDays(first, i);
      days.add(ProjectedDay(date, weight));
      if (reached(weight)) reachedOn = date;
    }

    // The first week, scaled when the target is reached sooner.
    final weekEnd = days.length > 7 ? 7 : days.length - 1;
    final pace = weekEnd == 0
        ? 0.0
        : (days[weekEnd].weightKg - startWeight) / weekEnd * 7;
    final fast = pace.abs() > startWeight * maxSafeWeeklyShare;
    final belowFloor =
        intakeKcal < MetabolicCalculator.minimumKcal(profile.sex);

    return Estimate.available(
      WeightProjection(
        days: days,
        targetReachedOn: reachedOn,
        weeklyPaceKg: pace,
        fastPace: fast,
        belowCalorieFloor: belowFloor,
        startTdeeKcal: startTdee.value!,
      ),
      notes: [
        estimateNote,
        ...startTdee.notes,
        if (fast) fastPaceNote,
        if (belowFloor) belowFloorNote,
        if (targetWeightKg != null && reachedOn == null) notReachedNote,
      ],
    );
  }

  static MetabolicProfile _withWeight(MetabolicProfile p, double weightKg) =>
      MetabolicProfile(
        ageYears: p.ageYears,
        heightCm: p.heightCm,
        weightKg: weightKg,
        sex: p.sex,
        activityLevel: p.activityLevel,
        goal: p.goal,
      );
}
