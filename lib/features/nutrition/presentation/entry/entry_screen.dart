import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';
import '../../../../shared/models/enums.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #26, which owns this file.
class EntryScreen extends StatelessWidget {
  const EntryScreen({
    super.key,
    this.entryId,
    this.foodId,
    this.meal,
    this.date,
  });

  final int? entryId;
  final int? foodId;
  final MealType? meal;
  final DateTime? date;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Log food', issue: 26);
}
