import 'dart:io';

import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/seed/food_seed.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Serves assets straight from the project folder.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  final json = File(foodCatalogAsset).readAsStringSync();

  group('catalog data', () {
    final foods = parseFoodCatalog(json);

    test('has about 150 foods with unique names', () {
      expect(foods.length, greaterThanOrEqualTo(140));
      final names = foods.map((f) => f.name.value.toLowerCase()).toSet();
      expect(names, hasLength(foods.length));
    });

    test('every food declares its basis and a matching serving unit', () {
      for (final f in foods) {
        final basis = f.referenceBasis.value;
        expect(basis, isNot(ReferenceBasis.perServing), reason: f.name.value);
        final unit = f.servingUnit.value;
        if (unit != null) {
          expect(
            unit,
            basis == ReferenceBasis.per100ml ? 'ml' : 'g',
            reason: f.name.value,
          );
        }
      }
    });

    test('label calories agree with macros (Atwater, within 15%)', () {
      const alcoholic = {'Beer, regular', 'Red wine'};
      for (final f in foods) {
        if (alcoholic.contains(f.name.value)) continue;
        final kcal = f.kcal.value!;
        final fromMacros =
            f.proteinG.value! * 4 + f.carbsG.value! * 4 + f.fatG.value! * 9;
        final tolerance = kcal * 0.15 < 20 ? 20 : kcal * 0.15;
        expect(
          (fromMacros - kcal).abs(),
          lessThanOrEqualTo(tolerance),
          reason: '${f.name.value}: $kcal kcal vs $fromMacros from macros',
        );
      }
    });

    test('rejects malformed catalogs', () {
      expect(
        () => parseFoodCatalog('{"version": 2, "foods": []}'),
        throwsFormatException,
      );
      expect(
        () => parseFoodCatalog(
          '{"version": 1, "foods": [{"name": "X", "basis": "cups"}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => parseFoodCatalog(
          '{"version": 1, "foods": [{"name": "X", "basis": "per100g", '
          '"kcal": -5}]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('seeding', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('inserts every food as bundled, and only once', () async {
      await seedFoods(db, bundle: _FileBundle());
      await seedFoods(db, bundle: _FileBundle());

      final rows = await db.select(db.foodItems).get();
      expect(rows, hasLength(parseFoodCatalog(json).length));
      expect(rows.every((r) => r.source == FoodSource.bundled), isTrue);
    });

    test('seeded foods can be searched and logged offline', () async {
      await seedFoods(db, bundle: _FileBundle());
      final repo = FoodRepository(
        db.foodDao,
        clock: () => DateTime(2026, 11, 4),
      );

      final banana = (await repo.searchLocal('banana')).first;
      await repo.logFood(
        foodId: banana.id,
        quantity: 1,
        unit: QuantityUnit.serving,
        meal: MealType.breakfast,
      );

      final entry = (await repo.watchDay(DateTime(2026, 11, 4)).first).single;
      expect(entry.kcal, closeTo(89 * 1.18, 0.01));

      final milk = (await repo.searchLocal('whole milk')).first;
      expect(milk.referenceBasis, ReferenceBasis.per100ml);
    });

    test('a database created normally seeds itself', () async {
      final seeded = createTestDatabase(seedCatalogs: true);
      addTearDown(seeded.close);
      TestWidgetsFlutterBinding.ensureInitialized();

      final count = await seeded.select(seeded.foodItems).get();
      expect(count, isNotEmpty);
    });
  });
}
