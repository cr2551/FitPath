import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/enums.dart';
import '../app_database.dart';

/// The bundled starter catalog (see `assets/data/README.md`).
const foodCatalogAsset = 'assets/data/foods_starter.json';

/// Inserts the bundled starter food catalog. Called once from the database's
/// `onCreate`; safe to call again (does nothing if bundled foods exist).
Future<void> seedFoods(AppDatabase db, {AssetBundle? bundle}) async {
  final existing =
      await (db.select(db.foodItems)
            ..where((f) => f.source.equalsValue(FoodSource.bundled))
            ..limit(1))
          .get();
  if (existing.isNotEmpty) return;

  final json = await (bundle ?? rootBundle).loadString(foodCatalogAsset);
  final foods = parseFoodCatalog(json);
  await db.batch((b) => b.insertAll(db.foodItems, foods));
}

/// Parses the catalog JSON into rows. Throws [FormatException] on bad data so
/// a broken asset fails loudly in tests instead of seeding garbage.
List<FoodItemsCompanion> parseFoodCatalog(String json) {
  final doc = jsonDecode(json);
  if (doc is! Map<String, dynamic> || doc['version'] != 1) {
    throw const FormatException('Unsupported food catalog version');
  }
  final foods = doc['foods'];
  if (foods is! List) throw const FormatException('Missing "foods" list');

  return [for (final raw in foods) _parseFood(raw as Map<String, dynamic>)];
}

FoodItemsCompanion _parseFood(Map<String, dynamic> f) {
  final name = f['name'];
  if (name is! String || name.trim().isEmpty) {
    throw FormatException('Food without a name: $f');
  }
  final basis = switch (f['basis']) {
    'per100g' => ReferenceBasis.per100g,
    'per100ml' => ReferenceBasis.per100ml,
    final other => throw FormatException('Bad basis "$other" for $name'),
  };
  final serving = f['serving'] as Map<String, dynamic>?;
  final unit = serving?['unit'];
  if (unit != null && unit != 'g' && unit != 'ml') {
    throw FormatException('Bad serving unit "$unit" for $name');
  }

  double? n(String key) {
    final v = f[key];
    if (v == null) return null;
    if (v is! num || v < 0) throw FormatException('Bad $key for $name');
    return v.toDouble();
  }

  return FoodItemsCompanion.insert(
    name: name.trim(),
    referenceBasis: basis,
    source: FoodSource.bundled,
    kcal: Value(n('kcal')),
    proteinG: Value(n('proteinG')),
    carbsG: Value(n('carbsG')),
    fatG: Value(n('fatG')),
    fiberG: Value(n('fiberG')),
    sugarG: Value(n('sugarG')),
    sodiumMg: Value(n('sodiumMg')),
    servingSize: Value((serving?['size'] as num?)?.toDouble()),
    servingUnit: Value(unit as String?),
    servingDescription: Value(serving?['description'] as String?),
  );
}
