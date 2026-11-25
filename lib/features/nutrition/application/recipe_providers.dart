import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/seed/recipe_seed.dart';
import '../data/local/recipe_repository.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RecipeRepository(db.recipeDao, db.foodDao);
});

/// Every loggable recipe, bundled and own.
final recipesProvider = StreamProvider<List<RecipeSummary>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchAll(),
);

/// Category and diet tags of a bundled recipe, from the dataset.
typedef RecipeTags = ({String? category, List<String> diets});

/// Tags of the bundled recipes by bundled id. Read from the asset rather than
/// stored, as only the recipe ideas filters use them.
final bundledRecipeTagsProvider = FutureProvider<Map<String, RecipeTags>>((
  ref,
) async {
  final json = await rootBundle.loadString(recipeCatalogAsset);
  return {
    for (final r in parseRecipeCatalog(json))
      r.id: (category: r.category, diets: r.diets),
  };
});
