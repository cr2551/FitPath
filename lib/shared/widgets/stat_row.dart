import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';

class StatItem {
  const StatItem({required this.label, required this.value, this.unit});

  /// Shown as an uppercase overline.
  final String label;
  final String value;
  final String? unit;
}

/// Stats side by side, separated by thin vertical lines.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) VerticalDivider(width: AppSpacing.xl, color: c.line),
            Expanded(
              child: Semantics(
                container: true,
                label:
                    '${items[i].label} ${items[i].value} ${items[i].unit ?? ''}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].label.toUpperCase(),
                      style: t.overline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: items[i].value,
                          style: t.cardTitle.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            if (items[i].unit != null)
                              TextSpan(
                                text: ' ${items[i].unit}',
                                style: t.label,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
