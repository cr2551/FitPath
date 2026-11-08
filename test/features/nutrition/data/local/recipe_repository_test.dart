import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FoodRepository foods;
  late RecipeRepository recipes;
  late int oats, milk, banana;

  setUp(() async {
    db = createTestDatabase();
    foods = FoodRepository(db.foodDao, clock: () => DateTime(2026, 11, 3, 8));
    recipes = RecipeRepository(db.recipeDao, db.foodDao);
    oats = await foods.createCustomFood(
      const FoodDetails(
        name: 'Rolled oats',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(
          kcal: 380,
          proteinG: 13,
          carbsG: 67,
          fatG: 7,
          fiberG: 10,
        ),
      ),
    );
    milk = await foods.createCustomFood(
      const FoodDetails(
        name: 'Milk',
        basis: ReferenceBasis.per100ml,
        nutrients: Nutrients(kcal: 64, proteinG: 3.4, carbsG: 4.8, fatG: 3.6),
      ),
    );
    banana = await foods.createCustomFood(
      const FoodDetails(
        name: 'Banana',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 89, proteinG: 1.1, carbsG: 23, fatG: 0.3),
        servingSize: 118,
        servingUnit: QuantityUnit.gram,
        servingDescription: '1 medium',
      ),
    );
  });
  tearDown(() => db.close());

  RecipeInput porridge({int servings = 2, List<IngredientInput>? items}) =>
      RecipeInput(
        name: '  Porridge ',
        servings: servings,
        ingredients:
            items ??
            [
              IngredientInput(
                foodId: oats,
                quantity: 100,
                unit: QuantityUnit.gram,
              ),
              IngredientInput(
                foodId: milk,
                quantity: 300,
                unit: QuantityUnit.milliliter,
                note: 'or water',
              ),
              IngredientInput(
                foodId: banana,
                quantity: 1,
                unit: QuantityUnit.serving,
              ),
            ],
      );

  test('a recipe is a per-serving food with computed nutrition', () async {
    final foodId = await recipes.create(porridge());
    final r = (await recipes.byFoodId(foodId))!;

    expect(r.food.name, 'Porridge');
    expect(r.food.source, FoodSource.recipe);
    expect(r.food.referenceBasis, ReferenceBasis.perServing);
    expect(r.food.servingDescription, '1 serving');
    expect(r.recipe.servings, 2);

    // Oats 380 + milk 3 × 64 = 192 + banana 1.18 × 89 = 105.02 → 677.02 / 2.
    expect(r.food.kcal, closeTo(338.51, 1e-9));
    // 13 + 10.2 + 1.298 = 24.498 / 2.
    expect(r.food.proteinG, closeTo(12.249, 1e-9));
    // Milk and banana have no fiber value: unknown stays unknown.
    expect(r.food.fiberG, isNull);

    expect(
      [for (final i in r.ingredients) (i.food.name, i.unit, i.ingredient.note)],
      [
        ('Rolled oats', QuantityUnit.gram, null),
        ('Milk', QuantityUnit.milliliter, 'or water'),
        ('Banana', QuantityUnit.serving, null),
      ],
    );
    expect(r.ingredients[1].nutrients.kcal, closeTo(192, 1e-9));

    // It is found and logged like any other food.
    expect((await foods.searchLocal('porr')).single.id, foodId);
    final entryId = await foods.logFood(
      foodId: foodId,
      quantity: 1,
      unit: QuantityUnit.serving,
      meal: MealType.breakfast,
    );
    expect((await foods.entryById(entryId))!.kcal, closeTo(338.51, 1e-9));
  });

  test('editing a recipe never changes logged entries', () async {
    final foodId = await recipes.create(porridge());
    final entryId = await foods.logFood(
      foodId: foodId,
      quantity: 1,
      unit: QuantityUnit.serving,
      meal: MealType.breakfast,
    );

    await recipes.update(
      foodId,
      RecipeInput(
        name: 'Oat porridge',
        servings: 1,
        ingredients: [
          IngredientInput(foodId: oats, quantity: 50, unit: QuantityUnit.gram),
        ],
      ),
    );

    final r = (await recipes.byFoodId(foodId))!;
    expect(r.food.name, 'Oat porridge');
    expect(r.food.kcal, 190);
    expect(r.food.fiberG, 5);
    expect(r.recipe.servings, 1);
    expect(r.ingredients, hasLength(1));

    final entry = (await foods.entryById(entryId))!;
    expect(entry.nameSnapshot, 'Porridge');
    expect(entry.kcal, closeTo(338.51, 1e-9));
  });

  group('delete', () {
    test('an unused recipe is removed with its ingredients', () async {
      final foodId = await recipes.create(porridge());
      await recipes.delete(foodId);
      expect(await foods.foodById(foodId), isNull);
      expect(await recipes.byFoodId(foodId), isNull);
      expect(await db.select(db.recipes).get(), isEmpty);
      expect(await db.select(db.recipeIngredients).get(), isEmpty);
    });

    test('a recipe the diary uses is only made inactive', () async {
      final foodId = await recipes.create(porridge());
      await foods.logFood(
        foodId: foodId,
        quantity: 2,
        unit: QuantityUnit.serving,
        meal: MealType.lunch,
      );
      await recipes.delete(foodId);

      expect((await foods.foodById(foodId))!.isActive, isFalse);
      expect(await foods.searchLocal('porr'), isEmpty);
      expect(await recipes.byFoodId(foodId), isNotNull);
    });

    test('a food used as an ingredient is only made inactive', () async {
      await recipes.create(porridge());
      await foods.removeFood(milk);
      expect((await foods.foodById(milk))!.isActive, isFalse);
    });
  });

  group('validation', () {
    Future<void> expectRejected(RecipeInput input, Matcher error) async {
      await expectLater(recipes.create(input), throwsA(error));
      expect(await db.select(db.recipes).get(), isEmpty);
    }

    test('name, servings, ingredients and quantities', () async {
      await expectRejected(
        RecipeInput(
          name: ' ',
          servings: 1,
          ingredients: porridge().ingredients,
        ),
        isArgumentError,
      );
      await expectRejected(porridge(servings: 0), isArgumentError);
      await expectRejected(porridge(items: []), isArgumentError);
      await expectRejected(
        porridge(
          items: [
            IngredientInput(foodId: oats, quantity: 0, unit: QuantityUnit.gram),
          ],
        ),
        isArgumentError,
      );
    });

    test('incompatible units and unknown foods', () async {
      await expectRejected(
        porridge(
          items: [
            IngredientInput(
              foodId: oats,
              quantity: 1,
              unit: QuantityUnit.serving,
            ),
          ],
        ),
        isA<IncompatibleQuantityUnit>(),
      );
      await expectRejected(
        porridge(
          items: [
            const IngredientInput(
              foodId: 999,
              quantity: 1,
              unit: QuantityUnit.gram,
            ),
          ],
        ),
        isA<FoodNotFound>(),
      );
      // Nothing half-written.
      expect(await foods.searchLocal('porridge'), isEmpty);
    });

    test('a recipe cannot be an ingredient', () async {
      final foodId = await recipes.create(porridge());
      await expectLater(
        recipes.create(
          porridge(
            items: [
              IngredientInput(
                foodId: foodId,
                quantity: 1,
                unit: QuantityUnit.serving,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  test('per serving: unknown stays unknown, no ingredients is empty', () {
    expect(
      RecipeRepository.perServing(const [
        Nutrients(kcal: 100, proteinG: 4),
        Nutrients(kcal: 50),
      ], 3),
      const Nutrients(kcal: 50),
    );
    expect(RecipeRepository.perServing(const [], 2), Nutrients.empty);
  });
}
