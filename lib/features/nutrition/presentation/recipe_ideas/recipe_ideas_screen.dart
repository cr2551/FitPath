import 'package:flutter/widgets.dart';

import '../../../../core/router/placeholder_screen.dart';
import '../../../../shared/models/enums.dart';

/// Recipes ranked by how well they fit the day's remaining calories and
/// macros.
class RecipeIdeasScreen extends StatelessWidget {
  const RecipeIdeasScreen({super.key, this.meal, this.date});

  final MealType? meal;
  final DateTime? date;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Recipe ideas', issue: 118);
}
