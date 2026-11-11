/// Text inputs of the recipe form, besides the ingredient amounts.
enum RecipeField { name, servings }

/// What can be done to one ingredient from its menu.
enum IngredientAction { moveUp, moveDown, remove }

/// One ingredient row. Plain strings only.
class IngredientRowData {
  const IngredientRowData({
    required this.key,
    required this.name,
    required this.detail,
    required this.initialQuantity,
    required this.quantityError,
    required this.unitLabels,
    required this.selectedUnit,
    required this.kcal,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  /// Stable while the row exists, also across reordering.
  final int key;
  final String name;

  /// Brand and source, e.g. "Fage · Bundled".
  final String detail;
  final String initialQuantity;
  final String? quantityError;

  /// Only the units valid for the food, e.g. ["g", "serving"].
  final List<String> unitLabels;
  final int selectedUnit;

  /// Calories of the amount, e.g. "120 kcal" or "— kcal".
  final String kcal;
  final bool canMoveUp;
  final bool canMoveDown;
}

/// One per-serving nutrient, already formatted ("12 g", "—").
class RecipeNutrientLine {
  const RecipeNutrientLine({required this.label, required this.value});

  final String label;
  final String value;
}

sealed class RecipeBody {
  const RecipeBody();
}

class RecipeLoading extends RecipeBody {
  const RecipeLoading();
}

class RecipeError extends RecipeBody {
  const RecipeError(this.message);

  final String message;
}

class RecipeFormData extends RecipeBody {
  const RecipeFormData({
    required this.isEdit,
    required this.initialName,
    required this.initialServings,
    required this.nameError,
    required this.servingsError,
    required this.ingredients,
    required this.perServing,
    required this.notes,
    required this.canSave,
    required this.saving,
  });

  final bool isEdit;
  final String initialName;
  final String initialServings;
  final String? nameError;
  final String? servingsError;
  final List<IngredientRowData> ingredients;

  /// Empty when there is nothing to compute yet.
  final List<RecipeNutrientLine> perServing;

  /// E.g. "2 ingredients have no protein data".
  final List<String> notes;
  final bool canSave;
  final bool saving;
}
