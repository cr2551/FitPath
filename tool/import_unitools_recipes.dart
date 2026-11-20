/// Converts UniTools World Recipes v2.0.0 into FitPath's small, offline
/// catalog. Run with:
///
///   dart run tool/import_unitools_recipes.dart `unitools.json`
///
/// The source must be the CC BY-SA 4.0 `unitools-recipes-v1.json` file. This
/// importer deliberately keeps only recipes whose main ingredients can be
/// represented by the starter-food catalog. Unmapped seasonings and regional
/// ingredients are recorded as an omission rather than guessed; recipes with
/// an unsupported unit for a *mapped* ingredient are skipped. Add an
/// ingredient mapping below to expand the subset.
library;

import 'dart:convert';
import 'dart:io';

const _sourceUrl =
    'https://github.com/farcrak/unitools-recipes/blob/main/unitools-recipes-v1.json';
const _landingPage = 'https://theunitools.com/en/data';

/// UniTools ingredient id -> FitPath starter-food name.
///
/// Mappings intentionally choose a generic equivalent from the USDA-based
/// starter list, not a branded or regional product. The generated asset keeps
/// the original recipe nutrition as an estimate.
const _foods = <String, String>{
  'apple': 'Apple, raw',
  'apples': 'Apple, raw',
  'avocado': 'Avocado, raw',
  'bacon': 'Bacon, pan-fried',
  'banana': 'Banana, raw',
  'bananas': 'Banana, raw',
  'beans': 'Black beans, boiled',
  'beef': 'Ground beef 85% lean, cooked',
  'bread': 'White bread',
  'broccoli': 'Broccoli, raw',
  'butter': 'Butter, salted',
  'cabbage': 'Cabbage, raw',
  'carrot': 'Carrot, raw',
  'carrots': 'Carrot, raw',
  'cauliflower': 'Cauliflower, raw',
  'celery': 'Celery, raw',
  'cheese': 'Cheddar cheese',
  'chicken': 'Chicken breast, skinless, roasted',
  'chickpeas': 'Chickpeas, boiled',
  'coconutmilk': 'Oat milk',
  'cod': 'Cod, cooked',
  'cucumber': 'Cucumber, raw',
  'egg': 'Egg, whole, hard-boiled',
  'eggs': 'Egg, whole, hard-boiled',
  'eggwhite': 'Egg white',
  'fish': 'Tilapia, cooked',
  'garlic': 'Garlic, raw',
  'ginger': 'Garlic, raw',
  'honey': 'Honey',
  'kale': 'Kale, raw',
  'lentils': 'Lentils, boiled',
  'milk': 'Whole milk',
  'mushrooms': 'Mushrooms, white, raw',
  'oats': 'Rolled oats, dry',
  'oil': 'Olive oil',
  'oliveoil': 'Olive oil',
  'onion': 'Onion, raw',
  'onions': 'Onion, raw',
  'orange': 'Orange, raw',
  'parmesan': 'Parmesan, grated',
  'pasta': 'Pasta, cooked',
  'peanuts': 'Peanuts, dry-roasted',
  'peas': 'Green peas, boiled',
  'pineapple': 'Pineapple, raw',
  'pork': 'Pork tenderloin, roasted',
  'potato': 'Potato, baked, with skin',
  'potatoes': 'Potato, baked, with skin',
  'prawns': 'Shrimp, cooked',
  'quinoa': 'Quinoa, cooked',
  'raisins': 'Raisins',
  'rice': 'White rice, cooked',
  'salmon': 'Salmon, Atlantic, cooked',
  'shrimp': 'Shrimp, cooked',
  'soy': 'Soy sauce',
  'soysauce': 'Soy sauce',
  'spinach': 'Spinach, raw',
  'sugar': 'Sugar, white',
  'sweetpotato': 'Sweet potato, baked',
  'tempeh': 'Tempeh',
  'tofu': 'Tofu, firm',
  'tomato': 'Tomato, raw',
  'tomatoes': 'Tomato, raw',
  'tuna': 'Tuna, canned in water, drained',
  'turkey': 'Turkey breast, roasted',
  'walnuts': 'Walnuts',
  'yogurt': 'Yogurt, plain, whole milk',
  'yoghurt': 'Yogurt, plain, whole milk',
  'zucchini': 'Zucchini, raw',
};

const _liquidFoods = <String>{
  'Almond milk, unsweetened',
  'Apple juice',
  'Coffee, black',
  'Oat milk',
  'Orange juice',
  'Soy milk, unsweetened',
  'Tea, black, brewed',
  'Whole milk',
};

/// Source measures in spoons are deliberately not handled. These densities
/// cover the few source ingredients expressed in ml/l but stored per 100 g in
/// FitPath's starter catalog.
const _gramsPerMl = <String, double>{
  'oil': 0.91,
  'oliveoil': 0.91,
  'honey': 1.42,
};

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/import_unitools_recipes.dart <unitools.json> '
      '[output.json]',
    );
    exitCode = 64;
    return;
  }
  final source = File(arguments.first);
  final output = File(
    arguments.length == 2 ? arguments[1] : 'assets/data/recipes_bundled.json',
  );
  final document =
      jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final version = document['version'];
  final recipes = document['recipes'];
  if (version is! String || recipes is! List) {
    throw const FormatException('Not a UniTools recipes document');
  }

  final converted = <Map<String, Object?>>[];
  for (final raw in recipes.cast<Map<String, dynamic>>()) {
    final recipe = _convert(raw);
    if (recipe != null) converted.add(recipe);
  }
  converted.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  final catalog = <String, Object?>{
    'version': 1,
    'dataset': {
      'name': 'UniTools World Recipes',
      'version': version,
      'sourceUrl': _sourceUrl,
      'landingPage': _landingPage,
      'license': 'CC BY-SA 4.0',
      'attribution': 'UniTools — theunitools.com',
      'retrievedAt': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'changes':
          'English-only subset; ingredient ids mapped to FitPath '
          'starter foods; unsupported ingredients and units omitted; no photos.',
    },
    'recipes': converted,
  };
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(catalog));
  stdout.writeln('Wrote ${converted.length} recipes to ${output.path}.');
}

Map<String, Object?>? _convert(Map<String, dynamic> recipe) {
  final name = (recipe['name'] as Map?)?['en'];
  final nutrition = recipe['nutritionPerServing'];
  final servings = recipe['baseServings'];
  if (name is! String ||
      name.trim().isEmpty ||
      nutrition is! Map ||
      servings is! int ||
      servings < 1) {
    return null;
  }
  final sourceIngredients = (recipe['ingredients'] as List)
      .cast<Map<String, dynamic>>();
  final ingredients = <Map<String, Object?>>[];
  var omitted = 0;
  for (final raw in sourceIngredients) {
    final ingredient = _convertIngredient(raw);
    if (ingredient == null) {
      omitted++;
    } else {
      ingredients.add(ingredient);
    }
  }
  // A recipe without a useful majority of its ingredients is more misleading
  // than useful in a tracker, even when its published nutrition is retained.
  if (ingredients.length < 2 ||
      ingredients.length * 2 < sourceIngredients.length) {
    return null;
  }
  num nutrient(String key) {
    final value = nutrition[key];
    if (value is! num || value < 0) {
      throw FormatException('Bad $key in ${recipe['slug']}');
    }
    return value;
  }

  return {
    'id': recipe['slug'] as String,
    'name': name.trim(),
    'category': recipe['category'],
    'diets': recipe['diets'],
    'servings': servings,
    'kcal': nutrient('calories'),
    'proteinG': nutrient('protein'),
    'carbsG': nutrient('carbs'),
    'fatG': nutrient('fat'),
    'ingredients': ingredients,
    if (omitted > 0) 'omittedIngredientCount': omitted,
  };
}

Map<String, Object?>? _convertIngredient(Map<String, dynamic> raw) {
  final id = raw['id'];
  final quantity = raw['quantity'];
  final unit = raw['unit'];
  if (id is! String || quantity is! num || quantity <= 0 || unit is! String) {
    return null;
  }
  final foodName = _foods[id];
  if (foodName == null) return null;
  final isLiquid = _liquidFoods.contains(foodName);
  final amount = quantity.toDouble();
  final converted = switch (unit) {
    'g' when isLiquid => (amount, 'ml'),
    'g' => (amount, 'g'),
    'kg' when isLiquid => (amount * 1000.0, 'ml'),
    'kg' => (amount * 1000.0, 'g'),
    'ml' when isLiquid => (amount, 'ml'),
    'l' when isLiquid => (amount * 1000.0, 'ml'),
    'ml' when _gramsPerMl[id] != null => (amount * _gramsPerMl[id]!, 'g'),
    'l' when _gramsPerMl[id] != null => (
      amount * 1000.0 * _gramsPerMl[id]!,
      'g',
    ),
    'piece' || 'clove' => (amount, 'serving'),
    _ => null,
  };
  if (converted == null) return null;
  final note = (raw['note'] as Map?)?['en'];
  return {
    'foodName': foodName,
    'quantity': converted.$1,
    'unit': converted.$2,
    if (note is String && note.trim().isNotEmpty) 'note': note.trim(),
  };
}
