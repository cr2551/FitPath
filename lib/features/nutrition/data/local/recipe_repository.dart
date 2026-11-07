import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/recipe_dao.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';
import 'food_repository.dart';

/// An amount of a catalog food in a recipe.
class IngredientInput {
  const IngredientInput({
    required this.foodId,
    required this.quantity,
    required this.unit,
    this.note,
  });

  final int foodId;
  final double quantity;
  final QuantityUnit unit;
  final String? note;
}

/// What the recipe builder (or the bundled recipe seeder) saves.
class RecipeInput {
  const RecipeInput({
    required this.name,
    required this.servings,
    required this.ingredients,
    this.bundledId,
    this.sourceVersion,
  });

  final String name;
  final int servings;

  /// In order.
  final List<IngredientInput> ingredients;

  /// Set only for bundled recipes.
  final String? bundledId;
  final String? sourceVersion;
}

/// One ingredient with its food and the nutrients of its amount.
class IngredientLine {
  const IngredientLine({
    required this.ingredient,
    required this.food,
    required this.nutrients,
  });

  final RecipeIngredient ingredient;
  final FoodItem food;
  final Nutrients nutrients;

  QuantityUnit get unit => FoodRepository.unitFromCode(ingredient.unit);
}

/// A recipe with its food row (name, cached per-serving nutrition) and
/// ingredients.
class RecipeDetails {
  const RecipeDetails({
    required this.food,
    required this.recipe,
    required this.ingredients,
  });

  final FoodItem food;
  final Recipe recipe;
  final List<IngredientLine> ingredients;
}

/// Recipes are stored as a `food_items` row (`source = recipe`, nutrients
/// per serving) plus a `recipes` row and its ingredients. Search, logging
/// and diary snapshots therefore work unchanged, and editing a recipe never
/// changes logged entries.
///
/// Recipes are addressed by their food id, like every other food.
class RecipeRepository {
  RecipeRepository(this._recipes, this._foods);

  final RecipeDao _recipes;
  final FoodDao _foods;

  static const servingDescription = '1 serving';

  Future<RecipeDetails?> byFoodId(int foodId) async {
    final food = await _foods.foodById(foodId);
    final recipe = await _recipes.recipeByFoodId(foodId);
    if (food == null || recipe == null) return null;
    return RecipeDetails(
      food: food,
      recipe: recipe,
      ingredients: [
        for (final (row, f) in await _recipes.ingredients(recipe.id))
          IngredientLine(
            ingredient: row,
            food: f,
            nutrients: _scale(
              f,
              row.quantity,
              FoodRepository.unitFromCode(row.unit),
            ),
          ),
      ],
    );
  }

  /// Creates a recipe and returns its food id.
  Future<int> create(RecipeInput input) async {
    _validate(input);
    return _foods.transaction(() async {
      final perServing = await _perServing(input);
      final foodId = await _foods.insertFood(
        _foodRow(
          input,
          perServing,
        ).copyWith(source: const Value(FoodSource.recipe)),
      );
      final recipeId = await _recipes.insertRecipe(
        RecipesCompanion.insert(
          foodItemId: foodId,
          servings: input.servings,
          bundledId: Value(input.bundledId),
          sourceVersion: Value(input.sourceVersion),
        ),
      );
      await _recipes.replaceIngredients(
        recipeId,
        _ingredientRows(recipeId, input),
      );
      return foodId;
    });
  }

  /// Replaces a recipe's name, servings and ingredients, and recomputes its
  /// per-serving nutrition. Logged entries keep their snapshots.
  Future<void> update(int foodId, RecipeInput input) async {
    _validate(input);
    await _foods.transaction(() async {
      final recipe = await _recipes.recipeByFoodId(foodId);
      if (recipe == null) throw FoodNotFound(foodId);
      final perServing = await _perServing(input);
      await _foods.updateFood(foodId, _foodRow(input, perServing));
      await _recipes.updateRecipe(
        recipe.id,
        RecipesCompanion(
          servings: Value(input.servings),
          sourceVersion: Value(input.sourceVersion),
        ),
      );
      await _recipes.replaceIngredients(
        recipe.id,
        _ingredientRows(recipe.id, input),
      );
    });
  }

  /// Deletes a recipe. One the diary uses is only made inactive (hidden from
  /// search), like any other food, so history stays intact.
  Future<void> delete(int foodId) => _foods.transaction(() async {
    if (await _foods.isReferenced(foodId)) {
      await _foods.updateFood(
        foodId,
        const FoodItemsCompanion(isActive: Value(false)),
      );
    } else {
      // Cascades to the recipe and its ingredients.
      await _foods.deleteFood(foodId);
    }
  });

  /// The sum of [amounts] divided by [servings]. A nutrient is known only
  /// when every ingredient knows it: unknown never becomes zero.
  static Nutrients perServing(Iterable<Nutrients> amounts, int servings) {
    final list = amounts.toList();
    double? sum(double? Function(Nutrients) f) {
      var total = 0.0;
      for (final n in list) {
        final v = f(n);
        if (v == null) return null;
        total += v;
      }
      return total;
    }

    if (list.isEmpty) return Nutrients.empty;
    return Nutrients(
          kcal: sum((n) => n.kcal),
          proteinG: sum((n) => n.proteinG),
          carbsG: sum((n) => n.carbsG),
          fatG: sum((n) => n.fatG),
          fiberG: sum((n) => n.fiberG),
          sugarG: sum((n) => n.sugarG),
          sodiumMg: sum((n) => n.sodiumMg),
        ) *
        (1 / servings);
  }

  Future<Nutrients> _perServing(RecipeInput input) async {
    final amounts = <Nutrients>[];
    for (final i in input.ingredients) {
      final food = await _foods.foodById(i.foodId);
      if (food == null) throw FoodNotFound(i.foodId);
      if (food.source == FoodSource.recipe) {
        throw ArgumentError.value(
          i.foodId,
          'foodId',
          'a recipe cannot be an ingredient',
        );
      }
      amounts.add(_scale(food, i.quantity, i.unit));
    }
    return perServing(amounts, input.servings);
  }

  static Nutrients _scale(FoodItem food, double quantity, QuantityUnit unit) {
    final n = NutritionMath.scale(
      FoodRepository.foodNutrition(food),
      quantity,
      unit,
    );
    if (n == null) throw IncompatibleQuantityUnit(food.referenceBasis, unit);
    return n;
  }

  static FoodItemsCompanion _foodRow(RecipeInput input, Nutrients n) =>
      FoodItemsCompanion(
        name: Value(input.name.trim()),
        referenceBasis: const Value(ReferenceBasis.perServing),
        servingDescription: const Value(servingDescription),
        kcal: Value(n.kcal),
        proteinG: Value(n.proteinG),
        carbsG: Value(n.carbsG),
        fatG: Value(n.fatG),
        fiberG: Value(n.fiberG),
        sugarG: Value(n.sugarG),
        sodiumMg: Value(n.sodiumMg),
      );

  static List<RecipeIngredientsCompanion> _ingredientRows(
    int recipeId,
    RecipeInput input,
  ) => [
    for (final (position, i) in input.ingredients.indexed)
      RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        foodItemId: i.foodId,
        quantity: i.quantity,
        unit: FoodRepository.unitCode(i.unit),
        position: position,
        note: Value(i.note?.trim().isEmpty ?? true ? null : i.note!.trim()),
      ),
  ];

  static void _validate(RecipeInput input) {
    if (input.name.trim().isEmpty) {
      throw ArgumentError.value(input.name, 'name', 'must not be empty');
    }
    if (input.servings < 1) {
      throw ArgumentError.value(
        input.servings,
        'servings',
        'must be at least 1',
      );
    }
    if (input.ingredients.isEmpty) {
      throw ArgumentError.value(
        input.ingredients,
        'ingredients',
        'must not be empty',
      );
    }
    for (final i in input.ingredients) {
      if (!(i.quantity > 0) || !i.quantity.isFinite) {
        throw ArgumentError.value(i.quantity, 'quantity', 'must be above 0');
      }
    }
  }
}
