// Drift `check()` constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_tables.dart';

/// A recipe. Its name and cached per-serving nutrition live in its
/// `food_items` row (`source = recipe`, basis per serving), so search,
/// logging and diary snapshots treat it like any other food.
@DataClassName('Recipe')
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 1:1 with the recipe's food row; deleting the food deletes the recipe.
  IntColumn get foodItemId => integer().unique().references(
    FoodItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get servings => integer().check(servings.isBiggerOrEqualValue(1))();

  /// Stable id of a bundled recipe, so seeding never duplicates it.
  TextColumn get bundledId => text().nullable().unique()();

  /// Version of the dataset a bundled recipe came from.
  TextColumn get sourceVersion => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// An ingredient of a recipe: an amount of a catalog food.
@DataClassName('RecipeIngredient')
@TableIndex(name: 'recipe_ingredients_recipe', columns: {#recipeId})
class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId =>
      integer().references(Recipes, #id, onDelete: KeyAction.cascade)();

  /// A food used in a recipe cannot be deleted, only made inactive.
  IntColumn get foodItemId =>
      integer().references(FoodItems, #id, onDelete: KeyAction.restrict)();
  RealColumn get quantity => real().check(quantity.isBiggerThanValue(0))();

  /// 'g', 'ml' or 'serving'.
  TextColumn get unit => text().check(unit.isIn(quantityUnits))();
  IntColumn get position => integer()();
  TextColumn get note => text().nullable()();
}
