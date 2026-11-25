import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/application/recipe_providers.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/recipe_ideas/recipe_ideas_screen.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
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

/// Two own recipes: a 600 kcal stew (exactly what is left) and a 200 kcal
/// salad, tagged vegetarian through a fake bundled id.
Future<AppDatabase> _db(WidgetTester tester, {bool targets = true}) async {
  final db = createTestDatabase();
  await tester.runAsync(() async {
    final foods = FoodRepository(db.foodDao);
    final recipes = RecipeRepository(db.recipeDao, db.foodDao);
    final base = await foods.createCustomFood(
      const FoodDetails(
        name: 'Base',
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: 100, proteinG: 10, carbsG: 5, fatG: 4),
      ),
    );
    Future<void> recipe(String name, double grams, {String? bundledId}) =>
        recipes.create(
          RecipeInput(
            name: name,
            servings: 1,
            bundledId: bundledId,
            ingredients: [
              IngredientInput(
                foodId: base,
                quantity: grams,
                unit: QuantityUnit.gram,
              ),
            ],
          ),
        );
    await recipe('Stew', 600);
    await recipe('Salad', 200, bundledId: 'salad');
    if (targets) {
      await ProfileRepository(db.profileDao)
          .setTargets(calories: 2000, source: TargetSource.user);
      final lunch = await foods.createCustomFood(
        const FoodDetails(
          name: 'Lunch',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 100),
        ),
      );
      await foods.logFood(
        foodId: lunch,
        quantity: 1400,
        unit: QuantityUnit.gram,
        meal: MealType.lunch,
      );
    }
  });
  return db;
}

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/ideas',
    routes: [
      GoRoute(
        path: '/ideas',
        builder: (_, _) => const RecipeIdeasScreen(meal: MealType.dinner),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bundledRecipeTagsProvider.overrideWith(
          (_) async => {
            'salad': (category: 'side', diets: ['vegetarian']),
          },
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('ranks recipes by the calories left and logs a serving', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db);

    expect(find.text('600 kcal left'), findsOneWidget);
    expect(find.textContaining('UniTools'), findsOneWidget);
    expect(find.text('Adding to Dinner'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Stew')).dy,
      lessThan(tester.getTopLeft(find.text('Salad')).dy),
    );
    expect(
      find.textContaining('Uses 100% of the 600 kcal left'),
      findsOneWidget,
    );

    // Filter by diet: only the tagged recipe is left.
    await tester.tap(find.text('Diet'));
    await _settle(tester);
    await tester.tap(find.text('Vegetarian').last);
    await _settle(tester);
    expect(find.text('Stew'), findsNothing);
    expect(find.text('Salad'), findsOneWidget);

    await tester.tap(find.text('Salad'));
    await _settle(tester);
    final label = tester.widget<Text>(find.textContaining('route ')).data!;
    final uri = Uri.parse(label.substring('route '.length));
    expect(uri.path, '/nutrition/entry/new');
    expect(uri.queryParameters['meal'], 'dinner');
    expect(uri.queryParameters['quantity'], '1.0');
    expect(uri.queryParameters['unit'], 'serving');

    await _dispose(tester, db);
  });

  testWidgets('explains when no targets are set', (tester) async {
    final db = await _db(tester, targets: false);
    await _pump(tester, db);
    expect(find.textContaining('Set a calorie target'), findsOneWidget);
    expect(find.text('Set targets'), findsOneWidget);
    expect(find.text('Stew'), findsNothing);
    await _dispose(tester, db);
  });
}
