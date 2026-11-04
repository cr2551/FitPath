import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';
import '../../../../shared/models/enums.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #25, which owns this file.
class FoodDetailsScreen extends StatelessWidget {
  const FoodDetailsScreen({
    super.key,
    required this.foodId,
    this.meal,
    this.date,
  });

  final int foodId;
  final MealType? meal;
  final DateTime? date;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Food details', issue: 25);
}
