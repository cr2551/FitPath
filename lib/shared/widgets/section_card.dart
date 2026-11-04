import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';

/// White card with an optional header, divider and footer.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.dividerBelowHeader = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final bool dividerBelowHeader;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            header!,
            if (dividerBelowHeader)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(),
              )
            else
              const SizedBox(height: AppSpacing.md),
          ],
          child,
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Card header: optional icon tile, title, optional subtitle, optional
/// trailing widget (e.g. a text button).
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;

  /// Plain text or rich text (e.g. a bold number).
  final InlineSpan? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Row(
      children: [
        if (icon != null) ...[
          IconTile(icon: icon!),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.cardTitle),
              if (subtitle != null) Text.rich(subtitle!, style: t.label),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 36 px square tile holding an icon, with the `subtle` fill.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: c.subtle, borderRadius: AppRadii.mdAll),
      child: Icon(icon, color: c.ink, size: 22),
    );
  }
}
