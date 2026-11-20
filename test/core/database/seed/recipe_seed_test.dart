import 'dart:io';

import 'package:fitpath/core/database/seed/food_seed.dart';
import 'package:fitpath/core/database/seed/recipe_seed.dart';
import 'package:fitpath/core/database/seed/substitution_seed.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  final recipeJson = File(recipeCatalogAsset).readAsStringSync();
  final substitutionJson = File(substitutionCatalogAsset).readAsStringSync();
  final recipes = parseRecipeCatalog(recipeJson);
  final foods = {
    for (final food in parseFoodCatalog(
      File(foodCatalogAsset).readAsStringSync(),
    ))
      food.name.value.toLowerCase(): food,
  };

  group('bundled recipe catalog', () {
    test('contains a useful, uniquely identified offline subset', () {
      expect(recipes.length, greaterThanOrEqualTo(100));
      expect(recipes.map((r) => r.id).toSet(), hasLength(recipes.length));
    });

    test('uses compatible starter-food units and credible source macros', () {
      for (final recipe in recipes) {
        final fromMacros =
            recipe.proteinG * 4 + recipe.carbsG * 4 + recipe.fatG * 9;
        final tolerance = recipe.kcal * .15 < 20 ? 20 : recipe.kcal * .15;
        expect(
          (fromMacros - recipe.kcal).abs(),
          lessThanOrEqualTo(tolerance),
          reason: recipe.id,
        );
        for (final ingredient in recipe.ingredients) {
          final food = foods[ingredient.foodName.toLowerCase()];
          expect(
            food,
            isNotNull,
            reason: '${recipe.id}: ${ingredient.foodName}',
          );
          switch (ingredient.unit) {
            case QuantityUnit.gram:
              expect(food!.referenceBasis.value, ReferenceBasis.per100g);
            case QuantityUnit.milliliter:
              expect(food!.referenceBasis.value, ReferenceBasis.per100ml);
            case QuantityUnit.serving:
              expect(food!.servingSize.value, isNotNull);
          }
        }
      }
    });
  });

  test('substitution catalog is valid and uses known foods', () {
    final substitutions = parseSubstitutionCatalog(substitutionJson);
    expect(substitutions, isNotEmpty);
    for (final substitution in substitutions) {
      expect(foods, contains(substitution.fromFoodName.toLowerCase()));
      expect(foods, contains(substitution.toFoodName.toLowerCase()));
    }
  });

  test('recipe seeding is idempotent and searchable offline', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final bundle = _FileBundle();
    await seedFoods(db, bundle: bundle);
    await seedRecipes(db, bundle: bundle);
    await seedRecipes(db, bundle: bundle);

    final recipeRows = await db.select(db.recipes).get();
    final foods = await db.select(db.foodItems).get();
    expect(recipeRows, hasLength(recipes.length));
    expect(
      foods.where((food) => food.source == FoodSource.recipe),
      hasLength(recipes.length),
    );
    expect(
      (await db.foodDao.searchActive('rice'))
          .any((food) => food.source == FoodSource.recipe),
      isTrue,
    );
  });
}
