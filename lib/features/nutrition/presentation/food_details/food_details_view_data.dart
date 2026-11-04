/// One nutrient line, already formatted ("12 g", "—").
class NutrientLine {
  const NutrientLine({required this.label, required this.value});

  final String label;
  final String value;
}

sealed class FoodDetailsBody {
  const FoodDetailsBody();
}

class FoodDetailsLoading extends FoodDetailsBody {
  const FoodDetailsLoading();
}

class FoodDetailsError extends FoodDetailsBody {
  const FoodDetailsError(this.message);

  final String message;
}

class FoodDetailsData extends FoodDetailsBody {
  const FoodDetailsData({
    required this.name,
    required this.subtitle,
    required this.basisLabel,
    required this.initialQuantity,
    required this.quantityError,
    required this.unitLabels,
    required this.selectedUnit,
    required this.amountLabel,
    required this.nutrients,
    required this.canEdit,
    this.attribution,
  });

  final String name;

  /// Brand and source, e.g. "Fage · Open Food Facts".
  final String subtitle;

  /// E.g. "Label values per 100 g".
  final String basisLabel;

  final String initialQuantity;
  final String? quantityError;
  final List<String> unitLabels;
  final int selectedUnit;

  /// What [nutrients] refer to, e.g. "For 150 g".
  final String amountLabel;
  final List<NutrientLine> nutrients;

  /// Custom foods can be edited.
  final bool canEdit;

  /// Data-source credit, e.g. for Open Food Facts.
  final String? attribution;
}
