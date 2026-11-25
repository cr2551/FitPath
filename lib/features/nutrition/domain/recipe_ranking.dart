import '../../../shared/models/enums.dart';
import 'nutrients.dart';

/// One serving of a recipe that can be suggested.
class RecipeCandidate {
  const RecipeCandidate({
    required this.foodId,
    required this.name,
    required this.perServing,
  });

  final int foodId;
  final String name;
  final Nutrients perServing;
}

/// The day's targets and what has been eaten so far. A null macro target is
/// not considered.
class DayBudget {
  const DayBudget({
    required this.targetKcal,
    required this.eatenKcal,
    this.targetProteinG,
    this.targetCarbsG,
    this.targetFatG,
    this.eatenProteinG = 0,
    this.eatenCarbsG = 0,
    this.eatenFatG = 0,
  });

  final double targetKcal;
  final double eatenKcal;
  final double? targetProteinG;
  final double? targetCarbsG;
  final double? targetFatG;
  final double eatenProteinG;
  final double eatenCarbsG;
  final double eatenFatG;

  double get remainingKcal => targetKcal - eatenKcal;
  bool get isOver => remainingKcal <= 0;

  /// Null when there is no protein target; never below zero.
  double? get remainingProteinG => targetProteinG == null
      ? null
      : (targetProteinG! - eatenProteinG).clamp(0, double.infinity);
}

class RankedRecipe {
  const RankedRecipe({
    required this.candidate,
    required this.score,
    this.kcalShareOfRemaining,
    this.proteinShareOfRemaining,
    this.highProtein = false,
  });

  final RecipeCandidate candidate;

  /// Lower fits better. Null when the recipe's calories are unknown.
  final double? score;

  /// Serving kcal / remaining kcal; null when over target or unknown.
  final double? kcalShareOfRemaining;

  /// Serving protein / remaining protein; null without a protein target,
  /// with no protein left, or when unknown.
  final double? proteinShareOfRemaining;

  /// At least [RecipeRanking.highProteinShare] of the calories from protein.
  final bool highProtein;
}

/// Rule-based recipe suggestions for what is left of the day.
///
/// Each nutrient's miss is measured against its daily target, so a gram of
/// protein and a calorie weigh the same whatever the size of the target.
/// Going over what is left costs twice as much as falling short. Calories
/// count fully, each macro with a target counts half. The goal then breaks
/// near-ties: more protein for muscle and strength goals, fewer calories
/// for weight loss.
///
/// When the day is already over its calories, recipes are ordered lightest
/// first. Recipes with unknown calories always come last, by name.
abstract final class RecipeRanking {
  static const overshootWeight = 2.0;
  static const macroWeight = 0.5;
  static const goalWeight = 0.05;
  static const highProteinShare = 0.3;

  static List<RankedRecipe> rank(
    Iterable<RecipeCandidate> candidates, {
    required DayBudget budget,
    GoalType? goal,
  }) {
    final known = <RankedRecipe>[];
    final unknown = <RankedRecipe>[];
    for (final c in candidates) {
      final kcal = c.perServing.kcal;
      if (kcal == null) {
        unknown.add(RankedRecipe(candidate: c, score: null));
        continue;
      }
      known.add(
        RankedRecipe(
          candidate: c,
          score: budget.isOver ? kcal : score(c.perServing, budget, goal),
          kcalShareOfRemaining: budget.isOver
              ? null
              : kcal / budget.remainingKcal,
          proteinShareOfRemaining: _proteinShare(c.perServing, budget),
          highProtein: isHighProtein(c.perServing),
        ),
      );
    }
    known.sort((a, b) {
      final byScore = a.score!.compareTo(b.score!);
      return byScore != 0
          ? byScore
          : a.candidate.name.compareTo(b.candidate.name);
    });
    unknown.sort((a, b) => a.candidate.name.compareTo(b.candidate.name));
    return [...known, ...unknown];
  }

  /// The fit of one serving with known calories; lower is better.
  static double score(Nutrients n, DayBudget budget, GoalType? goal) {
    var total = _miss(n.kcal!, budget.remainingKcal, budget.targetKcal);
    void macro(double? value, double? target, double eaten) {
      if (target == null || target <= 0) return;
      total +=
          macroWeight *
          _miss(value ?? 0, (target - eaten).clamp(0, target), target);
    }

    macro(n.proteinG, budget.targetProteinG, budget.eatenProteinG);
    macro(n.carbsG, budget.targetCarbsG, budget.eatenCarbsG);
    macro(n.fatG, budget.targetFatG, budget.eatenFatG);

    final kcal = n.kcal!;
    final bonus = switch (goal) {
      GoalType.buildMuscle ||
      GoalType.improveStrength => kcal > 0 ? (n.proteinG ?? 0) * 4 / kcal : 0.0,
      GoalType.loseWeight =>
        budget.targetKcal > 0 ? 1 - kcal / budget.targetKcal : 0.0,
      _ => 0.0,
    };
    return total - goalWeight * bonus;
  }

  static bool isHighProtein(Nutrients n) {
    final kcal = n.kcal, protein = n.proteinG;
    return kcal != null &&
        protein != null &&
        kcal > 0 &&
        protein * 4 / kcal >= highProteinShare;
  }

  static double _miss(double value, double remaining, double target) {
    if (target <= 0) return 0;
    final diff = value - remaining;
    return (diff > 0 ? overshootWeight * diff : -diff) / target;
  }

  static double? _proteinShare(Nutrients n, DayBudget budget) {
    final left = budget.remainingProteinG;
    final protein = n.proteinG;
    if (left == null || left <= 0 || protein == null) return null;
    return protein / left;
  }
}
