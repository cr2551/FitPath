import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/application/food_search_service.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/data/local/recipe_repository.dart';
import 'package:fitpath/features/nutrition/data/remote/off_product.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/food_details/food_details_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<(AppDatabase, int)> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  final id = await tester.runAsync(() async {
    await db.customSelect('SELECT 1').get();
    // An Open Food Facts product with unknown protein and a 60 g serving.
    return FoodRepository(db.foodDao).cacheExternalFood(
      '42',
      FoodSearchService.detailsFor(
        const OffProduct(
          barcode: '42',
          name: 'Protein bar',
          brand: 'Acme',
          kcal: 350,
          carbsG: 40,
          fatG: 12,
          fiberG: 5,
          servingSize: 60,
          servingDescription: '1 bar (60 g)',
        ),
      ),
    );
  });
  return (db, id!);
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget screen) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/details',
    routes: [GoRoute(path: '/details', builder: (_, _) => screen)],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
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
  testWidgets('unknown values show "—", preview follows the amount', (
    tester,
  ) async {
    final (db, id) = await _db(tester);
    await _pump(
      tester,
      db,
      FoodDetailsScreen(foodId: id, meal: MealType.snack),
    );

    expect(find.text('Protein bar'), findsOneWidget);
    expect(find.text('Acme · Open Food Facts'), findsOneWidget);
    expect(
      find.textContaining('Open Food Facts (openfoodfacts.org)'),
      findsOne,
    );
    // Defaults to one serving (60 g): 210 kcal, protein unknown.
    expect(find.text('FOR 60 G'), findsOneWidget);
    expect(find.text('210 kcal', findRichText: true), findsOneWidget);
    expect(find.text('—', findRichText: true), findsOneWidget);
    expect(find.text('0 g', findRichText: true), findsNothing);
    expect(find.text('3 g', findRichText: true), findsOneWidget); // fiber

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    expect(find.text('350 kcal', findRichText: true), findsOneWidget);

    await tester.tap(find.text('serving'));
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('FOR 2 SERVINGS'), findsOneWidget);
    expect(find.text('420 kcal', findRichText: true), findsOneWidget);

    await tester.tap(find.text('ADD TO DIARY'));
    await _settle(tester);
    expect(
      find.text(
        'route /nutrition/entry/new?foodId=$id&meal=snack&quantity=2.0&unit=serving',
      ),
      findsOneWidget,
    );
    await _dispose(tester, db);
  });

  testWidgets('a recipe is logged per serving and opens the recipe editor', (
    tester,
  ) async {
    final (db, barId) = await _db(tester);
    final id = (await tester.runAsync(
      () => RecipeRepository(db.recipeDao, db.foodDao).create(
        RecipeInput(
          name: 'Bar crumble',
          servings: 2,
          ingredients: [
            IngredientInput(
              foodId: barId,
              quantity: 1,
              unit: QuantityUnit.serving,
            ),
          ],
        ),
      ),
    ))!;
    await _pump(tester, db, FoodDetailsScreen(foodId: id));
    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('serving'), findsOneWidget); // the only unit
    expect(find.text('EDIT CUSTOM FOOD'), findsNothing);
    await tester.tap(find.text('EDIT RECIPE'));
    await _settle(tester);
    expect(find.text('route /nutrition/recipe/$id'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('a missing food shows an error', (tester) async {
    final (db, _) = await _db(tester);
    await _pump(tester, db, const FoodDetailsScreen(foodId: 999));
    expect(find.text("This food doesn't exist any more."), findsOneWidget);
    await _dispose(tester, db);
  });
}
