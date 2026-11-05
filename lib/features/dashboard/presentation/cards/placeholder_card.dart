import 'package:flutter/material.dart';

import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/card_catalog.dart';

/// Stand-in for a dashboard card whose content is built by a later issue.
class PlaceholderCard extends StatelessWidget {
  const PlaceholderCard({super.key, required this.type, required this.issue});

  final DashboardCardType type;

  /// The issue that builds this card.
  final int issue;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      header: CardHeader(title: CardCatalog.of(type).title),
      child: EmptyState(message: 'Coming in #$issue'),
    );
  }
}
