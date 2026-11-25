import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'recipe_ideas_view_data.dart';

/// Pure layout for the recipe ideas screen.
class RecipeIdeasView extends StatelessWidget {
  const RecipeIdeasView({
    super.key,
    required this.body,
    required this.onOpen,
    required this.onCategory,
    required this.onDiet,
    required this.onSetTargets,
    required this.onCreateRecipe,
    required this.onRetry,
    this.target,
  });

  final RecipeIdeasBody body;

  /// E.g. "Adding to Lunch · Today".
  final String? target;
  final ValueChanged<int> onOpen;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onDiet;
  final VoidCallback onSetTargets;
  final VoidCallback onCreateRecipe;
  final VoidCallback onRetry;

  static const attribution =
      'Bundled recipes: UniTools — theunitools.com, CC BY-SA 4.0. '
      'Their nutrition per serving is an estimate.';

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe ideas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            if (target != null) ...[
              Text(target!, style: t.label, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
            ],
            ...switch (body) {
              IdeasLoading() => const [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              IdeasError(:final message) => [
                ErrorState(message: message, onRetry: onRetry),
              ],
              IdeasNoTargets() => [
                Text(
                  'Recipe ideas are ranked by what is left of your daily '
                  'calories and macros. Set a calorie target to see them.',
                  style: t.body,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onSetTargets,
                    child: const Text('Set targets'),
                  ),
                ),
              ],
              final IdeasLoaded l => _loaded(context, l),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _loaded(BuildContext context, IdeasLoaded l) {
    final c = context.fitColors;
    final t = context.textStyles;
    return [
      Text(
        l.headline,
        style: t.cardTitle.copyWith(color: l.over ? c.warning : c.ink),
      ),
      if (l.over) Text('Lightest options first.', style: t.label),
      const SizedBox(height: AppSpacing.md),
      AppDropdown<String?>(
        label: 'Category',
        options: l.categories,
        value: l.category,
        onChanged: onCategory,
      ),
      const SizedBox(height: AppSpacing.sm),
      AppDropdown<String?>(
        label: 'Diet',
        options: l.diets,
        value: l.diet,
        onChanged: onDiet,
      ),
      const SizedBox(height: AppSpacing.md),
      if (!l.hasRecipes)
        EmptyState(
          message: 'No recipes yet.',
          actionLabel: 'Create recipe',
          onAction: onCreateRecipe,
        )
      else if (l.rows.isEmpty)
        const EmptyState(message: 'No recipes match these filters.')
      else
        SectionCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < l.rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListRow(
                  title: l.rows[i].name,
                  subtitle: [l.rows[i].macros, ...l.rows[i].reasons].join('\n'),
                  value: l.rows[i].kcal,
                  unit: 'kcal',
                  onTap: () => onOpen(l.rows[i].foodId),
                ),
              ],
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      Text(attribution, style: t.label),
    ];
  }
}
