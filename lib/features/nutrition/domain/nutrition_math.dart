import 'dart:math' as math;

import '../../../shared/models/enums.dart';
import 'nutrients.dart';

/// Unit of a logged quantity.
enum QuantityUnit { gram, milliliter, serving }

/// What a food's nutrient values refer to, plus its optional serving size.
class FoodNutrition {
  const FoodNutrition({
    required this.basis,
    required this.nutrients,
    this.servingSize,
    this.servingUnit,
  });

  /// Nutrients per 100 g, per 100 ml, or per serving (see [basis]).
  final Nutrients nutrients;
  final ReferenceBasis basis;

  /// Size of one serving, e.g. 118 (g) for "1 medium banana".
  final double? servingSize;

  /// [QuantityUnit.gram] or [QuantityUnit.milliliter].
  final QuantityUnit? servingUnit;
}

/// Atwater energy factors (kcal per gram).
abstract final class KcalPerGram {
  static const double protein = 4;
  static const double carbs = 4;
  static const double fat = 9;
}

abstract final class NutritionMath {
  /// How many "reference amounts" [quantity] [unit] of [food] is, or null if
  /// the unit is incompatible (grams and millilitres are never mixed).
  ///
  /// * per100g: grams / 100, or servings x serving size (g) / 100
  /// * per100ml: millilitres / 100, or servings x serving size (ml) / 100
  /// * perServing: servings, or grams/ml / serving size in that same unit
  static double? referenceFactor(
    FoodNutrition food,
    double quantity,
    QuantityUnit unit,
  ) {
    if (quantity < 0) return null;
    final size = food.servingSize;
    final sizeUnit = food.servingUnit;

    switch (food.basis) {
      case ReferenceBasis.per100g:
        if (unit == QuantityUnit.gram) return quantity / 100;
        if (unit == QuantityUnit.serving &&
            size != null &&
            sizeUnit == QuantityUnit.gram) {
          return quantity * size / 100;
        }
        return null;
      case ReferenceBasis.per100ml:
        if (unit == QuantityUnit.milliliter) return quantity / 100;
        if (unit == QuantityUnit.serving &&
            size != null &&
            sizeUnit == QuantityUnit.milliliter) {
          return quantity * size / 100;
        }
        return null;
      case ReferenceBasis.perServing:
        if (unit == QuantityUnit.serving) return quantity;
        if (size != null && size > 0 && unit == sizeUnit) {
          return quantity / size;
        }
        return null;
    }
  }

  /// Nutrients for [quantity] [unit] of [food], or null if the unit is
  /// incompatible with the food's reference basis.
  static Nutrients? scale(
    FoodNutrition food,
    double quantity,
    QuantityUnit unit,
  ) {
    final factor = referenceFactor(food, quantity, unit);
    return factor == null ? null : food.nutrients * factor;
  }

  /// Units a quantity of [food] can be entered in, best first.
  static List<QuantityUnit> allowedUnits(FoodNutrition food) => [
    for (final u in QuantityUnit.values)
      if (referenceFactor(food, 1, u) != null) u,
  ]..sort((a, b) => _preference(food.basis, a) - _preference(food.basis, b));

  static int _preference(ReferenceBasis basis, QuantityUnit u) =>
      switch ((basis, u)) {
        (ReferenceBasis.perServing, QuantityUnit.serving) => 0,
        (ReferenceBasis.per100g, QuantityUnit.gram) => 0,
        (ReferenceBasis.per100ml, QuantityUnit.milliliter) => 0,
        _ => 1,
      };
}

/// A diary entry's nutrient snapshot and meal, as the summaries need it.
class LoggedNutrients {
  const LoggedNutrients({required this.meal, required this.nutrients});

  final MealType meal;
  final Nutrients nutrients;
}

/// Totals of a set of entries. Unknown values are skipped but counted, so the
/// UI can say "2 entries have no protein data".
class NutrientTotals {
  const NutrientTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.entryCount,
    required this.entriesMissingKcal,
    required this.entriesMissingMacros,
  });

  factory NutrientTotals.of(Iterable<Nutrients> items) {
    var kcal = 0.0, p = 0.0, c = 0.0, f = 0.0;
    var count = 0, missingKcal = 0, missingMacros = 0;
    for (final n in items) {
      count++;
      kcal += n.kcal ?? 0;
      p += n.proteinG ?? 0;
      c += n.carbsG ?? 0;
      f += n.fatG ?? 0;
      if (n.kcal == null) missingKcal++;
      if (!n.hasAllMacros) missingMacros++;
    }
    return NutrientTotals(
      kcal: kcal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      entryCount: count,
      entriesMissingKcal: missingKcal,
      entriesMissingMacros: missingMacros,
    );
  }

  static const zero = NutrientTotals(
    kcal: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    entryCount: 0,
    entriesMissingKcal: 0,
    entriesMissingMacros: 0,
  );

  /// Sums of the KNOWN values only.
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  final int entryCount;
  final int entriesMissingKcal;
  final int entriesMissingMacros;

  bool get isEmpty => entryCount == 0;
}

/// Calories eaten split by where they came from: the data behind the
/// macro-segmented calorie ring (`DESIGN/README.md` section 4).
class MacroCalorieSplit {
  const MacroCalorieSplit({
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
    required this.unknownKcal,
  });

  /// For each entry with all macros known, the macro calories count toward
  /// their segments. For entries with some macros unknown, known macros still
  /// count and the rest of the label calories become [unknownKcal].
  factory MacroCalorieSplit.of(Iterable<Nutrients> items) {
    var p = 0.0, c = 0.0, f = 0.0, unknown = 0.0;
    for (final n in items) {
      final pk = (n.proteinG ?? 0) * KcalPerGram.protein;
      final ck = (n.carbsG ?? 0) * KcalPerGram.carbs;
      final fk = (n.fatG ?? 0) * KcalPerGram.fat;
      p += pk;
      c += ck;
      f += fk;
      if (!n.hasAllMacros && n.kcal != null) {
        unknown += math.max(0, n.kcal! - (pk + ck + fk));
      }
    }
    return MacroCalorieSplit(
      proteinKcal: p,
      carbsKcal: c,
      fatKcal: f,
      unknownKcal: unknown,
    );
  }

  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;
  final double unknownKcal;

  double get total => proteinKcal + carbsKcal + fatKcal + unknownKcal;

  double _share(double v) => total == 0 ? 0 : v / total;
  double get proteinShare => _share(proteinKcal);
  double get carbsShare => _share(carbsKcal);
  double get fatShare => _share(fatKcal);
  double get unknownShare => _share(unknownKcal);
}

/// One day's diary, grouped by meal.
class DailyNutritionSummary {
  DailyNutritionSummary(List<LoggedNutrients> entries)
    : total = NutrientTotals.of(entries.map((e) => e.nutrients)),
      split = MacroCalorieSplit.of(entries.map((e) => e.nutrients)),
      byMeal = {
        for (final meal in MealType.values)
          meal: NutrientTotals.of(
            entries.where((e) => e.meal == meal).map((e) => e.nutrients),
          ),
      };

  final NutrientTotals total;
  final MacroCalorieSplit split;
  final Map<MealType, NutrientTotals> byMeal;

  /// Meals with at least one entry.
  int get mealsLogged => byMeal.values.where((t) => !t.isEmpty).length;
}

enum CalorieState { noTarget, nothingLogged, onTrack, over }

/// Eaten vs target. Never exposes a negative "remaining" (spec section 5).
class CalorieProgress {
  const CalorieProgress({required this.eatenKcal, required this.targetKcal});

  final double eatenKcal;

  /// Null or <= 0 means no usable target.
  final double? targetKcal;

  bool get hasTarget => targetKcal != null && targetKcal! > 0;

  CalorieState get state {
    if (!hasTarget) return CalorieState.noTarget;
    if (eatenKcal <= 0) return CalorieState.nothingLogged;
    return eatenKcal > targetKcal! ? CalorieState.over : CalorieState.onTrack;
  }

  /// Calories left, never negative. Null without a target.
  double? get remainingKcal =>
      hasTarget ? math.max(0, targetKcal! - eatenKcal) : null;

  /// How far over the target, 0 when not over. Null without a target.
  double? get overKcal =>
      hasTarget ? math.max(0, eatenKcal - targetKcal!) : null;

  /// Arc fraction for the ring, clamped to 0..1. Null without a target.
  double? get fraction =>
      hasTarget ? (eatenKcal / targetKcal!).clamp(0.0, 1.0) : null;
}

/// Consumed grams of one macro vs its target.
class MacroProgress {
  const MacroProgress({required this.consumedG, required this.targetG});

  final double consumedG;

  /// Null means the user has not configured a target: show "Set target",
  /// never a misleading zero target.
  final double? targetG;

  bool get isConfigured => targetG != null && targetG! > 0;

  /// Bar fill, clamped to 0..1. Null when unconfigured.
  double? get fraction =>
      isConfigured ? (consumedG / targetG!).clamp(0.0, 1.0) : null;

  bool get isOver => isConfigured && consumedG > targetG!;
}
