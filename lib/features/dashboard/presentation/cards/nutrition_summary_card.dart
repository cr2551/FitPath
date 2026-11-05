import 'package:flutter/material.dart';

import '../../../../shared/models/enums.dart';
import 'placeholder_card.dart';

/// PLACEHOLDER created by #32 (Home dashboard). Replaced by #34, which owns
/// this file.
class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderCard(
    type: DashboardCardType.nutritionSummary,
    issue: 34,
  );
}
