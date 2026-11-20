import 'dart:convert';

/// Bundled Wikibooks-derived substitutions are parsed here for the recipe
/// builder. Persistence is intentionally deferred until a substitutions table
/// is needed; the catalog remains an attributed, versioned app asset.
const substitutionCatalogAsset = 'assets/data/substitutions.json';

class BundledSubstitution {
  const BundledSubstitution({
    required this.fromFoodName,
    required this.toFoodName,
    required this.ratio,
    required this.note,
  });

  final String fromFoodName;
  final String toFoodName;

  /// Amount of substitute for one amount of the original ingredient.
  final double ratio;
  final String note;
}

List<BundledSubstitution> parseSubstitutionCatalog(String json) {
  final document = jsonDecode(json);
  if (document is! Map<String, dynamic> || document['version'] != 1) {
    throw const FormatException('Unsupported substitution catalog version');
  }
  final rows = document['substitutions'];
  if (rows is! List) {
    throw const FormatException('Missing "substitutions" list');
  }
  return [
    for (final row in rows) _parseSubstitution(row as Map<String, dynamic>),
  ];
}

BundledSubstitution _parseSubstitution(Map<String, dynamic> row) {
  String text(String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Substitution missing $key: $row');
    }
    return value.trim();
  }

  final ratio = row['ratio'];
  if (ratio is! num || !ratio.isFinite || ratio <= 0) {
    throw FormatException('Substitution has invalid ratio: $row');
  }
  return BundledSubstitution(
    fromFoodName: text('fromFoodName'),
    toFoodName: text('toFoodName'),
    ratio: ratio.toDouble(),
    note: text('note'),
  );
}
