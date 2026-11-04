import '../../../../shared/models/enums.dart';

/// What the add/edit entry screen shows below its app bar.
sealed class EntryBody {
  const EntryBody();
}

class EntryLoading extends EntryBody {
  const EntryLoading();
}

class EntryError extends EntryBody {
  const EntryError(this.message);

  final String message;
}

class EntryFormData extends EntryBody {
  const EntryFormData({
    required this.isEdit,
    required this.foodName,
    required this.foodDetail,
    required this.initialQuantity,
    required this.quantityError,
    required this.unitLabels,
    required this.selectedUnit,
    required this.meal,
    required this.dateLabel,
    required this.timeLabel,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.canSave,
    required this.saving,
  });

  final bool isEdit;
  final String foodName;

  /// E.g. "Fage · 97 kcal per 100 g".
  final String foodDetail;

  /// Text the quantity field starts with.
  final String initialQuantity;
  final String? quantityError;

  /// E.g. ["g", "serving"].
  final List<String> unitLabels;
  final int selectedUnit;
  final MealType meal;
  final String dateLabel;
  final String timeLabel;

  /// Nutrients of the entered amount, formatted ("—" when unknown).
  final String kcal;
  final String proteinG;
  final String carbsG;
  final String fatG;

  final bool canSave;
  final bool saving;
}
