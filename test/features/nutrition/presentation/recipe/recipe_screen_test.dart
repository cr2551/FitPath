import 'package:dio/dio.dart';
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/application/food_search_service.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/data/remote/open_food_facts_client.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/recipe/recipe_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _Foods {
  late int oats, milk, butter;
}

Future<(AppDatabase, _Foods)> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  final ids = _Foods();
  await tester.runAsync(() async {
    final foods = FoodRepository(db.foodDao);
    ids.oats = await foods.createCustomFood(
      const FoodDetails(
        name: 'Rolled oats',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 380, proteinG: 13, carbsG: 67, fatG: 7),
      ),
    );
    ids.milk = await foods.createCustomFood(
      const FoodDetails(
        name: 'Milk',
        basis: ReferenceBasis.per100ml,
        nutrients: Nutrients(kcal: 64, proteinG: 3.4, carbsG: 4.8, fatG: 3.6),
      ),
    );
    // No protein data.
    ids.butter = await foods.createCustomFood(
      const FoodDetails(
        name: 'Butter',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 720, carbsG: 0, fatG: 80),
      ),
    );
  });
  return (db, ids);
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  RecipeScreen screen,
) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/recipe'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: '/recipe', builder: (_, _) => screen),
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        foodSearchServiceProvider.overrideWithValue(
          FoodSearchService(
            local: FoodRepository(db.foodDao),
            remote: OpenFoodFactsClient(Dio()),
            isOnline: () async => false,
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

Finder _input(String label) => find.widgetWithText(TextField, label);

Future<void> _addIngredient(
  WidgetTester tester,
  String query,
  String name,
) async {
  await tester.tap(find.text('Add ingredient'));
  await _settle(tester);
  expect(find.text('Choose an ingredient'), findsOneWidget);
  await tester.enterText(find.byType(TextField), query);
  await _settle(tester);
  await tester.tap(find.text(name));
  await _settle(tester);
}

FilledButton _saveButton(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

RecipeRepository _recipes(AppDatabase db) =>
    RecipeRepository(db.recipeDao, db.foodDao);

void main() {
  testWidgets('builds a recipe from searched ingredients with live nutrition', (
    tester,
  ) async {
    final (db, ids) = await _db(tester);
    // An existing recipe must not be offered as an ingredient.
    await tester.runAsync(
      () => _recipes(db).create(
        RecipeInput(
          name: 'Oat bars',
          servings: 4,
          ingredients: [
            IngredientInput(
              foodId: ids.oats,
              quantity: 200,
              unit: QuantityUnit.gram,
            ),
          ],
        ),
      ),
    );
    await _pump(tester, db, const RecipeScreen());
    expect(find.text('New recipe'), findsOneWidget);
    expect(find.text('No ingredients yet. Add at least one.'), findsOneWidget);
    expect(_saveButton(tester, 'CREATE RECIPE').onPressed, isNull);

    await tester.enterText(_input('Name'), 'Porridge');
    await tester.enterText(_input('Servings'), '2');
    await tester.pump();

    await tester.tap(find.text('Add ingredient'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'oat');
    await _settle(tester);
    expect(find.text('Rolled oats'), findsOneWidget);
    expect(find.text('Oat bars'), findsNothing);
    await tester.tap(find.text('Rolled oats'));
    await _settle(tester);

    // Defaults to 100 g of a per-100 g food.
    expect(find.text('380 kcal'), findsOneWidget);
    await tester.enterText(_input('Amount'), '80');
    await tester.pump();
    expect(find.text('304 kcal'), findsOneWidget);

    await _addIngredient(tester, 'milk', 'Milk');
    // Only the units valid for a per-100 ml food.
    expect(find.text('ml'), findsOneWidget);
    await tester.enterText(_input('Amount').at(1), '250');
    await tester.pump();

    // (304 + 160) / 2 servings.
    expect(find.text('PER SERVING'), findsOneWidget);
    expect(find.text('232 kcal'), findsOneWidget);

    await tester.tap(find.text('CREATE RECIPE'));
    await _settle(tester);
    expect(find.text('open'), findsOneWidget); // left the screen

    final found = (await tester.runAsync(
      () => FoodRepository(db.foodDao).searchLocal('porridge'),
    ))!;
    final food = found.single;
    expect(food.source, FoodSource.recipe);
    expect(food.referenceBasis, ReferenceBasis.perServing);
    expect(food.kcal, closeTo(232, 0.001));
    final saved = (await tester.runAsync(
      () => _recipes(db).byFoodId(food.id),
    ))!;
    expect(saved.recipe.servings, 2);
    expect(
      [for (final i in saved.ingredients) i.food.id],
      [ids.oats, ids.milk],
    );
    expect(saved.ingredients.first.ingredient.quantity, 80);
    await _dispose(tester, db);
  });

  testWidgets('validates servings and amounts', (tester) async {
    final (db, _) = await _db(tester);
    await _pump(tester, db, const RecipeScreen());
    await tester.enterText(_input('Name'), 'Toast');
    await tester.enterText(_input('Servings'), '0');
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 50'), findsOneWidget);

    await tester.enterText(_input('Servings'), '51');
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 50'), findsOneWidget);
    await tester.enterText(_input('Servings'), '1');
    await tester.pump();

    await _addIngredient(tester, 'butt', 'Butter');
    expect(_saveButton(tester, 'CREATE RECIPE').onPressed, isNotNull);
    await tester.enterText(_input('Amount'), '0');
    await tester.pump();
    expect(find.text('Must be more than 0'), findsOneWidget);
    expect(_saveButton(tester, 'CREATE RECIPE').onPressed, isNull);
    await _dispose(tester, db);
  });

  testWidgets('unknown values stay unknown and are explained', (tester) async {
    final (db, _) = await _db(tester);
    await _pump(tester, db, const RecipeScreen());
    await _addIngredient(tester, 'oat', 'Rolled oats');
    await _addIngredient(tester, 'butt', 'Butter');
    expect(find.text('1 ingredient has no protein data'), findsOneWidget);
    // Protein per serving is unknown, not the oats' protein alone.
    expect(find.text('13 g'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('editing reorders and keeps logged entries; delete hides it', (
    tester,
  ) async {
    final (db, ids) = await _db(tester);
    final foods = FoodRepository(db.foodDao);
    late int id;
    await tester.runAsync(() async {
      id = await _recipes(db).create(
        RecipeInput(
          name: 'Porridge',
          servings: 2,
          ingredients: [
            IngredientInput(
              foodId: ids.oats,
              quantity: 80,
              unit: QuantityUnit.gram,
            ),
            IngredientInput(
              foodId: ids.milk,
              quantity: 250,
              unit: QuantityUnit.milliliter,
            ),
          ],
        ),
      );
      // Logged per serving, like any per-serving food.
      await foods.logFood(
        foodId: id,
        quantity: 1,
        unit: QuantityUnit.serving,
        meal: MealType.breakfast,
      );
    });

    await _pump(tester, db, RecipeScreen(foodId: id));
    expect(_input('Porridge'), findsOneWidget);
    expect(_input('250'), findsOneWidget);

    await tester.tap(find.byTooltip('Ingredient options').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();
    await tester.enterText(_input('Servings'), '4');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await _settle(tester);

    final saved = (await tester.runAsync(() => _recipes(db).byFoodId(id)))!;
    expect(
      [for (final i in saved.ingredients) i.food.id],
      [ids.milk, ids.oats],
    );
    expect(saved.food.kcal, closeTo(116, 0.001));
    final entries = (await tester.runAsync(
      () => foods.watchDay(DateTime.now()).first,
    ))!;
    expect(entries.single.kcal, closeTo(232, 0.001)); // snapshot unchanged

    await _pump(tester, db, RecipeScreen(foodId: id));
    await tester.tap(find.text('Delete recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await _settle(tester);
    expect(await tester.runAsync(() => foods.searchLocal('porridge')), isEmpty);
    expect((await tester.runAsync(() => foods.foodById(id)))!.isActive, false);
    await _dispose(tester, db);
  });

  testWidgets('a missing recipe shows an error', (tester) async {
    final (db, _) = await _db(tester);
    await _pump(tester, db, const RecipeScreen(foodId: 42));
    expect(find.text('This recipe does not exist any more.'), findsOneWidget);
    await _dispose(tester, db);
  });
}
