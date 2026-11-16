import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// A card-sized loading indicator.
class CardLoading extends StatelessWidget {
  const CardLoading({super.key});

  @override
  Widget build(BuildContext context) => const SectionCard(
    child: SizedBox(
      height: 64,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}
