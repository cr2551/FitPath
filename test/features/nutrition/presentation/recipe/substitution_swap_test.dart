import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/database/seed/substitution_seed.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/application/recipe_providers.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/recipe/recipe_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

FoodDetails _food(String name, double kcal, {double? proteinG}) => FoodDetails(
  name: name,
  basis: ReferenceBasis.per100g,
  nutrients: Nutrients(
    kcal: kcal,
    proteinG: proteinG,
    carbsG: kcal / 4,
    fatG: 0,
  ),
);

/// A 2-serving recipe with 100 g sugar (400 kcal) and 100 g flour (360
/// kcal); honey (304 kcal / 100 g, no protein data) replaces sugar 1.25 : 1.
Future<(AppDatabase, int)> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  final id = await tester.runAsync(() async {
    final foods = FoodRepository(db.foodDao);
    final sugar = await foods.createCustomFood(
      _food('Sugar, white', 400, proteinG: 0),
    );
    await foods.createCustomFood(_food('Honey', 304));
    final flour = await foods.createCustomFood(
      _food('Flour', 360, proteinG: 10),
    );
    return RecipeRepository(db.recipeDao, db.foodDao).create(
      RecipeInput(
        name: 'Cake',
        servings: 2,
        ingredients: [
          IngredientInput(
            foodId: sugar,
            quantity: 100,
            unit: QuantityUnit.gram,
          ),
          IngredientInput(
            foodId: flour,
            quantity: 100,
            unit: QuantityUnit.gram,
          ),
        ],
      ),
    );
  });
  return (db, id!);
}

Future<void> _pump(WidgetTester tester, AppDatabase db, int id) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        substitutionsProvider.overrideWith(
          (_) async => const [
            BundledSubstitution(
              fromFoodName: 'Sugar, white',
              toFoodName: 'Honey',
              ratio: 1.25,
              note: 'Reduce the liquid.',
            ),
          ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: RecipeScreen(foodId: id),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _openMenu(WidgetTester tester, int index) async {
  await tester.tap(find.byTooltip('Ingredient options').at(index));
  await _settle(tester);
}

Future<void> _swapToHoney(WidgetTester tester) async {
  await _openMenu(tester, 0);
  await tester.tap(find.text('Swap'));
  await _settle(tester);
  await tester.tap(find.text('Honey'));
  await _settle(tester);
}

void main() {
  testWidgets('swaps an ingredient by exactly the shown difference', (
    tester,
  ) async {
    final (db, id) = await _db(tester);
    await _pump(tester, db, id);

    // (400 + 360) / 2.
    expect(find.text('380 kcal'), findsOneWidget);

    // Only sugar has a substitution.
    await _openMenu(tester, 1);
    expect(find.text('Swap'), findsNothing);
    await tester.tap(find.text('Move up'));
    await _settle(tester);
    // Flour is first now; put sugar back on top.
    await _openMenu(tester, 0);
    await tester.tap(find.text('Move down'));
    await _settle(tester);

    await _openMenu(tester, 0);
    await tester.tap(find.text('Swap'));
    await _settle(tester);
    expect(find.text('Swap Sugar, white'), findsOneWidget);
    expect(
      find.textContaining('Wikibooks Cookbook contributors, CC BY-SA 4.0'),
      findsOneWidget,
    );
    // 125 g honey = 380 kcal: (380 - 400) / 2 = -10 per serving.
    final option = tester.widget<Text>(
      find.textContaining('125 g (1.25 × the amount)'),
    );
    expect(option.data, contains('−10 kcal'));
    expect(option.data, contains('protein unknown'));
    expect(option.data, contains('Reduce the liquid.'));

    await tester.tap(find.text('Honey'));
    await _settle(tester);
    // 380 - 10.
    expect(find.text('370 kcal'), findsOneWidget);
    expect(find.text('Swapped Sugar, white for Honey'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await _settle(tester);
    expect(find.text('Sugar, white'), findsOneWidget);
    expect(find.text('380 kcal'), findsOneWidget);

    // Swap again and save: the stored recipe uses 125 g honey.
    await _swapToHoney(tester);
    await tester.tap(find.text('SAVE'));
    await _settle(tester);
    final saved = (await tester.runAsync(
      () => RecipeRepository(db.recipeDao, db.foodDao).byFoodId(id),
    ))!;
    expect(saved.ingredients.first.food.name, 'Honey');
    expect(saved.ingredients.first.ingredient.quantity, 125);
    expect(saved.food.kcal, closeTo(370, 1e-9));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(db.close);
  });
}
