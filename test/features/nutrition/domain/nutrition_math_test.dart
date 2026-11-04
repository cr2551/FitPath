import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const oats = FoodNutrition(
  basis: ReferenceBasis.per100g,
  nutrients: Nutrients(kcal: 380, proteinG: 13, carbsG: 67, fatG: 7),
);

const banana = FoodNutrition(
  basis: ReferenceBasis.per100g,
  nutrients: Nutrients(kcal: 89, proteinG: 1.1, carbsG: 23, fatG: 0.3),
  servingSize: 118,
  servingUnit: QuantityUnit.gram,
);

const milk = FoodNutrition(
  basis: ReferenceBasis.per100ml,
  nutrients: Nutrients(kcal: 64, proteinG: 3.4, carbsG: 4.8, fatG: 3.6),
);

const proteinBar = FoodNutrition(
  basis: ReferenceBasis.perServing,
  nutrients: Nutrients(kcal: 210, proteinG: 20, carbsG: 22, fatG: 7),
  servingSize: 60,
  servingUnit: QuantityUnit.gram,
);

void main() {
  group('scaling by reference basis', () {
    test('per 100 g: nutrient x grams / 100', () {
      final n = NutritionMath.scale(oats, 50, QuantityUnit.gram)!;
      expect(n.kcal, 190);
      expect(n.proteinG, 6.5);
      expect(n.carbsG, 33.5);
      expect(n.fatG, 3.5);
    });

    test('per 100 g logged in servings uses the serving size', () {
      final n = NutritionMath.scale(banana, 1, QuantityUnit.serving)!;
      expect(n.kcal, closeTo(105.02, 1e-9));
    });

    test('per 100 ml', () {
      final n = NutritionMath.scale(milk, 250, QuantityUnit.milliliter)!;
      expect(n.kcal, 160);
      expect(n.fatG, closeTo(9, 1e-9));
    });

    test('per serving, by servings or by grams of the serving', () {
      expect(
        NutritionMath.scale(proteinBar, 2, QuantityUnit.serving)!.kcal,
        420,
      );
      expect(NutritionMath.scale(proteinBar, 30, QuantityUnit.gram)!.kcal, 105);
    });

    test('grams and millilitres are never mixed', () {
      expect(NutritionMath.scale(oats, 100, QuantityUnit.milliliter), isNull);
      expect(NutritionMath.scale(milk, 100, QuantityUnit.gram), isNull);
      expect(
        NutritionMath.scale(proteinBar, 100, QuantityUnit.milliliter),
        isNull,
      );
    });

    test('servings need a serving size for 100 g / 100 ml foods', () {
      expect(NutritionMath.scale(oats, 1, QuantityUnit.serving), isNull);
    });

    test('negative quantities are rejected', () {
      expect(NutritionMath.scale(oats, -1, QuantityUnit.gram), isNull);
    });

    test('unknown nutrients stay unknown after scaling', () {
      const partial = FoodNutrition(
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 200, proteinG: 10),
      );
      final n = NutritionMath.scale(partial, 200, QuantityUnit.gram)!;
      expect(n.kcal, 400);
      expect(n.proteinG, 20);
      expect(n.carbsG, isNull);
      expect(n.fatG, isNull);
    });

    test('allowed units, preferred unit first', () {
      expect(NutritionMath.allowedUnits(oats), [QuantityUnit.gram]);
      expect(NutritionMath.allowedUnits(banana), [
        QuantityUnit.gram,
        QuantityUnit.serving,
      ]);
      expect(NutritionMath.allowedUnits(proteinBar), [
        QuantityUnit.serving,
        QuantityUnit.gram,
      ]);
    });
  });

  group('totals', () {
    test('sum known values and count unknowns', () {
      final t = NutrientTotals.of(const [
        Nutrients(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2),
        Nutrients(kcal: 200, proteinG: 5),
        Nutrients(proteinG: 1, carbsG: 1, fatG: 1),
      ]);
      expect(t.kcal, 300);
      expect(t.proteinG, 16);
      expect(t.carbsG, 6);
      expect(t.fatG, 3);
      expect(t.entryCount, 3);
      expect(t.entriesMissingKcal, 1);
      expect(t.entriesMissingMacros, 1);
    });

    test('empty list', () {
      final t = NutrientTotals.of(const []);
      expect(t.isEmpty, isTrue);
      expect(t.kcal, 0);
    });
  });

  group('macro calorie split (ring segments)', () {
    test('design example: P 110 g, C 180 g, F 53 g -> 27% / 44% / 29%', () {
      final s = MacroCalorieSplit.of(const [
        Nutrients(kcal: 1640, proteinG: 110, carbsG: 180, fatG: 53),
      ]);
      expect(s.proteinKcal, 440);
      expect(s.carbsKcal, 720);
      expect(s.fatKcal, 477);
      expect(s.unknownKcal, 0);
      expect((s.proteinShare * 100).round(), 27);
      expect((s.carbsShare * 100).round(), 44);
      expect((s.fatShare * 100).round(), 29);
    });

    test('calories without macro data become the unknown segment', () {
      final s = MacroCalorieSplit.of(const [
        Nutrients(kcal: 400, proteinG: 25, carbsG: 50, fatG: 10), // 390
        Nutrients(kcal: 210, proteinG: 20), // 80 known, 130 unknown
        Nutrients(kcal: 80), // all unknown
      ]);
      expect(s.proteinKcal, 180);
      expect(s.carbsKcal, 200);
      expect(s.fatKcal, 90);
      expect(s.unknownKcal, 210);
    });

    test('nothing logged: all shares are zero', () {
      final s = MacroCalorieSplit.of(const []);
      expect(s.total, 0);
      expect(s.proteinShare, 0);
    });
  });

  group('daily summary', () {
    test('groups by meal and counts meals logged', () {
      final d = DailyNutritionSummary(const [
        LoggedNutrients(
          meal: MealType.breakfast,
          nutrients: Nutrients(kcal: 441),
        ),
        LoggedNutrients(meal: MealType.lunch, nutrients: Nutrients(kcal: 500)),
        LoggedNutrients(meal: MealType.lunch, nutrients: Nutrients(kcal: 394)),
        LoggedNutrients(meal: MealType.snack, nutrients: Nutrients(kcal: 305)),
      ]);
      expect(d.total.kcal, 1640);
      expect(d.byMeal[MealType.lunch]!.kcal, 894);
      expect(d.byMeal[MealType.dinner]!.isEmpty, isTrue);
      expect(d.mealsLogged, 3);
    });
  });

  group('calorie progress', () {
    test('on track', () {
      const p = CalorieProgress(eatenKcal: 1640, targetKcal: 2100);
      expect(p.state, CalorieState.onTrack);
      expect(p.remainingKcal, 460);
      expect(p.overKcal, 0);
      expect(p.fraction, closeTo(0.781, 0.001));
    });

    test('over target never shows negative remaining', () {
      const p = CalorieProgress(eatenKcal: 2220, targetKcal: 2100);
      expect(p.state, CalorieState.over);
      expect(p.remainingKcal, 0);
      expect(p.overKcal, 120);
      expect(p.fraction, 1);
    });

    test('nothing logged', () {
      const p = CalorieProgress(eatenKcal: 0, targetKcal: 2100);
      expect(p.state, CalorieState.nothingLogged);
      expect(p.fraction, 0);
    });

    test('no target or a zero target', () {
      for (final target in [null, 0.0]) {
        final p = CalorieProgress(eatenKcal: 1640, targetKcal: target);
        expect(p.state, CalorieState.noTarget);
        expect(p.remainingKcal, isNull);
        expect(p.fraction, isNull);
      }
    });
  });

  group('macro progress', () {
    test('configured target', () {
      const m = MacroProgress(consumedG: 110, targetG: 140);
      expect(m.isConfigured, isTrue);
      expect(m.fraction, closeTo(0.786, 0.001));
      expect(m.isOver, isFalse);
    });

    test('over target clamps the bar', () {
      const m = MacroProgress(consumedG: 90, targetG: 70);
      expect(m.fraction, 1);
      expect(m.isOver, isTrue);
    });

    test('unset target is unconfigured, not zero', () {
      const m = MacroProgress(consumedG: 50, targetG: null);
      expect(m.isConfigured, isFalse);
      expect(m.fraction, isNull);
      expect(m.isOver, isFalse);
    });
  });
}
