/// A food as returned by Open Food Facts, mapped to FitPath's conventions.
///
/// Nutrient values are per 100 g, or per 100 ml when [isLiquid] is true.
/// Missing values stay null: community data is often incomplete and unknown
/// must never be shown as zero.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.isLiquid = false,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.servingSize,
    this.servingIsMl = false,
    this.servingDescription,
  });

  /// Barcode, used as `food_items.external_id` when cached.
  final String barcode;
  final String name;
  final String? brand;

  /// True when values are per 100 ml instead of per 100 g.
  final bool isLiquid;

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  /// One serving in g (or ml when [servingIsMl]), e.g. 30.
  final double? servingSize;
  final bool servingIsMl;

  /// Label text such as "1 bar (60 g)".
  final String? servingDescription;

  bool get hasAnyNutrient =>
      kcal != null || proteinG != null || carbsG != null || fatG != null;

  /// Maps one product JSON object. Returns null when the product has no
  /// barcode or no usable name (it could not be cached or shown).
  static OffProduct? fromJson(Map<String, dynamic> json) {
    final barcode = _string(json['code']);
    final name =
        _string(json['product_name']) ??
        _string(json['product_name_en']) ??
        _string(json['generic_name']);
    if (barcode == null || name == null) return null;

    final n = json['nutriments'] is Map<String, dynamic>
        ? json['nutriments'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final kcal =
        _number(n['energy-kcal_100g']) ??
        _kjToKcal(_number(n['energy-kj_100g']));
    final sodiumG = _number(n['sodium_100g']);

    final servingDescription = _string(json['serving_size']);
    final servingUnit =
        _string(json['serving_quantity_unit']) ?? _unitIn(servingDescription);

    return OffProduct(
      barcode: barcode,
      name: name,
      brand: _firstBrand(_string(json['brands'])),
      isLiquid: _isLiquid(json),
      kcal: kcal,
      proteinG: _number(n['proteins_100g']),
      carbsG: _number(n['carbohydrates_100g']),
      fatG: _number(n['fat_100g']),
      fiberG: _number(n['fiber_100g']),
      sugarG: _number(n['sugars_100g']),
      sodiumMg: sodiumG == null ? null : sodiumG * 1000,
      servingSize: _number(json['serving_quantity']),
      servingIsMl: servingUnit == 'ml',
      servingDescription: servingDescription,
    );
  }

  static bool _isLiquid(Map<String, dynamic> json) {
    final unit = _string(json['product_quantity_unit'])?.toLowerCase();
    if (unit != null) return unit == 'ml' || unit == 'cl' || unit == 'l';
    return _unitIn(_string(json['quantity'])) == 'ml';
  }

  /// Detects "ml" (incl. cl / l) or "g" (incl. kg) in a label like "330 ml".
  static String? _unitIn(String? text) {
    if (text == null) return null;
    final m = RegExp(
      r'\d\s*(ml|cl|l|kg|g)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    final u = m.group(1)!.toLowerCase();
    return (u == 'ml' || u == 'cl' || u == 'l') ? 'ml' : 'g';
  }

  static String? _firstBrand(String? brands) {
    final first = brands?.split(',').first.trim();
    return (first == null || first.isEmpty) ? null : first;
  }

  static double? _kjToKcal(double? kj) => kj == null ? null : kj / 4.184;

  static String? _string(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// OFF sometimes sends numbers as strings; negative values are invalid.
  static double? _number(Object? v) {
    final d = switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
    return (d == null || d.isNaN || d < 0) ? null : d;
  }
}

class OffSearchPage {
  const OffSearchPage({
    required this.products,
    required this.page,
    required this.totalCount,
  });

  static const empty = OffSearchPage(products: [], page: 1, totalCount: 0);

  final List<OffProduct> products;
  final int page;
  final int totalCount;
}
