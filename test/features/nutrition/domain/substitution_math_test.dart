import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/substitution_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scales the amount by the ratio', () {
    expect(SubstitutionMath.scaledQuantity(100, 1.25), 125);
    expect(SubstitutionMath.scaledQuantity(80, 1), 80);
  });

  test('per-serving difference; unknown stays unknown', () {
    const sugar = Nutrients(kcal: 400, proteinG: 0, carbsG: 100, fatG: 0);
    const honey = Nutrients(kcal: 375, carbsG: 100, fatG: 0);
    final diff = SubstitutionMath.perServingDifference(sugar, honey, 2);
    expect(diff.kcal, -12.5);
    expect(diff.carbsG, 0);
    expect(diff.fatG, 0);
    expect(diff.proteinG, isNull);
    expect(diff.fiberG, isNull);
  });
}
