import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/progress/presentation/nutrition/daily_calories_chart.dart';
import 'package:fitpath/features/progress/presentation/nutrition/nutrition_progress_view.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

NutrientTotals _t(double kcal, double p, double c, double f) => NutrientTotals(
  kcal: kcal,
  proteinG: p,
  carbsG: c,
  fatG: f,
  entryCount: 1,
  entriesMissingKcal: 0,
  entriesMissingMacros: 0,
);

NutritionTarget _target(int id, int kcal, String from) => NutritionTarget(
  id: id,
  calories: kcal,
  effectiveFrom: from,
  source: TargetSource.user,
  createdAt: DateTime(2026),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('mapping', () {
    final history = [
      _target(1, 2000, '2026-10-01'),
      _target(2, 2200, '2026-11-02'),
    ];
    final range = DateRange(
      start: DateTime(2026, 10, 28),
      end: DateTime(2026, 11, 4),
    );

    test('target history resolves per day', () {
      expect(targetOn(history, '2026-09-30'), isNull);
      expect(targetOn(history, '2026-10-15')!.calories, 2000);
      expect(targetOn(history, '2026-11-02')!.calories, 2200);
    });

    test('bars per day, historical targets, averages and rows', () {
      final d = nutritionProgressData(
        {
          '2026-10-30': _t(1800, 100, 200, 60),
          '2026-11-03': _t(2400, 150, 250, 80),
        },
        history,
        range,
      );
      expect(d.bars, hasLength(7)); // 28 Oct - 3 Nov
      final oct30 = d.bars[2];
      expect(oct30.proteinKcal, 400);
      expect(oct30.carbsKcal, 800);
      expect(oct30.fatKcal, 540);
      expect(oct30.unknownKcal, 60);
      expect(oct30.targetKcal, 2000);
      expect(d.bars.last.targetKcal, 2200);
      expect(d.bars[0].total, 0); // not logged
      expect(d.firstLabel, '28 Oct');
      expect(d.lastLabel, '3 Nov');

      expect(d.stats.map((s) => s.value), ['2,100', '2 of 7']);
      expect(d.macroStats.map((s) => s.value), ['125', '225', '70']);
      expect(d.rows.map((r) => r.date), ['Tue 3 Nov', 'Fri 30 Oct']);
      expect(d.rows.first.kcal, '2,400 / 2,200');
      expect(d.rows.first.overTarget, isTrue);
      expect(d.rows.last.overTarget, isFalse);
    });

    test('nothing logged', () {
      expect(nutritionProgressData({}, history, range).rows, isEmpty);
    });
  });

  testWidgets('shows logged days and opens a day', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() async {
      await ProfileRepository(db.profileDao).setTargets(
        calories: 2000,
        source: TargetSource.user,
        effectiveFrom: Dates.addDays(DateTime.now(), -40),
      );
      final foods = FoodRepository(db.foodDao);
      final id = await foods.createCustomFood(
        const FoodDetails(
          name: 'Rice',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 130, proteinG: 3, carbsG: 28, fatG: 0),
        ),
      );
      await foods.logFood(
        foodId: id,
        quantity: 500,
        unit: QuantityUnit.gram,
        meal: MealType.lunch,
      );
    });
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(children: const [NutritionProgressView()]),
          ),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _settle(tester);

    expect(find.byType(DailyCaloriesChart), findsOneWidget);
    expect(find.text('650 / 2,000'), findsOneWidget);
    expect(find.text('1 of 30'), findsOneWidget);

    await tester.tap(find.text('650 / 2,000'));
    await tester.pumpAndSettle();
    expect(
      find.text('route /nutrition?date=${Dates.localDateKey(DateTime.now())}'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
