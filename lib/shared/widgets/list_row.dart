import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';

/// A full-width list row: title and subtitle on the left, a value (and
/// optional unit) and chevron on the right. Separate rows with `Divider`s.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.unit,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final String? unit;

  /// Replaces the value/chevron area (e.g. a segmented control).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// E.g. the error color for "Reset all data".
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 1),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyStrong.copyWith(color: titleColor)),
                  if (subtitle != null) Text(subtitle!, style: t.label),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Text.rich(
                  TextSpan(
                    text: value,
                    style: t.body.copyWith(fontWeight: FontWeight.w500),
                    children: [
                      if (unit != null)
                        TextSpan(text: ' $unit', style: t.label),
                    ],
                  ),
                ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: c.inkMuted),
            ],
          ],
        ),
      ),
    );
  }
}
