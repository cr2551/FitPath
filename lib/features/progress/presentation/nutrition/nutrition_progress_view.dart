import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// PLACEHOLDER created by #36 (Progress shell). Replaced by #38, which owns
/// this file. Reads `progressRangeProvider` for the selected range.
class NutritionProgressView extends StatelessWidget {
  const NutritionProgressView({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    header: CardHeader(title: 'Nutrition'),
    child: EmptyState(message: 'Coming in #38'),
  );
}
