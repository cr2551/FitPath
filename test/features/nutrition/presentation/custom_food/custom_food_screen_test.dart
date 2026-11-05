import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/custom_food/custom_food_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<AppDatabase> _db(WidgetTester tester) async {
  final db = createTestDatabase();
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  return db;
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  CustomFoodScreen screen,
) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/food',
    routes: [GoRoute(path: '/food', builder: (_, _) => screen)],
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

Finder _input(String label) => find.widgetWithText(TextField, label);

Future<List<FoodItem>> _search(WidgetTester tester, AppDatabase db, String q) =>
    tester
        .runAsync(() => FoodRepository(db.foodDao).searchLocal(q))
        .then((v) => v!);

void main() {
  testWidgets('creates a searchable custom food; blank stays unknown', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db, const CustomFoodScreen());

    FilledButton create() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'CREATE FOOD'),
    );
    expect(create().onPressed, isNull); // name required

    await tester.enterText(_input('Name'), 'Mixed salad');
    await tester.tap(find.text('Serving'));
    await tester.pump();
    expect(find.text('Describe one serving or give its size'), findsOneWidget);
    await tester.enterText(_input('Description'), '1 bowl');
    await tester.enterText(_input('Calories'), '180');
    await tester.enterText(_input('Fat'), '14,5');
    await tester.pump();
    await tester.tap(find.text('CREATE FOOD'));
    await _settle(tester);

    final found = await _search(tester, db, 'salad');
    expect(found, hasLength(1));
    final food = found.single;
    expect(food.source, FoodSource.custom);
    expect(food.referenceBasis, ReferenceBasis.perServing);
    expect(food.servingDescription, '1 bowl');
    expect(food.kcal, 180);
    expect(food.fatG, 14.5);
    expect(food.proteinG, isNull); // blank = unknown, not 0
    await _dispose(tester, db);
  });

  testWidgets('units are visible before typing', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, const CustomFoodScreen());
    expect(find.text('kcal'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('rejects negative and non-numeric values', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, const CustomFoodScreen());
    await tester.enterText(_input('Name'), 'Thing');
    await tester.enterText(_input('Protein'), '-1');
    await tester.enterText(_input('Carbs'), 'abc');
    await tester.pump();
    expect(find.text('Must not be negative'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'CREATE FOOD'),
          )
          .onPressed,
      isNull,
    );
    await _dispose(tester, db);
  });

  testWidgets('editing keeps logged entries; delete hides a used food', (
    tester,
  ) async {
    final db = await _db(tester);
    final foods = FoodRepository(db.foodDao);
    late int id;
    await tester.runAsync(() async {
      id = await foods.createCustomFood(
        const FoodDetails(
          name: 'Granola',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 450),
        ),
      );
      await foods.logFood(
        foodId: id,
        quantity: 100,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
      );
    });

    await _pump(tester, db, CustomFoodScreen(foodId: id));
    expect(_input('450'), findsOneWidget);
    await tester.enterText(_input('Calories'), '500');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await _settle(tester);

    final entries = (await tester.runAsync(
      () => foods.watchDay(DateTime.now()).first,
    ))!;
    expect(entries.single.kcal, 450); // snapshot unchanged
    expect((await _search(tester, db, 'granola')).single.kcal, 500);

    await _pump(tester, db, CustomFoodScreen(foodId: id));
    await tester.tap(find.text('Delete food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await _settle(tester);
    expect(await _search(tester, db, 'granola'), isEmpty);
    final kept = await tester.runAsync(() => foods.foodById(id));
    expect(kept!.isActive, isFalse); // referenced, so only deactivated
    await _dispose(tester, db);
  });

  testWidgets('a non-custom or missing food cannot be edited', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db, const CustomFoodScreen(foodId: 42));
    expect(
      find.text('This custom food does not exist any more.'),
      findsOneWidget,
    );
    await _dispose(tester, db);
  });
}
