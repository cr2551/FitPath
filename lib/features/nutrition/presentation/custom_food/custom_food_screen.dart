import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #27, which owns this file.
class CustomFoodScreen extends StatelessWidget {
  const CustomFoodScreen({super.key, this.foodId});

  final int? foodId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Custom food', issue: 27);
}
