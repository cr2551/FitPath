import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_tables.dart';

part 'food_dao.g.dart';

/// Food catalog and diary queries.
@DriftAccessor(tables: [FoodItems, FoodEntries])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);

  // ---------------------------------------------------------------- catalog

  /// Active foods whose name or brand contains [query] (case-insensitive),
  /// names starting with the query first.
  Future<List<FoodItem>> searchActive(String query, {int limit = 30}) {
    final pattern = '%${_escapeLike(query.trim().toLowerCase())}%';
    final prefix = '${_escapeLike(query.trim().toLowerCase())}%';
    final nameLower = foodItems.name.lower();
    final brandLower = foodItems.brand.lower();
    return (select(foodItems)
          ..where(
            (f) =>
                f.isActive.equals(true) &
                (nameLower.like(pattern, escapeChar: r'\') |
                    brandLower.like(pattern, escapeChar: r'\')),
          )
          ..orderBy([
            (f) => OrderingTerm.desc(nameLower.like(prefix, escapeChar: r'\')),
            (f) => OrderingTerm.asc(nameLower),
          ])
          ..limit(limit))
        .get();
  }

  Future<FoodItem?> foodById(int id) =>
      (select(foodItems)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<FoodItem?> foodByExternalId(String externalId) => (select(
    foodItems,
  )..where((f) => f.externalId.equals(externalId))).getSingleOrNull();

  Future<int> insertFood(FoodItemsCompanion food) =>
      into(foodItems).insert(food);

  Future<void> updateFood(int id, FoodItemsCompanion food) =>
      (update(foodItems)..where((f) => f.id.equals(id))).write(
        food.copyWith(updatedAt: Value(DateTime.now())),
      );

  Future<bool> isReferenced(int foodId) async =>
      await (selectOnly(foodEntries)
            ..addColumns([foodEntries.id])
            ..where(foodEntries.foodItemId.equals(foodId))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<void> deleteFood(int id) =>
      (delete(foodItems)..where((f) => f.id.equals(id))).go();

  // ------------------------------------------------------------------ diary

  Future<int> insertEntry(FoodEntriesCompanion entry) =>
      into(foodEntries).insert(entry);

  Future<FoodEntry?> entryById(int id) =>
      (select(foodEntries)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<void> updateEntry(int id, FoodEntriesCompanion entry) =>
      (update(foodEntries)..where((e) => e.id.equals(id))).write(entry);

  Future<bool> deleteEntry(int id) async =>
      await (delete(foodEntries)..where((e) => e.id.equals(id))).go() == 1;

  /// Entries logged on [localDate] (yyyy-MM-dd), in eating order.
  Stream<List<FoodEntry>> watchEntriesOn(String localDate) =>
      (select(foodEntries)
            ..where((e) => e.localDate.equals(localDate))
            ..orderBy([
              (e) => OrderingTerm.asc(e.consumedAt),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .watch();

  /// Entries with `from <= local_date < to`; null bounds are open.
  Stream<List<FoodEntry>> watchEntriesBetween({String? from, String? to}) {
    final q = select(foodEntries)
      ..orderBy([(e) => OrderingTerm.asc(e.consumedAt)]);
    if (from != null) q.where((e) => e.localDate.isBiggerOrEqualValue(from));
    if (to != null) q.where((e) => e.localDate.isSmallerThanValue(to));
    return q.watch();
  }

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
