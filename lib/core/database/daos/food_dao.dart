import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_tables.dart';

part 'food_dao.g.dart';

/// Food catalog and diary queries.
@DriftAccessor(tables: [FoodItems, FoodEntries])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);

  // ---------------------------------------------------------------- catalog

  /// Active foods matching every word of [query] (case-insensitive) in their
  /// name or brand, names starting with the query first. Words are matched by
  /// their singular stem, so "eggs" finds "Egg, fried" and "tomatoes" finds
  /// "Tomato, raw".
  Future<List<FoodItem>> searchActive(String query, {int limit = 30}) {
    final words = searchStems(query);
    if (words.isEmpty) return Future.value(const []);
    final nameLower = foodItems.name.lower();
    final brandLower = foodItems.brand.lower();
    final prefix = '${_escapeLike(words.first)}%';
    return (select(foodItems)
          ..where((f) {
            var condition = f.isActive.equals(true);
            for (final w in words) {
              final pattern = '%${_escapeLike(w)}%';
              condition =
                  condition &
                  (nameLower.like(pattern, escapeChar: r'\') |
                      brandLower.like(pattern, escapeChar: r'\'));
            }
            return condition;
          })
          ..orderBy([
            (f) => OrderingTerm.desc(nameLower.like(prefix, escapeChar: r'\')),
            (f) => OrderingTerm.asc(nameLower),
          ])
          ..limit(limit))
        .get();
  }

  /// Lower-case words of [query] reduced to a stem shared by the singular and
  /// plural ("eggs" -> "egg", "tomatoes" -> "tomato", "berries" and "berry"
  /// -> "berr"). Stems stay at least
  /// three letters long so short words are not over-trimmed.
  static List<String> searchStems(String query) => [
    for (final word in query.toLowerCase().split(RegExp(r'[\s,]+')))
      if (word.isNotEmpty) _stem(word),
  ];

  static String _stem(String w) {
    String cut(int n) => w.length - n >= 3 ? w.substring(0, w.length - n) : w;
    if (w.endsWith('ies')) return cut(3);
    // "berry" and "berries" share "berr" ("turkey" keeps its y).
    if (RegExp(r'[^aeiou]y$').hasMatch(w)) return cut(1);
    if (w.endsWith('oes') || w.endsWith('ches') || w.endsWith('shes')) {
      return cut(2);
    }
    if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us')) {
      return cut(1);
    }
    return w;
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
