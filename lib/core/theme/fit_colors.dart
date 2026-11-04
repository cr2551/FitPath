import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// App-specific semantic colors, available as `context.fitColors`.
///
/// Feature code reads colors only from here or from `Theme.of(context)`,
/// never from `AppColors` or hex literals, so a restyle only touches
/// `lib/core/theme/`.
@immutable
class FitColors extends ThemeExtension<FitColors> {
  const FitColors({
    required this.background,
    required this.surface,
    required this.subtle,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.unknown,
    required this.success,
    required this.warning,
    required this.error,
  });

  static const light = FitColors(
    background: AppColors.background,
    surface: AppColors.surface,
    subtle: AppColors.subtle,
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    line: AppColors.line,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    protein: AppColors.protein,
    carbs: AppColors.carbs,
    fat: AppColors.fat,
    unknown: AppColors.unknown,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
  );

  static const dark = FitColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    subtle: AppColors.darkSubtle,
    ink: AppColors.darkInk,
    inkMuted: AppColors.darkInkMuted,
    line: AppColors.darkLine,
    accent: AppColors.darkAccent,
    onAccent: AppColors.darkOnAccent,
    protein: AppColors.protein,
    carbs: AppColors.carbs,
    fat: AppColors.fat,
    unknown: AppColors.darkUnknown,
    success: AppColors.darkSuccess,
    warning: AppColors.darkWarning,
    error: AppColors.darkError,
  );

  final Color background;
  final Color surface;

  /// Unselected tiles, icon buttons, footer strips, icon tiles.
  final Color subtle;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color protein;
  final Color carbs;
  final Color fat;

  /// Calories whose macro split is unknown.
  final Color unknown;
  final Color success;
  final Color warning;
  final Color error;

  @override
  FitColors copyWith({
    Color? background,
    Color? surface,
    Color? subtle,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? unknown,
    Color? success,
    Color? warning,
    Color? error,
  }) => FitColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    subtle: subtle ?? this.subtle,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    unknown: unknown ?? this.unknown,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  FitColors lerp(FitColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FitColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      subtle: l(subtle, other.subtle),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      line: l(line, other.line),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      protein: l(protein, other.protein),
      carbs: l(carbs, other.carbs),
      fat: l(fat, other.fat),
      unknown: l(unknown, other.unknown),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
    );
  }
}

/// Semantic text styles with theme colors applied, available as
/// `context.textStyles`.
@immutable
class FitTextStyles extends ThemeExtension<FitTextStyles> {
  const FitTextStyles({
    required this.hero,
    required this.display,
    required this.headline,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.overline,
    required this.button,
  });

  factory FitTextStyles.of(FitColors c) => FitTextStyles(
    hero: AppTypography.hero.copyWith(color: c.ink),
    display: AppTypography.display.copyWith(color: c.ink),
    headline: AppTypography.headline.copyWith(color: c.ink),
    cardTitle: AppTypography.cardTitle.copyWith(color: c.ink),
    body: AppTypography.body.copyWith(color: c.ink),
    bodyStrong: AppTypography.bodyStrong.copyWith(color: c.ink),
    label: AppTypography.label.copyWith(color: c.inkMuted),
    overline: AppTypography.overline.copyWith(color: c.inkMuted),
    button: AppTypography.button,
  );

  final TextStyle hero;
  final TextStyle display;
  final TextStyle headline;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle overline;
  final TextStyle button;

  @override
  FitTextStyles copyWith({
    TextStyle? hero,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? cardTitle,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? overline,
    TextStyle? button,
  }) => FitTextStyles(
    hero: hero ?? this.hero,
    display: display ?? this.display,
    headline: headline ?? this.headline,
    cardTitle: cardTitle ?? this.cardTitle,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    label: label ?? this.label,
    overline: overline ?? this.overline,
    button: button ?? this.button,
  );

  @override
  FitTextStyles lerp(FitTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return FitTextStyles(
      hero: l(hero, other.hero),
      display: l(display, other.display),
      headline: l(headline, other.headline),
      cardTitle: l(cardTitle, other.cardTitle),
      body: l(body, other.body),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      label: l(label, other.label),
      overline: l(overline, other.overline),
      button: l(button, other.button),
    );
  }
}

extension FitThemeContext on BuildContext {
  FitColors get fitColors => Theme.of(this).extension<FitColors>()!;
  FitTextStyles get textStyles => Theme.of(this).extension<FitTextStyles>()!;
}
