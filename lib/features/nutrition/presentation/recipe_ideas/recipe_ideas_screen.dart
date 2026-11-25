import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/diary_providers.dart';
import '../../application/recipe_providers.dart';
import '../../data/local/recipe_repository.dart';
import '../../domain/nutrition_math.dart';
import '../../domain/recipe_ranking.dart';
import '../day_overview/day_overview_screen.dart' show mealTitle;
import 'recipe_ideas_view.dart';
import 'recipe_ideas_view_data.dart';

/// Recipes ranked by how well they fit the day's remaining calories and
/// macros. Tapping one logs a serving through the entry screen.
class RecipeIdeasScreen extends ConsumerStatefulWidget {
  const RecipeIdeasScreen({super.key, this.meal, this.date});

  final MealType? meal;
  final DateTime? date;

  /// The most ideas shown at once.
  static const maxRows = 25;

  @override
  ConsumerState<RecipeIdeasScreen> createState() => _RecipeIdeasScreenState();
}

class _RecipeIdeasScreenState extends ConsumerState<RecipeIdeasScreen> {
  String? _category;
  String? _diet;

  DateTime get _day => Dates.startOfDay(widget.date ?? DateTime.now());

  @override
  Widget build(BuildContext context) {
    final key = Dates.localDateKey(_day);
    final targets = ref.watch(targetsForDateProvider(key));
    final summary = ref.watch(dailySummaryProvider(key));
    final recipes = ref.watch(recipesProvider);
    final goals = ref.watch(activeGoalsProvider);
    // Missing tags only disable filtering; never block the list.
    final tags = ref.watch(bundledRecipeTagsProvider).value ?? const {};

    final values = <AsyncValue<Object?>>[targets, summary, recipes, goals];
    final RecipeIdeasBody body;
    if (values.any((v) => v.hasError)) {
      body = const IdeasError("Couldn't load recipe ideas.");
    } else if (values.any((v) => !v.hasValue)) {
      body = const IdeasLoading();
    } else if (targets.requireValue == null ||
        targets.requireValue!.calories <= 0) {
      body = const IdeasNoTargets();
    } else {
      body = _loaded(
        targets.requireValue!,
        summary.requireValue.total,
        recipes.requireValue,
        goals.requireValue.where((g) => g.isPrimary).firstOrNull?.goalType,
        tags,
      );
    }

    return RecipeIdeasView(
      body: body,
      target: _target(),
      onOpen: (foodId) => context.push(
        Routes.newEntry(
          foodId: foodId,
          meal: widget.meal,
          date: _day,
          quantity: 1,
          unit: 'serving',
        ),
      ),
      onCategory: (v) => setState(() => _category = v),
      onDiet: (v) => setState(() => _diet = v),
      onSetTargets: () => context.go(Routes.targets),
      onCreateRecipe: () => context.push(Routes.newRecipe),
      onRetry: () => ref
        ..invalidate(targetsForDateProvider(key))
        ..invalidate(dailySummaryProvider(key))
        ..invalidate(recipesProvider)
        ..invalidate(activeGoalsProvider),
    );
  }

  IdeasLoaded _loaded(
    NutritionTarget target,
    NutrientTotals eaten,
    List<RecipeSummary> recipes,
    GoalType? goal,
    Map<String, RecipeTags> tags,
  ) {
    final budget = DayBudget(
      targetKcal: target.calories.toDouble(),
      eatenKcal: eaten.kcal,
      targetProteinG: target.proteinG,
      targetCarbsG: target.carbsG,
      targetFatG: target.fatG,
      eatenProteinG: eaten.proteinG,
      eatenCarbsG: eaten.carbsG,
      eatenFatG: eaten.fatG,
    );
    RecipeTags? tagsOf(RecipeSummary r) =>
        r.bundledId == null ? null : tags[r.bundledId];

    final shown = recipes.where((r) {
      final t = tagsOf(r);
      if (_category != null && t?.category != _category) return false;
      if (_diet != null && !(t?.diets.contains(_diet) ?? false)) return false;
      return true;
    });
    final ranked = RecipeRanking.rank(
      [
        for (final r in shown)
          RecipeCandidate(
            foodId: r.foodId,
            name: r.name,
            perServing: r.perServing,
          ),
      ],
      budget: budget,
      goal: goal,
    );

    final categories = {for (final r in recipes) ?tagsOf(r)?.category}.toList()
      ..sort();
    final diets = {for (final r in recipes) ...?tagsOf(r)?.diets}.toList()
      ..sort();
    final remaining = budget.remainingKcal;

    return IdeasLoaded(
      headline: budget.isOver
          ? '${Formatters.energy(-remaining)} over your target'
          : '${Formatters.energy(remaining)} left',
      over: budget.isOver,
      rows: [
        for (final r in ranked.take(RecipeIdeasScreen.maxRows))
          _row(r, remaining),
      ],
      categories: _options(categories),
      diets: _options(diets),
      category: _category,
      diet: _diet,
      hasRecipes: recipes.isNotEmpty,
    );
  }

  static RecipeIdeaRow _row(RankedRecipe r, double remaining) {
    final n = r.candidate.perServing;
    final kcalShare = r.kcalShareOfRemaining;
    final proteinShare = r.proteinShareOfRemaining;
    return RecipeIdeaRow(
      foodId: r.candidate.foodId,
      name: r.candidate.name,
      kcal: Formatters.integer(n.kcal),
      macros:
          'P ${Formatters.grams(n.proteinG)} · '
          'C ${Formatters.grams(n.carbsG)} · '
          'F ${Formatters.grams(n.fatG)}',
      reasons: [
        if (n.kcal == null) 'Calories unknown',
        if (kcalShare != null)
          kcalShare <= 1
              ? 'Uses ${Formatters.percent(kcalShare)} of the '
                    '${Formatters.energy(remaining)} left'
              : '${Formatters.energy(n.kcal! - remaining)} more than is left',
        if (proteinShare != null)
          'Covers ${Formatters.percent(proteinShare.clamp(0, 1))} of the '
              'protein left',
        if (r.highProtein) 'High protein',
      ],
    );
  }

  static List<DropdownOption<String?>> _options(List<String> values) => [
    const DropdownOption<String?>(null, 'All'),
    for (final v in values) DropdownOption<String?>(v, _label(v)),
  ];

  /// "gluten-free" -> "Gluten-free".
  static String _label(String v) => v[0].toUpperCase() + v.substring(1);

  String? _target() {
    final meal = widget.meal;
    final date = widget.date;
    if (meal == null && date == null) return null;
    return [
      if (meal != null) 'Adding to ${mealTitle(meal)}',
      if (date != null)
        Dates.isSameDay(date, DateTime.now())
            ? 'Today'
            : DateFormat('EEE d MMM').format(date),
    ].join(' · ');
  }
}
