// Drift `check()` constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';

/// Allowed values for a diary entry's quantity unit.
const quantityUnits = ['g', 'ml', 'serving'];

/// Food catalog: bundled, cached from Open Food Facts, or custom.
/// Nutrient values refer to [referenceBasis]; null means unknown, not zero.
@DataClassName('FoodItem')
@TableIndex(name: 'food_items_name', columns: {#name})
class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get brand => text().nullable()();
  TextColumn get referenceBasis => textEnum<ReferenceBasis>()();
  RealColumn get servingSize => real().nullable()();

  /// 'g' or 'ml': the unit of [servingSize].
  TextColumn get servingUnit =>
      text().nullable().check(servingUnit.isIn(const ['g', 'ml']))();
  TextColumn get servingDescription => text().nullable()();

  RealColumn get kcal => real().nullable()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fiberG => real().nullable()();
  RealColumn get sugarG => real().nullable()();
  RealColumn get sodiumMg => real().nullable()();

  TextColumn get source => textEnum<FoodSource>()();

  /// Open Food Facts barcode, so an external result is cached only once.
  TextColumn get externalId => text().nullable().unique()();

  /// Inactive items are hidden from search but keep diary history intact.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Diary entries. Nutrients are a SNAPSHOT taken when logging, so editing or
/// deactivating the catalog item never rewrites history.
@DataClassName('FoodEntry')
@TableIndex(name: 'food_entries_local_date', columns: {#localDate})
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodItemId =>
      integer().references(FoodItems, #id, onDelete: KeyAction.restrict)();
  RealColumn get quantity => real()();
  TextColumn get quantityUnit =>
      text().check(quantityUnit.isIn(quantityUnits))();
  TextColumn get mealType => textEnum<MealType>()();
  DateTimeColumn get consumedAt => dateTime()();

  /// Local date key (yyyy-MM-dd) of [consumedAt] when it was logged.
  TextColumn get localDate => text().withLength(min: 10, max: 10)();

  TextColumn get nameSnapshot => text()();
  TextColumn get brandSnapshot => text().nullable()();
  RealColumn get kcal => real().nullable()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fiberG => real().nullable()();
  RealColumn get sugarG => real().nullable()();
  RealColumn get sodiumMg => real().nullable()();
}
