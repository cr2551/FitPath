import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/nutrients.dart';
import '../../domain/nutrition_math.dart';

/// The requested quantity unit cannot be used with the food's reference basis
/// (e.g. millilitres of a per-100 g food).
class IncompatibleQuantityUnit implements Exception {
  const IncompatibleQuantityUnit(this.basis, this.unit);

  final ReferenceBasis basis;
  final QuantityUnit unit;

  @override
  String toString() => 'Cannot log ${unit.name} of a ${basis.name} food.';
}

class FoodNotFound implements Exception {
  const FoodNotFound(this.id);

  final int id;

  @override
  String toString() => 'Food $id does not exist.';
}

/// Nutrient values for creating or updating a catalog food. Null = unknown.
class FoodDetails {
  const FoodDetails({
    required this.name,
    required this.basis,
    this.brand,
    this.nutrients = Nutrients.empty,
    this.servingSize,
    this.servingUnit,
    this.servingDescription,
  });

  final String name;
  final String? brand;
  final ReferenceBasis basis;

  /// Per [basis].
  final Nutrients nutrients;
  final double? servingSize;

  /// [QuantityUnit.gram] or [QuantityUnit.milliliter].
  final QuantityUnit? servingUnit;
  final String? servingDescription;
}

/// Food catalog (bundled, cached external and custom foods) and the diary.
///
/// Diary entries store a nutrient SNAPSHOT computed when logging, so editing
/// or removing a catalog food never rewrites history.
class FoodRepository {
  FoodRepository(this._dao, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final FoodDao _dao;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- catalog

  Future<List<FoodItem>> searchLocal(String query, {int limit = 30}) =>
      query.trim().isEmpty
      ? Future.value(const [])
      : _dao.searchActive(query, limit: limit);

  Future<FoodItem?> foodById(int id) => _dao.foodById(id);

  Future<int> createCustomFood(FoodDetails details) {
    _validate(details);
    return _dao.insertFood(_companion(details, FoodSource.custom));
  }

  /// Edits a catalog food. Past diary entries keep their snapshots.
  Future<void> updateFood(int id, FoodDetails details) {
    _validate(details);
    return _dao.updateFood(id, _companion(details, null));
  }

  /// Caches an external (Open Food Facts) food by its barcode and returns the
  /// local id. Selecting the same product again updates it instead of adding
  /// a duplicate, and re-activates it if it had been removed.
  Future<int> cacheExternalFood(String externalId, FoodDetails details) {
    _validate(details);
    return _dao.transaction(() async {
      final existing = await _dao.foodByExternalId(externalId);
      final data = _companion(
        details,
        FoodSource.openFoodFacts,
      ).copyWith(externalId: Value(externalId), isActive: const Value(true));
      if (existing == null) return _dao.insertFood(data);
      await _dao.updateFood(existing.id, data);
      return existing.id;
    });
  }

  /// Removes a food from the catalog. Foods used in the diary are only marked
  /// inactive (hidden from search) so history stays intact.
  Future<void> removeFood(int id) => _dao.transaction(() async {
    if (await _dao.isReferenced(id)) {
      await _dao.updateFood(
        id,
        const FoodItemsCompanion(isActive: Value(false)),
      );
    } else {
      await _dao.deleteFood(id);
    }
  });

  // ------------------------------------------------------------------ diary

  /// Logs [quantity] [unit] of a catalog food and returns the entry id.
  /// Throws [IncompatibleQuantityUnit] or [FoodNotFound].
  Future<int> logFood({
    required int foodId,
    required double quantity,
    required QuantityUnit unit,
    required MealType meal,
    DateTime? consumedAt,
  }) async {
    _checkQuantity(quantity);
    final food = await _dao.foodById(foodId);
    if (food == null) throw FoodNotFound(foodId);
    final at = consumedAt ?? _now();
    final snapshot = _snapshot(food, quantity, unit);
    return _dao.insertEntry(
      FoodEntriesCompanion.insert(
        foodItemId: foodId,
        quantity: quantity,
        quantityUnit: unitCode(unit),
        mealType: meal,
        consumedAt: at,
        localDate: Dates.localDateKey(at),
        nameSnapshot: food.name,
        brandSnapshot: Value(food.brand),
        kcal: Value(snapshot.kcal),
        proteinG: Value(snapshot.proteinG),
        carbsG: Value(snapshot.carbsG),
        fatG: Value(snapshot.fatG),
        fiberG: Value(snapshot.fiberG),
        sugarG: Value(snapshot.sugarG),
        sodiumMg: Value(snapshot.sodiumMg),
      ),
    );
  }

  /// Edits an entry. Changing the meal or time keeps the snapshot; changing
  /// the quantity or unit recomputes it from the food's CURRENT values.
  Future<void> updateEntry(
    int id, {
    double? quantity,
    QuantityUnit? unit,
    MealType? meal,
    DateTime? consumedAt,
  }) async {
    final entry = await _dao.entryById(id);
    if (entry == null) return;

    final newQuantity = quantity ?? entry.quantity;
    final newUnit = unit ?? unitFromCode(entry.quantityUnit);
    final amountChanged =
        newQuantity != entry.quantity ||
        unitCode(newUnit) != entry.quantityUnit;

    var data = FoodEntriesCompanion(
      mealType: meal == null ? const Value.absent() : Value(meal),
      consumedAt: consumedAt == null ? const Value.absent() : Value(consumedAt),
      localDate: consumedAt == null
          ? const Value.absent()
          : Value(Dates.localDateKey(consumedAt)),
    );

    if (amountChanged) {
      _checkQuantity(newQuantity);
      final food = await _dao.foodById(entry.foodItemId);
      if (food == null) throw FoodNotFound(entry.foodItemId);
      final s = _snapshot(food, newQuantity, newUnit);
      data = data.copyWith(
        quantity: Value(newQuantity),
        quantityUnit: Value(unitCode(newUnit)),
        kcal: Value(s.kcal),
        proteinG: Value(s.proteinG),
        carbsG: Value(s.carbsG),
        fatG: Value(s.fatG),
        fiberG: Value(s.fiberG),
        sugarG: Value(s.sugarG),
        sodiumMg: Value(s.sodiumMg),
      );
    }
    await _dao.updateEntry(id, data);
  }

  Future<FoodEntry?> entryById(int id) => _dao.entryById(id);

  Future<bool> deleteEntry(int id) => _dao.deleteEntry(id);

  /// Entries of one day, in eating order.
  Stream<List<FoodEntry>> watchDay(DateTime day) =>
      _dao.watchEntriesOn(Dates.localDateKey(day));

  Stream<DailyNutritionSummary> watchDailySummary(DateTime day) =>
      watchDay(day).map(
        (entries) => DailyNutritionSummary([
          for (final e in entries)
            LoggedNutrients(meal: e.mealType, nutrients: entryNutrients(e)),
        ]),
      );

  /// Daily totals for every logged day in [range], keyed by local date key.
  /// Days without entries are absent.
  Stream<Map<String, NutrientTotals>> watchDailyTotals(DateRange range) => _dao
      .watchEntriesBetween(
        from: range.start == null ? null : Dates.localDateKey(range.start!),
        to: Dates.localDateKey(range.end),
      )
      .map((entries) {
        final byDay = <String, List<Nutrients>>{};
        for (final e in entries) {
          (byDay[e.localDate] ??= []).add(entryNutrients(e));
        }
        return {
          for (final MapEntry(:key, :value) in byDay.entries)
            key: NutrientTotals.of(value),
        };
      });

  // ---------------------------------------------------------------- mapping

  static Nutrients entryNutrients(FoodEntry e) => Nutrients(
    kcal: e.kcal,
    proteinG: e.proteinG,
    carbsG: e.carbsG,
    fatG: e.fatG,
    fiberG: e.fiberG,
    sugarG: e.sugarG,
    sodiumMg: e.sodiumMg,
  );

  static FoodNutrition foodNutrition(FoodItem f) => FoodNutrition(
    basis: f.referenceBasis,
    nutrients: Nutrients(
      kcal: f.kcal,
      proteinG: f.proteinG,
      carbsG: f.carbsG,
      fatG: f.fatG,
      fiberG: f.fiberG,
      sugarG: f.sugarG,
      sodiumMg: f.sodiumMg,
    ),
    servingSize: f.servingSize,
    servingUnit: f.servingUnit == null ? null : unitFromCode(f.servingUnit!),
  );

  static String unitCode(QuantityUnit unit) => switch (unit) {
    QuantityUnit.gram => 'g',
    QuantityUnit.milliliter => 'ml',
    QuantityUnit.serving => 'serving',
  };

  static QuantityUnit unitFromCode(String code) => switch (code) {
    'g' => QuantityUnit.gram,
    'ml' => QuantityUnit.milliliter,
    'serving' => QuantityUnit.serving,
    _ => throw ArgumentError.value(code, 'code', 'unknown quantity unit'),
  };

  Nutrients _snapshot(FoodItem food, double quantity, QuantityUnit unit) {
    final scaled = NutritionMath.scale(foodNutrition(food), quantity, unit);
    if (scaled == null) {
      throw IncompatibleQuantityUnit(food.referenceBasis, unit);
    }
    return scaled;
  }

  FoodItemsCompanion _companion(FoodDetails d, FoodSource? source) {
    final n = d.nutrients;
    return FoodItemsCompanion(
      name: Value(d.name.trim()),
      brand: Value(d.brand?.trim().isEmpty ?? true ? null : d.brand!.trim()),
      referenceBasis: Value(d.basis),
      servingSize: Value(d.servingSize),
      servingUnit: Value(
        d.servingUnit == null ? null : unitCode(d.servingUnit!),
      ),
      servingDescription: Value(d.servingDescription),
      kcal: Value(n.kcal),
      proteinG: Value(n.proteinG),
      carbsG: Value(n.carbsG),
      fatG: Value(n.fatG),
      fiberG: Value(n.fiberG),
      sugarG: Value(n.sugarG),
      sodiumMg: Value(n.sodiumMg),
      source: source == null ? const Value.absent() : Value(source),
    );
  }

  static void _validate(FoodDetails d) {
    if (d.name.trim().isEmpty) {
      throw ArgumentError.value(d.name, 'name', 'must not be empty');
    }
    if (d.servingUnit == QuantityUnit.serving) {
      throw ArgumentError.value(d.servingUnit, 'servingUnit', 'use g or ml');
    }
    if ((d.servingSize == null) != (d.servingUnit == null)) {
      throw ArgumentError('servingSize and servingUnit go together');
    }
    if (d.basis == ReferenceBasis.perServing &&
        d.servingSize == null &&
        d.servingDescription == null) {
      throw ArgumentError('per-serving foods must say what one serving is');
    }
    final n = d.nutrients;
    for (final v in [
      n.kcal,
      n.proteinG,
      n.carbsG,
      n.fatG,
      n.fiberG,
      n.sugarG,
      n.sodiumMg,
    ]) {
      if (v != null && (v < 0 || v.isNaN)) {
        throw ArgumentError.value(v, 'nutrients', 'must not be negative');
      }
    }
  }

  static void _checkQuantity(double q) {
    if (q <= 0 || q > 100000 || q.isNaN) {
      throw ArgumentError.value(q, 'quantity', 'must be positive');
    }
  }
}
