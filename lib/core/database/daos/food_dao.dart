import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_tables.dart';

part 'food_dao.g.dart';

/// Food catalog and diary queries. Owned by #11 (Food repository).
@DriftAccessor(tables: [FoodItems, FoodEntries])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);
}
