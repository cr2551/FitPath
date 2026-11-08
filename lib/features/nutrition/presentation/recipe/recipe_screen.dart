import 'package:flutter/widgets.dart';

import '../../../../core/router/placeholder_screen.dart';

/// Recipe builder: a new recipe, or the recipe stored as food [foodId].
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key, this.foodId});

  final int? foodId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Recipe', issue: 114);
}
