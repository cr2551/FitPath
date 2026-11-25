import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

/// One substitute as the swap sheet shows it. Plain strings only.
class SubstitutionOptionData {
  const SubstitutionOptionData({
    required this.name,
    required this.amount,
    required this.note,
    required this.differences,
  });

  final String name;

  /// The substitute's amount, e.g. "125 g (1.25 × the original)".
  final String amount;
  final String note;

  /// Per-serving changes, e.g. ["−12 kcal", "+3 g protein", "carbs unknown"].
  final List<String> differences;
}

/// Lists substitutes for [ingredient]. Returns the picked option's index, or
/// null when dismissed.
Future<int?> showSubstitutionSheet(
  BuildContext context, {
  required String ingredient,
  required List<SubstitutionOptionData> options,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final t = context.textStyles;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Swap $ingredient', style: t.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text('Change per serving', style: t.label),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListRow(
                title: options[i].name,
                subtitle: [
                  options[i].amount,
                  options[i].differences.join(' · '),
                  options[i].note,
                ].join('\n'),
                trailing: const Icon(Icons.swap_horiz),
                onTap: () => Navigator.of(context).pop(i),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Substitutions: Wikibooks Cookbook contributors, CC BY-SA 4.0.',
              style: t.label,
            ),
          ],
        ),
      );
    },
  );
}
