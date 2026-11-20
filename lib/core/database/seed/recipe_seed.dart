import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/enums.dart';
import '../../../features/nutrition/domain/nutrition_math.dart';
import '../app_database.dart';

/// Recipe data adapted from UniTools World Recipes 2.0.0 (CC BY-SA 4.0).
const recipeCatalogAsset = 'assets/data/recipes_bundled.json';

/// A parsed recipe whose ingredients reference starter-food names. Keeping
/// names in the asset, rather than database ids, makes the catalog portable
/// across fresh installs and upgrades.
class BundledRecipe {
  const BundledRecipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.sourceVersion,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ingredients,
  });

  final String id;
  final String name;
  final int servings;
  final String sourceVersion;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<BundledRecipeIngredient> ingredients;
}

class BundledRecipeIngredient {
  const BundledRecipeIngredient({
    required this.foodName,
    required this.quantity,
    required this.unit,
    this.note,
  });

  final String foodName;
  final double quantity;
  final QuantityUnit unit;
  final String? note;
}

/// Seeds bundled recipes after the starter food catalog is available. It is
/// intentionally idempotent: a stable UniTools slug is stored in
/// [Recipes.bundledId], so reopening the database or upgrading an install
/// never creates duplicates.
Future<void> seedRecipes(AppDatabase db, {AssetBundle? bundle}) async {
  final json = await (bundle ?? rootBundle).loadString(recipeCatalogAsset);
  final recipes = parseRecipeCatalog(json);
  final foods = await db.select(db.foodItems).get();
  final foodByName = {
    for (final food in foods) food.name.trim().toLowerCase(): food,
  };

  for (final recipe in recipes) {
    if (await db.recipeDao.recipeByBundledId(recipe.id) != null) continue;
    final ingredients = <(BundledRecipeIngredient, int)>[];
    for (final ingredient in recipe.ingredients) {
      final food = foodByName[ingredient.foodName.toLowerCase()];
      if (food == null) {
        throw FormatException(
          'Bundled recipe ${recipe.id} refers to missing food '
          '${ingredient.foodName}',
        );
      }
      ingredients.add((ingredient, food.id));
    }

    await db.transaction(() async {
      final foodId = await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              name: recipe.name,
              referenceBasis: ReferenceBasis.perServing,
              source: FoodSource.recipe,
              servingDescription: const Value('1 serving'),
              kcal: Value(recipe.kcal),
              proteinG: Value(recipe.proteinG),
              carbsG: Value(recipe.carbsG),
              fatG: Value(recipe.fatG),
            ),
          );
      final recipeId = await db
          .into(db.recipes)
          .insert(
            RecipesCompanion.insert(
              foodItemId: foodId,
              servings: recipe.servings,
              bundledId: Value(recipe.id),
              sourceVersion: Value(recipe.sourceVersion),
            ),
          );
      await db.batch((batch) {
        batch.insertAll(db.recipeIngredients, [
          for (final (position, entry) in ingredients.indexed)
            RecipeIngredientsCompanion.insert(
              recipeId: recipeId,
              foodItemId: entry.$2,
              quantity: entry.$1.quantity,
              unit: switch (entry.$1.unit) {
                QuantityUnit.gram => 'g',
                QuantityUnit.milliliter => 'ml',
                QuantityUnit.serving => 'serving',
              },
              position: position,
              note: Value(entry.$1.note),
            ),
        ]);
      });
    });
  }
}

/// Validates the small, versioned JSON format before any database write.
List<BundledRecipe> parseRecipeCatalog(String json) {
  final document = jsonDecode(json);
  if (document is! Map<String, dynamic> || document['version'] != 1) {
    throw const FormatException('Unsupported bundled recipe catalog version');
  }
  final version = document['dataset'] is Map
      ? (document['dataset'] as Map)['version']
      : null;
  if (version is! String || version.isEmpty) {
    throw const FormatException('Missing recipe dataset version');
  }
  final rows = document['recipes'];
  if (rows is! List) throw const FormatException('Missing "recipes" list');
  final ids = <String>{};
  return [
    for (final row in rows)
      _parseRecipe(row as Map<String, dynamic>, version, ids),
  ];
}

BundledRecipe _parseRecipe(
  Map<String, dynamic> row,
  String sourceVersion,
  Set<String> ids,
) {
  String string(String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Recipe missing $key: $row');
    }
    return value.trim();
  }

  double number(String key) {
    final value = row[key];
    if (value is! num || !value.isFinite || value < 0) {
      throw FormatException('Recipe has invalid $key: $row');
    }
    return value.toDouble();
  }

  final id = string('id');
  if (!ids.add(id)) throw FormatException('Duplicate bundled recipe id: $id');
  final servings = row['servings'];
  if (servings is! int || servings < 1) {
    throw FormatException('Recipe $id has invalid servings');
  }
  final ingredients = row['ingredients'];
  if (ingredients is! List || ingredients.isEmpty) {
    throw FormatException('Recipe $id has no ingredients');
  }
  return BundledRecipe(
    id: id,
    name: string('name'),
    servings: servings,
    sourceVersion: sourceVersion,
    kcal: number('kcal'),
    proteinG: number('proteinG'),
    carbsG: number('carbsG'),
    fatG: number('fatG'),
    ingredients: [
      for (final ingredient in ingredients)
        _parseIngredient(ingredient as Map<String, dynamic>, id),
    ],
  );
}

BundledRecipeIngredient _parseIngredient(
  Map<String, dynamic> row,
  String recipeId,
) {
  final foodName = row['foodName'];
  final quantity = row['quantity'];
  final unit = row['unit'];
  if (foodName is! String ||
      foodName.trim().isEmpty ||
      quantity is! num ||
      !quantity.isFinite ||
      quantity <= 0 ||
      unit is! String) {
    throw FormatException('Invalid ingredient in $recipeId');
  }
  final parsedUnit = switch (unit) {
    'g' => QuantityUnit.gram,
    'ml' => QuantityUnit.milliliter,
    'serving' => QuantityUnit.serving,
    _ => throw FormatException('Invalid ingredient unit "$unit" in $recipeId'),
  };
  final note = row['note'];
  if (note != null && note is! String) {
    throw FormatException('Invalid ingredient note in $recipeId');
  }
  return BundledRecipeIngredient(
    foodName: foodName.trim(),
    quantity: quantity.toDouble(),
    unit: parsedUnit,
    note: note as String?,
  );
}
