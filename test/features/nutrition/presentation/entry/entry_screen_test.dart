import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/nutrition/presentation/entry/entry_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

final day = DateTime(2026, 11, 2);

class _Harness {
  _Harness(this.db) : foods = FoodRepository(db.foodDao);

  final AppDatabase db;
  final FoodRepository foods;
}

/// Lets the database (real async) answer, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<_Harness> _setUp(WidgetTester tester) async {
  final h = _Harness(createTestDatabase());
  await tester.runAsync(() => h.db.customSelect('SELECT 1').get());
  return h;
}

Future<void> _pump(WidgetTester tester, _Harness h, EntryScreen screen) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/entry',
    routes: [GoRoute(path: '/entry', builder: (_, _) => screen)],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(h.db)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(h.db.close);
}

Future<int> _oats(_Harness h) async => (await h.foods.createCustomFood(
  const FoodDetails(
    name: 'Rolled oats',
    basis: ReferenceBasis.per100g,
    nutrients: Nutrients(kcal: 380, proteinG: 13, carbsG: 67, fatG: 7),
    servingSize: 40,
    servingUnit: QuantityUnit.gram,
  ),
));

Future<List<FoodEntry>> _entries(WidgetTester tester, _Harness h) async =>
    (await tester.runAsync(() => h.foods.watchDay(day).first))!;

void main() {
  testWidgets('logs a new entry with route defaults and opens that day', (
    tester,
  ) async {
    final h = await _setUp(tester);
    final oats = (await tester.runAsync(() => _oats(h)))!;
    await _pump(
      tester,
      h,
      EntryScreen(foodId: oats, meal: MealType.lunch, date: day),
    );

    expect(find.text('Rolled oats'), findsOneWidget);
    // Defaults to one serving size in grams: 40 g = 152 kcal.
    expect(find.widgetWithText(TextField, '40'), findsOneWidget);
    expect(find.text('152 kcal', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), '50');
    await tester.pump();
    expect(find.text('190 kcal', findRichText: true), findsOneWidget);

    await tester.tap(find.text('LOG FOOD'));
    await _settle(tester);

    final entries = await _entries(tester, h);
    expect(entries, hasLength(1));
    expect(entries.single.quantity, 50);
    expect(entries.single.mealType, MealType.lunch);
    expect(entries.single.kcal, closeTo(190, 0.001));
    expect(find.text('route /nutrition?date=2026-11-02'), findsOneWidget);
    await _dispose(tester, h);
  });

  testWidgets('a prefilled amount from food details is used when valid', (
    tester,
  ) async {
    final h = await _setUp(tester);
    final oats = (await tester.runAsync(() => _oats(h)))!;
    await _pump(
      tester,
      h,
      EntryScreen(foodId: oats, date: day, quantity: 60, unit: 'g'),
    );
    expect(find.widgetWithText(TextField, '60'), findsOneWidget);
    expect(find.text('228 kcal', findRichText: true), findsOneWidget);
    await _dispose(tester, h);

    // Millilitres of a per-100 g food are not valid: fall back to defaults.
    final h2 = await _setUp(tester);
    final oats2 = (await tester.runAsync(() => _oats(h2)))!;
    await _pump(
      tester,
      h2,
      EntryScreen(foodId: oats2, date: day, quantity: 60, unit: 'ml'),
    );
    expect(find.widgetWithText(TextField, '40'), findsOneWidget);
    await _dispose(tester, h2);
  });

  testWidgets('switching units converts the amount without drifting', (
    tester,
  ) async {
    final h = await _setUp(tester);
    final egg = (await tester.runAsync(
      () => h.foods.createCustomFood(
        const FoodDetails(
          name: 'Egg',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 150),
          servingSize: 46,
          servingUnit: QuantityUnit.gram,
          servingDescription: '1 large',
        ),
      ),
    ))!;
    await _pump(tester, h, EntryScreen(foodId: egg, date: day));
    Future<void> unit(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(find.widgetWithText(TextField, '46'), findsOneWidget);
    await unit('serving');
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2.3');
    await tester.pump();
    await unit('g');
    expect(find.widgetWithText(TextField, '105.8'), findsOneWidget);
    await unit('serving');
    expect(find.widgetWithText(TextField, '2.3'), findsOneWidget);

    // 100 g is 2.17 servings when shown, but exactly 100 g again on return.
    await unit('g');
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await unit('serving');
      expect(find.widgetWithText(TextField, '2.17'), findsOneWidget);
      await unit('g');
      expect(find.widgetWithText(TextField, '100'), findsOneWidget);
    }
    expect(find.text('150 kcal', findRichText: true), findsOneWidget);

    await unit('serving');
    await tester.tap(find.text('LOG FOOD'));
    await _settle(tester);
    final entry = (await _entries(tester, h)).single;
    expect(entry.quantityUnit, 'serving');
    expect(entry.kcal, closeTo(150, 0.001));
    await _dispose(tester, h);
  });

  testWidgets('rejects zero and absurd amounts', (tester) async {
    final h = await _setUp(tester);
    final oats = (await tester.runAsync(() => _oats(h)))!;
    await _pump(tester, h, EntryScreen(foodId: oats, date: day));

    FilledButton save() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'LOG FOOD'),
    );

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(find.text('Must be more than 0'), findsOneWidget);
    expect(save().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '6000');
    await tester.pump();
    expect(find.text('At most 5000 g'), findsOneWidget);
    expect(save().onPressed, isNull);
    await _dispose(tester, h);
  });

  testWidgets('editing the meal keeps the snapshot; the amount recomputes', (
    tester,
  ) async {
    final h = await _setUp(tester);
    late int entryId;
    await tester.runAsync(() async {
      final oats = await _oats(h);
      entryId = await h.foods.logFood(
        foodId: oats,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: day.add(const Duration(hours: 8)),
      );
      // The catalog food changes after logging.
      await h.foods.updateFood(
        oats,
        const FoodDetails(
          name: 'Rolled oats',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 400, proteinG: 13, carbsG: 67, fatG: 7),
        ),
      );
    });

    await _pump(tester, h, EntryScreen(entryId: entryId));
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.text('190 kcal', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Dinner'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await _settle(tester);
    var entry = (await _entries(tester, h)).single;
    expect(entry.mealType, MealType.dinner);
    expect(entry.kcal, closeTo(190, 0.001)); // snapshot kept

    await _pump(tester, h, EntryScreen(entryId: entryId));
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    expect(find.text('400 kcal', findRichText: true), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await _settle(tester);
    entry = (await _entries(tester, h)).single;
    expect(entry.kcal, closeTo(400, 0.001)); // current catalog values
    await _dispose(tester, h);
  });

  testWidgets('delete asks for confirmation', (tester) async {
    final h = await _setUp(tester);
    late int entryId;
    await tester.runAsync(() async {
      entryId = await h.foods.logFood(
        foodId: await _oats(h),
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: day.add(const Duration(hours: 8)),
      );
    });
    await _pump(tester, h, EntryScreen(entryId: entryId));

    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await _entries(tester, h), hasLength(1));

    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await _settle(tester);
    expect(await _entries(tester, h), isEmpty);
    expect(find.text('route /nutrition?date=2026-11-02'), findsOneWidget);
    await _dispose(tester, h);
  });

  testWidgets('a missing food shows an error', (tester) async {
    final h = await _setUp(tester);
    await _pump(tester, h, const EntryScreen(foodId: 999));
    expect(find.text("This food doesn't exist any more."), findsOneWidget);
    await _dispose(tester, h);
  });
}
