import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/recipe_ranking.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeCandidate _r(String name, double? kcal, {double? protein}) =>
    RecipeCandidate(
      foodId: name.hashCode,
      name: name,
      perServing: Nutrients(kcal: kcal, proteinG: protein),
    );

List<String> _names(List<RankedRecipe> list) => [
  for (final r in list) r.candidate.name,
];

void main() {
  // 600 kcal left of 2000.
  const budget = DayBudget(targetKcal: 2000, eatenKcal: 1400);

  test('closest to the remaining calories first; overshoot costs double', () {
    final ranked = RecipeRanking.rank([
      _r('Over 100', 700),
      _r('Exact', 600),
      _r('Under 100', 500),
      _r('Under 150', 450),
    ], budget: budget);
    // Exact 0, under 100 -> 0.05, under 150 -> 0.075, over 100 -> 0.1.
    expect(_names(ranked), ['Exact', 'Under 100', 'Under 150', 'Over 100']);
    expect(ranked[1].score, closeTo(0.05, 1e-9));
    expect(ranked[3].score, closeTo(0.1, 1e-9));
    expect(ranked[0].kcalShareOfRemaining, closeTo(1, 1e-9));
  });

  test('macro targets count half of their relative miss', () {
    // 50 g protein left of 150.
    const withProtein = DayBudget(
      targetKcal: 2000,
      eatenKcal: 1400,
      targetProteinG: 150,
      eatenProteinG: 100,
    );
    final ranked = RecipeRanking.rank([
      _r('Exact kcal, low protein', 600, protein: 20),
      _r('Short kcal, all protein', 500, protein: 50),
    ], budget: withProtein);
    // 0 + 0.5 * 30/150 = 0.1 against 0.05 + 0.
    expect(_names(ranked), [
      'Short kcal, all protein',
      'Exact kcal, low protein',
    ]);
    expect(ranked.first.score, closeTo(0.05, 1e-9));
    expect(ranked.last.score, closeTo(0.1, 1e-9));
    expect(ranked.first.proteinShareOfRemaining, closeTo(1, 1e-9));
  });

  test('the goal breaks ties', () {
    final candidates = [
      _r('A lean', 600, protein: 15),
      _r('B protein', 600, protein: 45),
    ];
    expect(_names(RecipeRanking.rank(candidates, budget: budget)), [
      'A lean',
      'B protein',
    ]);
    final muscle = RecipeRanking.rank(
      candidates,
      budget: budget,
      goal: GoalType.buildMuscle,
    );
    expect(_names(muscle), ['B protein', 'A lean']);
    // 45 g * 4 / 600 kcal = 0.3 of the calories from protein.
    expect(muscle.first.score, closeTo(-0.05 * 0.3, 1e-9));
    expect(muscle.first.highProtein, isTrue);
    expect(muscle.last.highProtein, isFalse);

    // 625 (25 over, x2) and 550 (50 under) miss by the same 0.025; weight
    // loss prefers the lighter one.
    final lighter = RecipeRanking.rank(
      [_r('Heavier', 625), _r('Lighter', 550)],
      budget: budget,
      goal: GoalType.loseWeight,
    );
    expect(_names(lighter), ['Lighter', 'Heavier']);
    expect(lighter.first.score, closeTo(0.025 - 0.05 * 0.725, 1e-9));
  });

  test('unknown calories rank last, by name', () {
    final ranked = RecipeRanking.rank([
      _r('Zucchini mystery', null),
      _r('Apple mystery', null),
      _r('Far off', 1800),
    ], budget: budget);
    expect(_names(ranked), ['Far off', 'Apple mystery', 'Zucchini mystery']);
    expect(ranked.last.score, isNull);
  });

  test('over target: lightest first', () {
    const over = DayBudget(targetKcal: 2000, eatenKcal: 2100);
    expect(over.isOver, isTrue);
    final ranked = RecipeRanking.rank([
      _r('Big', 900),
      _r('Small', 200),
      _r('Mid', 400),
    ], budget: over);
    expect(_names(ranked), ['Small', 'Mid', 'Big']);
    expect(ranked.first.kcalShareOfRemaining, isNull);
  });
}
