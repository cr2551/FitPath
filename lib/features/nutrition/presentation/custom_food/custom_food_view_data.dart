/// Text inputs on the custom food form.
enum CustomFoodField {
  name,
  brand,
  servingSize,
  servingDescription,
  kcal,
  protein,
  carbs,
  fat,
  fiber,
  sugar,
  sodium,
}

/// What a food's nutrient values refer to, as the form offers it.
enum BasisChoice { per100g, per100ml, perServing }

/// Unit of a serving size.
enum ServingUnitChoice { gram, milliliter }

sealed class CustomFoodBody {
  const CustomFoodBody();
}

class CustomFoodLoading extends CustomFoodBody {
  const CustomFoodLoading();
}

class CustomFoodError extends CustomFoodBody {
  const CustomFoodError(this.message);

  final String message;
}

class CustomFoodFormData extends CustomFoodBody {
  const CustomFoodFormData({
    required this.isEdit,
    required this.initialText,
    required this.errors,
    required this.basis,
    required this.servingUnit,
    required this.canSave,
    required this.saving,
  });

  final bool isEdit;

  /// Text each field starts with.
  final Map<CustomFoodField, String> initialText;

  /// Current validation messages; a missing key means valid.
  final Map<CustomFoodField, String> errors;
  final BasisChoice basis;
  final ServingUnitChoice servingUnit;
  final bool canSave;
  final bool saving;
}
