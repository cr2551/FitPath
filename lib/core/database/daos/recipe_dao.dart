import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_tables.dart';
import '../tables/recipe_tables.dart';

part 'recipe_dao.g.dart';

/// Recipe and ingredient queries.
@DriftAccessor(tables: [Recipes, RecipeIngredients, FoodItems])
class RecipeDao extends DatabaseAccessor<AppDatabase> with _$RecipeDaoMixin {
  RecipeDao(super.attachedDatabase);

  Future<Recipe?> recipeByFoodId(int foodId) => (select(
    recipes,
  )..where((r) => r.foodItemId.equals(foodId))).getSingleOrNull();

  Future<Recipe?> recipeByBundledId(String bundledId) => (select(
    recipes,
  )..where((r) => r.bundledId.equals(bundledId))).getSingleOrNull();

  Future<int> insertRecipe(RecipesCompanion recipe) =>
      into(recipes).insert(recipe);

  Future<void> updateRecipe(int id, RecipesCompanion recipe) =>
      (update(recipes)..where((r) => r.id.equals(id))).write(
        recipe.copyWith(updatedAt: Value(DateTime.now())),
      );

  /// Ingredients of [recipeId] in order, with their foods.
  Future<List<(RecipeIngredient, FoodItem)>> ingredients(int recipeId) async {
    final rows =
        await (select(recipeIngredients)
              ..where((i) => i.recipeId.equals(recipeId))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .join([
              innerJoin(
                foodItems,
                foodItems.id.equalsExp(recipeIngredients.foodItemId),
              ),
            ])
            .get();
    return [
      for (final r in rows)
        (r.readTable(recipeIngredients), r.readTable(foodItems)),
    ];
  }

  /// Replaces the ingredients of [recipeId] with [items], in order.
  Future<void> replaceIngredients(
    int recipeId,
    List<RecipeIngredientsCompanion> items,
  ) async {
    await (delete(
      recipeIngredients,
    )..where((i) => i.recipeId.equals(recipeId))).go();
    await batch((b) => b.insertAll(recipeIngredients, items));
  }
}
