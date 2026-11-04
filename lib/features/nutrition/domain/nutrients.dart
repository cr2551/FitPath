/// Nutrient amounts. Every value is nullable: **unknown is not zero**
/// (spec section 9), so a missing value must never be summed as 0 silently.
class Nutrients {
  const Nutrients({
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  static const empty = Nutrients();

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  /// True when protein, carbs and fat are all known.
  bool get hasAllMacros => proteinG != null && carbsG != null && fatG != null;

  /// Multiplies every known value; unknown values stay unknown.
  Nutrients operator *(double factor) => Nutrients(
    kcal: _mul(kcal, factor),
    proteinG: _mul(proteinG, factor),
    carbsG: _mul(carbsG, factor),
    fatG: _mul(fatG, factor),
    fiberG: _mul(fiberG, factor),
    sugarG: _mul(sugarG, factor),
    sodiumMg: _mul(sodiumMg, factor),
  );

  static double? _mul(double? v, double f) => v == null ? null : v * f;

  @override
  bool operator ==(Object other) =>
      other is Nutrients &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG &&
      other.sugarG == sugarG &&
      other.sodiumMg == sodiumMg;

  @override
  int get hashCode =>
      Object.hash(kcal, proteinG, carbsG, fatG, fiberG, sugarG, sodiumMg);

  @override
  String toString() =>
      'Nutrients(kcal: $kcal, P: $proteinG, C: $carbsG, F: $fatG, '
      'fiber: $fiberG, sugar: $sugarG, sodium: $sodiumMg)';
}
