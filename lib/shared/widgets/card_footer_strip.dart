import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';

class FooterItem {
  const FooterItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A `subtle` strip at the bottom of a card, with items separated by thin
/// vertical lines (e.g. "3 meals logged | 2 workouts this week").
class CardFooterStrip extends StatelessWidget {
  const CardFooterStrip({super.key, required this.items});

  final List<FooterItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Like the design's `auto 1fr`: earlier items take their natural
        // width (capped at an equal share), the last one fills the rest.
        final cap = constraints.maxWidth / items.length;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.subtle,
            borderRadius: AppRadii.smAll,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, color: c.line),
                  if (i == items.length - 1)
                    Expanded(child: _item(items[i], c, t))
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cap),
                      child: _item(items[i], c, t),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _item(FooterItem item, FitColors c, FitTextStyles t) {
    final text = Text(
      item.label,
      style: t.label.copyWith(color: c.ink),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.sm + 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 16, color: c.ink),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(child: text),
        ],
      ),
    );
  }
}
