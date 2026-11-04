import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';

/// Screen header with a centered title and optional icon buttons on either
/// side (e.g. profile on the left, edit layout on the right).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  /// A short line under the title, e.g. the goal.
  final String? subtitle;

  static const _slot = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: _slot, child: leading),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: t.headline,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: _slot, child: trailing),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: t.label, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A 40 px square icon button with the `subtle` fill.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: c.subtle,
          foregroundColor: c.ink,
        ),
        icon: Icon(icon),
      ),
    );
  }
}
