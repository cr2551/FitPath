// Drift `check()` constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';

/// One row per dashboard card, so cards can be reordered and hidden
/// independently.
@DataClassName('DashboardCard')
class DashboardCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardType => textEnum<DashboardCardType>()();
  IntColumn get position => integer()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  TextColumn get cardSize =>
      textEnum<CardSize>().withDefault(Constant(CardSize.regular.name))();
  TextColumn get configJson => text().nullable()();
}

/// User preferences. Exactly one row (id = 1), created with the database.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id =>
      integer().withDefault(const Constant(1)).check(id.equals(1))();
  TextColumn get unitSystem =>
      textEnum<UnitSystem>().withDefault(Constant(UnitSystem.metric.name))();

  /// 'system', 'light' or 'dark'.
  TextColumn get themeMode => text()
      .withDefault(const Constant('system'))
      .check(themeMode.isIn(const ['system', 'light', 'dark']))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Technical state. Exactly one row (id = 1), created with the database.
@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  IntColumn get id =>
      integer().withDefault(const Constant(1)).check(id.equals(1))();

  /// Version of the JSON backup format the data was last written with.
  IntColumn get dataFormatVersion => integer().withDefault(const Constant(1))();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
