import '../../../../shared/widgets/widgets.dart';

/// Everything the recipe ideas screen renders. Plain values only.
sealed class RecipeIdeasBody {
  const RecipeIdeasBody();
}

class IdeasLoading extends RecipeIdeasBody {
  const IdeasLoading();
}

class IdeasError extends RecipeIdeasBody {
  const IdeasError(this.message);

  final String message;
}

/// No calorie target is in effect on the day.
class IdeasNoTargets extends RecipeIdeasBody {
  const IdeasNoTargets();
}

class IdeasLoaded extends RecipeIdeasBody {
  const IdeasLoaded({
    required this.headline,
    required this.over,
    required this.rows,
    required this.categories,
    required this.diets,
    required this.category,
    required this.diet,
    required this.hasRecipes,
  });

  /// E.g. "640 kcal left" or "120 kcal over your target".
  final String headline;

  /// The day is over its calorie target: [rows] are lightest first.
  final bool over;
  final List<RecipeIdeaRow> rows;

  /// Filter choices; a null value means "All".
  final List<DropdownOption<String?>> categories;
  final List<DropdownOption<String?>> diets;
  final String? category;
  final String? diet;

  /// False when there are no recipes at all (before filtering).
  final bool hasRecipes;
}

class RecipeIdeaRow {
  const RecipeIdeaRow({
    required this.foodId,
    required this.name,
    required this.kcal,
    required this.macros,
    required this.reasons,
  });

  final int foodId;
  final String name;

  /// Formatted kcal per serving, "—" when unknown.
  final String kcal;

  /// E.g. "P 32 g · C 41 g · F 12 g".
  final String macros;

  /// Why it fits, e.g. "Uses 45% of the 640 kcal left".
  final List<String> reasons;
}
