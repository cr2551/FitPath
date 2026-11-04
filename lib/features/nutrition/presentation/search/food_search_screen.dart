import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';
import '../../../../shared/models/enums.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #25, which owns this file.
class FoodSearchScreen extends StatelessWidget {
  const FoodSearchScreen({super.key, this.meal, this.date});

  final MealType? meal;
  final DateTime? date;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Search foods', issue: 25);
}
