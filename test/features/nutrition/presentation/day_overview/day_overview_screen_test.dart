import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/day_overview/day_overview_screen.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

final today = Dates.startOfDay(DateTime.now());

Future<AppDatabase> _pump(WidgetTester tester, {AppDatabase? database}) async {
  tester.view.physicalSize = const Size(360, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = database ?? createTestDatabase();
  // Open (and migrate) the database outside the fake clock.
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  final router = GoRouter(
    initialLocation: '/nutrition',
    routes: [
      GoRoute(
        path: '/nutrition',
        builder: (_, _) => DayOverviewScreen(date: today),
      ),
    ],
    // Every other route: show where we went.
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
  return db;
}

/// Lets the database (real async) answer, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  // Unmount first so stream queries are cancelled, then close.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

Future<int> _food(FoodRepository foods, String name, double kcal) =>
    foods.createCustomFood(
      FoodDetails(
        name: name,
        basis: ReferenceBasis.per100g,
        nutrients: Nutrients(kcal: kcal, proteinG: 10, carbsG: 50, fatG: 5),
      ),
    );

void main() {
  testWidgets('shows the selected day only, grouped by meal, vs targets', (
    tester,
  ) async {
    final db = createTestDatabase();
    final foods = FoodRepository(db.foodDao);
    await tester.runAsync(() async {
      final oats = await _food(foods, 'Rolled oats', 380);
      final rice = await _food(foods, 'Brown rice', 120);
      await foods.logFood(
        foodId: oats,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: today.add(const Duration(hours: 8)),
      );
      await foods.logFood(
        foodId: rice,
        quantity: 200,
        unit: QuantityUnit.gram,
        meal: MealType.lunch,
        consumedAt: today.add(const Duration(hours: 13)),
      );
      // Another day: must never be mixed into today's totals.
      await foods.logFood(
        foodId: rice,
        quantity: 1000,
        unit: QuantityUnit.gram,
        meal: MealType.lunch,
        consumedAt: Dates.addDays(today, -1).add(const Duration(hours: 12)),
      );
      await ProfileRepository(db.profileDao).setTargets(
        calories: 2000,
        proteinG: 150,
        source: TargetSource.user,
        effectiveFrom: Dates.addDays(today, -30),
      );
    });

    await _pump(tester, database: db);

    expect(find.text('Rolled oats'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);
    expect(find.text('Brown rice'), findsOneWidget);
    // 190 + 240 = 430 of 2,000.
    expect(find.text('430 / 2,000 kcal', findRichText: true), findsOneWidget);
    expect(find.text('1,570 left', findRichText: true), findsOneWidget);
    expect(find.text('22%'), findsOneWidget);
    expect(find.text('190 kcal'), findsNWidgets(2)); // row + breakfast total
    expect(find.text('Nothing logged yet'), findsNWidgets(2)); // dinner, snacks

    await _dispose(tester, db);
  });

  testWidgets('without targets it offers to set them', (tester) async {
    final db = await _pump(tester);
    expect(find.text('Set targets'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsNWidgets(4));
    await _dispose(tester, db);
  });

  testWidgets('swipe deletes with undo; without undo the entry is removed', (
    tester,
  ) async {
    final db = createTestDatabase();
    final foods = FoodRepository(db.foodDao);
    await tester.runAsync(() async {
      final oats = await _food(foods, 'Rolled oats', 380);
      await foods.logFood(
        foodId: oats,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: today.add(const Duration(hours: 8)),
      );
    });
    await _pump(tester, database: db);

    await tester.drag(find.text('Rolled oats'), const Offset(-500, 0));
    await _settle(tester);
    expect(find.text('Rolled oats'), findsNothing);
    await tester.tap(find.text('UNDO'));
    await _settle(tester);
    expect(find.text('Rolled oats'), findsOneWidget);

    await tester.drag(find.text('Rolled oats'), const Offset(-500, 0));
    await _settle(tester);
    ScaffoldMessenger.of(tester.element(find.byType(DayOverviewScreen)))
        .hideCurrentSnackBar();
    await _settle(tester);
    expect(find.text('Rolled oats'), findsNothing);
    final left = await tester.runAsync(() => foods.watchDay(today).first);
    expect(left, isEmpty);

    await _dispose(tester, db);
  });

  testWidgets('meal "+" opens search for that meal and day', (tester) async {
    final db = await _pump(tester);
    await tester.tap(find.byTooltip('Add to Dinner'));
    await _settle(tester);
    expect(
      find.text(
        'route /nutrition/search?meal=dinner&date=${Dates.localDateKey(today)}',
      ),
      findsOneWidget,
    );
    await _dispose(tester, db);
  });

  test('quantity labels', () {
    expect(quantityLabel(200, 'g'), '200 g');
    expect(quantityLabel(250, 'ml'), '250 ml');
    expect(quantityLabel(1, 'serving'), '1 serving');
    expect(quantityLabel(1.5, 'serving'), '1.5 servings');
  });
}
