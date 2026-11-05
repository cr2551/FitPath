import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// PLACEHOLDER created by #36 (Progress shell). Replaced by #37, which owns
/// this file. Reads `progressRangeProvider` for the selected range.
class WeightProgressView extends StatelessWidget {
  const WeightProgressView({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    header: CardHeader(title: 'Weight'),
    child: EmptyState(message: 'Coming in #37'),
  );
}
