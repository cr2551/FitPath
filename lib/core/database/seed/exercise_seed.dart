import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../app_database.dart';

/// The bundled starter exercise catalog.
const exerciseCatalogAsset = 'assets/data/exercises_starter.json';

/// Muscle groups used by the catalog (and offered for custom exercises).
const muscleGroups = [
  'chest',
  'back',
  'legs',
  'shoulders',
  'arms',
  'core',
  'full body',
];

/// Inserts the bundled starter exercises. Called once from the database's
/// `onCreate`; safe to call again (does nothing if catalog exercises exist).
Future<void> seedExercises(AppDatabase db, {AssetBundle? bundle}) async {
  final existing =
      await (db.select(db.exercises)
            ..where((e) => e.isCustom.equals(false))
            ..limit(1))
          .get();
  if (existing.isNotEmpty) return;

  final json = await (bundle ?? rootBundle).loadString(exerciseCatalogAsset);
  final exercises = parseExerciseCatalog(json);
  await db.batch((b) => b.insertAll(db.exercises, exercises));
}

/// Parses the catalog JSON. Throws [FormatException] on bad data.
List<ExercisesCompanion> parseExerciseCatalog(String json) {
  final doc = jsonDecode(json);
  if (doc is! Map<String, dynamic> || doc['version'] != 1) {
    throw const FormatException('Unsupported exercise catalog version');
  }
  final list = doc['exercises'];
  if (list is! List) throw const FormatException('Missing "exercises" list');

  return [
    for (final raw in list.cast<Map<String, dynamic>>()) _parseExercise(raw),
  ];
}

ExercisesCompanion _parseExercise(Map<String, dynamic> e) {
  final name = e['name'];
  final group = e['muscleGroup'];
  if (name is! String || name.trim().isEmpty) {
    throw FormatException('Exercise without a name: $e');
  }
  if (!muscleGroups.contains(group)) {
    throw FormatException('Bad muscle group "$group" for $name');
  }
  return ExercisesCompanion.insert(
    name: name.trim(),
    muscleGroup: group as String,
    equipment: Value(e['equipment'] as String?),
    isBodyweight: Value(e['isBodyweight'] == true),
  );
}
