import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

const oats = FoodDetails(
  name: 'Rolled oats',
  basis: ReferenceBasis.per100g,
  nutrients: Nutrients(kcal: 380, proteinG: 13, carbsG: 67, fatG: 7),
);

const banana = FoodDetails(
  name: 'Banana',
  basis: ReferenceBasis.per100g,
  nutrients: Nutrients(kcal: 89, proteinG: 1.1, carbsG: 23, fatG: 0.3),
  servingSize: 118,
  servingUnit: QuantityUnit.gram,
  servingDescription: '1 medium',
);

const proteinBar = FoodDetails(
  name: 'Protein bar, chocolate',
  brand: 'FitCo',
  basis: ReferenceBasis.perServing,
  nutrients: Nutrients(kcal: 210, proteinG: 20),
  servingSize: 60,
  servingUnit: QuantityUnit.gram,
  servingDescription: '1 bar (60 g)',
);

void main() {
  final today = DateTime(2026, 11, 3, 12);
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = FoodRepository(db.foodDao, clock: () => today);
  });
  tearDown(() => db.close());

  group('catalog search', () {
    setUp(() async {
      await repo.createCustomFood(oats);
      await repo.createCustomFood(banana);
      await repo.createCustomFood(proteinBar);
      await repo.createCustomFood(
        const FoodDetails(name: 'Oat milk', basis: ReferenceBasis.per100ml),
      );
      await repo.createCustomFood(
        const FoodDetails(name: '100% juice', basis: ReferenceBasis.per100ml),
      );
    });

    test('case-insensitive, name prefix first', () async {
      final r = await repo.searchLocal('OAT');
      expect(r.map((f) => f.name), ['Oat milk', 'Rolled oats']);
    });

    test('matches brand', () async {
      final r = await repo.searchLocal('fitco');
      expect(r.single.name, 'Protein bar, chocolate');
    });

    test('LIKE wildcards in the query are literal', () async {
      expect((await repo.searchLocal('%')).map((f) => f.name), ['100% juice']);
      expect(await repo.searchLocal('_'), isEmpty);
    });

    test('plural words find singular names', () async {
      await repo.createCustomFood(
        const FoodDetails(name: 'Egg, fried', basis: ReferenceBasis.per100g),
      );
      await repo.createCustomFood(
        const FoodDetails(name: 'Strawberries', basis: ReferenceBasis.per100g),
      );
      expect((await repo.searchLocal('eggs')).single.name, 'Egg, fried');
      expect((await repo.searchLocal('egg')).single.name, 'Egg, fried');
      expect(
        (await repo.searchLocal('strawberry')).single.name,
        'Strawberries',
      );
      expect((await repo.searchLocal('bananas')).single.name, 'Banana');
    });

    test('every word must match, in any order', () async {
      expect((await repo.searchLocal('milk oat')).single.name, 'Oat milk');
      expect(await repo.searchLocal('oat banana'), isEmpty);
    });

    test('empty query returns nothing', () async {
      expect(await repo.searchLocal('  '), isEmpty);
    });
  });

  group('catalog changes', () {
    test('editing a food never rewrites a logged entry (acceptance)', () async {
      final id = await repo.createCustomFood(oats);
      await repo.logFood(
        foodId: id,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
      );

      await repo.updateFood(
        id,
        const FoodDetails(
          name: 'Oats (new recipe)',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 999),
        ),
      );

      final entry = (await repo.watchDay(today).first).single;
      expect(entry.nameSnapshot, 'Rolled oats');
      expect(entry.kcal, 190);
      expect(entry.proteinG, 6.5);
    });

    test('removing a used food hides it but keeps the diary', () async {
      final used = await repo.createCustomFood(oats);
      final unused = await repo.createCustomFood(banana);
      await repo.logFood(
        foodId: used,
        quantity: 40,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
      );

      await repo.removeFood(used);
      await repo.removeFood(unused);

      expect((await repo.foodById(used))!.isActive, isFalse);
      expect(await repo.foodById(unused), isNull);
      expect(await repo.searchLocal('oats'), isEmpty);
      expect(await repo.watchDay(today).first, hasLength(1));
    });

    test('external foods are cached once and updated in place', () async {
      final first = await repo.cacheExternalFood('5000112637922', proteinBar);
      // Logged, so removing only deactivates it; caching again revives it.
      await repo.logFood(
        foodId: first,
        quantity: 1,
        unit: QuantityUnit.serving,
        meal: MealType.snack,
      );
      await repo.removeFood(first);
      final second = await repo.cacheExternalFood(
        '5000112637922',
        const FoodDetails(
          name: 'Protein bar, chocolate (v2)',
          basis: ReferenceBasis.perServing,
          nutrients: Nutrients(kcal: 200),
          servingDescription: '1 bar',
        ),
      );

      expect(second, first);
      final food = (await repo.foodById(first))!;
      expect(food.source, FoodSource.openFoodFacts);
      expect(food.kcal, 200);
      expect(food.isActive, isTrue);
    });

    test('invalid details are rejected', () {
      expect(
        () => repo.createCustomFood(
          const FoodDetails(name: ' ', basis: ReferenceBasis.per100g),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createCustomFood(
          const FoodDetails(
            name: 'Bad',
            basis: ReferenceBasis.per100g,
            nutrients: Nutrients(fatG: -1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.createCustomFood(
          const FoodDetails(name: 'Bar', basis: ReferenceBasis.perServing),
        ),
        throwsArgumentError,
      );
    });
  });

  group('logging', () {
    test(
      'snapshot uses the reference basis and unknown stays unknown',
      () async {
        final bar = await repo.createCustomFood(proteinBar);
        await repo.logFood(
          foodId: bar,
          quantity: 1,
          unit: QuantityUnit.serving,
          meal: MealType.snack,
        );

        final e = (await repo.watchDay(today).first).single;
        expect(e.kcal, 210);
        expect(e.proteinG, 20);
        expect(e.carbsG, isNull);
        expect(e.brandSnapshot, 'FitCo');
        expect(e.localDate, '2026-11-03');
        expect(e.quantityUnit, 'serving');
      },
    );

    test('incompatible units are refused', () async {
      final id = await repo.createCustomFood(oats);
      expect(
        () => repo.logFood(
          foodId: id,
          quantity: 100,
          unit: QuantityUnit.milliliter,
          meal: MealType.lunch,
        ),
        throwsA(isA<IncompatibleQuantityUnit>()),
      );
    });

    test('unknown food and invalid quantities are refused', () async {
      final id = await repo.createCustomFood(oats);
      expect(
        () => repo.logFood(
          foodId: 999,
          quantity: 1,
          unit: QuantityUnit.gram,
          meal: MealType.lunch,
        ),
        throwsA(isA<FoodNotFound>()),
      );
      expect(
        () => repo.logFood(
          foodId: id,
          quantity: 0,
          unit: QuantityUnit.gram,
          meal: MealType.lunch,
        ),
        throwsArgumentError,
      );
    });
  });

  group('editing entries', () {
    late int foodId;
    late int entryId;

    setUp(() async {
      foodId = await repo.createCustomFood(banana);
      entryId = await repo.logFood(
        foodId: foodId,
        quantity: 1,
        unit: QuantityUnit.serving,
        meal: MealType.breakfast,
      );
    });

    test('changing meal or time keeps the snapshot', () async {
      await repo.updateFood(
        foodId,
        const FoodDetails(
          name: 'Banana',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 1000),
          servingSize: 118,
          servingUnit: QuantityUnit.gram,
        ),
      );
      await repo.updateEntry(
        entryId,
        meal: MealType.snack,
        consumedAt: DateTime(2026, 11, 2, 16),
      );

      final e = (await repo.watchDay(DateTime(2026, 11, 2)).first).single;
      expect(e.mealType, MealType.snack);
      expect(e.kcal, closeTo(105.02, 1e-9));
      expect(await repo.watchDay(today).first, isEmpty);
    });

    test('changing the quantity recomputes from current values', () async {
      await repo.updateEntry(entryId, quantity: 200, unit: QuantityUnit.gram);

      final e = (await repo.watchDay(today).first).single;
      expect((e.quantity, e.quantityUnit), (200.0, 'g'));
      expect(e.kcal, closeTo(178, 1e-9));
    });

    test('delete', () async {
      expect(await repo.deleteEntry(entryId), isTrue);
      expect(await repo.watchDay(today).first, isEmpty);
    });
  });

  group('summaries', () {
    test('daily summary groups by meal and splits calories by macro', () async {
      final oatsId = await repo.createCustomFood(oats);
      final barId = await repo.createCustomFood(proteinBar);
      await repo.logFood(
        foodId: oatsId,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
      );
      await repo.logFood(
        foodId: barId,
        quantity: 1,
        unit: QuantityUnit.serving,
        meal: MealType.snack,
      );

      final s = await repo.watchDailySummary(today).first;
      expect(s.total.kcal, 400);
      expect(s.byMeal[MealType.breakfast]!.kcal, 190);
      expect(s.mealsLogged, 2);
      expect(s.total.entriesMissingMacros, 1);
      // Bar: 210 kcal, 80 from protein, 130 unknown.
      expect(s.split.unknownKcal, 130);
      expect(s.split.proteinKcal, closeTo(6.5 * 4 + 80, 1e-9));
    });

    test('daily totals over a range, keyed by day', () async {
      final id = await repo.createCustomFood(oats);
      for (final (day, grams) in [(1, 100.0), (3, 50.0), (3, 50.0)]) {
        await repo.logFood(
          foodId: id,
          quantity: grams,
          unit: QuantityUnit.gram,
          meal: MealType.breakfast,
          consumedAt: DateTime(2026, 11, day, 8),
        );
      }
      await repo.logFood(
        foodId: id,
        quantity: 100,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
        consumedAt: DateTime(2026, 9, 1),
      );

      final totals = await repo
          .watchDailyTotals(Dates.rangeFor(RangePreset.days7, today))
          .first;
      expect(totals.keys, unorderedEquals(['2026-11-01', '2026-11-03']));
      expect(totals['2026-11-03']!.kcal, 380);
      expect(totals['2026-11-03']!.entryCount, 2);
    });
  });
}
