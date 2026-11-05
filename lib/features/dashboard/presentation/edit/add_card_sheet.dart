import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';

class AddCardOption {
  const AddCardOption({
    required this.type,
    required this.title,
    required this.description,
  });

  final DashboardCardType type;
  final String title;
  final String description;
}

/// Bottom sheet listing the cards that can be added. Returns the picked type,
/// or null when dismissed.
Future<DashboardCardType?> showAddCardSheet(
  BuildContext context,
  List<AddCardOption> options,
) {
  return showModalBottomSheet<DashboardCardType>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Add a card', style: context.textStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListRow(
              title: options[i].title,
              subtitle: options[i].description,
              trailing: const Icon(Icons.add),
              onTap: () => Navigator.of(context).pop(options[i].type),
            ),
          ],
        ],
      ),
    ),
  );
}
