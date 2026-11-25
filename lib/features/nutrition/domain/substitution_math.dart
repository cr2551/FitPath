import 'nutrients.dart';

/// Swapping one recipe ingredient for a substitute.
abstract final class SubstitutionMath {
  /// The substitute's amount for [quantity] of the original, in the same
  /// unit. [ratio] is the substitute amount per one amount of the original.
  static double scaledQuantity(double quantity, double ratio) =>
      quantity * ratio;

  /// How one serving changes when [original] (the ingredient's amount) is
  /// replaced by [substitute] (the substitute's scaled amount), in a recipe
  /// of [servings]. A nutrient is unknown when either side does not know it:
  /// unknown never becomes zero.
  static Nutrients perServingDifference(
    Nutrients original,
    Nutrients substitute,
    int servings,
  ) {
    double? diff(double? Function(Nutrients) f) {
      final a = f(original), b = f(substitute);
      return a == null || b == null ? null : (b - a) / servings;
    }

    return Nutrients(
      kcal: diff((n) => n.kcal),
      proteinG: diff((n) => n.proteinG),
      carbsG: diff((n) => n.carbsG),
      fatG: diff((n) => n.fatG),
      fiberG: diff((n) => n.fiberG),
      sugarG: diff((n) => n.sugarG),
      sodiumMg: diff((n) => n.sodiumMg),
    );
  }
}
